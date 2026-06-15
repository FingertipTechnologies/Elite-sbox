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
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', ProfileId = p.Id
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
}