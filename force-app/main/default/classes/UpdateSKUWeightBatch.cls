global class UpdateSKUWeightBatch implements Database.Batchable<SObject> {
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id, SKU_Weight__c, Product__r.Net_Weight__c ' +
            'FROM Order_Item__c ' +
            'WHERE SKU_Weight__c = null ' +
            'AND Product__r.Net_Weight__c != null Limit 500000'
        );
    }
    
    global void execute(Database.BatchableContext bc, List<Order_Item__c> scope) {
        List<Order_Item__c> toUpdate = new List<Order_Item__c>();
        
        for (Order_Item__c item : scope) {
            item.SKU_Weight__c = item.Product__r.Net_Weight__c;
            toUpdate.add(item);
        }
        
        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, false); // false = partial success, logs failures
        }
    }
    
    global void finish(Database.BatchableContext bc) {
        System.debug('UpdateSKUWeightBatch completed.');
    }
}