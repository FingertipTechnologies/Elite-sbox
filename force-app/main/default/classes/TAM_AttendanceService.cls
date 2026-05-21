/**
 * Computes attendance-aware working days per user for a period (BRD 3.3.1).
 * A working day = a date in [startDate, endDate] on which the user completed
 * Start Day (Daily_Log__c.Day_Started_Date__c). Daily Logs are matched by OwnerId
 * (the field rep who owns the log). Half days still count as a full working day.
 * Approved full-day leaves and telephonic-only days have no Start Day, so they are
 * inherently excluded from the divisor while their orders still count.
 */
public without sharing class TAM_AttendanceService {

    public static Map<Id, Set<Date>> getWorkingDates(Set<Id> userIds, Date startDate, Date endDate) {
        Map<Id, Set<Date>> result = new Map<Id, Set<Date>>();
        if (userIds == null || userIds.isEmpty()) return result;

        // Raw rows (no GROUP BY) — Day_Started_Date__c is a formula field and is
        // not reliably groupable; dedup per (owner, date) happens in Apex.
        for (Daily_Log__c dl : [
            SELECT OwnerId, Day_Started_Date__c
            FROM Daily_Log__c
            WHERE OwnerId IN :userIds
              AND Day_Started_Date__c >= :startDate
              AND Day_Started_Date__c <= :endDate
              AND Day_Started_Date__c != NULL
        ]) {
            if (!result.containsKey(dl.OwnerId)) result.put(dl.OwnerId, new Set<Date>());
            result.get(dl.OwnerId).add(dl.Day_Started_Date__c);
        }
        return result;
    }

    public static Map<Id, Integer> getWorkingDays(Set<Id> userIds, Date startDate, Date endDate) {
        Map<Id, Integer> days = new Map<Id, Integer>();
        Map<Id, Set<Date>> dates = getWorkingDates(userIds, startDate, endDate);
        for (Id uid : dates.keySet()) {
            days.put(uid, dates.get(uid).size());
        }
        return days;
    }
}
