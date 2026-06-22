@isTest
private class SchemeProductGroupControllerTest {

    private static final String CHANNEL = 'Cake';

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

    // First active Group Purpose that is NOT Price Division (e.g. FOC Qualifier), or null.
    private static String nonPriceDivisionPurpose() {
        for (Schema.PicklistEntry e :
                Scheme_Product_Group__c.Group_Purpose__c.getDescribe().getPicklistValues()) {
            if (!e.isActive()) continue;
            String v = e.getValue().toLowerCase().replaceAll('[\\s_\\-]', '');
            if (v != 'pricedivision') return e.getValue();
        }
        return null;
    }

    private static Product__c makeProduct(String name) {
        return makeProduct(name, null, null);
    }

    private static Product__c makeProduct(String name, Decimal mrp, Decimal weight) {
        Product__c p = new Product__c(
            Name = name,
            Is_Active__c = true,
            Channel__c = CHANNEL,
            SKU_Code__c = name,
            MRP__c = mrp,
            Net_Weight__c = weight
        );
        insert p;
        return p;
    }

    private static Sales_Channel_To_SKU__c linkSku(Id productId, String channel) {
        Sales_Channel_To_SKU__c link = new Sales_Channel_To_SKU__c(
            Sales_Channel__c = channel,
            SKU__c = productId
        );
        insert link;
        return link;
    }

    // Active group containing the product (direct DML — bypasses saveGroup validations).
    private static Scheme_Product_Group__c makeActiveGroupWithItem(String name, Id productId) {
        Scheme_Product_Group__c grp = new Scheme_Product_Group__c(
            Name = name,
            Sales_Channel__c = CHANNEL,
            Group_Purpose__c = resolvePurpose('Price Division'),
            Is_Active__c = true
        );
        insert grp;
        insert new Scheme_Product_Group_Item__c(
            Scheme_Product_Group__c = grp.Id,
            Product__c = productId
        );
        return grp;
    }

    // Active FOC Giveaway scheme that gives away the supplied product.
    private static Scheme__c makeActiveFocScheme(Id focProductId, Boolean active) {
        Scheme__c sc = new Scheme__c(
            Name = 'FOC ' + System.now().getTime(),
            Scheme_Type__c = 'FOC Giveaway',
            Sales_Channel__c = CHANNEL,
            IsActive__c = active,
            Scheme_Start_Date__c = Date.today(),
            Scheme_End_Date__c = Date.today().addDays(30)
        );
        insert sc;
        insert new Scheme_Slab__c(
            Scheme__c = sc.Id,
            Slab_Type__c = 'FOC Giveaway',
            FOC_Product__c = focProductId,
            Qualifying_Qty_Min__c = 10,
            Free_Qty__c = 1
        );
        return sc;
    }

    private static SchemeProductGroupController.GroupHeader headerFor(String label, Boolean active) {
        SchemeProductGroupController.GroupHeader h = new SchemeProductGroupController.GroupHeader();
        h.groupLabel   = label;
        h.salesChannel = CHANNEL;
        h.groupPurpose = resolvePurpose('Price Division');
        h.isActive     = active;
        return h;
    }

    /* ============================== FOC validation (existing) ============================== */

    @isTest
    static void saveGroup_blocksProductThatIsActiveFocProduct() {
        Product__c x = makeProduct('GFOCX1');
        makeActiveFocScheme(x.Id, true);

        SchemeProductGroupController.GroupHeader h = headerFor('Grp1', true);

        Test.startTest();
        Boolean blocked = false;
        try {
            SchemeProductGroupController.saveGroup(h, new List<Id>{ x.Id }, null);
        } catch (Exception e) {
            blocked = true;
            System.assert(e.getMessage().contains('FOC giveaway product'),
                'Expected FOC-scheme conflict message, got: ' + e.getMessage());
        }
        Test.stopTest();
        System.assert(blocked, 'Adding an active FOC product to an active group must be blocked.');
    }

    @isTest
    static void saveGroup_inactiveGroupWithFocProductAllowed() {
        Product__c x = makeProduct('GFOCX2');
        makeActiveFocScheme(x.Id, true);

        SchemeProductGroupController.GroupHeader h = headerFor('Grp2', false);

        Test.startTest();
        Id id = SchemeProductGroupController.saveGroup(h, new List<Id>{ x.Id }, null);
        Test.stopTest();
        System.assertNotEquals(null, id, 'Inactive group may contain the FOC product.');
    }

    @isTest
    static void saveGroup_allowedWhenFocSchemeInactive() {
        Product__c x = makeProduct('GFOCX3');
        makeActiveFocScheme(x.Id, false); // scheme inactive -> no conflict

        SchemeProductGroupController.GroupHeader h = headerFor('Grp3', true);

        Test.startTest();
        Id id = SchemeProductGroupController.saveGroup(h, new List<Id>{ x.Id }, null);
        Test.stopTest();
        System.assertNotEquals(null, id, 'Active group is allowed when no active FOC scheme gives away the product.');
    }

    /* ============================== getPicklists ============================== */

    @isTest
    static void getPicklists_returnsOptions() {
        Test.startTest();
        SchemeProductGroupController.BuilderPicklists pk = SchemeProductGroupController.getPicklists();
        Test.stopTest();
        System.assertNotEquals(null, pk, 'Picklists wrapper returned.');
        System.assertNotEquals(null, pk.salesChannels, 'Sales channels not null.');
        System.assertNotEquals(null, pk.groupPurposes, 'Group purposes not null.');
        System.assert(!pk.groupPurposes.isEmpty(), 'Group purposes should have values.');
        System.assertNotEquals(null, pk.categories, 'Categories not null.');
        System.assertNotEquals(null, pk.productGroups, 'Product groups not null.');
        System.assertNotEquals(null, pk.productSubGroups, 'Sub groups not null.');
        System.assertNotEquals(null, pk.varients, 'Varients not null.');
    }

    /* ============================== getSkusForChannel ============================== */

    @isTest
    static void getSkusForChannel_blankReturnsEmpty() {
        Test.startTest();
        List<SchemeProductGroupController.SkuRow> rows =
            SchemeProductGroupController.getSkusForChannel('');
        Test.stopTest();
        System.assertEquals(0, rows.size(), 'Blank channel returns empty.');
    }

    @isTest
    static void getSkusForChannel_noLinksReturnsEmpty() {
        Test.startTest();
        List<SchemeProductGroupController.SkuRow> rows =
            SchemeProductGroupController.getSkusForChannel(CHANNEL);
        Test.stopTest();
        System.assertEquals(0, rows.size(), 'Channel with no Sales_Channel_To_SKU links returns empty.');
    }

    @isTest
    static void getSkusForChannel_returnsLinkedActiveSku() {
        Product__c p = makeProduct('SKUROW1', 25, 1.5);
        linkSku(p.Id, CHANNEL);

        Test.startTest();
        List<SchemeProductGroupController.SkuRow> rows =
            SchemeProductGroupController.getSkusForChannel(CHANNEL);
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'One linked active SKU returned.');
        System.assertEquals(p.Id, rows[0].id, 'Row id maps the product.');
        System.assertEquals('SKUROW1', rows[0].skuCode, 'SKU code mapped.');
        System.assertEquals(25, rows[0].mrp, 'MRP mapped.');
    }

    /* ============================== loadGroup ============================== */

    @isTest
    static void loadGroup_nullReturnsNull() {
        Test.startTest();
        SchemeProductGroupController.LoadGroupResult res =
            SchemeProductGroupController.loadGroup(null);
        Test.stopTest();
        System.assertEquals(null, res, 'Null group id returns null.');
    }

    @isTest
    static void loadGroup_returnsHeaderAndProductIds() {
        Product__c p = makeProduct('LOADP1');
        Scheme_Product_Group__c grp = makeActiveGroupWithItem('LoadGrp', p.Id);

        Test.startTest();
        SchemeProductGroupController.LoadGroupResult res =
            SchemeProductGroupController.loadGroup(grp.Id);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Result returned.');
        System.assertEquals(grp.Id, res.id, 'Group id matches.');
        System.assertNotEquals(null, res.header, 'Header populated.');
        System.assertEquals(CHANNEL, res.header.salesChannel, 'Channel mapped.');
        System.assert(res.header.isActive, 'Active flag mapped.');
        System.assertEquals(1, res.productIds.size(), 'One member product.');
        System.assertEquals(p.Id, res.productIds[0], 'Member product mapped.');
    }

    /* ============================== getConflictingProductIds ============================== */

    @isTest
    static void getConflictingProductIds_blankOrEmpty() {
        Product__c p = makeProduct('CONFB1');
        Test.startTest();
        List<SchemeProductGroupController.ConflictRow> a =
            SchemeProductGroupController.getConflictingProductIds('', new List<Id>{ p.Id }, null);
        List<SchemeProductGroupController.ConflictRow> b =
            SchemeProductGroupController.getConflictingProductIds(CHANNEL, new List<Id>(), null);
        Test.stopTest();
        System.assertEquals(0, a.size(), 'Blank channel returns empty.');
        System.assertEquals(0, b.size(), 'Empty product list returns empty.');
    }

    @isTest
    static void getConflictingProductIds_findsAndExcludes() {
        Product__c p = makeProduct('CONF1');
        Scheme_Product_Group__c grp = makeActiveGroupWithItem('ConfGrp', p.Id);

        Test.startTest();
        List<SchemeProductGroupController.ConflictRow> found =
            SchemeProductGroupController.getConflictingProductIds(CHANNEL, new List<Id>{ p.Id }, null);
        List<SchemeProductGroupController.ConflictRow> excluded =
            SchemeProductGroupController.getConflictingProductIds(CHANNEL, new List<Id>{ p.Id }, grp.Id);
        Test.stopTest();

        System.assertEquals(1, found.size(), 'Conflict found in the active group.');
        System.assertEquals(grp.Id, found[0].groupId, 'Conflict points to the group.');
        System.assertEquals(0, excluded.size(), 'Excluding the same group yields no conflict.');
    }

    /* ============================== saveGroup — validation errors ============================== */

    private static void expectSaveError(
        SchemeProductGroupController.GroupHeader h, List<Id> ids, Id existingId, String fragment) {
        Boolean failed = false;
        try {
            SchemeProductGroupController.saveGroup(h, ids, existingId);
        } catch (Exception e) {
            failed = true;
            System.assert(e.getMessage().contains(fragment),
                'Expected "' + fragment + '", got: ' + e.getMessage());
        }
        System.assert(failed, 'Expected save to fail for: ' + fragment);
    }

    @isTest
    static void saveGroup_validationErrors() {
        Product__c p = makeProduct('VALP1');

        SchemeProductGroupController.GroupHeader noLabel = headerFor(null, true);
        SchemeProductGroupController.GroupHeader noChannel = headerFor('NoChan', true);
        noChannel.salesChannel = null;
        SchemeProductGroupController.GroupHeader noPurpose = headerFor('NoPurp', true);
        noPurpose.groupPurpose = null;
        SchemeProductGroupController.GroupHeader ok = headerFor('OkHdr', true);

        Test.startTest();
        expectSaveError(null, new List<Id>{ p.Id }, null, 'Group data is missing');
        expectSaveError(noLabel, new List<Id>{ p.Id }, null, 'Name is required');
        expectSaveError(noChannel, new List<Id>{ p.Id }, null, 'Sales Channel is required');
        expectSaveError(noPurpose, new List<Id>{ p.Id }, null, 'Group Purpose is required');
        expectSaveError(ok, new List<Id>(), null, 'Select at least one SKU');
        expectSaveError(ok, new List<Id>{ p.Id, p.Id }, null, 'Duplicate SKUs');
        Test.stopTest();
    }

    /* ============================== saveGroup — Price Division derivation ============================== */

    @isTest
    static void saveGroup_priceDivisionMixedMrp() {
        Product__c a = makeProduct('PDMRP1', 10, 1);
        Product__c b = makeProduct('PDMRP2', 20, 1);
        SchemeProductGroupController.GroupHeader h = headerFor('MixedMrp', true);

        Test.startTest();
        expectSaveError(h, new List<Id>{ a.Id, b.Id }, null, 'Mixed MRP');
        Test.stopTest();
    }

    @isTest
    static void saveGroup_priceDivisionMixedWeight() {
        Product__c a = makeProduct('PDW1', 10, 1);
        Product__c b = makeProduct('PDW2', 10, 2);
        SchemeProductGroupController.GroupHeader h = headerFor('MixedWt', true);

        Test.startTest();
        expectSaveError(h, new List<Id>{ a.Id, b.Id }, null, 'Mixed Net Weight');
        Test.stopTest();
    }

    @isTest
    static void saveGroup_priceDivisionValid() {
        Product__c a = makeProduct('PDOK1', 15, 2);
        Product__c b = makeProduct('PDOK2', 15, 2);
        SchemeProductGroupController.GroupHeader h = headerFor('PdOk', true);

        Test.startTest();
        Id id = SchemeProductGroupController.saveGroup(h, new List<Id>{ a.Id, b.Id }, null);
        Test.stopTest();

        Scheme_Product_Group__c grp = [
            SELECT MRP__c, Net_Weight__c FROM Scheme_Product_Group__c WHERE Id = :id
        ];
        System.assertEquals(15, grp.MRP__c, 'Derived MRP stored.');
        System.assertEquals(2, grp.Net_Weight__c, 'Derived net weight stored.');
        System.assertEquals(2, [
            SELECT COUNT() FROM Scheme_Product_Group_Item__c WHERE Scheme_Product_Group__c = :id
        ], 'Two items inserted.');
    }

    /* ============================== saveGroup — conflict block ============================== */

    @isTest
    static void saveGroup_conflictBlocked() {
        Product__c p = makeProduct('CONFSAVE1');
        makeActiveGroupWithItem('ExistingGrp', p.Id); // already in an active group

        SchemeProductGroupController.GroupHeader h = headerFor('NewGrp', true);

        Test.startTest();
        expectSaveError(h, new List<Id>{ p.Id }, null, 'already in another active group');
        Test.stopTest();
    }

    /* ============================== saveGroup — update existing ============================== */

    @isTest
    static void saveGroup_updateExistingReplacesItems() {
        Product__c first = makeProduct('UPDP1');
        Product__c second = makeProduct('UPDP2');

        SchemeProductGroupController.GroupHeader h = headerFor('UpdGrp', true);
        Id id = SchemeProductGroupController.saveGroup(h, new List<Id>{ first.Id }, null);

        Test.startTest();
        SchemeProductGroupController.GroupHeader h2 = headerFor('UpdGrp', true);
        Id sameId = SchemeProductGroupController.saveGroup(h2, new List<Id>{ second.Id }, id);
        Test.stopTest();

        System.assertEquals(id, sameId, 'Update returns the same group id.');
        List<Scheme_Product_Group_Item__c> items = [
            SELECT Product__c FROM Scheme_Product_Group_Item__c WHERE Scheme_Product_Group__c = :id
        ];
        System.assertEquals(1, items.size(), 'Old items replaced by the new set.');
        System.assertEquals(second.Id, items[0].Product__c, 'New product is the only member.');
    }

    /* ============================== saveGroup — non-Price-Division ============================== */

    @isTest
    static void saveGroup_nonPriceDivisionSkipsMrp() {
        String purpose = nonPriceDivisionPurpose();
        if (purpose == null) return; // org has only Price Division — nothing to assert

        Product__c p = makeProduct('NONPD1', 99, 9);
        SchemeProductGroupController.GroupHeader h = headerFor('NonPdGrp', true);
        h.groupPurpose = purpose;

        Test.startTest();
        Id id = SchemeProductGroupController.saveGroup(h, new List<Id>{ p.Id }, null);
        Test.stopTest();

        Scheme_Product_Group__c grp = [
            SELECT MRP__c, Net_Weight__c FROM Scheme_Product_Group__c WHERE Id = :id
        ];
        System.assertEquals(null, grp.MRP__c, 'Non-Price-Division does not derive MRP.');
        System.assertEquals(null, grp.Net_Weight__c, 'Non-Price-Division does not derive weight.');
    }
}
