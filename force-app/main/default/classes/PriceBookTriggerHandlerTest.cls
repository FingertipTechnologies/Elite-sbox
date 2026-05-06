@isTest
private class PriceBookTriggerHandlerTest {

    @TestSetup
    static void setupTestData() {
        Account customer = new Account(
            Name = 'Test PriceBook Customer',
            Customer_Type__c = 'Secondary Customer',
            State__c = 'Bihar',
            District__c = 'Patna'
        );
        insert customer;

        Account otherCustomer = new Account(
            Name = 'Test Other Customer',
            Customer_Type__c = 'Secondary Customer',
            State__c = 'Bihar',
            District__c = 'Patna'
        );
        insert otherCustomer;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'PBPartner',
            AccountId = customer.Id
        );
        insert con;

        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(adminUser) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Partner Community User' LIMIT 1];
            String uniqueStr = String.valueOf(DateTime.now().getTime());
            User u = new User(
                FirstName = 'Test', LastName = 'PBCommunity',
                Email = 'pbshare' + uniqueStr + '@test.com',
                Username = 'pbshare' + uniqueStr + '@test.com.pbshare',
                Alias = 'pbpr', TimeZoneSidKey = 'Asia/Kolkata',
                LocaleSidKey = 'en_IN', EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US', ProfileId = p.Id, ContactId = con.Id,
                Employee_Code__c = 'PBEMP' + uniqueStr
            );
            insert u;
        }
    }

    static Account getCustomer() {
        return [SELECT Id FROM Account WHERE Name = 'Test PriceBook Customer' LIMIT 1];
    }

    static Account getOtherCustomer() {
        return [SELECT Id FROM Account WHERE Name = 'Test Other Customer' LIMIT 1];
    }

    @isTest
    static void testHandleAfterInsertWithCustomer() {
        Account customer = getCustomer();

        Test.startTest();
        Price_Book__c pb = new Price_Book__c(
            Customer__c = customer.Id
        );
        insert pb;
        Test.stopTest();

        System.assertNotEquals(null, pb.Id);
    }

    @isTest
    static void testHandleAfterInsertWithoutCustomer() {
        Test.startTest();
        Price_Book__c pb = new Price_Book__c();
        insert pb;
        Test.stopTest();

        System.assertNotEquals(null, pb.Id);
    }

    @isTest
    static void testHandleAfterUpdateCustomerChanged() {
        Account customer = getCustomer();
        Account other = getOtherCustomer();

        Price_Book__c pb = new Price_Book__c(Customer__c = customer.Id);
        insert pb;

        Test.startTest();
        pb.Customer__c = other.Id;
        update pb;
        PriceBookSharingBatch batch = new PriceBookSharingBatch();
        Database.executeBatch(batch, 200);
        
        Test.stopTest();

        Price_Book__c refreshed = [SELECT Customer__c FROM Price_Book__c WHERE Id = :pb.Id];
        System.assertEquals(other.Id, refreshed.Customer__c);
    }

    @isTest
    static void testHandleAfterUpdateCustomerUnchanged() {
        Account customer = getCustomer();

        Price_Book__c pb = new Price_Book__c(Customer__c = customer.Id);
        insert pb;

        Test.startTest();
        pb.MRP__c = 999;
        update pb;
        Test.stopTest();

        Price_Book__c refreshed = [SELECT MRP__c FROM Price_Book__c WHERE Id = :pb.Id];
        System.assertEquals(999, refreshed.MRP__c);
    }

    @isTest
    static void testHandleDirectCallEmptyList() {
        Test.startTest();
        PriceBookTriggerHandler.handle(new List<Price_Book__c>(), null);
        PriceBookTriggerHandler.sharePriceBooksWithPartners(new List<Price_Book__c>());
        Test.stopTest();
    }

    @isTest
    static void testSharePriceBooksWithNoMatchingPartners() {
        Account other = getOtherCustomer();

        Test.startTest();
        Price_Book__c pb = new Price_Book__c(Customer__c = other.Id);
        insert pb;

        PriceBookTriggerHandler.sharePriceBooksWithPartners(
            new List<Price_Book__c>{ pb }
        );
        Test.stopTest();

        System.assertNotEquals(null, pb.Id);
    }

    @isTest
    static void testSharePriceBooksDuplicateShare() {
        Account customer = getCustomer();

        Price_Book__c pb = new Price_Book__c(Customer__c = customer.Id);
        insert pb;

        Test.startTest();
        PriceBookTriggerHandler.sharePriceBooksWithPartners(
            new List<Price_Book__c>{ pb }
        );
        Test.stopTest();
    }

    @isTest
    static void testHandleBulkInsert() {
        Account customer = getCustomer();

        List<Price_Book__c> priceBooks = new List<Price_Book__c>();
        for (Integer i = 0; i < 5; i++) {
            priceBooks.add(new Price_Book__c(
                Customer__c = customer.Id,
                MRP__c = 100 * (i + 1)
            ));
        }

        Test.startTest();
        insert priceBooks;
        Test.stopTest();

        System.assertEquals(5, [SELECT COUNT() FROM Price_Book__c WHERE Customer__c = :customer.Id]);
    }
}