@isTest
private class PrimaryKpiDashboard_ControllerTest {

    // A PBIS Target for the running user with the Task-4 calc fields set directly,
    // active in the current month (Monthly).
    @testSetup
    static void setup() {
        S_D_Parameter__c param = new S_D_Parameter__c(
            Name = 'Total Volume Achievement', Is_Mandatory__c = true, Is_Active__c = true
        );
        insert param;

        Date firstOfMonth = Date.today().toStartOfMonth();
        insert new PBIS_Target__c(
            User__c = UserInfo.getUserId(),
            Is_Active__c = true,
            Incentive_Period__c = 'Monthly',
            Start_Date__c = firstOfMonth,
            End_Date__c = Date.today().addDays(30),
            S_D_Parameter_1__c = param.Id,
            S_D_Parameter_1_Weightage__c = 100,
            S_D_Parameter_1_Target__c = 10,
            S_D_Parameter_1_Achievement__c = 8,
            S_D_Parameter_1_Achievement_Percent__c = 80,
            S_D_Parameter_1_Incentive_Amount__c = 5000,
            Total_Incentive_Value__c = 5000,
            Max_Incentive_Value__c = 7000,
            Is_Eligible__c = true
        );
    }

    @isTest
    static void testPersonalDetail() {
        Test.startTest();
        PrimaryKpiDashboard_Controller.Dashboard d = PrimaryKpiDashboard_Controller.getDashboard(
            Date.today().year(), Date.today().month(), 'Monthly', UserInfo.getUserId()
        );
        Test.stopTest();

        System.assertNotEquals(null, d.hero, 'Personal hero should be populated for the focused user');
        System.assertEquals(5000, d.hero.totalIncentive, 'Total Incentive from the target');
        System.assertEquals(7000, d.hero.maxIncentive, 'Max Incentive from the target');
        System.assertEquals(80, d.hero.achievementPct, 'Weighted achievement % = 80 (single slot at 100% weight)');
        System.assertEquals(true, d.hero.isEligible);
        System.assertEquals(1, d.parameters.size(), 'One filled S&D parameter slot');
        System.assertEquals('Total Volume Achievement', d.parameters[0].parameter);
        System.assertEquals(5000, d.parameters[0].incentive);
        System.assert(d.periodLabel.contains('Monthly'), 'Period label includes the incentive period');
    }

    @isTest
    static void testEmptyWhenNoTargetForPeriod() {
        Test.startTest();
        PrimaryKpiDashboard_Controller.Dashboard d = PrimaryKpiDashboard_Controller.getDashboard(
            2099, 1, 'Monthly', null
        );
        Test.stopTest();

        System.assertEquals('EMPTY', d.mode, 'No target active in that period');
        System.assertEquals(null, d.hero);
    }

    @isTest
    static void testDefaultsAndPicker() {
        // Null year/month default to today; picker list is built without error.
        Test.startTest();
        PrimaryKpiDashboard_Controller.Dashboard d = PrimaryKpiDashboard_Controller.getDashboard(
            null, null, null, null
        );
        Test.stopTest();

        System.assertNotEquals(null, d.periodLabel);
        System.assertNotEquals(null, d.userPickerOptions);
        // The running user's own target is present, so the focused detail is populated.
        System.assertNotEquals(null, d.hero);
    }

    @isTest
    static void testCurrentUserShowsPrimary() {
        // Always returns a non-null Boolean for the running user.
        Test.startTest();
        Boolean shows = PrimaryKpiDashboard_Controller.currentUserShowsPrimary();
        Test.stopTest();
        System.assertNotEquals(null, shows, 'currentUserShowsPrimary returns a Boolean');
    }

    @isTest
    static void testPayrollUserSeesPrimary() {
        // A user with Payroll__c = 'Yes' is allowed to see the Primary KPI tab.
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User payrollUser = new User(
            FirstName = 'Payroll', LastName = 'Kpi',
            Email = 'payroll.kpi@example.com',
            Username = 'payroll.kpi@example.com.pbis',
            Alias = 'paykpi',
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', ProfileId = p.Id, LanguageLocaleKey = 'en_US',
            Payroll__c = 'Yes'
        );
        insert payrollUser;

        Test.startTest();
        System.runAs(payrollUser) {
            System.assertEquals(true, PrimaryKpiDashboard_Controller.currentUserShowsPrimary(),
                'Payroll = Yes user should see the Primary KPI tab');
        }
        Test.stopTest();
    }
}
