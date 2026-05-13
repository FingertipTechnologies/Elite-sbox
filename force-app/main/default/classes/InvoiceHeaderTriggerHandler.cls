public class InvoiceHeaderTriggerHandler {
    public static void beforeInsert(List<Invoice__c> newInvoicesList) {
        
        Set<String> invoiceNumberSet = new Set<String>();
        Set<String> customerCodeSet = new Set<String>();
        Set<String> customerExecuivePair = new Set<String>();
        
        for(Invoice__c item : newInvoicesList) {
            invoiceNumberSet.add(item.Invoice_No__c); 
            customerCodeSet.add(item.Customer_SAP_Code__c); 
            if(item.SF_Order__c == null)
            {
                string key = item.Customer_SAP_Code__c+'_' +item.Delivery_Plant__c;
                customerExecuivePair.add(key); 
            }
        }
        
        Map<String, Product_Mapping__c> pairWithLowestHierarchy = new Map<String, Product_Mapping__c>();
        
        List<Product_Mapping__c> executiveMappings = [
            SELECT Id, Name, Customer_Delivery_Plant_Pair__c, Hierarchy_Number__c,Exectuive__c FROM Product_Mapping__c
            WHERE Customer_Delivery_Plant_Pair__c IN :customerExecuivePair and Exectuive__c != null AND Customer__c != null and is_Executive_Active__c = true limit 50000
        ];
        
        for (Product_Mapping__c pm : executiveMappings) {
            String key = pm.Customer_Delivery_Plant_Pair__c;
            // If key not in map, add it
            if (!pairWithLowestHierarchy.containsKey(key)) { pairWithLowestHierarchy.put(key, pm);} 
            else {
                // Compare hierarchy numbers, keep the lowest
                Product_Mapping__c existing = pairWithLowestHierarchy.get(key);
                if (pm.Hierarchy_Number__c < existing.Hierarchy_Number__c) {pairWithLowestHierarchy.put(key, pm); }
            }
        }
        
        // Example usage: assign owner or other logic
        for (Invoice__c inv : newInvoicesList) {
            String invoiceNumber = inv.Invoice_No__c;
                        system.debug('inv.Order_OwnerId__c '+inv.Order_OwnerId__c );
            system.debug('inv.SF_Order__c '+inv.SF_Order__c );
            system.debug('inv.Customer_SAP_Code__c '+inv.Customer_SAP_Code__c );
             system.debug('inv.Delivery_Plant__c '+inv.Delivery_Plant__c );
            if(inv.Is_Order_Owner_Active__c == True && inv.SF_Order__c != null && inv.Order_OwnerId__c != null){inv.OwnerId = inv.Order_OwnerId__c; }
            
            else if (String.isBlank(inv.SF_Order__c)  && String.isNotBlank(inv.Customer_SAP_Code__c) && String.isNotBlank(inv.Delivery_Plant__c))
            {
                system.debug('key p>>'+inv.Customer_SAP_Code__c + '_' + inv.Delivery_Plant__c);
                
                String key = inv.Customer_SAP_Code__c + '_' + inv.Delivery_Plant__c;
                if (pairWithLowestHierarchy.containsKey(key)) {
                    system.debug('key p>>'+pairWithLowestHierarchy.get(key));
                    Product_Mapping__c lowestMapping = pairWithLowestHierarchy.get(key);
                    if (String.isNotBlank(lowestMapping.Exectuive__c)) {
                        inv.OwnerId = lowestMapping.Exectuive__c; 
                    }
                }
            } 
        }
    }
}