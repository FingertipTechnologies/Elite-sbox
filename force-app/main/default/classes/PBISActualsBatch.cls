/**
 * Recomputes PBIS actuals & incentive for every active PBIS Target.
 * Delegates each scope chunk to PBISActuals_Service. Small scope keeps the
 * per-slot aggregate queries well under the async SOQL limit.
 */
global without sharing class PBISActualsBatch implements Database.Batchable<SObject>, Database.Stateful {

    global Integer processed = 0;

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id FROM PBIS_Target__c WHERE Is_Active__c = true
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
