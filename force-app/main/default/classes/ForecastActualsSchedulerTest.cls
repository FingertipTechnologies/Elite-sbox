@isTest
private class ForecastActualsSchedulerTest {

    @isTest
    static void scheduler_runsWithoutError() {
        Test.startTest();
        String jobId = System.schedule(
            'Forecast Actuals Test',
            '0 0 9 * * ? *',
            new ForecastActualsScheduler()
        );
        Test.stopTest();
        System.assertNotEquals(null, jobId);
    }

    @isTest
    static void batch_executesEmptyScope() {
        Test.startTest();
        Database.executeBatch(new ForecastActualsBatch(), 200);
        Test.stopTest();
    }
}
