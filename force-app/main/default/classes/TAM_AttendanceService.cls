/**
 * Computes attendance-aware working days per user for a period (BRD 3.3.1).
 * A working day = a date in [startDate, endDate] on which the user completed
 * Start Day (Daily_Log__c.Day_Started_Date__c). Half days still count as a full
 * working day. Approved full-day leaves and telephonic-only days have no Start
 * Day, so they are inherently excluded from the divisor while their orders still
 * count toward achievement.
 */
public without sharing class TAM_AttendanceService {

    public static Map<Id, Set<Date>> getWorkingDates(Set<Id> userIds, Date startDate, Date endDate) {
        Map<Id, Set<Date>> result = new Map<Id, Set<Date>>();
        if (userIds == null || userIds.isEmpty()) return result;

        for (AggregateResult ar : [
            SELECT User__c uid, Day_Started_Date__c d
            FROM Daily_Log__c
            WHERE User__c IN :userIds
              AND Day_Started_Date__c >= :startDate
              AND Day_Started_Date__c <= :endDate
              AND Day_Started_Date__c != NULL
            GROUP BY User__c, Day_Started_Date__c
        ]) {
            Id uid = (Id) ar.get('uid');
            Date d = (Date) ar.get('d');
            if (!result.containsKey(uid)) result.put(uid, new Set<Date>());
            result.get(uid).add(d);
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
