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

    private static String anyProductCategory() {
        for (Schema.PicklistEntry e :
                Scheme__c.Scheme_Product_Category__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) return e.getValue();
        }
        return null;
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
    static void saveSchemeWithSlabs_rejectsOpenTopInMiddleOfValueSlabs() {
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_ORDER_VALUE, null);
        SchemeDefinitionController.SlabDto s1 = slab(); s1.valueMin = 10000; s1.valueMax = 20000; s1.benefitPercent = 1;
        SchemeDefinitionController.SlabDto s2 = slab(); s2.valueMin = 21000; s2.valueMax = null;  s2.benefitPercent = 2;
        SchemeDefinitionController.SlabDto s3 = slab(); s3.valueMin = 30000; s3.valueMax = 350000; s3.benefitPercent = 3;

        Boolean threw = false;
        Test.startTest();
        try {
            SchemeDefinitionController.saveSchemeWithSlabs(
                m, new List<SchemeDefinitionController.SlabDto>{ s1, s2, s3 }, null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'expected open-top-in-middle rejection');
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
    static void validateActiveDuplicate_blocksSecondActiveSameTypeGroupOverlappingDates() {
        Scheme_Product_Group__c g = makeGroup('DupBlock', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s = slab(); s.qtyMin = 3; s.benefitPerEa = 40;
        SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s }, null);

        SchemeDefinitionController.MasterDto m2 = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s2 = slab(); s2.qtyMin = 3; s2.benefitPerEa = 50;

        Boolean threw = false;
        Test.startTest();
        try {
            SchemeDefinitionController.saveSchemeWithSlabs(m2, new List<SchemeDefinitionController.SlabDto>{ s2 }, null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'expected duplicate active scheme rejection for overlapping dates');
    }

    @isTest
    static void validateActiveDuplicate_allowsNonOverlappingDates() {
        Scheme_Product_Group__c g = makeGroup('DupNonOverlap', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s = slab(); s.qtyMin = 3; s.benefitPerEa = 40;
        SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s }, null);

        SchemeDefinitionController.MasterDto m2 = masterFor(TYPE_QPS, g.Id);
        m2.startDate = Date.today().addDays(31);
        m2.endDate   = Date.today().addDays(60);
        SchemeDefinitionController.SlabDto s2 = slab(); s2.qtyMin = 3; s2.benefitPerEa = 50;

        Test.startTest();
        Id id2 = SchemeDefinitionController.saveSchemeWithSlabs(m2, new List<SchemeDefinitionController.SlabDto>{ s2 }, null);
        Test.stopTest();
        System.assertNotEquals(null, id2, 'non-overlapping active scheme should be allowed');
    }

    @isTest
    static void validateActiveDuplicate_allowsWhenExistingIsInactive() {
        Scheme_Product_Group__c g = makeGroup('DupInactive', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        m.isActive = false;
        SchemeDefinitionController.SlabDto s = slab(); s.qtyMin = 3; s.benefitPerEa = 40;
        SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s }, null);

        SchemeDefinitionController.MasterDto m2 = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s2 = slab(); s2.qtyMin = 3; s2.benefitPerEa = 50;

        Test.startTest();
        Id id2 = SchemeDefinitionController.saveSchemeWithSlabs(m2, new List<SchemeDefinitionController.SlabDto>{ s2 }, null);
        Test.stopTest();
        System.assertNotEquals(null, id2, 'active scheme should be allowed when existing one is inactive');
    }

    @isTest
    static void validateActiveDuplicate_blocksReactivatingOldWhenNewActiveOverlaps() {
        Scheme_Product_Group__c g = makeGroup('DupReactivate', 'PriceDivision');
        SchemeDefinitionController.MasterDto mA = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto sA = slab(); sA.qtyMin = 3; sA.benefitPerEa = 40;
        Id idA = SchemeDefinitionController.saveSchemeWithSlabs(mA, new List<SchemeDefinitionController.SlabDto>{ sA }, null);

        // Deactivate A so a new active overlapping scheme can be created.
        update new Scheme__c(Id = idA, IsActive__c = false);

        SchemeDefinitionController.MasterDto mB = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto sB = slab(); sB.qtyMin = 3; sB.benefitPerEa = 50;
        SchemeDefinitionController.saveSchemeWithSlabs(mB, new List<SchemeDefinitionController.SlabDto>{ sB }, null);

        // Try to re-activate A while active overlapping B exists.
        SchemeDefinitionController.MasterDto mA2 = masterFor(TYPE_QPS, g.Id);
        mA2.isActive = true;
        SchemeDefinitionController.SlabDto sA2 = slab(); sA2.qtyMin = 3; sA2.benefitPerEa = 40;

        Boolean threw = false;
        Test.startTest();
        try {
            SchemeDefinitionController.saveSchemeWithSlabs(mA2, new List<SchemeDefinitionController.SlabDto>{ sA2 }, idA);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'expected rejection when re-activating old scheme while new active overlapping one exists');
    }

    @isTest
    static void validateActiveDuplicate_allowsResavingSameActiveRecord() {
        Scheme_Product_Group__c g = makeGroup('DupSelfResave', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s = slab(); s.qtyMin = 3; s.benefitPerEa = 40;
        Id id = SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s }, null);

        SchemeDefinitionController.MasterDto m2 = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s2 = slab(); s2.qtyMin = 3; s2.benefitPerEa = 45;

        Test.startTest();
        Id id2 = SchemeDefinitionController.saveSchemeWithSlabs(m2, new List<SchemeDefinitionController.SlabDto>{ s2 }, id);
        Test.stopTest();
        System.assertEquals(id, id2, 're-saving the same active record should be allowed (self excluded)');
    }

    @isTest
    static void validateActiveDuplicate_blocksCategoryValueSameCategoryChannelOverlap() {
        String cat = anyProductCategory();
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_CATEGORY, null);
        m.productCategory = cat;
        SchemeDefinitionController.SlabDto s = slab(); s.valueMin = 5000; s.benefitPercent = 5;
        SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s }, null);

        SchemeDefinitionController.MasterDto m2 = masterFor(TYPE_CATEGORY, null);
        m2.productCategory = cat;
        SchemeDefinitionController.SlabDto s2 = slab(); s2.valueMin = 5000; s2.benefitPercent = 6;

        Boolean threw = false;
        Test.startTest();
        try {
            SchemeDefinitionController.saveSchemeWithSlabs(m2, new List<SchemeDefinitionController.SlabDto>{ s2 }, null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'expected duplicate rejection for same category, channel and overlapping dates');
    }

    @isTest
    static void validateActiveDuplicate_allowsCategoryValueDifferentChannel() {
        String cat = anyProductCategory();
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_CATEGORY, null);
        m.productCategory = cat;
        SchemeDefinitionController.SlabDto s = slab(); s.valueMin = 5000; s.benefitPercent = 5;
        SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s }, null);

        SchemeDefinitionController.MasterDto m2 = masterFor(TYPE_CATEGORY, null);
        m2.productCategory = cat;
        m2.salesChannel = 'Plum';
        SchemeDefinitionController.SlabDto s2 = slab(); s2.valueMin = 5000; s2.benefitPercent = 6;

        Test.startTest();
        Id id2 = SchemeDefinitionController.saveSchemeWithSlabs(m2, new List<SchemeDefinitionController.SlabDto>{ s2 }, null);
        Test.stopTest();
        System.assertNotEquals(null, id2, 'category scheme on a different channel should be allowed');
    }

    @isTest
    static void validateActiveDuplicate_blocksOrderValueSameChannelOverlap() {
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_ORDER_VALUE, null);
        SchemeDefinitionController.SlabDto s = slab(); s.valueMin = 5000; s.benefitPercent = 5;
        SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s }, null);

        SchemeDefinitionController.MasterDto m2 = masterFor(TYPE_ORDER_VALUE, null);
        SchemeDefinitionController.SlabDto s2 = slab(); s2.valueMin = 5000; s2.benefitPercent = 6;

        Boolean threw = false;
        Test.startTest();
        try {
            SchemeDefinitionController.saveSchemeWithSlabs(m2, new List<SchemeDefinitionController.SlabDto>{ s2 }, null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'expected duplicate rejection for same channel and overlapping dates');
    }

    @isTest
    static void validateActiveDuplicate_allowsOrderValueDifferentChannel() {
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_ORDER_VALUE, null);
        SchemeDefinitionController.SlabDto s = slab(); s.valueMin = 5000; s.benefitPercent = 5;
        SchemeDefinitionController.saveSchemeWithSlabs(m, new List<SchemeDefinitionController.SlabDto>{ s }, null);

        SchemeDefinitionController.MasterDto m2 = masterFor(TYPE_ORDER_VALUE, null);
        m2.salesChannel = 'Plum';
        SchemeDefinitionController.SlabDto s2 = slab(); s2.valueMin = 5000; s2.benefitPercent = 6;

        Test.startTest();
        Id id2 = SchemeDefinitionController.saveSchemeWithSlabs(m2, new List<SchemeDefinitionController.SlabDto>{ s2 }, null);
        Test.stopTest();
        System.assertNotEquals(null, id2, 'order value scheme on a different channel should be allowed');
    }

    private static Area__c makeTerritory(String name, String region, String area) {
        Area__c t = new Area__c(
            Name = name,
            Region__c = region,
            Area__c = area,
            Sales_Channel__c = CHANNEL
        );
        insert t;
        return t;
    }

    private static SchemeDefinitionController.LevelStateDto level(Boolean applyToAll, List<String> values) {
        SchemeDefinitionController.LevelStateDto st = new SchemeDefinitionController.LevelStateDto();
        st.applyToAll = applyToAll;
        st.values = values == null ? new List<String>() : values;
        return st;
    }

    private static SchemeDefinitionController.ApplicabilityDto allApplyToAll() {
        SchemeDefinitionController.ApplicabilityDto a = new SchemeDefinitionController.ApplicabilityDto();
        a.regions          = level(true, null);
        a.areas            = level(true, null);
        a.territories      = level(true, null);
        a.outletCategories = level(true, null);
        return a;
    }

    @isTest
    static void saveSchemeWithApplicability_allApplyToAll_writesBooleansNoJunction() {
        Scheme_Product_Group__c g = makeGroup('Appl All', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s = slab(); s.qtyMin = 3; s.benefitPerEa = 40;

        Test.startTest();
        Id id = SchemeDefinitionController.saveSchemeWithApplicability(
            m, new List<SchemeDefinitionController.SlabDto>{ s }, allApplyToAll(), null);
        Test.stopTest();

        Scheme__c sv = [SELECT Apply_to_All_Regions__c, Apply_to_All_Areas__c,
                               Apply_to_All_Territories__c, Apply_to_All_Outlet_Categories__c,
                               Applicability_Summary__c
                        FROM Scheme__c WHERE Id = :id];
        System.assert(sv.Apply_to_All_Regions__c);
        System.assert(sv.Apply_to_All_Areas__c);
        System.assert(sv.Apply_to_All_Territories__c);
        System.assert(sv.Apply_to_All_Outlet_Categories__c);
        Integer rows = [SELECT COUNT() FROM Scheme_Applicability__c WHERE Scheme__c = :id];
        System.assertEquals(0, rows, 'no junction rows when all levels Apply to All');
        System.assert(sv.Applicability_Summary__c.contains('Regions: All'));
    }

    @isTest
    static void saveSchemeWithApplicability_specificValues_writesJunctionRows() {
        Scheme_Product_Group__c g = makeGroup('Appl Specific', 'PriceDivision');
        Area__c t1 = makeTerritory('T-KA-1', 'KA', 'North');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s = slab(); s.qtyMin = 3; s.benefitPerEa = 40;

        SchemeDefinitionController.ApplicabilityDto a = new SchemeDefinitionController.ApplicabilityDto();
        a.regions          = level(false, new List<String>{ 'KA' });
        a.areas            = level(false, new List<String>{ 'North' });
        a.territories      = level(false, new List<String>{ String.valueOf(t1.Id) });
        a.outletCategories = level(true, null);

        Test.startTest();
        Id id = SchemeDefinitionController.saveSchemeWithApplicability(
            m, new List<SchemeDefinitionController.SlabDto>{ s }, a, null);
        Test.stopTest();

        Map<String, Integer> byLevel = new Map<String, Integer>();
        for (Scheme_Applicability__c r : [
                SELECT Level__c FROM Scheme_Applicability__c WHERE Scheme__c = :id]) {
            byLevel.put(r.Level__c, (byLevel.containsKey(r.Level__c) ? byLevel.get(r.Level__c) : 0) + 1);
        }
        System.assertEquals(1, byLevel.get('Region'));
        System.assertEquals(1, byLevel.get('Area'));
        System.assertEquals(1, byLevel.get('Territory'));
        System.assert(!byLevel.containsKey('Outlet Category'),
            'Outlet Category should have no junction when Apply to All');
    }

    @isTest
    static void saveSchemeWithApplicability_rejectsEmptyLevelWithoutApplyToAll() {
        Scheme_Product_Group__c g = makeGroup('Appl Empty', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s = slab(); s.qtyMin = 3; s.benefitPerEa = 40;

        SchemeDefinitionController.ApplicabilityDto a = allApplyToAll();
        a.regions = level(false, new List<String>());

        Boolean threw = false;
        Test.startTest();
        try {
            SchemeDefinitionController.saveSchemeWithApplicability(
                m, new List<SchemeDefinitionController.SlabDto>{ s }, a, null);
        } catch (AuraHandledException ex) { threw = true; }
        Test.stopTest();
        System.assert(threw, 'expected empty level rejection');
    }

    @isTest
    static void saveSchemeWithApplicability_updateReplacesJunctionRows() {
        Scheme_Product_Group__c g = makeGroup('Appl Update', 'PriceDivision');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s = slab(); s.qtyMin = 3; s.benefitPerEa = 40;

        SchemeDefinitionController.ApplicabilityDto a1 = allApplyToAll();
        a1.regions = level(false, new List<String>{ 'KA', 'TN' });
        Id id = SchemeDefinitionController.saveSchemeWithApplicability(
            m, new List<SchemeDefinitionController.SlabDto>{ s }, a1, null);
        System.assertEquals(2,
            [SELECT COUNT() FROM Scheme_Applicability__c WHERE Scheme__c = :id AND Level__c = 'Region']);

        SchemeDefinitionController.ApplicabilityDto a2 = allApplyToAll();
        a2.regions = level(false, new List<String>{ 'KA' });

        Test.startTest();
        SchemeDefinitionController.saveSchemeWithApplicability(
            masterFor(TYPE_QPS, g.Id), new List<SchemeDefinitionController.SlabDto>{ s }, a2, id);
        Test.stopTest();

        List<Scheme_Applicability__c> rows = [
            SELECT Level__c, Value_Text__c FROM Scheme_Applicability__c WHERE Scheme__c = :id];
        System.assertEquals(1, rows.size());
        System.assertEquals('Region', rows[0].Level__c);
        System.assertEquals('KA', rows[0].Value_Text__c);
    }

    @isTest
    static void loadScheme_rehydratesApplicability() {
        Scheme_Product_Group__c g = makeGroup('Appl Rehydrate', 'PriceDivision');
        Area__c t1 = makeTerritory('T-KA-East', 'KA', 'North');
        SchemeDefinitionController.MasterDto m = masterFor(TYPE_QPS, g.Id);
        SchemeDefinitionController.SlabDto s = slab(); s.qtyMin = 3; s.benefitPerEa = 40;

        SchemeDefinitionController.ApplicabilityDto a = allApplyToAll();
        a.regions          = level(false, new List<String>{ 'KA' });
        a.territories      = level(false, new List<String>{ String.valueOf(t1.Id) });
        Id id = SchemeDefinitionController.saveSchemeWithApplicability(
            m, new List<SchemeDefinitionController.SlabDto>{ s }, a, null);

        Test.startTest();
        SchemeDefinitionController.LoadSchemeResult result = SchemeDefinitionController.loadScheme(id);
        Test.stopTest();

        System.assertNotEquals(null, result.applicability);
        System.assertEquals(false, result.applicability.regions.applyToAll);
        System.assertEquals(1, result.applicability.regions.values.size());
        System.assertEquals('KA', result.applicability.regions.values[0]);
        System.assertEquals(true, result.applicability.areas.applyToAll);
        System.assertEquals(1, result.savedTerritoryOptions.size());
        System.assertEquals('T-KA-East', result.savedTerritoryOptions[0].name);
    }

    @isTest
    static void getApplicabilityOptions_filtersByChannelRegionArea() {
        makeTerritory('T-KA-1', 'KA', 'North');
        makeTerritory('T-KA-2', 'KA', 'Central');
        makeTerritory('T-TN-1', 'TN', 'North');

        Test.startTest();
        SchemeDefinitionController.ApplicabilityOptions all =
            SchemeDefinitionController.getApplicabilityOptions(CHANNEL, null, null);
        SchemeDefinitionController.ApplicabilityOptions kaOnly =
            SchemeDefinitionController.getApplicabilityOptions(CHANNEL, new List<String>{ 'KA' }, null);
        SchemeDefinitionController.ApplicabilityOptions kaNorth =
            SchemeDefinitionController.getApplicabilityOptions(CHANNEL, new List<String>{ 'KA' }, new List<String>{ 'North' });
        Test.stopTest();

        System.assertEquals(2, all.regions.size(), 'two distinct regions');
        System.assertEquals(3, all.territories.size());
        System.assertEquals(2, kaOnly.territories.size());
        System.assertEquals(1, kaNorth.territories.size());
        System.assertEquals('T-KA-1', kaNorth.territories[0].name);
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