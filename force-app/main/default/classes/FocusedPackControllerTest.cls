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
            'FP Unit Test', 'Cake', 10, new List<Id>{ p.Id }
        );
        Test.stopTest();
        System.assertNotEquals(null, headerId);
        System.assertEquals(1, [SELECT COUNT() FROM Focused_Pack_Item__c WHERE Focused_Pack__c = :headerId]);
        System.assertEquals(false, FocusedPackController.isNameAvailable('FP Unit Test'));
    }

    @isTest
    static void saveRejectsDuplicateName() {
        Product__c p = [SELECT Id FROM Product__c LIMIT 1];
        FocusedPackController.saveFocusedPack('Dup Pack', 'Cake', null, new List<Id>{ p.Id });
        Boolean threw = false;
        try {
            FocusedPackController.saveFocusedPack('Dup Pack', 'Cake', null, new List<Id>{ p.Id });
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Duplicate name should have thrown');
    }

    @isTest
    static void saveRejectsMissingInputs() {
        Boolean threw = false;
        try {
            FocusedPackController.saveFocusedPack(null, 'Cake', null, new List<Id>{});
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Blank name should have thrown');
    }
}