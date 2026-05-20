/**
 * Config-driven achievement engine for the Secondary Targets module.
 * One Target_Criteria__c describes a BRD parameter via its Operator__c; this
 * service computes the achievement value per Secondary_Target__c for a period.
 *
 *   SUM / COUNT          - period total per user (Cumulative Secondary Revenue).
 *   COUNT_DISTINCT       - distinct outlets in period per user (UBO / ECO).
 *   DAILY_UNIQUE_AVG     - distinct (day, outlet) tuples / divisor (TC, PC),
 *                          deduped across the unioned secondary source objects.
 *   DAILY_RATIO_AVG      - average of daily numerator/denominator ratios (Avg TLSD).
 *   FOCUS_PACK_REVENUE   - secondary revenue of Focus-Pack SKUs.
 *   FOCUS_PACK_ECO       - distinct outlets where one order met the pack min qty.
 *
 * Daily averages divide by attendance working days when Use_Attendance_Divisor__c
 * is set, otherwise by the user's number of active days in the period.
 */
public without sharing class TAM_CalculationEngine_Service {

    private static final String SECONDARY_ORDER = 'Secondary Order';

    /**
     * Returns achievement value keyed by Secondary_Target__c Id.
     * workingDaysByUser may be null; it is only required for attendance-based divisors.
     */
    public static Map<Id, Decimal> compute(
        Target_Criteria__c crit,
        List<Secondary_Target__c> targets,
        Date startDate,
        Date endDate,
        Map<Id, Integer> workingDaysByUser
    ) {
        Map<Id, Decimal> resultByTarget = new Map<Id, Decimal>();
        if (crit == null || targets == null || targets.isEmpty()) return resultByTarget;
        if (workingDaysByUser == null) workingDaysByUser = new Map<Id, Integer>();

        String op = crit.Operator__c;

        if (op == 'FOCUS_PACK_REVENUE' || op == 'FOCUS_PACK_ECO') {
            return computeFocusPack(crit, targets, startDate, endDate);
        }

        Set<Id> userIds = new Set<Id>();
        for (Secondary_Target__c t : targets) {
            if (t.User__c != null) userIds.add(t.User__c);
        }
        if (userIds.isEmpty()) return resultByTarget;

        Map<Id, Decimal> perUser = computePerUser(crit, userIds, startDate, endDate, workingDaysByUser);

        for (Secondary_Target__c t : targets) {
            resultByTarget.put(t.Id, perUser.containsKey(t.User__c) ? perUser.get(t.User__c) : 0);
        }
        return resultByTarget;
    }

    /**
     * Per-user achievement for the non Focus-Pack operators. Exposed so previews
     * can run without persisted Secondary_Target__c rows.
     */
    public static Map<Id, Decimal> computePerUser(
        Target_Criteria__c crit, Set<Id> userIds, Date startDate, Date endDate,
        Map<Id, Integer> workingDaysByUser
    ) {
        if (workingDaysByUser == null) workingDaysByUser = new Map<Id, Integer>();
        if (userIds == null || userIds.isEmpty()) return new Map<Id, Decimal>();
        String op = crit.Operator__c;
        if (op == 'DAILY_UNIQUE_AVG') {
            return computeDailyUniqueAvg(crit, userIds, startDate, endDate, workingDaysByUser);
        } else if (op == 'DAILY_RATIO_AVG') {
            return computeDailyRatioAvg(crit, userIds, startDate, endDate, workingDaysByUser);
        }
        return computePeriodAggregate(crit, userIds, startDate, endDate);
    }

    // ---- SUM / COUNT / COUNT_DISTINCT ------------------------------------
    // Raw rows aggregated in Apex so a formula User Field (e.g. Order_Owner_Id__c)
    // does not need to be GROUP BY-able in SOQL.
    private static Map<Id, Decimal> computePeriodAggregate(
        Target_Criteria__c crit, Set<Id> userIds, Date startDate, Date endDate
    ) {
        Map<Id, Decimal> perUser = new Map<Id, Decimal>();
        Map<String, Id> keyToUser = buildKeyToUser(userIds);
        Set<String> userKeys = keyToUser.keySet();
        String op = crit.Operator__c;

        List<String> selectFields = new List<String>{ crit.User_Field__c };
        if (op == 'SUM') selectFields.add(crit.Field__c);
        if (op == 'COUNT_DISTINCT') selectFields.add(crit.Distinct_Field__c);

        String soql = 'SELECT ' + String.join(selectFields, ', ') +
            ' FROM ' + crit.Object__c + ' WHERE ' + buildBaseWhere(crit, true);

        Map<Id, Decimal> sumByUser = new Map<Id, Decimal>();
        Map<Id, Set<String>> distinctByUser = new Map<Id, Set<String>>();

        for (SObject row : Database.query(soql)) {
            Id uid = resolveUserId(row.get(crit.User_Field__c), keyToUser);
            if (uid == null) continue;
            if (op == 'SUM') {
                sumByUser.put(uid, (sumByUser.containsKey(uid) ? sumByUser.get(uid) : 0) + toDecimal(row.get(crit.Field__c)));
            } else if (op == 'COUNT_DISTINCT') {
                Object dv = row.get(crit.Distinct_Field__c);
                if (dv == null) continue;
                if (!distinctByUser.containsKey(uid)) distinctByUser.put(uid, new Set<String>());
                distinctByUser.get(uid).add(String.valueOf(dv));
            } else { // COUNT
                sumByUser.put(uid, (sumByUser.containsKey(uid) ? sumByUser.get(uid) : 0) + 1);
            }
        }

        if (op == 'COUNT_DISTINCT') {
            for (Id uid : distinctByUser.keySet()) perUser.put(uid, distinctByUser.get(uid).size());
        } else {
            perUser.putAll(sumByUser);
        }
        return perUser;
    }

    // ---- DAILY_UNIQUE_AVG (TC / PC) --------------------------------------
    private static Map<Id, Decimal> computeDailyUniqueAvg(
        Target_Criteria__c crit, Set<Id> userIds, Date startDate, Date endDate,
        Map<Id, Integer> workingDaysByUser
    ) {
        Map<String, Id> keyToUser = buildKeyToUser(userIds);
        Set<String> userKeys = keyToUser.keySet();

        Map<Id, Set<String>> userTuples = new Map<Id, Set<String>>();
        Map<Id, Set<Date>> userActiveDays = new Map<Id, Set<Date>>();

        List<SourceDef> sources = new List<SourceDef>();
        sources.add(new SourceDef(crit.Object__c, crit.User_Field__c, crit.Date_Field__c, crit.Distinct_Field__c, crit.Filters__c, crit.Filter_Logic__c));
        sources.addAll(parseSecondarySources(crit.Secondary_Source_Objects__c));

        // Raw rows (no GROUP BY) so date-time source fields like CreatedDate are
        // supported and cross-source dedup of (day, outlet) happens in Apex.
        for (SourceDef s : sources) {
            String soql = 'SELECT ' + s.userField + ', ' + s.dateField + ', ' + s.distinctField +
                ' FROM ' + s.objectName +
                ' WHERE ' + buildSourceWhere(s, true);

            for (SObject row : Database.query(soql)) {
                Id uid = resolveUserId(row.get(s.userField), keyToUser);
                if (uid == null) continue;
                Date d = toDate(row.get(s.dateField));
                Object outlet = row.get(s.distinctField);
                if (d == null || outlet == null) continue;
                if (!userTuples.containsKey(uid)) {
                    userTuples.put(uid, new Set<String>());
                    userActiveDays.put(uid, new Set<Date>());
                }
                userTuples.get(uid).add(String.valueOf(d) + '|' + String.valueOf(outlet));
                userActiveDays.get(uid).add(d);
            }
        }

        Map<Id, Decimal> perUser = new Map<Id, Decimal>();
        for (Id uid : userTuples.keySet()) {
            Decimal total = userTuples.get(uid).size();
            Integer divisor = resolveDivisor(crit, uid, userActiveDays.get(uid), workingDaysByUser);
            perUser.put(uid, divisor > 0 ? (total / divisor).setScale(2, System.RoundingMode.HALF_UP) : 0);
        }
        return perUser;
    }

    // ---- DAILY_RATIO_AVG (Average TLSD) ----------------------------------
    private static Map<Id, Decimal> computeDailyRatioAvg(
        Target_Criteria__c crit, Set<Id> userIds, Date startDate, Date endDate,
        Map<Id, Integer> workingDaysByUser
    ) {
        Map<String, Id> keyToUser = buildKeyToUser(userIds);
        Set<String> userKeys = keyToUser.keySet();

        // Raw rows summed per (user, day) in Apex, then daily ratios averaged.
        String soql = 'SELECT ' + crit.User_Field__c + ', ' + crit.Date_Field__c + ', ' +
            crit.Numerator_Field__c + ', ' + crit.Denominator_Field__c +
            ' FROM ' + crit.Object__c +
            ' WHERE ' + buildBaseWhere(crit, true);

        Map<Id, Map<Date, Decimal>> numByUserDay = new Map<Id, Map<Date, Decimal>>();
        Map<Id, Map<Date, Decimal>> denByUserDay = new Map<Id, Map<Date, Decimal>>();

        for (SObject row : Database.query(soql)) {
            Id uid = resolveUserId(row.get(crit.User_Field__c), keyToUser);
            if (uid == null) continue;
            Date d = toDate(row.get(crit.Date_Field__c));
            if (d == null) continue;
            Decimal num = toDecimal(row.get(crit.Numerator_Field__c));
            Decimal den = toDecimal(row.get(crit.Denominator_Field__c));
            if (!numByUserDay.containsKey(uid)) {
                numByUserDay.put(uid, new Map<Date, Decimal>());
                denByUserDay.put(uid, new Map<Date, Decimal>());
            }
            Map<Date, Decimal> nMap = numByUserDay.get(uid);
            Map<Date, Decimal> dMap = denByUserDay.get(uid);
            nMap.put(d, (nMap.containsKey(d) ? nMap.get(d) : 0) + num);
            dMap.put(d, (dMap.containsKey(d) ? dMap.get(d) : 0) + den);
        }

        Map<Id, Decimal> perUser = new Map<Id, Decimal>();
        for (Id uid : numByUserDay.keySet()) {
            Map<Date, Decimal> nMap = numByUserDay.get(uid);
            Map<Date, Decimal> dMap = denByUserDay.get(uid);
            Decimal ratioSum = 0;
            for (Date d : nMap.keySet()) {
                Decimal den = dMap.get(d);
                if (den != null && den != 0) ratioSum += nMap.get(d) / den;
            }
            Integer divisor = resolveDivisor(crit, uid, nMap.keySet(), workingDaysByUser);
            perUser.put(uid, divisor > 0 ? (ratioSum / divisor).setScale(2, System.RoundingMode.HALF_UP) : 0);
        }
        return perUser;
    }

    // ---- FOCUS_PACK_REVENUE / FOCUS_PACK_ECO -----------------------------
    private static Map<Id, Decimal> computeFocusPack(
        Target_Criteria__c crit, List<Secondary_Target__c> targets, Date startDate, Date endDate
    ) {
        Map<Id, Decimal> resultByTarget = new Map<Id, Decimal>();

        Map<Id, List<Secondary_Target__c>> targetsByPack = new Map<Id, List<Secondary_Target__c>>();
        for (Secondary_Target__c t : targets) {
            if (t.Focused_Pack__c == null) { resultByTarget.put(t.Id, 0); continue; }
            if (!targetsByPack.containsKey(t.Focused_Pack__c)) {
                targetsByPack.put(t.Focused_Pack__c, new List<Secondary_Target__c>());
            }
            targetsByPack.get(t.Focused_Pack__c).add(t);
        }
        if (targetsByPack.isEmpty()) return resultByTarget;

        Map<Id, Decimal> minQtyByPack = new Map<Id, Decimal>();
        for (Focused_Pack__c fp : [
            SELECT Id, Minimum_Qualifying_Quantity__c
            FROM Focused_Pack__c WHERE Id IN :targetsByPack.keySet()
        ]) {
            minQtyByPack.put(fp.Id, fp.Minimum_Qualifying_Quantity__c == null ? 0 : fp.Minimum_Qualifying_Quantity__c);
        }

        Map<Id, Set<Id>> skusByPack = new Map<Id, Set<Id>>();
        for (Focused_Pack_Item__c fpi : [
            SELECT Focused_Pack__c, SKU__c
            FROM Focused_Pack_Item__c
            WHERE Focused_Pack__c IN :targetsByPack.keySet() AND SKU__c != NULL
        ]) {
            if (!skusByPack.containsKey(fpi.Focused_Pack__c)) skusByPack.put(fpi.Focused_Pack__c, new Set<Id>());
            skusByPack.get(fpi.Focused_Pack__c).add(fpi.SKU__c);
        }

        Boolean isEco = (crit.Operator__c == 'FOCUS_PACK_ECO');

        for (Id packId : targetsByPack.keySet()) {
            List<Secondary_Target__c> packTargets = targetsByPack.get(packId);
            Set<Id> skuIds = skusByPack.containsKey(packId) ? skusByPack.get(packId) : new Set<Id>();

            Set<Id> userIds = new Set<Id>();
            for (Secondary_Target__c t : packTargets) {
                if (t.User__c != null) userIds.add(t.User__c);
            }

            Map<Id, Decimal> perUser = new Map<Id, Decimal>();
            if (!skuIds.isEmpty() && !userIds.isEmpty()) {
                Map<String, Id> keyToUser = buildKeyToUser(userIds);
                Set<String> userKeys = keyToUser.keySet();
                String secondaryType = SECONDARY_ORDER;

                if (isEco) {
                    Decimal minQty = minQtyByPack.containsKey(packId) ? minQtyByPack.get(packId) : 0;
                    // Sum pack-SKU quantity per (user, order, outlet) in Apex, then qualify.
                    Map<String, Decimal> qtyByKey = new Map<String, Decimal>();
                    Map<String, Id> userByKey = new Map<String, Id>();
                    Map<String, Id> outletByKey = new Map<String, Id>();
                    for (Order_Item__c oi : [
                        SELECT Order_Owner_Id__c, Order__c, Account__c, Quantity__c
                        FROM Order_Item__c
                        WHERE Product__c IN :skuIds
                          AND Order_Type__c = :secondaryType
                          AND Order_Date__c >= :startDate AND Order_Date__c <= :endDate
                          AND Order_Owner_Id__c IN :userKeys
                    ]) {
                        Id uid = resolveUserId(oi.Order_Owner_Id__c, keyToUser);
                        if (uid == null || oi.Account__c == null) continue;
                        String key = uid + '|' + oi.Order__c + '|' + oi.Account__c;
                        qtyByKey.put(key, (qtyByKey.containsKey(key) ? qtyByKey.get(key) : 0) + toDecimal(oi.Quantity__c));
                        userByKey.put(key, uid);
                        outletByKey.put(key, oi.Account__c);
                    }
                    Map<Id, Set<Id>> qualifiedOutlets = new Map<Id, Set<Id>>();
                    for (String key : qtyByKey.keySet()) {
                        if (qtyByKey.get(key) < minQty) continue;
                        Id uid = userByKey.get(key);
                        if (!qualifiedOutlets.containsKey(uid)) qualifiedOutlets.put(uid, new Set<Id>());
                        qualifiedOutlets.get(uid).add(outletByKey.get(key));
                    }
                    for (Id uid : qualifiedOutlets.keySet()) {
                        perUser.put(uid, qualifiedOutlets.get(uid).size());
                    }
                } else {
                    for (Order_Item__c oi : [
                        SELECT Order_Owner_Id__c, Total_Amount__c
                        FROM Order_Item__c
                        WHERE Product__c IN :skuIds
                          AND Order_Type__c = :secondaryType
                          AND Order_Date__c >= :startDate AND Order_Date__c <= :endDate
                          AND Order_Owner_Id__c IN :userKeys
                    ]) {
                        Id uid = resolveUserId(oi.Order_Owner_Id__c, keyToUser);
                        if (uid == null) continue;
                        perUser.put(uid, (perUser.containsKey(uid) ? perUser.get(uid) : 0) + toDecimal(oi.Total_Amount__c));
                    }
                }
            }

            for (Secondary_Target__c t : packTargets) {
                resultByTarget.put(t.Id, perUser.containsKey(t.User__c) ? perUser.get(t.User__c) : 0);
            }
        }
        return resultByTarget;
    }

    // ---- Helpers ---------------------------------------------------------

    private static Integer resolveDivisor(
        Target_Criteria__c crit, Id uid, Set<Date> activeDays, Map<Id, Integer> workingDaysByUser
    ) {
        if (crit.Use_Attendance_Divisor__c == true) {
            return workingDaysByUser.containsKey(uid) ? workingDaysByUser.get(uid) : 0;
        }
        return (activeDays != null) ? activeDays.size() : 0;
    }

    private static String buildBaseWhere(Target_Criteria__c crit, Boolean includeUser) {
        SourceDef s = new SourceDef(crit.Object__c, crit.User_Field__c, crit.Date_Field__c, null, crit.Filters__c, crit.Filter_Logic__c);
        return buildSourceWhere(s, includeUser);
    }

    private static String buildSourceWhere(SourceDef s, Boolean includeUser) {
        List<String> segs = new List<String>();
        segs.add(s.dateField + ' >= :startDate');
        segs.add(s.dateField + ' <= :endDate');
        if (includeUser) {
            segs.add(s.userField + ' IN :userKeys');
        }
        String extra = TAM_FilterEngine_Service.buildWhereClause(s.filters, s.filterLogic);
        if (!String.isBlank(extra)) segs.add(extra);
        return String.join(segs, ' AND ');
    }

    private static Map<String, Id> buildKeyToUser(Set<Id> userIds) {
        Map<String, Id> keyToUser = new Map<String, Id>();
        for (Id u : userIds) {
            String s = String.valueOf(u);
            keyToUser.put(s, u);
            if (s.length() >= 15) keyToUser.put(s.substring(0, 15), u);
        }
        return keyToUser;
    }

    private static Decimal toDecimal(Object o) {
        if (o == null) return 0;
        if (o instanceof Decimal) return (Decimal) o;
        if (o instanceof Integer) return (Integer) o;
        if (o instanceof Long) return (Long) o;
        if (o instanceof Double) return Decimal.valueOf((Double) o);
        return Decimal.valueOf(String.valueOf(o));
    }

    private static Date toDate(Object raw) {
        if (raw == null) return null;
        if (raw instanceof Datetime) return ((Datetime) raw).date();
        return (Date) raw;
    }

    private static Id resolveUserId(Object raw, Map<String, Id> keyToUser) {
        if (raw == null) return null;
        String s = String.valueOf(raw);
        if (keyToUser.containsKey(s)) return keyToUser.get(s);
        if (s.length() >= 15 && keyToUser.containsKey(s.substring(0, 15))) {
            return keyToUser.get(s.substring(0, 15));
        }
        return null;
    }

    private static List<SourceDef> parseSecondarySources(String jsonConfig) {
        List<SourceDef> defs = new List<SourceDef>();
        if (String.isBlank(jsonConfig)) return defs;
        List<Object> rows = (List<Object>) JSON.deserializeUntyped(jsonConfig);
        for (Object r : rows) {
            Map<String, Object> row = (Map<String, Object>) r;
            defs.add(new SourceDef(
                (String) row.get('object'),
                (String) row.get('userField'),
                (String) row.get('dateField'),
                (String) row.get('distinctField'),
                (String) row.get('filters'),
                (String) row.get('filterLogic')
            ));
        }
        return defs;
    }

    private class SourceDef {
        String objectName;
        String userField;
        String dateField;
        String distinctField;
        String filters;
        String filterLogic;
        SourceDef(String o, String u, String d, String dist, String f, String fl) {
            this.objectName = o;
            this.userField = u;
            this.dateField = d;
            this.distinctField = dist;
            this.filters = f;
            this.filterLogic = fl;
        }
    }
}
