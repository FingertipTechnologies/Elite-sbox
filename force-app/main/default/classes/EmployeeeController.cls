public class EmployeeeController {
    /**-------Quick Action buttons---------**/
    //User Activation
    @AuraEnabled
    public static String createUser(Id recordId) {
        try {
            // Query Employee record
            Employee__c emp =  [
                SELECT
                Id, Name, Role__c, Role_Id__c, Payroll__c,
                Profile__c, Mail_Id__c, User_Name__c, Aadhar_Number__c, Primary_Phone_Number__c,
                Secondary_Phone_Number__c, PAN__c, DOB__c, DOJ__c, User_Type__c,
                Reporting_Manager__c, Reporting_Manager__r.Name, Reporting_Manager_Name__c, Replaced_For__c, Replaced_For__r.Name,
                Replaced_For_Name__c, Payroll_Type__c, Employee_Code__c, Vendor_Code__c, Band__c,
                Shift_Time__c, Headquarter__c, Relieving_date__c, Designation__c, District_In_charge__c,
                Sales_Channel__c, Region__c, Working_District__c, Territory__c,
                Territory__r.Name, Territory_Name__c, Area__c, ASM_TSM__c, RSM__c,
                Heirarchial_Number__c, Sr_TSE_TSE__c, State__c, District__c, Pincode__c,
                Street__c, Category__c, Employee_Approver_3_HR__c, Primary_Customer_Approver_1__c, Primary_Customer_Approver_2__c,
                Primary_Customer_Approver_3_CD__c, Secondary_Customer_Approver_1__c, Secondary_Customer_Approver_2__c,
                PJP_Approver_1__c, PJP_Approver_2__c, Expense_Approver_1__c, Expense_Approver_2_Finance_Department__c,
                Basic_Pay__c, Gross_Salary__c, Minimum_Order_value__c,User__c,Contract_Type__c,
                Expense_Start_Date__c,Expense_End_Date__c,Expense_Back_Day_Entry_Limit__c,Employee_Remarks__c,Alternate_Sales_Channel__c,
                Leave_HR__c,Leave_Approver_L1__c
                FROM Employee__c
                WHERE Id = :recordId
            ];
            
            if(emp.Role_Id__c != null){
                // Fetch Profile ID based on Profile Name
                Profile userProfile = [ SELECT Id FROM Profile  WHERE Name = :emp.Profile__c  LIMIT 1];
                //User existed in employee menas user alredy create so we need to update 
                //On user Upsert operation will not work so insert update we are using separetly
                string UserId = '';
                if (emp.User__c != null) {
                    User newUser = new User(Id = emp.User__c);
                    newUser.IsActive = true;
                    update newUser;
                    UserId = emp.User__c;
                }
                else
                {
                    // Insert new User
                    User newUser = new User();
                    newUser = populateUserFields(newUser, emp, userProfile.Id);
                    insert newUser;
                    // Send password reset email
                    System.resetPassword(newUser.Id, true);
                    // Update Employee record with the new User ID
                    UserId = newUser.Id;
                }
                
                //We are calling in separate method due to the Mixed DML operations
                updateEmployeeRecord(emp.Id, UserId);
                return 'Success: User Activated Successfully';        
            }
            else{
                return 'Error: ROLE_MISSING';        
            }
        }
        catch (Exception ex) {
            system.debug( ex.getMessage());
            return 'Error: ' + ex.getMessage();
            
        }
    }
    public static User populateUserFields(User user, Employee__c emp, Id profileId) {
        // Assume emp.Name contains the full name string
        String fullName = emp.Name;
        // Step 1: Normalize spacing
        fullName = fullName.trim().replaceAll('\\s+', ' ');
        
        // Step 2: Split the full name into parts
        List<String> nameParts = fullName.split(' ');
        
        // Step 3: Assign FirstName and LastName based on the number of parts
        String firstName;
        String lastName;
        
        if (nameParts.size() == 1) {
            // Single word name
            firstName = '';
            lastName = nameParts[0];
        }
        else if (nameParts.size() > 1) {
            // Multiple word name
            firstName = nameParts[0];
            
            // Manually join remaining parts for last name
            lastName = '';
            for (Integer i = 1; i < nameParts.size(); i++) {
                if (i > 1) {
                    lastName += ' ';
                }
                lastName += nameParts[i];
            }
        }
        
        user.FirstName = firstName;
        user.LastName = lastName;
        user.Email = emp.Mail_Id__c;
        user.Username = emp.User_Name__c;
        user.Phone = emp.Primary_Phone_Number__c;
        user.ProfileId = profileId;
        user.UserRoleId = emp.Role_Id__c;
        user.ManagerId = emp.Reporting_Manager__c;
        user.Aadhar_Number__c = emp.Aadhar_Number__c;
        
        user.Employee_Type__c = emp.User_Type__c;
        user.Employee_Code__c = emp.Employee_Code__c;
        user.Vendor_Code__c = emp.Vendor_Code__c;
        user.Payroll__c = emp.Payroll__c;
        user.Payroll_Type__c = emp.Payroll_Type__c;
        user.Contract_Type__c = emp.Contract_Type__c;
        user.Band__c = emp.Band__c;
        user.Headquarter__c = emp.Headquarter__c;
        
        user.Sales_Channel__c =emp.Sales_Channel__c;  
        user.Alternate_Sales_Channel__c = emp.Alternate_Sales_Channel__c;
        user.Category__c = emp.Category__c;
        user.Territory__c = emp.Territory__c;
        user.Territory_Name__c = emp.Territory_Name__c;
        user.Area__c = emp.Area__c;
        user.Working_District__c = emp.Working_District__c;
        user.Region__c= emp.Region__c;
        user.Title = emp.Designation__c;
        
        
        user.RSM__c = emp.RSM__c;
        user.ASM_TSM__c = emp.ASM_TSM__c;
        user.Employee_Approver_3_HR__c = emp.Employee_Approver_3_HR__c;
        
        user.Secondary_Customer_Approver_1__c = emp.Secondary_Customer_Approver_1__c;
        user.Secondary_Customer_Approver_2__c = emp.Secondary_Customer_Approver_2__c;
        
        user.Primary_Customer_Approver_1__c = emp.Primary_Customer_Approver_1__c;
        user.Primary_Customer_Approver_2__c = emp.Primary_Customer_Approver_2__c;
        user.Primary_Customer_Approver_3_Credit_Dept__c = emp.Primary_Customer_Approver_3_CD__c;
        
        user.PJP_Approver_1__c = emp.PJP_Approver_1__c;
        user.PJP_Approver_2__c = emp.PJP_Approver_2__c;
        
        user.Leave_HR__c = emp.Leave_HR__c;
        user.Leave_Approver_L1__c = emp.Leave_Approver_L1__c;

        user.Expense_Approver_1__c = emp.Expense_Approver_1__c;
        user.Expense_Approver_2_Finance_Dept__c = emp.Expense_Approver_2_Finance_Department__c;
        user.District_In_charge__c = emp.District_In_charge__c;
        
        user.State__c = emp.State__c;
        user.District__c = emp.District__c; 
        user.Minimum_Order_value__c = emp.Minimum_Order_value__c;
        user.IsActive = true;
        
        user.CompanyName = 'Elite'; 
        user.Title = emp.Designation__c;
        user.TimeZoneSidKey = 'Asia/Kolkata'; 
        user.LocaleSidKey = 'en_IN'; 
        user.Alias = emp.Name.length() >= 5 ? emp.Name.substring(0, 5) : emp.Name;
        user.EmailEncodingKey = 'UTF-8';
        user.LanguageLocaleKey = 'en_US';
        
        user.Expense_Start_Date__c = emp.Expense_Start_Date__c;
        user.Expense_End_Date__c = emp.Expense_End_Date__c;
        user.Expense_Back_Day_Entry_Limit__c = emp.Expense_Back_Day_Entry_Limit__c;
        user.Employee_Remarks__c = emp.Employee_Remarks__c;
        user.DOJ__c = emp.DOJ__c;

        
        return user;
    }
    @future
    public static void updateEmployeeRecord(Id employeeId, String userId) {
        try {
            if (userId != null && userId != '') {
                Employee__c updateEmployee = new Employee__c();
                updateEmployee.Id = employeeId;
                updateEmployee.User__c = userId;
                updateEmployee.Employee_Activated_Date__c = Date.today();
                updateEmployee.Activation_Date__c = system.now();
                updateEmployee.OwnerId = userId;
                updateEmployee.Is_Active__c = true;
                update updateEmployee;
            }
         
        } catch (Exception e) {
            System.debug('Error updating Employee: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void deactivateUser(String recordId) {
        Employee__c emp = [
            SELECT Id, User__c FROM Employee__c WHERE Id = :recordId LIMIT 1
        ];
        if (emp.User__c == null) {
            throw new AuraHandledException('No associated User to deactivate.');
        }
        try {
            UserTriggerHandler.userdeactivationProcess = true;
            // Step 1: Remove user’s approver references
            List<User> lstUsers = [
                SELECT Id, ASM_TSM__c, RSM__c, Employee_Approver_3_HR__c,
                Primary_Customer_Approver_1__c, Primary_Customer_Approver_2__c, 
                Primary_Customer_Approver_3_Credit_Dept__c,
                Secondary_Customer_Approver_1__c, Secondary_Customer_Approver_2__c,
                Expense_Approver_1__c, Expense_Approver_2_Finance_Dept__c,
                PJP_Approver_1__c, PJP_Approver_2__c
                FROM User 
                WHERE ASM_TSM__c = :emp.User__c
                OR RSM__c = :emp.User__c
                OR Employee_Approver_3_HR__c = :emp.User__c
                OR Primary_Customer_Approver_1__c = :emp.User__c
                OR Primary_Customer_Approver_2__c = :emp.User__c
                OR Primary_Customer_Approver_3_Credit_Dept__c = :emp.User__c
                OR Secondary_Customer_Approver_1__c = :emp.User__c
                OR Secondary_Customer_Approver_2__c = :emp.User__c
                OR Expense_Approver_1__c = :emp.User__c
                OR Expense_Approver_2_Finance_Dept__c = :emp.User__c
                OR PJP_Approver_1__c = :emp.User__c
                OR PJP_Approver_2__c = :emp.User__c
            ];
            
            // Nullify approver references
            for (User uRec : lstUsers) {
                if (uRec.ASM_TSM__c == emp.User__c) uRec.ASM_TSM__c = null;
                if (uRec.RSM__c == emp.User__c) uRec.RSM__c = null;
                if (uRec.Employee_Approver_3_HR__c == emp.User__c) uRec.Employee_Approver_3_HR__c = null;
                if (uRec.Primary_Customer_Approver_1__c == emp.User__c) uRec.Primary_Customer_Approver_1__c = null;
                if (uRec.Primary_Customer_Approver_2__c == emp.User__c) uRec.Primary_Customer_Approver_2__c = null;
                if (uRec.Primary_Customer_Approver_3_Credit_Dept__c == emp.User__c) uRec.Primary_Customer_Approver_3_Credit_Dept__c = null;
                if (uRec.Secondary_Customer_Approver_1__c == emp.User__c) uRec.Secondary_Customer_Approver_1__c = null;
                if (uRec.Secondary_Customer_Approver_2__c == emp.User__c) uRec.Secondary_Customer_Approver_2__c = null;
                if (uRec.Expense_Approver_1__c == emp.User__c) uRec.Expense_Approver_1__c = null;
                if (uRec.Expense_Approver_2_Finance_Dept__c == emp.User__c) uRec.Expense_Approver_2_Finance_Dept__c = null;
                if (uRec.PJP_Approver_1__c == emp.User__c) uRec.PJP_Approver_1__c = null;
                if (uRec.PJP_Approver_2__c == emp.User__c) uRec.PJP_Approver_2__c = null;
            }
            if (!lstUsers.isEmpty()) {
                update lstUsers;
            }
            
            // Step 2: Deactivate user
            User u = new User(Id = emp.User__c, IsActive = false);
            update u;
            
            // Step 3: Async deactivate employee record
            deactivateEmployeeAsync(emp.Id, emp.User__c);
        } catch (DmlException e) {
            String errorMsg = 'Unknown error occurred while deactivating User.';
            if (String.isNotBlank(e.getDmlMessage(0))) {
                String rawMessage = e.getDmlMessage(0);
                if (rawMessage.contains('Cannot inactivate user that is the value of a hierarchy field')) {
                    // Remove "Cannot complete this operation."
                    String details = rawMessage
                        .replace('Cannot complete this operation. ', '')
                        .replace('Cannot inactivate user that is the value of a hierarchy field: ', '')
                        .trim();
                    // Put each occurrence on a new line
                    details = details.replace(
                        ' Cannot inactivate user that is the value of a hierarchy field: ',
                        '\n'
                    );
                    // Final message
                    errorMsg = 'Cannot De-Activate user because this user is the approver for:\n' + details;
                } else {
                    errorMsg = rawMessage;
                }
            }
            
            throw new AuraHandledException(errorMsg);
        }
    }
    
    @future
    public static void deactivateEmployeeAsync(Id employeeId,string userId) {
      
        Employee__c emp = new Employee__c(
            Id = employeeId,
            Is_Active__c = false,
            Is_User_Deactivated__c = true,
            In_Activation_Date__c = system.now()
        );
        update emp;
        
        list<Employee__c> emplist = [select Id,ASM_TSM__c,RSM__c,Employee_Approver_3_HR__c,
                                     Secondary_Customer_Approver_1__c,Secondary_Customer_Approver_2__c,
                                     Primary_Customer_Approver_1__c, Primary_Customer_Approver_2__c,
                                     Primary_Customer_Approver_3_CD__c, PJP_Approver_1__c,
                                     PJP_Approver_2__c, Expense_Approver_1__c,Expense_Approver_2_Finance_Department__c
                                     from Employee__c where
                                     (ASM_TSM__c =: userId OR RSM__c =: userId OR Employee_Approver_3_HR__c =: userId OR
                                      Secondary_Customer_Approver_1__c =:userId OR  Secondary_Customer_Approver_2__c =: userId OR
                                      Primary_Customer_Approver_1__c =:userId OR Primary_Customer_Approver_2__c =:userId OR 
                                      Primary_Customer_Approver_3_CD__c =:userId OR  PJP_Approver_1__c =:userId OR
                                      PJP_Approver_2__c =:userId OR   Expense_Approver_1__c =:userId OR
                                      Expense_Approver_2_Finance_Department__c =:userId ) ];
        
        for(Employee__c emp1 : emplist)
        {
            if (emp1.ASM_TSM__c == userId) emp1.ASM_TSM__c = null;
            if (emp1.RSM__c == userId) emp1.RSM__c = null;
            if (emp1.Employee_Approver_3_HR__c == userId) emp1.Employee_Approver_3_HR__c = null;
            
            if (emp1.Secondary_Customer_Approver_1__c == userId) emp1.Secondary_Customer_Approver_1__c = null;
            if (emp1.Secondary_Customer_Approver_2__c == userId) emp1.Secondary_Customer_Approver_2__c = null;
            
            if (emp1.Primary_Customer_Approver_1__c == userId) emp1.Primary_Customer_Approver_1__c = null;
            if (emp1.Primary_Customer_Approver_2__c == userId) emp1.Primary_Customer_Approver_2__c = null;
            if (emp1.Primary_Customer_Approver_3_CD__c == userId) emp1.Primary_Customer_Approver_3_CD__c = null;
            
            if (emp1.PJP_Approver_1__c == userId) emp1.PJP_Approver_1__c = null;
            if (emp1.PJP_Approver_2__c == userId) emp1.PJP_Approver_2__c = null; 
            
            if (emp1.Expense_Approver_1__c == userId) emp1.Expense_Approver_1__c = null; 
            if (emp1.Expense_Approver_2_Finance_Department__c == userId) emp1.Expense_Approver_2_Finance_Department__c = null;
            
        }
        update emplist;
    }

    @AuraEnabled
    public static String employeeReplacement(Id recordId) {
        try {
            List<Employee__c> employeeList = [ SELECT Id, Name, User__c, ReplacedForUserId__c, Cloning_is_Completed__c,
                Replaced_For__c, Replaced_For__r.Is_Employee_Replaced__c, Replaced_For__r.Employee_Replaced_With_Name__c FROM Employee__c  WHERE Id = :recordId
            ];
            
            if (employeeList.isEmpty()) {  return 'Error: EMPLOYEE_NOT_FOUND'; }
            
            Employee__c emp = employeeList[0];
            
            // Validate required fields
            if (emp.User__c == null || emp.ReplacedForUserId__c == null || emp.Replaced_For__c == null) { return 'Error: REPLACEMENT_MISSING'; }
            
            // Check if the replacement has already been done
            if (emp.Replaced_For__r != null && emp.Replaced_For__r.Is_Employee_Replaced__c) {
                return 'Error: EMPLOYEE_REPLACED::' + emp.Replaced_For__r.Employee_Replaced_With_Name__c;
            }
            
            // Proceed with replacement if not already cloned
            if (!emp.Cloning_is_Completed__c) {
                Map<String, String> oldToNewUserMap = new Map<String, String>();
                oldToNewUserMap.put(emp.ReplacedForUserId__c, emp.User__c);
                // Trigger sharing logic
                CustomSharingService.employeeReplacement(oldToNewUserMap);
                // Mark cloning complete for new employee
                emp.Cloning_is_Completed__c = true;
                
                // Mark replacement done for old employee
                Employee__c oldEmployee = new Employee__c(
                    Id = emp.Replaced_For__c,
                    Is_Employee_Replaced__c = true,
                    Employee_Replaced_With_Name__c = emp.Name
                );
                system.debug('Replacement Done');
                // Enqueue Queueable to perform update
                System.enqueueJob(new EmployeeReplacementUpdateQueue(new List<Employee__c>{ emp, oldEmployee }));
                
                //update new List<Employee__c>{ emp, oldEmployee };
                    
                    return 'Success: Employee access (Beat, PJP, Product Mappings) successfully transferred.';
            } else {
                return 'Error: CLONING_COMPLETED';
            }
        } catch (Exception ex) {
            System.debug('Exception in employeeReplacement: ' + ex.getMessage());
            return 'Error: ' + ex.getMessage();
        }
    }


    /**
     * Transfer (in-place) variant of Employee Replacement.
     * Instead of cloning records from old user to new user, this updates
     * existing Product Mappings, Employee Customer Assignments, Beats and
     * PJPs so that they now belong to the new DSM. Beats have both User__c
     * and OwnerId updated (the "user tag" on Child_beat__c).
     */
    @AuraEnabled
    public static String employeeTransferAction(Id recordId) {
        try {
            List<Employee__c> employeeList = [
                SELECT Id, Name, User__c, ReplacedForUserId__c, Cloning_is_Completed__c,
                    Replaced_For__c, Replaced_For__r.Is_Employee_Replaced__c, Replaced_For__r.Employee_Replaced_With_Name__c
                FROM Employee__c
                WHERE Id = :recordId
            ];

            if (employeeList.isEmpty()) { return 'Error: EMPLOYEE_NOT_FOUND'; }

            Employee__c emp = employeeList[0];

            // Validate required fields
            if (emp.User__c == null || emp.ReplacedForUserId__c == null || emp.Replaced_For__c == null) {
                return 'Error: REPLACEMENT_MISSING';
            }

            // Already replaced?
            if (emp.Replaced_For__r != null && emp.Replaced_For__r.Is_Employee_Replaced__c) {
                return 'Error: EMPLOYEE_REPLACED::' + emp.Replaced_For__r.Employee_Replaced_With_Name__c;
            }

            if (emp.Cloning_is_Completed__c) {
                return 'Error: CLONING_COMPLETED';
            }

            Map<String, String> oldToNewUserMap = new Map<String, String>();
            oldToNewUserMap.put(emp.ReplacedForUserId__c, emp.User__c);

            // Run transfer in without-sharing context
            EmployeeTransferService.transferEmployee(oldToNewUserMap);

            // Mark new employee complete
            emp.Cloning_is_Completed__c = true;

            // Mark replacement done on old employee
            Employee__c oldEmployee = new Employee__c(
                Id = emp.Replaced_For__c,
                Is_Employee_Replaced__c = true,
                Employee_Replaced_With_Name__c = emp.Name
            );

            System.debug('Employee Transfer Done for Employee: ' + emp.Id);
            System.enqueueJob(new EmployeeReplacementUpdateQueue(new List<Employee__c>{ emp, oldEmployee }));

            return 'Success: Employee records (Beats, PJPs, Product Mappings, Customer Assignments) successfully transferred to new DSM.';
        } catch (Exception ex) {
            System.debug('Exception in employeeTransferAction: ' + ex.getMessage());
            return 'Error: ' + ex.getMessage();
        }
    }


    /**----------LWC Controller ---------**/
    public class DataBox{
        @AuraEnabled public string profileName;
        @AuraEnabled public list<UserRole> roleList = new list<UserRole>();
        @AuraEnabled public list<User> userList = new list<User>();
        @AuraEnabled public Employee__c employee = new Employee__c();   
        @AuraEnabled public List<String> profileList = new List<String>();   
        @AuraEnabled public List<Map<String, String>> payrollList = new List<Map<String, String>>();   
        @AuraEnabled public Map<String,Decimal> hirachyNumberMap = new Map<String,Decimal>();   
        @AuraEnabled public Map<String,String> payrollMap = new Map<String,String>();   
        @AuraEnabled public list<Employee__c> employeesList = new list<Employee__c>();   
        @AuraEnabled public  List<CategoryToSalesChannelData__mdt> catoryToSalsChannelList = new List<CategoryToSalesChannelData__mdt> ();
        @AuraEnabled public List<PBIS_Policy__c> pbisPolicyList = new List<PBIS_Policy__c>();
        @AuraEnabled public List<Area__c> territoryList = new List<Area__c>(); 
        @AuraEnabled public List<Employee_Creation_Access__mdt> metadataRecordsList = new List<Employee_Creation_Access__mdt>();
        @AuraEnabled public User currentUser = new User();
        @AuraEnabled public string employeeName;
        @AuraEnabled public boolean duplicateFound;
        @AuraEnabled public String duplicateField;
        
        @AuraEnabled public boolean editEmployee;
        @AuraEnabled public String approvalMessage;
        @AuraEnabled public String recordId;
        @AuraEnabled public User userRecord;
        @AuraEnabled public boolean isEmployeeFound;
    }
    @AuraEnabled(cacheable=false)
    public static DataBox getAllData(string recordId) {
        DataBox db = new DataBox();
        string userId = UserInfo.getUserId();
        user currentUser = [select Id,Name,Profile.Name,ASM_TSM__c,Employee_Code__c,Territory__c,State__c,District__c,
                            Region__c,Profile_Name__c,Area__c,Territory_Name__c,Sales_Channel__c,Working_District__c,
                            isAdmin__c,Sr_TSE_TSE__c,RSM__c,Heirarchial_Number__c from user where Id =:userId limit 1];
        db.currentUser = currentUser;
        string currentUserProfieName = currentUser.Profile.Name; 
        //We are showing only suborindinate role while creating users
        Set<Id> subordinateRoleIds = RoleHeirarchyUtility.getSubordinateUserRoleIds(userId);
        
        db.roleList =  [SELECT Id, Name FROM UserRole where Id IN :subordinateRoleIds];
        db.userList = [select Id,Name,Profile.Name,ASM_TSM__c,Employee_Code__c,Territory__c,State__c,District__c,
                       Region__c,Profile_Name__c,Area__c,Territory_Name__c,Sales_Channel__c,Working_District__c,
                       Sr_TSE_TSE__c,RSM__c,Heirarchial_Number__c from User where IsActive = true and
                       ( Profile.UserLicense.Name = 'Salesforce' Or  Profile.UserLicense.Name = 'Salesforce Platform')];
        if(recordId != null && recordId != '')
        {
            Employee__c employee = [
                SELECT
                Id, Name, Role__c, Role_Id__c, Payroll__c,
                Profile__c, Mail_Id__c, User_Name__c, Aadhar_Number__c, Primary_Phone_Number__c,
                Secondary_Phone_Number__c, PAN__c, DOB__c, DOJ__c, User_Type__c,Role_Name__c,
                Reporting_Manager__c, Reporting_Manager__r.Name, Reporting_Manager_Name__c, Replaced_For__c, Replaced_For__r.Name,
                Replaced_For_Name__c, Payroll_Type__c, Employee_Code__c, Vendor_Code__c, Band__c,
                Shift_Time__c, Headquarter__c, Relieving_date__c, Designation__c, District_In_charge__c,
                Sales_Channel__c, Region__c, Working_State__c, Working_District__c, Territory__c,
                Territory__r.Name, Territory_Name__c, Area__c, ASM_TSM__c, RSM__c,Contract_Type__c,
                Heirarchial_Number__c, Sr_TSE_TSE__c, State__c, District__c, Pincode__c,
                Street__c, Category__c, Employee_Approver_3_HR__c, Primary_Customer_Approver_1__c, Primary_Customer_Approver_2__c,
                Primary_Customer_Approver_3_CD__c, Secondary_Customer_Approver_1__c, Secondary_Customer_Approver_2__c,
                PJP_Approver_1__c, PJP_Approver_2__c, Expense_Approver_1__c, Expense_Approver_2_Finance_Department__c,
                Basic_Pay__c, Gross_Salary__c, Minimum_Order_value__c,
                Approval_Status__c,Is_Record_Opned_By_Owner__c,Approver_RSM__r.Name,Approver_RSM__c,OwnerId,Is_Active__c,User__c,
                Secondary_Customer_Approver_1__r.Name,Secondary_Customer_Approver_2__r.Name,
                ASM_TSM__r.Name,RSM__r.Name,Employee_Approver_3_HR__r.Name,
                Primary_Customer_Approver_1__r.Name,Primary_Customer_Approver_2__r.Name,Primary_Customer_Approver_3_CD__r.Name,
                PJP_Approver_1__r.Name,PJP_Approver_2__r.Name,Cloning_is_Completed__c,
                Expense_Approver_1__r.Name,Expense_Approver_2_Finance_Department__r.Name,Opened_by_Credited_User__c,Alternate_Sales_Channel__c,
                Leave_HR__c,Leave_HR__r.Name,Leave_Approver_L1__c,Leave_Approver_L1__r.Name,
                PBIS_Policy__c, PBIS_Policy__r.Name
                FROM Employee__c
                WHERE Id = :recordId
            ];
            
            if((employee.Role_Name__c == null ||employee.Role_Name__c == '')  && currentUser.isAdmin__c && employee.User__c !=null )
            {
                //If in User Object Role is Deleted In Employee Object Still role is present that we are removing
                if(employee.Id != null)
                {
                    employee__c emp = new employee__c();
                    emp.Id = employee.Id;
                    emp.Role__c = null;
                    database.update(emp,false); 
                }
            }
            
            db.employee = employee;
            Boolean editEmployee = false;
            String approvalMessage = 'Access Denied'; // Default message
            Boolean isCurrentUserApprover = false;
            
            // Step 1: Get active approval process instances
            List<ProcessInstance> processInstances = [
                SELECT Id
                FROM ProcessInstance
                WHERE TargetObjectId =: employee.Id
                AND Status = 'Pending'
            ];
            if (!processInstances.isEmpty()) {
                
                Set<Id> processInstanceIds = new Set<Id>();
                for (ProcessInstance pi : processInstances) {
                    processInstanceIds.add(pi.Id);
                }
                
                // Step 2: Get pending approvers
                if (!processInstanceIds.isEmpty()) {
                    List<ProcessInstanceWorkitem> workItems = [
                        SELECT ActorId
                        FROM ProcessInstanceWorkitem
                        WHERE ProcessInstanceId IN :processInstanceIds
                    ];
                    
                    for (ProcessInstanceWorkitem item : workItems) {
                        if (item.ActorId == UserInfo.getUserId()) {
                            isCurrentUserApprover = true;
                            break;
                        }
                    }
                }
            }
            
            
            // Admins always get access
            if (currentUser.isAdmin__c) {
                editEmployee = true;
                approvalMessage = 'Access Granted';
            }
            // If created by user under specific conditions
            // until it is activated owner will be TSE only to DSM Empoloyee record
            else if ( employee.Payroll__c == 'No' && employee.Is_Record_Opned_By_Owner__c && !employee.Is_Active__c &&
                     (employee.Approval_Status__c != 'Pending' && employee.Approval_Status__c != 'Level 1 Approved' &&
                      employee.Approval_Status__c != 'Level 2 Approved' && employee.Approval_Status__c != 'HR Approved')) 
            {
                editEmployee = true;
                approvalMessage = 'Access Granted 1st condition';
            }
            // HR profile can edit if status is 'Level 2 Approved' or he is current approver
            else if ( (employee.Approval_Status__c == 'Level 2 Approved' || isCurrentUserApprover) && currentUser.Profile.Name == 'HR')
            {
                editEmployee = true;
                approvalMessage = 'Access Granted 2nd condition';
            }
            else if(isCurrentUserApprover)
            {
                editEmployee = true;
                approvalMessage = 'Access Granted 3nd condition';
            }
            // Remaining restricted cases
            else {
                //Active User Opned by Hr or 
                 if (employee.Is_Active__c && (currentUser.Profile.Name == 'HR' ||
                      (employee.Payroll__c == 'No' && (employee.Is_Record_Opned_By_Owner__c || employee.Opened_by_Credited_User__c))) ) 
                {
                    editEmployee = false;
                    approvalMessage = 'You cannot edit employee. The employee has been activated by the administrator. Please contact your administrator';
                } 
                else if ( currentUser.Profile.Name == 'HR' && !isCurrentUserApprover) 
                {
                    editEmployee = false;
                    if(employee.Approval_Status__c == 'HR Approved')
                    {
                        approvalMessage = 'You cannot edit employee, as the approval status is "' + employee.Approval_Status__c + '".';
                    }
                    else
                    {
                        approvalMessage = 'You are not the current approver. Please check the approval history to view the assigned approver.';
                    }
                }
               
                else if (employee.Payroll__c == 'No' && employee.Is_Record_Opned_By_Owner__c &&
                         (employee.Approval_Status__c == 'Pending' || employee.Approval_Status__c == 'Level 1 Approved' ||
                          employee.Approval_Status__c == 'Level 2 Approved' ||employee.Approval_Status__c == 'HR Approved')) 
                {
                    editEmployee = false;
                    approvalMessage = 'You cannot edit employee, as the approval status is "' + employee.Approval_Status__c + '".';
                }
                else if(employee.User__c != null && employee.User__c == currentUser.Id)
                {
                    approvalMessage = 'You cannot edit your own employee details. Please contact your administrator';
                }
            }
            
            db.editEmployee = editEmployee;
            db.approvalMessage = approvalMessage;
        }
        db.territoryList = [select Id,Name,Area__c,Region__c,District__c,Sales_Channel__c,ASM__c,RSM__c from Area__c];
        db.employeesList = [select Id,Name,Employee_Code__c,Reporting_Manager__r.Territory__c,User__c,Reporting_Manager__c,
                            Payroll__c,Payroll_Type__c,Contract_Type__c,Band__c,Shift_Time__c,Headquarter__c,
                            Designation__c,District_In_charge__c,Sales_Channel__c,Category__c,Region__c,Area__c,Territory_Name__c,
                            Territory__c,Territory__r.Name,Secondary_Customer_Approver_1__c,Secondary_Customer_Approver_2__c,
                            Primary_Customer_Approver_1__c,Primary_Customer_Approver_2__c,Primary_Customer_Approver_3_CD__c,
                            ASM_TSM__c,RSM__c,Employee_Approver_3_HR__c,PJP_Approver_1__c,Expense_Approver_1__c,
                            Expense_Approver_2_Finance_Department__c,Minimum_Order_value__c,
                            Secondary_Customer_Approver_1__r.Name,Secondary_Customer_Approver_2__r.Name,
                            ASM_TSM__r.Name,RSM__r.Name,Employee_Approver_3_HR__r.Name,
                            Primary_Customer_Approver_1__r.Name,Primary_Customer_Approver_2__r.Name,Primary_Customer_Approver_3_CD__r.Name,
                            PJP_Approver_1__r.Name, Expense_Approver_1__r.Name,Expense_Approver_2_Finance_Department__r.Name,
                            Gross_Salary__c,Basic_Pay__c,Alternate_Sales_Channel__c
                            from Employee__c where User__c != null AND Is_Employee_Replaced__c = false];
        
        
        db.catoryToSalsChannelList = [SELECT Category__c, Sales_Channel__c FROM CategoryToSalesChannelData__mdt];

        // Active Primary PBIS Policies, filtered client-side by the employee's Sales Channels.
        db.pbisPolicyList = [SELECT Id, Name, Sales_Channels__c FROM PBIS_Policy__c WHERE Is_Active__c = true ORDER BY Name];

        // Query Custom Metadata records for Employee_Creation_Access__mdt
        List<Employee_Creation_Access__mdt> metadataRecordsList = [
            SELECT Payroll__c, Non_Payroll__c, Hierarchy_Number__c, Label, Required_Approvers__c, Employee_Type__c
            FROM Employee_Creation_Access__mdt
            ORDER BY Hierarchy_Number__c ASC
        ];
        
        db.metadataRecordsList = metadataRecordsList;
        
        Map<String, Decimal> hierarchyMap = new Map<String, Decimal>();
        Map<String, String> payrollMap = new Map<String, String>();
        //current user's metadata record
        Employee_Creation_Access__mdt currentUserMetadata;
        for (Employee_Creation_Access__mdt record : metadataRecordsList) {
            hierarchyMap.put(record.Label, record.Hierarchy_Number__c);
            payrollMap.put(record.Label,record.Employee_Type__c);
            if (record.Label == currentUserProfieName) {
                currentUserMetadata = record;
            }
        }
        
        if (currentUserMetadata != null) {
            Decimal currentUserHierarchy = currentUserMetadata.Hierarchy_Number__c;
            Set<String> allowedProfileLabels = new Set<String>();
            // Filter allowed profiles based on current user's access
            for (Employee_Creation_Access__mdt record : metadataRecordsList) {
                if ((record.Hierarchy_Number__c < currentUserHierarchy || currentUser.isAdmin__c)
                    && record.Label !='System Administrator')
                {
                    if (currentUserMetadata.Payroll__c && record.Employee_Type__c == 'Yes') {
                        allowedProfileLabels.add(record.Label);
                    }
                    if (currentUserMetadata.Non_Payroll__c && record.Employee_Type__c == 'No') {
                        allowedProfileLabels.add(record.Label);
                    }
                }
            }
            
            db.hirachyNumberMap = hierarchyMap;
            db.payrollMap = payrollMap;
            db.profileList = new List<String>(allowedProfileLabels);
            
            // Set allowed employee type picklist options
            List<Map<String, String>> allowedOptions = new List<Map<String, String>>();
            if (currentUserMetadata.Payroll__c) {
                allowedOptions.add(new Map<String, String>{ 'label' => 'Yes', 'value' => 'Yes' });
            }
            if (currentUserMetadata.Non_Payroll__c) {
                allowedOptions.add(new Map<String, String>{ 'label' => 'No', 'value' => 'No' });
            }
            
            db.payrollList = allowedOptions;
            
        }
        
        
        
        return db;
        
    } 
    @AuraEnabled
    public static DataBox duplicationCheck(Employee__c employeeData) {
        DataBox db = new DataBox();
        db.employeeName = '';
        db.duplicateFound = false;
        db.duplicateField = '';
        
        if (employeeData == null) {
            return db;
        }
        
        // Check User_Name__c duplication
        if (!String.isBlank(employeeData.User_Name__c)) {
            List<Employee__c> userDup = [
                SELECT Id, Name 
                FROM Employee__c 
                WHERE User_Name__c = :employeeData.User_Name__c 
                AND Id != :employeeData.Id 
                LIMIT 1
            ];
            
            if (!userDup.isEmpty()) {
                db.employeeName = userDup[0].Name;
                db.duplicateFound = true;
                db.duplicateField = 'User_Name__c';
                return db;
            }
        }
        
        // Check Aadhar Number duplication
        if (!String.isBlank(employeeData.Aadhar_Number__c)) {
            List<Employee__c> aadharDup = [
                SELECT Id, Name 
                FROM Employee__c 
                WHERE Aadhar_Number__c = :employeeData.Aadhar_Number__c 
                AND Id != :employeeData.Id 
                LIMIT 1
            ];
            
            if (!aadharDup.isEmpty()) {
                db.employeeName = aadharDup[0].Name;
                db.duplicateFound = true;
                db.duplicateField = 'Aadhar_Number__c';
                return db;
            }
        }
        
        // Check Employee Code duplication
        if (!String.isBlank(employeeData.Employee_Code__c)) {
            List<Employee__c> codeDup = [
                SELECT Id, Name 
                FROM Employee__c 
                WHERE Employee_Code__c = :employeeData.Employee_Code__c 
                AND Id != :employeeData.Id 
                LIMIT 1
            ];
            
            if (!codeDup.isEmpty()) {
                db.employeeName = codeDup[0].Name;
                db.duplicateFound = true;
                db.duplicateField = 'Employee_Code__c';
                return db;
            }
        }
        return db;
    }
    @AuraEnabled
    public static DataBox saveData(Employee__c employeeData) {
        DataBox db = new DataBox();
        Boolean editEmployee = false;
        if (employeeData.Id != null) {
            String userId = UserInfo.getUserId();
            User currentUser = [
                SELECT Id, Name, Profile.Name, isAdmin__c
                FROM User 
                WHERE Id = :userId 
                LIMIT 1
            ];
            
            Employee__c employee = [
                SELECT Id, Name, Payroll__c, Is_Record_Opned_By_Owner__c, Is_Active__c,
                Approval_Status__c, Approver_RSM__r.Name, Approver_RSM__c, OwnerId,User__c
                FROM Employee__c 
                WHERE Id = :employeeData.Id
                LIMIT 1
            ];
            
            db.employee = employee;
            
            Boolean isCurrentUserApprover = false;
            String approvalMessage = 'Access Denied';
            
            // Step 1: Get active approval process instances
            List<ProcessInstance> processInstances = [
                SELECT Id
                FROM ProcessInstance
                WHERE TargetObjectId =: employee.Id
                AND Status = 'Pending'
            ];
            if (!processInstances.isEmpty()) {
                
                Set<Id> processInstanceIds = new Set<Id>();
                for (ProcessInstance pi : processInstances) {
                    processInstanceIds.add(pi.Id);
                }
                
                // Step 2: Get pending approvers
                if (!processInstanceIds.isEmpty()) {
                    List<ProcessInstanceWorkitem> workItems = [
                        SELECT ActorId
                        FROM ProcessInstanceWorkitem
                        WHERE ProcessInstanceId IN :processInstanceIds
                    ];
                    
                    for (ProcessInstanceWorkitem item : workItems) {
                        if (item.ActorId == UserInfo.getUserId()) {
                            isCurrentUserApprover = true;
                            break;
                        }
                    }
                }
            }
            
            
            // Admins always get access
            if (currentUser.isAdmin__c) {
                editEmployee = true;
                approvalMessage = 'Access Granted';
            }
            // If created by user under specific conditions
            else if ( employee.Payroll__c == 'No' && employee.Is_Record_Opned_By_Owner__c && !employee.Is_Active__c &&
                     (employee.Approval_Status__c != 'Pending' && employee.Approval_Status__c != 'Level 1 Approved' &&
                      employee.Approval_Status__c != 'Level 2 Approved' && employee.Approval_Status__c != 'HR Approved')) 
            {
                editEmployee = true;
                approvalMessage = 'Access Granted 1st condition';
            }
            // HR profile can edit if status is 'Level 2 Approved' or he is current approver
            else if ( (employee.Approval_Status__c == 'Level 2 Approved' || isCurrentUserApprover) && currentUser.Profile.Name == 'HR')
            {
                editEmployee = true;
                approvalMessage = 'Access Granted 2sd condition';
            }
            else if(isCurrentUserApprover)
            {
                editEmployee = true;
                approvalMessage = 'Access Granted 3nd condition';
            }
            // Remaining restricted cases
            else {
                if ((currentUser.Profile.Name == 'HR' || (employee.Payroll__c == 'No' && employee.Is_Record_Opned_By_Owner__c))
                    && employee.Is_Active__c ) 
                {
                    editEmployee = false;
                    approvalMessage = 'You cannot edit employee. The employee has been activated by the administrator. Please contact your administrator';
                } 
                else if ( currentUser.Profile.Name == 'HR' && !isCurrentUserApprover) 
                {
                    editEmployee = false;
                    if(employee.Approval_Status__c == 'HR Approved')
                    {
                        approvalMessage = 'You cannot edit employee, as the approval status is "' + employee.Approval_Status__c + '".';
                    }
                    else
                    {
                        approvalMessage = 'You are not the current approver. Please check the approval history to view the assigned approver.';
                    }
                }
                else if (employee.Payroll__c == 'No' && employee.Is_Record_Opned_By_Owner__c &&
                         (employee.Approval_Status__c == 'Pending' || employee.Approval_Status__c == 'Level 1 Approved' ||
                          employee.Approval_Status__c == 'Level 2 Approved' ||employee.Approval_Status__c == 'HR Approved')) 
                {
                    editEmployee = false;
                    approvalMessage = 'You cannot edit employee, as the approval status is "' + employee.Approval_Status__c + '".';
                }
                else if(employee.User__c != null && employee.User__c == currentUser.Id)
                {
                    approvalMessage = 'You cannot edit your own employee details. Please contact your administrator';
                }
            }
            
            db.editEmployee = editEmployee;
            db.approvalMessage = approvalMessage;
            
            // Allow update only if editable
            if (editEmployee) {
                upsert employeeData;
                db.recordId = employeeData.Id;
            }
        } else {
            // New employee creation
            editEmployee = true;
            db.editEmployee = editEmployee;
            upsert employeeData;
            db.recordId = employeeData.Id;
        }
        
        return db;
    }
    
    /**------------Record View Form----------**/
    @AuraEnabled
    public static DataBox getRecordViewFormData(String recordId, String objectName) {
        DataBox db = new DataBox();
        string userId = UserInfo.getUserId();
        user currentUser = [select Id,Name,Profile.Name,ASM_TSM__c,Employee_Code__c,Territory__c,State__c,District__c,
                            Region__c,Profile_Name__c,Area__c,Territory_Name__c,Sales_Channel__c,Working_District__c,
                            isAdmin__c,Sr_TSE_TSE__c,RSM__c,Heirarchial_Number__c from user where Id =:userId limit 1];
        db.currentUser = currentUser;
        string currentUserProfieName = currentUser.Profile.Name; 
        if (String.isNotBlank(recordId) && String.isNotBlank(objectName)) {
            objectName = objectName.toLowerCase();
            db.isEmployeeFound = false;
            if (objectName == 'employee') {
                // Query only Employee__c
                db.employee = [
                    SELECT Id, Name, Role__c, Role_Id__c, Payroll__c,
                    Profile__c, Mail_Id__c, User_Name__c, Aadhar_Number__c, Primary_Phone_Number__c,
                    Secondary_Phone_Number__c, PAN__c, DOB__c, DOJ__c, User_Type__c,
                    Reporting_Manager__c, Reporting_Manager__r.Name, Reporting_Manager_Name__c, Replaced_For__c, Replaced_For__r.Name,
                    Replaced_For_Name__c, Payroll_Type__c, Employee_Code__c, Vendor_Code__c, Band__c,
                    Shift_Time__c, Headquarter__c, Relieving_date__c, Designation__c, District_In_charge__c,
                    Sales_Channel__c, Region__c, Working_State__c, Working_District__c, Territory__c,
                    Territory__r.Name, Territory_Name__c, Area__c, ASM_TSM__c, RSM__c,
                    Heirarchial_Number__c, Sr_TSE_TSE__c, State__c, District__c, Pincode__c,
                    Street__c, Category__c, Employee_Approver_3_HR__c, Primary_Customer_Approver_1__c, Primary_Customer_Approver_2__c,
                    Primary_Customer_Approver_3_CD__c, Secondary_Customer_Approver_1__c, Secondary_Customer_Approver_2__c,
                    PJP_Approver_1__c, PJP_Approver_2__c, Expense_Approver_1__c, Expense_Approver_2_Finance_Department__c,
                    Basic_Pay__c, Gross_Salary__c, Minimum_Order_value__c,Leave_HR__c,Leave_Approver_L1__c,
                    Employee_Remarks__c,Expense_Back_Day_Entry_Limit__c,Expense_Start_Date__c,Expense_End_Date__c
                    FROM Employee__c
                    WHERE Id = :recordId
                ];
                db.isEmployeeFound = true;
            } 
            else if (objectName == 'user') {
                // Query User and related Employee__c
                db.userRecord = [
                    SELECT Id, Name, UserRole.Name, Profile_Name__c
                    FROM User
                    WHERE Id = :recordId
                ];
                
                List<Employee__c> empList = [
                    SELECT Id, Name, Role__c, Role_Id__c, Payroll__c,
                    Profile__c, Mail_Id__c, User_Name__c, Aadhar_Number__c, Primary_Phone_Number__c,
                    Secondary_Phone_Number__c, PAN__c, DOB__c, DOJ__c, User_Type__c,
                    Reporting_Manager__c, Reporting_Manager__r.Name, Reporting_Manager_Name__c, Replaced_For__c, Replaced_For__r.Name,
                    Replaced_For_Name__c, Payroll_Type__c, Employee_Code__c, Vendor_Code__c, Band__c,
                    Shift_Time__c, Headquarter__c, Relieving_date__c, Designation__c, District_In_charge__c,
                    Sales_Channel__c, Region__c, Working_State__c, Working_District__c, Territory__c,
                    Territory__r.Name, Territory_Name__c, Area__c, ASM_TSM__c, RSM__c,
                    Heirarchial_Number__c, Sr_TSE_TSE__c, State__c, District__c, Pincode__c,
                    Street__c, Category__c, Employee_Approver_3_HR__c, Primary_Customer_Approver_1__c, Primary_Customer_Approver_2__c,
                    Primary_Customer_Approver_3_CD__c, Secondary_Customer_Approver_1__c, Secondary_Customer_Approver_2__c,
                    PJP_Approver_1__c, PJP_Approver_2__c, Expense_Approver_1__c, Expense_Approver_2_Finance_Department__c,
                    Basic_Pay__c, Gross_Salary__c, Minimum_Order_value__c,Leave_HR__c,Leave_Approver_L1__c,
                    Employee_Remarks__c,Expense_Back_Day_Entry_Limit__c,Expense_Start_Date__c,Expense_End_Date__c
                    FROM Employee__c
                    WHERE User__c = :recordId
                    LIMIT 1
                ];
                if (!empList.isEmpty()) {
                    db.isEmployeeFound = true;
                    db.employee = empList[0];
                }
            }
        }
        db.profileName = currentUserProfieName;
        return db;
    }

    // Feature 2: Deactivate User with Beat Status Option
    @AuraEnabled
    public static String deactivateUserWithBeatOption(Id recordId, String beatOption) {
        try {
            Employee__c emp = [SELECT Id, User__c FROM Employee__c WHERE Id = :recordId LIMIT 1];
            if (emp.User__c == null) {
                throw new AuraHandledException('No associated User to deactivate.');
            }
            
            // Call existing deactivation logic
            deactivateUser(recordId);
 
            // If BEATS_INACTIVE, deactivate all beats asynchronously
            if (beatOption == 'BEATS_INACTIVE') {
                deactivateUserBeats(emp.User__c);
            }


            // Share customer access to hierarchy
            CustomSharingService.shareCustomerAccessToHierarchy(emp.User__c);

            return 'Success: User Deactivated Successfully';
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            return 'Error: ' + ex.getMessage();
        }
    }
    
    @future
    public static void deactivateUserBeats(Id userId) {
        List<Child_beat__c> userBeats = [
            SELECT Id 
            FROM Child_beat__c 
            WHERE OwnerId = :userId 
            AND Active__c = true
        ];
        if (!userBeats.isEmpty()) {
            for (Child_beat__c b : userBeats) {
                b.Active__c = false;
            }
            update userBeats;
        }
    }

    // Feature 4: Get Users for Beat Sharing
    public class UserWrapper {
        @AuraEnabled public Id userId;
        @AuraEnabled public String name;
        @AuraEnabled public String profileName;
    }

    @AuraEnabled
    public static List<UserWrapper> getUsersForBeatSharing(Id employeeId) {
        // Get the employee's reporting manager
        Employee__c emp = [SELECT Id, User__c, Reporting_Manager__c FROM Employee__c WHERE Id = :employeeId LIMIT 1];
        if (emp.Reporting_Manager__c == null) return new List<UserWrapper>();

        Id reportingManagerUserId = emp.Reporting_Manager__c;

        // Get all employees reporting to the same manager, excluding current employee
        List<Employee__c> peers = [
            SELECT Id, Name, User__c, Profile__c
            FROM Employee__c
            WHERE Reporting_Manager__c = :reportingManagerUserId
            AND Id != :employeeId
            AND User__c != null
            AND Is_Active__c = true
        ];

        List<UserWrapper> result = new List<UserWrapper>();
        for (Employee__c peer : peers) {
            UserWrapper uw = new UserWrapper();
            uw.userId = peer.User__c;
            uw.name = peer.Name;
            uw.profileName = peer.Profile__c;
            result.add(uw);
        }
        return result;
    }
    
    @AuraEnabled
    public static String shareBeatToUser(Id employeeId, Id targetUserId) {
        try {
            Employee__c emp = [SELECT Id, User__c FROM Employee__c WHERE Id = :employeeId LIMIT 1];
            if (emp.User__c == null) return 'Error: No user associated with this employee.';
            
            // Get all active beats of source employee
            List<Child_beat__c> sourceBeats = [
                SELECT Id, Primary_Customer__c 
                FROM Child_beat__c 
                WHERE OwnerId = :emp.User__c 
                AND Active__c = true
            ];
            if (sourceBeats.isEmpty()) return 'Error: No active beats found for this employee.';
            
            // Collect Primary_Customer__c account IDs
            Set<Id> accountIds = new Set<Id>();
            Set<Id> sourceBeatIds = new Set<Id>();
            for (Child_beat__c beat : sourceBeats) {
                if (beat.Primary_Customer__c != null) accountIds.add(beat.Primary_Customer__c);
                sourceBeatIds.add(beat.Id);
            }
            
            // Collect Junction_Beat__c account IDs
            List<Junction_Beat__c> beatItems = [
                SELECT Id, Account__c, Child_beat__c 
                FROM Junction_Beat__c 
                WHERE Child_beat__c IN :sourceBeatIds
                AND Account__c != null
            ];
            for (Junction_Beat__c jb : beatItems) {
                accountIds.add(jb.Account__c);
            }
            
            // Share Account records
            List<AccountShare> sharesToInsert = new List<AccountShare>();
            Set<Id> existingAccountIds = new Set<Id>();
            for (AccountShare s : [
                SELECT AccountId FROM AccountShare 
                WHERE AccountId IN :accountIds 
                AND UserOrGroupId = :targetUserId
            ]) {
                existingAccountIds.add(s.AccountId);
            }
            for (Id accId : accountIds) {
                if (!existingAccountIds.contains(accId)) {
                    sharesToInsert.add(CustomSharingService.buildAccountShare(accId, targetUserId));
                }
            }
            if (!sharesToInsert.isEmpty()) {
                Database.insert(sharesToInsert, false);
            }
            
            // Share Child_beat__c records
            List<Child_beat__Share> beatSharesToInsert = new List<Child_beat__Share>();
            Set<Id> existingBeatIds = new Set<Id>();
            for (Child_beat__Share s : [
                SELECT ParentId FROM Child_beat__Share 
                WHERE ParentId IN :sourceBeatIds 
                AND UserOrGroupId = :targetUserId
            ]) {
                existingBeatIds.add(s.ParentId);
            }
            for (Child_beat__c beat : sourceBeats) {
                if (!existingBeatIds.contains(beat.Id)) {
                    Child_beat__Share beatShare = new Child_beat__Share();
                    beatShare.ParentId = beat.Id;
                    beatShare.UserOrGroupId = targetUserId;
                    beatShare.AccessLevel = 'Edit';
                    beatShare.RowCause = Schema.Child_beat__Share.RowCause.Manual;
                    beatSharesToInsert.add(beatShare);
                }
            }
            if (!beatSharesToInsert.isEmpty()) {
                Database.insert(beatSharesToInsert, false);
            }
            
            return 'Success: Beats and accounts shared successfully';
            
        } catch (Exception ex) {
            return 'Error: ' + ex.getMessage();
        }
    }
}