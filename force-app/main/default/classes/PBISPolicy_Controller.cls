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
            SELECT Id, Name, Sales_Channels__c, Basis__c, Is_Active__c
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

        // Guard: an active policy may not share a Sales Channel with another active policy.
        assertUniqueSalesChannels(policy);

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

            // Set the master-detail only on NEW slabs. PBIS_Policy__c is a
            // non-reparentable master-detail (not updateable), so assigning it on an
            // existing slab during update throws "Field is not writeable".
            for (PBIS_Incentive_Slab__c s : slabs) {
                if (s.Id == null) s.PBIS_Policy__c = policy.Id;
            }
            if (!slabs.isEmpty()) upsert slabs;

            return getPolicy(policy.Id);
        } catch (DmlException e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }

    /**
     * Enforces that each Sales Channel has at most one ACTIVE PBIS Policy. If the policy
     * being saved is active and any of its channels is already used by another active
     * policy, throws with the conflicting channel(s) and the existing policy name(s).
     */
    private static void assertUniqueSalesChannels(PBIS_Policy__c policy) {
        if (policy.Is_Active__c != true || String.isBlank(policy.Sales_Channels__c)) {
            return; // inactive policies (or no channel) don't reserve a channel
        }
        Set<String> selected = new Set<String>(policy.Sales_Channels__c.split(';'));
        Id selfId = policy.Id; // null on insert -> "Id != null" matches all rows

        List<String> details = new List<String>();
        for (PBIS_Policy__c c : [
            SELECT Id, Name, Sales_Channels__c
            FROM PBIS_Policy__c
            WHERE Is_Active__c = true
              AND Id != :selfId
              AND Sales_Channels__c != null
        ]) {
            Set<String> overlap = new Set<String>(c.Sales_Channels__c.split(';'));
            overlap.retainAll(selected);
            if (!overlap.isEmpty()) {
                details.add('"' + c.Name + '" (' + String.join(new List<String>(overlap), ', ') + ')');
            }
        }
        if (details.isEmpty()) return;
        throw new AuraHandledException(
            'A PBIS Policy with the same Sales Channel already exists: ' +
            String.join(details, '; ') +
            '. Each Sales Channel can have only one active PBIS Policy.'
        );
    }
}