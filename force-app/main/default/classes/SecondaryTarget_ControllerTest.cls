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
        List<Secondary_Target__c> list1 = SecondaryTarget_Controller.getTargets('', crit.Id, true, null);
        System.assertEquals(1, list1.size(), 'one active target for the criteria');

        // Filter by User__c should also narrow correctly.
        List<Secondary_Target__c> list2 = SecondaryTarget_Controller.getTargets('', crit.Id, true, u.Id);
        System.assertEquals(1, list2.size(), 'user filter matches the seeded target');
        System.assertEquals(0,
            SecondaryTarget_Controller.getTargets('', crit.Id, true, UserInfo.getUserId()).size(),
            'a different user should return no rows');

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
        Secondary_Target__c orig = [SELECT Id, User__c, Target_Criteria__c, Target_Value__c,
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
}