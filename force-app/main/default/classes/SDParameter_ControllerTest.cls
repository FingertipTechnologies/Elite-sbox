@isTest
private class SDParameter_ControllerTest {

    @testSetup
    static void setup() {
        insert new Focused_Pack__c(Name = 'Test Focus Pack', Sales_Channel__c = firstChannel());
    }

    // First active value of the Chanel global value set used by Focused_Pack__c.Sales_Channel__c.
    private static String firstChannel() {
        for (Schema.PicklistEntry e : Focused_Pack__c.Sales_Channel__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) return e.getValue();
        }
        return null;
    }

    @isTest
    static void testSaveInsertAndUpdate() {
        S_D_Parameter__c param = new S_D_Parameter__c(
            Name = 'Total Volume Achievement',
            Object__c = 'Invoice_item__c',
            Operator__c = 'SUM',
            Field__c = 'Quantity__c',
            User_Field__c = 'OwnerId',
            Is_Mandatory__c = true,
            Is_Active__c = true
        );

        Test.startTest();
        S_D_Parameter__c saved = SDParameter_Controller.save(param);
        System.assertNotEquals(null, saved.Id, 'Insert should return an Id');
        System.assertEquals('SUM', saved.Operator__c);
        System.assertEquals(true, saved.Is_Mandatory__c, 'Mandatory flag should persist');
        System.assertEquals('Total Volume Achievement', saved.External_Id__c,
            'External Id auto-set from Name (no channel)');

        saved.Operator__c = 'COUNT';
        S_D_Parameter__c updated = SDParameter_Controller.save(saved);
        Test.stopTest();

        System.assertEquals('COUNT', updated.Operator__c, 'Update should persist');
        System.assertEquals(saved.Id, updated.Id, 'Upsert should keep the same record');
    }

    @isTest
    static void testBuildSoql() {
        // Account has a self-referential MasterRecord relationship; a filter that picked
        // MasterRecord.Type should be stripped back to Type in the generated SOQL.
        S_D_Parameter__c sumParam = new S_D_Parameter__c(
            Name = 'New Customer Count',
            Object__c = 'Account',
            Operator__c = 'COUNT',
            User_Field__c = 'CreatedById',
            Date_Field__c = 'CreatedDate',
            Filters__c = '{"filters":[{"id":1,"field":"MasterRecord.Type","operator":"=","value":"Prospect","type":"String"}]}',
            Filter_Logic__c = '1'
        );

        Test.startTest();
        String soql = SDParameter_Controller.buildSoql(sumParam);
        String packSoql = SDParameter_Controller.buildSoql(new S_D_Parameter__c(
            Operator__c = 'FOCUS_PACK_REVENUE'
        ));
        S_D_Parameter__c saved = SDParameter_Controller.save(sumParam);
        Test.stopTest();

        System.assert(soql.contains('COUNT(Id)'), 'COUNT aggregate expected: ' + soql);
        System.assert(soql.contains('FROM Account'), 'FROM clause expected');
        System.assert(soql.contains('CreatedDate >= :startDate'), 'period start expected: ' + soql);
        System.assert(soql.contains('CreatedDate <= :endDate'), 'period end expected');
        System.assert(soql.contains('CreatedById IN :userIds'), 'user gate expected');
        System.assert(soql.contains('GROUP BY CreatedById'), 'GROUP BY expected');
        System.assert(soql.contains('(Type ='), 'self-ref prefix should be stripped: ' + soql);
        System.assert(!soql.contains('MasterRecord.Type'), 'MasterRecord prefix should be gone');
        System.assert(packSoql.contains('Select a Focused Pack') || packSoql.contains('Select an Object'),
            'Focus pack without config returns a guidance note: ' + packSoql);
        System.assertNotEquals(null, saved.SOQL_Query__c, 'SOQL stored on save');
    }

    @isTest
    static void testBuildSoqlCountDistinct() {
        // COUNT_DISTINCT aggregates unique values of the chosen Field (e.g. unique Accounts).
        S_D_Parameter__c distinctParam = new S_D_Parameter__c(
            Name = 'Unique Accounts Ordered',
            Object__c = 'Order',
            Operator__c = 'COUNT_DISTINCT',
            Field__c = 'AccountId',
            User_Field__c = 'OwnerId',
            Date_Field__c = 'EffectiveDate'
        );

        Test.startTest();
        String soql = SDParameter_Controller.buildSoql(distinctParam);
        String noFieldNote = SDParameter_Controller.buildSoql(new S_D_Parameter__c(
            Object__c = 'Order', Operator__c = 'COUNT_DISTINCT', User_Field__c = 'OwnerId'
        ));
        Test.stopTest();

        System.assert(soql.contains('COUNT_DISTINCT(AccountId) total'),
            'COUNT_DISTINCT aggregate expected: ' + soql);
        System.assert(soql.contains('GROUP BY OwnerId'), 'GROUP BY expected: ' + soql);
        System.assert(noFieldNote.contains('Select a Field to count distinct'),
            'Missing field returns a guidance note: ' + noFieldNote);
    }

    @isTest
    static void testMultiObjectDistinctConfig() {
        // Two sources (object + customer field); save generates one cust-aliased query per source.
        String config = JSON.serialize(new Map<String, Object>{
            'sources' => new List<Object>{
                new Map<String, Object>{
                    'object' => 'Opportunity', 'customerField' => 'AccountId',
                    'userField' => 'OwnerId', 'dateField' => 'CreatedDate'
                },
                new Map<String, Object>{
                    'object' => 'Case', 'customerField' => 'AccountId',
                    'userField' => 'OwnerId', 'dateField' => 'CreatedDate'
                }
            }
        });
        S_D_Parameter__c p = new S_D_Parameter__c(
            Name = 'Unique Customers', Operator__c = 'MULTI_OBJECT_DISTINCT', Source_Config__c = config
        );

        Test.startTest();
        S_D_Parameter__c saved = SDParameter_Controller.save(p);
        Test.stopTest();

        System.assert(saved.Source_Config__c.contains('AccountId cust'),
            'Each source query selects the customer field as cust: ' + saved.Source_Config__c);
        System.assert(saved.Source_Config__c.contains('GROUP BY OwnerId, AccountId'),
            'Each source groups by user + customer: ' + saved.Source_Config__c);
        System.assert(saved.Source_Config__c.contains('FROM Opportunity')
            && saved.Source_Config__c.contains('FROM Case'), 'Both sources generated');
        System.assert(saved.SOQL_Query__c.contains('Unique customers'),
            'Preview describes the union: ' + saved.SOQL_Query__c);
    }

    @isTest
    static void testBuildSoqlFocusPack() {
        Focused_Pack__c fp = [SELECT Id FROM Focused_Pack__c LIMIT 1];
        S_D_Parameter__c packParam = new S_D_Parameter__c(
            Name = 'Focus Pack 1',
            Object__c = 'Invoice_item__c',
            Operator__c = 'FOCUS_PACK_REVENUE',
            Field__c = 'Amount__c',
            User_Field__c = 'OwnerId',
            Date_Field__c = 'CreatedDate',
            SKU_Field__c = 'Product__c',
            Focused_Pack__c = fp.Id
        );

        Test.startTest();
        String soql = SDParameter_Controller.buildSoql(packParam);
        Test.stopTest();

        System.assert(soql.contains('SUM(Amount__c)'), 'measure SUM expected: ' + soql);
        System.assert(soql.contains('FROM Invoice_item__c'), 'FROM line object expected');
        // Uses the chosen SKU Field (Product__c) matched to the pack's items
        System.assert(
            soql.contains('Product__c IN (SELECT SKU__c FROM Focused_Pack_Item__c WHERE Focused_Pack__c = \'' + fp.Id + '\')'),
            'Focus pack SKU semi-join expected: ' + soql
        );
        System.assert(soql.contains('CreatedDate >= :startDate'), 'period expected');
        System.assert(soql.contains('OwnerId IN :userIds'), 'user gate expected');
        System.assert(soql.contains('GROUP BY OwnerId'), 'GROUP BY expected');
    }

    @isTest
    static void testGetObjectFields() {
        Test.startTest();
        List<TAM_FieldMetadata_Service.FieldInfo> fields = SDParameter_Controller.getObjectFields('Account');
        Test.stopTest();
        System.assert(!fields.isEmpty(), 'Account fields expected');
        for (TAM_FieldMetadata_Service.FieldInfo fi : fields) {
            System.assert(
                !(fi.apiName != null && fi.apiName.toLowerCase().startsWith('masterrecord.')),
                'Self-referential MasterRecord.* fields should be excluded: ' + fi.apiName
            );
        }
    }

    @isTest
    static void testGetParameterAndFocusedPacks() {
        Focused_Pack__c fp = [SELECT Id, Sales_Channel__c FROM Focused_Pack__c LIMIT 1];
        S_D_Parameter__c param = SDParameter_Controller.save(new S_D_Parameter__c(
            Name = 'Focus Pack 1',
            Operator__c = 'FOCUS_PACK_REVENUE',
            Focused_Pack__c = fp.Id,
            Sales_Channel__c = fp.Sales_Channel__c,
            Is_Active__c = true
        ));

        Test.startTest();
        S_D_Parameter__c fetched = SDParameter_Controller.getParameter(param.Id);
        List<Map<String, String>> packs = SDParameter_Controller.getFocusedPacks(fp.Sales_Channel__c);
        List<Map<String, String>> noChannel = SDParameter_Controller.getFocusedPacks(null);
        Test.stopTest();

        System.assertEquals('FOCUS_PACK_REVENUE', fetched.Operator__c);
        System.assertEquals(fp.Id, fetched.Focused_Pack__c);
        System.assert(!packs.isEmpty(), 'Focused packs for the channel should be returned');
        System.assert(noChannel.isEmpty(), 'Blank channel returns no packs (pick a channel first)');
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