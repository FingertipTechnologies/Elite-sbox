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
}