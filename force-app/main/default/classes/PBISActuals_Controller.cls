/**
 * Server endpoint for the per-record "Recalculate Incentive" quick action.
 * Recomputes a single PBIS Target synchronously.
 */
public with sharing class PBISActuals_Controller {
    @AuraEnabled
    public static void recalcOne(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('No record id provided.');
        }
        try {
            PBISActuals_Service.recalculate(new Set<Id>{ recordId });
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
