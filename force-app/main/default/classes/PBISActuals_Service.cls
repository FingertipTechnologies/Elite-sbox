/**
 * PBIS Task 4 — Actuals & Incentive calculation.
 *
 * For each PBIS_Target__c: runs every filled "S & D Parameter" slot's stored
 * SOQL_Query__c to get the actual achievement, derives achievement %, matches the
 * per-Profile incentive slab on the user's policy, computes the per-slot incentive
 * amount (Gross x Slab% x Weightage), and rolls up Total / Max / Eligibility.
 *
 * Shared by the daily scheduler/batch, the admin list-button page and the per-record
 * quick action. Bulk-safe: one target re-query (with parent fields), one slab query,
 * then one aggregate query per filled slot bound to the single target user.
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

        List<PBIS_Target__c> targets = queryTargets(targetIds);
        if (targets.isEmpty()) return;

        // Slabs for every policy referenced by the users in scope.
        Set<Id> policyIds = new Set<Id>();
        for (PBIS_Target__c t : targets) {
            Id policyId = userPolicyId(t);
            if (policyId != null) policyIds.add(policyId);
        }
        Map<String, List<PBIS_Incentive_Slab__c>> slabsByKey = loadSlabs(policyIds);

        for (PBIS_Target__c t : targets) {
            computeTarget(t, slabsByKey);
        }
        update targets;
    }

    // ===== per-target calculation =====
    private static void computeTarget(PBIS_Target__c t, Map<String, List<PBIS_Incentive_Slab__c>> slabsByKey) {
        List<String> notes = new List<String>();

        Id policyId = userPolicyId(t);
        String profile = (String) t.get('Profile__c');
        List<PBIS_Incentive_Slab__c> slabs =
            (policyId != null && String.isNotBlank(profile))
                ? slabsByKey.get(policyId + '|' + profile)
                : null;

        if (policyId == null) notes.add('No PBIS Policy on the user');
        else if (slabs == null || slabs.isEmpty()) notes.add('No active slabs for this policy/profile');

        Decimal floor = (slabs != null && !slabs.isEmpty()) ? slabs[0].Achievement_From__c : null;
        Boolean isQuarter = t.Incentive_Period__c == 'Quarterly';
        Decimal gross = (Decimal) t.Gross_Salary__c;
        if (gross == null) gross = 0;

        Decimal totalIncentive = 0;
        Decimal maxIncentive = 0;
        Boolean anyMandatory = false;
        Boolean mandatoryMet = true; // until a mandatory slot fails the floor

        for (Integer n = 1; n <= SLOTS; n++) {
            Id paramId = (Id) t.get('S_D_Parameter_' + n + '__c');
            if (paramId == null) {
                // clear any stale calc values for an empty slot
                t.put('S_D_Parameter_' + n + '_Achievement__c', null);
                t.put('S_D_Parameter_' + n + '_Achievement_Percent__c', null);
                t.put('S_D_Parameter_' + n + '_Qualified_Slab__c', null);
                t.put('S_D_Parameter_' + n + '_Incentive_Amount__c', null);
                continue;
            }

            SObject param = t.getSObject('S_D_Parameter_' + n + '__r');
            String soql = param != null ? (String) param.get('SOQL_Query__c') : null;
            Boolean mandatory = param != null && param.get('Is_Mandatory__c') == true;
            Decimal target = (Decimal) t.get('S_D_Parameter_' + n + '_Target__c');
            Decimal weightage = (Decimal) t.get('S_D_Parameter_' + n + '_Weightage__c');
            if (weightage == null) weightage = 0;

            // 1) achievement from the stored SOQL
            Decimal achievement = runAchievement(soql, t.User__c, t.Start_Date__c, t.End_Date__c, n, notes);

            // 2) achievement %
            Decimal pct = (target != null && target != 0) ? (achievement / target) * 100 : 0;

            // 3) slab match + 4) incentive amount
            PBIS_Incentive_Slab__c slab = matchSlab(slabs, pct);
            Decimal amount = 0;
            if (slab != null) {
                Decimal slabPct = isQuarter ? slab.Quarterly_Incentive_Percent__c : slab.Monthly_Incentive_Percent__c;
                if (slabPct == null) slabPct = 0;
                amount = gross * (slabPct / 100) * (weightage / 100);
            }

            // max possible for this slot = top slab % at this weightage
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
        }

        Boolean eligible = anyMandatory && mandatoryMet;
        if (!anyMandatory) notes.add('No mandatory parameter selected');

        t.Is_Eligible__c = eligible;
        t.Total_Incentive_Value__c = eligible ? totalIncentive : 0;
        t.Max_Incentive_Value__c = maxIncentive;
        t.Validation_Message__c = notes.isEmpty() ? null : truncate(String.join(notes, '; '), 255);
    }

    // Runs one parameter's stored aggregate SOQL for a single user/period; returns the summed total.
    private static Decimal runAchievement(String soql, Id userId, Date startDate, Date endDate, Integer slot, List<String> notes) {
        if (String.isBlank(soql) || !soql.trim().toUpperCase().startsWith('SELECT')) {
            notes.add('Slot ' + slot + ': parameter has no runnable query');
            return 0;
        }
        if (startDate == null || endDate == null) {
            notes.add('Slot ' + slot + ': missing period dates');
            return 0;
        }
        Set<Id> userIds = new Set<Id>{ userId };
        Decimal total = 0;
        try {
            for (AggregateResult ar : (List<AggregateResult>) Database.query(soql)) {
                Object v = ar.get('total');
                if (v != null) total += (Decimal) v;
            }
        } catch (Exception e) {
            notes.add('Slot ' + slot + ': ' + e.getMessage());
            return 0;
        }
        return total;
    }

    // First slab (sorted by From asc) whose band contains pct; blank To = open-ended top band.
    private static PBIS_Incentive_Slab__c matchSlab(List<PBIS_Incentive_Slab__c> slabs, Decimal pct) {
        if (slabs == null || pct == null) return null;
        for (PBIS_Incentive_Slab__c s : slabs) {
            Decimal from = s.Achievement_From__c;
            Decimal upto = s.Achievement_To__c;
            if (from != null && pct >= from && (upto == null || pct <= upto)) {
                return s;
            }
        }
        return null;
    }

    // ===== data loaders =====
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

    private static Id userPolicyId(PBIS_Target__c t) {
        SObject u = t.getSObject('User__r');
        return u != null ? (Id) u.get('PBIS_Policy__c') : null;
    }

    // Builds the full target query (header + all 10 slots + parent param/user fields).
    private static List<PBIS_Target__c> queryTargets(Set<Id> ids) {
        List<String> fields = new List<String>{
            'Id', 'User__c', 'User__r.PBIS_Policy__c', 'Profile__c', 'Gross_Salary__c',
            'Incentive_Period__c', 'Start_Date__c', 'End_Date__c'
        };
        for (Integer n = 1; n <= SLOTS; n++) {
            fields.add('S_D_Parameter_' + n + '__c');
            fields.add('S_D_Parameter_' + n + '__r.SOQL_Query__c');
            fields.add('S_D_Parameter_' + n + '__r.Is_Mandatory__c');
            fields.add('S_D_Parameter_' + n + '_Target__c');
            fields.add('S_D_Parameter_' + n + '_Weightage__c');
        }
        String soql = 'SELECT ' + String.join(fields, ', ') +
                      ' FROM PBIS_Target__c WHERE Id IN :ids';
        return (List<PBIS_Target__c>) Database.query(soql);
    }

    private static String truncate(String s, Integer max) {
        return (s != null && s.length() > max) ? s.substring(0, max) : s;
    }
}
