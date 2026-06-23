/**
 * Tests for PBISActualsRefreshController — the VF list-button controller that launches
 * the batch over all active in-period PBIS Targets and navigates back to the list view.
 */
@isTest
private class PBISActualsRefreshControllerTest {

    @isTest
    static void testRunAllStartsBatch() {
        User u = makeUser();
        insert new PBIS_Target__c(
            User__c = u.Id, Is_Active__c = true, Incentive_Period__c = 'Monthly',
            Start_Date__c = Date.today().addDays(-1), End_Date__c = Date.today().addDays(1)
        );

        Test.startTest();
        PBISActualsRefreshController ctl = new PBISActualsRefreshController(
            new ApexPages.StandardSetController(
                Database.getQueryLocator([SELECT Id FROM PBIS_Target__c])
            )
        );
        PageReference pr = ctl.runAll();
        Test.stopTest();

        System.assertEquals(null, pr, 'runAll stays on the page');
        System.assertEquals(true, ctl.started, 'Refresh should mark started');
        System.assert(ctl.targetCount >= 1, 'Counts the active in-period targets');
        System.assert([SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'BatchApex'] >= 1,
            'Batch should have been enqueued');
        System.assert(!ApexPages.getMessages().isEmpty(), 'A confirmation message is added');
    }

    @isTest
    static void testBackToList() {
        PBISActualsRefreshController ctl = new PBISActualsRefreshController(
            new ApexPages.StandardSetController(
                Database.getQueryLocator([SELECT Id FROM PBIS_Target__c])
            )
        );
        PageReference pr = ctl.backToList();

        String prefix = PBIS_Target__c.SObjectType.getDescribe().getKeyPrefix();
        System.assert(pr.getUrl().contains('/' + prefix + '/o'),
            'Back navigates to the PBIS Target list view: ' + pr.getUrl());
    }

    // ===== helpers =====
    private static User makeUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        String alias = 'pb' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User u = new User(
            FirstName = 'PBIS', LastName = 'Refresh',
            Email = alias + '@example.com',
            Username = alias + '.pbisrefresh@example.com',
            Alias = alias.left(8),
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', ProfileId = p.Id, LanguageLocaleKey = 'en_US'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }
        return u;
    }
}