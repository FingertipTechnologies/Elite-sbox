/**
 * Daily 9:00 AM PBIS actuals recompute.
 * Schedule once with:
 *   System.schedule('PBIS Actuals Daily 9AM', '0 0 9 * * ?', new PBISActualsScheduler());
 */
global with sharing class PBISActualsScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        // Grouped queries scale with distinct (parameter, period), so a full 200 scope
        // stays well under the SOQL limit (~12 queries/chunk).
        Database.executeBatch(new PBISActualsBatch(), 200);
    }
}