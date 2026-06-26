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
            Sales_Channel__c ='KA',
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

    }

    @isTest
    static void testEmptyWhenNoTargetForPeriod() {
        Test.startTest();
        PrimaryKpiDashboard_Controller.Dashboard d = PrimaryKpiDashboard_Controller.getDashboard(
            2099, 1, 'Monthly', null
        );
        Test.stopTest();

    }

    @isTest
    static void testDefaultsAndPicker() {
        // Null year/month default to today; picker list is built without error.
        Test.startTest();
        PrimaryKpiDashboard_Controller.Dashboard d = PrimaryKpiDashboard_Controller.getDashboard(
            null, null, null, null
        );
        Test.stopTest();

  
    }
}