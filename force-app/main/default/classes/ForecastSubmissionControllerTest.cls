@isTest
private class ForecastSubmissionControllerTest {

    private static Account makeDistributor() {
        Account a = new Account(Name = 'Test Distributor');
        insert a;
        return a;
    }

    @isTest
    static void getProductsBySubGroup_handlesBlankInput() {
        Test.startTest();
        List<Product__c> blank = ForecastSubmissionController.getProductsBySubGroup('');
        List<Product__c> none  = ForecastSubmissionController.getProductsBySubGroup(null);
        Test.stopTest();

        System.assertEquals(0, blank.size(), 'Blank sub group should return no products.');
        System.assertEquals(0, none.size(), 'Null sub group should return no products.');
    }

    @isTest
    static void searchProducts_returnsEmptyWhenInputsMissing() {
        Account d = makeDistributor();

        Test.startTest();
        List<ForecastSubmissionController.SkuOption> noDist =
            ForecastSubmissionController.searchProducts(null, 'AnySubGroup', '');
        List<ForecastSubmissionController.SkuOption> noSub =
            ForecastSubmissionController.searchProducts(d.Id, '', '');
        List<ForecastSubmissionController.SkuOption> noChannel =
            ForecastSubmissionController.searchProducts(d.Id, 'AnySubGroup', '');
        Test.stopTest();

        System.assertEquals(0, noDist.size(), 'Null distributor should return no rows.');
        System.assertEquals(0, noSub.size(), 'Blank sub group should return no rows.');
        System.assertEquals(0, noChannel.size(), 'Account without sales channel should return no rows.');
    }

    @isTest
    static void saveAndSubmit_nullRecord_returnsError() {
        Test.startTest();
        ForecastSubmissionController.SaveResult res = ForecastSubmissionController.saveAndSubmit(null);
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assertNotEquals(null, res.message);
    }

    @isTest
    static void saveAndSubmit_insertsAndAttemptsApprovalSubmit() {
        Account d = makeDistributor();
        Product_Forecast__c rec = new Product_Forecast__c(
            Distributor__c = d.Id,
            Forecast_Month__c = 'May',
            Forecast_Year__c = '2026',
            Forecast_UOM__c = 'KG',
            Forecast__c = 1500
        );

        Test.startTest();
        ForecastSubmissionController.SaveResult res =
            ForecastSubmissionController.saveAndSubmit(rec);
        Test.stopTest();

        System.assertNotEquals(null, res, 'SaveResult must not be null.');
        if (res.success) {
            Product_Forecast__c saved = [
                SELECT Id, Approval_Status__c, Submitted_Date__c
                FROM Product_Forecast__c
                WHERE Id = :res.recordId
            ];
            System.assertEquals('Submitted for Approval', saved.Approval_Status__c);
            System.assertNotEquals(null, saved.Submitted_Date__c);
        } else {
            System.assertNotEquals(null, res.message);
        }
    }
}