/**
 * Recomputes PBIS actuals & incentive for the active PBIS Targets whose period
 * (Start_Date__c .. End_Date__c) includes today — i.e. the current month/quarter
 * targets only. Delegates each scope chunk to PBISActuals_Service.
 */
global without sharing class PBISActualsBatch implements Database.Batchable<SObject>, Database.Stateful {

    global Integer processed = 0;

    global Database.QueryLocator start(Database.BatchableContext bc) {
        Date today = Date.today();
        return Database.getQueryLocator([
            SELECT Id FROM PBIS_Target__c
            WHERE Is_Active__c = true
              AND Start_Date__c <= :today
              AND End_Date__c >= :today
        ]);
    }

    global void execute(Database.BatchableContext bc, List<PBIS_Target__c> scope) {
        Set<Id> ids = new Set<Id>();
        for (PBIS_Target__c t : scope) ids.add(t.Id);
        PBISActuals_Service.recalculate(ids);
        processed += scope.size();
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('PBISActualsBatch processed ' + processed + ' targets.');
    }
}