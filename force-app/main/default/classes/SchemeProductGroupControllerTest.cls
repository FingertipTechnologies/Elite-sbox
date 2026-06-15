@isTest
private class SchemeProductGroupControllerTest {

    private static final String CHANNEL = 'Cake';

    private static String resolvePurpose(String token) {
        String norm = token.toLowerCase().replaceAll('[\\s_\\-]', '');
        for (Schema.PicklistEntry e :
                Scheme_Product_Group__c.Group_Purpose__c.getDescribe().getPicklistValues()) {
            if (!e.isActive()) continue;
            String v = e.getValue().toLowerCase().replaceAll('[\\s_\\-]', '');
            if (v == norm) return e.getValue();
        }
        return null;
    }

    private static Product__c makeProduct(String name) {
        Product__c p = new Product__c(
            Name = name,
            Is_Active__c = true,
            Channel__c = CHANNEL,
            SKU_Code__c = name
        );
        insert p;
        return p;
    }

    // Active FOC Giveaway scheme that gives away the supplied product.
    private static Scheme__c makeActiveFocScheme(Id focProductId, Boolean active) {
        Scheme__c sc = new Scheme__c(
            Name = 'FOC ' + System.now().getTime(),
            Scheme_Type__c = 'FOC Giveaway',
            Sales_Channel__c = CHANNEL,
            IsActive__c = active,
            Scheme_Start_Date__c = Date.today(),
            Scheme_End_Date__c = Date.today().addDays(30)
        );
        insert sc;
        insert new Scheme_Slab__c(
            Scheme__c = sc.Id,
            Slab_Type__c = 'FOC Giveaway',
            FOC_Product__c = focProductId,
            Qualifying_Qty_Min__c = 10,
            Free_Qty__c = 1
        );
        return sc;
    }

    private static SchemeProductGroupController.GroupHeader headerFor(String label, Boolean active) {
        SchemeProductGroupController.GroupHeader h = new SchemeProductGroupController.GroupHeader();
        h.groupLabel   = label;
        h.salesChannel = CHANNEL;
        h.groupPurpose = resolvePurpose('Price Division');
        h.isActive     = active;
        return h;
    }

    @isTest
    static void saveGroup_blocksProductThatIsActiveFocProduct() {
        Product__c x = makeProduct('GFOCX1');
        makeActiveFocScheme(x.Id, true);

        SchemeProductGroupController.GroupHeader h = headerFor('Grp1', true);

        Test.startTest();
        Boolean blocked = false;
        try {
            SchemeProductGroupController.saveGroup(h, new List<Id>{ x.Id }, null);
        } catch (Exception e) {
            blocked = true;
            System.assert(e.getMessage().contains('FOC giveaway product'),
                'Expected FOC-scheme conflict message, got: ' + e.getMessage());
        }
        Test.stopTest();
        System.assert(blocked, 'Adding an active FOC product to an active group must be blocked.');
    }

    @isTest
    static void saveGroup_inactiveGroupWithFocProductAllowed() {
        Product__c x = makeProduct('GFOCX2');
        makeActiveFocScheme(x.Id, true);

        SchemeProductGroupController.GroupHeader h = headerFor('Grp2', false);

        Test.startTest();
        Id id = SchemeProductGroupController.saveGroup(h, new List<Id>{ x.Id }, null);
        Test.stopTest();
        System.assertNotEquals(null, id, 'Inactive group may contain the FOC product.');
    }

    @isTest
    static void saveGroup_allowedWhenFocSchemeInactive() {
        Product__c x = makeProduct('GFOCX3');
        makeActiveFocScheme(x.Id, false); // scheme inactive -> no conflict

        SchemeProductGroupController.GroupHeader h = headerFor('Grp3', true);

        Test.startTest();
        Id id = SchemeProductGroupController.saveGroup(h, new List<Id>{ x.Id }, null);
        Test.stopTest();
        System.assertNotEquals(null, id, 'Active group is allowed when no active FOC scheme gives away the product.');
    }
}
