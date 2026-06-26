/**
 * Tests for PBISActualsRefreshController — the VF list-button controller that launches
 * the batch over all active in-period PBIS Targets and navigates back to the list view.
 */
@isTest
private class PBISActualsRefreshControllerTest {

    @isTest
    static void testRunAllStartsBatch() {
        User u = makeUser();
        S_D_Parameter__c param = new S_D_Parameter__c(
            Name = 'Total Volume Achievement',
            Object__c = 'Invoice_item__c',
            Operator__c = 'SUM',
            Field__c = 'Quantity__c',
            User_Field__c = 'OwnerId',
            Is_Mandatory__c = true,
            Is_Active__c = true
        );
        insert param;
        
   
        
        insert new PBIS_Target__c(
            User__c = u.Id, Is_Active__c = true, Incentive_Period__c = 'Monthly',Sales_Channel__c ='KA',
            S_D_Parameter_1__c = param.Id, S_D_Parameter_1_Target__c = 12,S_D_Parameter_1_Weightage__c =100,
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
            Employee_Code__c  ='111'+alias,
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', ProfileId = p.Id, LanguageLocaleKey = 'en_US'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }
        return u;
    }
}