@isTest
private class FocusedPackControllerTest {

    @TestSetup
    static void setupData() {
        Product__c p1 = new Product__c(Name = 'Test SKU 1', Is_Active__c = true, SKU_Code__c = 'FP-SKU-001');
        Product__c p2 = new Product__c(Name = 'Test SKU 2', Is_Active__c = true, SKU_Code__c = 'FP-SKU-002');
        insert new List<Product__c>{ p1, p2 };

        insert new List<Sales_Channel_To_SKU__c>{
            new Sales_Channel_To_SKU__c(Sales_Channel__c = 'Cake', SKU__c = p1.Id),
            new Sales_Channel_To_SKU__c(Sales_Channel__c = 'Cake', SKU__c = p2.Id)
        };
    }

    @isTest
    static void picklistsReturnsAllFour() {
        Test.startTest();
        FocusedPackController.FocusedPackPicklists pl = FocusedPackController.getPicklists();
        Test.stopTest();
        System.assertNotEquals(null, pl);
        System.assertNotEquals(null, pl.salesChannels);
        System.assertNotEquals(null, pl.categories);
        System.assertNotEquals(null, pl.productGroups);
        System.assertNotEquals(null, pl.productSubGroups);
    }

    @isTest
    static void getSkusReturnsChannelMatches() {
        Test.startTest();
        List<FocusedPackController.SkuRow> rows =
            FocusedPackController.getSkusForChannel('Cake', null, null, null, null);
        Test.stopTest();
        System.assertEquals(2, rows.size());
    }

    @isTest
    static void getSkusFiltersBySearchTerm() {
        Test.startTest();
        List<FocusedPackController.SkuRow> rows =
            FocusedPackController.getSkusForChannel('Cake', null, null, null, 'SKU 1');
        Test.stopTest();
        System.assertEquals(1, rows.size());
        System.assertEquals('Test SKU 1', rows[0].name);
    }

    @isTest
    static void getSkusEmptyWhenChannelBlank() {
        List<FocusedPackController.SkuRow> rows =
            FocusedPackController.getSkusForChannel('', null, null, null, null);
        System.assertEquals(0, rows.size());
    }

    @isTest
    static void saveCreatesHeaderAndItems() {
        Product__c p = [SELECT Id FROM Product__c LIMIT 1];
        Test.startTest();
        Id headerId = FocusedPackController.saveFocusedPack(
            null, 'FP Unit Test', 'Cake', 10, new List<Id>{ p.Id }
        );
        Test.stopTest();
        System.assertNotEquals(null, headerId);
        System.assertEquals(1, [SELECT COUNT() FROM Focused_Pack_Item__c WHERE Focused_Pack__c = :headerId]);
        System.assertEquals(false, FocusedPackController.isNameAvailable('FP Unit Test', null));
    }

    @isTest
    static void getAndUpdateFocusedPack() {
        List<Product__c> ps = [SELECT Id FROM Product__c ORDER BY Name];
        Id headerId = FocusedPackController.saveFocusedPack(
            null, 'Editable Pack', 'Cake', 5, new List<Id>{ ps[0].Id }
        );

        Test.startTest();
        // Edit form loads the existing record.
        FocusedPackController.FocusedPackData data = FocusedPackController.getFocusedPack(headerId);
        System.assertEquals('Editable Pack', data.name);
        System.assertEquals('Cake', data.salesChannel);
        System.assertEquals(1, data.skuIds.size());

        // Update: rename + swap to both SKUs.
        Id sameId = FocusedPackController.saveFocusedPack(
            headerId, 'Editable Pack v2', 'Cake', 12, new List<Id>{ ps[0].Id, ps[1].Id }
        );
        Test.stopTest();

        System.assertEquals(headerId, sameId, 'Update keeps the same record');
        Focused_Pack__c fp = [SELECT Name, Minimum_Qualifying_Quantity__c FROM Focused_Pack__c WHERE Id = :headerId];
        System.assertEquals('Editable Pack v2', fp.Name);
        System.assertEquals(12, fp.Minimum_Qualifying_Quantity__c);
        System.assertEquals(2, [SELECT COUNT() FROM Focused_Pack_Item__c WHERE Focused_Pack__c = :headerId],
            'Items replaced with the new selection');
        // The record may keep its own name on edit.
        System.assertEquals(true, FocusedPackController.isNameAvailable('Editable Pack v2', headerId));
    }

    @isTest
    static void saveRejectsDuplicateName() {
        Product__c p = [SELECT Id FROM Product__c LIMIT 1];
        FocusedPackController.saveFocusedPack(null, 'Dup Pack', 'Cake', null, new List<Id>{ p.Id });
        Boolean threw = false;
        try {
            FocusedPackController.saveFocusedPack(null, 'Dup Pack', 'Cake', null, new List<Id>{ p.Id });
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Duplicate name should have thrown');
    }

    @isTest
    static void saveRejectsMissingInputs() {
        Boolean threw = false;
        try {
            FocusedPackController.saveFocusedPack(null, null, 'Cake', null, new List<Id>{});
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Blank name should have thrown');
    }
}