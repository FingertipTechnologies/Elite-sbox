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
        @AuraEnabled public String targetName;       // e.g. STGT-0033 (blank = insert)
        @AuraEnabled public String employeeCode;     // User.Employee_Code__c
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
     * Users are resolved by Employee_Code__c, criteria and focus packs by Name,
     * and the existing record (for updates) by its Name (e.g. STGT-0033).
     * Rows with a Target Name update the existing record; rows without one insert.
     * Errors are reported per row and the rest are upserted (partial success).
     */
    @AuraEnabled
    public static ImportResult importTargets(String rowsJson) {
        ImportResult res = new ImportResult();
        if (String.isBlank(rowsJson)) return res;
        // Deserialize manually — @AuraEnabled with a List<CustomClass> parameter is
        // unreliable across LWC ↔ Apex (inner property names don't always map).
        List<ImportRow> rows;
        try {
            rows = (List<ImportRow>) JSON.deserialize(rowsJson, List<ImportRow>.class);
        } catch (Exception e) {
            throw new AuraHandledException('Could not parse import payload: ' + e.getMessage());
        }
        if (rows == null || rows.isEmpty()) return res;

        Set<String> empCodes = new Set<String>();
        Set<String> critNames = new Set<String>();
        Set<String> packNames = new Set<String>();
        Set<String> targetNames = new Set<String>();
        for (ImportRow r : rows) {
            if (String.isNotBlank(r.employeeCode)) empCodes.add(r.employeeCode);
            if (String.isNotBlank(r.criteriaName)) critNames.add(r.criteriaName);
            if (String.isNotBlank(r.focusPackName)) packNames.add(r.focusPackName);
            if (String.isNotBlank(r.targetName)) targetNames.add(r.targetName);
        }

        // Resolve lookups by key. If a key matches more than one record (duplicate
        // Names / Employee Codes), flag it as ambiguous and surface a clear error
        // per row instead of silently picking one.
        Map<String, Id> userByCode = new Map<String, Id>();
        Set<String> ambiguousEmp = new Set<String>();
        Map<Id, String> userIdToName = new Map<Id, String>();
        for (User u : [SELECT Id, Name, Employee_Code__c FROM User
                       WHERE Employee_Code__c IN :empCodes AND Employee_Code__c != null]) {
            if (userByCode.containsKey(u.Employee_Code__c)) ambiguousEmp.add(u.Employee_Code__c);
            else userByCode.put(u.Employee_Code__c, u.Id);
            userIdToName.put(u.Id, u.Name);
        }
        for (String code : ambiguousEmp) userByCode.remove(code);

        Map<String, Id> critByName = new Map<String, Id>();
        Set<String> ambiguousCrit = new Set<String>();
        for (Target_Criteria__c c : [SELECT Id, Name FROM Target_Criteria__c WHERE Name IN :critNames]) {
            if (critByName.containsKey(c.Name)) ambiguousCrit.add(c.Name);
            else critByName.put(c.Name, c.Id);
        }
        for (String n : ambiguousCrit) critByName.remove(n);

        Map<String, Id> packByName = new Map<String, Id>();
        Set<String> ambiguousPack = new Set<String>();
        for (Focused_Pack__c fp : [SELECT Id, Name FROM Focused_Pack__c WHERE Name IN :packNames]) {
            if (packByName.containsKey(fp.Name)) ambiguousPack.add(fp.Name);
            else packByName.put(fp.Name, fp.Id);
        }
        for (String n : ambiguousPack) packByName.remove(n);

        Map<String, Id> targetByName = new Map<String, Id>();
        for (Secondary_Target__c t : [SELECT Id, Name FROM Secondary_Target__c WHERE Name IN :targetNames]) {
            targetByName.put(t.Name, t.Id);
        }

        List<Secondary_Target__c> toUpsert = new List<Secondary_Target__c>();
        List<Integer> rowIndexOf = new List<Integer>();

        for (Integer i = 0; i < rows.size(); i++) {
            ImportRow r = rows[i];
            Integer rowNum = i + 2; // header is row 1
            try {
                if (String.isBlank(r.employeeCode)) throw new IllegalArgumentException('User Employee Code is required.');
                if (String.isBlank(r.criteriaName)) throw new IllegalArgumentException('Criteria Name is required.');
                if (String.isBlank(r.startDate)) throw new IllegalArgumentException('Start Date is required.');
                if (String.isBlank(r.endDate)) throw new IllegalArgumentException('End Date is required.');

                if (ambiguousEmp.contains(r.employeeCode)) {
                    throw new IllegalArgumentException('Employee Code "' + r.employeeCode + '" is used by more than one user; resolve the duplicate before importing.');
                }
                Id userId = userByCode.get(r.employeeCode);
                if (userId == null) throw new IllegalArgumentException('Unknown Employee Code: ' + r.employeeCode);

                if (ambiguousCrit.contains(r.criteriaName)) {
                    throw new IllegalArgumentException('Criteria Name "' + r.criteriaName + '" matches more than one record; rename the duplicate(s) before importing.');
                }
                Id critId = critByName.get(r.criteriaName);
                if (critId == null) throw new IllegalArgumentException('Unknown Criteria: ' + r.criteriaName);

                Id packId = null;
                if (String.isNotBlank(r.focusPackName)) {
                    if (ambiguousPack.contains(r.focusPackName)) {
                        throw new IllegalArgumentException('Focus Pack Name "' + r.focusPackName + '" matches more than one pack; rename the duplicate(s) before importing.');
                    }
                    packId = packByName.get(r.focusPackName);
                    if (packId == null) throw new IllegalArgumentException('Unknown Focus Pack: ' + r.focusPackName);
                }

                Id existingTargetId = null;
                if (String.isNotBlank(r.targetName)) {
                    existingTargetId = targetByName.get(r.targetName);
                    if (existingTargetId == null) throw new IllegalArgumentException('Unknown Target: ' + r.targetName);
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
                if (existingTargetId != null) t.Id = existingTargetId;
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
