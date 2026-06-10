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

    // ===== Achievement Breakdown =====

    public class KV {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public KV(String l, String v) { this.label = l; this.value = v; }
    }

    public class AchievementExplanation {
        @AuraEnabled public String targetName;
        @AuraEnabled public String userName;
        @AuraEnabled public String criterionName;
        @AuraEnabled public String operator;
        @AuraEnabled public String sourceObject;
        @AuraEnabled public String dateField;
        @AuraEnabled public String userField;
        @AuraEnabled public String distinctField;
        @AuraEnabled public String focusPackName;
        @AuraEnabled public Decimal minQualifyingQty;
        @AuraEnabled public List<String> filterClauses = new List<String>();
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public Integer workingDays;
        @AuraEnabled public Boolean useAttendance;
        @AuraEnabled public Decimal achievementValue;
        @AuraEnabled public Decimal achievementPercent;
        @AuraEnabled public Decimal targetValue;
        @AuraEnabled public List<KV> steps = new List<KV>();
        @AuraEnabled public List<String> packSkus;
    }

    /**
     * Produces a per-target explanation of *how* the engine arrived at the
     * Achievement_Value__c. Used by the Secondary Target Manager so QA can
     * understand and verify the calculation without diving into Apex logs.
     */
    @AuraEnabled
    public static AchievementExplanation explainAchievement(Id targetId) {
        Secondary_Target__c t = [
            SELECT Id, Name, User__c, User__r.Name, Sales_Channel__c,
                   Target_Criteria__c, Target_Value__c, Achievement_Value__c, Achievement_Percent__c,
                   Focused_Pack__c, Focused_Pack__r.Name, Focused_Pack__r.Minimum_Qualifying_Quantity__c,
                   Start_Date__c, End_Date__c
            FROM Secondary_Target__c WHERE Id = :targetId LIMIT 1
        ];
        Target_Criteria__c crit = [
            SELECT Id, Name, Object__c, Operator__c, Field__c, Date_Field__c, User_Field__c,
                   Distinct_Field__c, Use_Attendance_Divisor__c, Filters__c, Filter_Logic__c
            FROM Target_Criteria__c WHERE Id = :t.Target_Criteria__c LIMIT 1
        ];

        AchievementExplanation x = new AchievementExplanation();
        x.targetName = t.Name;
        x.userName = (t.User__r != null) ? t.User__r.Name : null;
        x.criterionName = crit.Name;
        x.operator = crit.Operator__c;
        x.sourceObject = crit.Object__c;
        x.dateField = crit.Date_Field__c;
        x.userField = crit.User_Field__c;
        x.distinctField = crit.Distinct_Field__c;
        x.focusPackName = (t.Focused_Pack__r != null) ? t.Focused_Pack__r.Name : null;
        x.minQualifyingQty = (t.Focused_Pack__r != null) ? t.Focused_Pack__r.Minimum_Qualifying_Quantity__c : null;
        x.startDate = t.Start_Date__c;
        x.endDate = t.End_Date__c;
        x.useAttendance = (crit.Use_Attendance_Divisor__c == true);
        x.achievementValue = t.Achievement_Value__c;
        x.achievementPercent = t.Achievement_Percent__c;
        x.targetValue = t.Target_Value__c;
        x.filterClauses = describeFilters(crit.Filters__c);

        if (t.User__c != null) {
            Map<Id, Integer> wd = TAM_AttendanceService.getWorkingDays(
                new Set<Id>{ t.User__c }, t.Start_Date__c, t.End_Date__c);
            x.workingDays = wd.containsKey(t.User__c) ? wd.get(t.User__c) : 0;
        }

        String op = crit.Operator__c;
        if (op == 'SUM' || op == 'COUNT' || op == 'COUNT_DISTINCT') {
            explainPeriodAggregate(t, crit, x);
        } else if (op == 'DAILY_UNIQUE_AVG' || op == 'DAILY_LINES_PER_ORDER') {
            explainDailyOperator(t, crit, x);
        } else if (op == 'FOCUS_PACK_REVENUE' || op == 'FOCUS_PACK_ECO') {
            explainFocusPack(t, crit, x);
        }
        return x;
    }

    // ---- helpers ----

    private static List<String> describeFilters(String filtersJson) {
        List<String> out = new List<String>();
        if (String.isBlank(filtersJson)) return out;
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(filtersJson);
            List<Object> rows = (List<Object>) root.get('filters');
            if (rows == null) return out;
            for (Object r : rows) {
                Map<String, Object> f = (Map<String, Object>) r;
                String fld = String.valueOf(f.get('field'));
                String opr = String.valueOf(f.get('operator'));
                Object val = f.get('value');
                String valStr;
                if (val instanceof List<Object>) {
                    List<String> bits = new List<String>();
                    for (Object o : (List<Object>) val) bits.add(String.valueOf(o));
                    valStr = '[' + String.join(bits, ', ') + ']';
                } else {
                    valStr = '"' + String.valueOf(val) + '"';
                }
                out.add(fld + ' ' + opr + ' ' + valStr);
            }
        } catch (Exception e) {
            out.add('(could not parse filter JSON)');
        }
        return out;
    }

    private static String buildBaseWhere(Target_Criteria__c crit, Date startDate, Date endDate, Boolean userBind) {
        List<String> segs = new List<String>();
        segs.add(crit.Date_Field__c + ' >= :startDate');
        segs.add(crit.Date_Field__c + ' <= :endDate');
        if (userBind) segs.add(crit.User_Field__c + ' IN :userKeys');
        String extra = TAM_FilterEngine_Service.buildWhereClause(crit.Filters__c, crit.Filter_Logic__c);
        if (String.isNotBlank(extra)) segs.add(extra);
        return String.join(segs, ' AND ');
    }

    private static Set<String> buildUserKeys(Id userId) {
        Set<String> keys = new Set<String>();
        if (userId == null) return keys;
        String s = String.valueOf(userId);
        keys.add(s);
        if (s.length() >= 15) keys.add(s.substring(0, 15));
        return keys;
    }

    private static void explainPeriodAggregate(Secondary_Target__c t, Target_Criteria__c crit, AchievementExplanation x) {
        Date startDate = t.Start_Date__c;
        Date endDate = t.End_Date__c;
        Set<String> userKeys = buildUserKeys(t.User__c);
        String soql = 'SELECT Count(Id) cnt FROM ' + crit.Object__c +
            ' WHERE ' + buildBaseWhere(crit, startDate, endDate, true);
        AggregateResult ar = (AggregateResult) Database.query(soql)[0];
        Integer rowCount = (Integer) ar.get('cnt');
        x.steps.add(new KV('Rows matched', String.valueOf(rowCount)));

        if (crit.Operator__c == 'SUM' && String.isNotBlank(crit.Field__c)) {
            String sumSoql = 'SELECT SUM(' + crit.Field__c + ') v FROM ' + crit.Object__c +
                ' WHERE ' + buildBaseWhere(crit, startDate, endDate, true);
            AggregateResult sr = (AggregateResult) Database.query(sumSoql)[0];
            Decimal v = (sr.get('v') != null) ? (Decimal) sr.get('v') : 0;
            x.steps.add(new KV('Sum field', crit.Field__c));
            x.steps.add(new KV('SUM(' + crit.Field__c + ')', String.valueOf(v)));
        } else if (crit.Operator__c == 'COUNT_DISTINCT' && String.isNotBlank(crit.Distinct_Field__c)) {
            String dSoql = 'SELECT COUNT_DISTINCT(' + crit.Distinct_Field__c + ') v FROM ' + crit.Object__c +
                ' WHERE ' + buildBaseWhere(crit, startDate, endDate, true);
            AggregateResult dr = (AggregateResult) Database.query(dSoql)[0];
            Integer dc = (dr.get('v') != null) ? (Integer) dr.get('v') : 0;
            x.steps.add(new KV('Distinct field', crit.Distinct_Field__c));
            x.steps.add(new KV('COUNT_DISTINCT', String.valueOf(dc)));
        }
    }

    private static void explainDailyOperator(Secondary_Target__c t, Target_Criteria__c crit, AchievementExplanation x) {
        Integer divisor = (crit.Use_Attendance_Divisor__c == true)
            ? (x.workingDays == null ? 0 : x.workingDays)
            : null;
        x.steps.add(new KV('Divisor type', crit.Use_Attendance_Divisor__c == true ? 'Working days (attendance)' : 'Active days (days with data)'));
        if (divisor != null) x.steps.add(new KV('Working days', String.valueOf(divisor)));
        // Count the rows the engine evaluates so QA can sanity check
        Date startDate = t.Start_Date__c;
        Date endDate = t.End_Date__c;
        Set<String> userKeys = buildUserKeys(t.User__c);
        String soql = 'SELECT Count(Id) cnt FROM ' + crit.Object__c +
            ' WHERE ' + buildBaseWhere(crit, startDate, endDate, true);
        AggregateResult ar = (AggregateResult) Database.query(soql)[0];
        x.steps.add(new KV('Source rows in period', String.valueOf(ar.get('cnt'))));
        if (String.isNotBlank(crit.Distinct_Field__c)) {
            x.steps.add(new KV(crit.Operator__c == 'DAILY_LINES_PER_ORDER' ? 'Order field' : 'Distinct field', crit.Distinct_Field__c));
        }
        x.steps.add(new KV('Result', String.valueOf(x.achievementValue)));
    }

    private static void explainFocusPack(Secondary_Target__c t, Target_Criteria__c crit, AchievementExplanation x) {
        x.packSkus = new List<String>();
        if (t.Focused_Pack__c == null) {
            x.steps.add(new KV('Note', 'No Focus Pack linked on this target.'));
            return;
        }
        Set<Id> skuIds = new Set<Id>();
        for (Focused_Pack_Item__c fpi : [SELECT SKU__c, SKU__r.Name FROM Focused_Pack_Item__c
                                          WHERE Focused_Pack__c = :t.Focused_Pack__c AND SKU__c != null]) {
            skuIds.add(fpi.SKU__c);
            if (fpi.SKU__r != null) x.packSkus.add(fpi.SKU__r.Name);
        }
        x.steps.add(new KV('Pack SKUs', String.valueOf(skuIds.size())));
        if (skuIds.isEmpty()) {
            x.steps.add(new KV('Note', 'Pack has no SKU line items.'));
            return;
        }
        Date startDate = t.Start_Date__c;
        Date endDate = t.End_Date__c;
        Set<String> userKeys = buildUserKeys(t.User__c);
        String userField = String.isNotBlank(crit.User_Field__c) ? crit.User_Field__c : 'Order_Owner_Id__c';
        String dateField = String.isNotBlank(crit.Date_Field__c) ? crit.Date_Field__c : 'Order_Date__c';
        String baseWhere = 'Product__c IN :skuIds AND ' + dateField + ' >= :startDate AND ' + dateField + ' <= :endDate AND ' + userField + ' IN :userKeys';
        String extra = TAM_FilterEngine_Service.buildWhereClause(crit.Filters__c, crit.Filter_Logic__c);
        if (String.isNotBlank(extra)) baseWhere += ' AND ' + extra;

        AggregateResult ar = (AggregateResult) Database.query('SELECT Count(Id) cnt FROM Order_Item__c WHERE ' + baseWhere)[0];
        x.steps.add(new KV('Pack-SKU line items in period', String.valueOf(ar.get('cnt'))));

        if (crit.Operator__c == 'FOCUS_PACK_REVENUE') {
            String valueField = String.isNotBlank(crit.Field__c) ? crit.Field__c : 'Non_Taxable_Order_Value__c';
            String sumSoql = 'SELECT SUM(' + valueField + ') v FROM Order_Item__c WHERE ' + baseWhere;
            AggregateResult sr = (AggregateResult) Database.query(sumSoql)[0];
            Decimal v = (sr.get('v') != null) ? (Decimal) sr.get('v') : 0;
            x.steps.add(new KV('Value field', valueField));
            x.steps.add(new KV('SUM(' + valueField + ')', String.valueOf(v)));
        } else {
            String qtyField = String.isNotBlank(crit.Field__c) ? crit.Field__c : 'Quantity__c';
            String outletField = String.isNotBlank(crit.Distinct_Field__c) ? crit.Distinct_Field__c : 'Account__c';
            x.steps.add(new KV('Quantity field', qtyField));
            x.steps.add(new KV('Outlet field', outletField));
            x.steps.add(new KV('Minimum qualifying quantity', String.valueOf(x.minQualifyingQty)));
        }
    }
}
