// One-time registration for the daily 9:00 AM Forecast actuals job.
// Run via: sf apex run --file scripts/apex/scheduleForecastActuals.apex --target-org <alias>
String cron = '0 0 9 * * ? *';
String jobId = System.schedule('Forecast Actuals Daily 9AM', cron, new ForecastActualsScheduler());
System.debug('Scheduled job Id: ' + jobId);
