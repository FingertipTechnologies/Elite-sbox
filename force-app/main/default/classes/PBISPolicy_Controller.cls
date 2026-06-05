/**
 * Controller for the PBIS Policy Setup screen (Primary PBIS, Task 2).
 *
 * A PBIS Policy is a channel-wise master that holds, per Profile, the incentive slabs
 * (band + monthly/quarterly % of gross). The builder LWC saves the policy and its slab
 * rows together; removed rows are deleted.
 */
public with sharing class PBISPolicy_Controller {

    /** Wrapper passed back to the LWC: a policy plus its slab rows. */
    public class PolicyBundle {
        @AuraEnabled public PBIS_Policy__c policy { get; set; }
        @AuraEnabled public List<PBIS_Incentive_Slab__c> slabs { get; set; }
        public PolicyBundle() { slabs = new List<PBIS_Incentive_Slab__c>(); }
    }

    /** Hydrate a policy and its slabs for the edit form. */
    @AuraEnabled(cacheable=false)
    public static PolicyBundle getPolicy(Id policyId) {
        PolicyBundle b = new PolicyBundle();
        b.policy = [
            SELECT Id, Name, Sales_Channels__c, Basis__c, Is_Active__c, Description__c
            FROM PBIS_Policy__c WHERE Id = :policyId LIMIT 1
        ];
        b.slabs = [
            SELECT Id, Profile__c, Slab_Number__c, Achievement_From__c, Achievement_To__c,
                   Monthly_Incentive_Percent__c, Quarterly_Incentive_Percent__c, Is_Active__c
            FROM PBIS_Incentive_Slab__c
            WHERE PBIS_Policy__c = :policyId
            ORDER BY Profile__c, Slab_Number__c
        ];
        return b;
    }

    /**
     * Upsert a policy and its slab rows in one transaction. Slabs not present in the
     * incoming list (by Id) are deleted. Returns the saved bundle.
     */
    @AuraEnabled
    public static PolicyBundle savePolicy(PBIS_Policy__c policy, List<PBIS_Incentive_Slab__c> slabs) {
        if (policy == null) {
            throw new AuraHandledException('No policy provided to save.');
        }
        if (slabs == null) slabs = new List<PBIS_Incentive_Slab__c>();

        Savepoint sp = Database.setSavepoint();
        try {
            upsert policy;

            // Delete child slabs that were removed in the UI.
            if (policy.Id != null) {
                Set<Id> keepIds = new Set<Id>();
                for (PBIS_Incentive_Slab__c s : slabs) {
                    if (s.Id != null) keepIds.add(s.Id);
                }
                List<PBIS_Incentive_Slab__c> toDelete = new List<PBIS_Incentive_Slab__c>();
                for (PBIS_Incentive_Slab__c existing : [
                    SELECT Id FROM PBIS_Incentive_Slab__c WHERE PBIS_Policy__c = :policy.Id
                ]) {
                    if (!keepIds.contains(existing.Id)) toDelete.add(existing);
                }
                if (!toDelete.isEmpty()) delete toDelete;
            }

            for (PBIS_Incentive_Slab__c s : slabs) {
                s.PBIS_Policy__c = policy.Id;
            }
            if (!slabs.isEmpty()) upsert slabs;

            return getPolicy(policy.Id);
        } catch (DmlException e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }
}
