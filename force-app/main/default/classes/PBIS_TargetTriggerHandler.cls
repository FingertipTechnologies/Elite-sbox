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
        checkDuplicates(rows, null);
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
        checkDuplicates(rows, oldMap);
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
     * Prevents duplicate PBIS Targets for the same User + Incentive Period + period
     * (Start_Date + End_Date). Bulk-safe for a 1000-user upload: detects duplicates within
     * the incoming batch and, with a single SOQL, against records already in the org. Each
     * offending row is failed via addError so the rest of a partial-success upload still loads.
     */
    private static void checkDuplicates(List<PBIS_Target__c> rows, Map<Id, PBIS_Target__c> oldMap) {
        Map<String, PBIS_Target__c> firstByKey = new Map<String, PBIS_Target__c>();
        Set<Id> userIds = new Set<Id>();
        Set<Date> starts = new Set<Date>();
        Set<Date> ends = new Set<Date>();
        Set<String> periods = new Set<String>();

        for (PBIS_Target__c t : rows) {
            if (!hasKeyFields(t)) continue;
            String key = keyOf(t);
            if (firstByKey.containsKey(key)) {
                t.addError('Duplicate PBIS Target: another row in this upload has the same User, ' +
                    'Incentive Period and Start/End dates.');
            } else {
                firstByKey.put(key, t);
                userIds.add(t.User__c);
                starts.add(t.Start_Date__c);
                ends.add(t.End_Date__c);
                periods.add(t.Incentive_Period__c);
            }
        }
        if (firstByKey.isEmpty()) return;

        Set<Id> selfIds = oldMap != null ? oldMap.keySet() : new Set<Id>();
        for (PBIS_Target__c ex : [
            SELECT Id, User__c, Incentive_Period__c, Start_Date__c, End_Date__c
            FROM PBIS_Target__c
            WHERE User__c IN :userIds
              AND Start_Date__c IN :starts
              AND End_Date__c IN :ends
              AND Incentive_Period__c IN :periods
        ]) {
            if (selfIds.contains(ex.Id)) continue; // ignore the record being updated itself
            PBIS_Target__c dup = firstByKey.get(keyOf(ex));
            if (dup != null) {
                dup.addError('A PBIS Target already exists for this User, Incentive Period and period ' +
                    '(Start/End dates). Duplicates are not allowed.');
            }
        }
    }

    private static Boolean hasKeyFields(PBIS_Target__c t) {
        return t.User__c != null && t.Incentive_Period__c != null
            && t.Start_Date__c != null && t.End_Date__c != null;
    }

    private static String keyOf(PBIS_Target__c t) {
        return t.Incentive_Period__c + '|' + t.User__c + '|'
            + String.valueOf(t.Start_Date__c) + '|' + String.valueOf(t.End_Date__c);
    }
}