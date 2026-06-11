/**
 * Controller for the PBISActualsRefresh Visualforce list button. Launches the
 * batch that recalculates actuals & incentive for ALL active PBIS Targets.
 */
public with sharing class PBISActualsRefreshController {

    public Boolean started { get; set; }
    public Integer targetCount { get; set; }

    public PBISActualsRefreshController(ApexPages.StandardSetController controller) {
        started = false;
        targetCount = 0;
    }

    public PageReference runAll() {
        Date today = Date.today();
        targetCount = [
            SELECT COUNT() FROM PBIS_Target__c
            WHERE Is_Active__c = true
              AND Start_Date__c <= :today
              AND End_Date__c >= :today
        ];
        Database.executeBatch(new PBISActualsBatch(), 200);
        started = true;
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM,
            'Started actuals & incentive recalculation for ' + targetCount + ' active PBIS Targets. ' +
            'Refresh the list view in a few moments to see the updated values.'));
        return null;
    }

    /**
     * Cancel / back: return to the PBIS Target list view. The StandardSetController's own
     * cancel() can land on a "page not found" when this page is launched as a list button,
     * so navigate explicitly to the object's list using its key prefix (Lightning upgrades
     * the /{prefix}/o URL to the Lightning list view).
     */
    public PageReference backToList() {
        String prefix = PBIS_Target__c.SObjectType.getDescribe().getKeyPrefix();
        PageReference pr = new PageReference('/' + prefix + '/o');
        pr.setRedirect(true);
        return pr;
    }
}