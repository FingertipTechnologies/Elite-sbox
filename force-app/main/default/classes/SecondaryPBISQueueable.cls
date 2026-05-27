/**
 * Async runner for the monthly Secondary PBIS computation. One-shot — enqueue
 * once per month either from the scheduler or the console.
 */
public without sharing class SecondaryPBISQueueable implements Queueable {
    private final Integer year;
    private final Integer month;

    public SecondaryPBISQueueable(Integer year, Integer month) {
        this.year = year;
        this.month = month;
    }

    public void execute(QueueableContext qc) {
        SecondaryPBIS_Service.computeForMonth(year, month);
    }
}