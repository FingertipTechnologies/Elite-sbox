public without sharing class InvoiceItemTriggerHandler {
    
    //This Method is Useful for the data upload
    //when Elite team data uploaded only invoice items were uploaded and invoice header we used
    //to create from the trigger now from azure we are getting invoice header also
    //this method now we are not using
   /* public static void handleBeforeInsert(List<Invoice_Item__c> newInvoiceItems) {
        Set<String> invoiceNumberSet = new Set<String>();
        Set<String> customerCodeSet = new Set<String>();
        Set<String> customerExecuivePair = new Set<String>();
        
        for(Invoice_Item__c item : newInvoiceItems) {
            invoiceNumberSet.add(item.Bill_Number__c); 
            customerCodeSet.add(item.Bill_to_Party__c); 
            if(item.Order__c == null)
            {
                string key = item.Bill_To_Party__c+'_' +item.Plant__c;
                customerExecuivePair.add(key); 
            }
        }
        
        Map<String, Product_Mapping__c> pairWithLowestHierarchy = new Map<String, Product_Mapping__c>();
        
        List<Product_Mapping__c> executiveMappings = [
            SELECT Id, Name, Customer_Delivery_Plant_Pair__c, Hierarchy_Number__c,Exectuive__c FROM Product_Mapping__c
            WHERE Customer_Delivery_Plant_Pair__c IN :customerExecuivePair and 
            Exectuive__c != null AND Customer__c != null and is_Executive_Active__c = true limit 50000
        ];
        
        for (Product_Mapping__c pm : executiveMappings) {
            String key = pm.Customer_Delivery_Plant_Pair__c;
            
            // If key not in map, add it
            if (!pairWithLowestHierarchy.containsKey(key)) {
                pairWithLowestHierarchy.put(key, pm);
            } 
            else {
                // Compare hierarchy numbers, keep the lowest
                Product_Mapping__c existing = pairWithLowestHierarchy.get(key);
                if (pm.Hierarchy_Number__c < existing.Hierarchy_Number__c) {
                    pairWithLowestHierarchy.put(key, pm);
                }
            }
        }

  


        
        // Query existing invoices
        Map<String, Invoice__c> existingInvoicesMap = new Map<String, Invoice__c>();
        for(Invoice__c inv : [SELECT Id, Invoice_No__c, Store__c FROM Invoice__c 
                              WHERE Invoice_No__c IN :invoiceNumberSet]) {
                                  existingInvoicesMap.put(inv.Invoice_No__c, inv);
                              }
        
        // Query accounts
        Map<String, Account> accountBySapCodeMap = new Map<String, Account>();
        for(Account acc : [SELECT Id, SAP_Customer_Code__c FROM Account 
                           WHERE SAP_Customer_Code__c IN :customerCodeSet]) {
                               accountBySapCodeMap.put(acc.SAP_Customer_Code__c, acc);
                           }
        
        // Identify invoices that need to be created
        Map<String, Invoice__c> invoicesToCreateMap = new Map<String, Invoice__c>();
        Map<String, String> invoiceToCustomerMap = new Map<String, String>();
        
        for(Invoice_Item__c item : newInvoiceItems) {
            String invoiceNumber = item.Bill_Number__c;
            if(!existingInvoicesMap.containsKey(invoiceNumber) && 
               !invoicesToCreateMap.containsKey(invoiceNumber)) {
                   
                   Account relatedAccount = accountBySapCodeMap.get(item.Bill_to_Party__c);
                   if(relatedAccount != null) {
                       invoicesToCreateMap.put(invoiceNumber, new Invoice__c(
                           Invoice_No__c = invoiceNumber,
                           Store__c = relatedAccount.Id,
                           Status__c = 'Raised'
                       ));
                   } else {
                       invoiceToCustomerMap.put(invoiceNumber, item.Bill_to_Party__c);
                   }
               }
        }
        
        // Bulk create invoices with error handling
        if(!invoicesToCreateMap.isEmpty()) {
            Database.SaveResult[] results = Database.insert(invoicesToCreateMap.values(), false);
            
            for(Integer i = 0; i < results.size(); i++) {
                if(results[i].isSuccess()) {
                    Invoice__c createdInvoice = invoicesToCreateMap.values()[i];
                    existingInvoicesMap.put(createdInvoice.Invoice_No__c, createdInvoice);
                }
            }
        }
        
        // Process each invoice item
        for(Invoice_Item__c item : newInvoiceItems) {
            String invoiceNumber = item.Bill_Number__c;
            if(item.Is_Order_Owner_Active__c == True && item.Order__c != null && item.Order_Owner_Id__c != null)
            {
               // item.OwnerId = item.Order_Owner_Id__c; 
            }
            else if((item.Order__c == null || item.Order__c == '') && (item.Bill_To_Party__c != null && item.Plant__c != null))
            {
                String key = item.Bill_To_Party__c + '_' + item.Plant__c;
                
                if (pairWithLowestHierarchy.containsKey(key)) {
                    Product_Mapping__c lowestMapping = pairWithLowestHierarchy.get(key);
                   // item.OwnerId = lowestMapping.Exectuive__c; 
                }
            }
            
           
            
            if(existingInvoicesMap.containsKey(invoiceNumber)) {
                item.Invoice__c = existingInvoicesMap.get(invoiceNumber).Id;
            } else if(invoiceToCustomerMap.containsKey(invoiceNumber)) {
                item.addError('No Account found with SAP Customer Code: ' + 
                              invoiceToCustomerMap.get(invoiceNumber) + ' for Invoice Number: ' + invoiceNumber);
            } else {
                item.addError('Could not find or create parent Invoice for Invoice Number: ' + invoiceNumber);
            }
        }
    }
    */
    public static void mapInvoiceItemOwner(List<Invoice_Item__c> newInvoiceItems)
    {
        // Copy header-derived fields first so Bill_to_Party__c is available as the
        // Product_Mapping key below.
        for(Invoice_Item__c item : newInvoiceItems) {
            if(item.Invoice_Customer_Name__c != null) item.Bill_to_party_name__c = item.Invoice_Customer_Name__c;
            if(item.Invoice_SAP_Customer_Code__c != null) item.Bill_to_Party__c = item.Invoice_SAP_Customer_Code__c;
            if(item.Invoice_Ship_to_party_Name__c != null) item.Ship_to_party_name__c = item.Invoice_Ship_to_party_Name__c;
        }

        // Build the customer + plant -> lowest-hierarchy executive map for items
        // that have no SF Order linked.
        Set<String> customerExecuivePair = new Set<String>();
        for(Invoice_Item__c item : newInvoiceItems) {
            if(item.Order__c == null && item.Bill_To_Party__c != null && item.Plant__c != null) {
                customerExecuivePair.add(item.Bill_To_Party__c + '_' + item.Plant__c);
            }
        }

        Map<String, Product_Mapping__c> pairWithLowestHierarchy = new Map<String, Product_Mapping__c>();
        if(!customerExecuivePair.isEmpty()) {
            for (Product_Mapping__c pm : [
                SELECT Id, Customer_Delivery_Plant_Pair__c, Hierarchy_Number__c, Exectuive__c
                FROM Product_Mapping__c
                WHERE Customer_Delivery_Plant_Pair__c IN :customerExecuivePair
                AND Exectuive__c != null AND Customer__c != null AND is_Executive_Active__c = true
                LIMIT 50000
            ]) {
                String key = pm.Customer_Delivery_Plant_Pair__c;
                Product_Mapping__c existing = pairWithLowestHierarchy.get(key);
                if (existing == null || pm.Hierarchy_Number__c < existing.Hierarchy_Number__c) {
                    pairWithLowestHierarchy.put(key, pm);
                }
            }
        }

        for(Invoice_Item__c item : newInvoiceItems) {
            if(item.Order__c != null && item.Is_Order_Owner_Active__c == true && item.Order_Owner_Id__c != null) {
                item.OwnerId = item.Order_Owner_Id__c;
            }
            else if(item.Order__c == null && item.Bill_To_Party__c != null && item.Plant__c != null) {
                Product_Mapping__c lowestMapping = pairWithLowestHierarchy.get(item.Bill_To_Party__c + '_' + item.Plant__c);
                if (lowestMapping != null && String.isNotBlank(lowestMapping.Exectuive__c)) {
                    item.OwnerId = lowestMapping.Exectuive__c;
                }
            }
        }
    }
    // Links each Invoice Item to the Order Item it fulfills, using the same
    // SKU/product-name + Order match as handleAfterInsert. On duplicate matches the
    // first Order Item found wins.
    public static void linkOrderItems(List<Invoice_Item__c> newInvoiceItems) {
        Set<Id> orderIds = new Set<Id>();
        for (Invoice_Item__c item : newInvoiceItems) {
            if (item.Order__c != null && item.SKU_Name__c != null) {
                orderIds.add(item.Order__c);
            }
        }
        if (orderIds.isEmpty()) return;

        Map<String, Id> productOrderToItemId = new Map<String, Id>();
        for (Order_Item__c oi : [
            SELECT Id, Order__c, Product__r.Name
            FROM Order_Item__c
            WHERE Order__c IN :orderIds
        ]) {
            if (oi.Product__r.Name == null) continue;
            String key = oi.Product__r.Name + '_' + oi.Order__c;
            if (!productOrderToItemId.containsKey(key)) {
                productOrderToItemId.put(key, oi.Id);
            }
        }

        for (Invoice_Item__c item : newInvoiceItems) {
            if (item.Order__c != null && item.SKU_Name__c != null) {
                Id matchId = productOrderToItemId.get(item.SKU_Name__c + '_' + item.Order__c);
                if (matchId != null) item.Order_Item__c = matchId;
            }
        }
    }

    public static void handleAfterInsert(List<Invoice_Item__c> newInvoiceItems) {
        // Step 1: Collect Order + Product wise delivered quantities from new Invoice Items
        Map<String, Decimal> orderProductToDeliveredQty = new Map<String, Decimal>();
        Set<Id> orderIds = new Set<Id>();
        Map<String, Date> orderIdWithInvoiceDate = new Map<String, Date>();
        
        for (Invoice_Item__c inv : newInvoiceItems) {
            if(inv.Order__c != null && !orderIdWithInvoiceDate.ContainsKey(inv.Order__c) && inv.Bill_Date__c != null)
            {
                orderIdWithInvoiceDate.put(inv.Order__c,inv.Bill_Date__c);
            }
            if (inv.Order__c != null && inv.SKU_Name__c != null) {
                String key = inv.SKU_Name__c + '_' + inv.Order__c;
                orderProductToDeliveredQty.put(
                    key, 
                    (orderProductToDeliveredQty.containsKey(key) ? orderProductToDeliveredQty.get(key) : 0) 
                    + (inv.Qyt_in_Each__c == null ? 0 : inv.Qyt_in_Each__c)
                );
                orderIds.add(inv.Order__c);
            }
        }
        
        if (orderIds.isEmpty()) return;
        
        // Step 2: Fetch all relevant Order Items
        List<Order_Item__c> orderItems = [
            SELECT Id, Product__c, Product__r.Name, Order__c, Quantity__c, Delivered_Quantity__c, 
            Status__c
            FROM Order_Item__c
            WHERE Order__c IN :orderIds
        ];
        
        // Step 3: Update Delivered_Quantity__c and Status__c on Order Items
        for (Order_Item__c oi : orderItems) {
            String key = oi.Product__r.Name + '_' + oi.Order__c;
            if (orderProductToDeliveredQty.containsKey(key)) {
                Decimal newDelivered = orderProductToDeliveredQty.get(key);
                oi.Delivered_Quantity__c = newDelivered;
                
                if (newDelivered > oi.Quantity__c) {
                    oi.Status__c = 'Over-Fulfilled';
                } else if (newDelivered < oi.Quantity__c) {
                    oi.Status__c = 'Under-Fulfilled';
                } else if (newDelivered == oi.Quantity__c) {
                    oi.Status__c = 'Back-To-Back';
                }
            }
        }
        
        if (!orderItems.isEmpty()) {
            update orderItems;
        }
        
        // Step 4: Aggregate at Order level
        List<AggregateResult> orderAggList = [
            SELECT Order__c orderId, SUM(Delivered_Quantity__c) delivaredqty, SUM(Quantity__c) orderedqty
            FROM Order_Item__c
            WHERE Order__c IN :orderIds
            GROUP BY Order__c
        ];
        
        Map<Id, AggregateResult> orderAggregates = new Map<Id, AggregateResult>();
        for (AggregateResult ar : orderAggList) {
            if (ar.get('orderId') != null) {
                orderAggregates.put((Id)ar.get('orderId'), ar);
            }
        }
        
        // Step 5: Update Orders
        List<Order__c> ordersToUpdate = new List<Order__c>();
        for (Id orderId : orderAggregates.keySet()) {
            AggregateResult agg = orderAggregates.get(orderId);
            Decimal totalDelivered = (Decimal) agg.get('delivaredqty');
            Decimal totalOrderedQty = (Decimal) agg.get('orderedqty');
            
            Order__c ord = new Order__c(Id = orderId);
            ord.DB_Bill_Quantity__c = totalDelivered;
            if(orderIdWithInvoiceDate.ContainsKey(orderId))
            {
                ord.Orderfulfilment_Date__c = orderIdWithInvoiceDate.get(orderId);
            }
           
            if (totalDelivered > totalOrderedQty) {
                ord.Order_Fulfillment_Status__c = 'Over-Fulfilled';
            } else if (totalDelivered < totalOrderedQty) {
                ord.Order_Fulfillment_Status__c = 'Under-Fulfilled';
            } else {
                ord.Order_Fulfillment_Status__c = 'Back-To-Back';
            }
            ordersToUpdate.add(ord);
        }
        
        if (!ordersToUpdate.isEmpty()) {
            update ordersToUpdate;
        }

    }

    
}