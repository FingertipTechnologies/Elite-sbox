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
            Date.today().year(), Date.today().month(), 'Monthly', UserInfo.getUserId(), null, null
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
            2099, 1, 'Monthly', null, null, null
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
            null, null, null, null, null, null
        );
        Test.stopTest();

        System.assertNotEquals(null, d.periodLabel);
        System.assertNotEquals(null, d.userPickerOptions);
        // The running user's own target is present, so the focused detail is populated.
        System.assertNotEquals(null, d.hero);
    }

    // Selecting Quarterly + a quarter resolves the quarterly target whose
    // Start–End span contains the fiscal quarter's first day, and labels it
    // "Q{n} {fiscalYear}". A fiscal year two years out keeps the end date in the
    // future (validation rule) regardless of when the test runs.
    @isTest
    static void testQuarterlyPeriod() {
        S_D_Parameter__c param = [SELECT Id FROM S_D_Parameter__c LIMIT 1];
        Id me = UserInfo.getUserId();
        Integer fy = Date.today().year() + 2;   // FY start year; Q1 = Apr–Jun fy (future)
        insert new PBIS_Target__c(
            User__c = me,
            Is_Active__c = true,
            Incentive_Period__c = 'Quarterly',
            Start_Date__c = Date.newInstance(fy, 4, 1),
            End_Date__c = Date.newInstance(fy, 6, 30),
            S_D_Parameter_1__c = param.Id,
            S_D_Parameter_1_Weightage__c = 100,
            S_D_Parameter_1_Target__c = 10,
            S_D_Parameter_1_Achievement__c = 9,
            S_D_Parameter_1_Achievement_Percent__c = 90,
            S_D_Parameter_1_Incentive_Amount__c = 6000,
            Total_Incentive_Value__c = 6000,
            Max_Incentive_Value__c = 8000,
            Is_Eligible__c = true
        );

        Test.startTest();
        PrimaryKpiDashboard_Controller.Dashboard d = PrimaryKpiDashboard_Controller.getDashboard(
            fy, null, 'Quarterly', me, null, 1
        );
        Test.stopTest();

        System.assertNotEquals(null, d.hero, 'Quarterly Q1 target should resolve for the fiscal quarter');
        System.assertEquals(6000, d.hero.totalIncentive, 'Quarterly target incentive');
        System.assert(d.periodLabel.startsWith('Q1'), 'Label starts with the quarter: ' + d.periodLabel);
        System.assert(d.periodLabel.contains(String.valueOf(fy)), 'Fiscal-year label present: ' + d.periodLabel);
        System.assert(d.periodLabel.contains('Quarterly'), 'Period noted in label: ' + d.periodLabel);
    }

    // The KPI Dashboard tab wrapper calls this to decide whether to show the
    // Primary tab. It reads the running user's Payroll__c flag.
    @isTest
    static void testCurrentUserShowsPrimary() {
        Test.startTest();
        Boolean shows = PrimaryKpiDashboard_Controller.currentUserShowsPrimary();
        Test.stopTest();
        System.assertNotEquals(null, shows, 'Should return a boolean for the running user');
    }

    // Drilling My Team onto a specific user surfaces THAT user's own record,
    // even if their team below is empty (the July TSE case from the field report).
    @isTest
    static void testTeamDrillShowsSelectedUserRecord() {
        Id me = UserInfo.getUserId();
        Test.startTest();
        PrimaryKpiDashboard_Controller.Dashboard d = PrimaryKpiDashboard_Controller.getDashboard(
            Date.today().year(), Date.today().month(), 'Monthly', null, new List<Id>{ me }, null
        );
        Test.stopTest();

        System.assertEquals(true, d.teamShowsPersonal,
            'A selected user with a target shows their own record inside My Team');
        System.assertNotEquals(null, d.hero, 'Hero built for the drilled-to user');
        System.assertEquals(5000, d.hero.totalIncentive, 'Own record, not the empty team below');
    }

    // The My Team drill-down metadata is always populated so the LWC can render
    // its cascading pickers. The running (admin) user starts at the RSM tier.
    @isTest
    static void testTeamDrilldownMetadata() {
        Test.startTest();
        PrimaryKpiDashboard_Controller.Dashboard d = PrimaryKpiDashboard_Controller.getDashboard(
            Date.today().year(), Date.today().month(), 'Monthly', null, new List<Id>(), null
        );
        Test.stopTest();

        System.assertNotEquals(null, d.teamPickers, 'Drill-down pickers should always be provided');
        System.assertNotEquals(null, d.viewerIsAdmin, 'Admin flag should be set');
    }
}