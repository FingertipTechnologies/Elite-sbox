public class StockAdjustmentTriggerHandler {
    public static void beforeInsert(List<Stock_Adjustment__c> newAdjustments)
    {
        // Only handle records that don't have a Distributor Stock yet (e.g. data loads)
        List<Stock_Adjustment__c> pendingItems = new List<Stock_Adjustment__c>();
        Set<Id> productIds = new Set<Id>();
        for (Stock_Adjustment__c stk : newAdjustments) {
            if (stk.Distributor_Stock__c == null && stk.Distributor__c != null && stk.Product__c != null) {
                pendingItems.add(stk);
                productIds.add(stk.Product__c);
            }
        }
        if (pendingItems.isEmpty()) {
            return;
        }

        Map<Id, String> productNameMap = new Map<Id, String>();
        for (Product__c prod : [SELECT Id, Name FROM Product__c WHERE Id IN :productIds]) {
            productNameMap.put(prod.Id, prod.Name);
        }

        // Key matches Distributor_Stock__c.DistributorWithProduct__c = CASESAFEID(Distributor__c)+'_'+Product__r.Name
        Set<String> keySet = new Set<String>();
        for (Stock_Adjustment__c stk : pendingItems) {
            if (String.isBlank(stk.Product_Name__c)) {
                stk.Product_Name__c = productNameMap.get(stk.Product__c);
            }
            keySet.add(stk.Distributor__c + '_' + productNameMap.get(stk.Product__c));
        }

        // Load existing stocks
        Map<String, Distributor_Stock__c> existingStockMap = new Map<String, Distributor_Stock__c>();
        for (Distributor_Stock__c stock : [
            SELECT Id, Product__c, Distributor__c, DistributorWithProduct__c
            FROM Distributor_Stock__c
            WHERE DistributorWithProduct__c IN :keySet
        ]) {
            existingStockMap.put(stock.DistributorWithProduct__c, stock);
        }

        // Create new stock records if needed
        List<Distributor_Stock__c> newStocks = new List<Distributor_Stock__c>();
        for (Stock_Adjustment__c stk : pendingItems) {
            String key = stk.Distributor__c + '_' + productNameMap.get(stk.Product__c);
            if (!existingStockMap.containsKey(key)) {
                Distributor_Stock__c newStock = new Distributor_Stock__c(
                    Product__c = stk.Product__c,
                    Distributor__c = stk.Distributor__c
                );
                newStocks.add(newStock);
                existingStockMap.put(key, newStock);
            }
        }
        if (!newStocks.isEmpty()) {
            insert newStocks;
        }

        // Assign the Distributor Stock reference on each adjustment
        for (Stock_Adjustment__c stk : pendingItems) {
            String key = stk.Distributor__c + '_' + productNameMap.get(stk.Product__c);
            stk.Distributor_Stock__c = existingStockMap.get(key).Id;
        }
    }
}
