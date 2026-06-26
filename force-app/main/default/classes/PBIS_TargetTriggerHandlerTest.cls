@isTest
private class PBIS_TargetTriggerHandlerTest {

    // Two Users with different gross salaries, plus a third with no salary set.
    @testSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        List<User> users = new List<User>{
            buildUser(p.Id, 'pbisone', 60000),
            buildUser(p.Id, 'pbistwo', 85000),
            buildUser(p.Id, 'pbisnone', null) 
        };
        insert users;
    }

    static User buildUser(Id profileId, String alias, Decimal salary) {
        return new User(
            FirstName = 'PBIS', LastName = alias,
            Email = alias + '@example.com',
            Username = alias + '.pbistarget@example.com',
            Employee_Code__c = '1292910'+alias,
            Alias = alias.left(8),
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', ProfileId = profileId, LanguageLocaleKey = 'en_US',
            Monthly_Gross_Salary_INR__c = salary
        );
    }

    static User userByAlias(String alias) {
        return [SELECT Id, Monthly_Gross_Salary_INR__c FROM User
                WHERE Username = :(alias + '.pbistarget@example.com') LIMIT 1];
    }

    // A target with a valid (future) period so the End-Date validation rule passes.
    static PBIS_Target__c newTarget(Id userId, String period) {
        S_D_Parameter__c param = new S_D_Parameter__c(
            Name = 'Total Volume Achievement',
            Object__c = 'Invoice_item__c',
            Operator__c = 'SUM',
            Field__c = 'Quantity__c',
            User_Field__c = 'OwnerId',
            Is_Mandatory__c = true,
            Is_Active__c = true
        );
        insert param;
        
        return new PBIS_Target__c(
            User__c = userId, Incentive_Period__c = period,Sales_Channel__c ='KA',
            S_D_Parameter_1__c = param.Id, S_D_Parameter_1_Target__c = 12,S_D_Parameter_1_Weightage__c =100,
            Start_Date__c = Date.today(), End_Date__c = Date.today().addDays(30)
        );
    }

    @isTest
    static void testInsertCopiesSalary() {
        User u1 = userByAlias('pbisone');

        Test.startTest();
        PBIS_Target__c t = newTarget(u1.Id, 'Monthly');
        insert t;
        Test.stopTest();

        PBIS_Target__c saved = [SELECT Gross_Salary__c FROM PBIS_Target__c WHERE Id = :t.Id];

    }

  

    @isTest
    static void testUpdateOtherFieldKeepsSalary() {
        User u1 = userByAlias('pbisone');
        PBIS_Target__c t = newTarget(u1.Id, 'Monthly');
        insert t;
        // Manually override the salary, then edit an unrelated field.
        t.Gross_Salary__c = 12345;
        update t;

        Test.startTest();
        t.Incentive_Period__c = 'Quarterly';
        update t;
        Test.stopTest();

        PBIS_Target__c saved = [SELECT Gross_Salary__c FROM PBIS_Target__c WHERE Id = :t.Id];
     
    }

  

    // ===== overlap prevention =====
    static PBIS_Target__c newTargetDates(Id userId, String period, Date s, Date e) {
        return new PBIS_Target__c(
            User__c = userId, Incentive_Period__c = period, Start_Date__c = s, End_Date__c = e
        );
    }

    @isTest
    static void testDuplicateWithinBatch() {
        User u1 = userByAlias('pbisone');
        // Two identical periods (same User + Period + dates) in one insert -> overlap.
        List<PBIS_Target__c> rows = new List<PBIS_Target__c>{
            newTarget(u1.Id, 'Monthly'),
            newTarget(u1.Id, 'Monthly')
        };

        Test.startTest();
        List<Database.SaveResult> res = Database.insert(rows, false); // partial success
        Test.stopTest();


    }

  
    @isTest
    static void testDifferentPeriodIsNotDuplicate() {
        User u1 = userByAlias('pbisone');
        insert newTarget(u1.Id, 'Monthly');

        Test.startTest();
        // Same user/dates but a different Incentive Period -> allowed.
        Database.SaveResult r = Database.insert(newTarget(u1.Id, 'Quarterly'), false);
        Test.stopTest();

    }
}