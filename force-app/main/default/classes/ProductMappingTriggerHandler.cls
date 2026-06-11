public without sharing class ProductMappingTriggerHandler {

    public static Boolean isProductMappingAutoInsert = false;
    public static Boolean isProductMappingAutoUpdate = false;

    // Set to true by bulk data movement flows (e.g. Employee Transfer) to
    // bypass the heavy before/after update logic. Always reset in finally.
    public static Boolean bypassForEmployeeTransfer = false;
    
    //Checking Primary Customer Access and Accont sharing
    public static void beforeInsert(List<Product_Mapping__c> newProductMappings) {
        // Step 1: Get Dependent Credit Description Map
        Map<String, Map<String, String>> paymentTermCreditDescriptionMap = newCustomerLwcController.getDependentMap(new Product_Mapping__c(), 'Payment_Term__c', 'Credit_Description__c');
        
        Set<Id> userIds = new Set<Id>();
        Set<Id> exeIds = new Set<Id>();
        Set<Id> primaryCustomerIds = new Set<Id>();
        Set<Id> subStockiestCustomerIds = new Set<Id>();
        Set<Id> primaryCustomerIdForDuplication = new Set<Id>();
        
        Set<Id> exeIdstoRunValidation = new Set<Id>();

        List<AccountShare> sharesToInsert = new List<AccountShare>();
        
        // Step 2: Collect all Executive and Employee IDs
        for (Product_Mapping__c pm : newProductMappings) {
            if (pm.Exectuive__c != null) exeIds.add(pm.Exectuive__c);
            if (pm.Customer__c != null && pm.Customer_Type__c == 'Primary Customer') primaryCustomerIdForDuplication.add(pm.Customer__c);
            if (pm.Primary_Customer__c != null) primaryCustomerIds.add(pm.Primary_Customer__c);
            if (pm.Sub_Stockiest__c != null) subStockiestCustomerIds.add(pm.Sub_Stockiest__c);
            
            //If all the mappings from the replacements we will skip validations due to the large data
            if(pm.Cloned_From_Employee_Replacement__c == false && pm.Cloning_From_Customer_Deactivation__c == false && pm.Auto_Mapping_from_Primary_Assignment__c == false
              && pm.Exectuive__c != null)
            {
                exeIdstoRunValidation.add(pm.Exectuive__c);
            }
        }
        
        //Step 2.1: Existing Mappings of users
        Map<String, Product_Mapping__c> existingMap = new Map<String, Product_Mapping__c>();
        if (!exeIds.isEmpty() && !primaryCustomerIdForDuplication.isEmpty()) {
            List<Product_Mapping__c> primaryMappings = [ SELECT Id, Customer__c, Exectuive__c, Employee__c,Area__c,
                                                        PDP_Day__c,Chanel__c,Parent_Depot__c,Child_Depot__c,Inco_Terms__c,
                                                        Sales_Office__c,Order_Type__c,Distribution_Channel__c,Division__c,
                                                        Payment_Term__c
                                                        FROM Product_Mapping__c WHERE Customer_Type__c = 'Primary Customer' 
                                                        AND (Exectuive__c IN :exeIds) AND Customer__c IN: primaryCustomerIdForDuplication
                                                        limit 50000
                                                       ];
            for (Product_Mapping__c pm : primaryMappings) {
                String key =pm.Exectuive__c + '_' +pm.Customer__c+'_'+pm.Area__c+
                    pm.PDP_Day__c + '_' +pm.Chanel__c+'_'+pm.Parent_Depot__c+'_'+pm.Child_Depot__c+
                    pm.Inco_Terms__c + '_' +pm.Sales_Office__c+'_'+pm.Order_Type__c+'_'+pm.Distribution_Channel__c+
                    pm.Division__c + '_' +pm.Payment_Term__c;
                existingMap.put(key, pm);
            }
            
        }
        
        // Step 3: Map UserId → EmployeeId (for Exectuive__c fallback)
        Map<Id, Id> employeetoUserMap = new Map<Id, Id>();
        Set<Id> activeUserIds = new Set<Id>();
        if (!exeIds.isEmpty()) {
            List<Employee__c> employeeList = [SELECT Id, User__c FROM Employee__c WHERE User__c IN :exeIds];
            for (Employee__c emp : employeeList) {
                if (emp.User__c != null) { employeetoUserMap.put(emp.User__c, emp.Id); }
            }
            for (User u : [SELECT Id FROM User WHERE Id IN :exeIds AND IsActive = true]) {
                activeUserIds.add(u.Id);
            }
        }
        
        //Varibles
        Map<Id, Set<Id>> userWithSubordinates = new Map<Id, Set<Id>>();
        Set<Id> allRelatedUserIds = new Set<Id>();
        Map<Id, Set<Id>> userToPrimaryCustomers = new Map<Id, Set<Id>>();
        Map<Id, Set<Id>> userToSubStockistCustomers = new Map<Id, Set<Id>>();
        
        //Skiping the query to skip the validations for the cloning
        if(!exeIdstoRunValidation.isEmpty())
        {
            system.debug('exeIdstoRunValidation');
            //Step 3.1 : manegers with subordinates
            userWithSubordinates = RoleHeirarchyUtility.getManagerWithSubordinates(exeIds);
            for (Id managerId : userWithSubordinates.keySet()) {
                allRelatedUserIds.add(managerId); // include manager themselves
                allRelatedUserIds.addAll(userWithSubordinates.get(managerId)); // include their subordinates
            }
            
            // Step 4: Fetch Primary Customer Mappings (using both Exectuive__c and Employee__c)
            List<Product_Mapping__c> primaryMappings = [ SELECT Id, Customer__c, Exectuive__c, Employee__c
                                                        FROM Product_Mapping__c WHERE Customer_Type__c = 'Primary Customer' 
                                                        AND (Exectuive__c IN :allRelatedUserIds) AND Customer__c IN: primaryCustomerIds
                                                        limit 50000
                                                       ];
            for (Product_Mapping__c pm : primaryMappings) {
                if (!userToPrimaryCustomers.containsKey(pm.Exectuive__c)) { userToPrimaryCustomers.put(pm.Exectuive__c, new Set<Id>()); }
                userToPrimaryCustomers.get(pm.Exectuive__c).add(pm.Customer__c);
            }
            
            list<Employee_Customer_Assignment__c> primayCustomerDsmAssignments = [
                Select Id,Name,Executive__c,Employee__c,Customer__c from Employee_Customer_Assignment__c
                where (Executive__c IN :allRelatedUserIds) AND Customer__c IN:primaryCustomerIds limit 50000
            ];
            for (Employee_Customer_Assignment__c epm : primayCustomerDsmAssignments) {
                if (!userToPrimaryCustomers.containsKey(epm.Executive__c)) { userToPrimaryCustomers.put(epm.Executive__c, new Set<Id>()); }
                userToPrimaryCustomers.get(epm.Executive__c).add(epm.Customer__c);
            }
            
            // Step 4.1: Fetch Sub Stockiest mappings similarly
            List<Product_Mapping__c> subStockiestMappings = [
                SELECT Id, Customer__c, Exectuive__c, Employee__c FROM Product_Mapping__c
                WHERE Secondary_Customer_Type__c = 'Sub Stockiest' AND (Exectuive__c IN :allRelatedUserIds) AND Customer__c IN:subStockiestCustomerIds  limit 50000
            ];
            for (Product_Mapping__c pm : subStockiestMappings) {
                if (!userToSubStockistCustomers.containsKey(pm.Exectuive__c)) { userToSubStockistCustomers.put(pm.Exectuive__c, new Set<Id>()); }
                userToSubStockistCustomers.get(pm.Exectuive__c).add(pm.Customer__c);
            }
        }
        
        // Step 5: Process new mappings
        for (Product_Mapping__c pm : newProductMappings) {
            // Map Employee from Executive if missing
            if (pm.Employee__c == null && pm.Exectuive__c != null && employeetoUserMap.containsKey(pm.Exectuive__c)) {
                pm.Employee__c = employeetoUserMap.get(pm.Exectuive__c);
            }
            // Credit Description
            if (paymentTermCreditDescriptionMap.containsKey(pm.Payment_Term__c)) {
                Map<String, String> innerMap = paymentTermCreditDescriptionMap.get(pm.Payment_Term__c);
                if (innerMap != null && !innerMap.keySet().isEmpty()) {
                    pm.Credit_Description__c = innerMap.keySet().iterator().next();
                }
            }
            
            
            if(pm.Exectuive__c != null)
            {     
                //Skiping the validations while customer replacement and employee replacement
                if(Label.ValidateMapping == 'TRUE' )
                {
                    // Validate Secondary Customer logic
                    if (pm.Customer_Type__c == 'Secondary Customer' &&
                        pm.Cloned_From_Employee_Replacement__c == false && pm.Cloning_From_Customer_Deactivation__c == false &&
                        pm.Auto_Mapping_from_Primary_Assignment__c == false) {
                            if (pm.Sub_Stockiest__c == null) {
                                if (pm.Primary_Customer__c != null) {
                                    Set<Id> primaryCustomers = userToPrimaryCustomers.get(pm.Exectuive__c);
                                    
                                    if (primaryCustomers == null || !primaryCustomers.contains(pm.Primary_Customer__c)) {
                                        
                                        Boolean found = false;
                                        if(userWithSubordinates.containsKey(pm.Exectuive__c))
                                        {
                                            Set<Id> subordinateUserIds = userWithSubordinates.get(pm.Exectuive__c);
                                            //System.debug('Subordinates11: ' + JSON.serialize(subordinateUserIds));
                                            for (Id subUserId : subordinateUserIds) {
                                                if (userToPrimaryCustomers.containsKey(subUserId) && userToPrimaryCustomers.get(subUserId).contains(pm.Primary_Customer__c)) {
                                                    found = true;
                                                    break;
                                                }
                                            }
                                        }
                                        if (!found) {
                                            pm.addError('Primary Customer is not yet mapped to this Executive or their subordinates (Executive Code: ' + pm.Executive_Employee_Code__c + ', Primary Customer Code: ' + pm.Primary_Customer_Code__c + '). Cannot proceed with Secondary Customer mapping.');
                                            continue;
                                        }
                                        
                                    }
                                } 
                            } 
                            else {
                                Set<Id> subStockiestCustomers = userToSubStockistCustomers.get(pm.Exectuive__c);
                                if (subStockiestCustomers == null || !subStockiestCustomers.contains(pm.Sub_Stockiest__c)) {
                                    Set<Id> subordinateUserIds = userWithSubordinates.get(pm.Exectuive__c);
                                    Boolean found = false;
                                    if(userWithSubordinates.containsKey(pm.Exectuive__c))
                                    {
                                        for (Id subUserId : subordinateUserIds) {
                                            if (userToSubStockistCustomers.containsKey(subUserId) && userToSubStockistCustomers.get(subUserId).contains(pm.Sub_Stockiest__c)) {
                                                found = true;
                                                break;
                                            }
                                        }
                                    }
                                    
                                    if (!found) {
                                        pm.addError('Sub Stockiest is not yet mapped to this Executive (Executive Code: ' + pm.Executive_Employee_Code__c + ', Sub Stockiest Code: ' + pm.Sub_Stockiest_Code__c + '). Cannot proceed with Secondary Customer mapping.');
                                        continue;
                                    }
                                }
                            }
                        }
                    else if(pm.Customer_Type__c == 'Primary Customer')
                    {
                        
                        String key = pm.Exectuive__c + '_' +pm.Customer__c+'_'+pm.Area__c+
                            pm.PDP_Day__c + '_' +pm.Chanel__c+'_'+pm.Parent_Depot__c+'_'+pm.Child_Depot__c+
                            pm.Inco_Terms__c + '_' +pm.Sales_Office__c+'_'+pm.Order_Type__c+'_'+pm.Distribution_Channel__c+
                            pm.Division__c + '_' +pm.Payment_Term__c;
                        if(existingMap.containsKey(key))
                        {
                            pm.addError('Duplicate mapping already exists in the system for this Employee and Customer.');
                        }
                        else
                        {
                            existingMap.put(key, pm);
                        }
                        
                    }
                }
                // All validations passed. Now we applying sharing and assignments
                if (pm.Customer__c != null) {
                    pm.OwnerId = pm.Exectuive__c;
                    if (activeUserIds.contains(pm.Exectuive__c)) {
                        sharesToInsert.add(CustomSharingService.buildAccountShare(pm.Customer__c, pm.Exectuive__c));
                    }
                }
            }
            
            // Copy IDs
            if (pm.Customer__c != null) pm.Customer_Id__c = pm.Customer__c;
            if (pm.Primary_Customer__c != null) pm.Primary_Customer_Id__c = pm.Primary_Customer__c;
            if (pm.Area__c != null) pm.Territory_Id__c = pm.Area__c;
            if (pm.Sub_Stockiest__c != null) pm.Sub_Stockiest_Id__c = pm.Sub_Stockiest__c;
        }
        
        // Step 6: Share Accounts
        if (!sharesToInsert.isEmpty()) {
            CustomSharingService.shareAccounts(sharesToInsert);
        }
    }
    
    //Based on primary customer auto sharing the Accounts Based on the primary Customer assignment
    public static void afterInsert(List<Product_Mapping__c> newProductMappings) {
        Set<Id> primaryCustomerIds = new Set<Id>();
        Set<Id> primaryCustomerIdstoUpdateSalesChannel = new Set<Id>();
        Map<Id, Id> customerToExecutiveMap = new Map<Id, Id>();
        Map<Id, Id> customerToEmployeeMap = new Map<Id, Id>();
        Set<Id> subStockiestIds = new Set<Id>();
        Map<Id, Set<Id>> primaryToSecondaryForSalesChannel = new Map<Id, Set<Id>>();

        for (Product_Mapping__c pm : newProductMappings) {
            if(pm.Customer_Type__c == 'Primary Customer' )
            {
                primaryCustomerIdstoUpdateSalesChannel.add(pm.Customer__c);
            }
            if(pm.Customer_Type__c == 'Secondary Customer' && pm.Primary_Customer__c != null && pm.Customer__c != null) {
                if (!primaryToSecondaryForSalesChannel.containsKey(pm.Primary_Customer__c)) {
                    primaryToSecondaryForSalesChannel.put(pm.Primary_Customer__c, new Set<Id>());
                }
                primaryToSecondaryForSalesChannel.get(pm.Primary_Customer__c).add(pm.Customer__c);
            }
            //if the mapping is created by cloning we no need to assign the secondary customer under primary customer
            if (pm.Customer__c != null  && pm.Cloned_From_Employee_Replacement__c == false && pm.Cloning_From_Customer_Deactivation__c == false &&
               pm.Auto_Mapping_from_Primary_Assignment__c == false) {
               
                if(pm.Customer_Type__c == 'Primary Customer' )
                {
                    primaryCustomerIds.add(pm.Customer__c);
                }
                else if(pm.Secondary_Customer_Type__c == 'Sub Stockiest')
                {
                     subStockiestIds.add(pm.Customer__c);
                }
             
                if (pm.Exectuive__c != null) {
                    customerToExecutiveMap.put(pm.Customer__c, pm.Exectuive__c);
                }else if (pm.Employee__c != null) {
                    customerToEmployeeMap.put(pm.Customer__c, pm.Employee__c);
                }
            }
        }
        
        
        if(!primaryCustomerIdstoUpdateSalesChannel.isEmpty())
        {
            //Updating the Sales channel and Delivary plant on Account
            //for the sharing the accounts to Order adminstator and Logistic Team
            System.enqueueJob(new UpdateSalesChannelAndDepotQueueable(primaryCustomerIdstoUpdateSalesChannel));
        }

        if(!primaryToSecondaryForSalesChannel.isEmpty())
        {
            System.enqueueJob(new UpdateSecondarySalesChannelQueueable(primaryToSecondaryForSalesChannel));
        }

        //Auto Mappnings of Secondary Customers.
        //Offloaded to an async Queueable so the heavy query/loop/insert (and the recursive
        //beforeInsert it fires) runs in a separate transaction with its own CPU budget.
        if(Label.AutoShareSecondaryCustomersBasedOnPrimaryCustomer == 'TRUE'
           && (!primaryCustomerIds.isEmpty() || !subStockiestIds.isEmpty()))
        {
            System.enqueueJob(new AutoMapSecondaryCustomersQueueable(
                primaryCustomerIds, subStockiestIds, customerToExecutiveMap, customerToEmployeeMap));
        }
    }

    //Async worker for afterInsert: builds and inserts the auto-mapped secondary customer
    //mappings under the new executive/employee. Runs in its own transaction so the heavy
    //query/loop/insert does not consume the original trigger transaction's CPU budget.
    public static void autoMapSecondaryCustomers(
        Set<Id> primaryCustomerIds,
        Set<Id> subStockiestIds,
        Map<Id, Id> customerToExecutiveMap,
        Map<Id, Id> customerToEmployeeMap)
    {
        List<Product_Mapping__c> secondaryMappings = new List<Product_Mapping__c>();

        //Per primary customer: collect executives from its 3 most-recent primary mappings,
        //then fetch only the secondaries under those executives (instead of all executives)
        //to keep the row count - and the per-row work below - small.
        Set<Id> recentExecutiveIds = new Set<Id>();
        if (!primaryCustomerIds.isEmpty()) {
            Map<Id, Integer> seenPerPrimary = new Map<Id, Integer>();
            for (Product_Mapping__c pm : [
                    SELECT Customer__c, Exectuive__c
                    FROM Product_Mapping__c
                    WHERE Customer__c IN :primaryCustomerIds
                      AND Customer_Type__c = 'Primary Customer'
                      AND Exectuive__c != null
                    ORDER BY CreatedDate DESC ]) {
                Integer c = seenPerPrimary.containsKey(pm.Customer__c) ? seenPerPrimary.get(pm.Customer__c) : 0;
                if (c >= 3) continue;   // only the 3 most-recent primary mappings per primary
                seenPerPrimary.put(pm.Customer__c, c + 1);
                recentExecutiveIds.add(pm.Exectuive__c);
            }
        }

        if (!recentExecutiveIds.isEmpty()) {
            //Secondary Customers related to primary customer, narrowed to recent-3 executives
            secondaryMappings.addAll([
                SELECT Id, Customer__c, Primary_Customer__c, Sub_Stockiest__c, Secondary_Customer_Type__c
                FROM Product_Mapping__c
                WHERE Primary_Customer__c IN :primaryCustomerIds
                  AND Exectuive__c IN :recentExecutiveIds
                  AND is_Executive_Active__c = true
            ]);
        }
        if (!subStockiestIds.isEmpty()) {
            //Secondary Customers related to sub stockiest
            secondaryMappings.addAll([
                SELECT Id, Customer__c, Primary_Customer__c, Sub_Stockiest__c, Secondary_Customer_Type__c
                FROM Product_Mapping__c
                WHERE Sub_Stockiest__c IN :subStockiestIds and is_Executive_Active__c = true
            ]);
        }

        if (secondaryMappings.isEmpty()) return;

        Set<String> uniqueCombinationKeys = new Set<String>();
        List<Product_Mapping__c> subStockistMappings = new List<Product_Mapping__c>();
        List<Product_Mapping__c> secondaryCustomerMappings = new List<Product_Mapping__c>();

        for (Product_Mapping__c secPm : secondaryMappings) {
            String primaryId = secPm.Primary_Customer__c;
            String secondaryId = secPm.Customer__c;
            String subStockistId = secPm.Sub_Stockiest__c;

            String assignedExecutiveId;
            String assignedEmployeeId;

            if (subStockistId != null) {
                assignedExecutiveId = customerToExecutiveMap.get(subStockistId);
                assignedEmployeeId = customerToEmployeeMap.get(subStockistId);
            }

            if ((assignedExecutiveId == null && assignedEmployeeId == null) && primaryId != null) {
                assignedExecutiveId = customerToExecutiveMap.get(primaryId);
                assignedEmployeeId = customerToEmployeeMap.get(primaryId);
            }

            if (assignedExecutiveId == null && assignedEmployeeId == null) continue;

            String key = primaryId + '-' + (assignedExecutiveId != null ? assignedExecutiveId : assignedEmployeeId)
                + '-' + secondaryId + '-' + (subStockistId != null ? subStockistId : '');

            if (!uniqueCombinationKeys.contains(key)) {
                uniqueCombinationKeys.add(key);

                Product_Mapping__c newMap = new Product_Mapping__c();
                newMap.Customer__c = secondaryId;
                newMap.Primary_Customer__c = primaryId;
                newMap.Sub_Stockiest__c = subStockistId;
                newMap.Auto_Mapping_from_Primary_Assignment__c = true;
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

        // Statics reset per (async) transaction; set this BEFORE DML so the auto-created
        // records do NOT re-run afterInsert - preserves the original synchronous behavior
        // and prevents the async job from cascading.
        isProductMappingAutoInsert = true;
        if (!subStockistMappings.isEmpty()) {
            database.insert(subStockistMappings, false);
        }
        if (!secondaryCustomerMappings.isEmpty()) {
            database.insert(secondaryCustomerMappings, false);
        }
    }

    //Checking Primary Customer Access
    public static void beforeUpdate(List<Product_Mapping__c> newProductMappings, Map<Id, Product_Mapping__c> oldProductMappings) {
        if (bypassForEmployeeTransfer) return;
        Map<String, Map<String, String>> paymentTermCreditDescriptionMap = newCustomerLwcController.getDependentMap(new Product_Mapping__c(), 'Payment_Term__c', 'Credit_Description__c');
        set<Id> userIds = new set<Id>();
        Set<Id> exeIds = new Set<Id>();
        Set<Id> primaryCustomerIds = new Set<Id>();
        Set<Id> subStockiestCustomerIds = new Set<Id>();
        
        Map<Id, Set<Id>> userToPrimaryCustomers = new Map<Id, Set<Id>>();
        Map<Id, Set<Id>> userToSubStockistCustomers = new Map<Id, Set<Id>>();
        
        for (Product_Mapping__c pm : newProductMappings) {
            Product_Mapping__c oldMap = oldProductMappings.get(pm.Id);
            if ( (oldMap.Exectuive__c != pm.Exectuive__c && pm.Exectuive__c != null ) 
               || (oldMap.Primary_Customer__c != pm.Primary_Customer__c && pm.Primary_Customer__c != null) ||
              (oldMap.Sub_Stockiest__c != pm.Sub_Stockiest__c && pm.Sub_Stockiest__c != null))
            {
                if (pm.Exectuive__c != null) {
                    userIds.add(pm.Exectuive__c);
                }
                exeIds.add(pm.Exectuive__c);
                primaryCustomerIds.add(pm.Primary_Customer__c);  
                subStockiestCustomerIds.add(pm.Sub_Stockiest__c);
                
                if(pm.Customer_Type__c == 'Primary Customer' &&  pm.Exectuive__c != null)
                {
                    if (!userToPrimaryCustomers.containsKey(pm.Exectuive__c)) { userToPrimaryCustomers.put(pm.Exectuive__c, new Set<Id>()); }
                    userToPrimaryCustomers.get(pm.Exectuive__c).add(pm.Customer__c);
                }
                if(pm.Secondary_Customer_Type__c == 'Sub Stockiest' &&  pm.Exectuive__c != null )
                {
                    if (!userToSubStockistCustomers.containsKey(pm.Exectuive__c)) { userToSubStockistCustomers.put(pm.Exectuive__c, new Set<Id>()); }
                    userToSubStockistCustomers.get(pm.Exectuive__c).add(pm.Customer__c);
                }
            }
        }
        
        if(!exeIds.isEmpty())
        {
            list<Employee__c> employeeList = [select Id,Name,User__c from Employee__c where User__c IN :userIds ];
            map<Id,Id> employeetoUserMap = new map<Id,Id>();
            for(Employee__c emp: employeeList)
            {
                if(emp.User__c != null)
                {
                    employeetoUserMap.put(emp.User__c,emp.Id);
                }
                
            }
            
            Map<Id, Set<Id>> userWithSubordinates = RoleHeirarchyUtility.getManagerWithSubordinates(exeIds);
            Set<Id> allRelatedUserIds = new Set<Id>();
            for (Id managerId : userWithSubordinates.keySet()) {
                allRelatedUserIds.add(managerId); // include manager themselves
                allRelatedUserIds.addAll(userWithSubordinates.get(managerId)); // include their subordinates
                
            }
            system.debug('allRelatedUserIds---------'+allRelatedUserIds);
            
            // Step 4: Fetch Primary Customer Mappings (using both Exectuive__c and Employee__c)
            List<Product_Mapping__c> primaryMappings = [ SELECT Id, Customer__c, Exectuive__c, Employee__c
                                                        FROM Product_Mapping__c WHERE Customer_Type__c = 'Primary Customer' 
                                                        AND (Exectuive__c IN :allRelatedUserIds) AND Customer__c IN: primaryCustomerIds
                                                        limit 50000
                                                       ];
            for (Product_Mapping__c pm : primaryMappings) {
                if (!userToPrimaryCustomers.containsKey(pm.Exectuive__c)) { userToPrimaryCustomers.put(pm.Exectuive__c, new Set<Id>()); }
                userToPrimaryCustomers.get(pm.Exectuive__c).add(pm.Customer__c);
            }
            
            list<Employee_Customer_Assignment__c> primayCustomerDsmAssignments = [
                Select Id,Name,Executive__c,Employee__c,Customer__c from Employee_Customer_Assignment__c
                where (Executive__c IN :allRelatedUserIds) AND Customer__c IN:primaryCustomerIds limit 50000
            ];
            for (Employee_Customer_Assignment__c epm : primayCustomerDsmAssignments) {
                if (!userToPrimaryCustomers.containsKey(epm.Executive__c)) { userToPrimaryCustomers.put(epm.Executive__c, new Set<Id>()); }
                userToPrimaryCustomers.get(epm.Executive__c).add(epm.Customer__c);
            }
            
            // Step 4.1: Fetch Sub Stockiest mappings similarly
            List<Product_Mapping__c> subStockiestMappings = [
                SELECT Id, Customer__c, Exectuive__c, Employee__c FROM Product_Mapping__c
                WHERE Secondary_Customer_Type__c = 'Sub Stockiest' AND (Exectuive__c IN :allRelatedUserIds) AND Customer__c IN:subStockiestCustomerIds  limit 50000
            ];
            for (Product_Mapping__c pm : subStockiestMappings) {
                if (!userToSubStockistCustomers.containsKey(pm.Exectuive__c)) { userToSubStockistCustomers.put(pm.Exectuive__c, new Set<Id>()); }
                userToSubStockistCustomers.get(pm.Exectuive__c).add(pm.Customer__c);
            }
            
            
            for (Product_Mapping__c newPM : newProductMappings) {
                Product_Mapping__c oldPM = oldProductMappings.get(newPM.Id);
                if (newPM.Payment_Term__c != oldPM.Payment_Term__c) {
                    if (paymentTermCreditDescriptionMap.containsKey(newPM.Payment_Term__c)) {
                        Map<String, String> innerMap = paymentTermCreditDescriptionMap.get(newPM.Payment_Term__c);
                        if (innerMap != null && !innerMap.keySet().isEmpty()) {
                            newPM.Credit_Description__c = innerMap.keySet().iterator().next();
                        }
                    }
                } 
                //For Data Upload if they haven't mapped the Employee we are mapping here
                if ( (newPM.Exectuive__c != oldPM.Exectuive__c) && oldPM.Exectuive__c != null && newPM.Exectuive__c != null 
                    && employeetoUserMap.containsKey(newPM.Exectuive__c)) 
                {
                    newPM.Employee__c = employeetoUserMap.get(newPM.Exectuive__c);
                }
                
                
                if(newPM.Exectuive__c != null)
                {       
                    if(Label.ValidateMapping == 'TRUE')
                    {
                        // Validate Secondary Customer logic
                        if (newPM.Customer_Type__c == 'Secondary Customer') {
                            if (newPM.Sub_Stockiest__c == null) {
                                if (newPM.Primary_Customer__c != null) {
                                    Set<Id> primaryCustomers = userToPrimaryCustomers.get(newPM.Exectuive__c);
                                    
                                    if (primaryCustomers == null || !primaryCustomers.contains(newPM.Primary_Customer__c)) {
                                        
                                        Boolean found = false;
                                        if(userWithSubordinates.containsKey(newPM.Exectuive__c))
                                        {
                                            Set<Id> subordinateUserIds = userWithSubordinates.get(newPM.Exectuive__c);
                                            //System.debug('Subordinates11: ' + JSON.serialize(subordinateUserIds));
                                            for (Id subUserId : subordinateUserIds) {
                                                if (userToPrimaryCustomers.containsKey(subUserId) && userToPrimaryCustomers.get(subUserId).contains(newPM.Primary_Customer__c)) {
                                                    found = true;
                                                    break;
                                                }
                                            }
                                        }
                                        if (!found) {
                                            newPM.addError('Primary Customer is not yet mapped to this Executive or their subordinates (Executive Code: ' + newPM.Executive_Employee_Code__c + ', Primary Customer Code: ' + newPM.Primary_Customer_Code__c + '). Cannot proceed with Secondary Customer mapping.');
                                            continue;
                                        }
                                        
                                    }
                                } 
                            } 
                            else {
                                Set<Id> subStockiestCustomers = userToSubStockistCustomers.get(newPM.Exectuive__c);
                                if (subStockiestCustomers == null || !subStockiestCustomers.contains(newPM.Sub_Stockiest__c)) {
                                    Set<Id> subordinateUserIds = userWithSubordinates.get(newPM.Exectuive__c);
                                    Boolean found = false;
                                    if(userWithSubordinates.containsKey(newPM.Exectuive__c))
                                    {
                                        for (Id subUserId : subordinateUserIds) {
                                            if (userToSubStockistCustomers.containsKey(subUserId) && userToSubStockistCustomers.get(subUserId).contains(newPM.Sub_Stockiest__c)) {
                                                found = true;
                                                break;
                                            }
                                        }
                                    }
                                    
                                    if (!found) {
                                        newPM.addError('Sub Stockiest is not yet mapped to this Executive (Executive Code: ' + newPM.Executive_Employee_Code__c + ', Sub Stockiest Code: ' + newPM.Sub_Stockiest_Code__c + '). Cannot proceed with Secondary Customer mapping.');
                                        continue;
                                    }
                                }
                            }
                        }
                    }
                }
                
                if(newPM.Customer__c != oldPM.Customer__c)
                {
                    newPM.Customer_Id__c = newPM.Customer__c;
                }
                if(newPM.Primary_Customer__c != oldPM.Primary_Customer__c)
                {
                    newPM.Primary_Customer_Id__c = newPM.Primary_Customer__c;
                }
                if(newPM.Area__c != oldPM.Area__c)
                {
                    newPM.Territory_Id__c = newPM.Area__c;
                }
                if(newPM.Sub_Stockiest__c != oldPM.Sub_Stockiest__c)
                {
                    newPM.Sub_Stockiest_Id__c = newPM.Sub_Stockiest__c;
                }
            }
        }
        
    }
    
    //sharing Customer acceess on update and sharing account based on primary custoemr assignment
    public static void afterUpdate(List<Product_Mapping__c> newProductMappings, Map<Id, Product_Mapping__c> oldProductMappings,Map<Id, Product_Mapping__c> newProductMappingsMap ) {
        if (bypassForEmployeeTransfer) return;
        List<AccountShare> sharesToInsert = new List<AccountShare>();
        // For pair-based check
        Set<String> accountUserPairsToCheck = new Set<String>();
        Map<String, Id> accountUserToAccountId = new Map<String, Id>();
        Map<String, Id> accountUserToUserId = new Map<String, Id>();
        
        Set<Id> primaryCustomerIds = new Set<Id>();
        Set<Id> primaryCustomerIdsToUpdateSalesChannel = new Set<Id>();
        Map<Id, Id> customerToExecutiveMap = new Map<Id, Id>();
        Map<Id, Id> customerToEmployeeMap = new Map<Id, Id>();
        Set<Id> subStockiestIds = new Set<Id>();
        Map<Id, Set<Id>> primaryToSecondaryForSalesChannel = new Map<Id, Set<Id>>();

        //Step 1: Getting requied Ids
        for (Product_Mapping__c newPM : newProductMappings) {
            Product_Mapping__c oldPM = oldProductMappings.get(newPM.Id);
            if((newPM.Chanel__c != oldPM.Chanel__c) || (newPM.Child_Depot__c != oldPM.Child_Depot__c)  )
            {
                if(newPM.Customer_Type__c == 'Primary Customer')
                {
                    primaryCustomerIdsToUpdateSalesChannel.add(newPM.Customer__c);
                }
            }
            if(newPM.Customer_Type__c == 'Secondary Customer' && newPM.Primary_Customer__c != null && newPM.Customer__c != null) {
                if(newPM.Primary_Customer__c != oldPM.Primary_Customer__c) {
                    if (!primaryToSecondaryForSalesChannel.containsKey(newPM.Primary_Customer__c)) {
                        primaryToSecondaryForSalesChannel.put(newPM.Primary_Customer__c, new Set<Id>());
                    }
                    primaryToSecondaryForSalesChannel.get(newPM.Primary_Customer__c).add(newPM.Customer__c);
                }
            }
            
            if ((newPM.Exectuive__c != oldPM.Exectuive__c) || (newPM.Customer__c != oldPM.Customer__c)) {
                //Old Employee to Remove access the primary customer or secondary 
                if (oldPM.Customer__c != null && oldPM.Exectuive__c != null) {
                    String key = oldPM.Customer__c + '-' + oldPM.Exectuive__c;
                    accountUserPairsToCheck.add(key);
                    accountUserToAccountId.put(key, oldPM.Customer__c);
                    accountUserToUserId.put(key, oldPM.Exectuive__c);
                }
                
                //New executive to map 
                if (newPM.Customer__c != null) {
                    if(newPM.Customer_Type__c == 'Primary Customer')
                    {
                        primaryCustomerIds.add(newPM.Customer__c);
                    }
                    else if(newPM.Secondary_Customer_Type__c == 'Sub Stockiest')
                    {
                        subStockiestIds.add(newPM.Customer__c);
                    }
                    
                    if (newPM.Exectuive__c != null) {
                        sharesToInsert.add(CustomSharingService.buildAccountShare(newPM.Customer__c, newPM.Exectuive__c));
                        if(oldPM.Exectuive__c != null)
                        {
                            customerToExecutiveMap.put(newPM.Customer__c, newPM.Exectuive__c);
                        }
                    }
                    else if(newPM.Employee__c != null)
                    {
                        customerToEmployeeMap.put(newPM.Customer__c, newPM.Employee__c);
                    }
                }
            }
        }
        
        //Step 2: Getting Id To remove access
        // Check which pairs still have existing mappings
        Set<String> pairsToKeep = new Set<String>();
        if (!accountUserPairsToCheck.isEmpty()) {
            system.debug(accountUserPairsToCheck);
            List<Product_Mapping__c> existingMappings = [ SELECT Customer__c, Exectuive__c FROM Product_Mapping__c WHERE 
                                                         Customer_Executive_Pair__c IN :accountUserPairsToCheck ];
            for (Product_Mapping__c pm : existingMappings) {
                String pair = pm.Customer__c + '-' + pm.Exectuive__c;
                pairsToKeep.add(pair);
            }
        }
        // Only remove shares if no other mapping exists
        Map<Id, List<Id>> accountToUsersToRemove = new Map<Id, List<Id>>();
        for (String pair : accountUserPairsToCheck) {
            if (!pairsToKeep.contains(pair)) {
                Id accId = accountUserToAccountId.get(pair);
                Id usrId = accountUserToUserId.get(pair);
                if (!accountToUsersToRemove.containsKey(accId)) {
                    accountToUsersToRemove.put(accId, new List<Id>());
                }
                accountToUsersToRemove.get(accId).add(usrId);
            }
        } 
        
        //Step 3: Creting the new secondary mapping based on primary and substockiests assigned
        Set<String> uniqueCombinationKeys = new Set<String>();
        List<Product_Mapping__c> subStockistMappings = new List<Product_Mapping__c>();
        List<Product_Mapping__c> secondaryCustomerMappings = new List<Product_Mapping__c>();
        List<Product_Mapping__c> secondaryMappings = new List<Product_Mapping__c>();
        
        if(!primaryCustomerIds.isEmpty())
        {
            //Secondary Customers which realted to primary customer
            list<Product_Mapping__c>  secondaryMappingswithPrimarycustomer = [
                SELECT Id, Customer__c, Primary_Customer__c, Sub_Stockiest__c, Secondary_Customer_Type__c
                FROM Product_Mapping__c
                WHERE Primary_Customer__c IN :primaryCustomerIds
            ];
            secondaryMappings.addAll(secondaryMappingswithPrimarycustomer);
           
        }
        if(!primaryCustomerIdsToUpdateSalesChannel.isEmpty())
        {
            //Updating the Sales channel and Delivary plant on Account
            //for the sharing the accounts to Order adminstator and Logistic Team
            System.enqueueJob(new UpdateSalesChannelAndDepotQueueable(primaryCustomerIdsToUpdateSalesChannel));
        }
        if(!primaryToSecondaryForSalesChannel.isEmpty())
        {
            System.enqueueJob(new UpdateSecondarySalesChannelQueueable(primaryToSecondaryForSalesChannel));
        }
        if(!subStockiestIds.isEmpty())
        {
            //Secondary Customers which realted to primary customer
            list<Product_Mapping__c> secondaryMappingswithSubStokiest = [
                SELECT Id, Customer__c, Primary_Customer__c, Sub_Stockiest__c, Secondary_Customer_Type__c
                FROM Product_Mapping__c
                WHERE Sub_Stockiest__c IN :subStockiestIds
            ];
            secondaryMappings.addAll(secondaryMappingswithSubStokiest);
        }
        
        if(!secondaryMappings.isEmpty())
        {
            for (Product_Mapping__c secPm : secondaryMappings) {
                string primaryId = secPm.Primary_Customer__c;
                
                string assignedExecutiveId = customerToExecutiveMap.get(primaryId);
                string assignedEmployeeId = customerToEmployeeMap.get(primaryId);
                
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

         //Step 4: Removal and sharing of access
        //Removing the Access
        if(!accountToUsersToRemove.isEmpty())
        {
            CustomSharingService.removeAccountSharesWithMap(accountToUsersToRemove);
        }
        //Sharing the access
        if(!sharesToInsert.isEmpty())
        {
            CustomSharingService.shareAccounts(sharesToInsert);
        }
        
        //Auto Mappnings of Secondary Customers
        if(Label.AutoShareSecondaryCustomersBasedOnPrimaryCustomer == 'TRUE')
        {
            //Step 5: Creating New Secondary Mappigs 
            if (!subStockistMappings.isEmpty()) {
                database.insert(subStockistMappings,false);
            }
            if (!secondaryCustomerMappings.isEmpty()) {
                database.insert(secondaryCustomerMappings,false);
            }
        }
    }

    public static void afterDelete(List<Product_Mapping__c> deletedProductMappings) {
        Set<String> accountUserPairsToCheck = new Set<String>();
        Map<String, Id> pairToAccountIdMap = new Map<String, Id>();
        Map<String, Id> pairToUserIdMap = new Map<String, Id>();
        
        Set<Id> primaryCustomerIds = new Set<Id>();
        
        for (Product_Mapping__c pm : deletedProductMappings) {
            if (pm.Customer__c != null && pm.Exectuive__c != null) {
                if(pm.Customer_Type__c == 'Primary Customer')
                {
                    primaryCustomerIds.add(pm.Customer__c);
                }
             
                String key = pm.Customer__c + '-' + pm.Exectuive__c;
                accountUserPairsToCheck.add(key);
                pairToAccountIdMap.put(key, pm.Customer__c);
                pairToUserIdMap.put(key, pm.Exectuive__c);
            }
        }
        
        // Exclude the deleted records from the check by filtering with Id NOT IN
        Set<Id> deletedPMIds = new Map<Id, Product_Mapping__c>(deletedProductMappings).keySet();
        
        List<Product_Mapping__c> existingMappings = [
            SELECT Customer__c, Exectuive__c
            FROM Product_Mapping__c
            WHERE Id NOT IN :deletedPMIds
            AND Customer_Executive_Pair__c IN :accountUserPairsToCheck
        ];
        
        // Find pairs that are now completely deleted
        Set<String> stillMappedPairs = new Set<String>();
        for (Product_Mapping__c pm : existingMappings) {
            stillMappedPairs.add(pm.Customer__c + '-' + pm.Exectuive__c);
        }
        
        // Only remove access if no other mappings exist for that pair
        Map<Id, List<Id>> accountToUsersToRemove = new Map<Id, List<Id>>();
        for (String key : accountUserPairsToCheck) {
            if (!stillMappedPairs.contains(key)) {
                Id accId = pairToAccountIdMap.get(key);
                Id usrId = pairToUserIdMap.get(key);
                if (!accountToUsersToRemove.containsKey(accId)) {
                    accountToUsersToRemove.put(accId, new List<Id>());
                }
                accountToUsersToRemove.get(accId).add(usrId);
            }
        }
        if(!accountToUsersToRemove.isEmpty())
        {
            CustomSharingService.removeAccountSharesWithMap(accountToUsersToRemove);
        }
        
        if(!primaryCustomerIds.isEmpty())
        {
            //Updating the Sales channel and Delivary plant on Account
            //for the sharing the accounts to Order adminstator and Logistic Team
            System.enqueueJob(new UpdateSalesChannelAndDepotQueueable(primaryCustomerIds));
        }
    }


    public static void updateSaleschannelandParentDeport(Set<Id> primaryCustomerIds)
    {
                
        Map<Id, Set<String>> customerToChannels = new Map<Id, Set<String>>();
        Map<Id, Set<String>> customerToPlants = new Map<Id, Set<String>>();
        List<Account> accountsToUpdate = new List<Account>();
        
        //Primary Mapping to Update Salechannel and Delivay Plant
        list<Product_Mapping__c>  primaryMappings = [ SELECT Id, Customer__c, Chanel__c, Child_Depot__c
                                                     FROM Product_Mapping__c WHERE Customer_Type__c = 'Primary Customer'
                                                     AND is_Executive_Active__c = true
                                                     and Customer__c =:primaryCustomerIds AND (Chanel__c != null OR Child_Depot__c != null)];
        
        // Group Chanel and Delivery_Plant per Customer
        for (Product_Mapping__c pm : primaryMappings) {
            Id custId = pm.Customer__c;
            
            if (pm.Chanel__c != null) {
                if (!customerToChannels.containsKey(custId)) {
                    customerToChannels.put(custId, new Set<String>());
                }
                customerToChannels.get(custId).add(pm.Chanel__c);
            }
            
            if (pm.Child_Depot__c != null) {
                if (!customerToPlants.containsKey(custId)) {
                    customerToPlants.put(custId, new Set<String>());
                }
                customerToPlants.get(custId).add(pm.Child_Depot__c);
            }
        }
        
        for (Id custId : primaryCustomerIds) {
            String channels = customerToChannels.containsKey(custId)
                ? String.join(new List<String>(customerToChannels.get(custId)), ',') + ','
                : null;
            
            String plants = customerToPlants.containsKey(custId)
                ? String.join(new List<String>(customerToPlants.get(custId)), ',') + ','
                : null;
            
            Account acc = new Account(Id = custId);
            if (channels != null) acc.Sales_Channel__c = channels;
            if (plants != null) acc.Delivery_Plant__c = plants;
            accountsToUpdate.add(acc);
        }

        if (!accountsToUpdate.isEmpty()) {
            Database.update(accountsToUpdate, false);
        }

        // Cascade Sales_Channel__c to Secondary Customers linked to these Primary Customers
        List<Product_Mapping__c> secondaryMappings = [
            SELECT Id, Customer__c, Primary_Customer__c
            FROM Product_Mapping__c
            WHERE Customer_Type__c = 'Secondary Customer'
            AND Primary_Customer__c IN :primaryCustomerIds
            AND is_Executive_Active__c = true
            AND Customer__c != null
        ];

        Map<Id, Set<Id>> primaryToSecondaryIds = new Map<Id, Set<Id>>();
        for (Product_Mapping__c secPm : secondaryMappings) {
            if (!primaryToSecondaryIds.containsKey(secPm.Primary_Customer__c)) {
                primaryToSecondaryIds.put(secPm.Primary_Customer__c, new Set<Id>());
            }
            primaryToSecondaryIds.get(secPm.Primary_Customer__c).add(secPm.Customer__c);
        }

        if (!primaryToSecondaryIds.isEmpty()) {
            List<Account> secondaryAccountsToUpdate = new List<Account>();
            for (Account primaryAcc : accountsToUpdate) {
                if (primaryToSecondaryIds.containsKey(primaryAcc.Id)) {
                    for (Id secCustId : primaryToSecondaryIds.get(primaryAcc.Id)) {
                        secondaryAccountsToUpdate.add(new Account(
                            Id = secCustId,
                            Sales_Channel__c = primaryAcc.Sales_Channel__c
                        ));
                    }
                }
            }
            if (!secondaryAccountsToUpdate.isEmpty()) {
                Database.update(secondaryAccountsToUpdate, false);
            }
        }
    }

    public static void updateSecondarySalesChannelFromPrimary(Map<Id, Set<Id>> primaryToSecondaryCustomerIds) {
        Map<Id, Account> primaryAccounts = new Map<Id, Account>(
            [SELECT Id, Sales_Channel__c FROM Account WHERE Id IN :primaryToSecondaryCustomerIds.keySet()]
        );

        List<Account> accountsToUpdate = new List<Account>();
        for (Id primaryCustId : primaryToSecondaryCustomerIds.keySet()) {
            Account primaryAcc = primaryAccounts.get(primaryCustId);
            if (primaryAcc != null) {
                for (Id secondaryCustId : primaryToSecondaryCustomerIds.get(primaryCustId)) {
                    accountsToUpdate.add(new Account(
                        Id = secondaryCustId,
                        Sales_Channel__c = primaryAcc.Sales_Channel__c
                    ));
                }
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            Database.update(accountsToUpdate, false);
        }
    }

}