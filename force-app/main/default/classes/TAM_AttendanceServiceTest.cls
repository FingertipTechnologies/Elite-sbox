@isTest
public class TAM_AttendanceServiceTest {

    private static User makeUser(String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        return new User(
            FirstName = 'T', LastName = alias,
            Email = alias + '@example.com',
            Username = alias + System.currentTimeMillis() + '@example.com',
            Alias = alias.substring(0, Math.min(8, alias.length())),
            TimeZoneSidKey = 'Asia/Kolkata', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', ProfileId = p.Id
        );
    }

    // Day_Started_Date__c is a formula on Day_started_time__c; set time mid-day.
    private static Daily_Log__c makeLog(Id userId, Date d) {
        return new Daily_Log__c(
            User__c = userId, OwnerId = userId,
            Day_started_time__c = Datetime.newInstance(d.year(), d.month(), d.day(), 12, 0, 0)
        );
    }

    @isTest
    static void testWorkingDaysCountsDistinctStartDaysInRange() {
        User u = makeUser('attn');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }

        Date startDate = Date.today().addDays(-10);
        Date endDate = Date.today();
        Date inRange1 = Date.today().addDays(-1);
        Date inRange2 = Date.today().addDays(-2);
        Date outOfRange = Date.today().addDays(-20);

        insert new List<Daily_Log__c>{
            makeLog(u.Id, inRange1),
            // duplicate date should not double count
            makeLog(u.Id, inRange1),
            makeLog(u.Id, inRange2),
            makeLog(u.Id, Date.today()),
            // outside the period — excluded
            makeLog(u.Id, outOfRange)
        };

        Test.startTest();
        Map<Id, Integer> days = TAM_AttendanceService.getWorkingDays(new Set<Id>{ u.Id }, startDate, endDate);
        Map<Id, Set<Date>> dates = TAM_AttendanceService.getWorkingDates(new Set<Id>{ u.Id }, startDate, endDate);
        Test.stopTest();

        System.assertEquals(3, days.get(u.Id), 'three distinct in-range start days');
        System.assertEquals(3, dates.get(u.Id).size(), 'date set matches count');
    }

    @isTest
    static void testEmptyInputReturnsEmpty() {
        Test.startTest();
        Map<Id, Integer> days = TAM_AttendanceService.getWorkingDays(new Set<Id>(), Date.today(), Date.today());
        Test.stopTest();
        System.assertEquals(0, days.size());
    }
}
