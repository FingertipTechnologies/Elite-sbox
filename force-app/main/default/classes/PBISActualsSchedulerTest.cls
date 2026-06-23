/**
 * Tests for PBISActualsScheduler — the daily 9 AM job that enqueues PBISActualsBatch.
 */
@isTest
private class PBISActualsSchedulerTest {

    @isTest
    static void testScheduleEnqueuesBatch() {
        String cron = '0 0 9 * * ?';

        Test.startTest();
        String jobId = System.schedule('PBIS Actuals Test 9AM', cron, new PBISActualsScheduler());
        Test.stopTest();

        CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cron, ct.CronExpression, 'Scheduled with the 9 AM cron expression');
        System.assert([SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'BatchApex'] >= 1,
            'Scheduler should enqueue the actuals batch');
    }
}