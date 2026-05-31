/**
 * Daily executor for the Secondary Targets module. Recomputes achievement on
 * every active Secondary_Target__c whose period includes today (BRD 3.1.1),
 * routing each through TAM_CalculationEngine_Service by its Target Criteria.
 */
global without sharing class SecondaryAchievementBatch implements Database.Batchable<SObject>, Database.Stateful {

    global Database.QueryLocator start(Database.BatchableContext BC) {
        Date today = Date.today();
        return Database.getQueryLocator([
            SELECT Id, User__c, Target_Criteria__c, Target_Value__c, Focused_Pack__c,
                   Start_Date__c, End_Date__c, Achievement_Value__c
            FROM Secondary_Target__c
            WHERE Is_Active__c = true
              AND Target_Criteria__c != NULL
              AND Start_Date__c <= :today
              AND End_Date__c >= :today
        ]);
    }

    global void execute(Database.BatchableContext BC, List<Secondary_Target__c> scope) {
        // Group by criteria + period so each engine call shares one period.
        Set<Id> critIds = new Set<Id>();
        Map<String, List<Secondary_Target__c>> groups = new Map<String, List<Secondary_Target__c>>();
        for (Secondary_Target__c t : scope) {
            critIds.add(t.Target_Criteria__c);
            String key = t.Target_Criteria__c + '|' + String.valueOf(t.Start_Date__c) + '|' + String.valueOf(t.End_Date__c);
            if (!groups.containsKey(key)) groups.put(key, new List<Secondary_Target__c>());
            groups.get(key).add(t);
        }

        Map<Id, Target_Criteria__c> critMap = new Map<Id, Target_Criteria__c>([
            SELECT Id, Object__c, Operator__c, Field__c, Date_Field__c, User_Field__c,
                   Filters__c, Filter_Logic__c, Distinct_Field__c, Numerator_Field__c,
                   Denominator_Field__c, Use_Attendance_Divisor__c, Secondary_Source_Objects__c
            FROM Target_Criteria__c WHERE Id IN :critIds
        ]);

        Map<Id, Decimal> achievementByTarget = new Map<Id, Decimal>();
        Map<Id, Integer> workingDaysByTarget = new Map<Id, Integer>();

        for (String key : groups.keySet()) {
            List<Secondary_Target__c> grp = groups.get(key);
            Target_Criteria__c crit = critMap.get(grp[0].Target_Criteria__c);
            if (crit == null) continue;

            Date startDate = grp[0].Start_Date__c;
            Date endDate = grp[0].End_Date__c;

            Set<Id> userIds = new Set<Id>();
            for (Secondary_Target__c t : grp) {
                if (t.User__c != null) userIds.add(t.User__c);
            }
            Map<Id, Integer> workingDaysByUser = TAM_AttendanceService.getWorkingDays(userIds, startDate, endDate);

            Map<Id, Decimal> res = TAM_CalculationEngine_Service.compute(crit, grp, startDate, endDate, workingDaysByUser);
            achievementByTarget.putAll(res);
            for (Secondary_Target__c t : grp) {
                workingDaysByTarget.put(t.Id, workingDaysByUser.containsKey(t.User__c) ? workingDaysByUser.get(t.User__c) : 0);
            }
        }

        List<Secondary_Target__c> toUpdate = new List<Secondary_Target__c>();
        for (Secondary_Target__c t : scope) {
            Decimal newVal = achievementByTarget.containsKey(t.Id) ? achievementByTarget.get(t.Id) : 0;
            Decimal oldVal = (t.Achievement_Value__c != null) ? t.Achievement_Value__c : 0;
            Decimal target = (t.Target_Value__c != null) ? t.Target_Value__c : 0;

            t.Daily_Achievement__c = newVal - oldVal;
            t.Achievement_Value__c = newVal;
            t.Achievement_Percent__c = (target != 0) ? (newVal / target * 100).setScale(2, System.RoundingMode.HALF_UP) : 0;
            t.Pending_Target__c = target - newVal;
            t.Working_Days__c = workingDaysByTarget.containsKey(t.Id) ? workingDaysByTarget.get(t.Id) : 0;
            t.Last_Updated__c = System.now();
            toUpdate.add(t);
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    global void finish(Database.BatchableContext BC) {}
}