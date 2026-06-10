/**
 * UI controller for the Secondary Targets management console.
 * Handles CRUD on Secondary_Target__c plus on-demand achievement recalculation
 * (single target synchronously, or all active targets via the daily batch).
 */
public with sharing class SecondaryTarget_Controller {

    @AuraEnabled(cacheable=false)
    public static List<Secondary_Target__c> getTargets(String channel, String criteriaId, Boolean activeOnly, String userId) {
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
        if (String.isNotBlank(userId)) wheres.add('User__c = :userId');
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
        // BRD 3.1.1 — block overlapping active duplicates (same user, criteria, pack).
        // A revision should close the old record (Is_Active = false) and create a new one.
        if (target.Is_Active__c == true
            && target.User__c != null
            && target.Target_Criteria__c != null
            && target.Start_Date__c != null
            && target.End_Date__c != null) {

            List<Secondary_Target__c> overlaps = [
                SELECT Id, Name, Focused_Pack__c, Start_Date__c, End_Date__c
                FROM Secondary_Target__c
                WHERE Is_Active__c = true
                  AND User__c = :target.User__c
                  AND Target_Criteria__c = :target.Target_Criteria__c
                  AND Start_Date__c <= :target.End_Date__c
                  AND End_Date__c >= :target.Start_Date__c
            ];
            List<String> conflictNames = new List<String>();
            for (Secondary_Target__c o : overlaps) {
                if (o.Id == target.Id) continue;                       // skip self on edit
                if (o.Focused_Pack__c != target.Focused_Pack__c) continue; // different pack is OK
                conflictNames.add(o.Name);
            }
            if (!conflictNames.isEmpty()) {
                throw new AuraHandledException(
                    'An active Secondary Target already exists for this user, criteria' +
                    (target.Focused_Pack__c != null ? ' and Focus Pack' : '') +
                    ' with an overlapping period: ' + String.join(conflictNames, ', ') +
                    '. Close that target (uncheck Is Active) before creating a new one.'
                );
            }
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
    public static List<Map<String, String>> getChannelOptions() {
        List<Map<String, String>> opts = new List<Map<String, String>>();
        Schema.DescribeFieldResult dfr = Secondary_Target__c.Sales_Channel__c.getDescribe();
        for (Schema.PicklistEntry e : dfr.getPicklistValues()) {
            if (e.isActive()) {
                opts.add(new Map<String, String>{ 'label' => e.getLabel(), 'value' => e.getValue() });
            }
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

    // ===== CSV Import =====

    public class ImportRow {
        @AuraEnabled public String targetId;
        @AuraEnabled public String username;
        @AuraEnabled public String criteriaName;
        @AuraEnabled public String focusPackName;
        @AuraEnabled public String salesChannel;
        @AuraEnabled public Decimal targetYear;
        @AuraEnabled public String startDate;
        @AuraEnabled public String endDate;
        @AuraEnabled public Decimal targetValue;
        @AuraEnabled public Boolean isActive;
    }

    public class ImportResult {
        @AuraEnabled public Integer createdCount = 0;
        @AuraEnabled public Integer updatedCount = 0;
        @AuraEnabled public List<String> errors = new List<String>();
    }

    /**
     * Bulk insert / update of Secondary_Target__c from a CSV-driven UI.
     * Users, criteria, focus packs are resolved by Username / Name (one SOQL each).
     * Rows with a Target Id update the existing record; rows without one insert.
     * Errors are reported per row and the rest are upserted (partial success).
     */
    @AuraEnabled
    public static ImportResult importTargets(List<ImportRow> rows) {
        ImportResult res = new ImportResult();
        if (rows == null || rows.isEmpty()) return res;

        Set<String> usernames = new Set<String>();
        Set<String> critNames = new Set<String>();
        Set<String> packNames = new Set<String>();
        for (ImportRow r : rows) {
            if (String.isNotBlank(r.username)) usernames.add(r.username);
            if (String.isNotBlank(r.criteriaName)) critNames.add(r.criteriaName);
            if (String.isNotBlank(r.focusPackName)) packNames.add(r.focusPackName);
        }

        Map<String, Id> userByLogin = new Map<String, Id>();
        Map<String, Id> userByName = new Map<String, Id>();
        Map<Id, String> userIdToName = new Map<Id, String>();
        for (User u : [SELECT Id, Username, Name FROM User WHERE Username IN :usernames OR Name IN :usernames]) {
            userByLogin.put(u.Username, u.Id);
            userByName.put(u.Name, u.Id);
            userIdToName.put(u.Id, u.Name);
        }
        Map<String, Id> critByName = new Map<String, Id>();
        for (Target_Criteria__c c : [SELECT Id, Name FROM Target_Criteria__c WHERE Name IN :critNames]) {
            critByName.put(c.Name, c.Id);
        }
        Map<String, Id> packByName = new Map<String, Id>();
        for (Focused_Pack__c fp : [SELECT Id, Name FROM Focused_Pack__c WHERE Name IN :packNames]) {
            packByName.put(fp.Name, fp.Id);
        }

        List<Secondary_Target__c> toUpsert = new List<Secondary_Target__c>();
        List<Integer> rowIndexOf = new List<Integer>(); // parallel array for error reporting

        for (Integer i = 0; i < rows.size(); i++) {
            ImportRow r = rows[i];
            Integer rowNum = i + 2; // header is row 1
            try {
                if (String.isBlank(r.username)) throw new IllegalArgumentException('User Username is required.');
                if (String.isBlank(r.criteriaName)) throw new IllegalArgumentException('Criteria Name is required.');
                if (String.isBlank(r.startDate)) throw new IllegalArgumentException('Start Date is required.');
                if (String.isBlank(r.endDate)) throw new IllegalArgumentException('End Date is required.');

                Id userId = userByLogin.get(r.username);
                if (userId == null) userId = userByName.get(r.username);
                if (userId == null) throw new IllegalArgumentException('Unknown User: ' + r.username);

                Id critId = critByName.get(r.criteriaName);
                if (critId == null) throw new IllegalArgumentException('Unknown Criteria: ' + r.criteriaName);

                Id packId = null;
                if (String.isNotBlank(r.focusPackName)) {
                    packId = packByName.get(r.focusPackName);
                    if (packId == null) throw new IllegalArgumentException('Unknown Focus Pack: ' + r.focusPackName);
                }

                Date startD;
                Date endD;
                try { startD = Date.valueOf(r.startDate); }
                catch (Exception e) { throw new IllegalArgumentException('Bad Start Date "' + r.startDate + '" (expected YYYY-MM-DD).'); }
                try { endD = Date.valueOf(r.endDate); }
                catch (Exception e) { throw new IllegalArgumentException('Bad End Date "' + r.endDate + '" (expected YYYY-MM-DD).'); }
                if (endD < startD) throw new IllegalArgumentException('End Date is before Start Date.');

                Secondary_Target__c t = new Secondary_Target__c(
                    User__c = userId,
                    User_Name__c = userIdToName.get(userId),
                    Target_Criteria__c = critId,
                    Focused_Pack__c = packId,
                    Sales_Channel__c = String.isBlank(r.salesChannel) ? null : r.salesChannel,
                    Year__c = r.targetYear,
                    Start_Date__c = startD,
                    End_Date__c = endD,
                    Target_Value__c = r.targetValue,
                    Is_Active__c = r.isActive == true
                );
                if (String.isNotBlank(r.targetId)) t.Id = r.targetId;
                toUpsert.add(t);
                rowIndexOf.add(rowNum);
            } catch (Exception e) {
                res.errors.add('Row ' + rowNum + ': ' + e.getMessage());
            }
        }

        if (!toUpsert.isEmpty()) {
            Database.UpsertResult[] urs = Database.upsert(toUpsert, false);
            for (Integer i = 0; i < urs.size(); i++) {
                Database.UpsertResult u = urs[i];
                if (u.isSuccess()) {
                    if (u.isCreated()) res.createdCount++; else res.updatedCount++;
                } else {
                    String msg = '';
                    for (Database.Error err : u.getErrors()) msg += err.getMessage() + '; ';
                    res.errors.add('Row ' + rowIndexOf[i] + ': ' + msg.removeEnd('; '));
                }
            }
        }
        return res;
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