/**
 * Schedules ForecastActualsBatch to run daily at 9:00 AM (BRD point 8).
 * Register via scripts/apex/scheduleForecastActuals.apex.
 */
global class ForecastActualsScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new ForecastActualsBatch(), 200);
    }
}
