/**
 * Secondary PBIS computation (BRD §5).
 * For a given month, reads achievement values off Secondary_Target__c, matches
 * each target to a per-channel slab on Incentive_Slab__c, and writes one
 * Incentive_Credit__c row per matched slab (Source__c = 'Secondary PBIS').
 * The user's monthly incentive is SUM(Credit_Amount__c) over those rows.
 *
 * Idempotent: re-running for the same month replaces the prior PBIS rows for
 * the affected users instead of duplicating them.
 */
public without sharing class SecondaryPBIS_Service {

    public static final String SOURCE_SEC_PBIS = 'Secondary PBIS';

    /** Returns the number of Incentive_Credit__c rows written. */
    public static Integer computeForMonth(Integer year, Integer month) {
        Date monthStart = Date.newInstance(year, month, 1);
        Date monthEnd = monthStart.addMonths(1).addDays(-1);

        List<Secondary_Target__c> targets = [
            SELECT Id, User__c, User__r.Name, Sales_Channel__c, Target_Criteria__c,
                   Focused_Pack__c, Achievement_Value__c, Achievement_Percent__c,
                   Start_Date__c, End_Date__c, LastModifiedDate
            FROM Secondary_Target__c
            WHERE Is_Active__c = true
              AND Target_Criteria__c != NULL
              AND User__c != NULL
              AND Start_Date__c <= :monthEnd
              AND End_Date__c >= :monthStart
        ];
        if (targets.isEmpty()) return 0;

        // Safety-net dedup: if two active targets exist for the same
        // (user, criterion, pack) and both overlap the month, only the best one
        // pays. Tie-breaker order: highest Achievement_Percent, then highest
        // Achievement_Value, then latest LastModifiedDate.
        Map<String, Secondary_Target__c> bestByKey = new Map<String, Secondary_Target__c>();
        for (Secondary_Target__c t : targets) {
            String key = String.valueOf(t.User__c) + '|' +
                String.valueOf(t.Target_Criteria__c) + '|' +
                (t.Focused_Pack__c == null ? '_' : String.valueOf(t.Focused_Pack__c));
            Secondary_Target__c kept = bestByKey.get(key);
            if (kept == null || isBetterTarget(t, kept)) bestByKey.put(key, t);
        }
        targets = bestByKey.values();

        List<Incentive_Slab__c> slabs = [
            SELECT Id, Target_Criteria__c, Sales_Channel__c, Focused_Pack__c,
                   Compare_On__c, Achievement_From__c, Achievement_To__c, Incentive_Amount__c
            FROM Incentive_Slab__c
            WHERE Active__c = true AND Target_Criteria__c != NULL
        ];

        Set<Id> userIds = new Set<Id>();
        List<Incentive_Credit__c> credits = new List<Incentive_Credit__c>();
        Date today = Date.today();
        Datetime now = System.now();

        for (Secondary_Target__c t : targets) {
            userIds.add(t.User__c);
            Incentive_Slab__c match = findMatchingSlab(t, slabs);
            if (match == null) continue;
            credits.add(new Incentive_Credit__c(
                Executive__c = t.User__c,
                User_Name__c = (t.User__r != null) ? t.User__r.Name : null,
                Sales_Channel__c = t.Sales_Channel__c,
                Year__c = year,
                Month__c = month,
                Source__c = SOURCE_SEC_PBIS,
                Target_Criteria__c = t.Target_Criteria__c,
                Focused_Pack__c = t.Focused_Pack__c,
                Matched_Slab__c = match.Id,
                Secondary_Target__c = t.Id,
                Achievement_Value__c = t.Achievement_Value__c,
                Achievement_Percent__c = t.Achievement_Percent__c,
                Compare_On__c = match.Compare_On__c,
                Credit_Amount__c = match.Incentive_Amount__c,
                Credit_Date__c = today,
                Computed_At__c = now
            ));
        }

        // Idempotent replace — delete prior PBIS rows for these users/month first.
        List<Incentive_Credit__c> prior = [
            SELECT Id FROM Incentive_Credit__c
            WHERE Source__c = :SOURCE_SEC_PBIS
              AND Year__c = :year AND Month__c = :month
              AND Executive__c IN :userIds
        ];
        if (!prior.isEmpty()) delete prior;

        if (!credits.isEmpty()) insert credits;
        return credits.size();
    }

    /**
     * Picks the best slab for a target. Pack-specific slabs win over generic
     * (Focused_Pack=null) when both qualify. Among qualifiers, highest
     * Achievement_From__c wins, then highest Incentive_Amount__c.
     * A slab with null Sales_Channel__c applies to every channel.
     */
    public static Incentive_Slab__c findMatchingSlab(Secondary_Target__c t, List<Incentive_Slab__c> slabs) {
        List<Incentive_Slab__c> packSpecific = new List<Incentive_Slab__c>();
        List<Incentive_Slab__c> generic = new List<Incentive_Slab__c>();
        for (Incentive_Slab__c s : slabs) {
            if (s.Target_Criteria__c != t.Target_Criteria__c) continue;
            if (s.Sales_Channel__c != null && s.Sales_Channel__c != t.Sales_Channel__c) continue;
            if (s.Focused_Pack__c != null) {
                if (s.Focused_Pack__c == t.Focused_Pack__c) packSpecific.add(s);
            } else {
                generic.add(s);
            }
        }

        List<Incentive_Slab__c> qualify = filterQualifying(packSpecific, t);
        if (qualify.isEmpty()) qualify = filterQualifying(generic, t);
        if (qualify.isEmpty()) return null;

        Incentive_Slab__c best = qualify[0];
        for (Incentive_Slab__c s : qualify) {
            Decimal sFrom = (s.Achievement_From__c == null) ? 0 : s.Achievement_From__c;
            Decimal bFrom = (best.Achievement_From__c == null) ? 0 : best.Achievement_From__c;
            if (sFrom > bFrom) {
                best = s;
            } else if (sFrom == bFrom) {
                Decimal sAmt = (s.Incentive_Amount__c == null) ? 0 : s.Incentive_Amount__c;
                Decimal bAmt = (best.Incentive_Amount__c == null) ? 0 : best.Incentive_Amount__c;
                if (sAmt > bAmt) best = s;
            }
        }
        return best;
    }

    // Returns true when candidate is strictly better than kept.
    private static Boolean isBetterTarget(Secondary_Target__c candidate, Secondary_Target__c kept) {
        Decimal candPct = candidate.Achievement_Percent__c == null ? 0 : candidate.Achievement_Percent__c;
        Decimal keptPct = kept.Achievement_Percent__c == null ? 0 : kept.Achievement_Percent__c;
        if (candPct > keptPct) return true;
        if (candPct < keptPct) return false;
        Decimal candVal = candidate.Achievement_Value__c == null ? 0 : candidate.Achievement_Value__c;
        Decimal keptVal = kept.Achievement_Value__c == null ? 0 : kept.Achievement_Value__c;
        if (candVal > keptVal) return true;
        if (candVal < keptVal) return false;
        return candidate.LastModifiedDate > kept.LastModifiedDate;
    }

    private static List<Incentive_Slab__c> filterQualifying(List<Incentive_Slab__c> slabs, Secondary_Target__c t) {
        List<Incentive_Slab__c> out = new List<Incentive_Slab__c>();
        for (Incentive_Slab__c s : slabs) {
            Decimal value = (s.Compare_On__c == 'Value') ? t.Achievement_Value__c : t.Achievement_Percent__c;
            if (value == null) continue;
            Decimal fromV = (s.Achievement_From__c == null) ? 0 : s.Achievement_From__c;
            if (value < fromV) continue;
            if (s.Achievement_To__c != null && value > s.Achievement_To__c) continue;
            out.add(s);
        }
        return out;
    }
}
