/**
 * Daily batch that recomputes Actual_Quantity_KG__c on every approved
 * Product_Forecast__c by aggregating matching Invoice_item__c rows.
 *
 * Match key (per BRD point 8) — TODO confirm with business:
 *   Invoice_item__c.OwnerId            == Product_Forecast__c.OwnerId
 *   Invoice_item__c.Product__c         == Product_Forecast__c.Product__c
 *   Invoice_item__c.Invoice__r.Store__c == Product_Forecast__c.Distributor__c
 *   Invoice_item__c.Invoice__r.Invoice_Date__c BETWEEN Start_Date__c AND End_Date__c
 *
 * See Batch_TargetActualsActuals.cls for the aggregate-query pattern this
 * stub should follow when fully implemented.
 */
global without sharing class ForecastActualsBatch implements Database.Batchable<SObject>, Database.Stateful {

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, OwnerId, Product__c, Distributor__c, Start_Date__c, End_Date__c,
                   Forecast_KG__c, Actual_Quantity_KG__c
            FROM Product_Forecast__c
            WHERE Approval_Status__c = 'Approved'
              AND Is_Monthly_Forecast__c = true
              AND Start_Date__c != null
              AND End_Date__c != null
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Product_Forecast__c> scope) {
        // TODO: aggregate Invoice_item__c rows per scope record and update Actual_Quantity_KG__c.
        // Skeleton retained so the scheduler can be wired without errors.
        // Reference pattern: force-app/main/default/classes/Batch_TargetActualsActuals.cls
    }

    global void finish(Database.BatchableContext bc) {
        // No-op for now.
    }
}
