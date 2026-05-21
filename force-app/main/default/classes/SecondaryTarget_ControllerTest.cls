@isTest
public class SecondaryTarget_ControllerTest {

    private static final String SECONDARY_FILTER =
        '{"filters":[{"id":1,"field":"Order_Type__c","operator":"=","type":"Picklist","value":"Secondary Order"}]}';

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

        Product__c prod = new Product__c(Name = 'P', Net_Weight__c = 1);
        insert prod;

        Order__c o = new Order__c(Order_Type__c = 'Secondary Order', Account__c = acc.Id,
            OwnerId = u.Id, Order_Fulfillment_Status__c = 'Not Fulfilled', Order_Date__c = Date.today());
        insert o;

        // Order_Owner_Id__c and Order_Date__c are formula fields from the parent Order.
        insert new List<Order_Item__c>{
            new Order_Item__c(Order__c = o.Id, Product__c = prod.Id, Account__c = acc.Id,
                Order_Type__c = 'Secondary Order', Quantity__c = 1, Total_Amount__c = 700),
            new Order_Item__c(Order__c = o.Id, Product__c = prod.Id, Account__c = acc.Id,
                Order_Type__c = 'Secondary Order', Quantity__c = 1, Total_Amount__c = 300)
        };

        Target_Criteria__c crit = new Target_Criteria__c(
            Name = 'Sec Revenue', Object__c = 'Order_Item__c', Operator__c = 'SUM',
            Field__c = 'Total_Amount__c', Date_Field__c = 'Order_Date__c',
            User_Field__c = 'Order_Owner_Id__c', Filters__c = SECONDARY_FILTER, Active__c = true);
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

        Test.startTest();
        List<Secondary_Target__c> list1 = SecondaryTarget_Controller.getTargets('', crit.Id, true);
        System.assertEquals(1, list1.size(), 'one active target for the criteria');

        Secondary_Target__c neu = new Secondary_Target__c(
            User__c = u.Id, Target_Criteria__c = crit.Id, Target_Value__c = 500,
            Is_Active__c = true, Start_Date__c = Date.today(), End_Date__c = Date.today().addDays(10));
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
    static void testRecalculateAll() {
        Test.startTest();
        Id jobId = SecondaryTarget_Controller.recalculateAll();
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'batch enqueued');

        Secondary_Target__c t = [SELECT Achievement_Value__c FROM Secondary_Target__c LIMIT 1];
        System.assertEquals(1000.00, t.Achievement_Value__c, 'batch computed achievement');
    }
}