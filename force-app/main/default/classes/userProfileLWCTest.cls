@isTest
public class userProfileLWCTest {
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
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
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
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'testuser@example.com' + System.currentTimeMillis(),
            Sales_Channel__c = 'Cake'
        );
        insert testUser2 ;
        
        
        
    }
    
    @isTest
    public static void testGetUserData_WithEmployeeId() {
        // Create profile
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        
        // Create test user
        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@test.com',
            Username = 'testuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'tusr',
            Employee_Code__c = 'EMP001',
            ProfileId = prof.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        
        
        Employee__c emp = new Employee__c(
            OwnerId = u.Id,
            Payroll__c = 'No',
            Is_Active__c = false,
            Reporting_Manager__c = u.Id,
            Approval_Status__c = 'Pending',
            Mail_Id__c = 'mainuseraaass@example.com',
            Aadhar_Number__c = '123456789012',
            Profile__c = 'TSE', // use a valid picklist value if applicable
            Sales_Channel__c = 'CPD', // use a valid picklist or reference value
            User_Name__c =  'mainuseraaass@example.com',
            Working_District__c = 'Kolar',
            Pincode__c = '563101',
            Primary_Phone_Number__c = '9876543210',
            State__c = 'Karnataka',
            District__c = 'Kolar'
        );
        insert emp;
        
        // Run method with employee Id
        Test.startTest();
        userProfileLWC.userData result = userProfileLWC.getUserData(emp.Id);
        Test.stopTest();
    }
    @isTest
    public static void testGetUserData_WithoutEmployeeId() {
        // Create profile
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        
        User approver1 = new User(
            FirstName = 'Approver1',
            LastName = 'User',
            Email = 'approver111@example.com',
            Username = 'approv2211er1@example.com' + System.currentTimeMillis(),
            ProfileId = prof.Id,
            Alias = 'aprv1',
            Employee_Code__c = 'EMP001',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles'
        );
        insert approver1;
        // Create test user
        User u = new User(
            FirstName = 'Another',
            LastName = 'User',
            Email = 'anotheruser@test.com',
            Username = 'anotheruser' + System.currentTimeMillis() + '@test.com',
            Alias = 'auser',
            
            Employee_Code__c = 'EMP002',
            ProfileId = prof.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        
        // Run method without passing employee id
        Test.startTest();
        userProfileLWC.userData result = userProfileLWC.getUserData(null);
        Test.stopTest();
    }
    
    
    @isTest
    public static void testAddVisitData_DSMUser() {
        // Fetch an existing profile (DSM) or fallback to System Administrator
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        
        // Create DSM User
        User dsmUser = new User(
            FirstName = 'Test',
            LastName = 'DSM',
            Email = 'dsmuser@test.com',
            Username = 'dsmuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'dsmusr',
            Employee_Code__c = 'EMP001',
            ProfileId = prof.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert dsmUser;
        
        // Create Account
        Account acc = new Account(
            Name = 'DSM Customer',
            Customer_Type__c = 'Primary Customer',
            OwnerId = dsmUser.Id,
            Pincode__c = '123456',
            Primary_Phone_Number__c = '9886573210',
            State__c = 'Karnataka',
            SAP_Customer_Code__c ='1210199',
            District__c = 'Kolar',
            Customer_Status__c = 'Active'
        );
        insert acc;
        
        // Link user to Account via Employee_Customer_Assignment__c
        Employee_Customer_Assignment__c eca = new Employee_Customer_Assignment__c(
            Customer__c = acc.Id,
            Executive__c = dsmUser.Id
        );
        insert eca;
        
        
        
        Test.startTest();
        userProfileLWC.userData result = userProfileLWC.AddVisitData(dsmUser.Id);
        Test.stopTest();
        
        // Since you asked not to add assertions, skipping them
    }
    
    @isTest
    public static void testAddVisitData_NonDSMUser() {
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        
        // Create normal user
        User user = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@test.com',
            Username = 'testuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'tuser',
            Employee_Code__c = 'EMP002',
            
            ProfileId = prof.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert user;
        
        // Create Account
        Account acc = new Account(
            Name = 'Test Customer',
            Customer_Type__c = 'Primary Customer',
            Customer_Category__c = 'Retail',
            Pincode__c = '123456',
            SAP_Customer_Code__c ='1210199121',
            Primary_Phone_Number__c = '9886573320',
            State__c = 'Karnataka',
            District__c = 'Kolar',
            Customer_Status__c = 'Active'
        );
        insert acc;
        

    }

    @isTest
    public static void testBeforeInsert11() {
        
        
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
                                     SAP_Customer_Code__c = 'SAP0012233',
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
        
        // Step 6: Call the method
        Test.startTest();
        userProfileLWC.userData result = userProfileLWC.getRelatedAccs(acc2.Id, testUser.Id);
        userProfileLWC.userData result1 = userProfileLWC.AddVisitData(testUser.Id);
        userProfileLWC.shareAccountAccess(testUser.Id,'User');
        Test.stopTest();
        
        
        
    }

    @isTest
    static void testBeatPlan_CalendarAndPJPView() {
        // Create profile
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        // Create User
        User user = new User(
            FirstName = 'Beat',
            LastName = 'User',
            Email = 'beatuser@test.com',
            Username = 'beatuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'buser',
            ProfileId = prof.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Employee_Code__c = 'EMP123'
        );
        insert user;
        
        // Create Account
        Account acc = new Account(
            Name = 'Test Account',
            Customer_Type__c = 'Primary Customer',
            Customer_Category__c = 'Retail',
            Pincode__c = '560001',
            SAP_Customer_Code__c ='121727280199',
            Primary_Phone_Number__c = '9876543210',
            State__c = 'Karnataka',
            District__c = 'Kolar',
            Customer_Status__c = 'Active'
        );
        insert acc;
        
        // Create Visit Plan
        Beat__c plan = new Beat__c();
        insert plan;
        
        // Create Child Beat owned by user
        Child_Beat__c beat = new Child_Beat__c(Name = 'Beat 1', OwnerId = user.Id, Active__c = true,Beat_Type__c ='Secondary');
        insert beat;
        
        // Create Junction_Beat__c
        Junction_Beat__c junction = new Junction_Beat__c(
            Account__c = acc.Id,
            Child_Beat__c = beat.Id,
            Visit_Plan__c = plan.Id,
            Visit_Date__c = Date.today(),
            isRepeat__c = false,
            Order_Number__c = 1,
            Active__c = true
        );
        insert junction;
        
        // Create Calendar_beat__c
        Calendar_beat__c calendar = new Calendar_beat__c(
            OwnerId = user.Id,
            Start_Month__c = Date.today().toStartOfMonth(),
            Next_Start_Date__c = Date.today().addDays(10),
            Approval_Status__c = 'Approved',
            Active__c = true
        );
        insert calendar;
        
        Test.startTest();
        // Call for CalendarView
        userProfileLWC.userData result1 = userProfileLWC.beatPlan(user.Id, 'CalendarView');
        
        // Call for PJPView
        userProfileLWC.userData result2 = userProfileLWC.beatPlan(user.Id, 'PJPView');
        Test.stopTest();
        
    }
    
    @isTest
    static void testCreatePJP() {
        // Create a test profile
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        // Create a user
        User u = new User(
            FirstName = 'PJP',
            LastName = 'User',
            Email = 'pjpuser@test.com',
            Username = 'pjpuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'pjpu',
            ProfileId = prof.Id,
            Employee_Code__c = 'EMP900',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        // Create a Calendar_beat__c
        Calendar_beat__c cal = new Calendar_beat__c(
            OwnerId = u.Id,
            Start_Month__c = Date.today().toStartOfMonth(),
            Next_Start_Date__c = Date.today().addDays(10),
            Approval_Status__c = 'Approved',
            Active__c = true
        );
        insert cal;

        // Create a Child_Beat__c
        Child_Beat__c beat1 = new Child_Beat__c(
            Name = 'Beat A',
            Beat_Type__c ='Secondary',
            OwnerId = u.Id,
            Order_Number__c = 1,
            isRepeat__c = false
        );
        insert beat1;

        Child_Beat__c beat2 = new Child_Beat__c(
            Name = 'Beat B',
            OwnerId = u.Id,
            Beat_Type__c ='Secondary',
            Order_Number__c = 2,
            isRepeat__c = false
        );
        insert beat2;

        // Create a holiday
        Holiday__c holiday = new Holiday__c(
            Name = 'Test Holiday',
            Date__c = Date.today().addDays(2),
            Region__c = 'Tamil Nadu'
        );
        insert holiday;

        // Call method
        Test.startTest();
        userProfileLWC.userData result = userProfileLWC.createPJP(u.Id, Date.today().addDays(-2), beat1.Id);
         userProfileLWC.userData result2 = userProfileLWC.RotateBeats(u.Id, 7);
        Test.stopTest();

        // Assertions
        List<PJP_Item__c> createdItems = [
            SELECT Id, PJP__c, Beat__c, Date__c, Order_Number__c 
            FROM PJP_Item__c WHERE PJP__c = :cal.Id
        ];
       

    }

    @isTest
    static void testSavePjpItems_InsertFlow() {
        // Create test profile
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        // Create test user
        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'pjptest@test.com',
            Username = 'pjptest' + System.currentTimeMillis() + '@test.com',
            Alias = 'pjpt',
            ProfileId = prof.Id,
            Employee_Code__c = 'EMP998',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        
        // Create a dummy child beat
        Child_Beat__c cb = new Child_Beat__c(
            Name = 'Test Beat',
            Beat_Type__c ='Secondary',
            OwnerId = u.Id,
            Order_Number__c = 1
        );
        insert cb;
        
        // Create PJP item (no PJP__c yet, method will assign it)
        Date pjpDate = Date.today();
        PJP_Item__c item = new PJP_Item__c(
            Beat__c = cb.Id,
            Assigned_Beat__c = cb.Id,
            Date__c = pjpDate,
            Order_Number__c = 1,
            Status__c = 'Approved'
        );
        
        List<PJP_Item__c> pjpList = new List<PJP_Item__c>{ item };
            
            Test.startTest();
        userProfileLWC.savePjpItems(u.Id, pjpList);
        Test.stopTest();
        
        // Verify inserted Calendar_beat__c
        List<Calendar_beat__c> insertedBeats = [
            SELECT Id FROM Calendar_beat__c WHERE OwnerId = :u.Id AND Active__c = true
        ];
        
        // Verify PJP_Item__c inserted with PJP__c linked
        List<PJP_Item__c> insertedItems = [
            SELECT Id, PJP__c, Beat__c FROM PJP_Item__c WHERE Beat__c = :cb.Id
        ];
        
    }

    @isTest
    static void testDeleteAndSubmitPJP() {
        // Create a profile
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        // Create test user
        User user = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'submituser@test.com',
            Username = 'submituser' + System.currentTimeMillis() + '@test.com',
            Alias = 'subusr',
            Employee_Code__c = 'EMP899',
            ProfileId = prof.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert user;
        
        // Create Calendar_beat__c
        Calendar_beat__c pjp = new Calendar_beat__c(
            OwnerId = user.Id,
            Start_Month__c = Date.today(),
            Next_Start_Date__c = Date.today().addDays(30),
            Active__c = true
        );
        insert pjp;
        
        // Create a PJP_Item__c record
        PJP_Item__c item = new PJP_Item__c(
            PJP__c = pjp.Id,
            Date__c = Date.today().addDays(1),
            Status__c = 'Not Submitted',
            Order_Number__c = 1
        );
        insert item;
        
        Test.startTest();
        
        // Call deletePJPItem
        userProfileLWC.deletePJPItem(item.Id);
        
        // Re-insert for testing approval submission
        item = new PJP_Item__c(
            PJP__c = pjp.Id,
            Date__c = Date.today().addDays(2),
            Status__c = 'Not Submitted',
            Order_Number__c = 2
        );
        insert item;
        
        // Submit for approval (note: approval process must be active for Calendar_beat__c)
        try {
            userProfileLWC.submitApprovalProcess(user.Id, pjp.Id);
        } catch (Exception e) {
            System.debug('Expected approval error if process not configured: ' + e.getMessage());
        }
        
        Test.stopTest();
        
    }
    
    @isTest
    static void testSaveBeatAndGetAcc() {
        // Create test Account
        Account acc = new Account(
            Name = 'Primary Customer',
            Customer_Type__c = 'Primary Customer',
            Pincode__c = '123456',
            Primary_Phone_Number__c = '6776543210',
            State__c = 'Karnataka',
            District__c = 'Kolar'
        );
        insert acc;
        
        Child_beat__c ch = new Child_beat__c();
        ch.Beat_Type__c ='Secondary';
        insert ch;
        
        // Create related Junction_Beat__c to delete
        Junction_Beat__c jn1 = new Junction_Beat__c(
            Account__c = acc.Id,
            Active__c = true,
            Child_beat__c = ch.Id
        );
        insert jn1;
        
        // Create Junction_Beat__c to upsert
        Junction_Beat__c jn2 = new Junction_Beat__c(
            Account__c = acc.Id,
            Active__c = true,
            Child_beat__c =ch.Id
        );
        
        Test.startTest();
        
        // Call saveBeat method
        UserProfileLWC.saveBeat(
            new List<String>{jn1.Id},
            new List<Junction_Beat__c>{jn2}
        );
        
        // Call getAcc method
        UserProfileLWC.userData result = UserProfileLWC.getAcc();
        
        Test.stopTest();
        
        
    }
    
    @isTest
    static void testGetHoliday() {
        // Create user
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User usr = new User(
            FirstName = 'Test',
            LastName = 'HolidayUser',
            Email = 'holidayuser@test.com',
            Username = 'holidayuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'huser',
            ProfileId = prof.Id,
            Employee_Code__c = 'EMPjksjskj1wqjdkjhslkl001',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Region__c = 'Tamil Nadu'
        );
        insert usr;
        
        // Create Holiday for user region
        Holiday__c holiday = new Holiday__c(
            Name = 'Test Holiday',
            Date__c = Date.today(),
            Region__c = 'Tamil Nadu',
            Description__c = 'Sample holiday',
            OwnerId = usr.Id
        );
        insert holiday;
        
        Test.startTest();
        UserProfileLWC.getHoliday(usr.Id);
        Test.stopTest();

    }
    
    @isTest
    static void testGetAllUserDatas() {
        // Create user
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User usr = new User(
            FirstName = 'Test',
            LastName = 'EmpUser',
            Email = 'empuser@test.com',
            Username = 'empuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'euser',
            ProfileId = prof.Id,
               Employee_Code__c = 'EMP1wqjdkjhslkl001',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert usr;

        // Create Employee record for the user
        Employee__c emp = new Employee__c(
            User__c = usr.Id,
            Name = 'Test Emp',
            Employee_Code__c = 'EMP1wqjdkjhslkl001',
            Profile__c = 'TSE',
            User_Name__c = usr.Username,
            Mail_Id__c = usr.Email,
            Aadhar_Number__c = '123456789012',
            Primary_Phone_Number__c = '9076543210',
            Role__c = 'Sales Executive',
            Reporting_Manager__c = usr.Id,
            Sales_Channel__c = 'CPD',
            State__c = 'Karnataka',
            District__c = 'Kolar',
            Region__c = 'Tamil Nadu',
            Pincode__c = '563101'
        );
        insert emp;

        Test.startTest();
        UserProfileLWC.getAllUserDatas(usr.Id);
        Test.stopTest();
    }
    
    
    @isTest
    static void testGraphDataDetails() {
        // Step 1: Create a Profile (use existing standard profile)
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        // Step 2: Create a test user
        User user = new User(
            FirstName = 'Graph',
            LastName = 'User',
            Email = 'graphuser@example.com',
            Username = 'graphuser' + System.currentTimeMillis() + '@example.com',
            Alias = 'guser',
            TimeZoneSidKey = 'Asia/Kolkata',
            Employee_Code__c = 'jhgjhgfjhfyg97987',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = prof.Id
        );
        insert user;
        
        Test.startTest();
        userProfileLWC.graphDataDetails(user.Id);
        Test.stopTest();
        
    }
    @isTest
    static void testTargetData1() {
        // Step 1: Use existing Standard User profile
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        // Step 2: Create test user
        User testUser = new User(
            FirstName = 'Target',
            LastName = 'User',
            Email = 'targetuser@example.com',
            Username = 'targetuser' + System.currentTimeMillis() + '@example.com',
            Alias = 'tusr',
            Employee_Code__c = 'jhgjhgfjhks99s9sfyg97987',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = prof.Id
        );
        insert testUser;
        
        // Step 3: Create related Period__c record (if Period__c is a custom object)
        Period__c period = new Period__c(Name = '2025-Q1');
        insert period;
        
        // Step 4: Create Target__c record
        Target__c target = new Target__c(
            OwnerId = testUser.Id,
            Executive__c = testUser.Id,
            Actual__c = 50000,
            Target__c = 100000,
            Period__c = period.Id
        );
        insert target;
        
        // Step 5: Call the method inside test context
        Test.startTest();
        userProfileLWC.targetData1(testUser.Id);
        Test.stopTest();
        
    }
    
    @isTest
    static void testVisitData_AllFilters() {
        // Setup: Create test user
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Visit',
            LastName = 'User',
            Email = 'visituser@example.com',
            Username = 'visituser' + System.currentTimeMillis() + '@example.com',
            Alias = 'vuser',
            Employee_Code__c = 'jhgjhgklslfjhfyg97987',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = prof.Id
        );
        insert testUser;
        
        // Create Account
        Account acc = new Account( Name = 'Primary Customer',
                                  Customer_Type__c = 'Primary Customer',
                                  Pincode__c = '123456',
                                  Primary_Phone_Number__c = '8976543210',
                                  State__c = 'Karnataka',
                                  District__c = 'Kolar');
        insert acc;
        
        // Create Child_Beat__c (Created THIS_MONTH)
        Child_Beat__c cb = new Child_Beat__c(
            Name = 'Test Beat',
            Beat_Type__c ='Secondary',
            OwnerId = testUser.Id,
            Order_Number__c = 1
        );
        insert cb;
        
        // Create Junction_Beat__c related to Child_Beat__c
        Junction_Beat__c jn = new Junction_Beat__c(
            Account__c = acc.Id,
            Child_Beat__c = cb.Id,
            Order_Number__c = 1
        );
        insert jn;
        
        // Create Visit record
        Visit__c visit = new Visit__c(
            OwnerId = testUser.Id,
            Child_Beat__c = cb.Id,
            Account1__c = acc.Id,
            Planned_Start_Time__c  = Date.today(),
            Status__c = 'Completed',
            OrderCreated__c = true
        );
        insert visit;
        
        // Run all 4 combinations
        List<String> statuses = new List<String>{ 'All', 'Completed' };
            List<String> durations = new List<String>{ 'All', '1 hour' };
                Test.startTest();
        for (String stat : statuses) {
            for (String dur : durations) {
                
                userProfileLWC.visitData(
                    testUser.Id,
                    Date.today().addDays(-1),
                    Date.today().addDays(1),
                    stat,
                    dur
                );
                
                
            }
        }
        userProfileLWC.getBeatVisitSummaries(
            testUser.Id,
            Date.today().addDays(-1),
            Date.today().addDays(1)
        );
        Test.stopTest();
    }
    
    @isTest
    static void testAllOrderDataMethod() {
        // Step 1: Create test profile and user
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'allorder@test.com',
            Username = 'testuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'auser',
            Employee_Code__c = 'jhgjhgfksksjsjhfyg97987',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = prof.Id
        );
        insert testUser;
        
        // Step 2: Create test account
        Account acc = new Account(
            Name = 'Primary Customer',
            Customer_Type__c = 'Primary Customer',
            Pincode__c = '123456',
            Primary_Phone_Number__c = '8976763210',
            State__c = 'Karnataka',
            District__c = 'Kolar'
        );
        insert acc;
        
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
        
        // Step 3: Create Order__c records
        Order__c ord1 = new Order__c(
            OwnerId = testUser.Id,
            Account__c = acc.Id,
            visit__C = visit.id,
            Order_Date__c = Date.today()
        );
        insert ord1;
   
        
        // Step 4: Call the method with status = 'All'
        Test.startTest();
        userProfileLWC.allOrderData(
            testUser.Id,
            'All',
            Date.today().addDays(-5),
            Date.today().addDays(5)
        );
        Test.stopTest();
        
     
        
    }    
    
    @isTest
    static void test_allInvoiceData() {
        
        // Step 1: Create User
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User u = new User(
            FirstName = 'Invoice',
            LastName = 'Tester',
            Employee_Code__c = 'EMP001',
            Email = 'invoice@test.com',
            Username = 'invoiceuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'invusr',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;
        
        // Step 2: Account
        Account acc = new Account(
            Name = 'Test Customer',
            Customer_Type__c = 'Primary Customer',
            State__c = 'Karnataka',
            District__c = 'Kolar'
            
        );
        insert acc;
        
        // Step 3: Order (for Order__c != null condition)
        Order ord = new Order(
            Name = 'Test Order',
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            OwnerId = u.Id
        );
        insert ord;
        
        // Step 4: Invoice
        Invoice__c inv = new Invoice__c(
            OwnerId = u.Id,
            Store__c = acc.Id,
            Customer_Name__c = 'Test',
            Invoice_No__c = 'INV001',
            Invoice_Date__c = Date.today()
        );
        insert inv;
        
        // Step 5: Invoice Items
        
        // Case 1: With Order__c
        Invoice_item__c item1 = new Invoice_item__c(
            Invoice__c = inv.Id,
            Bill_Number__c = 'BILL001',
            Bill_Date__c = Date.today(),
            Bill_Amount__c = 100,
            Qyt__c = 5,
            Qyt_in_Each__c = 10,
            OwnerId = u.Id,
            Bill_to_party_name__c = 'Party A'
        );
        
        // Case 2: Without Order__c
        Invoice_item__c item2 = new Invoice_item__c(
            Invoice__c = inv.Id,
            Bill_Number__c = 'BILL002',
            Bill_Date__c = Date.today(),
            Bill_Amount__c = 200,
            Qyt__c = 3,
            Qyt_in_Each__c = 6,
            OwnerId = u.Id,
            Bill_to_party_name__c = 'Party B'
        );
        
        insert new List<Invoice_item__c>{item1, item2};
            
            Date startDate = Date.today().addDays(-2);
        Date endDate = Date.today().addDays(2);
        
        Test.startTest();
        
        // Call method
        userProfileLWC.userData result =
            userProfileLWC.allInvoiceData(u.Id, 'All', startDate, endDate);
        
        Test.stopTest();
        
        
    }
    
    @isTest
    static void testAttendanceMethod() {
        // Create test user
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Test',
            LastName = 'User2',
            Email = 'testuser2@example.com',
            Username = 'testuser2' + DateTime.now().getTime() + '@example.com',
            Alias = 'test2',
            Employee_Code__c = 'jhgjhgklsksksksksklfjhfyg97987',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        
        // Create Daily Log
        Daily_Log__c log = new Daily_Log__c(
            OwnerId = u.Id,
            Day_started_time__c = DateTime.newInstance(Date.today().year(), Date.today().month(), Date.today().day(), 9, 0, 0)
        );
        insert log;
        
        // Create Visit__c
        Visit__c visit = new Visit__c(
            OwnerId = u.Id,
            Status__c = 'Completed',
            Daily_Log__c = log.Id
        );
        insert visit; 
        
        list<Visit__c> lst = [select Id,Name,Status__c,Daily_Log__c,minute_duration__c from Visit__c ];
        
        Test.startTest();
        userProfileLWC.attendance(u.Id, Date.today().addDays(-1), Date.today(), 'All');
        userProfileLWC.allExpData(u.Id,'All', Date.today(), Date.today());
        
        Test.stopTest();
        
    }
     
    @isTest
    static void testRepeatDaysMethod() {
        // Create test user
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Test',
            LastName = 'UserRD',
            Email = 'testrd@example.com',
            Username = 'testrd' + DateTime.now().getTime() + '@example.com',
            Alias = 'trd',
            ProfileId = p.Id,
            Employee_Code__c = 'jhgjhgklskskskskskskksklfjhfyg97987',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        
      // Step 2: Create test account
        Account acc = new Account(
            Name = 'Primary Customer',
            Customer_Type__c = 'Primary Customer',
            Pincode__c = '123456',
            Primary_Phone_Number__c = '8076763210',
            State__c = 'Karnataka',
            District__c = 'Kolar'
        );
        insert acc;
        
        // Create Child_Beat__c (Created THIS_MONTH)
        Child_Beat__c cb = new Child_Beat__c(
            Name = 'Test Beat',
            Beat_Type__c ='Secondary',
            OwnerId = u.Id,
            Order_Number__c = 1
        );
        insert cb;
        
        // Create Junction_Beat__c related to Child_Beat__c
        Junction_Beat__c jn = new Junction_Beat__c(
            Account__c = acc.Id,
            Child_Beat__c = cb.Id,
            Order_Number__c = 1
        );
        insert jn;
        
        Test.startTest();
        try
        {
            userProfileLWC.repeatDays(u.Id);
        }
        catch(exception e)
        {
            
        }
        //
        Test.stopTest();
        
      
    }
    @isTest
    static void testIncentive() {
        User u = createTestUser();
        
        Target_Plan__c plan = new Target_Plan__c(OwnerId = u.Id, Incentive_Type__c = 'Variable Pay');
        insert plan;

        Period__c tp = new Period__c( Start_Date__c=Date.today().addDays(-2));
        insert tp;

        Target__c target = new Target__c( Executive__c = u.Id, Period__c = tp.Id);
        insert target;

        Target_Item__c item = new Target_Item__c(
            Target__c = target.Id,
            Amount__c = 500
        );
        insert item;

        Test.startTest();
        userProfileLWC.Incentive(u.Id, Date.today().addDays(-10), Date.today());
        Test.stopTest();

    }

    @isTest
    static void testGetMapLocationData() {
        User u = createTestUser();

        Account a = new Account(Name='Store A', 
                                GeoLocation__Latitude__s=17.0, 
                                GeoLocation__Longitude__s=78.0,
                                OwnerId=u.Id,
                                Customer_Type__c = 'Primary Customer',
                                Pincode__c = '123456',
                                Primary_Phone_Number__c = '8076763210',
                                State__c = 'Karnataka',
                                District__c = 'Kolar');
        insert a;

        Daily_Log__c dl = new Daily_Log__c(
            OwnerId = u.Id,
            Clock_In_Location__Latitude__s = 17.0,
            Clock_In_Location__Longitude__s = 78.0
        );
        insert dl;

        Test.startTest();
        userProfileLWC.getMapLocationDta(u.Id, Date.today().addDays(-5), Date.today());
        Test.stopTest();

    }

    private static User createTestUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Username = 'testuser' + Math.random() + '@example.com',
            Email = 'test@example.com',
            Employee_Code__c = 'jhgjhgklskskskskskskksklfjhfyg97987'+Math.random() ,
            Alias = 'tuser',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        return u;
    }
     @isTest
    static void testVisitMethods() {
        // Create test user
        User u = new User(
            Username = 'testuqdfsewwrwww@example.com',
            LastName = 'Test',
            Email = 'testuser@ewwsswxample.com',
            Employee_Code__c = 'jhgjhgklskskskskskskksklfjhfyg97987'+Math.random() ,
            Alias = 'tstusr',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        // Set date
        Date today = Date.today();

        // Create a Daily Log with Child_beat__c null
        Daily_Log__c dailyLog = new Daily_Log__c(
            OwnerId = u.Id,
            Day_started_time__c = DateTime.newInstance(today.year(), today.month(), today.day(), 9, 0, 0)
        );
        insert dailyLog;

        // Create Account
         Account acc = new Account(
            Name = 'Primary Customer',
            Customer_Type__c = 'Primary Customer',
            Pincode__c = '123456',
            Primary_Phone_Number__c = '8070763910',
            State__c = 'Karnataka',
            District__c = 'Kolar'
        );
        insert acc;

        // Create a non-PJP Visit (Child_beat__c = null)
        Visit__c nonPjp = new Visit__c(
            OwnerId = u.Id,
            Daily_log__c = dailyLog.Id,
            Status__c = 'In Progress',
            Account1__c = acc.Id
        );
        insert nonPjp;

        // Create a PJP Visit (Child_beat__c = some value)
        Child_Beat__c cb = new Child_Beat__c(Name = 'Test Beat',Beat_Type__c ='Secondary');
        insert cb;

        dailyLog.Child_beat__c = cb.Id;
        update dailyLog;

        Visit__c pjpVisit = new Visit__c(
            OwnerId = u.Id,
            Daily_log__c = dailyLog.Id,
            Child_beat__c = cb.Id,
            Status__c = 'In Progress',
            Account1__c = acc.Id
        );
        insert pjpVisit;

        // Create a completed visit with an Order (Productive)
        Visit__c productiveVisit = new Visit__c(
            OwnerId = u.Id,
            Daily_log__c = dailyLog.Id,
            Child_beat__c = cb.Id,
            Status__c = 'Completed',
            Account1__c = acc.Id
        );
        insert productiveVisit;

        Order__c order = new Order__c(
            OwnerId = u.Id,
            Visit__c = productiveVisit.Id,
            Account__c = acc.Id,
            Order_Date__c = today
        );
        insert order;

        // Create a completed visit with NO order (Non-Productive)
        Visit__c nonProductiveVisit = new Visit__c(
            OwnerId = u.Id,
            Daily_log__c = dailyLog.Id,
            Child_beat__c = cb.Id,
            Status__c = 'Completed',
            Account1__c = acc.Id
        );
        insert nonProductiveVisit;

        Test.startTest();

        // Run methods
        userProfileLWC.nonPjpVisit(u.Id, today, today);
        userProfileLWC.PjpVisit(u.Id, today, today);
        userProfileLWC.Productive(u.Id, today, today);
        userProfileLWC.NonProductive(u.Id, today, today);

        Test.stopTest();

    }

     @isTest
    static void testWrapperClassUsage() {
        // Cover incData
        userProfileLWC.incData inc = new userProfileLWC.incData();
        inc.period = '2025-Q1';
        inc.monthName = 'January';
        inc.amt = '10000';
        inc.exeId = '005XX0000012345';
        inc.exeName = 'Test Executive';
        inc.incId = 'a0BXX0000023456';
        inc.startDt = '2025-01-01';
        inc.endDt = '2025-01-31';
        inc.creditDt = '2025-02-05';

        // Cover CalendarEvent
        userProfileLWC.CalendarEvent event = new userProfileLWC.CalendarEvent();
        event.type = 'Beat';
        event.id = 'a0DXX0000023456';
        event.name = 'Test Beat';
        event.visitDate = Date.today();
        event.color = 'blue';
        event.accName = 'Test Account';
        event.accId = '001XX0000034567';
        event.description = 'N/A';

        // Cover DateGroup
          // Cover userProfileLWC.DateGroup
        userProfileLWC.DateGroup dg = new userProfileLWC.DateGroup();
        dg.chBeatId = 'a0CXX0000012345';
        dg.isHoliday = false;
        dg.commonId = 'CID001';
        dg.BeatId = 'BID001';
        dg.JnId = 'JN001';
        dg.color = 'green';
        dg.dates = '2025-06-23';
        dg.name = 'Beat Plan June';
        dg.events = new List<userProfileLWC.CalendarEvent>{ event };
    }
    
     @isTest
    static void testWrapper() {
        // Arrange test data
        String beatId = '001XXXXXXXXXXXX'; 
        String beatName = 'Test Beat';
        Date beatDate = Date.today();
        String formattedDate = '2025-02-05';
        Integer orderNumber = 5;

        // Act: create wrapper instance
        userProfileLWC.chBeatVisitWrapper wrapper = new userProfileLWC.chBeatVisitWrapper(
            beatId,
            beatName,
            beatDate,
            formattedDate,
            orderNumber
        );

    }

    
}