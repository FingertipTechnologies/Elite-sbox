/**
 * Tests for PBISActuals_Controller.recalcOne — the per-record "Recalculate Incentive"
 * quick-action endpoint that recomputes a single PBIS Target synchronously.
 */
@isTest
private class PBISActuals_ControllerTest {

    private static final String ACCOUNT_COUNT_SOQL =
        'SELECT OwnerId uid, COUNT(Id) total FROM Account ' +
        'WHERE CreatedDate >= :startDate AND CreatedDate <= :endDate ' +
        'AND OwnerId IN :userIds GROUP BY OwnerId';

    @isTest
    static void testRecalcOnePopulates() {
        User u = makeUser(40000);
        S_D_Parameter__c param = makeParam();
        insert new List<Account>{
            new Account(Name = 'C1', OwnerId = u.Id),
            new Account(Name = 'C2', OwnerId = u.Id),
            new Account(Name = 'C3', OwnerId = u.Id)
        };
        PBIS_Target__c t = new PBIS_Target__c(
            User__c = u.Id, Is_Active__c = true, Incentive_Period__c = 'Monthly',
            Start_Date__c = Date.today().addDays(-1), End_Date__c = Date.today().addDays(1),
            S_D_Parameter_1__c = param.Id, S_D_Parameter_1_Weightage__c = 100,
            S_D_Parameter_1_Target__c = 3
        );
        insert t;

        Test.startTest();
        PBISActuals_Controller.recalcOne(t.Id);
        Test.stopTest();

        PBIS_Target__c r = [SELECT S_D_Parameter_1_Achievement__c, S_D_Parameter_1_Achievement_Percent__c
                            FROM PBIS_Target__c WHERE Id = :t.Id];
        System.assertEquals(3, r.S_D_Parameter_1_Achievement__c, 'Three accounts counted');
        System.assertEquals(100, r.S_D_Parameter_1_Achievement_Percent__c, 'Achievement % = 3/3*100');
    }

    @isTest
    static void testRecalcOneNullThrows() {
        Test.startTest();
        try {
            PBISActuals_Controller.recalcOne(null);
            System.assert(false, 'A null record id should throw');
        } catch (AuraHandledException e) {
            System.assert(true, 'AuraHandledException thrown for null id');
        }
        Test.stopTest();
    }

    // ===== helpers =====
    private static User makeUser(Decimal salary) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        String alias = 'pb' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User u = new User(
            FirstName = 'PBIS', LastName = 'Ctrl',
            Email = alias + '@example.com',
            Username = alias + '.pbisctrl@example.com',
            Alias = alias.left(8),
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', ProfileId = p.Id, LanguageLocaleKey = 'en_US',
            Monthly_Gross_Salary_INR__c = salary
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }
        return u;
    }

    private static S_D_Parameter__c makeParam() {
        S_D_Parameter__c param = new S_D_Parameter__c(
            Name = 'Vol', Operator__c = 'COUNT', Object__c = 'Account',
            Is_Mandatory__c = true, Is_Active__c = true, SOQL_Query__c = ACCOUNT_COUNT_SOQL
        );
        insert param;
        return param;
    }
}