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
        // Date sanity checks.
        if (target.Start_Date__c != null && target.End_Date__c != null
            && target.End_Date__c < target.Start_Date__c) {
            throw new AuraHandledException('End Date cannot be before Start Date.');
        }
        if (target.Id == null && target.End_Date__c != null) {
            // Block creating a target that's already over. The Start Date is free to
            // sit in the past so quarterly / annual targets (e.g. FY26 starting 1 Apr,
            // created mid-year) still work — the target just has to extend to today
            // or later.
            Date today = Date.today();
            if (target.End_Date__c < today) {
                throw new AuraHandledException(
                    'End Date cannot be in the past. The target must extend to ' + today.format() + ' or later.'
                );
            }
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
                if (existingTargetId == null) {
                    Date today = Date.today();
                    if (endD < today) {
                        throw new IllegalArgumentException(
                            'End Date "' + r.endDate + '" is in the past. The target must extend to ' + today.format() + ' or later.'
                        );
                    }
                }

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
        // Per-day data for DAILY_UNIQUE_AVG / DAILY_LINES_PER_ORDER so QA can see
        // how each day's number rolls up into the final value.
        @AuraEnabled public List<DayRow> perDay;
        @AuraEnabled public String formula;
    }

    public class DayRow {
        @AuraEnabled public String day;       // formatted date
        @AuraEnabled public Integer count1;   // lines (TLSD) / distinct outlets (TC/PC)
        @AuraEnabled public Integer count2;   // distinct orders (TLSD), unused otherwise
        @AuraEnabled public Decimal value;    // ratio (TLSD), count (TC/PC)
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
                   Distinct_Field__c, Use_Attendance_Divisor__c, Filters__c, Filter_Logic__c,
                   Secondary_Source_Objects__c
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

    private static Date safeToDate(Object raw) {
        if (raw == null) return null;
        if (raw instanceof Datetime) return ((Datetime) raw).date();
        return (Date) raw;
    }

    // Read a (possibly dot-traversed) field from an SObject, e.g. Order__r.Order_Date__c.
    private static Object readField(SObject row, String field) {
        if (row == null || String.isBlank(field)) return null;
        if (!field.contains('.')) return row.get(field);
        SObject cur = row;
        List<String> parts = field.split('\\.');
        for (Integer i = 0; i < parts.size() - 1; i++) {
            if (cur == null) return null;
            cur = cur.getSObject(parts[i]);
        }
        return cur == null ? null : cur.get(parts[parts.size() - 1]);
    }

    private static Decimal toDecimal(Object o) {
        if (o == null) return 0;
        if (o instanceof Decimal) return (Decimal) o;
        if (o instanceof Integer) return (Integer) o;
        if (o instanceof Long) return (Long) o;
        if (o instanceof Double) return Decimal.valueOf((Double) o);
        return Decimal.valueOf(String.valueOf(o));
    }

    private static void explainPeriodAggregate(Secondary_Target__c t, Target_Criteria__c crit, AchievementExplanation x) {
        Date startDate = t.Start_Date__c;
        Date endDate = t.End_Date__c;
        Set<String> userKeys = buildUserKeys(t.User__c);

        // Raw rows — aggregates in Apex. Cross-object relationship paths work in
        // raw SELECT WHERE but not always in COUNT(Id)/SUM() aggregate WHERE.
        List<String> selectFields = new List<String>();
        if (crit.Operator__c == 'SUM' && String.isNotBlank(crit.Field__c)) selectFields.add(crit.Field__c);
        if (crit.Operator__c == 'COUNT_DISTINCT' && String.isNotBlank(crit.Distinct_Field__c)) selectFields.add(crit.Distinct_Field__c);
        if (selectFields.isEmpty()) selectFields.add('Id');

        String soql = 'SELECT ' + String.join(selectFields, ', ') +
            ' FROM ' + crit.Object__c +
            ' WHERE ' + buildBaseWhere(crit, startDate, endDate, true);
        List<SObject> rows = Database.query(soql);
        Integer rowCount = rows.size();
        x.steps.add(new KV('Rows matched', String.valueOf(rowCount)));

        if (crit.Operator__c == 'SUM' && String.isNotBlank(crit.Field__c)) {
            Decimal total = 0;
            for (SObject r : rows) total += toDecimal(readField(r, crit.Field__c));
            x.steps.add(new KV('Sum field', crit.Field__c));
            x.steps.add(new KV('SUM(' + crit.Field__c + ')', String.valueOf(total)));
            x.formula = 'SUM(' + crit.Field__c + ') over ' + rowCount + ' matched rows = ' + total;
        } else if (crit.Operator__c == 'COUNT_DISTINCT' && String.isNotBlank(crit.Distinct_Field__c)) {
            Set<String> distinctVals = new Set<String>();
            for (SObject r : rows) {
                Object v = readField(r, crit.Distinct_Field__c);
                if (v != null) distinctVals.add(String.valueOf(v));
            }
            x.steps.add(new KV('Distinct field', crit.Distinct_Field__c));
            x.steps.add(new KV('COUNT_DISTINCT', String.valueOf(distinctVals.size())));
            x.formula = 'COUNT_DISTINCT(' + crit.Distinct_Field__c + ') over ' + rowCount + ' matched rows = ' + distinctVals.size();
        } else if (crit.Operator__c == 'COUNT') {
            x.formula = 'COUNT(Id) = ' + rowCount;
        }
    }

    private static void explainDailyOperator(Secondary_Target__c t, Target_Criteria__c crit, AchievementExplanation x) {
        Date startDate = t.Start_Date__c;
        Date endDate = t.End_Date__c;
        Set<String> userKeys = buildUserKeys(t.User__c);
        String op = crit.Operator__c;

        x.steps.add(new KV('Divisor type',
            crit.Use_Attendance_Divisor__c == true ? 'Working days (attendance)' : 'Active days (days with data)'));

        if (op == 'DAILY_LINES_PER_ORDER') {
            String orderField = crit.Distinct_Field__c;
            if (String.isBlank(orderField)) {
                x.steps.add(new KV('Result', String.valueOf(x.achievementValue)));
                return;
            }
            // Pull raw rows and aggregate per day
            String soql = 'SELECT ' + crit.Date_Field__c + ', ' + orderField +
                ' FROM ' + crit.Object__c +
                ' WHERE ' + buildBaseWhere(crit, startDate, endDate, true);
            Map<Date, Integer> linesByDay = new Map<Date, Integer>();
            Map<Date, Set<String>> ordersByDay = new Map<Date, Set<String>>();
            for (SObject row : Database.query(soql)) {
                Date d = safeToDate(readField(row, crit.Date_Field__c));
                if (d == null) continue;
                Object ord = readField(row, orderField);
                if (ord == null) continue;
                if (!linesByDay.containsKey(d)) {
                    linesByDay.put(d, 0);
                    ordersByDay.put(d, new Set<String>());
                }
                linesByDay.put(d, linesByDay.get(d) + 1);
                ordersByDay.get(d).add(String.valueOf(ord));
            }

            List<Date> sortedDays = new List<Date>(linesByDay.keySet());
            sortedDays.sort();
            Decimal sumRatios = 0;
            x.perDay = new List<DayRow>();
            for (Date d : sortedDays) {
                Integer lines = linesByDay.get(d);
                Integer orders = ordersByDay.get(d).size();
                Decimal ratio = orders > 0 ? (Decimal.valueOf(lines) / orders).setScale(2, System.RoundingMode.HALF_UP) : 0;
                sumRatios += ratio;
                DayRow dr = new DayRow();
                dr.day = String.valueOf(d);
                dr.count1 = lines;
                dr.count2 = orders;
                dr.value = ratio;
                x.perDay.add(dr);
            }
            Integer divisor = (crit.Use_Attendance_Divisor__c == true)
                ? (x.workingDays == null ? 0 : x.workingDays)
                : sortedDays.size();
            Decimal result = divisor > 0 ? (sumRatios / divisor).setScale(2, System.RoundingMode.HALF_UP) : 0;
            x.steps.add(new KV('Sum of daily ratios', String.valueOf(sumRatios.setScale(2, System.RoundingMode.HALF_UP))));
            x.steps.add(new KV('Divisor', String.valueOf(divisor)));
            x.formula = sumRatios.setScale(2, System.RoundingMode.HALF_UP) + ' ÷ ' + divisor + ' = ' + result;
        } else if (op == 'DAILY_UNIQUE_AVG') {
            // Build distinct (day, outlet) tuples — also union secondary sources.
            Set<String> tuples = new Set<String>();
            Map<Date, Set<String>> outletsByDay = new Map<Date, Set<String>>();
            String distinctField = crit.Distinct_Field__c;
            if (String.isNotBlank(distinctField)) {
                String soql = 'SELECT ' + crit.Date_Field__c + ', ' + distinctField +
                    ' FROM ' + crit.Object__c +
                    ' WHERE ' + buildBaseWhere(crit, startDate, endDate, true);
                for (SObject row : Database.query(soql)) {
                    Date d = safeToDate(readField(row, crit.Date_Field__c));
                    Object outlet = readField(row, distinctField);
                    if (d == null || outlet == null) continue;
                    String key = String.valueOf(d) + '|' + String.valueOf(outlet);
                    tuples.add(key);
                    if (!outletsByDay.containsKey(d)) outletsByDay.put(d, new Set<String>());
                    outletsByDay.get(d).add(String.valueOf(outlet));
                }
                // Secondary source objects (Visit__c, Visit_Form__c, etc.)
                if (String.isNotBlank(crit.Secondary_Source_Objects__c)) {
                    try {
                        List<Object> srcs = (List<Object>) JSON.deserializeUntyped(crit.Secondary_Source_Objects__c);
                        for (Object o : srcs) {
                            Map<String, Object> s = (Map<String, Object>) o;
                            String sObj = String.valueOf(s.get('object'));
                            String sUF = String.valueOf(s.get('userField'));
                            String sDF = String.valueOf(s.get('dateField'));
                            String sDist = String.valueOf(s.get('distinctField'));
                            if (String.isBlank(sObj) || String.isBlank(sUF) || String.isBlank(sDF) || String.isBlank(sDist)) continue;
                            String soql2 = 'SELECT ' + sDF + ', ' + sDist +
                                ' FROM ' + sObj +
                                ' WHERE ' + sDF + ' >= :startDate AND ' + sDF + ' <= :endDate AND ' + sUF + ' IN :userKeys';
                            for (SObject row : Database.query(soql2)) {
                                Date d = safeToDate(readField(row, sDF));
                                Object outlet = readField(row, sDist);
                                if (d == null || outlet == null) continue;
                                String key = String.valueOf(d) + '|' + String.valueOf(outlet);
                                tuples.add(key);
                                if (!outletsByDay.containsKey(d)) outletsByDay.put(d, new Set<String>());
                                outletsByDay.get(d).add(String.valueOf(outlet));
                            }
                        }
                    } catch (Exception ignored) { /* malformed source JSON — skip */ }
                }
            }
            List<Date> sortedDays = new List<Date>(outletsByDay.keySet());
            sortedDays.sort();
            x.perDay = new List<DayRow>();
            for (Date d : sortedDays) {
                DayRow dr = new DayRow();
                dr.day = String.valueOf(d);
                dr.count1 = outletsByDay.get(d).size();
                dr.value = dr.count1;
                x.perDay.add(dr);
            }
            Integer divisor = (crit.Use_Attendance_Divisor__c == true)
                ? (x.workingDays == null ? 0 : x.workingDays)
                : sortedDays.size();
            Integer totalTuples = tuples.size();
            Decimal result = divisor > 0 ? (Decimal.valueOf(totalTuples) / divisor).setScale(2, System.RoundingMode.HALF_UP) : 0;
            x.steps.add(new KV('Distinct (day, outlet) tuples', String.valueOf(totalTuples)));
            x.steps.add(new KV('Divisor', String.valueOf(divisor)));
            x.formula = totalTuples + ' ÷ ' + divisor + ' = ' + result;
        }
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

        Integer lineCount = Database.query('SELECT Id FROM Order_Item__c WHERE ' + baseWhere).size();
        x.steps.add(new KV('Pack-SKU line items in period', String.valueOf(lineCount)));

        if (crit.Operator__c == 'FOCUS_PACK_REVENUE') {
            String valueField = String.isNotBlank(crit.Field__c) ? crit.Field__c : 'Non_Taxable_Order_Value__c';
            String revSoql = 'SELECT ' + valueField + ' FROM Order_Item__c WHERE ' + baseWhere;
            Decimal v = 0;
            for (SObject oi : Database.query(revSoql)) v += toDecimal(readField(oi, valueField));
            x.steps.add(new KV('Value field', valueField));
            x.steps.add(new KV('SUM(' + valueField + ')', String.valueOf(v)));
            x.formula = 'SUM(' + valueField + ') over pack-SKU lines = ' + v;
        } else {
            String qtyField = String.isNotBlank(crit.Field__c) ? crit.Field__c : 'Quantity__c';
            String outletField = String.isNotBlank(crit.Distinct_Field__c) ? crit.Distinct_Field__c : 'Account__c';
            x.steps.add(new KV('Quantity field', qtyField));
            x.steps.add(new KV('Outlet field', outletField));
            x.steps.add(new KV('Minimum qualifying quantity', String.valueOf(x.minQualifyingQty)));

            // Group by order / outlet, sum qty, count distinct qualifying outlets
            String soql = 'SELECT Order__c, ' + outletField + ', ' + qtyField + ' FROM Order_Item__c WHERE ' + baseWhere;
            Map<String, Decimal> qtyByKey = new Map<String, Decimal>();
            Map<String, String> outletByKey = new Map<String, String>();
            for (SObject oi : Database.query(soql)) {
                Object outlet = readField(oi, outletField);
                if (outlet == null) continue;
                String key = String.valueOf(oi.get('Order__c')) + '|' + String.valueOf(outlet);
                Decimal q = toDecimal(readField(oi, qtyField));
                qtyByKey.put(key, (qtyByKey.containsKey(key) ? qtyByKey.get(key) : 0) + q);
                outletByKey.put(key, String.valueOf(outlet));
            }
            Decimal minQty = (x.minQualifyingQty == null) ? 0 : x.minQualifyingQty;
            Set<String> qualified = new Set<String>();
            Integer totalOrderOutletGroups = qtyByKey.size();
            for (String key : qtyByKey.keySet()) {
                if (qtyByKey.get(key) >= minQty) qualified.add(outletByKey.get(key));
            }
            x.steps.add(new KV('(order × outlet) groups checked', String.valueOf(totalOrderOutletGroups)));
            x.steps.add(new KV('Distinct qualifying outlets', String.valueOf(qualified.size())));
            x.formula = 'Distinct outlets whose single-order pack-SKU qty ≥ ' + minQty +
                ' = ' + qualified.size();
        }
    }
}