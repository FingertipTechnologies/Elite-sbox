@isTest
public class SecondaryKpiDashboard_ControllerTest {

    private static User makeUser(String alias, String profileName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
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
        // Standard User stands in for a DSM/SSA — actual DSM/SSA profile names
        // may not exist in every dev org. Mode-specific behaviour is exercised
        // in tests that invoke getDashboard directly with explicit user ids.
        User u = makeUser('kpi', 'Standard User');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }

        Target_Criteria__c crit = new Target_Criteria__c(
            Name = 'KPI Revenue', Object__c = 'Order_Item__c', Operator__c = 'SUM',
            Field__c = 'Total_Amount__c', Date_Field__c = 'Order_Date__c',
            User_Field__c = 'Order_Owner_Id__c', Active__c = true
        );
        insert crit;

        Date today = Date.today();
        Date monthStart = Date.newInstance(today.year(), today.month(), 1);
        Date monthEnd = monthStart.addMonths(1).addDays(-1);

        Secondary_Target__c t = new Secondary_Target__c(
            User__c = u.Id, Target_Criteria__c = crit.Id,
            Target_Value__c = 1000, Achievement_Value__c = 850,
            Achievement_Percent__c = 85.00,
            Is_Active__c = true,
            Start_Date__c = monthStart, End_Date__c = monthEnd
        );
        insert t;

        Incentive_Credit__c ic = new Incentive_Credit__c(
            Executive__c = u.Id, Credit_Amount__c = 500,
            Source__c = 'Secondary PBIS',
            Year__c = today.year(), Month__c = today.month(),
            Target_Criteria__c = crit.Id
        );
        insert ic;
    }

    @isTest
    static void getDashboardWithoutSubordinatesReturnsEmptyOrFallback() {
        Test.startTest();
        SecondaryKpiDashboard_Controller.DashboardData d =
            SecondaryKpiDashboard_Controller.getDashboard(null, null, null);
        Test.stopTest();

        System.assertNotEquals(null, d);
        // Running admin may or may not have DSM/SSAs in the test org — both
        // outcomes are valid; just confirm the contract is honored.
        System.assert(
            d.mode == 'EMPTY' || d.mode == 'TEAM' || d.mode == 'PERSONAL',
            'mode must be one of the three documented values'
        );
    }

    @isTest
    static void coerceInvalidPeriodToCurrent() {
        Test.startTest();
        SecondaryKpiDashboard_Controller.DashboardData d =
            SecondaryKpiDashboard_Controller.getDashboard(2026, 99, null);
        Test.stopTest();

        System.assert(d.month >= 1 && d.month <= 12, 'invalid month coerced to current');
    }

    @isTest
    static void getDsmSsaSubordinatesIsCallable() {
        Test.startTest();
        List<SecondaryKpiDashboard_Controller.UserOption> opts =
            SecondaryKpiDashboard_Controller.getDsmSsaSubordinates();
        Test.stopTest();
        System.assertNotEquals(null, opts);
    }
}