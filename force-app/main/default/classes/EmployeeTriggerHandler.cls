/****************************************************************
* Class Name : EmployeeTriggerHandler
* Company : Fingertipplus
* Created Date : 
* @description : This class handles  insert and  update opertations of Employee
* @author : Durga Prasad
* Used By : - EmployeeTrigger
* Change Log:
* -----------------------------------------------------------------------------
* Ver | Author | Date | Description
* -----------------------------------------------------------------------------
* 1.0 | Durga Prasad |  | Initial version
* -----------------------------------------------------------------------------
******************************************************************/
public class EmployeeTriggerHandler {
    public static Boolean stopAfterUpdate = false; 
    public static Boolean stopbeforeUpdate = false; 
    /**
    * Method Name: beforeInsert
    * @author: Durga Prasad
    * @description: 1.For Data upload based based Priority we will map Territory,Area,Region
    *               2.Based on Name we will map Role,Profile
    *               3.Approvers for current Employee Record
    * @parameters:
    *   - List<Employee__c> newEmployees trigger.new list.
    * @return: void
    */
    public static void beforeInsert(List<Employee__c> newEmployees) 
    {
        Set<Id> userIds = new Set<Id>();
        
        for (Employee__c emp : newEmployees) {
            if (emp.OwnerId != null) userIds.add(emp.OwnerId);
            if (emp.Reporting_Manager__c != null) userIds.add(emp.Reporting_Manager__c);
        }
        
        // User Map
        Map<Id, User> userMap = new Map<Id, User>([
            SELECT Id, Name,Region__c, Area__c, Territory__c, State__c, District__c,RSM__c,ASM_TSM__c,Working_District__c,
            Employee_Approver_3_HR__c FROM User WHERE Id IN :userIds
        ]);
         
        // Territory Map
        Map<Id, Area__c> territoryMap = new Map<Id, Area__c>([
            SELECT Id, Name, Area__c, Region__c, District__c, Sales_Channel__c
            FROM Area__c
        ]);
        
        Map<String, String> areaToRegionMap = new Map<String, String>();
        for (Area__c terr : territoryMap.values()) {
            if (terr.Area__c != null && terr.Region__c != null) {
                areaToRegionMap.put(terr.Area__c, terr.Region__c );
            }
        }
        
        
        // Role Name to Role Id map
        Map<String, String> roleMap = new Map<String, String>();
        for (UserRole ur : [SELECT Id, Name FROM UserRole]) {
            roleMap.put(ur.Name.trim(), ur.Id);
        }
        
        for (Employee__c emp : newEmployees) {
            // ========== 1. Approver Mapping to Approve this particular Record==========
            if (userMap.containsKey(emp.OwnerId)) {
                User owner = userMap.get(emp.OwnerId);
                if (owner.ASM_TSM__c != null) {
                    emp.Approver_ASM__c = owner.ASM_TSM__c;
                }
                if (owner.RSM__c != null) {
                    emp.Approver_RSM__c = owner.RSM__c;
                }
                if (owner.Employee_Approver_3_HR__c != null) {
                    emp.Employee_Owner_Approver_3_HR__c = owner.Employee_Approver_3_HR__c;
                }
            }
            // ========== 2. Role Id Mapping ==========
            if (emp.Role__c != null && emp.Role_Id__c == null && emp.IsDataUpload__c) {
                String roleName = emp.Role__c.trim();
                if (roleMap.containsKey(roleName)) {
                    emp.Role_Id__c = roleMap.get(roleName);
                }
            }
            
            // ========== 3. Region/Area/District Auto-Mapping ==========
            // Priority 1: Based on Territory
            if (emp.Territory__c != null && territoryMap.containsKey(emp.Territory__c) && emp.IsDataUpload__c) {
                Area__c terr = territoryMap.get(emp.Territory__c);
                emp.Area__c = terr.Area__c;
                emp.Region__c = terr.Region__c;
                emp.Working_District__c = terr.District__c;
            }
            // Priority 2: Based on Area
            else if (emp.Area__c != null && areaToRegionMap.containsKey(emp.Area__c) && emp.IsDataUpload__c) {
                emp.Region__c = areaToRegionMap.get(emp.Area__c);
            }
            // Priority 4: Based on Reporting Manager
            else if (emp.Reporting_Manager__c != null && userMap.containsKey(emp.Reporting_Manager__c) && emp.IsDataUpload__c) {
                User mgr = userMap.get(emp.Reporting_Manager__c);
                emp.Region__c = mgr.Region__c;
                emp.Area__c = mgr.Area__c;
                emp.Working_District__c = mgr.Working_District__c;
            }
            
       
        }
    }
    /**
    * Method Name: beforeInsert
    * @author: Durga Prasad
    * @description: 1.For Data upload based based Priority we will map Territory,Area,Region
    *               2.Based on Name we will map Role,Profile
    * @parameters:
    *   - List<Employee__c> newEmployees trigger.new list.
    * @return: void
    */
    public static void beforeUpdate(List<Employee__c> newEmployees,Map<Id, Employee__c> oldEmployeeMap)
    {
        Set<Id> userIds = new Set<Id>();
        
        for (Employee__c emp : newEmployees) {
            if (emp.OwnerId != null) userIds.add(emp.OwnerId);
            if (emp.Reporting_Manager__c != null) userIds.add(emp.Reporting_Manager__c);
        }
        
        // User Map
        Map<Id, User> userMap = new Map<Id, User>([
            SELECT Id, Name,Region__c, Area__c, Territory__c, State__c, District__c,RSM__c,ASM_TSM__c,Working_District__c,
            Employee_Approver_3_HR__c FROM User WHERE Id IN :userIds
        ]);
        
        // Territory Map
        Map<Id, Area__c> territoryMap = new Map<Id, Area__c>([
            SELECT Id, Name, Area__c, Region__c, District__c, Sales_Channel__c
            FROM Area__c
        ]);
        
        Map<String, String> areaToRegionMap = new Map<String, String>();
        for (Area__c terr : territoryMap.values()) {
            if (terr.Area__c != null && terr.Region__c != null) {
                areaToRegionMap.put(terr.Area__c, terr.Region__c );
            }
        }
        
        
        // Role Name to Role Id map
        Map<String, String> roleMap = new Map<String, String>();
        for (UserRole ur : [SELECT Id, Name FROM UserRole]) {
            roleMap.put(ur.Name.trim(), ur.Id);
        }
        
        for (Employee__c emp : newEmployees) {
            Employee__c oldEmp = oldEmployeeMap.get(emp.Id);
            // ========== 1. Role Id Mapping ==========
            if (emp.Role__c != oldEmp.Role__c && emp.Role__c != null &&  emp.IsDataUpload__c) {
                String roleName = emp.Role__c.trim();
                if (roleMap.containsKey(roleName)) {
                    emp.Role_Id__c = roleMap.get(roleName);
                }
            }
            // ========== 2. Region/Area/District Auto-Mapping ==========
            
            // Priority 1: Based on Territory
            if ( emp.Territory__c != oldEmp.Territory__c &&  emp.Territory__c != null && territoryMap.containsKey(emp.Territory__c) && emp.IsDataUpload__c) {
                Area__c terr = territoryMap.get(emp.Territory__c);
                emp.Area__c = terr.Area__c;
                emp.Region__c = terr.Region__c;
                emp.Working_District__c = terr.District__c;
            }
            // Priority 2: Based on Area
            else if (emp.Area__c != oldEmp.Area__c && emp.Area__c != null && areaToRegionMap.containsKey(emp.Area__c) && emp.IsDataUpload__c) {
                emp.Region__c = areaToRegionMap.get(emp.Area__c);
            }
            // Priority 4: Based on Reporting Manager
            else if (emp.Reporting_Manager__c != oldEmp.Reporting_Manager__c && emp.Reporting_Manager__c != null && userMap.containsKey(emp.Reporting_Manager__c) && emp.IsDataUpload__c) {
                User mgr = userMap.get(emp.Reporting_Manager__c);
                emp.Region__c = mgr.Region__c;
                emp.Area__c = mgr.Area__c;
                emp.Working_District__c = mgr.Working_District__c;
            }
        }
            
    }
    /**
    * Method Name: beforeInsert
    * @author: Durga Prasad
    * @description: 1.For Data upload based based Priority we will map Territory,Area,Region
    *               2.Based on Name we will map Role,profile
    * @parameters:
    *   - List<Employee__c> newEmployees trigger.new list.
    * @return: void
    */
    public static void AfterUpdate(List<Employee__c> newEmployees, Map<Id, Employee__c> oldEmployeeMap)
    {
        
        // Fetch Profile ID based on Profile Name
        Map<String, String> profileMap = new Map<String, String>();
        for (Profile pro : [SELECT Id, Name FROM Profile]) {
            profileMap.put(pro.Name, pro.Id);
        }
        
        Map<String, String> roleMap = new Map<String, String>();
        set<Id> roleIds = new set<Id>();
        for (UserRole ur : [SELECT Id, Name FROM UserRole]) {
            roleMap.put(ur.Name,ur.Id);
            roleIds.add(ur.Id);
        }
        Map<Id, User> userList = new Map<Id, User>([SELECT Id FROM User WHERE IsActive = true]);
        
        
        string AdminUserProfleName = Label.Admin_User_Profile_Name;
        User adminUser = [select Id,Name from User where Profile.Name =:AdminUserProfleName limit 1];
        
        map<String,String> OldEmployeewithNewEmployeeMap = new map<String,String>();
        set<Id> activatedUsers = new  set<Id>();
        set<Id> userIdToDeleteOldMapping = new set<Id>();
        map<Id,Id> activatedEmployees = new map<Id,Id>();
        
        
        List<User> usersToUpdate = new List<User>();
        for (Employee__c emp : newEmployees) {
            Employee__c oldEmp = oldEmployeeMap.get(emp.Id);
            // When thse fields upadated we are updating Users
            if (oldEmp != null && emp.User__c != null) 
            {
                
                User newUser = new User();
                newUser.Id = emp.User__c;
                
                if( emp.Name != oldEmp.Name)
                {
                    String fullName = emp.Name;
                    fullName = fullName.trim().replaceAll('\\s+', ' ');
                    List<String> nameParts = fullName.split(' ');
                    String firstName;
                    String lastName;
                    if (nameParts.size() == 1) {
                        firstName = '';
                        lastName = nameParts[0];
                    } 
                    else if (nameParts.size() > 1) {
                        firstName = nameParts[0];
                        lastName = '';
                        for (Integer i = 1; i < nameParts.size(); i++) {
                            if (i > 1) {
                                lastName += ' '; 
                            }
                            lastName += nameParts[i];
                        }
                    }
                    newUser.FirstName = firstName;
                    newUser.LastName = lastName;
                }
                if(emp.Mail_Id__c != oldEmp.Mail_Id__c )
                {
                    newUser.Email = emp.Mail_Id__c;
                }
                if( emp.User_Name__c != oldEmp.User_Name__c)
                {
                    newUser.Username = emp.User_Name__c;
                }
                if(emp.Primary_Phone_Number__c != oldEmp.Primary_Phone_Number__c )
                {
                    newUser.Phone = emp.Primary_Phone_Number__c;
                }
                
                if(emp.Profile__c != oldEmp.Profile__c && profileMap.containsKey(emp.Profile__c))
                {
                    newUser.ProfileId = profileMap.get(emp.Profile__c);
                }
                if(emp.Role__c != oldEmp.Role__c && emp.Role__c != null && roleMap.containsKey(emp.Role__c))
                {
                    newUser.UserRoleId  = roleMap.get(emp.Role__c);
                }
                if (emp.Role__c != oldEmp.Role__c && emp.Role__c != null) {
                    if (emp.Role_Id__c != null && roleIds.contains(emp.Role_Id__c)) {
                        newUser.UserRoleId = emp.Role_Id__c;
                    } else if (roleMap.containsKey(emp.Role__c)) {
                        newUser.UserRoleId = roleMap.get(emp.Role__c);
                    }
                }
                if(emp.Reporting_Manager__c != oldEmp.Reporting_Manager__c )
                {
                    newUser.ManagerId = emp.Reporting_Manager__c;
                }
                if(emp.Aadhar_Number__c != oldEmp.Aadhar_Number__c )
                {
                    newUser.Aadhar_Number__c = emp.Aadhar_Number__c;
                }
                if(emp.Employee_Code__c != oldEmp.Employee_Code__c)
                {
                    newuser.Employee_Code__c = emp.Employee_Code__c;
                }
                if(emp.Designation__c != oldEmp.Designation__c)
                {
                    newUser.Title = emp.Designation__c;
                }
                if(emp.Payroll__c != oldEmp.Payroll__c)
                {
                    newUser.Payroll__c = emp.Payroll__c;
                }
                if(emp.Payroll_Type__c != oldEmp.Payroll_Type__c)
                {
                    newUser.Payroll_Type__c = emp.Payroll_Type__c;
                }
                if(emp.Contract_Type__c != oldEmp.Contract_Type__c)
                {
                    newUser.Contract_Type__c = emp.Contract_Type__c;
                }
                if(emp.Band__c != oldEmp.Band__c)
                {
                    newUser.Band__c = emp.Band__c;
                }
                if(emp.Headquarter__c != oldEmp.Headquarter__c)
                {
                    newUser.Headquarter__c = emp.Headquarter__c;
                }
                if(emp.Sales_Channel__c != oldEmp.Sales_Channel__c)
                {
                    newUser.Sales_Channel__c = emp.Sales_Channel__c;
                }
                if(emp.Category__c != oldEmp.Category__c)
                {
                    newUser.Category__c = emp.Category__c;
                }
                if(emp.Territory__c != oldEmp.Territory__c)
                {
                    newUser.Territory__c = emp.Territory__c;
                }
                if(emp.Territory_Name__c != oldEmp.Territory_Name__c)
                {
                    newUser.Territory_Name__c = emp.Territory_Name__c;
                }
                 if(emp.Area__c != oldEmp.Area__c)
                {
                    newUser.Area__c = emp.Area__c;
                }
                 if(emp.Working_District__c != oldEmp.Working_District__c)
                {
                    newUser.Working_District__c = emp.Working_District__c;
                }
                 if(emp.Region__c != oldEmp.Region__c)
                {
                    newUser.Region__c = emp.Region__c;
                }
                
				
                if(emp.RSM__c != oldEmp.RSM__c)
                {
                    newUser.RSM__c = emp.RSM__c;
                }
                if(emp.ASM_TSM__c != oldEmp.ASM_TSM__c)
                {
                    newUser.ASM_TSM__c = emp.ASM_TSM__c;
                }
                if(emp.Employee_Approver_3_HR__c != oldEmp.Employee_Approver_3_HR__c)
                {
                    newUser.Employee_Approver_3_HR__c = emp.Employee_Approver_3_HR__c;
                }
                
                if(emp.Leave_HR__c != oldEmp.Leave_HR__c)
                {
                    newUser.Leave_HR__c = emp.Leave_HR__c;
                }
                if(emp.Leave_Approver_L1__c != oldEmp.Leave_Approver_L1__c)
                {
                    newUser.Leave_Approver_L1__c = emp.Leave_Approver_L1__c;
                }


                if(emp.Secondary_Customer_Approver_1__c != oldEmp.Secondary_Customer_Approver_1__c)
                {
                    newUser.Secondary_Customer_Approver_1__c = emp.Secondary_Customer_Approver_1__c;
                }
                if(emp.Secondary_Customer_Approver_2__c != oldEmp.Secondary_Customer_Approver_2__c)
                {
                    newUser.Secondary_Customer_Approver_2__c = emp.Secondary_Customer_Approver_2__c;
                }
            
                if(emp.Primary_Customer_Approver_1__c != oldEmp.Primary_Customer_Approver_1__c)
                {
                    newUser.Primary_Customer_Approver_1__c = emp.Primary_Customer_Approver_1__c;
                }
                if(emp.Primary_Customer_Approver_2__c != oldEmp.Primary_Customer_Approver_2__c)
                {
                    newUser.Primary_Customer_Approver_2__c = emp.Primary_Customer_Approver_2__c;
                }
                if(emp.Primary_Customer_Approver_3_CD__c != oldEmp.Primary_Customer_Approver_3_CD__c)
                {
                    newUser.Primary_Customer_Approver_3_Credit_Dept__c = emp.Primary_Customer_Approver_3_CD__c;
                }
                
                if(emp.PJP_Approver_1__c != oldEmp.PJP_Approver_1__c)
                {
                    newUser.PJP_Approver_1__c = emp.PJP_Approver_1__c;
                }
                if(emp.PJP_Approver_2__c != oldEmp.PJP_Approver_2__c)
                {
                    newUser.PJP_Approver_2__c = emp.PJP_Approver_2__c;
                }
                
                if(emp.Expense_Approver_1__c != oldEmp.Expense_Approver_1__c)
                {
                    newUser.Expense_Approver_1__c = emp.Expense_Approver_1__c;
                }
                if(emp.Expense_Approver_2_Finance_Department__c != oldEmp.Expense_Approver_2_Finance_Department__c)
                {
                    newUser.Expense_Approver_2_Finance_Dept__c = emp.Expense_Approver_2_Finance_Department__c;
                }
                
                if(emp.State__c != oldEmp.State__c){ newUser.State__c = emp.State__c; }
                if(emp.District__c != oldEmp.District__c) {newUser.District__c = emp.District__c; }
                if(emp.Minimum_Order_value__c != oldEmp.Minimum_Order_value__c){newUser.Minimum_Order_value__c = emp.Minimum_Order_value__c;}
                if(emp.District_In_charge__c != oldEmp.District_In_charge__c){newUser.District_In_charge__c = emp.District_In_charge__c;}
                if(emp.Expense_Start_Date__c != oldEmp.Expense_Start_Date__c){ newUser.Expense_Start_Date__c = emp.Expense_Start_Date__c; }
                if(emp.Expense_End_Date__c != oldEmp.Expense_End_Date__c) { newUser.Expense_End_Date__c = emp.Expense_End_Date__c;}
                if(emp.Expense_Back_Day_Entry_Limit__c != oldEmp.Expense_Back_Day_Entry_Limit__c)
                {
                    newUser.Expense_Back_Day_Entry_Limit__c = emp.Expense_Back_Day_Entry_Limit__c;
                }
                if(emp.Employee_Remarks__c != oldEmp.Employee_Remarks__c)
                {
                    newUser.Employee_Remarks__c = emp.Employee_Remarks__c;
                }
                if(emp.DOJ__c != oldEmp.DOJ__c)
                {
                    newUser.DOJ__c = emp.DOJ__c;
                }
                //New field Added on 06/10/2025
                if(emp.Alternate_Sales_Channel__c != oldEmp.Alternate_Sales_Channel__c)
                {
                    newUser.Alternate_Sales_Channel__c = emp.Alternate_Sales_Channel__c;
                }
                if(emp.PBIS_Policy__c != oldEmp.PBIS_Policy__c)
                {
                    newUser.PBIS_Policy__c = emp.PBIS_Policy__c;
                }

                usersToUpdate.add(newUser);
            }
            
            //When it is Approved by Hr Notification to Admin
            if(emp.Approval_Status__c != oldEmp.Approval_Status__c && emp.Approval_Status__c == 'HR Approved')
            {
                string notificationBody = 'Employee Name : ' + emp.Name + 
                    '\nEmployee Type : ' + emp.User_Type__c+
                    '\nProfile Name : ' + emp.Profile__c +
                    '\nPayroll : ' + emp.Payroll__c;
                
                string notificationTitle = emp.Name+' employee has been Approved by HR';
                if(adminUser.Id != null)
                {
                    GenericNotificationCenter.notificationSend(notificationTitle, emp.Id, notificationBody, new set<string> {adminUser.Id});
                }
            }
            
            
            //When User Activated Notification to created user and HR and 
            //If it replacement changing the Product mapping of existing user
            if(emp.Is_Active__c != oldEmp.Is_Active__c && emp.Is_Active__c == true)
            {
                //Notification to 
                string notificationBody = 'Employee Name : ' + emp.Name + 
                    '\nEmployee Type : ' + emp.User_Type__c+
                    '\nProfile Name : ' + emp.Profile__c +
                    '\nPayroll : ' + emp.Payroll__c;
                
                string notificationTitle = emp.Name+' employee has been Activated by Admin';
                Set<String> recipientIds = new Set<String>();
                
                if (userList.containsKey(emp.CreatedById)) {
                    recipientIds.add(emp.CreatedById);
                }
                if (userList.containsKey(emp.Employee_Owner_Approver_3_HR__c)) {
                    recipientIds.add(emp.Employee_Owner_Approver_3_HR__c);
                }
                if (!recipientIds.isEmpty()) {
                    GenericNotificationCenter.notificationSend(notificationTitle, emp.Id, notificationBody, recipientIds);
                }
                //When user is Deactivated and Activated again Is_User_Deactivated__c will be true
                if(emp.User__c != null && emp.Is_User_Deactivated__c == true)
                {
                    activatedUsers.add(emp.User__c);
                }
                if(emp.User__c != null && emp.Is_User_Deactivated__c == false)
                {
                    activatedEmployees.put(emp.Id,emp.User__c);
                }
                
            }
   
        }
        //Updating users enqueueJob used When they update any field on employee
        //beacause of Steup object and non setup objects we can't update in single transaction
        if (!usersToUpdate.isEmpty()) {
            System.enqueueJob(new UpdateUsersQueueable(usersToUpdate));
        }
        
        //When employee is activated and assigned with some mapping we are updating the executive field
        if (!activatedEmployees.isEmpty()) {
            updateExecutiveOnActivation(activatedEmployees);
        }
        
        //If user is deacitvated salesforce automatically removes the shared records access
        //so when same user is activated we need to share the record access again
        if(!activatedUsers.isEmpty())
        {
            reshareCustomerAccess(activatedUsers);
        }
    }
    
    public static void updateExecutiveOnActivation(map<Id,Id> activatedEmployees)
    {
        
        list<Employee_Customer_Assignment__c> employeeCustomerAssignments = [select Id,Executive__c,Employee__c
                                                                             from Employee_Customer_Assignment__c
                                                                             where Employee__c IN :activatedEmployees.keySet()];
        if (!employeeCustomerAssignments.isEmpty()) {
            for (Employee_Customer_Assignment__c pMapping : employeeCustomerAssignments) {
                if(activatedEmployees.containsKey(pMapping.Employee__c))
                {
                    string executieId =  activatedEmployees.get(pMapping.Employee__c); 
                    pMapping.Executive__c = executieId;
                    pMapping.OwnerId = executieId;
                }
            }
            database.update(employeeCustomerAssignments,false);
        }
        
        
        
        List<Product_Mapping__c> ProductMappingsToUpdate = [SELECT Id,Employee__c,Exectuive__c FROM Product_Mapping__c 
                                                            WHERE Employee__c IN :activatedEmployees.keySet()];
        if (!ProductMappingsToUpdate.isEmpty()) {
            for (Product_Mapping__c pm : ProductMappingsToUpdate) {
                if(activatedEmployees.containsKey(pm.Employee__c))
                {
                    string executieId =  activatedEmployees.get(pm.Employee__c); 
                    pm.Exectuive__c = executieId;
                    pm.OwnerId = executieId;
                }
            }
            database.update(ProductMappingsToUpdate,false);
        }
    }
    
    public static void reshareCustomerAccess(set<Id> activatedUsers)
    {
        List<AccountShare> sharesToInsert = new List<AccountShare>();
        //Customer product mapping
        List<Product_Mapping__c> mappingsToUpdate = [SELECT Id,Customer__c, Exectuive__c FROM Product_Mapping__c 
                                                     WHERE Exectuive__c IN :activatedUsers];
        if (!mappingsToUpdate.isEmpty()) {
            for (Product_Mapping__c pm : mappingsToUpdate) {
                if (pm.Customer__c != null && pm.Exectuive__c != null) {
                    sharesToInsert.add(CustomSharingService.buildAccountShare(pm.Customer__c, pm.Exectuive__c));
                }
            }
        }
        
        //DSM/SSA Primary Customer assignment
        list<Employee_Customer_Assignment__c> employeeCustomerAssignmentsToUpdate = [select Id,Executive__c,Employee__c,Customer__c
                                                                                     from Employee_Customer_Assignment__c where
                                                                                     Executive__c IN :activatedUsers];
        if (!employeeCustomerAssignmentsToUpdate.isEmpty()) {
            for (Employee_Customer_Assignment__c pMapping : employeeCustomerAssignmentsToUpdate) {
                // Add new share (new customer + same executive)
                if (pMapping.Customer__c != null && pMapping.Executive__c != null) {
                    sharesToInsert.add(CustomSharingService.buildAccountShare(pMapping.Customer__c, pMapping.Executive__c));
                }
            }
        }
        CustomSharingService.shareAccounts(sharesToInsert);
    }
}