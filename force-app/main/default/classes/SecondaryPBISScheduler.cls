/**
 * Monthly scheduler — kicks off PBIS for the prior calendar month.
 * Suggested cron (02:00 on the 1st of every month):
 *   System.schedule('Secondary PBIS Monthly', '0 0 2 1 * ?', new SecondaryPBISScheduler());
 */
global with sharing class SecondaryPBISScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        Date prior = Date.today().addMonths(-1);
        System.enqueueJob(new SecondaryPBISQueueable(prior.year(), prior.month()));
    }
}