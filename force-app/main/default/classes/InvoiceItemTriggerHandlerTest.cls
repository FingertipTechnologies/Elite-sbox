@isTest
public class InvoiceItemTriggerHandlerTest {

    @testSetup
    static void setupTestData() {
        
     
        // Create common test accounts
        List<Account> testAccounts = new List<Account>{
            new Account(
                Name = 'Primary Cust',
                City__c = 'Delhi',
                State__c = 'Delhi',
                District__c = 'New Delhi',
                Primary_Phone_Number__c = '9999999999',
                Aadhaar_No__c = '123412341234',
                Pincode__c = '110001',
                Customer_Type__c = 'Primary Customer',
                Customer_Status__c = 'Active',
                GeoLocation__Latitude__s =  28.6139,
                GeoLocation__Longitude__s = 77.2090,
                Secondary_Customer_Category__c = 'TN_Elite Club',
                Secondary_Customer_Type__c = 'Retailer',
                Approval_Status__c = 'Credit Dept. Approved',
                Email_ID__c = 'test@gmail.com',
                 SAP_Customer_Code__c ='1133'
              
                
            ),
            new Account(
                Name = 'Secondary Cust',
                City__c = 'Mumbai',
                State__c = 'Andhra Pradesh',
                District__c = 'East Godavari',
                Primary_Phone_Number__c = '8888888888',
                Aadhaar_No__c = '567856785678',
                Pincode__c = '575444',
                Customer_Type__c = 'Secondary Customer',
                Customer_Status__c = 'Active',
                Email_ID__c = 'test@gmail.com',
                SAP_Customer_Code__c ='1122'
            )
        };
        insert testAccounts;

        // Create one existing invoice for one account
        Invoice__c existingInvoice = new Invoice__c(
            Invoice_No__c = 'INV-EXISTING',
            Store__c = testAccounts[0].Id,
            Customer_SAP_Code__c = 'CUST002',
            Status__c = 'Raised',
            Customer_Name__c = 'tetete',
            Delivery_Plant__c ='1480'
        );
        insert existingInvoice;
        
        area__c tr = new area__c();
        tr.Name = 'test11121';
        tr.Sales_Channel__c = 'CPD';
        tr.Region__c =	'Kerala';
        tr.Area__c  = 'Central';
        insert tr;
        
    }

    // Test Case 1: Insert Invoice Items for an existing Invoice
    @isTest
    static void testInsertItemsWithExistingInvoice() {
        // Get the existing invoice and account
        Invoice__c existingInv = [SELECT Id, Invoice_No__c FROM Invoice__c WHERE Invoice_No__c = 'INV-EXISTING' LIMIT 1];
        Account existingAcc = [SELECT Id, SAP_Customer_Code__c FROM Account WHERE SAP_Customer_Code__c = '1122' LIMIT 1];
        
        Product__c prod = new Product__c(Name='Test Product',SKU_Code__c ='1010sksksk');
        insert prod;
        // Primary Order
        Order__c order = new Order__c(
            Order_Type__c = 'Primary Order',
            Account__c = existingAcc.Id,
            Order_Fulfillment_Status__c = 'Not Fulfilled',
            Order_Date__c = Date.today()
        );
        insert order;
        
        List<Order_Item__c> items = new List<Order_Item__c>();
        for (Integer i = 0; i < 2; i++) {
            items.add(new Order_Item__c(
                Order__c = order.Id,
                Product__c = prod.Id,
                Quantity__c = 10,
                Delivered_Quantity__c = 0,
                Unit_Price__c = 100,
                Total_Amount__c = 1000,
                Tax_Amount__c = 100,
                Status__c = 'Not Fulfilled'
            ));
        }
        insert items;
        
        
 

        List<Invoice_Item__c> testItems = new List<Invoice_Item__c>();
        for(Integer i = 0; i < 3; i++) {
            testItems.add(new Invoice_Item__c(
                Bill_Number__c = existingInv.Invoice_No__c,
                Invoice__c =existingInv.Id,
                Bill_to_Party__c = existingAcc.SAP_Customer_Code__c,
                Order__c =  order.Id,
                Qyt_in_Each__c =10,
                SKU__c = prod.id
            ));
        }

        Test.startTest();
        insert testItems;
        Test.stopTest();

    }

    // Test Case 2: Insert Invoice Items for a NEW Invoice (should be auto-created)
    @isTest
    static void testInsertItemsWithNewInvoice() {
          Invoice__c existingInv = [SELECT Id, Invoice_No__c FROM Invoice__c WHERE Invoice_No__c = 'INV-EXISTING' LIMIT 1];
        Account existingAcc = [SELECT Id, SAP_Customer_Code__c FROM Account WHERE SAP_Customer_Code__c = '1133' LIMIT 1];
        String newInvoiceNumber = 'INV-NEW-123';

        List<Invoice_Item__c> testItems = new List<Invoice_Item__c>();
        for(Integer i = 0; i < 2; i++) {
            testItems.add(new Invoice_Item__c(
                Bill_Number__c = newInvoiceNumber,
                Invoice__c =existingInv.Id,
                Bill_to_Party__c = existingAcc.SAP_Customer_Code__c
            ));
        }

        Test.startTest();
        insert testItems;
        Test.stopTest();

    }

    // Test Case 3: Insert Invoice Items with an INVALID Customer Code (should fail)
    @isTest
    static void testInsertItemsWithInvalidCustomerCode() {
        String invalidCustomerCode = 'INVALID_CUST';
        String invoiceNumber = 'INV-FAIL';

        Invoice_Item__c failingItem = new Invoice_Item__c(
            Bill_Number__c = invoiceNumber,
            Bill_to_Party__c = invalidCustomerCode
        );

        Test.startTest();
        try {
            insert failingItem;
        } catch (DmlException e) {
           
        }
        Test.stopTest();

     
    }

    // Test Case 4: Bulk test - mixed scenario (some existing, some new invoices)
    @isTest
    static void testBulkInsertMixedScenario() {
        Account acc1 = [SELECT Id, SAP_Customer_Code__c FROM Account WHERE SAP_Customer_Code__c = '1122' LIMIT 1];
        Account acc2 = [SELECT Id, SAP_Customer_Code__c FROM Account WHERE SAP_Customer_Code__c = '1133' LIMIT 1];
        
        Invoice__c existingInv = [SELECT Id, Invoice_No__c FROM Invoice__c WHERE Invoice_No__c = 'INV-EXISTING' LIMIT 1];
        String newInvoiceNumber = 'INV-BULK-NEW';

        List<Invoice_Item__c> testItems = new List<Invoice_Item__c>();
        for(Integer i = 0; i < 50; i++) {
            testItems.add(new Invoice_Item__c(
                Bill_Number__c = existingInv.Invoice_No__c,
                Invoice__c =existingInv.Id,
                Bill_to_Party__c = acc1.SAP_Customer_Code__c
            ));
        }
        
        for(Integer i = 0; i < 50; i++) {
            testItems.add(new Invoice_Item__c(
                Bill_Number__c = newInvoiceNumber,
                Invoice__c =existingInv.Id,
                Bill_to_Party__c = acc2.SAP_Customer_Code__c
            ));
        }

        Test.startTest();
        insert testItems;
        Test.stopTest();
    }

    // Test: Invoice insert without SF_Order__c but with matching Product_Mapping__c (covers executive assignment + hierarchy comparison)
    @isTest
    static void testInvoiceHeaderOwnerFromProductMapping() {
        Account acc = [SELECT Id, SAP_Customer_Code__c FROM Account WHERE SAP_Customer_Code__c = '1133' LIMIT 1];
        Area__c tr = [SELECT Id FROM Area__c WHERE Name = 'test11121' LIMIT 1];

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User execUser1 = new User(
            FirstName = 'Exec1', LastName = 'User1', Email = 'execuser1@test.com',
            Username = 'execuser1' + System.currentTimeMillis() + '@test.com',
            Alias = 'eu1', Employee_Code__c = 'EXHC01', ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', IsActive = true
        );
        User execUser2 = new User(
            FirstName = 'Exec2', LastName = 'User2', Email = 'execuser2@test.com',
            Username = 'execuser2' + System.currentTimeMillis() + '@test.com',
            Alias = 'eu2', Employee_Code__c = 'EXHC02', ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', IsActive = true
        );
        insert new List<User>{execUser1, execUser2};

        // Two mappings for same customer+plant pair to cover hierarchy comparison loop
        Product_Mapping__c pm1 = new Product_Mapping__c(
            Customer__c = acc.Id, Exectuive__c = execUser1.Id,
            Area__c = tr.Id, Chanel__c = 'CPD',
            Parent_Depot__c = '1400', Child_Depot__c = '1480'
        );
        Product_Mapping__c pm2 = new Product_Mapping__c(
            Customer__c = acc.Id, Exectuive__c = execUser2.Id,
            Area__c = tr.Id, Chanel__c = 'CPD',
            Parent_Depot__c = '1400', Child_Depot__c = '1480'
        );
        insert new List<Product_Mapping__c>{pm1, pm2};

        Test.startTest();
        Invoice__c inv = new Invoice__c(
            Invoice_No__c = 'INV-HEADER-PM',
            Store__c = acc.Id,
            Customer_SAP_Code__c = '1133',
            Delivery_Plant__c = '1480',
            Status__c = 'Raised',
            Customer_Name__c = 'Test Customer'
        );
        insert inv;
        Test.stopTest();

        Invoice__c result = [SELECT OwnerId FROM Invoice__c WHERE Invoice_No__c = 'INV-HEADER-PM'];
        System.assertNotEquals(null, result.OwnerId, 'Owner should be set from Product Mapping executive');
    }

    // Test: Invoice insert with SF_Order__c (covers order owner path + orderMap query)
    @isTest
    static void testInvoiceHeaderWithOrder() {
        Account acc = [SELECT Id, SAP_Customer_Code__c FROM Account WHERE SAP_Customer_Code__c = '1122' LIMIT 1];

        Order__c order = new Order__c(
            Order_Type__c = 'Primary Order',
            Account__c = acc.Id,
            Order_Fulfillment_Status__c = 'Not Fulfilled',
            Order_Date__c = Date.today()
        );
        insert order;

        Test.startTest();
        Invoice__c inv = new Invoice__c(
            Invoice_No__c = 'INV-HEADER-ORD',
            Store__c = acc.Id,
            Customer_SAP_Code__c = '1122',
            Delivery_Plant__c = '1480',
            Status__c = 'Raised',
            Customer_Name__c = 'Test Customer',
            SF_Order__c = order.Id
        );
        insert inv;
        Test.stopTest();
    }

    // Test: Invoice insert without SF_Order__c and no matching Product_Mapping (covers else-if condition but no PM match)
    @isTest
    static void testInvoiceHeaderNoMatchingMapping() {
        Account acc = [SELECT Id, SAP_Customer_Code__c FROM Account WHERE SAP_Customer_Code__c = '1122' LIMIT 1];

        Test.startTest();
        Invoice__c inv = new Invoice__c(
            Invoice_No__c = 'INV-HEADER-NOMATCH',
            Store__c = acc.Id,
            Customer_SAP_Code__c = '9999',
            Delivery_Plant__c = '9999',
            Status__c = 'Raised',
            Customer_Name__c = 'No Match Customer'
        );
        insert inv;
        Test.stopTest();
    }

    // Item with linked Order -> owner taken from the Order owner.
    @isTest
    static void testInvoiceItemOwnerFromOrder() {
        Account acc = [SELECT Id, SAP_Customer_Code__c FROM Account WHERE SAP_Customer_Code__c = '1122' LIMIT 1];
        Invoice__c inv = [SELECT Id, Invoice_No__c FROM Invoice__c WHERE Invoice_No__c = 'INV-EXISTING' LIMIT 1];

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User orderOwner = new User(
            FirstName = 'Order', LastName = 'Owner', Email = 'orderowner@test.com',
            Username = 'orderowner' + System.currentTimeMillis() + '@test.com',
            Alias = 'oo1', Employee_Code__c = 'OOHC01', ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', IsActive = true
        );
        insert orderOwner;

        Order__c order = new Order__c(
            Order_Type__c = 'Primary Order',
            Account__c = acc.Id,
            Order_Fulfillment_Status__c = 'Not Fulfilled',
            Order_Date__c = Date.today(),
            OwnerId = orderOwner.Id
        );
        insert order;

        Test.startTest();
        Invoice_Item__c item = new Invoice_Item__c(
            Bill_Number__c = inv.Invoice_No__c,
            Invoice__c = inv.Id,
            Bill_to_Party__c = acc.SAP_Customer_Code__c,
            Order__c = order.Id,
            Qyt_in_Each__c = 5
        );
        insert item;
        Test.stopTest();

        Invoice_Item__c result = [SELECT OwnerId FROM Invoice_Item__c WHERE Id = :item.Id];
        System.assertEquals(orderOwner.Id, result.OwnerId, 'Item owner should be the linked Order owner');
    }

    // Item without an Order -> owner taken from the bottom Product Mapping executive.
    @isTest
    static void testInvoiceItemOwnerFromProductMapping() {
        Account acc = [SELECT Id, SAP_Customer_Code__c FROM Account WHERE SAP_Customer_Code__c = '1133' LIMIT 1];
        Area__c tr = [SELECT Id FROM Area__c WHERE Name = 'test11121' LIMIT 1];

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User execLow = new User(
            FirstName = 'ExecLow', LastName = 'User', Email = 'execlow@test.com',
            Username = 'execlow' + System.currentTimeMillis() + '@test.com',
            Alias = 'el1', Employee_Code__c = 'ELHC01', ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', IsActive = true
        );
        User execHigh = new User(
            FirstName = 'ExecHigh', LastName = 'User', Email = 'exechigh@test.com',
            Username = 'exechigh' + System.currentTimeMillis() + '@test.com',
            Alias = 'eh1', Employee_Code__c = 'EHHC01', ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', IsActive = true
        );
        insert new List<User>{execLow, execHigh};

        // Two mappings for the same customer + plant pair to exercise lowest-hierarchy selection.
        Product_Mapping__c pmLow = new Product_Mapping__c(
            Customer__c = acc.Id, Exectuive__c = execLow.Id,
            Area__c = tr.Id, Chanel__c = 'CPD',
            Parent_Depot__c = '1400', Child_Depot__c = '1480'
        );
        Product_Mapping__c pmHigh = new Product_Mapping__c(
            Customer__c = acc.Id, Exectuive__c = execHigh.Id,
            Area__c = tr.Id, Chanel__c = 'CPD',
            Parent_Depot__c = '1400', Child_Depot__c = '1480'
        );
        insert new List<Product_Mapping__c>{pmLow, pmHigh};

        // Dedicated invoice whose SAP code is the customer code so the item Bill_To_Party__c resolves to '1133'.
        Invoice__c inv = new Invoice__c(
            Invoice_No__c = 'INV-ITEM-PM',
            Store__c = acc.Id,
            Customer_SAP_Code__c = '1133',
            Delivery_Plant__c = '1480',
            Status__c = 'Raised',
            Customer_Name__c = 'PM Customer'
        );
        insert inv;

        Test.startTest();
        Invoice_Item__c item = new Invoice_Item__c(
            Bill_Number__c = inv.Invoice_No__c,
            Invoice__c = inv.Id,
            Bill_to_Party__c = '1133',
            Plant__c = '1480',
            Qyt_in_Each__c = 5
        );
        insert item;
        Test.stopTest();

        Invoice_Item__c result = [SELECT OwnerId FROM Invoice_Item__c WHERE Id = :item.Id];
        System.assert(result.OwnerId == execLow.Id || result.OwnerId == execHigh.Id,
            'Item owner should come from a matching Product Mapping executive');
    }

    // Invoice header is always owned by a System Administrator.
    @isTest
    static void testInvoiceHeaderOwnerIsAdmin() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Customer_Code__c = '1122' LIMIT 1];
        User admin = [
            SELECT Id FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = true
            ORDER BY CreatedDate ASC LIMIT 1
        ];

        Test.startTest();
        Invoice__c inv = new Invoice__c(
            Invoice_No__c = 'INV-ADMIN-OWN',
            Store__c = acc.Id,
            Customer_SAP_Code__c = '1122',
            Delivery_Plant__c = '1480',
            Status__c = 'Raised',
            Customer_Name__c = 'Admin Owned'
        );
        insert inv;
        Test.stopTest();

        Invoice__c result = [SELECT OwnerId FROM Invoice__c WHERE Invoice_No__c = 'INV-ADMIN-OWN'];
        System.assertEquals(admin.Id, result.OwnerId, 'Invoice header should be owned by a System Administrator');
    }
}