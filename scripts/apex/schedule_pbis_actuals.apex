/*
 * Schedule the daily 9:00 AM PBIS actuals & incentive recompute.
 * Run once:  sf apex run -f scripts/apex/schedule_pbis_actuals.apex -o <org>
 */
System.schedule('PBIS Actuals Daily 9AM', '0 0 9 * * ?', new PBISActualsScheduler());
System.debug('Scheduled PBIS Actuals Daily 9AM');
