@isTest
private class SDParameter_ControllerTest {

    @testSetup
    static void setup() {
        insert new Focused_Pack__c(Name = 'Test Focus Pack');
    }

    @isTest
    static void testSaveInsertAndUpdate() {
        S_D_Parameter__c param = new S_D_Parameter__c(
            Name = 'Total Volume Achievement',
            Object__c = 'Invoice_item__c',
            Operator__c = 'SUM',
            Field__c = 'Quantity__c',
            User_Field__c = 'OwnerId',
            Is_Active__c = true
        );

        Test.startTest();
        S_D_Parameter__c saved = SDParameter_Controller.save(param);
        System.assertNotEquals(null, saved.Id, 'Insert should return an Id');
        System.assertEquals('SUM', saved.Operator__c);

        saved.Operator__c = 'COUNT';
        S_D_Parameter__c updated = SDParameter_Controller.save(saved);
        Test.stopTest();

        System.assertEquals('COUNT', updated.Operator__c, 'Update should persist');
        System.assertEquals(saved.Id, updated.Id, 'Upsert should keep the same record');
    }

    @isTest
    static void testBuildSoql() {
        S_D_Parameter__c sumParam = new S_D_Parameter__c(
            Name = 'Total Revenue Achievement',
            Object__c = 'Invoice__c',
            Operator__c = 'SUM',
            Field__c = 'Amount__c',
            User_Field__c = 'OwnerId',
            Filters__c = '{"filters":[{"id":1,"field":"Status__c","operator":"=","value":"Posted","type":"String"}]}',
            Filter_Logic__c = '1'
        );

        Test.startTest();
        String sumSoql = SDParameter_Controller.buildSoql(sumParam);
        String packSoql = SDParameter_Controller.buildSoql(new S_D_Parameter__c(
            Operator__c = 'FOCUS_PACK_REVENUE'
        ));
        // Persisted on save too
        S_D_Parameter__c saved = SDParameter_Controller.save(sumParam);
        Test.stopTest();

        System.assert(sumSoql.contains('SUM(Amount__c)'), 'SUM aggregate expected: ' + sumSoql);
        System.assert(sumSoql.contains('FROM Invoice__c'), 'FROM clause expected');
        System.assert(sumSoql.contains('GROUP BY OwnerId'), 'GROUP BY expected');
        System.assert(sumSoql.contains('Status__c'), 'Filter condition expected');
        System.assert(packSoql.contains('FOCUS_PACK_REVENUE'), 'Focus pack note expected');
        System.assertNotEquals(null, saved.SOQL_Query__c, 'SOQL stored on save');
    }

    @isTest
    static void testGetParameterAndFocusedPacks() {
        Focused_Pack__c fp = [SELECT Id FROM Focused_Pack__c LIMIT 1];
        S_D_Parameter__c param = SDParameter_Controller.save(new S_D_Parameter__c(
            Name = 'Focus Pack 1',
            Operator__c = 'FOCUS_PACK_REVENUE',
            Focused_Pack__c = fp.Id,
            Sales_Channel__c = null,
            Is_Active__c = true
        ));

        Test.startTest();
        S_D_Parameter__c fetched = SDParameter_Controller.getParameter(param.Id);
        List<Map<String, String>> packs = SDParameter_Controller.getFocusedPacks();
        Test.stopTest();

        System.assertEquals('FOCUS_PACK_REVENUE', fetched.Operator__c);
        System.assertEquals(fp.Id, fetched.Focused_Pack__c);
        System.assert(!packs.isEmpty(), 'Focused pack options should be returned');
    }

    @isTest
    static void testSaveNullThrows() {
        Test.startTest();
        try {
            SDParameter_Controller.save(null);
            System.assert(false, 'Expected an exception for null input');
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}
