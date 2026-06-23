/**
 * Tests for PBISActualsBatch — the batch that recalculates actuals & incentive for the
 * active PBIS Targets whose period includes today. Confirms it runs the service for
 * in-period targets and that the start() filter skips out-of-period ones.
 */
@isTest
private class PBISActualsBatchTest {

    private static final String ACCOUNT_COUNT_SOQL =
        'SELECT OwnerId uid, COUNT(Id) total FROM Account ' +
        'WHERE CreatedDate >= :startDate AND CreatedDate <= :endDate ' +
        'AND OwnerId IN :userIds GROUP BY OwnerId';

    @isTest
    static void testBatchRecalculatesInPeriodTargets() {
        User u = makeUser(40000);
        S_D_Parameter__c param = makeParam();
        insert new List<Account>{
            new Account(Name = 'B1', OwnerId = u.Id),
            new Account(Name = 'B2', OwnerId = u.Id)
        };
        PBIS_Target__c t = makeTarget(u.Id, param.Id,
            Date.today().addDays(-1), Date.today().addDays(1), 2);
        insert t;

        Test.startTest();
        Database.executeBatch(new PBISActualsBatch(), 200);
        Test.stopTest();

        PBIS_Target__c r = [SELECT S_D_Parameter_1_Achievement__c
                            FROM PBIS_Target__c WHERE Id = :t.Id];
        System.assertEquals(2, r.S_D_Parameter_1_Achievement__c,
            'Batch should compute achievement for the in-period target');
        System.assert([SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'BatchApex'] >= 1,
            'Batch should have been enqueued');
    }

    @isTest
    static void testBatchSkipsOutOfPeriodTargets() {
        User u = makeUser(40000);
        S_D_Parameter__c param = makeParam();
        insert new Account(Name = 'B1', OwnerId = u.Id);
        // Period entirely in the past -> excluded by the start() Start<=today<=End filter.
        PBIS_Target__c t = makeTarget(u.Id, param.Id,
            Date.today().addDays(-30), Date.today().addDays(-10), 2);
        insert t;

        Test.startTest();
        Database.executeBatch(new PBISActualsBatch(), 200);
        Test.stopTest();

        PBIS_Target__c r = [SELECT S_D_Parameter_1_Achievement__c
                            FROM PBIS_Target__c WHERE Id = :t.Id];
        System.assertEquals(null, r.S_D_Parameter_1_Achievement__c,
            'Out-of-period target should not be recalculated');
    }

    // ===== helpers =====
    private static User makeUser(Decimal salary) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        String alias = 'pb' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User u = new User(
            FirstName = 'PBIS', LastName = 'Batch',
            Email = alias + '@example.com',
            Username = alias + '.pbisbatch@example.com',
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

    private static PBIS_Target__c makeTarget(Id userId, Id paramId, Date s, Date e, Decimal targetVal) {
        return new PBIS_Target__c(
            User__c = userId, Is_Active__c = true, Incentive_Period__c = 'Monthly',
            Start_Date__c = s, End_Date__c = e,
            S_D_Parameter_1__c = paramId, S_D_Parameter_1_Weightage__c = 100,
            S_D_Parameter_1_Target__c = targetVal
        );
    }
}