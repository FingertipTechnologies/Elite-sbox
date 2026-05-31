/**
 * Schedules the daily Secondary Targets achievement recompute.
 * Suggested cron (1 AM daily):
 *   System.schedule('Secondary Achievement Daily', '0 0 1 * * ?', new SecondaryAchievementScheduler());
 */
global with sharing class SecondaryAchievementScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new SecondaryAchievementBatch(), 200);
    }
}