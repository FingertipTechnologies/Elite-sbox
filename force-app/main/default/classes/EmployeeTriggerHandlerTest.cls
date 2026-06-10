@isTest
private class EmployeeTriggerHandlerTest {
    
    @TestSetup
    static void setupTestData() {
        // Setup object DML (Profiles, Users, Roles)
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        Profile testProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Admin%' LIMIT 1];
        
        User adminUser = new User(
            FirstName = 'Admin',
            LastName = 'User',
            Email = 'admin.user@test.com',
            Username = 'admin.useruser@test.com',
            Alias = 'admin',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = adminProfile.Id,
            LanguageLocaleKey = 'en_US',
            Employee_Code__c = '994332'
        );
        insert adminUser;
        
        User managerUser = new User(
            FirstName = 'Manager',
            LastName = 'User',
            ManagerId = adminUser.Id,
            Email = 'manager.user@test.com',
            Username = 'manager.useruser@test.com',
            Alias = 'mgr',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = testProfile.Id,
            LanguageLocaleKey = 'en_US',
            Employee_Code__c = '33456'
        );
        insert managerUser;
        
        UserRole testRole;
        System.runAs(adminUser) {
            testRole = new UserRole(Name = 'Test Role');
            insert testRole;
        }
        
        // Separate the rest into a new transaction
        Test.startTest();
        
        managerUser.UserRoleId = testRole.Id;
        update managerUser;
        
        
        
        // Update again after non-setup insert
        managerUser.Region__c = 'Ker_CPD';
        managerUser.Area__c = 'Central';
        managerUser.Working_District__c = 'Chittoor';
        update managerUser;
        
        Test.stopTest();
    }
    
    
    // Rest of the test methods remain the same...
    @isTest
    static void testBeforeInsert() {
        // Get test data
        
        area__c testTerritory111 = new area__c();
        testTerritory111.Name = 'test11121';
        testTerritory111.Sales_Channel__c = 'CPD';
        testTerritory111.Region__c =	'Kerala';
        testTerritory111.Area__c  = 'Central';
        insert testTerritory111;

        User managerUser = [SELECT Id FROM User WHERE Username = 'manager.useruser@test.com' LIMIT 1];
        Area__c testTerritory = [SELECT Id FROM Area__c LIMIT 1];
        UserRole testRole = [SELECT Id, Name FROM UserRole WHERE Name = 'Test Role' LIMIT 1];
        
        // Create test employee
        Employee__c emp = new Employee__c(
            Name = 'Test Employee',
            OwnerId = managerUser.Id,
            Reporting_Manager__c = managerUser.Id,
            Role__c = testRole.Name,
            Territory__c = testTerritory.Id,
            IsDataUpload__c = true,
            Mail_Id__c = 'test@gmail.com', Aadhar_Number__c = '119977663390', Profile__c = 'ASM', Sales_Channel__c = 'TN', User_Name__c = 'my@tstasm.com'
        );
        
        Test.startTest();
        insert emp;
        try{
            delete emp;
        }
        catch(exception e)
        {}
        
        Test.stopTest();
        
        // Verify results
        Employee__c insertedEmp = [SELECT Id, Role_Id__c, Region__c, Area__c, Working_District__c, 
                                   Approver_ASM__c, Approver_RSM__c, Employee_Owner_Approver_3_HR__c 
                                   FROM Employee__c WHERE Id = :emp.Id];
        
    }
    
    @isTest
    static void testBeforeUpdate() {
        Profile testProfile = [SELECT Id, Name FROM Profile WHERE Name LIKE '%Admin%' LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test.user@test.com',
            Username = 'test.useruser2@test.com',
            Alias = 'test',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = testProfile.Id,
            LanguageLocaleKey = 'en_US',
            Employee_Code__c = '664453'
        );
        insert testUser;
        

        
        area__c testTerritory = new area__c();
        testTerritory.Name = 'test11121';
        testTerritory.Sales_Channel__c = 'CPD';
        testTerritory.Region__c =	'Kerala';
        testTerritory.Area__c  = 'Central';
        insert testTerritory;

        
        
        
        UserRole testRole = [SELECT Id, Name FROM UserRole LIMIT 1];
        
        // Create test employee
        Employee__c emp = new Employee__c(
            Name = 'Test Employee',
            OwnerId = testUser.Id,
            Reporting_Manager__c = testUser.Id,
            Role__c = 'Old Role',
            IsDataUpload__c = true,
            Mail_Id__c = 'test@gmail.com', Aadhar_Number__c = '119977663390', Profile__c = 'ASM', Sales_Channel__c = 'TN', User_Name__c = 'my@tstasm.com'
            
        );
        insert emp;
        
        // Update employee
        emp.Role__c = testRole.Name;
        emp.Territory__c = testTerritory.Id;
        
        Test.startTest();
        update emp;
        Test.stopTest();
        
        // Verify results
        Employee__c updatedEmp = [SELECT Id, Role_Id__c, Region__c, Area__c, Working_District__c 
                                  FROM Employee__c WHERE Id = :emp.Id];
        
        //System.assertEquals(testRole.Id, updatedEmp.Role_Id__c, 'Role Id should be updated');
        //System.assertEquals('Test Region', updatedEmp.Region__c, 'Region should be mapped from territory');
        //System.assertEquals('Test Area', updatedEmp.Area__c, 'Area should be mapped from territory');
        //System.assertEquals('Test District', updatedEmp.Working_District__c, 'District should be mapped from territory');
    }
    
    @isTest
    static void testBeforeUpdat1e() {
        Profile testProfile = [SELECT Id, Name FROM Profile WHERE Name LIKE '%Admin%' LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test.user@test.com',
            Username = 'test.useruser2@test.com',
            Alias = 'test',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = testProfile.Id,
            LanguageLocaleKey = 'en_US',
            Employee_Code__c = '664453'
        );
        insert testUser;
        

        
        area__c testTerritory = new area__c();
        testTerritory.Name = 'test11121';
        testTerritory.Sales_Channel__c = 'CPD';
        testTerritory.Region__c =	'Kerala';
        testTerritory.Area__c  = 'Central';
        insert testTerritory;

        
        
        
        UserRole testRole = [SELECT Id, Name FROM UserRole LIMIT 1];
        
        // Create test employee
        Employee__c emp = new Employee__c(
            Name = 'Test Employee',
            OwnerId = testUser.Id,
            Reporting_Manager__c = testUser.Id,
            Role__c = 'Old Role',
            IsDataUpload__c = true,
            Mail_Id__c = 'test@gmail.com', Aadhar_Number__c = '119977663390', Profile__c = 'ASM', Sales_Channel__c = 'TN', User_Name__c = 'my@tstasm.com'
            
        );
        insert emp;
        
        // Update employee
        emp.Name = 'Suresh';
        emp.Territory__c = testTerritory.Id;
        
        Test.startTest();
        update emp;
        Test.stopTest();
        
        // Verify results
        Employee__c updatedEmp = [SELECT Id, Role_Id__c, Region__c, Area__c, Working_District__c 
                                  FROM Employee__c WHERE Id = :emp.Id];
        
        //System.assertEquals(testRole.Id, updatedEmp.Role_Id__c, 'Role Id should be updated');
        //System.assertEquals('Test Region', updatedEmp.Region__c, 'Region should be mapped from territory');
        //System.assertEquals('Test Area', updatedEmp.Area__c, 'Area should be mapped from territory');
        //System.assertEquals('Test District', updatedEmp.Working_District__c, 'District should be mapped from territory');
    }
    
    
    
    @isTest
    static void testAfterUpdateHRApproval() {
        // Get admin user
        User adminUser = [SELECT Id FROM User WHERE Username = 'admin.useruser@test.com' LIMIT 1];
        
        // Create test employee
        Employee__c emp = new Employee__c(
            Name = 'Test Employee',
            Approval_Status__c = 'Pending',
            Employee_Owner_Approver_3_HR__c = adminUser.Id,
            Reporting_Manager__c = userInfo.getUserId(),
            Mail_Id__c = 'test@gmail.com', Aadhar_Number__c = '119977663390', Profile__c = 'ASM', Sales_Channel__c = 'TN', User_Name__c = 'my@tstasm.com'
            
        );
        insert emp;
        
        // Update approval status
        emp.Approval_Status__c = 'HR Approved';
        
        Test.startTest();
        update emp;
        Test.stopTest();
        
        // Verify notification was sent (would need to query platform events or use a mock)
        // This is just a placeholder assertion
        //System.assertEquals('HR Approved', [SELECT Approval_Status__c FROM Employee__c WHERE Id = :emp.Id].Approval_Status__c);
    }
    
    @isTest
    static void testAfterUpdateActivation() {
        // Get test data
        User managerUser = [SELECT Id FROM User WHERE Username = 'manager.useruser@test.com' LIMIT 1];
        
        // Create test user
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test.useruser@test.com',
            Username = 'test.user1234@test.com',
            Alias = 'test',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name LIKE '%Admin%' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US',
            Employee_Code__c= '001123'
        );
        insert testUser;
        
        // Create test employee
        Employee__c emp = new Employee__c(
            Name = 'Test Employee',
            User__c = testUser.Id,
            Is_Active__c = false,
            Is_User_Deactivated__c = true,
            Employee_Owner_Approver_3_HR__c = managerUser.Id,
            Reporting_Manager__c = UserInfo.getUserId(),
            Mail_Id__c = 'test@gmail.com',
            Aadhar_Number__c = '119977663390',
            Profile__c = 'ASM',
            Sales_Channel__c = 'TN',
            User_Name__c = 'my@tstasm.com'
            
        );
        insert emp;
        
        // Create test account for sharing
        Account testAccount = new Account(Name = 'Test Account',City__c = 'Delhi',
                                          State__c = 'Delhi',
                                          District__c = 'New Delhi',
                                          Primary_Phone_Number__c = '9900099999',Pincode__c = '774456');
        insert testAccount;
        
        // Create product mapping
        Product_Mapping__c pm = new Product_Mapping__c(
            Customer__c = testAccount.Id,
            Exectuive__c = testUser.Id
        );
        insert pm;
        
        // Activate employee
        emp.Is_Active__c = true;
        
        Test.startTest();
        update emp;
        Test.stopTest();
        
        // Verify employee is active
        Employee__c updatedEmp = [SELECT Is_Active__c FROM Employee__c WHERE Id = :emp.Id];
        //System.assertEquals(true, updatedEmp.Is_Active__c, 'Employee should be active');
        
        // Verify product mapping was updated (would need to query in real test)
        // Verify sharing was recreated (would need to query AccountShare in real test)
    }
    

    
    
    @isTest
    static void testBeforeInsert11() {
        
        
        user testUser = [select Id,Name from User where Employee_Code__C = '994332' limit 1];   
        
        user testUser2 = [select Id,Name from User where Employee_Code__C = '33456' limit 1];   
        Employee__c emp = new Employee__c(
            Name = 'Test Employee',
            OwnerId = testUser.Id,
            Reporting_Manager__c = testUser2.Id,
            user__C = testUser.Id,
            IsDataUpload__c = true,
            Mail_Id__c = 'test@gmail.com', Aadhar_Number__c = '119977663390', Profile__c = 'ASM', Sales_Channel__c = 'TN', User_Name__c = 'my@tstasm.com'
        );
        insert emp;
        
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
        
        
        
         
        // Activate employee and assign user
        emp.Is_Active__c = true;
        emp.User__c = testUser.Id;
        emp.Mail_Id__c = 'testing@gmail.com';
        emp.User_Name__c = 'testing76747@gmail.com';
        emp.Primary_Phone_Number__c = '7733440091';
        emp.Aadhar_Number__c = '771100997712';
        emp.Employee_Code__c = '54546637383';
        emp.Designation__c = 'ASM.TSE';
        emp.Payroll__c = 'Yes';
        emp.Payroll_Type__c = 'YRFM';
        emp.Contract_Type__c = 'Distributor';
        emp.Band__c = 'M1';
        update emp;
        
        // Call the method directly for testing
        Map<Id, Id> activatedEmployees = new Map<Id, Id>();
        activatedEmployees.put(emp.Id, testUser.Id);
        EmployeeTriggerHandler.updateExecutiveOnActivation(activatedEmployees);
        
        
        
    }

    @isTest
    static void testReshareCustomerAccess() {
        // Create test user
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test.user@test.com',
            Username = 'test.useruseruser@test.com',
            Alias = 'test',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name LIKE '%Admin%' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US',
            Employee_code__c= '99001'
        );
        insert testUser;
        
        // Create test account
        Account testAccount = new Account(Name = 'Test Account',City__c = 'Delhi',
                                          State__c = 'Delhi',
                                          District__c = 'New Delhi',
                                          Primary_Phone_Number__c = '9901099999',Pincode__c = '774456');
        insert testAccount;
        
        // Create product mapping
        Product_Mapping__c pm = new Product_Mapping__c(
            Customer__c = testAccount.Id,
            Exectuive__c = testUser.Id
        );
        insert pm;
        
        // Create employee customer assignment
        Employee_Customer_Assignment__c eca = new Employee_Customer_Assignment__c(
            Customer__c = testAccount.Id,
            Executive__c = testUser.Id
        );
        insert eca;
        
        // Delete existing shares (simulate deactivation)
        delete [SELECT Id FROM AccountShare WHERE UserOrGroupId = :testUser.Id AND AccountId = :testAccount.Id];
        
        Test.startTest();
        EmployeeTriggerHandler.reshareCustomerAccess(new Set<Id>{testUser.Id});
        Test.stopTest();
        
        // Verify shares were recreated
        List<AccountShare> shares = [SELECT Id FROM AccountShare WHERE UserOrGroupId = :testUser.Id AND AccountId = :testAccount.Id];
        //System.assert(!shares.isEmpty(), 'Account shares should be recreated');
    }

    // Verifies that changing PBIS_Policy__c on an Employee mirrors onto the related User.
    // Also exercises the partial-success UpdateUsersQueueable across a bulk of employees,
    // so a single bad row can no longer roll back the rest of the User sync.
    @isTest
    static void testPbisPolicySyncToUser() {
        User userA = [SELECT Id FROM User WHERE Username = 'manager.useruser@test.com' LIMIT 1];
        User userB = [SELECT Id FROM User WHERE Username = 'admin.useruser@test.com' LIMIT 1];

        PBIS_Policy__c policy = new PBIS_Policy__c(Name = 'Test PBIS Policy');
        insert policy;

        List<Employee__c> emps = new List<Employee__c>{
            new Employee__c(
                Name = 'Pbis Employee A', User__c = userA.Id, Reporting_Manager__c = userA.Id,
                IsDataUpload__c = true, Mail_Id__c = 'pbisa@gmail.com', Aadhar_Number__c = '119977663391',
                Profile__c = 'ASM', Sales_Channel__c = 'TN', User_Name__c = 'pbisa@tstasm.com'),
            new Employee__c(
                Name = 'Pbis Employee B', User__c = userB.Id, Reporting_Manager__c = userA.Id,
                IsDataUpload__c = true, Mail_Id__c = 'pbisb@gmail.com', Aadhar_Number__c = '119977663392',
                Profile__c = 'ASM', Sales_Channel__c = 'TN', User_Name__c = 'pbisb@tstasm.com')
        };
        insert emps;

        // Bulk update both employees' PBIS_Policy__c, mimicking a data upload.
        for (Employee__c e : emps) {
            e.PBIS_Policy__c = policy.Id;
        }

        Test.startTest();
        update emps;
        Test.stopTest(); // forces UpdateUsersQueueable to run

        Map<Id, User> updatedUsers = new Map<Id, User>(
            [SELECT Id, PBIS_Policy__c, PBIS_Policy_Name__c FROM User WHERE Id IN (:userA.Id, :userB.Id)]);
        String policyId = String.valueOf(policy.Id);
        System.assertEquals(policyId, updatedUsers.get(userA.Id).PBIS_Policy__c,
            'User A PBIS_Policy__c should store the Employee policy Id');
        System.assertEquals('Test PBIS Policy', updatedUsers.get(userA.Id).PBIS_Policy_Name__c,
            'User A PBIS_Policy_Name__c should store the policy name');
        System.assertEquals(policyId, updatedUsers.get(userB.Id).PBIS_Policy__c,
            'User B PBIS_Policy__c should store the Employee policy Id');
        System.assertEquals('Test PBIS Policy', updatedUsers.get(userB.Id).PBIS_Policy_Name__c,
            'User B PBIS_Policy_Name__c should store the policy name');
    }
}