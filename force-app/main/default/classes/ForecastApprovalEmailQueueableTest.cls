@isTest
private class ForecastApprovalEmailQueueableTest {

    @isTest
    static void sendEmail_populatesProductionEmailSentAt() {
        Account d = new Account(Name = 'Test Dist');
        insert d;

        // Leave Is_Monthly_Forecast__c=false to skip BRD validation rules during seed;
        // the email queueable only reads forecast data, not the gate flag.
        Product_Forecast__c f = new Product_Forecast__c(
            Distributor__c = d.Id,
            Forecast_Month__c = 'May',
            Forecast_Year__c = '2026',
            Forecast_UOM__c = 'KG',
            Forecast__c = 1500,
            Approval_Status__c = 'Approved'
        );
        insert f;

        Test.startTest();
        System.enqueueJob(new ForecastApprovalEmailQueueable(f.Id));
        Test.stopTest();

        Product_Forecast__c updated = [
            SELECT Id, Production_Email_Sent_At__c
            FROM Product_Forecast__c
            WHERE Id = :f.Id
        ];
        System.assertNotEquals(null, updated.Production_Email_Sent_At__c,
            'Production_Email_Sent_At__c must be populated after queueable runs.');
    }

    @isTest
    static void invocable_enqueuesWithoutError() {
        Account d = new Account(Name = 'Test Dist 2');
        insert d;

        Product_Forecast__c f = new Product_Forecast__c(
            Distributor__c = d.Id,
            Forecast_Month__c = 'June',
            Forecast_Year__c = '2026',
            Forecast_UOM__c = 'TON',
            Forecast__c = 2,
            Approval_Status__c = 'Approved'
        );
        // Is_Monthly_Forecast__c stays false to bypass BRD validation rules in seed.
        insert f;

        ForecastApprovalEmailQueueable.InvocableInput input = new ForecastApprovalEmailQueueable.InvocableInput();
        input.forecastId = f.Id;

        Test.startTest();
        ForecastApprovalEmailQueueable.enqueueFromFlow(new List<ForecastApprovalEmailQueueable.InvocableInput>{ input });
        ForecastApprovalEmailQueueable.enqueueFromFlow(null);
        ForecastApprovalEmailQueueable.enqueueFromFlow(new List<ForecastApprovalEmailQueueable.InvocableInput>());
        Test.stopTest();
    }

    @isTest
    static void sendEmail_nullId_isNoop() {
        Test.startTest();
        ForecastApprovalEmailQueueable.sendEmail(null);
        Test.stopTest();
    }
}
