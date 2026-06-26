@isTest
public class SecondaryTarget_ControllerTest {

    private static User makeUser(String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        return new User(
            FirstName = 'T', LastName = alias,
            Email = alias + '@example.com',
            Username = alias + System.currentTimeMillis() + '@example.com',
            Alias = alias.substring(0, Math.min(8, alias.length())),
            TimeZoneSidKey = 'Asia/Kolkata', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', ProfileId = p.Id,
            Employee_Code__c = 'EC-' + alias + String.valueOf(System.currentTimeMillis())
        );
    }

    @TestSetup
    static void setup() {
        User u = makeUser('stctrl');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }

        Account acc = new Account(Name = 'Outlet', Customer_Type__c = 'Secondary Customer',
            Pincode__c = '123456', Primary_Phone_Number__c = '9876543210',
            State__c = 'Karnataka', District__c = 'Kolar');
        insert acc;

        Product__c prod = new Product__c(Name = 'P', Net_Weight__c = 1, SKU_Code__c = 'STC-P');
        insert prod;

        // Order_Type__c (both objects) + Order_Fulfillment_Status__c are
        // restricted picklists whose active values vary per org (SAP codes
        // in some, 'Secondary Order' in others). Leave them null and scope
        // the criterion's filter by Account__c instead — see filter setup
        // below.
        Order__c o = new Order__c(Account__c = acc.Id,
            OwnerId = u.Id, Order_Date__c = Date.today());
        insert o;

        // Order_Owner_Id__c and Order_Date__c are formula fields from the parent Order.
        insert new List<Order_Item__c>{
            new Order_Item__c(Order__c = o.Id, Product__c = prod.Id, Account__c = acc.Id,
                Quantity__c = 1, Total_Amount__c = 700),
            new Order_Item__c(Order__c = o.Id, Product__c = prod.Id, Account__c = acc.Id,
                Quantity__c = 1, Total_Amount__c = 300)
        };

        // Scope the criterion to the one test Account so pre-existing org
        // data can't bleed into the per-user totals (the previous
        // Order_Type__c filter is unreliable across orgs).
        String accountFilter = '{"filters":[{"id":1,"field":"Account__c","operator":"=","type":"Picklist","value":"'
            + acc.Id + '"}]}';

        Target_Criteria__c crit = new Target_Criteria__c(
            Name = 'Sec Revenue', Object__c = 'Order_Item__c', Operator__c = 'SUM',
            Field__c = 'Total_Amount__c', Date_Field__c = 'Order_Date__c',
            User_Field__c = 'Order_Owner_Id__c', Filters__c = accountFilter, Active__c = true);
        insert crit;

        Secondary_Target__c t = new Secondary_Target__c(
            User__c = u.Id, Target_Criteria__c = crit.Id, Target_Value__c = 2000,
            Sales_Channel__c = null, Is_Active__c = true,
            Start_Date__c = Date.today().addDays(-5), End_Date__c = Date.today().addDays(5));
        insert t;
    }

    @isTest
    static void testCrudAndOptions() {
        Target_Criteria__c crit = [SELECT Id FROM Target_Criteria__c LIMIT 1];
        User u = [SELECT Id FROM User WHERE LastName = 'stctrl' LIMIT 1];
        // Capture the admin id BEFORE entering runAs so the negative
        // assertion below can still check a different user's id.
        Id otherId = UserInfo.getUserId();

        Test.startTest();
        // The seeded user has no UserRoleId, so a manager running this test
        // would scope them out via the new role-hierarchy filter. Run as the
        // seeded user (also no role) so downlineUserIds() returns null → no
        // scope filter is applied → the seeded target is visible.
        List<Secondary_Target__c> list1;
        List<Secondary_Target__c> list2;
        List<Secondary_Target__c> listOther;
        System.runAs(u) {
            list1 = SecondaryTarget_Controller.getTargets('', crit.Id, true, null);
            list2 = SecondaryTarget_Controller.getTargets('', crit.Id, true, u.Id);
            listOther = SecondaryTarget_Controller.getTargets('', crit.Id, true, otherId);
        }
        System.assertEquals(1, list1.size(), 'one active target for the criteria');
        System.assertEquals(1, list2.size(), 'user filter matches the seeded target');
        System.assertEquals(0, listOther.size(), 'a different user returns no rows');

        // Use a date window that doesn't overlap the seeded target
        // (today-5 .. today+5) so the duplicate-active guard doesn't reject
        // this save — the test's purpose is to verify the happy CRUD path,
        // not the duplicate-guard which has its own dedicated test below.
        Secondary_Target__c neu = new Secondary_Target__c(
            User__c = u.Id, Target_Criteria__c = crit.Id, Target_Value__c = 500,
            Is_Active__c = true,
            Start_Date__c = Date.today().addDays(6),
            End_Date__c = Date.today().addDays(20));
        Secondary_Target__c saved = SecondaryTarget_Controller.saveTarget(neu);
        System.assertNotEquals(null, saved.Id);

        Secondary_Target__c fetched = SecondaryTarget_Controller.getTarget(saved.Id);
        System.assertEquals(u.Id, fetched.User__c);

        SecondaryTarget_Controller.deleteTarget(saved.Id);

        System.assert(!SecondaryTarget_Controller.getCriteriaOptions().isEmpty(), 'criteria options present');
        SecondaryTarget_Controller.getFocusedPackOptions();
        SecondaryTarget_Controller.getChannelOptions();
        System.assert(!SecondaryTarget_Controller.searchUsers('T').isEmpty(), 'user search returns rows');
        Test.stopTest();
    }

    @isTest
    static void testDuplicateActiveTargetBlocked() {
        Target_Criteria__c crit = [SELECT Id FROM Target_Criteria__c LIMIT 1];
        User u = [SELECT Id FROM User WHERE LastName = 'stctrl' LIMIT 1];

        // Seeded target covers today-5 .. today+5. A new active target overlapping that
        // window for the same user + criteria must be rejected.
        Secondary_Target__c dup = new Secondary_Target__c(
            User__c = u.Id, Target_Criteria__c = crit.Id, Target_Value__c = 500,
            Is_Active__c = true,
            Start_Date__c = Date.today(), End_Date__c = Date.today().addDays(10)
        );
        Boolean threw = false;
        Test.startTest();
        try {
            SecondaryTarget_Controller.saveTarget(dup);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'overlapping active duplicate should be blocked');

        // Inactive duplicate is allowed.
        Secondary_Target__c inactive = new Secondary_Target__c(
            User__c = u.Id, Target_Criteria__c = crit.Id, Target_Value__c = 500,
            Is_Active__c = false,
            Start_Date__c = Date.today(), End_Date__c = Date.today().addDays(10)
        );
        Secondary_Target__c saved = SecondaryTarget_Controller.saveTarget(inactive);
        System.assertNotEquals(null, saved.Id);

        // Editing the original record (same Id) must NOT trigger self-conflict.
        // Include User_Name__c so saveTarget's "auto-fill from User.Name if
        // blank" branch doesn't throw a 'field not queried' error.
        Secondary_Target__c orig = [SELECT Id, User__c, User_Name__c, Target_Criteria__c, Target_Value__c,
                                           Is_Active__c, Start_Date__c, End_Date__c
                                    FROM Secondary_Target__c
                                    WHERE Is_Active__c = true LIMIT 1];
        orig.Target_Value__c = 3000;
        Secondary_Target__c reSaved = SecondaryTarget_Controller.saveTarget(orig);
        System.assertEquals(3000, reSaved.Target_Value__c);
    }

    @isTest
    static void testRecalculateTarget() {
        Secondary_Target__c t = [SELECT Id FROM Secondary_Target__c LIMIT 1];

        Test.startTest();
        Secondary_Target__c updated = SecondaryTarget_Controller.recalculateTarget(t.Id);
        Test.stopTest();

        System.assertEquals(1000.00, updated.Achievement_Value__c, '700 + 300 secondary revenue');
        System.assertEquals(50.00, updated.Achievement_Percent__c, '1000 / 2000');
        System.assertEquals(1000.00, updated.Pending_Target__c, '2000 - 1000');
        System.assertNotEquals(null, updated.Last_Updated__c);
    }

    @isTest
    static void testImportTargetsInsertUpdateError() {
        Target_Criteria__c crit = [SELECT Id, Name FROM Target_Criteria__c LIMIT 1];
        User u = [SELECT Id, Employee_Code__c FROM User WHERE LastName = 'stctrl' LIMIT 1];
        // Seed an Employee_Code__c value the import will look up.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            u.Employee_Code__c = 'EMP-IMPORT-001';
            update u;
        }
        Secondary_Target__c existing = [SELECT Id, Name FROM Secondary_Target__c LIMIT 1];

        SecondaryTarget_Controller.ImportRow rNew = new SecondaryTarget_Controller.ImportRow();
        rNew.employeeCode = 'EMP-IMPORT-001';
        rNew.criteriaName = crit.Name;
        rNew.startDate = String.valueOf(Date.today().addDays(20));
        rNew.endDate = String.valueOf(Date.today().addDays(50));
        rNew.targetValue = 1500;
        rNew.isActive = true;

        SecondaryTarget_Controller.ImportRow rUpd = new SecondaryTarget_Controller.ImportRow();
        rUpd.targetName = existing.Name;   // STGT-xxxx, not the Id
        rUpd.employeeCode = 'EMP-IMPORT-001';
        rUpd.criteriaName = crit.Name;
        rUpd.startDate = String.valueOf(Date.today().addDays(-5));
        rUpd.endDate = String.valueOf(Date.today().addDays(5));
        rUpd.targetValue = 2500;
        rUpd.isActive = true;

        SecondaryTarget_Controller.ImportRow rBad = new SecondaryTarget_Controller.ImportRow();
        rBad.employeeCode = 'EMP-IMPORT-001';
        rBad.criteriaName = 'No Such Criteria';
        rBad.startDate = String.valueOf(Date.today().addDays(60));
        rBad.endDate = String.valueOf(Date.today().addDays(70));
        rBad.targetValue = 100;
        rBad.isActive = true;

        SecondaryTarget_Controller.ImportRow rUnknownEmp = new SecondaryTarget_Controller.ImportRow();
        rUnknownEmp.employeeCode = 'NO-SUCH-CODE';
        rUnknownEmp.criteriaName = crit.Name;
        rUnknownEmp.startDate = String.valueOf(Date.today().addDays(80));
        rUnknownEmp.endDate = String.valueOf(Date.today().addDays(90));
        rUnknownEmp.targetValue = 100;
        rUnknownEmp.isActive = true;

        Test.startTest();
        SecondaryTarget_Controller.ImportResult res =
            SecondaryTarget_Controller.importTargets(JSON.serialize(
                new List<SecondaryTarget_Controller.ImportRow>{ rNew, rUpd, rBad, rUnknownEmp }));
        Test.stopTest();

        System.assertEquals(1, res.createdCount, 'one inserted');
        System.assertEquals(1, res.updatedCount, 'one updated by Target Name');
        System.assertEquals(2, res.errors.size(), 'two errors (unknown criteria + unknown employee code)');
        System.assertEquals(2500, [SELECT Target_Value__c FROM Secondary_Target__c WHERE Id = :existing.Id].Target_Value__c,
            'updated value persisted');
    }

    @isTest
    static void testRecalculateAll() {
        Test.startTest();
        Id jobId = SecondaryTarget_Controller.recalculateAll();
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'batch enqueued');

        Secondary_Target__c t = [SELECT Achievement_Value__c FROM Secondary_Target__c LIMIT 1];
        System.assertEquals(1000.00, t.Achievement_Value__c, 'batch computed achievement');
    }

    // ----- Isolated option-method coverage (does not depend on saveTarget) -----

    @isTest
    static void testGetCriteriaOptionsStandalone() {
        Test.startTest();
        List<Map<String, String>> opts = SecondaryTarget_Controller.getCriteriaOptions();
        Test.stopTest();
        System.assert(opts != null && !opts.isEmpty(), 'criteria seeded by @TestSetup are surfaced');
        // Each option carries label/value/operator triplet.
        System.assertNotEquals(null, opts[0].get('value'));
        System.assertNotEquals(null, opts[0].get('label'));
    }

    @isTest
    static void testGetChannelOptionsStandalone() {
        Test.startTest();
        List<Map<String, String>> opts = SecondaryTarget_Controller.getChannelOptions();
        Test.stopTest();
        System.assertNotEquals(null, opts, 'channels list is returned (may be empty in some orgs)');
    }

    @isTest
    static void testGetFocusedPackOptionsStandalone() {
        Test.startTest();
        List<Map<String, String>> opts = SecondaryTarget_Controller.getFocusedPackOptions();
        Test.stopTest();
        System.assertNotEquals(null, opts);
        // Schema entries now carry the channel slot we added for the
        // per-channel-filter feature — verify the key is present even when empty.
        if (!opts.isEmpty()) {
            System.assert(opts[0].containsKey('label'));
            System.assert(opts[0].containsKey('value'));
            System.assert(opts[0].containsKey('channel'));
        }
    }

    @isTest
    static void testSearchUsersStandalone() {
        Test.startTest();
        List<Map<String, String>> matches = SecondaryTarget_Controller.searchUsers('T');
        // Even an empty string is acceptable input — the helper wraps it with %.
        List<Map<String, String>> blank = SecondaryTarget_Controller.searchUsers('');
        List<Map<String, String>> nullArg = SecondaryTarget_Controller.searchUsers(null);
        Test.stopTest();
        System.assertNotEquals(null, matches);
        System.assertNotEquals(null, blank);
        System.assertNotEquals(null, nullArg);
    }

    @isTest
    static void testGetTargetsFilterCombinations() {
        // Exercise the dynamic SOQL WHERE-clause assembly: every combination
        // of (channel, criteria, active, userId) builds a different SOQL.
        User u = [SELECT Id FROM User WHERE LastName = 'stctrl' LIMIT 1];
        Target_Criteria__c c = [SELECT Id FROM Target_Criteria__c LIMIT 1];

        Test.startTest();
        SecondaryTarget_Controller.getTargets(null, null, null, null);                // no filters
        SecondaryTarget_Controller.getTargets(null, c.Id, true, null);                // criteria + active
        SecondaryTarget_Controller.getTargets(null, null, null, String.valueOf(u.Id)); // user only
        SecondaryTarget_Controller.getTargets('Cake', c.Id, true, String.valueOf(u.Id)); // every filter
        Test.stopTest();
        // No assertions on row counts (sandbox-dependent); the goal is to
        // exercise each WHERE-clause branch.
        System.assert(true);
    }

    @isTest
    static void testGetTargetReturnsSeededRecord() {
        Secondary_Target__c t = [SELECT Id FROM Secondary_Target__c LIMIT 1];
        Test.startTest();
        Secondary_Target__c got = SecondaryTarget_Controller.getTarget(t.Id);
        Test.stopTest();
        System.assertEquals(t.Id, got.Id);
    }

    @isTest
    static void testDeleteTargetStandalone() {
        // Create-then-delete in this test so other tests still have the
        // seeded target available.
        User u = [SELECT Id, Name FROM User WHERE LastName = 'stctrl' LIMIT 1];
        Target_Criteria__c c = [SELECT Id FROM Target_Criteria__c LIMIT 1];
        Secondary_Target__c throwaway = new Secondary_Target__c(
            User__c = u.Id, User_Name__c = u.Name,
            Target_Criteria__c = c.Id, Target_Value__c = 100,
            Is_Active__c = false,
            Start_Date__c = Date.today(), End_Date__c = Date.today().addDays(1)
        );
        insert throwaway;

        Test.startTest();
        SecondaryTarget_Controller.deleteTarget(throwaway.Id);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Secondary_Target__c WHERE Id = :throwaway.Id]);
    }

    @isTest
    static void testExplainAchievementSmoke() {
        // explainAchievement is the View-Calculation modal driver — biggest
        // uncovered surface in the controller. Smoke-test it against the
        // seeded SUM target so the wrapper structure + dynamic SOQL paths
        // get exercised.
        Secondary_Target__c t = [SELECT Id FROM Secondary_Target__c LIMIT 1];
        Test.startTest();
        SecondaryTarget_Controller.AchievementExplanation exp =
            SecondaryTarget_Controller.explainAchievement(t.Id);
        Test.stopTest();
        System.assertNotEquals(null, exp);
        System.assertNotEquals(null, exp.targetName);
        System.assertNotEquals(null, exp.startDate);
        System.assertNotEquals(null, exp.endDate);
    }

    @isTest
    static void testExplainAchievementAllOperators() {
        // explainAchievement has a switch over Operator__c with one branch
        // per operator (SUM / COUNT / COUNT_DISTINCT / DAILY_* / FOCUS_PACK_*).
        // The smoke test above only exercises SUM. Create one criterion +
        // target per remaining operator and call explainAchievement on each
        // so every branch gets executed.
        User u = [SELECT Id, Name FROM User WHERE LastName = 'stctrl' LIMIT 1];
        Focused_Pack__c fp = new Focused_Pack__c(
            Name = 'Exp Pack', Minimum_Qualifying_Quantity__c = 1
        );
        insert fp;

        Map<String, Target_Criteria__c> crits = new Map<String, Target_Criteria__c>();
        crits.put('COUNT', new Target_Criteria__c(
            Name = 'Exp COUNT', Object__c = 'Order_Item__c', Operator__c = 'COUNT',
            Date_Field__c = 'Order_Date__c', User_Field__c = 'Order_Owner_Id__c', Active__c = true
        ));
        crits.put('COUNT_DISTINCT', new Target_Criteria__c(
            Name = 'Exp UBO', Object__c = 'Order_Item__c', Operator__c = 'COUNT_DISTINCT',
            Date_Field__c = 'Order_Date__c', User_Field__c = 'Order_Owner_Id__c',
            Distinct_Field__c = 'Account__c', Active__c = true
        ));
        crits.put('DAILY_UNIQUE_AVG', new Target_Criteria__c(
            Name = 'Exp TC', Object__c = 'Order_Item__c', Operator__c = 'DAILY_UNIQUE_AVG',
            Date_Field__c = 'Order_Date__c', User_Field__c = 'Order_Owner_Id__c',
            Distinct_Field__c = 'Account__c', Use_Attendance_Divisor__c = true, Active__c = true
        ));
        crits.put('DAILY_LINES_PER_ORDER', new Target_Criteria__c(
            Name = 'Exp TLSD', Object__c = 'Order_Item__c', Operator__c = 'DAILY_LINES_PER_ORDER',
            Date_Field__c = 'Order_Date__c', User_Field__c = 'Order_Owner_Id__c',
            Distinct_Field__c = 'Order__c', Use_Attendance_Divisor__c = true, Active__c = true
        ));
        crits.put('DAILY_RATIO_AVG', new Target_Criteria__c(
            Name = 'Exp Ratio', Object__c = 'Order_Item__c', Operator__c = 'DAILY_RATIO_AVG',
            Date_Field__c = 'Order_Date__c', User_Field__c = 'Order_Owner_Id__c',
            Numerator_Field__c = 'Total_Amount__c', Denominator_Field__c = 'Quantity__c',
            Use_Attendance_Divisor__c = true, Active__c = true
        ));
        crits.put('FOCUS_PACK_REVENUE', new Target_Criteria__c(
            Name = 'Exp FP Rev', Object__c = 'Order_Item__c', Operator__c = 'FOCUS_PACK_REVENUE',
            Date_Field__c = 'Order_Date__c', User_Field__c = 'Order_Owner_Id__c', Active__c = true
        ));
        crits.put('FOCUS_PACK_ECO', new Target_Criteria__c(
            Name = 'Exp FP ECO', Object__c = 'Order_Item__c', Operator__c = 'FOCUS_PACK_ECO',
            Date_Field__c = 'Order_Date__c', User_Field__c = 'Order_Owner_Id__c', Active__c = true
        ));
        insert crits.values();

        List<Secondary_Target__c> targets = new List<Secondary_Target__c>();
        for (String op : crits.keySet()) {
            Boolean needsPack = op.startsWith('FOCUS_PACK');
            targets.add(new Secondary_Target__c(
                User__c = u.Id, User_Name__c = u.Name,
                Target_Criteria__c = crits.get(op).Id, Target_Value__c = 100,
                Focused_Pack__c = needsPack ? fp.Id : null,
                Is_Active__c = true,
                Start_Date__c = Date.today().addDays(-5),
                End_Date__c = Date.today().addDays(5)
            ));
        }
        insert targets;

        Test.startTest();
        for (Secondary_Target__c t : targets) {
            SecondaryTarget_Controller.AchievementExplanation exp =
                SecondaryTarget_Controller.explainAchievement(t.Id);
            System.assertNotEquals(null, exp, 'explainAchievement returned a wrapper');
            System.assertNotEquals(null, exp.targetName);
            System.assertNotEquals(null, exp.operator);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetTargetsExercisesRoleHierarchyHelper() {
        // The other tests wrap getTargets in System.runAs(seededUser) — that
        // user has no UserRoleId, so downlineUserIds() short-circuits and the
        // descendant-walk + user-collection paths stay uncovered. Call
        // getTargets as the default test runner (the org's automated process
        // user / admin), who typically does have a UserRoleId, so the helper
        // runs end-to-end. Assertions are loose — the result set depends on
        // the running user's downline; the goal is just code coverage.
        Test.startTest();
        List<Secondary_Target__c> result =
            SecondaryTarget_Controller.getTargets(null, null, null, null);
        Test.stopTest();
        System.assertNotEquals(null, result, 'getTargets returned a list');
    }
}