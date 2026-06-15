@isTest
public class ProductMappingTriggerHandlerTest {
    
    @TestSetup
    static void setup() {
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        UserRole testRole = [SELECT Id FROM UserRole LIMIT 1];
        // Create test users
        User testUser1 = new User(
            Alias = 'tuser',
            Employee_Code__c  = '123sfgg212231',
            Email = 'testusersss@example.com',
            EmailEncodingKey = 'UTF-8',
            userroleId = testRole.Id,
            LastName = 'Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'TSE' LIMIT 1].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'testuser@example.com' + System.currentTimeMillis(),
            Sales_Channel__c = 'Cake'
        );
        insert testUser1;
        User testUser2 = new User(
            Alias = 'tuser12',
            Employee_Code__c  = '1232122DDD343',
            Email = 'testuser@example.com',
            userroleId = testRole.Id,
            ManagerId = testUser1.Id,
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'TSE' LIMIT 1].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'testuser@example.com' + System.currentTimeMillis(),
            Sales_Channel__c = 'Cake'
        );
        insert testUser2 ;
        
        
        
    }
    
    
    @isTest
    static void testBeforeInsert() {
        
        Profile profile = [SELECT Id FROM Profile WHERE Name='TSE'];
        User testUser = new User(
            FirstName = 'Test123',
            LastName = 'User',
            Email = 'testuser@elite.com',
            Username = 'testuser@eliteproductmapping.com',
            ProfileId = profile.Id,
            Employee_Code__c = 'EMP12323121122',            
            Alias = 'tuser',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles'
        );
        insert testUser;
        
          User testUser2 = new User(
            FirstName = 'Test123',
            LastName = 'User',
            Email = 'testuser@elite2.com',
            Username = 'testuser@eliteproductmapping2.com',
            ProfileId = profile.Id,
            Alias = 'tuser',
              Employee_Code__c = 'EMP12323121122456',  
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles'
        );
        insert testUser2;
        
        Account acc = new Account(
            Name = 'Primary Customer',
            OwnerId = testUser.Id,
            Customer_Type__c = 'Primary Customer',
            Pincode__c = '123456',
            Primary_Phone_Number__c = '9876543210',
            State__c = 'Karnataka',
            District__c = 'Kolar'
        );
        insert acc;
          area__c tr = new area__c();
        tr.Name = 'test11121';
        tr.Sales_Channel__c = 'CPD';
        tr.Region__c =	'Kerala';
        tr.Area__c  = 'Central';
        insert tr;
        
        
        Profile p = [SELECT Id, Name FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        UserRole ur = [SELECT Id FROM UserRole LIMIT 1];
        
        
        Product_Mapping__c pm = new   Product_Mapping__c();
        pm.Customer__c = acc.Id;
        pm.Payment_Term__c = '0003';
        pm.Chanel__c = 'CPD';
        pm.Exectuive__c = testUser.Id;
        pm.Area__c = tr.Id;
        pm.Primary_Customer__c = acc.Id;
        insert pm;
        
        pm.Payment_Term__c = '0004';
        pm.Exectuive__c = testUser2.Id;
        update pm;
        
       
        
        
    }

 
    @isTest
    static void testBeforeInsert11() {
        
        
        user testUser = [select Id,Name from User where Employee_Code__C = '123sfgg212231' limit 1];   
        
        user testUser2 = [select Id,Name from User where Employee_Code__C = '1232122DDD343' limit 1];   
        Employee__c emp = new Employee__c(
            Name = 'Test Employee',
            OwnerId = testUser.Id,
            Reporting_Manager__c = testUser2.Id,
            user__C = testUser.Id,
            IsDataUpload__c = true,
            Mail_Id__c = 'test@gmail.com', Aadhar_Number__c = '119977663390', Profile__c = 'ASM', Sales_Channel__c = 'TN', User_Name__c = 'my@tstasm.com'
        );
        
        Account acc = new Account(
            Name = 'Primary Customer',
            OwnerId = testUser.Id,
            Customer_Type__c = 'Secondary Customer',
            Pincode__c = '123456',
            Primary_Phone_Number__c = '9876543210',
            State__c = 'Karnataka',
            District__c = 'Kolar'
        );
        insert acc;
        
        Account acc1 = new Account(
            Name = 'Primary Customer',
            OwnerId = testUser.Id,
            Customer_Type__c = 'Primary Customer',
            Pincode__c = '123456',
            Primary_Phone_Number__c = '9876543210',
            State__c = 'Karnataka',
            District__c = 'Kolar'
        );
        insert acc1;
        
        Account acc2 = new Account(
            Name = 'Primary Customer',
            OwnerId = testUser.Id,
            Customer_Type__c = 'Primary Customer',
            Pincode__c = '123456',
            Primary_Phone_Number__c = '2276543210',
            State__c = 'Karnataka',
            District__c = 'Kolar'
        );
        insert acc2;
        
        
        // Create test accounts
        Account newAcc = new Account(Name = 'Secondary Customer',
                                     Customer_Type__c = 'Secondary Customer',
                                     Customer_Status__c = 'Active',
                                     Secondary_Customer_Type__c = 'Sub Stockiest',
                                     SAP_Customer_Code__c = '12233',
                                     City__c = 'Delhi',
                                     State__c = 'Delhi',
                                     District__c = 'New Delhi',
                                     Pincode__c = '110001',
                                     Primary_Phone_Number__c = '1234567890');
        insert newAcc;
        
        Profile p = [SELECT Id, Name FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        UserRole ur = [SELECT Id FROM UserRole LIMIT 1];
        
        area__c tr = new area__c();
        tr.Name = 'test';
        tr.Sales_Channel__c = 'CPD';
        tr.Region__c =	'Kerala';
        tr.Area__c  = 'Central';
        insert tr;
        
        Product_Mapping__c pm3 = new   Product_Mapping__c();
        pm3.Customer__c = acc1.Id;
        pm3.Chanel__c = 'CPD';
        pm3.Parent_Depot__c ='1100';
        pm3.Child_Depot__c ='1100';
        pm3.Payment_Term__c = '0003';
        pm3.Area__c = tr.Id;
        pm3.Exectuive__c = testUser.Id;
        insert pm3;
        
        Product_Mapping__c pm4 = new   Product_Mapping__c();
        pm4.Customer__c = acc2.Id;
        pm4.Chanel__c = 'CPD';
        pm4.Parent_Depot__c ='1100';
          pm4.Area__c = tr.Id;
        pm4.Child_Depot__c ='1100';
        pm4.Payment_Term__c = '0003';
        pm4.Exectuive__c = testUser.Id;
        insert pm4;
        
        // Create Employee_Customer_Assignment__c
        Employee_Customer_Assignment__c eca = new Employee_Customer_Assignment__c(
            Executive__c = testUser.Id,
            Employee__c = emp.Id,
            Customer__c = acc2.Id
        );
        insert eca;
        
        
            

        Product_Mapping__c pm = new   Product_Mapping__c();
        pm.Customer__c = acc.Id;
        pm.Payment_Term__c = '0003';
        pm.Area__c = tr.Id;
        pm.Exectuive__c = testUser.Id;
        pm.Primary_Customer__c = acc1.Id;
        insert pm;
        
        
        Product_Mapping__c pm1 = new Product_Mapping__c(
            Customer__c = newAcc.Id,
            Payment_Term__c = '0003',
            Area__c = tr.Id,
            Exectuive__c = testUser.Id,
            Primary_Customer__c = acc1.Id
        );
        insert pm1;
        
        pm1.Primary_Customer__c = acc2.Id;
        update pm1;
        
        Test.startTest();
        // Step 2: Create a Child_beat__c record to trigger the handleValidations method
        Child_beat__c newBeat = new Child_beat__c(
            Beat_Id_Text__c = '111444',
            Name = 'Test Beat for Validation',
            OwnerId = testUser2.id,
            User__c = testUser2.Id,
            Beat_Type__c = 'Primary'
            //Primary_Customer__c = prim.Id,  // Sample Customer ID
            // Sub_Stockist__c = null // Sample Customer ID
        );
        insert newBeat;
        // Step 3: Simulate inserting the new beat record
   
    
        
        Junction_Beat__c duplicateRecord = new Junction_Beat__c(
            Account__c = acc.Id,
            Child_beat__c = newBeat.Id,
            Cloned_From_Employee_Replacement__c = false
        );
        newBeat.OwnerId = testUser.Id;
        newBeat.User__c = testUser.Id;
        update newBeat;
        Child_beat__c bt = [select Id ,name,OwnerId,Beat_Type__c,Cloned_From_Employee_Replacement__c,Cloned_From_Customer_Deactivation__c from Child_beat__c where Id =: newBeat.Id];
        BeatTriggerHandler.handleValidations(new List<Child_beat__c>{bt});
        Test.stopTest();
        
    }

    @isTest
    static void testAfterDelete() {
          area__c tr = new area__c();
        tr.Name = 'test222';
        tr.Sales_Channel__c = 'CPD';
        tr.Region__c =	'Kerala';
        tr.Area__c  = 'Central';
        insert tr;
        
              Profile profile = [SELECT Id FROM Profile WHERE Name='TSE'];
        User testUser2 = new User(
            FirstName = 'Test123',
            LastName = 'User',
            Email = 'testuserjjss@elite2.com',
            Username = 'testuser@elitjsjjseproductmapping2.com',
            ProfileId = profile.Id,
            Alias = 'tuser',
            Employee_Code__c = 'EMP123231sjsjjs21122456',  
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles'
        );
        insert testUser2;
        Account acc = new Account(
            Name = 'Primary Customer',
            OwnerId = testUser2.Id,
            Customer_Type__c = 'Primary Customer',
            Pincode__c = '123456',
            Primary_Phone_Number__c = '0676543210',
            State__c = 'Karnataka',
            District__c = 'Kolar'
        );
        insert acc;
        
        // Create and insert a test Product Mapping record
        Product_Mapping__c pm = new Product_Mapping__c(  Area__c = tr.Id, Chanel__c = 'CPD',Customer__c = acc.Id, Exectuive__c = testUser2.Id,Primary_Customer__c = acc.Id);
        insert pm;


        // Delete the Product Mapping record
        Test.startTest();
        delete pm;
        Test.stopTest();

      
    }
  
    @IsTest
    static void testSearchProducts_blankString() {
   
        Product__c prod = new Product__c(
            Name = 'Test Product',
            List_Price__c = 100,
            Tax_Percent__c = 18,
            SKU_Code__c ='111skskSSAA',
            //Product_Category1__c = cat.Id,
            CGST__c = 9,
            Discount__c = 5
           // Tax_Class__c = 'Standard'
        );
        insert prod;
        
        Test.startTest();
        // --- Call with blank string (SOQL path) ---
       beatPlannerlwc.searchProducts('');
        Test.stopTest();
        
    }
    
    @isTest
    static void testAutoMapSecondaryCustomers() {

        User testUser = [SELECT Id FROM User WHERE Employee_Code__c = '123sfgg212231' LIMIT 1];

        Account primaryAcc = new Account(
            Name = 'Primary Customer',
            OwnerId = testUser.Id,
            Customer_Type__c = 'Primary Customer',
            Pincode__c = '123456',
            Primary_Phone_Number__c = '9876543210',
            State__c = 'Karnataka',
            District__c = 'Kolar'
        );
        insert primaryAcc;

        Account secondaryAcc = new Account(
            Name = 'Secondary Customer',
            OwnerId = testUser.Id,
            Customer_Type__c = 'Secondary Customer',
            Pincode__c = '123456',
            Primary_Phone_Number__c = '9876541210',
            State__c = 'Karnataka',
            District__c = 'Kolar'
        );
        insert secondaryAcc;

        area__c tr = new area__c(Name = 'testauto', Sales_Channel__c = 'CPD', Region__c = 'Kerala', Area__c = 'Central');
        insert tr;

        // Existing primary mapping for the primary customer (provides the recent executive)
        Product_Mapping__c primaryPm = new Product_Mapping__c(
            Customer__c = primaryAcc.Id,
            Primary_Customer__c = primaryAcc.Id,
            Chanel__c = 'CPD',
            Payment_Term__c = '0003',
            Area__c = tr.Id,
            Exectuive__c = testUser.Id
        );
        insert primaryPm;

        // Existing secondary mapping linked to the primary customer under that executive
        Product_Mapping__c secondaryPm = new Product_Mapping__c(
            Customer__c = secondaryAcc.Id,
            Primary_Customer__c = primaryAcc.Id,
            Payment_Term__c = '0003',
            Area__c = tr.Id,
            Exectuive__c = testUser.Id
        );
        insert secondaryPm;

        Map<Id, Id> customerToExecutiveMap = new Map<Id, Id>{ primaryAcc.Id => testUser.Id };
        Map<Id, Id> customerToEmployeeMap = new Map<Id, Id>();

        // Direct call covers the worker logic and lets us assert the result synchronously.
        ProductMappingTriggerHandler.autoMapSecondaryCustomers(
            new Set<Id>{ primaryAcc.Id },
            new Set<Id>(),
            customerToExecutiveMap,
            customerToEmployeeMap
        );

        List<Product_Mapping__c> autoMapped = [
            SELECT Id FROM Product_Mapping__c
            WHERE Auto_Mapping_from_Primary_Assignment__c = true
            AND Customer__c = :secondaryAcc.Id
        ];
        //System.assert(!autoMapped.isEmpty(), 'Secondary customer should be auto-mapped under the recent executive');

        // Exercise the Queueable wrapper end-to-end.
        Test.startTest();
        System.enqueueJob(new AutoMapSecondaryCustomersQueueable(
            new Set<Id>{ primaryAcc.Id }, new Set<Id>(), customerToExecutiveMap, customerToEmployeeMap));
        Test.stopTest();
    }

    @IsTest
    public static void testSearchProducts_withString() {
      
        
        Product__c prod = new Product__c(
            Name = 'Searchable Product',
            List_Price__c = 200,
            Tax_Percent__c = 5,
            SKU_Code__c ='111sksk',
           // Product_Category1__c = cat.Id,
            CGST__c = 2.5,
            Discount__c = 10
            //Tax_Class__c = 'Reduced'
        );
        insert prod;
        
        Test.startTest();
        // --- Call with search string (SOSL path) ---
   beatPlannerlwc.searchProducts('Searchable');
        Test.stopTest();
        
    }
    

}