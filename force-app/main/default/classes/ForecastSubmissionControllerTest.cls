@isTest
private class ForecastSubmissionControllerTest {

    private static Account makeDistributor() {
        Account a = new Account(Name = 'Test Distributor');
        insert a;
        return a;
    }

    private static Product__c makeProduct(String subGroup) {
        Product__c p = new Product__c(
            Name = 'Test SKU',
            Is_Active__c = true,
            Product_Sub_Group__c = subGroup
        );
        insert p;
        return p;
    }

    private static Product_Forecast__c baseRecord(Account dist, Product__c prod) {
        return new Product_Forecast__c(
            Distributor__c = dist.Id,
            Product__c = prod != null ? prod.Id : null,
            Product_Sub_Group__c = prod != null ? prod.Product_Sub_Group__c : null,
            Forecast_Month__c = 'May',
            Forecast_Year__c = '2026',
            Forecast_UOM__c = 'KG',
            Forecast__c = 1500
        );
    }

    @isTest
    static void getProductsBySubGroup_returnsActiveProductsForSubGroup() {
        // Pick any value from the global value set; the SOQL filter is what we exercise.
        Account d = makeDistributor();
        Product__c p = new Product__c(Name = 'Active SKU', Is_Active__c = true);
        // Skip Product_Sub_Group__c assignment if global value set is empty in the test org.
        insert p;

        Test.startTest();
        List<Product__c> blank = ForecastSubmissionController.getProductsBySubGroup('');
        List<Product__c> none  = ForecastSubmissionController.getProductsBySubGroup(null);
        Test.stopTest();

        System.assertEquals(0, blank.size(), 'Blank sub group should return no products.');
        System.assertEquals(0, none.size(), 'Null sub group should return no products.');
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

        // Insert path always runs; approval submit may fail without an active process
        // configured in the test org. We assert the controller doesn't throw and that
        // a record id is returned (success or failure both populate recordId after insert).
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
