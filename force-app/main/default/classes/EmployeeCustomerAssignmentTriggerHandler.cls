public class EmployeeCustomerAssignmentTriggerHandler
{
    // Set to true by bulk data movement flows (e.g. Employee Transfer) to
    // bypass the heavy before/after update logic. Always reset in finally.
    public static Boolean bypassForEmployeeTransfer = false;

    //before Insert Sharing the accounts based on assignment
    public static void beforeInsert(List<Employee_Customer_Assignment__c> newPrimaryAssignments) {

        Set<Id> exeIds = new Set<Id>();
        Set<Id> customerIds = new Set<Id>();
        // step 1: Getting Ids and Mapping Owner Id
        for (Employee_Customer_Assignment__c mapping : newPrimaryAssignments) {
            if (mapping.Executive__c != null) {
                mapping.OwnerId = mapping.Executive__c;
                exeIds.add(mapping.Executive__c);
            }
            if(mapping.Customer__c != null)
            {
                customerIds.add(mapping.Customer__c);
                mapping.Customer_Id__c = mapping.Customer__c; 
            }
        }
        
        // Step 2: Map UserId → EmployeeId (for Exectuive__c fallback)
        Map<Id, Id> employeetoUserMap = new Map<Id, Id>();
        if (!exeIds.isEmpty()) {
            List<Employee__c> employeeList = [SELECT Id, User__c FROM Employee__c WHERE User__c IN :exeIds ];
            for (Employee__c emp : employeeList) {
                if (emp.User__c != null) employeetoUserMap.put(emp.User__c, emp.Id); 
            }
        }
        
        // Step 3: Set Employee fields
        for (Employee_Customer_Assignment__c mapping : newPrimaryAssignments) {
            if (mapping.Employee__c == null && mapping.Executive__c != null && employeetoUserMap.containsKey(mapping.Executive__c)) {
                mapping.Employee__c = employeetoUserMap.get(mapping.Executive__c);
            }
        }
        
        // Step 4: Getting Reporting Managers
        Set<String> empIds = new Set<String>();
        map<String,String> executiveToReportingManager = new map<String,String>();
        for (Employee_Customer_Assignment__c eca : newPrimaryAssignments) {
            if (eca.Employee__c != null && eca.Customer__c != null) {
                empIds.add(eca.Employee__c);
                if(eca.Reporting_Manager_Employee_Id__c != null)
                {
                    executiveToReportingManager.put(eca.Employee__c,eca.Reporting_Manager_Employee_Id__c);
                }
            }
        }
        
        //Step 5: Getting Manager Primary Assignments
        Map<Id, Set<Id>> reportingManagersPrimaryMappings = new Map<Id, Set<Id>>();
        List<Product_Mapping__c> existingManagerPrimaryCustomerMappings = [
            SELECT Id, Customer__c, Exectuive__c FROM Product_Mapping__c 
            WHERE Customer_Type__c = 'Primary Customer'AND Exectuive__c IN :executiveToReportingManager.values()
            AND Customer__c != null
        ];
        for (Product_Mapping__c rMapping : existingManagerPrimaryCustomerMappings) {
            if (!reportingManagersPrimaryMappings.containsKey(rMapping.Exectuive__c)) {
                reportingManagersPrimaryMappings.put(rMapping.Exectuive__c, new Set<Id>());
            }
            reportingManagersPrimaryMappings.get(rMapping.Exectuive__c).add(rMapping.Customer__c);
        }

        //Step 6: Existing Mappings of DSM/SSA
        Map<String, Employee_Customer_Assignment__c> existingMap = new Map<String, Employee_Customer_Assignment__c>();
        if (!empIds.isEmpty()) {
            for (Employee_Customer_Assignment__c existing : [ SELECT Id, Employee__c, Customer__c  FROM Employee_Customer_Assignment__c
                                                             WHERE Employee__c != null AND Customer__c != null AND Employee__c IN :empIds 
                                                             AND Customer__c IN :customerIds
                                                            ]) 
            {
                String key = existing.Employee__c + '-' + existing.Customer__c;
                existingMap.put(key, existing);
            }
        }
        
        // Step 7: Check for duplicates and reporting manager validation
        Set<String> seenKeys = new Set<String>();
        for (Employee_Customer_Assignment__c eca : newPrimaryAssignments) {
            if (eca.Employee__c != null && eca.Customer__c != null) {
                String key = eca.Employee__c + '-' + eca.Customer__c;
                
                // Check if key already exists in DB
                if (existingMap.containsKey(key)) {
                    eca.addError('Duplicate mapping already exists in the system for this Employee and Customer.');
                    continue;
                }
                
                // Check duplicate in the same batch
                if (seenKeys.contains(key)) {
                    eca.addError('Duplicate mapping found in the incoming records for the same Employee and Customer.');
                }
                else { seenKeys.add(key);  }
                
                // Validate reporting manager mapping
                if (executiveToReportingManager.containsKey(eca.Employee__c)) {
                    String reportingManagerId = executiveToReportingManager.get(eca.Employee__c);
                    Boolean found = reportingManagersPrimaryMappings.containsKey(reportingManagerId) &&
                        reportingManagersPrimaryMappings.get(reportingManagerId).contains(eca.Customer__c);
                    
                    if (!found) {
                        String errorMsg = 'This executive\'s reporting manager is not assigned with this primary customer ' +
                            '(Executive Employee Code: ' + eca.Employee_Code__c +
                            ', Reporting Manager Code: ' + eca.Reporting_Manager_Employee_Code__c;
                        
                        if (eca.Primary_Customer_SAP_Code__c != null) { errorMsg += ', Customer SAP Code: ' + eca.Primary_Customer_SAP_Code__c;}
                        errorMsg += ').';
                        eca.addError(errorMsg);
                        continue;
                    }
                }
            }
        }
    }
    
    //After Insert Sharing the accounts based on assignment
    public static void afterInsert(List<Employee_Customer_Assignment__c> newPrimaryAssignments) {
        List<AccountShare> sharesToInsert = new List<AccountShare>();
        Set<Id> primaryCustomerIds = new Set<Id>();
        Map<Id, Id> primaryCustomerToExecutiveMap = new Map<Id, Id>();
        Map<Id, Id> primaryCustomerToEmployeeMap = new Map<Id, Id>();

        Set<Id> customerIdToRunAutoMappings = new Set<Id>();

        // Collect executive Ids to check active status
        Set<Id> executiveIds = new Set<Id>();
        for (Employee_Customer_Assignment__c mapping : newPrimaryAssignments) {
            if (mapping.Executive__c != null) {
                executiveIds.add(mapping.Executive__c);
            }
        }
        Set<Id> activeUserIds = new Set<Id>();
        if (!executiveIds.isEmpty()) {
            for (User u : [SELECT Id FROM User WHERE Id IN :executiveIds AND IsActive = true]) {
                activeUserIds.add(u.Id);
            }
        }

        //Step 1: Getting Primary Customer Ids and Customer Employee Map
        for (Employee_Customer_Assignment__c mapping : newPrimaryAssignments) {
            if (mapping.Customer__c != null) {
                primaryCustomerIds.add(mapping.Customer__c);
                if (mapping.Executive__c != null) {
                    primaryCustomerToExecutiveMap.put(mapping.Customer__c, mapping.Executive__c);
                    if (activeUserIds.contains(mapping.Executive__c)) {
                        sharesToInsert.add(CustomSharingService.buildAccountShare(mapping.Customer__c, mapping.Executive__c));
                    }
                } else if (mapping.Employee__c != null) {
                    primaryCustomerToEmployeeMap.put(mapping.Customer__c, mapping.Employee__c);
                }

                if(mapping.Cloned_From_Customer_Deactivation__c == false && mapping.Cloned_From_Employee_Replacement__c == false)
                {
                    customerIdToRunAutoMappings.add(mapping.Customer__c);
                }
            }
        }


        //Sharing Primary Customer
        if(!sharesToInsert.isEmpty())
        {
            CustomSharingService.shareAccounts(sharesToInsert);
        }

        //Auto Mappnings of Secondary Customers.
        //Offloaded to an async Queueable (shared with ProductMappingTriggerHandler) so the
        //heavy query/loop/insert - and the ProductMapping beforeInsert it re-fires - runs in
        //a separate transaction with its own CPU budget. The worker also narrows secondaries
        //to the executives from each primary customer's 3 most-recent primary mappings.
        if(Label.AutoShareSecondaryCustomersBasedOnPrimaryCustomer == 'TRUE'
           && !customerIdToRunAutoMappings.isEmpty())
        {
            System.enqueueJob(new AutoMapSecondaryCustomersQueueable(
                primaryCustomerIds, new Set<Id>(), primaryCustomerToExecutiveMap, primaryCustomerToEmployeeMap));
        }
    }
     
    //Duplication check and validating the primary customer assignments
    public static void beforeUpdate(List<Employee_Customer_Assignment__c> newPrimaryAssignments, Map<Id, Employee_Customer_Assignment__c> oldPrimaryAssignmentsMap) {
        if (bypassForEmployeeTransfer) return;

        // Step 1: Build a Set of new Employee-Customer pairs to check
        Set<String> newEmpCustKeys = new Set<String>();
        Set<Id> newMappingIds = new Set<Id>(); // to avoid self-check
        Set<Id> customerIds = new Set<Id>();
        Set<Id> employeeIds = new Set<Id>();
        Set<Id> exeIds = new Set<Id>();
        map<String,String> executiveToReportingManager = new map<String,String>();
        
        //Step 1: Setting the fields
        for (Employee_Customer_Assignment__c mapping : newPrimaryAssignments) {
            Employee_Customer_Assignment__c oldPM = oldPrimaryAssignmentsMap.get(mapping.Id);
            if (mapping.Customer__c != oldPM.Customer__c || mapping.Employee__c != oldPM.Employee__c || mapping.Executive__c != oldPM.Executive__c) 
            {
                newMappingIds.add(mapping.Id);
                if (mapping.Executive__c != null) {
                    mapping.OwnerId = mapping.Executive__c;
                    exeIds.add(mapping.Executive__c);   
                }
                if(mapping.Customer__c != null)
                {
                    mapping.Customer_Id__c = mapping.Customer__c; 
                    customerIds.add(mapping.Customer__c);
                }
            }
        }
        
        // Step 2: Map UserId → EmployeeId (for Exectuive__c fallback)
        Map<Id, Id> employeetoUserMap = new Map<Id, Id>();
        if (!exeIds.isEmpty()) {
            List<Employee__c> employeeList = [ SELECT Id, User__c FROM Employee__c WHERE User__c IN :exeIds ];
            for (Employee__c emp : employeeList) {
                if (emp.User__c != null) employeetoUserMap.put(emp.User__c, emp.Id);
            }
        }

        // Step 3: Set fields
        for (Employee_Customer_Assignment__c mapping : newPrimaryAssignments) {
            if (mapping.Employee__c == null && mapping.Executive__c != null && employeetoUserMap.containsKey(mapping.Executive__c)) {
                mapping.Employee__c = employeetoUserMap.get(mapping.Executive__c);
            }
        }
        
        //Step 4: Getting Reporting manager Ids
        for (Employee_Customer_Assignment__c eca : newPrimaryAssignments) {
            if (eca.Employee__c != null && eca.Customer__c != null) {
                if(eca.Reporting_Manager_Employee_Id__c != null)
                {
                    executiveToReportingManager.put(eca.Employee__c,eca.Reporting_Manager_Employee_Id__c);
                }
            }
        }
        
        //Step 5:Getting Reporting Manager Primary Customers
        Map<Id, Set<Id>> reportingManagersPrimaryMappings = new Map<Id, Set<Id>>();
        List<Product_Mapping__c> existingManagerPrimaryCustomerMappings = [
            SELECT Id, Customer__c, Exectuive__c FROM Product_Mapping__c 
            WHERE Customer_Type__c = 'Primary Customer'AND Exectuive__c IN :executiveToReportingManager.values()
            AND Customer__c != null
        ];
        for (Product_Mapping__c rMapping : existingManagerPrimaryCustomerMappings) {
            if (!reportingManagersPrimaryMappings.containsKey(rMapping.Exectuive__c)) {
                reportingManagersPrimaryMappings.put(rMapping.Exectuive__c, new Set<Id>());
            }
            reportingManagersPrimaryMappings.get(rMapping.Exectuive__c).add(rMapping.Customer__c);
        }
        
        //Detect duplicates (excluding current ones)
        if (!newMappingIds.isEmpty()) {
            List<Employee_Customer_Assignment__c> existingRecords = [
                SELECT Id, Employee__c, Customer__c 
                FROM Employee_Customer_Assignment__c
                WHERE Employee__c IN :employeeIds
                AND Customer__c IN :customerIds
                AND Id NOT IN :newMappingIds
            ];
            
            Set<String> existingKeys = new Set<String>();
            for (Employee_Customer_Assignment__c existing : existingRecords) {
                String key = existing.Employee__c + '-' + existing.Customer__c;
                existingKeys.add(key);
            }
            
            // Step 3: Add errors for duplicates
            Set<String> seenKeys = new Set<String>();
            for (Employee_Customer_Assignment__c mapping : newPrimaryAssignments) {
                if (mapping.Employee__c != null && mapping.Customer__c != null) {
                    String key = mapping.Employee__c + '-' + mapping.Customer__c;
                    
                    // Check against DB duplicates
                    if (existingKeys.contains(key)) {
                        mapping.addError('Duplicate record found: This Employee-Customer mapping already exists.');
                    }
                    
                    // Check for duplicates in the current update list
                    if (seenKeys.contains(key)) {
                        mapping.addError('Duplicate record in the update list: This Employee-Customer mapping is repeated.');
                    } else {  seenKeys.add(key);  }
                    
                    // Validate reporting manager mapping
                    if (executiveToReportingManager.containsKey(mapping.Employee__c)) {
                        String reportingManagerId = executiveToReportingManager.get(mapping.Employee__c);
                        Boolean found = reportingManagersPrimaryMappings.containsKey(reportingManagerId) &&
                            reportingManagersPrimaryMappings.get(reportingManagerId).contains(mapping.Customer__c);
                        
                        if (!found) {
                            String errorMsg = 'This executive\'s reporting manager is not assigned with this primary customer ' +
                                '(Executive Employee Code: ' + mapping.Employee_Code__c +
                                ', Reporting Manager Code: ' + mapping.Reporting_Manager_Employee_Code__c;
                            if (mapping.Primary_Customer_SAP_Code__c != null) { errorMsg += ', Customer SAP Code: ' + mapping.Primary_Customer_SAP_Code__c; }
                            errorMsg += ').';
                            mapping.addError(errorMsg);
                            continue;
                        }
                    }
                }
            }
        }
    }
    
    //After Update Auto mapping of Secondary customer and sharing of Primary customers
    public static void afterUpdate(List<Employee_Customer_Assignment__c> newPrimaryAssignments, Map<Id, Employee_Customer_Assignment__c> oldPrimaryAssignmentsMap) {
        if (bypassForEmployeeTransfer) return;
        List<AccountShare> sharesToInsert = new List<AccountShare>();
        Set<Id> accountIdsToRemove = new Set<Id>();
        Set<Id> userIdsToRemove = new Set<Id>();
        Set<String> pairsToRemove = new Set<String>();
        
        Set<Id> primaryCustomerIds = new Set<Id>();
        Map<Id, Id> primaryCustomerToExecutiveMap = new Map<Id, Id>();
        Map<Id, Id> primaryCustomerToEmployeeMap = new Map<Id, Id>();
        
        for (Employee_Customer_Assignment__c newRec : newPrimaryAssignments) {
            Employee_Customer_Assignment__c oldRec = oldPrimaryAssignmentsMap.get(newRec.Id);

            if ((newRec.Customer__c != oldRec.Customer__c) || (newRec.Executive__c != oldRec.Executive__c)) {
                //  System.debug('Old Customer: ' + oldRec.Customer__c + ', New Customer: ' + newRec.Customer__c);
                // Remove old share (old customer + same executive)
                if (oldRec.Customer__c != null && oldRec.Executive__c != null) {
                    accountIdsToRemove.add(oldRec.Customer__c);
                    userIdsToRemove.add(oldRec.Executive__c);
                    pairsToRemove.add(oldRec.Customer__c + '_' + oldRec.Executive__c);
                }
                
                // Add new share (new customer + same executive)
                if (newRec.Customer__c != null) {
                     primaryCustomerIds.add(newRec.Customer__c);
                    if (newRec.Executive__c != null) {
                        sharesToInsert.add(CustomSharingService.buildAccountShare(newRec.Customer__c, newRec.Executive__c));
                        
                        if(oldRec.Executive__c != null)
                        {
                            primaryCustomerToExecutiveMap.put(newRec.Customer__c, newRec.Executive__c);
                        }
                        
                    } else if (newRec.Employee__c != null) {
                        primaryCustomerToEmployeeMap.put(newRec.Customer__c, newRec.Employee__c);
                    }
                }
            }
        }
        
        List<Product_Mapping__c> secondaryMappings = [
            SELECT Id, Customer__c, Primary_Customer__c, Sub_Stockiest__c, Secondary_Customer_Type__c
            FROM Product_Mapping__c
            WHERE Primary_Customer__c IN :primaryCustomerIds and  is_Executive_Active__c = true
        ];
        
        Set<String> uniqueCombinationKeys = new Set<String>();
        List<Product_Mapping__c> subStockistMappings = new List<Product_Mapping__c>();
        List<Product_Mapping__c> secondaryCustomerMappings = new List<Product_Mapping__c>();
        if (!secondaryMappings.isEmpty()) {
            for (Product_Mapping__c secPm : secondaryMappings) {
                string primaryId = secPm.Primary_Customer__c;
                
                string assignedExecutiveId = primaryCustomerToExecutiveMap.get(primaryId);
                string assignedEmployeeId = primaryCustomerToEmployeeMap.get(primaryId);
                
                if (assignedExecutiveId == null && assignedEmployeeId == null) continue;
                
                string secondaryId = secPm.Customer__c;
                string subStockistId = secPm.Sub_Stockiest__c;
                
                String key = primaryId + '-' + (assignedExecutiveId != null ? assignedExecutiveId : assignedEmployeeId)
                    + '-' + secondaryId + '-' + (subStockistId != null ? subStockistId : '');
                
                if (!uniqueCombinationKeys.contains(key)) {
                    uniqueCombinationKeys.add(key);
                    
                    Product_Mapping__c newMap = new Product_Mapping__c();
                    newMap.Customer__c = secondaryId;
                    newMap.Primary_Customer__c = primaryId;
                    newMap.Sub_Stockiest__c = subStockistId;
                    
                    // Fill either Executive or Employee based on which is available
                    if (assignedExecutiveId != null) {
                        newMap.Exectuive__c = assignedExecutiveId;
                    } else {
                        newMap.Employee__c = assignedEmployeeId;
                    }
                    
                    if (secPm.Secondary_Customer_Type__c == 'Sub Stockiest') {
                        subStockistMappings.add(newMap);
                    } else {
                        secondaryCustomerMappings.add(newMap);
                    }
                }
            }
        }
        
        if (!accountIdsToRemove.isEmpty() && !userIdsToRemove.isEmpty()) {
            CustomSharingService.removeAccountWithPairShares(accountIdsToRemove, userIdsToRemove, pairsToRemove);
        }
        
        if (!sharesToInsert.isEmpty()) {
            CustomSharingService.shareAccounts(sharesToInsert);
        }
        
        //Auto Mappnings of Secondary Customers
        if(Label.AutoShareSecondaryCustomersBasedOnPrimaryCustomer == 'TRUE')
        {
            if (!subStockistMappings.isEmpty()) {
                database.insert(subStockistMappings,false);
            }
            if (!secondaryCustomerMappings.isEmpty()) {
                database.insert(secondaryCustomerMappings,false);
            }
        }
    }
    
    //After delete we are removing the account sharing
    public static void afterDelete(List<Employee_Customer_Assignment__c> deletedPrimaryAssignments) {
        Set<Id> accountIdsToRemove = new Set<Id>();
        Set<Id> userIdsToRemove = new Set<Id>();
        Set<String> pairsToRemove = new Set<String>();
        
        for (Employee_Customer_Assignment__c mapping : deletedPrimaryAssignments) {
            if (mapping.Customer__c != null && mapping.Executive__c != null) {
                String key = mapping.Customer__c + '-' + mapping.Executive__c;
                accountIdsToRemove.add(mapping.Customer__c);
                userIdsToRemove.add(mapping.Executive__c);
                pairsToRemove.add(key);
            }
        }
        // Exclude the deleted records from the check by filtering with Id NOT IN
        Set<Id> deletedMappingIds = new Map<Id, Employee_Customer_Assignment__c>(deletedPrimaryAssignments).keySet();
        
        list<Employee_Customer_Assignment__c> existingMappings = [select Id,Customer__c,Executive__c,Customer_Executive_Pair__c from Employee_Customer_Assignment__c
                                                                  WHERE Id NOT IN :deletedMappingIds AND Customer_Executive_Pair__c IN :pairsToRemove];
            
            
        // Find pairs that are now completely deleted
        Set<String> stillMappedPairs = new Set<String>();
        for (Employee_Customer_Assignment__c epm : existingMappings) {
            stillMappedPairs.add(epm.Customer_Executive_Pair__c);
        }
        
        // Only remove access if no other mappings exist for that pair
        Set<String> accountToUsersToRemove = new Set<String>();
        for (String key : pairsToRemove) {
            if (!stillMappedPairs.contains(key)) {
  				accountToUsersToRemove.add(key);
            }
        }
        
        if (!accountIdsToRemove.isEmpty() && !userIdsToRemove.isEmpty()) {
            CustomSharingService.removeAccountWithPairShares(accountIdsToRemove, userIdsToRemove, accountToUsersToRemove);
        }
    }
}