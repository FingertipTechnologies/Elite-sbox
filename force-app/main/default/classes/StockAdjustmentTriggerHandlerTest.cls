@isTest
public class StockAdjustmentTriggerHandlerTest {

    @TestSetup
    static void setupTestData() {

        // ── Step 1: Setup Objects (User) — must be done first, separately ──
        Profile tseProfile = [SELECT Id FROM Profile WHERE Name = 'TSE' LIMIT 1];
        UserRole testRole  = [SELECT Id FROM UserRole LIMIT 1];

        User tseUser = new User(
            Alias             = 'tuser2',
            Employee_Code__c  = 'TSE987654321',
            Email             = 'tse1@stockadjtest.com',
            EmailEncodingKey  = 'UTF-8',
            LastName          = 'TSEUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey      = 'en_US',
            ProfileId         = tseProfile.Id,
            TimeZoneSidKey    = 'America/Los_Angeles',
            Username          = 'tse1@stockadjtest.com' + System.currentTimeMillis(),
            userroleId        = testRole.Id,
            Sales_Channel__c  = 'Cake'
        );
        insert tseUser;

        // ── Step 2: Non-Setup Objects inside System.runAs() ──
        System.runAs(tseUser) {

            // Primary Customer (Distributor)
            Account distributor = new Account(
                Name                    = 'Test Distributor',
                OwnerId                 = tseUser.Id,
                Customer_Type__c        = 'Primary Customer',
                Pincode__c              = '500001',
                Primary_Phone_Number__c = '9876543210',
                State__c                = 'Telangana',
                District__c             = 'Hyderabad'
            );
            insert distributor;

            // Product
            Product__c product = new Product__c(
                Name        = 'Test Product',
                SKU_Code__c = '12111stkadj'
            );
            insert product;
        }
    }

    // ── Helpers ──
    static Account getDistributor() {
        return [SELECT Id FROM Account WHERE Name = 'Test Distributor' LIMIT 1];
    }

    static Product__c getProduct() {
        return [SELECT Id, Name FROM Product__c WHERE Name = 'Test Product' LIMIT 1];
    }

    // ─────────────────────────────────────────
    // Test 1: Closing Stock - New Stock Created When None Exists
    // ─────────────────────────────────────────
    @isTest
    static void testClosingStock_NewStockCreated() {

        Account distributor = getDistributor();
        Product__c product  = getProduct();

        Stock_Adjustment__c adj = new Stock_Adjustment__c(
            Distributor__c            = distributor.Id,
            Product__c                = product.Id,
            Adjustment_Type__c        = 'Closing Stock',
            Quantity__c               = 100,
            Stock_Adjustment_Date__c  = Date.today()
        );

        Test.startTest();
        insert adj;
        Test.stopTest();

        Stock_Adjustment__c inserted = [
            SELECT Id, Distributor_Stock__c, Product_Name__c
            FROM Stock_Adjustment__c
            WHERE Id = :adj.Id
        ];
        System.assertNotEquals(null, inserted.Distributor_Stock__c,
            'Distributor Stock should be auto-created and linked');
        System.assertEquals(product.Name, inserted.Product_Name__c,
            'Product Name should be auto-populated');

        List<Distributor_Stock__c> stocks = [
            SELECT Id, Closing_Stock_Quantity__c, Available_Saleable_Quantity__c
            FROM Distributor_Stock__c
            WHERE Distributor__c = :distributor.Id
            AND Product__c = :product.Id
        ];
        System.assertEquals(1, stocks.size(), 'Exactly one Distributor Stock should exist');
        System.assertEquals(100, stocks[0].Closing_Stock_Quantity__c,
            'Closing Stock quantity should roll up');
        System.assertEquals(100, stocks[0].Available_Saleable_Quantity__c,
            'Available Saleable Quantity should include Closing Stock');
    }

    // ─────────────────────────────────────────
    // Test 2: Existing Stock Linked (No Duplicate)
    // ─────────────────────────────────────────
    @isTest
    static void testClosingStock_ExistingStockLinked() {

        Account distributor = getDistributor();
        Product__c product  = getProduct();

        Distributor_Stock__c existingStock = new Distributor_Stock__c(
            Product__c     = product.Id,
            Distributor__c = distributor.Id
        );
        insert existingStock;

        Stock_Adjustment__c adj = new Stock_Adjustment__c(
            Distributor__c            = distributor.Id,
            Product__c                = product.Id,
            Adjustment_Type__c        = 'Closing Stock',
            Quantity__c               = 50,
            Stock_Adjustment_Date__c  = Date.today()
        );

        Test.startTest();
        insert adj;
        Test.stopTest();

        Stock_Adjustment__c inserted = [
            SELECT Id, Distributor_Stock__c
            FROM Stock_Adjustment__c
            WHERE Id = :adj.Id
        ];
        System.assertEquals(existingStock.Id, inserted.Distributor_Stock__c,
            'Should link to existing Distributor_Stock__c');

        Integer stockCount = [
            SELECT COUNT() FROM Distributor_Stock__c
            WHERE Distributor__c = :distributor.Id
            AND Product__c = :product.Id
        ];
        System.assertEquals(1, stockCount, 'No duplicate Distributor Stock should be created');
    }

    // ─────────────────────────────────────────
    // Test 3: Other Adjustment Type (Written Off) - Stock Auto-Created
    // ─────────────────────────────────────────
    @isTest
    static void testWrittenOff_NewStockCreated() {

        Account distributor = getDistributor();
        Product__c product  = getProduct();

        Stock_Adjustment__c adj = new Stock_Adjustment__c(
            Distributor__c            = distributor.Id,
            Product__c                = product.Id,
            Adjustment_Type__c        = 'Written Off Quantity',
            Quantity__c               = 5,
            Stock_Adjustment_Date__c  = Date.today()
        );

        Test.startTest();
        insert adj;
        Test.stopTest();

        Stock_Adjustment__c inserted = [
            SELECT Id, Distributor_Stock__c
            FROM Stock_Adjustment__c
            WHERE Id = :adj.Id
        ];
        System.assertNotEquals(null, inserted.Distributor_Stock__c,
            'Distributor Stock should be auto-created for Written Off adjustments too');

        List<Distributor_Stock__c> stocks = [
            SELECT Id, Written_Off_Quantity__c, Closing_Stock_Quantity__c
            FROM Distributor_Stock__c
            WHERE Id = :inserted.Distributor_Stock__c
        ];
        System.assertEquals(5, stocks[0].Written_Off_Quantity__c,
            'Written Off quantity should roll up');
        System.assertEquals(0, stocks[0].Closing_Stock_Quantity__c,
            'Closing Stock rollup should not include other adjustment types');
    }

    // ─────────────────────────────────────────
    // Test 4: Bulk Insert - Mixed Stock Scenario, No Duplicates
    // ─────────────────────────────────────────
    @isTest
    static void testBulkInsert_MixedScenario() {

        Account distributor = getDistributor();

        List<Product__c> products = new List<Product__c>();
        for (Integer i = 0; i < 5; i++) {
            products.add(new Product__c(Name = 'Bulk Product ' + i, SKU_Code__c = '12111b' + i));
        }
        insert products;

        // Pre-create stock for first 2 only
        List<Distributor_Stock__c> preStocks = new List<Distributor_Stock__c>();
        for (Integer i = 0; i < 2; i++) {
            preStocks.add(new Distributor_Stock__c(
                Product__c     = products[i].Id,
                Distributor__c = distributor.Id
            ));
        }
        insert preStocks;

        // 2 adjustments per product — 2 products match existing stock, 3 need new stock
        List<Stock_Adjustment__c> adjs = new List<Stock_Adjustment__c>();
        for (Integer i = 0; i < 5; i++) {
            for (Integer j = 0; j < 2; j++) {
                adjs.add(new Stock_Adjustment__c(
                    Distributor__c            = distributor.Id,
                    Product__c                = products[i].Id,
                    Adjustment_Type__c        = 'Closing Stock',
                    Quantity__c               = 10,
                    Stock_Adjustment_Date__c  = Date.today()
                ));
            }
        }

        Test.startTest();
        insert adjs;
        Test.stopTest();

        for (Stock_Adjustment__c a : [
            SELECT Id, Distributor_Stock__c
            FROM Stock_Adjustment__c
            WHERE Id IN :adjs
        ]) {
            System.assertNotEquals(null, a.Distributor_Stock__c,
                'Every adjustment should be linked to a Distributor Stock');
        }

        Integer totalStocks = [
            SELECT COUNT() FROM Distributor_Stock__c
            WHERE Distributor__c = :distributor.Id
            AND Product__c IN :products
        ];
        System.assertEquals(5, totalStocks, 'One Distributor Stock per product, no duplicates');

        for (Distributor_Stock__c ds : [
            SELECT Id, Closing_Stock_Quantity__c
            FROM Distributor_Stock__c
            WHERE Distributor__c = :distributor.Id
            AND Product__c IN :products
        ]) {
            System.assertEquals(20, ds.Closing_Stock_Quantity__c,
                'Both adjustments of a product should roll up into the same stock');
        }
    }

    // ─────────────────────────────────────────
    // Test 5: Distributor Stock Already Set - Left Untouched
    // ─────────────────────────────────────────
    @isTest
    static void testExistingReference_Untouched() {

        Account distributor = getDistributor();
        Product__c product  = getProduct();

        Distributor_Stock__c existingStock = new Distributor_Stock__c(
            Product__c     = product.Id,
            Distributor__c = distributor.Id
        );
        insert existingStock;

        Stock_Adjustment__c adj = new Stock_Adjustment__c(
            Distributor__c            = distributor.Id,
            Product__c                = product.Id,
            Distributor_Stock__c      = existingStock.Id,
            Adjustment_Type__c        = 'Closing Stock',
            Quantity__c               = 30,
            Stock_Adjustment_Date__c  = Date.today()
        );

        Test.startTest();
        insert adj;
        Test.stopTest();

        Stock_Adjustment__c inserted = [
            SELECT Id, Distributor_Stock__c
            FROM Stock_Adjustment__c
            WHERE Id = :adj.Id
        ];
        System.assertEquals(existingStock.Id, inserted.Distributor_Stock__c,
            'Pre-set Distributor Stock reference should be left untouched');
    }
}
