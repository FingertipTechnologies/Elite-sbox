/**
 * UI controller for the Secondary Targets management console.
 * Handles CRUD on Secondary_Target__c plus on-demand achievement recalculation
 * (single target synchronously, or all active targets via the daily batch).
 */
public with sharing class SecondaryTarget_Controller {

    @AuraEnabled(cacheable=false)
    public static List<Secondary_Target__c> getTargets(String channel, String criteriaId, Boolean activeOnly) {
        String q =
            'SELECT Id, Name, User__c, User__r.Name, User_Name__c, Sales_Channel__c, Year__c, ' +
            'Start_Date__c, End_Date__c, Target_Criteria__c, Target_Criteria__r.Name, ' +
            'Target_Criteria__r.Operator__c, Target_Value__c, Achievement_Value__c, ' +
            'Achievement_Percent__c, Pending_Target__c, Daily_Achievement__c, Working_Days__c, ' +
            'Focused_Pack__c, Focused_Pack__r.Name, Is_Active__c, Last_Updated__c ' +
            'FROM Secondary_Target__c';
        List<String> wheres = new List<String>();
        if (String.isNotBlank(channel)) wheres.add('Sales_Channel__c = :channel');
        if (String.isNotBlank(criteriaId)) wheres.add('Target_Criteria__c = :criteriaId');
        if (activeOnly == true) wheres.add('Is_Active__c = true');
        if (!wheres.isEmpty()) q += ' WHERE ' + String.join(wheres, ' AND ');
        q += ' ORDER BY LastModifiedDate DESC LIMIT 500';
        return Database.query(q);
    }

    @AuraEnabled(cacheable=false)
    public static Secondary_Target__c getTarget(Id targetId) {
        return [
            SELECT Id, Name, User__c, User_Name__c, Sales_Channel__c, Year__c,
                   Start_Date__c, End_Date__c, Target_Criteria__c, Target_Value__c,
                   Focused_Pack__c, Is_Active__c
            FROM Secondary_Target__c WHERE Id = :targetId
        ];
    }

    @AuraEnabled
    public static Secondary_Target__c saveTarget(Secondary_Target__c target) {
        if (target.User__c != null && String.isBlank(target.User_Name__c)) {
            User u = [SELECT Name FROM User WHERE Id = :target.User__c LIMIT 1];
            target.User_Name__c = u.Name;
        }
        upsert target;
        return getTarget(target.Id);
    }

    @AuraEnabled
    public static void deleteTarget(Id targetId) {
        delete [SELECT Id FROM Secondary_Target__c WHERE Id = :targetId LIMIT 1];
    }

    // ===== Option providers =====

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCriteriaOptions() {
        List<Map<String, String>> opts = new List<Map<String, String>>();
        for (Target_Criteria__c c : [
            SELECT Id, Name, Operator__c FROM Target_Criteria__c
            WHERE Active__c = true ORDER BY Name
        ]) {
            opts.add(new Map<String, String>{
                'label' => c.Name + ' (' + c.Operator__c + ')',
                'value' => c.Id,
                'operator' => c.Operator__c
            });
        }
        return opts;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getFocusedPackOptions() {
        List<Map<String, String>> opts = new List<Map<String, String>>();
        for (Focused_Pack__c fp : [
            SELECT Id, Name, Sales_Channel__c FROM Focused_Pack__c ORDER BY Name LIMIT 1000
        ]) {
            opts.add(new Map<String, String>{ 'label' => fp.Name, 'value' => fp.Id });
        }
        return opts;
    }

    @AuraEnabled
    public static List<Map<String, String>> searchUsers(String term) {
        List<Map<String, String>> opts = new List<Map<String, String>>();
        String pattern = '%' + (term == null ? '' : String.escapeSingleQuotes(term)) + '%';
        for (User u : [
            SELECT Id, Name, Username FROM User
            WHERE IsActive = true AND Name LIKE :pattern ORDER BY Name LIMIT 25
        ]) {
            opts.add(new Map<String, String>{ 'label' => u.Name + ' (' + u.Username + ')', 'value' => u.Id });
        }
        return opts;
    }

    // ===== Recalculation =====

    @AuraEnabled
    public static Id recalculateAll() {
        return Database.executeBatch(new SecondaryAchievementBatch(), 200);
    }

    /**
     * Recomputes one target synchronously for instant feedback in the console.
     * Mirrors the field updates performed by SecondaryAchievementBatch.
     */
    @AuraEnabled
    public static Secondary_Target__c recalculateTarget(Id targetId) {
        Secondary_Target__c t = [
            SELECT Id, User__c, Target_Criteria__c, Target_Value__c, Focused_Pack__c,
                   Start_Date__c, End_Date__c, Achievement_Value__c
            FROM Secondary_Target__c WHERE Id = :targetId LIMIT 1
        ];
        if (t.Target_Criteria__c == null) {
            throw new AuraHandledException('This target has no Target Criteria assigned.');
        }

        Target_Criteria__c crit = [
            SELECT Id, Object__c, Operator__c, Field__c, Date_Field__c, User_Field__c,
                   Filters__c, Filter_Logic__c, Distinct_Field__c, Numerator_Field__c,
                   Denominator_Field__c, Use_Attendance_Divisor__c, Secondary_Source_Objects__c
            FROM Target_Criteria__c WHERE Id = :t.Target_Criteria__c LIMIT 1
        ];

        Set<Id> userIds = new Set<Id>();
        if (t.User__c != null) userIds.add(t.User__c);
        Map<Id, Integer> workingDays = TAM_AttendanceService.getWorkingDays(userIds, t.Start_Date__c, t.End_Date__c);

        Map<Id, Decimal> res = TAM_CalculationEngine_Service.compute(
            crit, new List<Secondary_Target__c>{ t }, t.Start_Date__c, t.End_Date__c, workingDays
        );

        Decimal newVal = res.containsKey(t.Id) ? res.get(t.Id) : 0;
        Decimal oldVal = (t.Achievement_Value__c != null) ? t.Achievement_Value__c : 0;
        Decimal target = (t.Target_Value__c != null) ? t.Target_Value__c : 0;

        t.Daily_Achievement__c = newVal - oldVal;
        t.Achievement_Value__c = newVal;
        t.Achievement_Percent__c = (target != 0) ? (newVal / target * 100).setScale(2, System.RoundingMode.HALF_UP) : 0;
        t.Pending_Target__c = target - newVal;
        t.Working_Days__c = (t.User__c != null && workingDays.containsKey(t.User__c)) ? workingDays.get(t.User__c) : 0;
        t.Last_Updated__c = System.now();
        update t;

        return t;
    }
}
