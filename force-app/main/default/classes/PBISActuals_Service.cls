/**
 * PBIS Task 4 — Actuals & Incentive calculation.
 *
 * recalculate() runs in five clear steps:
 *   1. queryTargets       - load the targets (header + 10 slots + parent param fields).  [1 SOQL]
 *   2. loadSlabs          - load the per-Profile incentive slabs for those policies.     [1 SOQL]
 *   3. computeAchievements - run ONE aggregate query per distinct (parameter, period)
 *                            for all users at once, then split the totals back per user.
 *                            Query count scales with parameters, not targets×slots.      [G SOQL]
 *   4. applyResults       - per target: achievement %, slab match, incentive amount,
 *                            eligibility, totals and validation message.
 *   5. update             - one DML for the whole chunk.
 *
 * Incentive per filled slot = Gross x slab(Monthly|Quarterly)% x Weightage. Total is paid
 * only when eligible (every mandatory slot reaches the lowest slab floor), else 0.
 */
public without sharing class PBISActuals_Service {

    private static final Integer SLOTS = 10;

    // ===== entry points =====
    public static void recalculate(List<PBIS_Target__c> targets) {
        if (targets == null || targets.isEmpty()) return;
        Set<Id> ids = new Set<Id>();
        for (PBIS_Target__c t : targets) {
            if (t != null && t.Id != null) ids.add(t.Id);
        }
        recalculate(ids);
    }

    public static void recalculate(Set<Id> targetIds) {
        if (targetIds == null || targetIds.isEmpty()) return;

        // 1. targets
        List<PBIS_Target__c> targets = queryTargets(targetIds);
        if (targets.isEmpty()) return;

        // 2. slabs, keyed by policyId|profile
        Set<Id> policyIds = new Set<Id>();
        for (PBIS_Target__c t : targets) {
            Id policyId = policyIdOf(t);
            if (policyId != null) policyIds.add(policyId);
        }
        Map<String, List<PBIS_Incentive_Slab__c>> slabsByKey = loadSlabs(policyIds);

        // 3. achievement[targetId][slot] from grouped queries
        Map<Id, Map<Integer, Decimal>> achievement = computeAchievements(targets);

        // 4. apply per target
        for (PBIS_Target__c t : targets) {
            Map<Integer, Decimal> slotAchv = achievement.get(t.Id);
            applyResults(t, slotAchv == null ? new Map<Integer, Decimal>() : slotAchv, slabsByKey);
        }

        // 5. save
        update targets;
    }

    // ===== step 3: grouped achievement =====
    // A bucket of slots that share the same parameter + period, so one query serves them all.
    private class AchvGroup {
        String soql;                  // single-aggregate operators: one query, reads uid+total
        List<String> sourceSoqls;     // MULTI_OBJECT_DISTINCT: one query per source, reads uid+cust
        Date startDate;
        Date endDate;
        Set<Id> userIds = new Set<Id>();
        List<SlotRef> refs = new List<SlotRef>();
    }
    // Points back to the (target, slot) and the user whose total we need.
    private class SlotRef {
        Id targetId;
        Integer slot;
        Id userId;
        SlotRef(Id targetId, Integer slot, Id userId) {
            this.targetId = targetId;
            this.slot = slot;
            this.userId = userId;
        }
    }

    private static Map<Id, Map<Integer, Decimal>> computeAchievements(List<PBIS_Target__c> targets) {
        // Bucket every runnable slot by parameter + period.
        Map<String, AchvGroup> groups = new Map<String, AchvGroup>();
        for (PBIS_Target__c t : targets) {
            if (t.User__c == null || t.Start_Date__c == null || t.End_Date__c == null) continue;
            for (Integer n = 1; n <= SLOTS; n++) {
                Id paramId = (Id) t.get('S_D_Parameter_' + n + '__c');
                if (paramId == null) continue;
                SObject param = t.getSObject('S_D_Parameter_' + n + '__r');
                if (param == null) continue;

                Boolean isMulti = param.get('Operator__c') == 'MULTI_OBJECT_DISTINCT';
                String soql = (String) param.get('SOQL_Query__c');
                List<String> sourceSoqls = isMulti ? parseSourceSoqls((String) param.get('Source_Config__c')) : null;

                // Skip slots with nothing runnable (no source queries / no single SELECT).
                if (isMulti) {
                    if (sourceSoqls.isEmpty()) continue;
                } else if (String.isBlank(soql) || !soql.trim().toUpperCase().startsWith('SELECT')) {
                    continue;
                }

                String key = paramId + '|' + t.Start_Date__c + '|' + t.End_Date__c;
                AchvGroup g = groups.get(key);
                if (g == null) {
                    g = new AchvGroup();
                    g.soql = soql;
                    g.sourceSoqls = sourceSoqls;
                    g.startDate = t.Start_Date__c;
                    g.endDate = t.End_Date__c;
                    groups.put(key, g);
                }
                g.userIds.add(t.User__c);
                g.refs.add(new SlotRef(t.Id, n, t.User__c));
            }
        }

        // Run one query per group and fan the per-user totals back to each slot.
        Map<Id, Map<Integer, Decimal>> out = new Map<Id, Map<Integer, Decimal>>();
        for (AchvGroup g : groups.values()) {
            Map<Id, Decimal> totalByUser = runGroupQuery(g);
            for (SlotRef ref : g.refs) {
                Decimal value = totalByUser.containsKey(ref.userId) ? totalByUser.get(ref.userId) : 0;
                if (!out.containsKey(ref.targetId)) out.put(ref.targetId, new Map<Integer, Decimal>());
                out.get(ref.targetId).put(ref.slot, value);
            }
        }
        return out;
    }

    // Returns the achievement per user for a group. For single-aggregate operators this is the
    // `total` from one query; for MULTI_OBJECT_DISTINCT it is the size of the distinct union of
    // `cust` values across the source queries. Binds :startDate, :endDate and :userIds.
    private static Map<Id, Decimal> runGroupQuery(AchvGroup g) {
        if (g.sourceSoqls != null) return runMultiDistinct(g);

        Date startDate = g.startDate;
        Date endDate = g.endDate;
        Set<Id> userIds = g.userIds;
        Map<Id, Decimal> totalByUser = new Map<Id, Decimal>();
        try {
            for (AggregateResult ar : (List<AggregateResult>) Database.query(g.soql)) {
                Id uid = (Id) ar.get('uid');
                Object v = ar.get('total');
                if (uid != null && v != null) totalByUser.put(uid, (Decimal) v);
            }
        } catch (Exception e) {
            // A bad parameter query yields 0 for its slots rather than aborting the chunk.
            System.debug('PBISActuals_Service group query failed: ' + e.getMessage());
        }
        return totalByUser;
    }

    // Unique customers across multiple objects: run one query per source, collect the distinct
    // `cust` values per user into a Set, and return each user's set size.
    private static Map<Id, Decimal> runMultiDistinct(AchvGroup g) {
        Date startDate = g.startDate;
        Date endDate = g.endDate;
        Set<Id> userIds = g.userIds;
        Map<Id, Set<String>> custByUser = new Map<Id, Set<String>>();
        for (String soql : g.sourceSoqls) {
            if (String.isBlank(soql)) continue;
            try {
                for (AggregateResult ar : (List<AggregateResult>) Database.query(soql)) {
                    Id uid = (Id) ar.get('uid');
                    Object cust = ar.get('cust');
                    if (uid == null || cust == null) continue;
                    if (!custByUser.containsKey(uid)) custByUser.put(uid, new Set<String>());
                    custByUser.get(uid).add(String.valueOf(cust));
                }
            } catch (Exception e) {
                System.debug('PBISActuals_Service source query failed: ' + e.getMessage());
            }
        }
        Map<Id, Decimal> countByUser = new Map<Id, Decimal>();
        for (Id uid : custByUser.keySet()) {
            countByUser.put(uid, custByUser.get(uid).size());
        }
        return countByUser;
    }

    // Pulls the generated per-source queries out of a parameter's Source_Config__c JSON.
    private static List<String> parseSourceSoqls(String sourceConfig) {
        List<String> soqls = new List<String>();
        if (String.isBlank(sourceConfig)) return soqls;
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(sourceConfig);
            List<Object> rows = (List<Object>) root.get('sources');
            if (rows == null) return soqls;
            for (Object r : rows) {
                Map<String, Object> src = (Map<String, Object>) r;
                String soql = (String) src.get('soql');
                if (String.isNotBlank(soql) && soql.trim().toUpperCase().startsWith('SELECT')) {
                    soqls.add(soql);
                }
            }
        } catch (Exception e) {
            System.debug('PBISActuals_Service could not parse Source_Config__c: ' + e.getMessage());
        }
        return soqls;
    }

    // ===== step 4: per-target results =====
    private static void applyResults(PBIS_Target__c t, Map<Integer, Decimal> slotAchv,
            Map<String, List<PBIS_Incentive_Slab__c>> slabsByKey) {
        List<String> notes = new List<String>();

        Id policyId = policyIdOf(t);
        String profile = (String) t.get('Profile__c');
        List<PBIS_Incentive_Slab__c> slabs =
            (policyId != null && String.isNotBlank(profile)) ? slabsByKey.get(policyId + '|' + profile) : null;

        if (policyId == null) notes.add('No PBIS Policy on the target');
        else if (slabs == null || slabs.isEmpty()) notes.add('No active slabs for this policy/profile');

        Decimal floor = (slabs != null && !slabs.isEmpty()) ? slabs[0].Achievement_From__c : null;
        Boolean isQuarter = t.Incentive_Period__c == 'Quarterly';
        Decimal gross = t.Gross_Salary__c == null ? 0 : t.Gross_Salary__c;

        Decimal totalIncentive = 0;
        Decimal maxIncentive = 0;
        Boolean anyMandatory = false;
        Boolean mandatoryMet = true;

        for (Integer n = 1; n <= SLOTS; n++) {
            Id paramId = (Id) t.get('S_D_Parameter_' + n + '__c');
            if (paramId == null) {
                clearSlot(t, n);
                continue;
            }

            SObject param = t.getSObject('S_D_Parameter_' + n + '__r');
            String soql = param != null ? (String) param.get('SOQL_Query__c') : null;
            Boolean mandatory = param != null && param.get('Is_Mandatory__c') == true;
            Boolean isMulti = param != null && param.get('Operator__c') == 'MULTI_OBJECT_DISTINCT';
            Decimal target = (Decimal) t.get('S_D_Parameter_' + n + '_Target__c');
            Decimal weightage = (Decimal) t.get('S_D_Parameter_' + n + '_Weightage__c');
            if (weightage == null) weightage = 0;

            // Multi-object params run per-source queries (Source_Config__c), so their SOQL_Query__c
            // is just a preview; only flag single-query params that have nothing runnable.
            if (!isMulti && (String.isBlank(soql) || !soql.trim().toUpperCase().startsWith('SELECT'))) {
                notes.add('Slot ' + n + ': parameter has no runnable query');
            }

            // Achievement came from step 3 (0 if the slot/group produced nothing).
            Decimal achievement = slotAchv.containsKey(n) ? slotAchv.get(n) : 0;
            Decimal pct = (target != null && target != 0) ? (achievement / target) * 100 : 0;

            PBIS_Incentive_Slab__c slab = matchSlab(slabs, pct);
            Decimal amount = 0;
            Decimal slabPct = null;
            String slabBand = null;
            if (slab != null) {
                slabPct = isQuarter ? slab.Quarterly_Incentive_Percent__c : slab.Monthly_Incentive_Percent__c;
                if (slabPct == null) slabPct = 0;
                amount = gross * (slabPct / 100) * (weightage / 100);
                slabBand = bandLabel(slab.Achievement_From__c, slab.Achievement_To__c);
            }
            if (slabs != null && !slabs.isEmpty()) {
                PBIS_Incentive_Slab__c top = slabs[slabs.size() - 1];
                Decimal topPct = isQuarter ? top.Quarterly_Incentive_Percent__c : top.Monthly_Incentive_Percent__c;
                if (topPct == null) topPct = 0;
                maxIncentive += gross * (topPct / 100) * (weightage / 100);
            }
            totalIncentive += amount;

            if (mandatory) {
                anyMandatory = true;
                if (floor == null || pct < floor) mandatoryMet = false;
            }

            t.put('S_D_Parameter_' + n + '_Achievement__c', achievement);
            t.put('S_D_Parameter_' + n + '_Achievement_Percent__c', pct);
            t.put('S_D_Parameter_' + n + '_Qualified_Slab__c', slab != null ? slab.Id : null);
            t.put('S_D_Parameter_' + n + '_Incentive_Amount__c', amount);
            // Snapshot the slab band + % so the record keeps a trace if the slab is later deleted.
            t.put('S_D_Parameter_' + n + '_Slab__c', slabBand);
            t.put('S_D_Parameter_' + n + '_Incentive_Percentage__c', slabPct);
        }

        Boolean eligible = anyMandatory && mandatoryMet;
        if (!anyMandatory) notes.add('No mandatory parameter selected');

        t.Is_Eligible__c = eligible;
        t.Total_Incentive_Value__c = eligible ? totalIncentive : 0;
        t.Max_Incentive_Value__c = maxIncentive;
        String msg = notes.isEmpty() ? null : String.join(notes, '; ');
        if (msg != null && msg.length() > 255) msg = msg.substring(0, 255);
        t.Validation_Message__c = msg;
    }

    private static void clearSlot(PBIS_Target__c t, Integer n) {
        t.put('S_D_Parameter_' + n + '_Achievement__c', null);
        t.put('S_D_Parameter_' + n + '_Achievement_Percent__c', null);
        t.put('S_D_Parameter_' + n + '_Qualified_Slab__c', null);
        t.put('S_D_Parameter_' + n + '_Incentive_Amount__c', null);
        t.put('S_D_Parameter_' + n + '_Slab__c', null);
        t.put('S_D_Parameter_' + n + '_Incentive_Percentage__c', null);
    }

    // "from - to" band label for the snapshot field; blank To = open-ended top band.
    private static String bandLabel(Decimal fromPct, Decimal toPct) {
        String f = fromPct == null ? '' : String.valueOf(fromPct);
        String t = toPct == null ? '+' : String.valueOf(toPct);
        return f + ' - ' + t;
    }

    // First slab (sorted by From asc) whose band contains pct; blank To = open-ended top band.
    private static PBIS_Incentive_Slab__c matchSlab(List<PBIS_Incentive_Slab__c> slabs, Decimal pct) {
        if (slabs == null || pct == null) return null;
        for (PBIS_Incentive_Slab__c s : slabs) {
            Decimal fromPct = s.Achievement_From__c;
            Decimal upto = s.Achievement_To__c;
            if (fromPct != null && pct >= fromPct && (upto == null || pct <= upto)) {
                return s;
            }
        }
        return null;
    }

    // ===== loaders =====
    private static Map<String, List<PBIS_Incentive_Slab__c>> loadSlabs(Set<Id> policyIds) {
        Map<String, List<PBIS_Incentive_Slab__c>> byKey = new Map<String, List<PBIS_Incentive_Slab__c>>();
        if (policyIds == null || policyIds.isEmpty()) return byKey;
        for (PBIS_Incentive_Slab__c s : [
            SELECT Id, PBIS_Policy__c, Profile__c, Slab_Number__c,
                   Achievement_From__c, Achievement_To__c,
                   Monthly_Incentive_Percent__c, Quarterly_Incentive_Percent__c
            FROM PBIS_Incentive_Slab__c
            WHERE PBIS_Policy__c IN :policyIds AND Is_Active__c = true
            ORDER BY Achievement_From__c ASC NULLS LAST
        ]) {
            String key = s.PBIS_Policy__c + '|' + s.Profile__c;
            if (!byKey.containsKey(key)) byKey.put(key, new List<PBIS_Incentive_Slab__c>());
            byKey.get(key).add(s);
        }
        return byKey;
    }

    // PBIS_Policy__c is a formula sourced from User.PBIS_Policy__c (Text), so the value
    // may be blank or not a valid Id; parse safely rather than letting a cast abort the run.
    private static Id policyIdOf(PBIS_Target__c t) {
        Object v = t.get('PBIS_Policy__c');
        String s = v == null ? null : String.valueOf(v);
        if (String.isBlank(s)) return null;
        try {
            return Id.valueOf(s);
        } catch (Exception e) {
            return null;
        }
    }

    // Builds the full target query (header + all 10 slots + parent param fields).
    private static List<PBIS_Target__c> queryTargets(Set<Id> ids) {
        List<String> fields = new List<String>{
            'Id', 'User__c', 'PBIS_Policy__c', 'Profile__c', 'Gross_Salary__c',
            'Incentive_Period__c', 'Start_Date__c', 'End_Date__c'
        };
        for (Integer n = 1; n <= SLOTS; n++) {
            fields.add('S_D_Parameter_' + n + '__c');
            fields.add('S_D_Parameter_' + n + '__r.SOQL_Query__c');
            fields.add('S_D_Parameter_' + n + '__r.Operator__c');
            fields.add('S_D_Parameter_' + n + '__r.Source_Config__c');
            fields.add('S_D_Parameter_' + n + '__r.Is_Mandatory__c');
            fields.add('S_D_Parameter_' + n + '_Target__c');
            fields.add('S_D_Parameter_' + n + '_Weightage__c');
        }
        String soql = 'SELECT ' + String.join(fields, ', ') + ' FROM PBIS_Target__c WHERE Id IN :ids';
        return (List<PBIS_Target__c>) Database.query(soql);
    }
}