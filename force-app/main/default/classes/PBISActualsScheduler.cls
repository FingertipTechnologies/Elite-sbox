/**
 * Daily 9:00 AM PBIS actuals recompute.
 * Schedule once with:
 *   System.schedule('PBIS Actuals Daily 9AM', '0 0 9 * * ?', new PBISActualsScheduler());
 */
global with sharing class PBISActualsScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new PBISActualsBatch(), 10);
    }
}
