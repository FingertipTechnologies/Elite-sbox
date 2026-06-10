@isTest
private class PBIS_TargetTriggerHandlerTest {

    // Two Users with different gross salaries, plus a third with no salary set.
    @testSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        List<User> users = new List<User>{
            buildUser(p.Id, 'pbisone', 60000),
            buildUser(p.Id, 'pbistwo', 85000),
            buildUser(p.Id, 'pbisnone', null)
        };
        insert users;
    }

    static User buildUser(Id profileId, String alias, Decimal salary) {
        User u = new User(
            FirstName = 'PBIS',
            LastName = alias,
            Email = alias + '@example.com',
            Username = alias + '.pbistarget@example.com',
            Alias = alias.left(8),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = profileId,
            LanguageLocaleKey = 'en_US',
            Monthly_Gross_Salary_INR__c = salary
        );
        return u;
    }

    static User userByAlias(String alias) {
        return [SELECT Id, Monthly_Gross_Salary_INR__c FROM User
                WHERE Username = :(alias + '.pbistarget@example.com') LIMIT 1];
    }

    @isTest
    static void testInsertCopiesSalary() {
        User u1 = userByAlias('pbisone');

        Test.startTest();
        PBIS_Target__c t = new PBIS_Target__c(User__c = u1.Id, Incentive_Period__c = 'Monthly');
        insert t;
        Test.stopTest();

        PBIS_Target__c saved = [SELECT Gross_Salary__c FROM PBIS_Target__c WHERE Id = :t.Id];
        System.assertEquals(60000, saved.Gross_Salary__c, 'Gross Salary should copy from the User on insert');
    }

    @isTest
    static void testUpdateUserRefreshesSalary() {
        User u1 = userByAlias('pbisone');
        User u2 = userByAlias('pbistwo');
        PBIS_Target__c t = new PBIS_Target__c(User__c = u1.Id, Incentive_Period__c = 'Monthly');
        insert t;

        Test.startTest();
        t.User__c = u2.Id;
        update t;
        Test.stopTest();

        PBIS_Target__c saved = [SELECT Gross_Salary__c FROM PBIS_Target__c WHERE Id = :t.Id];
        System.assertEquals(85000, saved.Gross_Salary__c, 'Changing the User should refresh Gross Salary');
    }

    @isTest
    static void testUpdateOtherFieldKeepsSalary() {
        User u1 = userByAlias('pbisone');
        PBIS_Target__c t = new PBIS_Target__c(User__c = u1.Id, Incentive_Period__c = 'Monthly');
        insert t;
        // Manually override the salary, then edit an unrelated field.
        t.Gross_Salary__c = 12345;
        update t;

        Test.startTest();
        t.Incentive_Period__c = 'Quarterly';
        update t;
        Test.stopTest();

        PBIS_Target__c saved = [SELECT Gross_Salary__c FROM PBIS_Target__c WHERE Id = :t.Id];
        System.assertEquals(12345, saved.Gross_Salary__c,
            'Editing a non-User field should not overwrite a manual Gross Salary');
    }

    @isTest
    static void testClearUserBlanksSalary() {
        User u1 = userByAlias('pbisone');
        PBIS_Target__c t = new PBIS_Target__c(User__c = u1.Id, Incentive_Period__c = 'Monthly');
        insert t;

        Test.startTest();
        t.User__c = null;
        update t;
        Test.stopTest();

        PBIS_Target__c saved = [SELECT Gross_Salary__c FROM PBIS_Target__c WHERE Id = :t.Id];
        System.assertEquals(null, saved.Gross_Salary__c, 'Clearing the User should blank Gross Salary');
    }

    @isTest
    static void testInsertWithoutUserAndBulk() {
        User u1 = userByAlias('pbisone');
        User uNone = userByAlias('pbisnone');

        Test.startTest();
        List<PBIS_Target__c> rows = new List<PBIS_Target__c>{
            new PBIS_Target__c(User__c = u1.Id, Incentive_Period__c = 'Monthly'),
            new PBIS_Target__c(User__c = uNone.Id, Incentive_Period__c = 'Monthly'),
            new PBIS_Target__c(Incentive_Period__c = 'Monthly') // no User
        };
        insert rows;
        Test.stopTest();

        Map<Id, PBIS_Target__c> saved = new Map<Id, PBIS_Target__c>([
            SELECT Id, User__c, Gross_Salary__c FROM PBIS_Target__c WHERE Id IN :rows
        ]);
        System.assertEquals(60000, saved.get(rows[0].Id).Gross_Salary__c, 'User with salary copies');
        System.assertEquals(null, saved.get(rows[1].Id).Gross_Salary__c, 'User without salary stays null');
        System.assertEquals(null, saved.get(rows[2].Id).Gross_Salary__c, 'No User leaves salary null');
    }
}