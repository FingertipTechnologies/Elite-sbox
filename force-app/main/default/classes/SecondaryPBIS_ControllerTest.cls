@isTest
public class SecondaryPBIS_ControllerTest {

    private static User makeUser(String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        return new User(
            FirstName = 'T', LastName = alias,
            Email = alias + '@example.com',
            Username = alias + System.currentTimeMillis() + '@example.com',
            Alias = alias.substring(0, Math.min(8, alias.length())),
            TimeZoneSidKey = 'Asia/Kolkata', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', ProfileId = p.Id
        );
    }

    @TestSetup
    static void setup() {
        User u = makeUser('pbisc');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }

        Target_Criteria__c crit = new Target_Criteria__c(
            Name = 'Sec Revenue', Object__c = 'Order_Item__c', Operator__c = 'SUM',
            Date_Field__c = 'Order_Date__c', User_Field__c = 'Order_Owner_Id__c',
            Field__c = 'Total_Amount__c', Active__c = true
        );
        insert crit;

        Date may1 = Date.newInstance(2026, 5, 1);
        Date may31 = Date.newInstance(2026, 5, 31);

        insert new Secondary_Target__c(
            User__c = u.Id, Target_Criteria__c = crit.Id,
            Target_Value__c = 1000, Achievement_Value__c = 1100, Achievement_Percent__c = 110.00,
            Is_Active__c = true, Start_Date__c = may1, End_Date__c = may31
        );

        insert new Incentive_Slab__c(
            Target_Criteria__c = crit.Id, Compare_On__c = 'Percent',
            Achievement_From__c = 105.01, Incentive_Amount__c = 1250, Active__c = true
        );
    }

    @isTest
    static void testSlabCrudAndOptions() {
        Target_Criteria__c crit = [SELECT Id FROM Target_Criteria__c LIMIT 1];

        Test.startTest();
        List<Incentive_Slab__c> list1 = SecondaryPBIS_Controller.getSlabs('', crit.Id, true);
        System.assert(!list1.isEmpty(), 'seeded slab returned');

        Incentive_Slab__c neu = new Incentive_Slab__c(
            Target_Criteria__c = crit.Id, Compare_On__c = 'Percent',
            Achievement_From__c = 100, Achievement_To__c = 105, Incentive_Amount__c = 1000, Active__c = true
        );
        Incentive_Slab__c saved = SecondaryPBIS_Controller.saveSlab(neu);
        System.assertNotEquals(null, saved.Id);

        SecondaryPBIS_Controller.deleteSlab(saved.Id);
        System.assert(!SecondaryPBIS_Controller.getCriteriaOptions().isEmpty());
        SecondaryPBIS_Controller.getChannelOptions();
        SecondaryPBIS_Controller.getFocusedPackOptions();
        Test.stopTest();
    }

    @isTest
    static void testRunMonthAndResults() {
        User u = [SELECT Id FROM User WHERE LastName = 'pbisc' LIMIT 1];

        Test.startTest();
        SecondaryPBIS_Service.PbisRunResult res = SecondaryPBIS_Controller.runMonth(2026, 5);
        Test.stopTest();

        System.assertEquals(1, res.rowsWritten, 'one match for the seeded data');

        List<SecondaryPBIS_Controller.MonthlyTotal> totals =
            SecondaryPBIS_Controller.getUserMonthlyTotals(2026, 5);
        System.assertEquals(1, totals.size());
        System.assertEquals(u.Id, totals[0].executiveId);
        System.assertEquals(1250.00, totals[0].total, 'Revenue 110% picks the >105 slab');

        List<Incentive_Credit__c> rows = SecondaryPBIS_Controller.getUserMonthlyRows(u.Id, 2026, 5);
        System.assertEquals(1, rows.size());
        System.assertEquals(1250.00, rows[0].Credit_Amount__c);
    }

    @isTest
    static void testRunMonthAsync() {
        Test.startTest();
        Id jobId = SecondaryPBIS_Controller.runMonthAsync(2026, 5);
        Test.stopTest();
        System.assertNotEquals(null, jobId);

        Integer rows = [
            SELECT COUNT() FROM Incentive_Credit__c
            WHERE Source__c = 'Secondary PBIS' AND Year__c = 2026 AND Month__c = 5
        ];
        System.assertEquals(1, rows, 'queueable processed the month');
    }

    @isTest
    static void testBulkSave() {
        Target_Criteria__c crit = [SELECT Id FROM Target_Criteria__c LIMIT 1];
        List<Incentive_Slab__c> recs = new List<Incentive_Slab__c>{
            new Incentive_Slab__c(Target_Criteria__c = crit.Id, Compare_On__c = 'Percent',
                Achievement_From__c = 0, Achievement_To__c = 99.99,
                Incentive_Amount__c = 750, Active__c = true),
            new Incentive_Slab__c(Target_Criteria__c = crit.Id, Compare_On__c = 'Percent',
                Achievement_From__c = 100, Achievement_To__c = 105,
                Incentive_Amount__c = 1000, Active__c = true)
        };
        Boolean threwEmpty = false;
        Test.startTest();
        Integer count = SecondaryPBIS_Controller.saveSlabs(recs);
        try {
            SecondaryPBIS_Controller.saveSlabs(new List<Incentive_Slab__c>());
        } catch (AuraHandledException e) {
            threwEmpty = true;
        }
        Test.stopTest();
        System.assertEquals(2, count);
        System.assert(threwEmpty, 'empty list should throw');
    }

    @isTest
    static void testRunMonthValidation() {
        Boolean threw = false;
        try {
            SecondaryPBIS_Controller.runMonth(2026, 0);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'invalid month should throw');
    }
}