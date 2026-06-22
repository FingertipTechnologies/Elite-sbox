@isTest
public class SecondaryAchievementBatchTest {

    // Account.Customer_Type__c is the only restricted picklist the test
    // setup still touches that's worth defending — keep it resilient to
    // org-specific picklist drift via firstActivePicklist().
    //
    // Order_Type__c was previously filtered on by every criterion, but the
    // production engine uses Customer_Order_Type__c (a formula derived from
    // the parent Order) instead, and the per-org Order_Type__c values vary
    // wildly (SAP codes like ZTRK / ZCST / ZDSO in some orgs, the literal
    // 'Primary Order' / 'Secondary Order' in others). The test setup
    // inserts only secondary-style data, so we just drop the filter — the
    // engine aggregates every Order_Item__c the user owns, which is exactly
    // what the test assertions expect.
    private static final String CUSTOMER_TYPE_VALUE = firstActivePicklist(Account.Customer_Type__c, 'Secondary Customer');
    private static final String VISIT_SOURCE =
        '[{"object":"Visit_Form__c","userField":"OwnerId","dateField":"CreatedDate","distinctField":"CustomerId__c"}]';

    private static String firstActivePicklist(Schema.SObjectField field, String preferred) {
        List<Schema.PicklistEntry> entries = field.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry e : entries) {
            if (e.isActive() && e.getValue() == preferred) return preferred;
        }
        for (Schema.PicklistEntry e : entries) {
            if (e.isActive()) return e.getValue();
        }
        return preferred;
    }

    private static Date startDate = Date.today().addDays(-5);
    private static Date endDate = Date.today().addDays(5);
    private static Date d1 = Date.today();
    private static Date d2 = Date.today().addDays(1);
    private static Date d3 = Date.today().addDays(2);

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

    private static Account makeAccount(String name) {
        return new Account(
            Name = name, Customer_Type__c = CUSTOMER_TYPE_VALUE,
            Pincode__c = '123456', Primary_Phone_Number__c = '9876543210',
            State__c = 'Karnataka', District__c = 'Kolar'
        );
    }

    // Both Order_Type__c and Order_Fulfillment_Status__c on Order__c are
    // optional (required=false in the source metadata) AND unused by the
    // calculation engine — the only Order_Type__c the engine cares about
    // lives on Order_Item__c, set inside makeItem below. Leaving them null
    // here sidesteps every per-org picklist quirk on the parent Order
    // (validation rules, record-type filtering, drift between source and
    // deployed picklist values).
    private static Order__c makeOrder(Id ownerId, Id accId, String type, Date orderDate) {
        return new Order__c(
            Account__c = accId, OwnerId = ownerId, Order_Date__c = orderDate
        );
    }

    // Order_Owner_Id__c and Order_Date__c are formula fields derived from the
    // parent Order, so they are set there (via makeOrder), not on the item.
    // `type` is accepted but no longer applied — Order_Type__c was a per-org
    // restricted picklist that complicates the deploy; the criterion filter
    // is dropped instead (see SECONDARY_FILTER removal).
    private static Order_Item__c makeItem(Id orderId, Id prodId, Id accId,
                                          Decimal qty, Decimal amount, String type) {
        return new Order_Item__c(
            Order__c = orderId, Product__c = prodId, Account__c = accId,
            Quantity__c = qty, Each_Qyt__c = qty,
            // Non_Taxable_Order_Value__c is a formula (Total_Amount - Tax_Amount);
            // zero tax makes the pre-tax value equal the amount (BRD 3.3.5).
            Total_Amount__c = amount, Tax_Amount__c = 0
        );
    }

    private static Target_Criteria__c baseCriteria(String name, String op) {
        return new Target_Criteria__c(
            Name = name, Object__c = 'Order_Item__c', Operator__c = op,
            Date_Field__c = 'Order_Date__c', User_Field__c = 'Order_Owner_Id__c',
            Active__c = true
        );
    }

    private static Secondary_Target__c makeTarget(Id userId, Id critId, Decimal target, Id packId) {
        return new Secondary_Target__c(
            User__c = userId, Target_Criteria__c = critId, Target_Value__c = target,
            Focused_Pack__c = packId, Is_Active__c = true,
            Start_Date__c = startDate, End_Date__c = endDate
        );
    }

    // Day_Started_Date__c is a formula on Day_started_time__c (a DateTime);
    // use mid-day so the date does not shift across time zones.
    private static Daily_Log__c makeLog(Id userId, Date d) {
        return new Daily_Log__c(
            User__c = userId, OwnerId = userId,
            Day_started_time__c = Datetime.newInstance(d.year(), d.month(), d.day(), 12, 0, 0)
        );
    }

    private static Visit_Form__c makeVisit(Id ownerId, Id outletId) {
        return new Visit_Form__c(
            OwnerId = ownerId, Secondary_Customer__c = outletId,
            Geo_Location__Latitude__s = 17.41, Geo_Location__Longitude__s = 78.43
        );
    }

    @TestSetup
    static void setup() {
        Date day1 = Date.today();
        Date day2 = Date.today().addDays(1);
        Date day3 = Date.today().addDays(2);

        // Users — one per parameter so each criteria's user filter isolates data.
        User uRev = makeUser('srev');
        User uUbo = makeUser('subo');
        User uTc = makeUser('stc');
        User uPc = makeUser('spc');
        User uTlsd = makeUser('stlsd');
        User uFpRev = makeUser('sfprev');
        User uFpEco = makeUser('sfpeco');
        // User is a setup object; isolate its DML to avoid MIXED_DML with the data below.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new List<User>{ uRev, uUbo, uTc, uPc, uTlsd, uFpRev, uFpEco };
        }

        Account acc1 = makeAccount('Outlet 1');
        Account acc2 = makeAccount('Outlet 2');
        Account acc3 = makeAccount('Outlet 3');
        insert new List<Account>{ acc1, acc2, acc3 };

        Product__c prodA = new Product__c(Name = 'Pack A', Net_Weight__c = 1, SKU_Code__c = 'SAB-A');
        Product__c prodB = new Product__c(Name = 'Pack B', Net_Weight__c = 1, SKU_Code__c = 'SAB-B');
        Product__c prodC = new Product__c(Name = 'Other C', Net_Weight__c = 1, SKU_Code__c = 'SAB-C');
        insert new List<Product__c>{ prodA, prodB, prodC };

        // Focus packs
        Focused_Pack__c fpRev = new Focused_Pack__c(Name = 'FP Rev', Minimum_Qualifying_Quantity__c = 1);
        Focused_Pack__c fpEco = new Focused_Pack__c(Name = 'FP Eco', Minimum_Qualifying_Quantity__c = 12);
        insert new List<Focused_Pack__c>{ fpRev, fpEco };
        insert new List<Focused_Pack_Item__c>{
            new Focused_Pack_Item__c(Focused_Pack__c = fpRev.Id, SKU__c = prodA.Id),
            new Focused_Pack_Item__c(Focused_Pack__c = fpRev.Id, SKU__c = prodB.Id),
            new Focused_Pack_Item__c(Focused_Pack__c = fpEco.Id, SKU__c = prodA.Id),
            new Focused_Pack_Item__c(Focused_Pack__c = fpEco.Id, SKU__c = prodB.Id)
        };

        // Attendance working days (via Day_started_time__c)
        insert new List<Daily_Log__c>{
            makeLog(uTc.Id, day1), makeLog(uTc.Id, day2), makeLog(uTc.Id, day3),
            makeLog(uTlsd.Id, day1), makeLog(uTlsd.Id, day2)
        };

        // Orders — one per (user, date, type) since item date/owner derive from the order.
        Order__c oRevD1 = makeOrder(uRev.Id, acc1.Id, ORDER_TYPE_VALUE, day1);
        Order__c oRevD2 = makeOrder(uRev.Id, acc1.Id, ORDER_TYPE_VALUE, day2);
        Order__c oRevPri = makeOrder(uRev.Id, acc1.Id, 'Primary Order', day1);
        Order__c oUboD1 = makeOrder(uUbo.Id, acc1.Id, ORDER_TYPE_VALUE, day1);
        Order__c oUboD2 = makeOrder(uUbo.Id, acc1.Id, ORDER_TYPE_VALUE, day2);
        Order__c oTcD1 = makeOrder(uTc.Id, acc1.Id, ORDER_TYPE_VALUE, day1);
        Order__c oPcD1 = makeOrder(uPc.Id, acc1.Id, ORDER_TYPE_VALUE, day1);
        Order__c oPcD2 = makeOrder(uPc.Id, acc1.Id, ORDER_TYPE_VALUE, day2);
        Order__c oTlsdD1 = makeOrder(uTlsd.Id, acc1.Id, ORDER_TYPE_VALUE, day1);
        Order__c oTlsdD2 = makeOrder(uTlsd.Id, acc1.Id, ORDER_TYPE_VALUE, day2);
        Order__c oFpRev = makeOrder(uFpRev.Id, acc1.Id, ORDER_TYPE_VALUE, day1);
        Order__c oEco1 = makeOrder(uFpEco.Id, acc1.Id, ORDER_TYPE_VALUE, day1);
        Order__c oEco2 = makeOrder(uFpEco.Id, acc2.Id, ORDER_TYPE_VALUE, day1);
        Order__c oEco3 = makeOrder(uFpEco.Id, acc2.Id, ORDER_TYPE_VALUE, day1);
        insert new List<Order__c>{
            oRevD1, oRevD2, oRevPri, oUboD1, oUboD2, oTcD1, oPcD1, oPcD2,
            oTlsdD1, oTlsdD2, oFpRev, oEco1, oEco2, oEco3
        };

        List<Order_Item__c> items = new List<Order_Item__c>();
        // Revenue: 1000 (d1) + 500 (d2) secondary, plus 9999 primary (excluded)
        items.add(makeItem(oRevD1.Id, prodC.Id, acc1.Id, 1, 1000, ORDER_TYPE_VALUE));
        items.add(makeItem(oRevD2.Id, prodC.Id, acc1.Id, 1, 500, ORDER_TYPE_VALUE));
        items.add(makeItem(oRevPri.Id, prodC.Id, acc1.Id, 1, 9999, 'Primary Order'));
        // UBO distinct outlets: acc1, acc1, acc2 -> 2
        items.add(makeItem(oUboD1.Id, prodC.Id, acc1.Id, 1, 10, ORDER_TYPE_VALUE));
        items.add(makeItem(oUboD1.Id, prodC.Id, acc2.Id, 1, 10, ORDER_TYPE_VALUE));
        items.add(makeItem(oUboD2.Id, prodC.Id, acc1.Id, 1, 10, ORDER_TYPE_VALUE));
        // TC: orders today acc1, acc2 (visit forms add acc1 dedup + acc3)
        items.add(makeItem(oTcD1.Id, prodC.Id, acc1.Id, 1, 10, ORDER_TYPE_VALUE));
        items.add(makeItem(oTcD1.Id, prodC.Id, acc2.Id, 1, 10, ORDER_TYPE_VALUE));
        // PC: day1 acc1+acc2, day2 acc1 -> tuples 3, active days 2 -> 1.5
        items.add(makeItem(oPcD1.Id, prodC.Id, acc1.Id, 1, 10, ORDER_TYPE_VALUE));
        items.add(makeItem(oPcD1.Id, prodC.Id, acc2.Id, 1, 10, ORDER_TYPE_VALUE));
        items.add(makeItem(oPcD2.Id, prodC.Id, acc1.Id, 1, 10, ORDER_TYPE_VALUE));
        // TLSD: day1 amt 100+200 qty 2+4 -> 300/6=50 ; day2 amt 90 qty 3 -> 30 ; /2 days = 40
        items.add(makeItem(oTlsdD1.Id, prodC.Id, acc1.Id, 2, 100, ORDER_TYPE_VALUE));
        items.add(makeItem(oTlsdD1.Id, prodC.Id, acc1.Id, 4, 200, ORDER_TYPE_VALUE));
        items.add(makeItem(oTlsdD2.Id, prodC.Id, acc1.Id, 3, 90, ORDER_TYPE_VALUE));
        // Focus Pack Revenue: prodA 300 + prodB 200 (+ prodC 1000 excluded) = 500
        items.add(makeItem(oFpRev.Id, prodA.Id, acc1.Id, 1, 300, ORDER_TYPE_VALUE));
        items.add(makeItem(oFpRev.Id, prodB.Id, acc1.Id, 1, 200, ORDER_TYPE_VALUE));
        items.add(makeItem(oFpRev.Id, prodC.Id, acc1.Id, 1, 1000, ORDER_TYPE_VALUE));
        // Focus Pack ECO (min 12): order1 acc1 6+6=12 qualifies; acc2 split across orders 6/6 fails
        items.add(makeItem(oEco1.Id, prodA.Id, acc1.Id, 6, 60, ORDER_TYPE_VALUE));
        items.add(makeItem(oEco1.Id, prodB.Id, acc1.Id, 6, 60, ORDER_TYPE_VALUE));
        items.add(makeItem(oEco2.Id, prodA.Id, acc2.Id, 6, 60, ORDER_TYPE_VALUE));
        items.add(makeItem(oEco3.Id, prodB.Id, acc2.Id, 6, 60, ORDER_TYPE_VALUE));
        insert items;

        // Visit forms for TC (CreatedDate = today)
        insert new List<Visit_Form__c>{
            makeVisit(uTc.Id, acc1.Id),
            makeVisit(uTc.Id, acc3.Id)
        };

        // Criteria
        Target_Criteria__c cRev = baseCriteria('Sec Revenue', 'SUM');
        cRev.Field__c = 'Total_Amount__c';

        Target_Criteria__c cUbo = baseCriteria('UBO', 'COUNT_DISTINCT');
        cUbo.Distinct_Field__c = 'Account__c';

        Target_Criteria__c cTc = baseCriteria('TC', 'DAILY_UNIQUE_AVG');
        cTc.Distinct_Field__c = 'Account__c';
        cTc.Use_Attendance_Divisor__c = true;
        cTc.Secondary_Source_Objects__c = VISIT_SOURCE;

        Target_Criteria__c cPc = baseCriteria('PC', 'DAILY_UNIQUE_AVG');
        cPc.Distinct_Field__c = 'Account__c';
        cPc.Use_Attendance_Divisor__c = false;

        // Average TLSD (BRD 3.3.4): lines per order per day, averaged over working days.
        Target_Criteria__c cTlsd = baseCriteria('Avg TLSD', 'DAILY_LINES_PER_ORDER');
        cTlsd.Distinct_Field__c = 'Order__c';
        cTlsd.Use_Attendance_Divisor__c = true;

        // Generic daily ratio (sum/sum) — keeps that operator covered.
        Target_Criteria__c cTlsdRatio = baseCriteria('TLSD Ratio', 'DAILY_RATIO_AVG');
        cTlsdRatio.Numerator_Field__c = 'Total_Amount__c';
        cTlsdRatio.Denominator_Field__c = 'Quantity__c';
        cTlsdRatio.Use_Attendance_Divisor__c = true;

        Target_Criteria__c cFpRev = baseCriteria('FP Revenue', 'FOCUS_PACK_REVENUE');
        Target_Criteria__c cFpEco = baseCriteria('FP ECO', 'FOCUS_PACK_ECO');
        cFpEco.Field__c = 'Each_Qyt__c'; // configurable ECO quantity field
        insert new List<Target_Criteria__c>{ cRev, cUbo, cTc, cPc, cTlsd, cTlsdRatio, cFpRev, cFpEco };

        Map<String, Id> fp = new Map<String, Id>();
        for (Focused_Pack__c f : [SELECT Id, Name FROM Focused_Pack__c]) fp.put(f.Name, f.Id);

        insert new List<Secondary_Target__c>{
            makeTarget(uRev.Id, cRev.Id, 2000, null),
            makeTarget(uUbo.Id, cUbo.Id, 5, null),
            makeTarget(uTc.Id, cTc.Id, 2, null),
            makeTarget(uPc.Id, cPc.Id, 3, null),
            makeTarget(uTlsd.Id, cTlsd.Id, 5, null),
            makeTarget(uTlsd.Id, cTlsdRatio.Id, 50, null),
            makeTarget(uFpRev.Id, cFpRev.Id, 1000, fp.get('FP Rev')),
            makeTarget(uFpEco.Id, cFpEco.Id, 2, fp.get('FP Eco'))
        };
    }

    private static Decimal achievementFor(String critName) {
        Secondary_Target__c t = [
            SELECT Achievement_Value__c FROM Secondary_Target__c
            WHERE Target_Criteria__r.Name = :critName LIMIT 1
        ];
        return t.Achievement_Value__c;
    }

    @isTest
    static void testBatchComputesAllParameters() {
        Test.startTest();
        Database.executeBatch(new SecondaryAchievementBatch(), 200);
        Test.stopTest();

        System.assertEquals(1500.00, achievementFor('Sec Revenue'), 'Cumulative secondary revenue');
        System.assertEquals(2.00, achievementFor('UBO'), 'Distinct outlets');
        System.assertEquals(1.00, achievementFor('TC'), 'TC = 3 deduped tuples / 3 working days');
        System.assertEquals(1.50, achievementFor('PC'), 'PC = 3 tuples / 2 active days');
        System.assertEquals(1.50, achievementFor('Avg TLSD'), 'TLSD = (2/1 day1 + 1/1 day2) / 2 working days');
        System.assertEquals(40.00, achievementFor('TLSD Ratio'), 'Day-wise sum/sum avg (50+30)/2');
        System.assertEquals(500.00, achievementFor('FP Revenue'), 'Focus pack pre-tax SKU revenue');
        System.assertEquals(1.00, achievementFor('FP ECO'), 'One outlet met min qty within one order');

        Secondary_Target__c rev = [
            SELECT Achievement_Percent__c, Pending_Target__c, Working_Days__c, Last_Updated__c, Daily_Achievement__c
            FROM Secondary_Target__c WHERE Target_Criteria__r.Name = 'Sec Revenue' LIMIT 1
        ];
        System.assertEquals(75.00, rev.Achievement_Percent__c, 'percent = 1500/2000');
        System.assertEquals(500.00, rev.Pending_Target__c, 'pending = 2000-1500');
        System.assertEquals(1500.00, rev.Daily_Achievement__c, 'first run increment from 0');
        System.assertNotEquals(null, rev.Last_Updated__c);

        Secondary_Target__c tc = [
            SELECT Working_Days__c FROM Secondary_Target__c WHERE Target_Criteria__r.Name = 'TC' LIMIT 1
        ];
        System.assertEquals(3, (Integer) tc.Working_Days__c, 'three start-day dates');
    }

    @isTest
    static void testSchedulerEnqueues() {
        Test.startTest();
        String cron = '0 0 1 * * ?';
        System.schedule('Sec Achievement Test', cron, new SecondaryAchievementScheduler());
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = 'Sec Achievement Test']);
    }

    @isTest
    static void testPreviewRoutesThroughEngine() {
        Target_Criteria__c cRev = [SELECT Id FROM Target_Criteria__c WHERE Name = 'Sec Revenue' LIMIT 1];
        Target_Criteria__c cFp = [SELECT Id FROM Target_Criteria__c WHERE Name = 'FP Revenue' LIMIT 1];

        Test.startTest();
        Map<String, Object> revPrev = TAM_TargetCriteria_Controller.previewCriteria(cRev.Id);
        Map<String, Object> fpPrev = TAM_TargetCriteria_Controller.previewCriteria(cFp.Id);
        Test.stopTest();

        System.assertEquals(true, revPrev.get('success'), 'preview ran');
        System.assertNotEquals(null, fpPrev.get('note'), 'focus pack preview returns guidance note');
    }
}
