/**
 * PBIS_Target__c trigger handler.
 *
 * Auto-populates Gross_Salary__c from the linked User's Monthly_Gross_Salary_INR__c,
 * so the salary does not have to be entered/imported on the per-user target row.
 *
 * Sync behaviour:
 *  - before insert: set Gross_Salary__c for every row that has a User__c.
 *  - before update: only when User__c changed — re-derive from the new User, or blank
 *    out Gross_Salary__c if the User was cleared. Manual edits are otherwise preserved.
 */
public with sharing class PBIS_TargetTriggerHandler {

    public static void beforeInsert(List<PBIS_Target__c> rows) {
        List<PBIS_Target__c> withUser = new List<PBIS_Target__c>();
        for (PBIS_Target__c t : rows) {
            if (t.User__c != null) {
                withUser.add(t);
            }
        }
        applyGrossSalary(withUser);
        checkPeriodOverlaps(rows, null);
    }

    public static void beforeUpdate(List<PBIS_Target__c> rows, Map<Id, PBIS_Target__c> oldMap) {
        List<PBIS_Target__c> changedWithUser = new List<PBIS_Target__c>();
        for (PBIS_Target__c t : rows) {
            PBIS_Target__c old = oldMap.get(t.Id);
            if (old != null && t.User__c == old.User__c) {
                continue; // User unchanged — leave Gross Salary as-is
            }
            if (t.User__c == null) {
                t.Gross_Salary__c = null; // User cleared
            } else {
                changedWithUser.add(t);
            }
        }
        applyGrossSalary(changedWithUser);
        checkPeriodOverlaps(rows, oldMap);
    }

    /**
     * Copies Monthly_Gross_Salary_INR__c from each row's User onto Gross_Salary__c.
     * Bulk-safe: a single SOQL across all distinct User ids.
     */
    private static void applyGrossSalary(List<PBIS_Target__c> rows) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        Set<Id> userIds = new Set<Id>();
        for (PBIS_Target__c t : rows) {
            userIds.add(t.User__c);
        }
        Map<Id, User> userMap = new Map<Id, User>([
            SELECT Id, Monthly_Gross_Salary_INR__c
            FROM User
            WHERE Id IN :userIds
        ]);
        for (PBIS_Target__c t : rows) {
            if (userMap.containsKey(t.User__c)) {
                t.Gross_Salary__c = userMap.get(t.User__c).Monthly_Gross_Salary_INR__c;
            }
        }
    }

    /**
     * Prevents OVERLAPPING PBIS Targets for the same User + Incentive Period. Two targets
     * conflict when their periods overlap (Start <= other.End AND End >= other.Start), so e.g.
     * a Monthly 01-30 Jun and a Monthly 12-29 Jun are rejected, while back-to-back months
     * (01-30 Jun and 01-31 Jul) and a different Incentive Period are allowed.
     *
     * Bulk-safe for a 1000-user upload: detects in-batch overlaps and, with one SOQL narrowed
     * to the batch's user/period sets and overall date window, overlaps with records already in
     * the org. Offending rows fail via addError so a partial-success upload still loads the rest.
     */
    private static void checkPeriodOverlaps(List<PBIS_Target__c> rows, Map<Id, PBIS_Target__c> oldMap) {
        Map<String, List<PBIS_Target__c>> incomingByGroup = new Map<String, List<PBIS_Target__c>>();
        Set<Id> userIds = new Set<Id>();
        Set<String> periods = new Set<String>();
        Date minStart;
        Date maxEnd;

        for (PBIS_Target__c t : rows) {
            if (!hasKeyFields(t) || t.Start_Date__c > t.End_Date__c) continue;
            String g = groupKey(t);
            if (!incomingByGroup.containsKey(g)) incomingByGroup.put(g, new List<PBIS_Target__c>());
            // Overlap with an earlier row in the same upload (same User + Incentive Period).
            for (PBIS_Target__c other : incomingByGroup.get(g)) {
                if (overlaps(t, other)) {
                    t.addError('Overlapping PBIS Target: another row in this upload for the same User ' +
                        'and Incentive Period has an overlapping period.');
                    break;
                }
            }
            incomingByGroup.get(g).add(t);
            userIds.add(t.User__c);
            periods.add(t.Incentive_Period__c);
            if (minStart == null || t.Start_Date__c < minStart) minStart = t.Start_Date__c;
            if (maxEnd == null || t.End_Date__c > maxEnd) maxEnd = t.End_Date__c;
        }
        if (incomingByGroup.isEmpty()) return;

        Set<Id> selfIds = oldMap != null ? oldMap.keySet() : new Set<Id>();
        for (PBIS_Target__c ex : [
            SELECT Id, User__c, Incentive_Period__c, Start_Date__c, End_Date__c
            FROM PBIS_Target__c
            WHERE User__c IN :userIds
              AND Incentive_Period__c IN :periods
              AND Start_Date__c <= :maxEnd
              AND End_Date__c >= :minStart
        ]) {
            if (selfIds.contains(ex.Id)) continue; // ignore the record being updated itself
            List<PBIS_Target__c> grp = incomingByGroup.get(groupKey(ex));
            if (grp == null) continue;
            for (PBIS_Target__c t : grp) {
                if (overlaps(t, ex)) {
                    t.addError('A PBIS Target already exists for this User and Incentive Period with an ' +
                        'overlapping period (' + ex.Start_Date__c.format() + ' - ' + ex.End_Date__c.format() +
                        '). Overlapping periods are not allowed.');
                }
            }
        }
    }

    // Two date ranges overlap when each starts on or before the other ends.
    private static Boolean overlaps(PBIS_Target__c a, PBIS_Target__c b) {
        return a.Start_Date__c <= b.End_Date__c && a.End_Date__c >= b.Start_Date__c;
    }

    private static Boolean hasKeyFields(PBIS_Target__c t) {
        return t.User__c != null && t.Incentive_Period__c != null
            && t.Start_Date__c != null && t.End_Date__c != null;
    }

    private static String groupKey(PBIS_Target__c t) {
        return t.Incentive_Period__c + '|' + t.User__c;
    }
}