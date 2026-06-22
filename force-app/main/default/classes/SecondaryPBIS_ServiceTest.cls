@isTest
public class SecondaryPBIS_ServiceTest {

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

    private static Target_Criteria__c makeCriteria(String name, String op) {
        return new Target_Criteria__c(
            Name = name, Object__c = 'Order_Item__c', Operator__c = op,
            Date_Field__c = 'Order_Date__c', User_Field__c = 'Order_Owner_Id__c',
            Active__c = true
        );
    }

    private static Incentive_Slab__c makeSlab(Id criteriaId, String compareOn, Decimal fromV, Decimal toV, Decimal amount, Id packId) {
        return new Incentive_Slab__c(
            Target_Criteria__c = criteriaId,
            Focused_Pack__c = packId,
            Compare_On__c = compareOn,
            Achievement_From__c = fromV,
            Achievement_To__c = toV,
            Incentive_Amount__c = amount,
            Active__c = true
        );
    }

    @TestSetup
    static void setup() {
        User u = makeUser('pbis');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }

        Focused_Pack__c fp = new Focused_Pack__c(
            Name = 'Test Pack', Minimum_Qualifying_Quantity__c = 1
        );
        insert fp;

        Target_Criteria__c cRev = makeCriteria('Sec Revenue', 'SUM');
        cRev.Field__c = 'Total_Amount__c';
        Target_Criteria__c cFpEco = makeCriteria('FP ECO', 'FOCUS_PACK_ECO');
        insert new List<Target_Criteria__c>{ cRev, cFpEco };

        Date may1 = Date.newInstance(2026, 5, 1);
        Date may31 = Date.newInstance(2026, 5, 31);

        // Revenue: achievement 800 / target 1000 = 80% → matches the <100% slab.
        Secondary_Target__c tRev = new Secondary_Target__c(
            User__c = u.Id, Target_Criteria__c = cRev.Id,
            Target_Value__c = 1000, Achievement_Value__c = 800, Achievement_Percent__c = 80.00,
            Is_Active__c = true, Start_Date__c = may1, End_Date__c = may31
        );
        // Focus Pack ECO: 1 outlet, matches the ≥1 Value slab.
        Secondary_Target__c tFp = new Secondary_Target__c(
            User__c = u.Id, Target_Criteria__c = cFpEco.Id, Focused_Pack__c = fp.Id,
            Target_Value__c = 1, Achievement_Value__c = 1, Achievement_Percent__c = 100.00,
            Is_Active__c = true, Start_Date__c = may1, End_Date__c = may31
        );
        insert new List<Secondary_Target__c>{ tRev, tFp };

        // Revenue slabs (Percent): <100 → 750, 100-105 → 1000, >105 → 1250.
        // Focus Pack ECO slab (Value): ≥1 → 250 (generic, no pack).
        insert new List<Incentive_Slab__c>{
            makeSlab(cRev.Id, 'Percent', 0, 99.99, 750, null),
            makeSlab(cRev.Id, 'Percent', 100, 105, 1000, null),
            makeSlab(cRev.Id, 'Percent', 105.01, null, 1250, null),
            makeSlab(cFpEco.Id, 'Value', 1, null, 250, null)
        };
    }

    private static Decimal monthlyTotal(Id userId, Integer year, Integer month) {
        AggregateResult ar = [
            SELECT SUM(Credit_Amount__c) total FROM Incentive_Credit__c
            WHERE Source__c = 'Secondary PBIS'
              AND Year__c = :year AND Month__c = :month
              AND Executive__c = :userId
        ];
        Object t = ar.get('total');
        return (t == null) ? 0 : (Decimal) t;
    }

    @isTest
    static void testComputeMatchesAndTotals() {
        User u = [SELECT Id FROM User WHERE LastName = 'pbis' LIMIT 1];

        Test.startTest();
        SecondaryPBIS_Service.PbisRunResult res = SecondaryPBIS_Service.computeForMonth(2026, 5);
        Test.stopTest();

        System.assertEquals(2, res.rowsWritten, 'two slab matches expected');

        List<Incentive_Credit__c> rows = [
            SELECT Credit_Amount__c, Compare_On__c, Source__c, Target_Criteria__r.Name
            FROM Incentive_Credit__c
            WHERE Executive__c = :u.Id AND Year__c = 2026 AND Month__c = 5
        ];
        System.assertEquals(2, rows.size());
        Map<String, Decimal> amountByCriterion = new Map<String, Decimal>();
        for (Incentive_Credit__c r : rows) {
            System.assertEquals('Secondary PBIS', r.Source__c);
            amountByCriterion.put(r.Target_Criteria__r.Name, r.Credit_Amount__c);
        }
        System.assertEquals(750.00, amountByCriterion.get('Sec Revenue'), 'Revenue 80% picks <100 slab = 750');
        System.assertEquals(250.00, amountByCriterion.get('FP ECO'), 'FP ECO Value 1 picks ≥1 slab = 250');
        System.assertEquals(1000.00, monthlyTotal(u.Id, 2026, 5), 'aggregate = 750 + 250');
    }

    @isTest
    static void testIdempotentReplace() {
        User u = [SELECT Id FROM User WHERE LastName = 'pbis' LIMIT 1];

        Test.startTest();
        SecondaryPBIS_Service.computeForMonth(2026, 5);
        SecondaryPBIS_Service.computeForMonth(2026, 5);
        Test.stopTest();

        Integer rows = [
            SELECT COUNT() FROM Incentive_Credit__c
            WHERE Executive__c = :u.Id AND Year__c = 2026 AND Month__c = 5 AND Source__c = 'Secondary PBIS'
        ];
        System.assertEquals(2, rows, 'second run replaces, not duplicates');
    }

    @isTest
    static void testPackSpecificSlabBeatsGeneric() {
        Target_Criteria__c cFp = [SELECT Id FROM Target_Criteria__c WHERE Name = 'FP ECO' LIMIT 1];
        Focused_Pack__c fp = [SELECT Id FROM Focused_Pack__c LIMIT 1];
        // pack-specific slab pays MORE than the generic slab — engine must prefer it
        insert makeSlab(cFp.Id, 'Value', 1, null, 300, fp.Id);

        User u = [SELECT Id FROM User WHERE LastName = 'pbis' LIMIT 1];

        Test.startTest();
        SecondaryPBIS_Service.computeForMonth(2026, 5);
        Test.stopTest();

        Incentive_Credit__c fpRow = [
            SELECT Credit_Amount__c, Matched_Slab__c FROM Incentive_Credit__c
            WHERE Executive__c = :u.Id AND Year__c = 2026 AND Month__c = 5
              AND Target_Criteria__c = :cFp.Id
            LIMIT 1
        ];
        System.assertEquals(300.00, fpRow.Credit_Amount__c, 'pack-specific slab wins');
    }

    @isTest
    static void testNoMatchYieldsNoRow() {
        // Achievement below the lowest slab boundary — none should match.
        Target_Criteria__c cRev = [SELECT Id FROM Target_Criteria__c WHERE Name = 'Sec Revenue' LIMIT 1];
        delete [SELECT Id FROM Incentive_Slab__c WHERE Target_Criteria__c = :cRev.Id];
        insert makeSlab(cRev.Id, 'Percent', 100, null, 1000, null); // requires >=100% to qualify

        User u = [SELECT Id FROM User WHERE LastName = 'pbis' LIMIT 1];

        Test.startTest();
        SecondaryPBIS_Service.computeForMonth(2026, 5);
        Test.stopTest();

        Integer revRows = [
            SELECT COUNT() FROM Incentive_Credit__c
            WHERE Executive__c = :u.Id AND Target_Criteria__c = :cRev.Id
              AND Year__c = 2026 AND Month__c = 5 AND Source__c = 'Secondary PBIS'
        ];
        System.assertEquals(0, revRows, 'Revenue 80% should not match a slab requiring >=100');
    }

    @isTest
    static void testSchedulerEnqueues() {
        Test.startTest();
        System.schedule('PBIS Test', '0 0 2 1 * ?', new SecondaryPBISScheduler());
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = 'PBIS Test']);
    }

    // ===== Dedup tie-breakers (findOverlappingTargets / pickBestPerKey / isBetterTarget) =====

    @isTest
    static void testFindOverlappingTargetsByPercentTieBreak() {
        // Add a second 'Sec Revenue' target overlapping the same period for the
        // same user. Higher Achievement_Percent__c should win; the loser is
        // reported as skipped by findOverlappingTargets.
        User u = [SELECT Id FROM User WHERE LastName = 'pbis' LIMIT 1];
        Target_Criteria__c cRev = [SELECT Id FROM Target_Criteria__c WHERE Name = 'Sec Revenue' LIMIT 1];
        Date may1 = Date.newInstance(2026, 5, 1);
        Date may31 = Date.newInstance(2026, 5, 31);

        Secondary_Target__c stronger = new Secondary_Target__c(
            User__c = u.Id, Target_Criteria__c = cRev.Id,
            Target_Value__c = 1000, Achievement_Value__c = 950, Achievement_Percent__c = 95.00,
            Is_Active__c = true, Start_Date__c = may1, End_Date__c = may31
        );
        insert stronger;

        Test.startTest();
        List<SecondaryPBIS_Service.SkippedTargetInfo> skipped =
            SecondaryPBIS_Service.findOverlappingTargets(2026, 5);
        Test.stopTest();

        // The 80%-existing target loses to the 95%-new one — exactly one row
        // is reported skipped, and it's the 80% one (Achievement_Percent__c
        // path of isBetterTarget exercised).
        System.assertEquals(1, skipped.size(), 'exactly one duplicate should be skipped');
        Secondary_Target__c loser = [
            SELECT Id, Achievement_Percent__c FROM Secondary_Target__c
            WHERE Id = :skipped[0].targetId LIMIT 1
        ];
        System.assertEquals(80.00, loser.Achievement_Percent__c, 'the 80% target is the loser');
        System.assertEquals(stronger.Id, skipped[0].keptTargetId, 'the 95% target is the winner');
    }

    @isTest
    static void testFindOverlappingTargetsByValueTieBreak() {
        // Same Achievement_Percent__c on both → tie-break falls through to
        // Achievement_Value__c (line 224 of isBetterTarget).
        User u = [SELECT Id FROM User WHERE LastName = 'pbis' LIMIT 1];
        Target_Criteria__c cRev = [SELECT Id FROM Target_Criteria__c WHERE Name = 'Sec Revenue' LIMIT 1];
        Date may1 = Date.newInstance(2026, 5, 1);
        Date may31 = Date.newInstance(2026, 5, 31);

        // Bring the existing target's percent up to 90% to match what we add.
        Secondary_Target__c existing = [
            SELECT Id, Achievement_Percent__c, Achievement_Value__c
            FROM Secondary_Target__c WHERE Target_Criteria__c = :cRev.Id LIMIT 1
        ];
        existing.Achievement_Percent__c = 90.00;
        existing.Achievement_Value__c = 900;
        update existing;

        Secondary_Target__c higherValue = new Secondary_Target__c(
            User__c = u.Id, Target_Criteria__c = cRev.Id,
            Target_Value__c = 1000, Achievement_Value__c = 1500,  // higher value at same %
            Achievement_Percent__c = 90.00,
            Is_Active__c = true, Start_Date__c = may1, End_Date__c = may31
        );
        insert higherValue;

        Test.startTest();
        List<SecondaryPBIS_Service.SkippedTargetInfo> skipped =
            SecondaryPBIS_Service.findOverlappingTargets(2026, 5);
        Test.stopTest();

        System.assertEquals(1, skipped.size());
        System.assertEquals(higherValue.Id, skipped[0].keptTargetId,
            'higher Achievement_Value__c wins when percent ties');
        System.assertEquals(existing.Id, skipped[0].targetId,
            'the lower-value target is the skipped loser');
    }

    @isTest
    static void testFindOverlappingTargetsByLastModifiedTieBreak() {
        // Percent + Value both tie → tie-break falls through to
        // LastModifiedDate (line 226 of isBetterTarget). The most-recently
        // touched record wins; touch `existing` last so it becomes the winner.
        User u = [SELECT Id FROM User WHERE LastName = 'pbis' LIMIT 1];
        Target_Criteria__c cRev = [SELECT Id FROM Target_Criteria__c WHERE Name = 'Sec Revenue' LIMIT 1];
        Date may1 = Date.newInstance(2026, 5, 1);
        Date may31 = Date.newInstance(2026, 5, 31);

        Secondary_Target__c existing = [
            SELECT Id FROM Secondary_Target__c WHERE Target_Criteria__c = :cRev.Id LIMIT 1
        ];

        Secondary_Target__c sibling = new Secondary_Target__c(
            User__c = u.Id, Target_Criteria__c = cRev.Id,
            Target_Value__c = 1000, Achievement_Value__c = 800, Achievement_Percent__c = 80.00,
            Is_Active__c = true, Start_Date__c = may1, End_Date__c = may31
        );
        insert sibling;
        // Touch the existing record so its LastModifiedDate is strictly newer.
        existing.Last_Updated__c = Datetime.now();
        update existing;

        Test.startTest();
        List<SecondaryPBIS_Service.SkippedTargetInfo> skipped =
            SecondaryPBIS_Service.findOverlappingTargets(2026, 5);
        Test.stopTest();

        System.assertEquals(1, skipped.size());
        System.assertEquals(existing.Id, skipped[0].keptTargetId,
            'most recently modified wins the LastModifiedDate tie-breaker');
        System.assertEquals(sibling.Id, skipped[0].targetId);
    }

    @isTest
    static void testFindOverlappingTargetsHandlesNullAchievementFields() {
        // candidate/kept Achievement_Percent__c == null → covers the null
        // coalesce branches at the top of isBetterTarget (lines 218-219).
        User u = [SELECT Id FROM User WHERE LastName = 'pbis' LIMIT 1];
        Target_Criteria__c cRev = [SELECT Id FROM Target_Criteria__c WHERE Name = 'Sec Revenue' LIMIT 1];
        Date may1 = Date.newInstance(2026, 5, 1);
        Date may31 = Date.newInstance(2026, 5, 31);

        // Existing target has Achievement_Percent__c = 80.
        // Add a sibling with null percent + null value → loses on every axis.
        Secondary_Target__c nullSibling = new Secondary_Target__c(
            User__c = u.Id, Target_Criteria__c = cRev.Id,
            Target_Value__c = 1000,
            Achievement_Value__c = null, Achievement_Percent__c = null,
            Is_Active__c = true, Start_Date__c = may1, End_Date__c = may31
        );
        insert nullSibling;

        Test.startTest();
        List<SecondaryPBIS_Service.SkippedTargetInfo> skipped =
            SecondaryPBIS_Service.findOverlappingTargets(2026, 5);
        Test.stopTest();

        System.assertEquals(1, skipped.size(), 'one of the two must be skipped');
        // Null-percent target is the loser — verify by id.
        System.assertEquals(nullSibling.Id, skipped[0].targetId);
    }

    // ===== findMatchingSlab (public matcher used by the engine) =====

    @isTest
    static void testFindMatchingSlabPicksHighestQualifyingBracket() {
        Target_Criteria__c cRev = [SELECT Id FROM Target_Criteria__c WHERE Name = 'Sec Revenue' LIMIT 1];
        List<Incentive_Slab__c> slabs = [
            SELECT Id, Target_Criteria__c, Sales_Channel__c, Focused_Pack__c,
                   Compare_On__c, Achievement_From__c, Achievement_To__c,
                   Incentive_Amount__c, Active__c
            FROM Incentive_Slab__c WHERE Target_Criteria__c = :cRev.Id
        ];

        // A target sitting in the 100-105% bracket should match the 1,000-payout slab.
        Secondary_Target__c match = new Secondary_Target__c(
            Target_Criteria__c = cRev.Id, Target_Value__c = 1000,
            Achievement_Value__c = 1020, Achievement_Percent__c = 102.00,
            Is_Active__c = true
        );

        Test.startTest();
        Incentive_Slab__c chosen = SecondaryPBIS_Service.findMatchingSlab(match, slabs);
        Test.stopTest();

        System.assertNotEquals(null, chosen);
        System.assertEquals(1000, chosen.Incentive_Amount__c,
            'the 100-105 bracket pays 1,000 per the seed data');
    }

    @isTest
    static void testFindMatchingSlabReturnsNullBelowFloor() {
        // Achievement_Percent__c = -5 falls under every bracket's floor;
        // findMatchingSlab should return null instead of any slab.
        Target_Criteria__c cRev = [SELECT Id FROM Target_Criteria__c WHERE Name = 'Sec Revenue' LIMIT 1];
        // Must SELECT every field findMatchingSlab reads, otherwise it throws
        // "SObject row was retrieved via SOQL without querying the requested field".
        List<Incentive_Slab__c> slabs = [
            SELECT Id, Target_Criteria__c, Sales_Channel__c, Focused_Pack__c,
                   Compare_On__c, Achievement_From__c, Achievement_To__c, Incentive_Amount__c
            FROM Incentive_Slab__c WHERE Target_Criteria__c = :cRev.Id AND Achievement_From__c > 0
        ];

        Secondary_Target__c underTarget = new Secondary_Target__c(
            Target_Criteria__c = cRev.Id,
            Achievement_Value__c = -1, Achievement_Percent__c = -5,
            Is_Active__c = true
        );

        Test.startTest();
        Incentive_Slab__c chosen = SecondaryPBIS_Service.findMatchingSlab(underTarget, slabs);
        Test.stopTest();

        System.assertEquals(null, chosen,
            'below every slab floor → no payout, returns null');
    }
}
