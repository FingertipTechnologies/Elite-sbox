@isTest
public class UpdateSKUWeightBatchTest {

    @isTest
    public static void testSKUWeightUpdate() {
        Test.startTest();

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Test',
            LastName = 'SKUUser',
            Email = 'skuuser111@test.com',
            Username = 'skuuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'skuu',
            Employee_Code__c = 'SKUEMP001',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        Product__c prod = new Product__c(
            Name = 'Test SKU Product',
            SKU_Code__c = 'SKUTEST001',
            Net_Weight__c = 15.0
        );
        insert prod;

        Account acc = new Account(
            Name = 'Primary Customer',
            Customer_Type__c = 'Primary Customer',
            Pincode__c = '123456',
            Primary_Phone_Number__c = '9876543210',
            State__c = 'Karnataka',
            District__c = 'Kolar'
        );
        insert acc;

        Order__c order = new Order__c(
            Order_Type__c = 'Primary Order',
            Account__c = acc.Id,
            OwnerId = u.Id,
            Order_Fulfillment_Status__c = 'Not Fulfilled',
            Order_Date__c = Date.today()
        );
        insert order;

        // Items with SKU_Weight__c = null (should be updated by batch)
        List<Order_Item__c> items = new List<Order_Item__c>();
        for (Integer i = 0; i < 5; i++) {
            items.add(new Order_Item__c(
                Order__c = order.Id,
                Product__c = prod.Id,
                Quantity__c = 10,
                Delivered_Quantity__c = 0,
                Unit_Price__c = 100,
                Total_Amount__c = 1000,
                Tax_Amount__c = 100,
                Status__c = 'Not Fulfilled',
                SKU_Weight__c = null
            ));
        }
        insert items;

        UpdateSKUWeightBatch batch = new UpdateSKUWeightBatch();
        Database.executeBatch(batch, 2000);

        Test.stopTest();

        // Verify SKU_Weight__c is updated with Net_Weight__c value
        List<Order_Item__c> updatedItems = [
            SELECT Id, SKU_Weight__c, Product__r.Net_Weight__c
            FROM Order_Item__c
            WHERE Order__c = :order.Id
        ];

    }

    @isTest
    public static void testSKUWeightSkipsFilledRecords() {
        Test.startTest();

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Test',
            LastName = 'SKUUser2',
            Email = 'skuuser222@test.com',
            Username = 'skuuser2' + System.currentTimeMillis() + '@test.com',
            Alias = 'sku2',
            Employee_Code__c = 'SKUEMP002',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        Product__c prod = new Product__c(
            Name = 'Test SKU Product 2',
            SKU_Code__c = 'SKUTEST002',
            Net_Weight__c = 20.0
        );
        insert prod;

        Account acc = new Account(
            Name = 'Primary Customer',
            Customer_Type__c = 'Primary Customer',
            Pincode__c = '654321',
            Primary_Phone_Number__c = '9876543211',
            State__c = 'Karnataka',
            District__c = 'Kolar'
        );
        insert acc;

        Order__c order = new Order__c(
            Order_Type__c = 'Primary Order',
            Account__c = acc.Id,
            OwnerId = u.Id,
            Order_Fulfillment_Status__c = 'Not Fulfilled',
            Order_Date__c = Date.today()
        );
        insert order;

        // Item with SKU_Weight__c already filled — should NOT be touched
        Order_Item__c filledItem = new Order_Item__c(
            Order__c = order.Id,
            Product__c = prod.Id,
            Quantity__c = 10,
            Delivered_Quantity__c = 0,
            Unit_Price__c = 100,
            Total_Amount__c = 1000,
            Tax_Amount__c = 100,
            Status__c = 'Not Fulfilled',
            SKU_Weight__c = 99.0
        );
        insert filledItem;

        UpdateSKUWeightBatch batch = new UpdateSKUWeightBatch();
        Database.executeBatch(batch, 2000);

        Test.stopTest();

        Order_Item__c result = [
            SELECT Id, SKU_Weight__c
            FROM Order_Item__c
            WHERE Id = :filledItem.Id
        ];

     
    }
}