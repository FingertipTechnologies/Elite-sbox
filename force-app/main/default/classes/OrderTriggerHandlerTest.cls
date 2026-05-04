@isTest
public class OrderTriggerHandlerTest {
    
    @isTest
    public static void testClassMethod(){
        Test.startTest();
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Test',
            LastName = 'User11',
            Email = 'visituser111@test.com',
            Username = 'visituser' + System.currentTimeMillis() + '@test.com',
            Alias = 'vusr',
            Employee_Code__c  = 'sjkhjkj18118',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        
        Product__c prod = new Product__c(Name='Test Product',SKU_Code__c ='1010sksksk');
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
        
        // Primary Order
        Order__c order = new Order__c(
            Order_Type__c = 'Primary Order',
            Account__c = acc.Id,
            OwnerId = u.Id,
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
        
        // Secondary Order
        Order__c order1 = new Order__c(
            Order_Type__c = 'Secondary Order',
            Account__c = acc.Id,
            Status__c = 'New',
            OwnerId = u.Id,
            Order_Fulfillment_Status__c = 'Not Fulfilled',
            Order_Date__c = Date.today(),
            Executive__c = userInfo.getUserId()
        );
        insert order1;
        
        List<Order_Item__c> items1 = new List<Order_Item__c>();
        for (Integer i = 0; i < 2; i++) {
            items1.add(new Order_Item__c(
                Order__c = order1.Id,
                Product__c = prod.Id,
                Quantity__c = 10,
                Delivered_Quantity__c = 0,
                Unit_Price__c = 100,
                Total_Amount__c = 1000,
                Tax_Amount__c = 100,
                Status__c = 'Not Fulfilled'
            ));
        }
        insert items1;
        
     
        
        // Call the handler
        OrderItemTriggerHandler.updateOrderAmount(items1);
        
        Test.stopTest();
        
  
    }
     @isTest
    public static void testClassMethod1(){
        Test.startTest();
        
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Test',
            LastName = 'User11',
            Email = 'visituserSS111@test.com',
            Username = 'visituser' + System.currentTimeMillis() + '@test.com',
            Alias = 'vusr',
            Employee_Code__c  = 'sjkhjkj18118',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        
        Product__c prod = new Product__c(Name='Test Product',SKU_Code__c ='10DD10sksksk');
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
        
        // Primary Order
        Order__c order = new Order__c(
            Order_Type__c = 'Primary Order',
            Account__c = acc.Id,
            OwnerId = u.Id,
            Order_Fulfillment_Status__c = 'Not Fulfilled',
            Order_Date__c = Date.today(),
            Executive__c = userInfo.getUserId()
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
        delete items[0];
        items[1].Quantity__c = 12;
        update   items[1];
        // Create a Daily Log record
        Daily_Log__c log = new Daily_Log__c();
        log.Day_started_time__c = Date.today().addDays(-1);
        log.Clock_Out_Location__Longitude__s =37.7749;
        log.Clock_Out_Location__Latitude__s = 78.4194;
        insert log;
        
            
        // Create Visit record with key fields
        Visit__c visit = new Visit__c(
            //OwnerId = u.Id,
            UniqueFileId__c = 'fileKey123',
            ClockIn_Latitude__c = 12.9716,
            Clockin_Longitude__c = 77.5946,
            Actual_Start_Time__c = System.now(),
            Distance__c = 10,
            Daily_log__c = log.Id
        );
        
       
        insert visit;  
        // Secondary Order
        Order__c order1 = new Order__c(
            Order_Type__c = 'Secondary Order',
            Account__c = acc.Id,
            visit__C = visit.id,
            OwnerId = u.Id,
            Order_Fulfillment_Status__c = 'Not Fulfilled',
            Order_Date__c = Date.today()
        );
        insert order1;
        
            // Secondary Order
        Order__c order2 = new Order__c(
            Order_Type__c = 'Secondary Order',
            Account__c = acc.Id,
            visit__C = visit.id,
            OwnerId = u.Id,
            Order_Fulfillment_Status__c = 'Not Fulfilled',
            Order_Date__c = Date.today()
        );
        insert order2;
        
        delete order1;
        DailyLogOrderAmountBatch bt = new DailyLogOrderAmountBatch();
        database.executeBatch(bt,200);
        UpdateSKUWeightBatch batch = new UpdateSKUWeightBatch();
        Database.executeBatch(batch, 2000);


        
        Test.stopTest();
        
  
    }
    
}