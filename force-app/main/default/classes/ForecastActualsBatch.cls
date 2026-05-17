/**
 * Daily batch that recomputes Actual_Quantity_KG__c on every approved
 * monthly Product_Forecast__c for the current month and year, by aggregating
 * matching Invoice_Item__c rows.
 *
 * Match key:
 *   Invoice_Item__c.OwnerId                    == Product_Forecast__c.OwnerId
 *   Invoice_Item__c.Invoice__r.Store__c        == Product_Forecast__c.Distributor__c
 *   Invoice_Item__c.Product__c                 == Product_Forecast__c.Product__c
 *     (when Product__c is set on the forecast)
 *   Invoice_Item__c.Product__r.Product_Sub_Group__c == Product_Forecast__c.Product_Sub_Group__c
 *     (when Product__c is null on the forecast)
 *   Invoice__r.Invoice_Date__c falls within the current calendar month/year.
 *
 * Schedules via ForecastActualsScheduler.
 */
global without sharing class ForecastActualsBatch implements Database.Batchable<SObject>, Database.Stateful {

    global Database.QueryLocator start(Database.BatchableContext bc) {
        String monthName = Datetime.now().format('MMMM');
        String yearStr   = String.valueOf(Date.today().year());

        return Database.getQueryLocator([
            SELECT Id, OwnerId, Distributor__c, Product__c, Product_Sub_Group__c,
                   Forecast_KG__c, Actual_Quantity_KG__c
            FROM Product_Forecast__c
            WHERE Approval_Status__c = 'Approved'
              AND Is_Monthly_Forecast__c = true
              AND Forecast_Month__c = :monthName
              AND Forecast_Year__c  = :yearStr
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Product_Forecast__c> scope) {
        Set<Id> distributorIds = new Set<Id>();
        Set<Id> productIds     = new Set<Id>();
        Set<String> subGroups  = new Set<String>();
        Set<Id> ownerIds       = new Set<Id>();

        for (Product_Forecast__c f : scope) {
            if (f.Distributor__c != null) distributorIds.add(f.Distributor__c);
            if (f.OwnerId        != null) ownerIds.add(f.OwnerId);
            if (f.Product__c != null) {
                productIds.add(f.Product__c);
            } else if (String.isNotBlank(f.Product_Sub_Group__c)) {
                subGroups.add(f.Product_Sub_Group__c);
            }
        }

        Integer currentMonth = Date.today().month();
        Integer currentYear  = Date.today().year();

        Map<String, Decimal> productActuals  = new Map<String, Decimal>();
        Map<String, Decimal> subGroupActuals = new Map<String, Decimal>();

        if (!distributorIds.isEmpty() && !ownerIds.isEmpty() && !productIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT Invoice__r.Store__c dist, Product__c prod, OwnerId own,
                       SUM(Net_Weight_in_KG__c) kg
                FROM Invoice_Item__c
                WHERE Invoice__r.Store__c IN :distributorIds
                  AND Product__c          IN :productIds
                  AND OwnerId             IN :ownerIds
                  AND CALENDAR_MONTH(Invoice__r.Invoice_Date__c) = :currentMonth
                  AND CALENDAR_YEAR(Invoice__r.Invoice_Date__c)  = :currentYear
                GROUP BY Invoice__r.Store__c, Product__c, OwnerId
            ]) {
                String key = String.valueOf(ar.get('dist'))
                           + '|' + String.valueOf(ar.get('prod'))
                           + '|' + String.valueOf(ar.get('own'));
                Decimal kg = (Decimal) ar.get('kg');
                productActuals.put(key, kg == null ? 0 : kg);
            }
        }

        if (!distributorIds.isEmpty() && !ownerIds.isEmpty() && !subGroups.isEmpty()) {
            for (AggregateResult ar : [
                SELECT Invoice__r.Store__c dist, Product__r.Product_Sub_Group__c sub, OwnerId own,
                       SUM(Net_Weight_in_KG__c) kg
                FROM Invoice_Item__c
                WHERE Invoice__r.Store__c IN :distributorIds
                  AND Product__r.Product_Sub_Group__c IN :subGroups
                  AND OwnerId IN :ownerIds
                  AND CALENDAR_MONTH(Invoice__r.Invoice_Date__c) = :currentMonth
                  AND CALENDAR_YEAR(Invoice__r.Invoice_Date__c)  = :currentYear
                GROUP BY Invoice__r.Store__c, Product__r.Product_Sub_Group__c, OwnerId
            ]) {
                String key = String.valueOf(ar.get('dist'))
                           + '|' + String.valueOf(ar.get('sub'))
                           + '|' + String.valueOf(ar.get('own'));
                Decimal kg = (Decimal) ar.get('kg');
                subGroupActuals.put(key, kg == null ? 0 : kg);
            }
        }

        List<Product_Forecast__c> toUpdate = new List<Product_Forecast__c>();
        for (Product_Forecast__c f : scope) {
            Decimal actual = 0;
            if (f.Product__c != null) {
                String key = String.valueOf(f.Distributor__c)
                           + '|' + String.valueOf(f.Product__c)
                           + '|' + String.valueOf(f.OwnerId);
                if (productActuals.containsKey(key)) {
                    actual = productActuals.get(key);
                }
            } else if (String.isNotBlank(f.Product_Sub_Group__c)) {
                String key = String.valueOf(f.Distributor__c)
                           + '|' + f.Product_Sub_Group__c
                           + '|' + String.valueOf(f.OwnerId);
                if (subGroupActuals.containsKey(key)) {
                    actual = subGroupActuals.get(key);
                }
            }
            f.Actual_Quantity_KG__c = actual;
            toUpdate.add(f);
        }

        if (!toUpdate.isEmpty()) {
            Database.SaveResult[] results = Database.update(toUpdate, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    System.debug(LoggingLevel.ERROR,
                        'ForecastActualsBatch failed to update ' + toUpdate[i].Id +
                        ' : ' + results[i].getErrors());
                }
            }
        }
    }

    global void finish(Database.BatchableContext bc) {
        // No-op.
    }
}