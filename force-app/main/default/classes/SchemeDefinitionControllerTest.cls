@isTest
private class SchemeDefinitionControllerTest {

    private static final String CHANNEL = 'Cake';
    private static final String TYPE_FREE_QTY     = 'Free Quantity';
    private static final String TYPE_QPS          = 'QPS';
    private static final String TYPE_FOC_GIVEAWAY = 'FOC Giveaway';
    private static final String TYPE_ORDER_VALUE  = 'Order Value';
    private static final String TYPE_CATEGORY     = 'Category Value';

    private static String resolvePurpose(String token) {
        String norm = token.toLowerCase().replaceAll('[\\s_\\-]', '');
        for (Schema.PicklistEntry e :
                Scheme_Product_Group__c.Group_Purpose__c.getDescribe().getPicklistValues()) {
            if (!e.isActive()) continue;
            String v = e.getValue().toLowerCase().replaceAll('[\\s_\\-]', '');
            if (v == norm) return e.getValue();
        }
        return null;
    }

    private static Scheme_Product_Group__c makeGroup(String name, String purposeToken) {
        String purpose = resolvePurpose(purposeToken);
        Scheme_Product_Group__c g = new Scheme_Product_Group__c(
            Name = name,
            Sales_Channel__c = CHANNEL,
            Group_Purpose__c = purpose,
            Is_Active__c = true
        );
        insert g;
        return g;
    }

    private static Product__c makeProduct(String name) {
        Product__c p = new Product__c(
            Name = name,
            Is_Active__c = true,
            Channel__c = CHANNEL,
            SKU_Code__c = name
        );
        insert p;
        return p;
    }

    private static SchemeDefinitionController.MasterDto masterFor(String schemeType, Id groupId) {
        SchemeDefinitionController.MasterDto m = new SchemeDefinitionController.MasterDto();
        m.name           = 'Test ' + schemeType + ' ' + System.now().getTime();
        m.schemeType     = schemeType;
        m.salesChannel   = CHANNEL;
        m.startDate      = Date.today();
        m.endDate        = Date.today().addDays(30);
        m.description    = 'unit test';
        m.productGroupId = groupId;
        return m;
    }

    private static SchemeDefinitionController.SlabDto slab() {
        return new SchemeDefinitionController.SlabDto();
    }

    @isTest
    static void getPicklists_returnsActiveValues() {
        Test.startTest();
        SchemeDefinitionController.WizardPicklists p = SchemeDefinitionController.getPicklists();
        Test.stopTest();
        System.assertNotEquals(null, p, 'picklists wrapper');
        System.assertNotEquals(null, p.salesChannels, 'salesChannels');
        System.assertNotEquals(null, p.schemeTypes, 'schemeTypes');
        System.assertNotEquals(null, p.productCategories, 'productCategories');
    }

    @isTest
    static void saveSchemeWithSlabs_insertFreeQtyCycleCreatesSchemeAndSlab() {
        Scheme_Product_Group__c g = makeGroup('FQ Group', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_FREE_QTY, g.Id);
        SchemeDefinitionController.SlabDto s = slab();
        s.qtyMin = 11; s.qtyMax = null; s.freeQty = 1;

        Test.startTest();
        Id id = SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s }, null);
        Test.stopTest();

        Scheme__c saved = [SELECT Id, Name, Scheme_Type__c, Sales_Channel__c FROM Scheme__c WHERE Id = :id];
        System.assertEquals(TYPE_FREE_QTY, saved.Scheme_Type__c);
        List<Scheme_Slab__c> slabs = [SELECT Id, Qualifying_Qty_Min__c, Qualifying_Qty_Max__c, Free_Qty__c, Slab_Sequence__c FROM Scheme_Slab__c WHERE Scheme__c = :id];
        System.assertEquals(1, slabs.size());
        System.assertEquals(11, slabs[0].Qualifying_Qty_Min__c);
        System.assertEquals(null, slabs[0].Qualifying_Qty_Max__c);
        System.assertEquals(1, slabs[0].Free_Qty__c);
        System.assertEquals(1, slabs[0].Slab_Sequence__c);
    }

    @isTest
    static void saveSchemeWithSlabs_insertQpsMultiSlab() {
        Scheme_Product_Group__c g = makeGroup('QPS Group', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s1 = slab(); s1.qtyMin = 3; s1.benefitPerEa = 40;
        SchemeDefinitionController.SlabDto s2 = slab(); s2.qtyMin = 5; s2.benefitPerEa = 80;

        Test.startTest();
        Id id = SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s1, s2 }, null);
        Test.stopTest();

        List<Scheme_Slab__c> slabs = [SELECT Slab_Sequence__c, Qualifying_Qty_Min__c, Benefit_Amount_Per_EA__c FROM Scheme_Slab__c WHERE Scheme__c = :id ORDER BY Slab_Sequence__c];
        System.assertEquals(2, slabs.size());
        System.assertEquals(1, slabs[0].Slab_Sequence__c);
        System.assertEquals(2, slabs[1].Slab_Sequence__c);
        System.assertEquals(80, slabs[1].Benefit_Amount_Per_EA__c);
    }

    @isTest
    static void saveSchemeWithSlabs_updateReplacesSlabs() {
        Scheme_Product_Group__c g = makeGroup('Update Group', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s = slab(); s.qtyMin = 3; s.benefitPerEa = 40;
        Id id = SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s }, null);

        Test.startTest();
        SchemeDefinitionController.SlabDto s2 = slab(); s2.qtyMin = 5; s2.benefitPerEa = 80;
        SchemeDefinitionController.SlabDto s3 = slab(); s3.qtyMin = 10; s3.benefitPerEa = 120;
        Id id2 = SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s2, s3 }, id);
        Test.stopTest();

        System.assertEquals(id, id2, 'same record');
        List<Scheme_Slab__c> slabs = [SELECT Slab_Sequence__c, Qualifying_Qty_Min__c FROM Scheme_Slab__c WHERE Scheme__c = :id ORDER BY Slab_Sequence__c];
        System.assertEquals(2, slabs.size());
        System.assertEquals(5, slabs[0].Qualifying_Qty_Min__c);
    }

    @isTest
    static void loadScheme_returnsMasterAndSlabsInOrder() {
        Scheme_Product_Group__c g = makeGroup('Load Group', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s1 = slab(); s1.qtyMin = 3; s1.benefitPerEa = 40;
        SchemeDefinitionController.SlabDto s2 = slab(); s2.qtyMin = 5; s2.benefitPerEa = 80;
        Id id = SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s1, s2 }, null);

        Test.startTest();
        SchemeDefinitionController.LoadSchemeResult r = SchemeDefinitionController.loadScheme(id);
        Test.stopTest();

        System.assertEquals(id, r.id);
        System.assertEquals(TYPE_QPS, r.master.schemeType);
        System.assertEquals(2, r.slabs.size());
        System.assertEquals(1, r.slabs[0].sequence);
        System.assertEquals(2, r.slabs[1].sequence);
    }

    @isTest
    static void loadScheme_nullReturnsNull() {
        Test.startTest();
        SchemeDefinitionController.LoadSchemeResult r = SchemeDefinitionController.loadScheme(null);
        Test.stopTest();
        System.assertEquals(null, r);
    }

    @isTest
    static void searchProductGroups_filtersByChannelAndPurpose() {
        Scheme_Product_Group__c match    = makeGroup('Search Match', 'PriceDivision');
        Scheme_Product_Group__c wrongPurp = makeGroup('Search Foc', 'FOCQualifier');

        Test.startTest();
        List<SchemeDefinitionController.ProductGroupRow> rows =
            SchemeDefinitionController.searchProductGroups(CHANNEL, 'PriceDivision', 'Search', null);
        Test.stopTest();

        Set<Id> ids = new Set<Id>();
        for (SchemeDefinitionController.ProductGroupRow r : rows) ids.add(r.id);
        System.assert(ids.contains(match.Id), 'price-division match included');
        System.assert(!ids.contains(wrongPurp.Id), 'foc purpose excluded');
    }

    @isTest
    static void saveSchemeWithSlabs_rollbackOnEndBeforeStart() {
        Scheme_Product_Group__c g = makeGroup('Bad Date Group', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        m.endDate = m.startDate.addDays(-1);
        SchemeDefinitionController.SlabDto s = slab(); s.qtyMin = 3; s.benefitPerEa = 40;

        Boolean threw = false;
        Test.startTest();
        try {
            SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s }, null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'expected validation error');
    }

    @isTest
    static void saveSchemeWithSlabs_rollbackOnFocRowMissingProduct() {
        Scheme_Product_Group__c g = makeGroup('FOC Group', 'FOCQualifier');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_FOC_GIVEAWAY, g.Id);
        SchemeDefinitionController.SlabDto s = slab(); s.qtyMin = 1000; s.freeQty = 1; s.focProductId = null;

        Boolean threw = false;
        Test.startTest();
        try {
            SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s }, null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'expected FOC product required error');
    }

    @isTest
    static void saveSchemeWithSlabs_rollbackOnOverlappingQtyRangesQps() {
        Scheme_Product_Group__c g = makeGroup('QPS Overlap', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s1 = slab(); s1.qtyMin = 3;  s1.qtyMax = 10; s1.benefitPerEa = 40;
        SchemeDefinitionController.SlabDto s2 = slab(); s2.qtyMin = 8;  s2.qtyMax = 20; s2.benefitPerEa = 80;

        Boolean threw = false;
        Test.startTest();
        try {
            SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s1, s2 }, null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'expected qty overlap error');
    }

    @isTest
    static void saveSchemeWithSlabs_qpsPersistsMaxQty() {
        Scheme_Product_Group__c g = makeGroup('QPS Max', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s1 = slab(); s1.qtyMin = 3; s1.qtyMax = 4;  s1.benefitPerEa = 40;
        SchemeDefinitionController.SlabDto s2 = slab(); s2.qtyMin = 5; s2.qtyMax = 10; s2.benefitPerEa = 80;

        Test.startTest();
        Id id = SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s1, s2 }, null);
        Test.stopTest();

        List<Scheme_Slab__c> slabs = [SELECT Qualifying_Qty_Min__c, Qualifying_Qty_Max__c FROM Scheme_Slab__c WHERE Scheme__c = :id ORDER BY Slab_Sequence__c];
        System.assertEquals(2, slabs.size());
        System.assertEquals(4, slabs[0].Qualifying_Qty_Max__c);
        System.assertEquals(10, slabs[1].Qualifying_Qty_Max__c);
    }

    @isTest
    static void saveSchemeWithSlabs_rollbackOnOverlappingValueRanges() {
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_ORDER_VALUE, null);
        SchemeDefinitionController.SlabDto s1 = slab(); s1.valueMin = 5000;  s1.valueMax = 20000; s1.benefitPercent = 5;
        SchemeDefinitionController.SlabDto s2 = slab(); s2.valueMin = 15000; s2.valueMax = 30000; s2.benefitPercent = 7;

        Boolean threw = false;
        Test.startTest();
        try {
            SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s1, s2 }, null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'expected overlap error');
    }

    @isTest
    static void saveSchemeWithSlabs_rollbackOnProductGroupChannelMismatch() {
        Scheme_Product_Group__c g = new Scheme_Product_Group__c(
            Name = 'WrongChannel',
            Sales_Channel__c = 'Plum',
            Group_Purpose__c = resolvePurpose('PriceDivision'),
            Is_Active__c = true
        );
        insert g;
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s = slab(); s.qtyMin = 3; s.benefitPerEa = 40;

        Boolean threw = false;
        Test.startTest();
        try {
            SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s }, null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'expected channel mismatch error');
    }

    @isTest
    static void saveSchemeWithSlabs_categoryRequiresCategoryValue() {
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_CATEGORY, null);
        m.productCategory = null;
        SchemeDefinitionController.SlabDto s = slab(); s.valueMin = 50000; s.valueMax = 100000; s.benefitPercent = 1;

        Boolean threw = false;
        Test.startTest();
        try {
            SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s }, null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'expected category required error');
    }

    @isTest
    static void saveSchemeWithSlabs_noSlabsThrows() {
        Scheme_Product_Group__c g = makeGroup('NoSlab Group', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);

        Boolean threw = false;
        Test.startTest();
        try {
            SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>(), null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'expected at-least-one-slab error');
    }

    @isTest
    static void saveSchemeWithSlabs_rollbackOnDuplicateOpenTopFreeQty() {
        Scheme_Product_Group__c g = makeGroup('FQ DupOpenTop', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_FREE_QTY, g.Id);
        SchemeDefinitionController.SlabDto s1 = slab(); s1.qtyMin = 11; s1.qtyMax = null; s1.freeQty = 1;
        SchemeDefinitionController.SlabDto s2 = slab(); s2.qtyMin = 11; s2.qtyMax = null; s2.freeQty = 2;

        Boolean threw = false;
        Test.startTest();
        try {
            SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s1, s2 }, null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'expected duplicate open-top rejection');
    }

    @isTest
    static void saveSchemeWithSlabs_rollbackOnDuplicateMinQpsClosedBands() {
        Scheme_Product_Group__c g = makeGroup('QPS DupMin', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s1 = slab(); s1.qtyMin = 3; s1.qtyMax = 10; s1.benefitPerEa = 40;
        SchemeDefinitionController.SlabDto s2 = slab(); s2.qtyMin = 3; s2.qtyMax = 12; s2.benefitPerEa = 80;

        Boolean threw = false;
        Test.startTest();
        try {
            SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s1, s2 }, null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'expected duplicate Min Qty rejection');
    }

    @isTest
    static void saveSchemeWithSlabs_rejectsPastStartDateOnInsert() {
        Scheme_Product_Group__c g = makeGroup('PastStart', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        m.startDate = Date.today().addDays(-1);
        m.endDate   = Date.today().addDays(10);
        SchemeDefinitionController.SlabDto s = slab(); s.qtyMin = 3; s.benefitPerEa = 40;

        Boolean threw = false;
        Test.startTest();
        try {
            SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s }, null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'expected past start date rejection');
    }

    @isTest
    static void saveSchemeWithSlabs_rejectsPastEndDateOnInsert() {
        Scheme_Product_Group__c g = makeGroup('PastEnd', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        m.startDate = Date.today().addDays(-30);
        m.endDate   = Date.today().addDays(-1);
        SchemeDefinitionController.SlabDto s = slab(); s.qtyMin = 3; s.benefitPerEa = 40;

        Boolean threw = false;
        Test.startTest();
        try {
            SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s }, null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'expected past end date rejection');
    }

    @isTest
    static void saveSchemeWithSlabs_allowsUnchangedPastStartDateOnUpdate() {
        Scheme_Product_Group__c g = makeGroup('PastStartUpdate', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s = slab(); s.qtyMin = 3; s.benefitPerEa = 40;
        Id id = SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s }, null);

        update new Scheme__c(Id = id, Scheme_Start_Date__c = Date.today().addDays(-5));

        SchemeDefinitionController.MasterDto m2 = masterFor(TYPE_QPS, g.Id);
        m2.startDate = Date.today().addDays(-5);
        m2.endDate   = Date.today().addDays(30);
        SchemeDefinitionController.SlabDto s2 = slab(); s2.qtyMin = 3; s2.benefitPerEa = 50;

        Test.startTest();
        Id id2 = SchemeDefinitionController.saveSchemeWithSlabs(m2, new List<SchemeDefinitionController.SlabDto>{ s2 }, id);
        Test.stopTest();

        System.assertEquals(id, id2);
    }

    @isTest
    static void saveSchemeWithSlabs_rejectsLoweringStartDateBelowToday() {
        Scheme_Product_Group__c g = makeGroup('LowerStart', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s = slab(); s.qtyMin = 3; s.benefitPerEa = 40;
        Id id = SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s }, null);

        SchemeDefinitionController.MasterDto m2 = masterFor(TYPE_QPS, g.Id);
        m2.startDate = Date.today().addDays(-2);
        m2.endDate   = Date.today().addDays(30);
        SchemeDefinitionController.SlabDto s2 = slab(); s2.qtyMin = 3; s2.benefitPerEa = 50;

        Boolean threw = false;
        Test.startTest();
        try {
            SchemeDefinitionController.saveSchemeWithSlabs(m2, new List<SchemeDefinitionController.SlabDto>{ s2 }, id);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'expected past start date rejection on update');
    }

    @isTest
    static void saveSchemeWithSlabs_persistsIsActiveToggle() {
        Scheme_Product_Group__c g = makeGroup('Active Toggle', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        m.isActive = false;
        SchemeDefinitionController.SlabDto s = slab(); s.qtyMin = 3; s.benefitPerEa = 40;

        Test.startTest();
        Id id = SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s }, null);
        Test.stopTest();

        Scheme__c saved = [SELECT IsActive__c FROM Scheme__c WHERE Id = :id];
        System.assertEquals(false, saved.IsActive__c);
    }
}
