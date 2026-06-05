@isTest
private class PBISPolicy_ControllerTest {

    private static PBIS_Incentive_Slab__c slab(Integer n, Decimal from, Decimal to, Decimal m, Decimal q) {
        return new PBIS_Incentive_Slab__c(
            Slab_Number__c = n,
            Achievement_From__c = from,
            Achievement_To__c = to,
            Monthly_Incentive_Percent__c = m,
            Quarterly_Incentive_Percent__c = q,
            Is_Active__c = true
        );
    }

    @isTest
    static void testSaveInsertWithSlabs() {
        PBIS_Policy__c policy = new PBIS_Policy__c(Name = 'Institutional', Basis__c = 'Value', Is_Active__c = true);
        List<PBIS_Incentive_Slab__c> slabs = new List<PBIS_Incentive_Slab__c>{
            slab(1, 90, 94.99, 4.50, 4.05),
            slab(2, 95, 99.99, 10.00, 9.90)
        };

        Test.startTest();
        PBISPolicy_Controller.PolicyBundle saved = PBISPolicy_Controller.savePolicy(policy, slabs);
        Test.stopTest();

        System.assertNotEquals(null, saved.policy.Id, 'Policy should be inserted');
        System.assertEquals(2, saved.slabs.size(), 'Both slabs should be saved');
        System.assertEquals(1, [SELECT COUNT() FROM PBIS_Policy__c]);
        System.assertEquals(2, [SELECT COUNT() FROM PBIS_Incentive_Slab__c WHERE PBIS_Policy__c = :saved.policy.Id]);
    }

    @isTest
    static void testSaveRemovesDroppedSlabs() {
        PBIS_Policy__c policy = new PBIS_Policy__c(Name = 'Bulk', Basis__c = 'Volume', Is_Active__c = true);
        PBISPolicy_Controller.PolicyBundle first = PBISPolicy_Controller.savePolicy(
            policy,
            new List<PBIS_Incentive_Slab__c>{ slab(1, 92, 95.99, 3.75, 3.75), slab(2, 96, 99.99, 8.25, 8.20) }
        );
        System.assertEquals(2, first.slabs.size());

        // Re-save keeping only the first slab.
        List<PBIS_Incentive_Slab__c> keep = new List<PBIS_Incentive_Slab__c>{ first.slabs[0] };

        Test.startTest();
        PBISPolicy_Controller.PolicyBundle second = PBISPolicy_Controller.savePolicy(first.policy, keep);
        Test.stopTest();

        System.assertEquals(1, second.slabs.size(), 'Dropped slab should be deleted');
        System.assertEquals(1, [SELECT COUNT() FROM PBIS_Incentive_Slab__c WHERE PBIS_Policy__c = :first.policy.Id]);
    }

    @isTest
    static void testGetPolicy() {
        PBISPolicy_Controller.PolicyBundle saved = PBISPolicy_Controller.savePolicy(
            new PBIS_Policy__c(Name = 'CPD', Basis__c = 'Value'),
            new List<PBIS_Incentive_Slab__c>{ slab(1, 90, 94.99, 4.5, 4.05) }
        );

        Test.startTest();
        PBISPolicy_Controller.PolicyBundle got = PBISPolicy_Controller.getPolicy(saved.policy.Id);
        Test.stopTest();

        System.assertEquals('CPD', got.policy.Name);
        System.assertEquals(1, got.slabs.size());
    }

    @isTest
    static void testSaveNullThrows() {
        Test.startTest();
        try {
            PBISPolicy_Controller.savePolicy(null, null);
            System.assert(false, 'Expected an exception for null policy');
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}
