@isTest
private class PBISActuals_ServiceTest {

    // A SOQL that counts Accounts owned by the bound user within the period.
    private static final String ACCOUNT_COUNT_SOQL =
        'SELECT OwnerId, COUNT(Id) total FROM Account ' +
        'WHERE CreatedDate >= :startDate AND CreatedDate <= :endDate ' +
        'AND OwnerId IN :userIds GROUP BY OwnerId';

    // Pick a Salesforce Profile whose Name is also a value in the slab Profile GVS,
    // so the Target's Profile__c formula (= User.Profile.Name) matches a slab.
    private static Profile matchableProfile() {
        Set<String> gvs = new Set<String>();
        for (Schema.PicklistEntry e : PBIS_Incentive_Slab__c.Profile__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) gvs.add(e.getValue());
        }
        for (Profile p : [SELECT Id, Name FROM Profile WHERE Name IN :gvs LIMIT 1]) {
            return p;
        }
        return null;
    }

    @isTest
    static void testFullIncentivePath() {
        Profile matchProf = matchableProfile();
        Profile useProf = matchProf != null
            ? matchProf
            : [SELECT Id, Name FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        // Policy + S&D parameter (created without User DML to avoid MIXED_DML)
        PBIS_Policy__c policy = new PBIS_Policy__c(Name = 'Test PBIS Policy', Basis__c = 'Value', Is_Active__c = true);
        insert policy;

        // Slab profile = the user's profile name when matchable, else a GVS value (no match).
        String slabProfile = matchProf != null ? matchProf.Name : firstGvsValue();
        insert new List<PBIS_Incentive_Slab__c>{
            slab(policy.Id, slabProfile, 1, 90, 94.99, 3.5, 3.7),
            slab(policy.Id, slabProfile, 2, 95, 99.99, 7.5, 6),
            slab(policy.Id, slabProfile, 3, 100, 109.99, 12, 12.9),
            slab(policy.Id, slabProfile, 4, 110, null, 14, 15)
        };

        S_D_Parameter__c param = new S_D_Parameter__c(
            Name = 'Total Revenue Achievement',
            Operator__c = 'COUNT',
            Object__c = 'Account',
            Is_Mandatory__c = true,
            Is_Active__c = true,
            SOQL_Query__c = ACCOUNT_COUNT_SOQL
        );
        insert param;

        // User (setup object) in its own DML context.
        User u = buildUser(useProf.Id, policy.Id, 50000);
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }

        // Two Accounts owned by u → achievement = 2 against a target of 2 → 100%.
        insert new List<Account>{
            new Account(Name = 'A1', OwnerId = u.Id),
            new Account(Name = 'A2', OwnerId = u.Id)
        };

        PBIS_Target__c t = new PBIS_Target__c(
            User__c = u.Id,
            Incentive_Period__c = 'Monthly',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c = Date.today().addDays(1),
            S_D_Parameter_1__c = param.Id,
            S_D_Parameter_1_Weightage__c = 100,
            S_D_Parameter_1_Target__c = 2
        );
        insert t;

        Test.startTest();
        PBISActuals_Service.recalculate(new Set<Id>{ t.Id });
        Test.stopTest();

        PBIS_Target__c r = [
            SELECT S_D_Parameter_1_Achievement__c, S_D_Parameter_1_Achievement_Percent__c,
                   S_D_Parameter_1_Qualified_Slab__c, S_D_Parameter_1_Incentive_Amount__c,
                   Is_Eligible__c, Total_Incentive_Value__c, Max_Incentive_Value__c, Validation_Message__c
            FROM PBIS_Target__c WHERE Id = :t.Id
        ];

        System.assertEquals(2, r.S_D_Parameter_1_Achievement__c, 'Two accounts should be counted');
        System.assertEquals(100, r.S_D_Parameter_1_Achievement_Percent__c, 'Achievement % = 2/2*100');

        if (matchProf != null) {
            // 100% lands in slab 3 (Monthly 12%): 50000 * 12% * 100% = 6000; eligible (>= floor 90).
            System.assertEquals(6000, r.S_D_Parameter_1_Incentive_Amount__c, 'Gross x slab% x weightage');
            System.assertEquals(true, r.Is_Eligible__c, 'Mandatory 100% >= floor 90 → eligible');
            System.assertEquals(6000, r.Total_Incentive_Value__c, 'Total = sum of slot incentives');
            System.assertEquals(7000, r.Max_Incentive_Value__c, 'Max = top slab 14% x gross x weightage');
            System.assertNotEquals(null, r.S_D_Parameter_1_Qualified_Slab__c, 'A slab should be matched');
        } else {
            // No profile matches the slab set → no slab, not eligible, total 0.
            System.assertEquals(0, r.Total_Incentive_Value__c, 'No slab → total 0');
            System.assertEquals(false, r.Is_Eligible__c, 'No slab → not eligible');
            System.assert(r.Validation_Message__c != null &&
                r.Validation_Message__c.contains('slab'), 'Should note missing slabs');
        }
    }

    @isTest
    static void testNoPolicyValidation() {
        // User without a PBIS_Policy → validation message, no incentive.
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = buildUser(p.Id, null, 40000);
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }
        S_D_Parameter__c param = new S_D_Parameter__c(
            Name = 'Vol', Operator__c = 'COUNT', Object__c = 'Account',
            Is_Mandatory__c = true, Is_Active__c = true, SOQL_Query__c = ACCOUNT_COUNT_SOQL
        );
        insert param;
        PBIS_Target__c t = new PBIS_Target__c(
            User__c = u.Id, Incentive_Period__c = 'Monthly',
            Start_Date__c = Date.today().addDays(-1), End_Date__c = Date.today().addDays(1),
            S_D_Parameter_1__c = param.Id, S_D_Parameter_1_Weightage__c = 100, S_D_Parameter_1_Target__c = 5
        );
        insert t;

        Test.startTest();
        PBISActuals_Controller.recalcOne(t.Id); // exercises the quick-action endpoint
        Test.stopTest();

        PBIS_Target__c r = [SELECT Is_Eligible__c, Total_Incentive_Value__c, Validation_Message__c
                            FROM PBIS_Target__c WHERE Id = :t.Id];
        System.assertEquals(0, r.Total_Incentive_Value__c, 'No policy → total 0');
        System.assert(r.Validation_Message__c != null, 'Validation message expected');
    }

    @isTest
    static void testBatchAndScheduler() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = buildUser(p.Id, null, 30000);
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }
        S_D_Parameter__c param = new S_D_Parameter__c(
            Name = 'Vol', Operator__c = 'COUNT', Object__c = 'Account',
            Is_Mandatory__c = true, Is_Active__c = true, SOQL_Query__c = ACCOUNT_COUNT_SOQL
        );
        insert param;
        insert new PBIS_Target__c(
            User__c = u.Id, Is_Active__c = true, Incentive_Period__c = 'Monthly',
            Start_Date__c = Date.today().addDays(-1), End_Date__c = Date.today().addDays(1),
            S_D_Parameter_1__c = param.Id, S_D_Parameter_1_Weightage__c = 100, S_D_Parameter_1_Target__c = 1
        );

        Test.startTest();
        Database.executeBatch(new PBISActualsBatch(), 10);
        System.schedule('PBIS Actuals Test', '0 0 9 * * ?', new PBISActualsScheduler());
        Test.stopTest();

        System.assert([SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'BatchApex'] >= 1,
            'Batch should have been enqueued');
    }

    @isTest
    static void testRefreshController() {
        Test.startTest();
        PBISActualsRefreshController ctl = new PBISActualsRefreshController(
            new ApexPages.StandardSetController(
                Database.getQueryLocator([SELECT Id FROM PBIS_Target__c])
            )
        );
        ctl.runAll();
        Test.stopTest();
        System.assertEquals(true, ctl.started, 'Refresh should mark started');
    }

    // ===== helpers =====
    private static PBIS_Incentive_Slab__c slab(Id policyId, String profile, Integer num,
            Decimal from, Decimal upto, Decimal monthly, Decimal quarterly) {
        return new PBIS_Incentive_Slab__c(
            PBIS_Policy__c = policyId, Profile__c = profile, Slab_Number__c = num,
            Achievement_From__c = from, Achievement_To__c = upto,
            Monthly_Incentive_Percent__c = monthly, Quarterly_Incentive_Percent__c = quarterly,
            Is_Active__c = true
        );
    }

    private static String firstGvsValue() {
        for (Schema.PicklistEntry e : PBIS_Incentive_Slab__c.Profile__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) return e.getValue();
        }
        return null;
    }

    private static User buildUser(Id profileId, Id policyId, Decimal salary) {
        String alias = 'pbis' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        return new User(
            FirstName = 'PBIS', LastName = 'Calc',
            Email = alias + '@example.com',
            Username = alias + '.pbiscalc@example.com',
            Alias = alias.left(8),
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', ProfileId = profileId, LanguageLocaleKey = 'en_US',
            Monthly_Gross_Salary_INR__c = salary,
            PBIS_Policy__c = policyId
        );
    }
}
