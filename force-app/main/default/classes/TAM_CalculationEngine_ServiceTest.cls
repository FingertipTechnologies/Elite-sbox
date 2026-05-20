@isTest
public class TAM_CalculationEngine_ServiceTest {

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

    @isTest
    static void testEmptyAndNullGuards() {
        Target_Criteria__c crit = new Target_Criteria__c(
            Name = 'g', Object__c = 'Order_Item__c', Operator__c = 'SUM',
            Field__c = 'Total_Amount__c', Date_Field__c = 'Order_Date__c',
            User_Field__c = 'Order_Owner_Id__c', Active__c = true
        );
        insert crit;

        Test.startTest();
        Map<Id, Decimal> r1 = TAM_CalculationEngine_Service.compute(
            crit, new List<Secondary_Target__c>(), Date.today(), Date.today(), null);
        Map<Id, Decimal> r2 = TAM_CalculationEngine_Service.computePerUser(
            crit, new Set<Id>(), Date.today(), Date.today(), null);
        Test.stopTest();

        System.assertEquals(0, r1.size());
        System.assertEquals(0, r2.size());
    }

    @isTest
    static void testFocusPackEcoDirect() {
        User u = makeUser('engeco');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }

        Account acc1 = new Account(Name = 'O1', Customer_Type__c = 'Secondary Customer',
            Pincode__c = '123456', Primary_Phone_Number__c = '9876543210',
            State__c = 'Karnataka', District__c = 'Kolar');
        Account acc2 = new Account(Name = 'O2', Customer_Type__c = 'Secondary Customer',
            Pincode__c = '123456', Primary_Phone_Number__c = '9876543210',
            State__c = 'Karnataka', District__c = 'Kolar');
        insert new List<Account>{ acc1, acc2 };

        Product__c prodA = new Product__c(Name = 'A', Net_Weight__c = 1);
        Product__c prodB = new Product__c(Name = 'B', Net_Weight__c = 1);
        insert new List<Product__c>{ prodA, prodB };

        Focused_Pack__c fp = new Focused_Pack__c(Name = 'Pack', Minimum_Qualifying_Quantity__c = 12);
        insert fp;
        insert new List<Focused_Pack_Item__c>{
            new Focused_Pack_Item__c(Focused_Pack__c = fp.Id, SKU__c = prodA.Id),
            new Focused_Pack_Item__c(Focused_Pack__c = fp.Id, SKU__c = prodB.Id)
        };

        // acc1 qualifies (12 in one order); acc2 has 6 only -> not qualified
        Order__c o1 = new Order__c(Order_Type__c = 'Secondary Order', Account__c = acc1.Id,
            OwnerId = u.Id, Order_Fulfillment_Status__c = 'Not Fulfilled', Order_Date__c = Date.today());
        Order__c o2 = new Order__c(Order_Type__c = 'Secondary Order', Account__c = acc2.Id,
            OwnerId = u.Id, Order_Fulfillment_Status__c = 'Not Fulfilled', Order_Date__c = Date.today());
        insert new List<Order__c>{ o1, o2 };

        // Order_Owner_Id__c and Order_Date__c are formula fields from the parent Order.
        insert new List<Order_Item__c>{
            new Order_Item__c(Order__c = o1.Id, Product__c = prodA.Id, Account__c = acc1.Id,
                Order_Type__c = 'Secondary Order', Quantity__c = 6, Total_Amount__c = 60),
            new Order_Item__c(Order__c = o1.Id, Product__c = prodB.Id, Account__c = acc1.Id,
                Order_Type__c = 'Secondary Order', Quantity__c = 6, Total_Amount__c = 60),
            new Order_Item__c(Order__c = o2.Id, Product__c = prodA.Id, Account__c = acc2.Id,
                Order_Type__c = 'Secondary Order', Quantity__c = 6, Total_Amount__c = 60)
        };

        Target_Criteria__c crit = new Target_Criteria__c(
            Name = 'Eco', Object__c = 'Order_Item__c', Operator__c = 'FOCUS_PACK_ECO',
            Date_Field__c = 'Order_Date__c', User_Field__c = 'Order_Owner_Id__c', Active__c = true);
        insert crit;

        Secondary_Target__c t = new Secondary_Target__c(
            User__c = u.Id, Target_Criteria__c = crit.Id, Target_Value__c = 5,
            Focused_Pack__c = fp.Id, Is_Active__c = true,
            Start_Date__c = Date.today().addDays(-1), End_Date__c = Date.today().addDays(1));
        insert t;

        Test.startTest();
        Map<Id, Decimal> res = TAM_CalculationEngine_Service.compute(
            crit, new List<Secondary_Target__c>{ t },
            Date.today().addDays(-1), Date.today().addDays(1), null);
        Test.stopTest();

        System.assertEquals(1, (Integer) res.get(t.Id), 'only acc1 met the 12-unit single-order threshold');
    }
}
