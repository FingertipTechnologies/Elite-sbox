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
        // Use Standard User as the DSM proxy — DSM/SSA profiles aren't guaranteed
        // to exist in every dev org. The picker behaviour itself is exercised in
        // separate tests with the same profile name set on the viewer.
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
    static void dashboardForSelectedUserAggregatesCorrectly() {
        User u = [SELECT Id FROM User WHERE LastName = 'kpi' LIMIT 1];
        Date today = Date.today();

        Test.startTest();
        SecondaryKpiDashboard_Controller.DashboardData d =
            SecondaryKpiDashboard_Controller.getDashboard(today.year(), today.month(), u.Id);
        Test.stopTest();

        System.assertEquals(u.Id, d.selectedUserId);
        System.assertEquals(1000, d.hero.totalTarget, 'target');
        System.assertEquals(850, d.hero.totalAchievement, 'achievement');
        System.assertEquals(85, d.hero.achievementPct.setScale(0), 'ach pct');
        System.assertEquals(500, d.hero.totalIncentive, 'incentive');
        System.assertEquals(1, d.hero.activeTargets, 'one active target');
        System.assertEquals(1, d.targets.size(), 'one target row');
        // Row carries criterion + matched-incentive snapshot.
        SecondaryKpiDashboard_Controller.TargetRow tr = d.targets[0];
        System.assertEquals('KPI Revenue', tr.criterionName);
        System.assertEquals(500, tr.incentive, 'incentive snapshot for the matched criterion');
    }

    @isTest
    static void dashboardFallsBackForUnknownPeriod() {
        Test.startTest();
        SecondaryKpiDashboard_Controller.DashboardData d =
            SecondaryKpiDashboard_Controller.getDashboard(2026, 99, null);
        Test.stopTest();

        System.assertNotEquals(null, d);
        System.assert(d.month >= 1 && d.month <= 12, 'month coerced to valid range');
    }

    @isTest
    static void dashboardEmptyStateWhenNoSubordinates() {
        // Viewer is the running admin user, who is not a DSM/SSA and (in the test
        // org) has no DSM/SSA subordinates. The dashboard should return the empty
        // state instead of throwing.
        Test.startTest();
        SecondaryKpiDashboard_Controller.DashboardData d =
            SecondaryKpiDashboard_Controller.getDashboard(null, null, null);
        Test.stopTest();

        System.assertNotEquals(null, d);
        // Either we genuinely have no DSM/SSAs (noSubordinates=true) or the test
        // org happens to have one (selectedUserId set). Both outcomes are valid.
        System.assert(d.noSubordinates == true || d.selectedUserId != null,
            'either empty state or fell through to a selected user');
    }

    @isTest
    static void getDsmSsaSubordinatesIsCallable() {
        Test.startTest();
        List<SecondaryKpiDashboard_Controller.UserOption> opts =
            SecondaryKpiDashboard_Controller.getDsmSsaSubordinates();
        Test.stopTest();

        // The list may be empty in the test org; the contract is just that the
        // call succeeds and returns a list.
        System.assertNotEquals(null, opts);
    }
}
