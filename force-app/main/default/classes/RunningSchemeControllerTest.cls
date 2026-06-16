@isTest
private class RunningSchemeControllerTest {

    private static final String CHANNEL = 'CPD';
    private static final String TYPE_FREE_QTY = 'Free Quantity';
    private static final String TYPE_QPS      = 'QPS';

    // Resolve a valid Group_Purpose picklist value (global value set lives in the org).
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

    @TestSetup
    static void setupTestData() {
        // Distributor account whose Sales_Channel matches the scheme channel
        Account acc = new Account(
            Name = 'Test Distributor RSC',
            Customer_Type__c = 'Secondary Customer',
            State__c = 'Bihar',
            District__c = 'Patna',
            Sales_Channel__c = CHANNEL
        );
        insert acc;

        // Contact for the Partner Community User
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Partner RSC',
            AccountId = acc.Id
        );
        insert con;

        // Product
        Product__c prod = new Product__c(
            Name = 'Test Product RSC',
            Is_Active__c = true,
            Channel__c = CHANNEL,
            SKU_Code__c = 'RSC001'
        );
        insert prod;

        // Territory (Area__c) driving the Product_Mapping geo formula fields
        Area__c territory = new Area__c(
            Name = 'T-KA-North RSC',
            Region__c = 'KA',
            Area__c = 'North',
            Sales_Channel__c = CHANNEL
        );
        insert territory;

        // Product_Mapping for the account: Region_Name__c / Area_Area_Name__c are
        // formula fields derived from the Area__c (territory) lookup.
        Product_Mapping__c pm = new Product_Mapping__c(
            Primary_Customer__c = acc.Id,
            Customer__c = acc.Id,
            Chanel__c = CHANNEL,
            Area__c = territory.Id
        );
        insert pm;

        // Product groups (one per scheme)
        String purpose = resolvePurpose('PriceDivision');
        Scheme_Product_Group__c groupA = new Scheme_Product_Group__c(
            Name = 'RSC Group A', Sales_Channel__c = CHANNEL,
            Group_Purpose__c = purpose, Is_Active__c = true
        );
        Scheme_Product_Group__c groupB = new Scheme_Product_Group__c(
            Name = 'RSC Group B', Sales_Channel__c = CHANNEL,
            Group_Purpose__c = purpose, Is_Active__c = true
        );
        insert new List<Scheme_Product_Group__c>{ groupA, groupB };

        insert new List<Scheme_Product_Group_Item__c>{
            new Scheme_Product_Group_Item__c(Scheme_Product_Group__c = groupA.Id, Product__c = prod.Id),
            new Scheme_Product_Group_Item__c(Scheme_Product_Group__c = groupB.Id, Product__c = prod.Id)
        };

        // Scheme A — Apply to All (matches without applicability rows)
        Scheme__c schemeA = new Scheme__c(
            Name = 'RSC Scheme A (Apply All)',
            Scheme_Type__c = TYPE_FREE_QTY,
            Sales_Channel__c = CHANNEL,
            IsActive__c = true,
            Scheme_Start_Date__c = Date.today().addDays(-15),
            Scheme_End_Date__c = Date.today().addDays(15),
            Scheme_Product_Group__c = groupA.Id,
            Apply_to_All_Regions__c = true,
            Apply_to_All_Areas__c = true,
            Apply_to_All_Territories__c = true,
            Apply_to_All_Outlet_Categories__c = true
        );

        // Scheme B — specific applicability matching the mapping geo (exercises anyMatch)
        Scheme__c schemeB = new Scheme__c(
            Name = 'RSC Scheme B (Specific Geo)',
            Scheme_Type__c = TYPE_QPS,
            Sales_Channel__c = CHANNEL,
            IsActive__c = true,
            Scheme_Start_Date__c = Date.today().addDays(-15),
            Scheme_End_Date__c = Date.today().addDays(15),
            Scheme_Product_Group__c = groupB.Id,
            Apply_to_All_Regions__c = false,
            Apply_to_All_Areas__c = false,
            Apply_to_All_Territories__c = false,
            Apply_to_All_Outlet_Categories__c = true
        );
        insert new List<Scheme__c>{ schemeA, schemeB };

        // Slabs (multi-tier on B to exercise tier labelling)
        insert new List<Scheme_Slab__c>{
            new Scheme_Slab__c(
                Scheme__c = schemeA.Id, Slab_Type__c = TYPE_FREE_QTY,
                Slab_Sequence__c = 1, Qualifying_Qty_Min__c = 10, Free_Qty__c = 2
            ),
            new Scheme_Slab__c(
                Scheme__c = schemeB.Id, Slab_Type__c = TYPE_QPS,
                Slab_Sequence__c = 1, Qualifying_Qty_Min__c = 3, Benefit_Amount_Per_EA__c = 40
            ),
            new Scheme_Slab__c(
                Scheme__c = schemeB.Id, Slab_Type__c = TYPE_QPS,
                Slab_Sequence__c = 2, Qualifying_Qty_Min__c = 5, Benefit_Amount_Per_EA__c = 80
            )
        };

        // Applicability rows for Scheme B (Region/Area/Territory)
        insert new List<Scheme_Applicability__c>{
            new Scheme_Applicability__c(Scheme__c = schemeB.Id, Level__c = 'Region',    Value_Text__c = 'KA'),
            new Scheme_Applicability__c(Scheme__c = schemeB.Id, Level__c = 'Area',      Value_Text__c = 'North'),
            new Scheme_Applicability__c(Scheme__c = schemeB.Id, Level__c = 'Territory', Value_Lookup__c = territory.Id)
        };

        // Partner Community User (separate runAs to avoid MIXED_DML_OPERATION)
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(adminUser) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Partner Community User' LIMIT 1];
            String uniqueStr = String.valueOf(DateTime.now().getTime());
            User u = new User(
                FirstName = 'Test',
                LastName = 'PartnerRSC',
                Email = 'trsc' + uniqueStr + '@test.com',
                Username = 'trsc' + uniqueStr + '@test.com.rsc',
                Alias = 'trsc',
                TimeZoneSidKey = 'Asia/Kolkata',
                LocaleSidKey = 'en_IN',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = p.Id,
                ContactId = con.Id,
                Employee_Code__c = 'EMPRSC' + uniqueStr
            );
            insert u;
        }
    }

    static User getCommunityUser() {
        return [SELECT Id FROM User WHERE Username LIKE 'trsc%' AND IsActive = true LIMIT 1];
    }

    @isTest
    static void testGetRunningSchemesAsPartnerCurrent() {
        User u = getCommunityUser();
        System.runAs(u) {
            Test.startTest();
            List<beatPlannerlwc.CoverageScheme> result =
                RunningSchemeController.getRunningSchemes('current', null, null);
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals(2, result.size(), 'Both Apply-All and specific-geo schemes should match');

            Boolean foundSlabs = false;
            for (beatPlannerlwc.CoverageScheme cs : result) {
                System.assertNotEquals(null, cs.id);
                System.assertNotEquals(null, cs.validLabel);
                System.assert(cs.validLabel.contains(' to '), 'Valid label spans start/end');
                System.assertNotEquals(null, cs.products);
                System.assertEquals(1, cs.products.size(), 'Group has one product');
                if (cs.slabRows != null && !cs.slabRows.isEmpty()) foundSlabs = true;
            }
            System.assert(foundSlabs, 'At least one scheme should render slab offer rows');
        }
    }

    @isTest
    static void testGetRunningSchemesAsPartnerPrevious() {
        User u = getCommunityUser();
        System.runAs(u) {
            Test.startTest();
            List<beatPlannerlwc.CoverageScheme> result =
                RunningSchemeController.getRunningSchemes('previous', null, null);
            Test.stopTest();
            // Schemes are dated around today, so the previous month likely returns none.
            System.assertNotEquals(null, result);
        }
    }

    @isTest
    static void testGetRunningSchemesAsPartnerCustom() {
        User u = getCommunityUser();
        System.runAs(u) {
            Test.startTest();
            List<beatPlannerlwc.CoverageScheme> result =
                RunningSchemeController.getRunningSchemes(
                    'custom',
                    String.valueOf(Date.today().addDays(-30)),
                    String.valueOf(Date.today().addDays(30))
                );
            Test.stopTest();
            System.assertNotEquals(null, result);
            System.assertEquals(2, result.size());
        }
    }

    @isTest
    static void testGetRunningSchemesAsPartnerCustomMissingDates() {
        // custom + null dates falls through to the default (current month) branch
        User u = getCommunityUser();
        System.runAs(u) {
            Test.startTest();
            List<beatPlannerlwc.CoverageScheme> result =
                RunningSchemeController.getRunningSchemes('custom', null, null);
            Test.stopTest();
            System.assertNotEquals(null, result);
            System.assertEquals(2, result.size());
        }
    }

    @isTest
    static void testGetRunningSchemesAsPartnerDefaultFilter() {
        // Unknown dateFilter hits the else (default current month) branch
        User u = getCommunityUser();
        System.runAs(u) {
            Test.startTest();
            List<beatPlannerlwc.CoverageScheme> result =
                RunningSchemeController.getRunningSchemes('unknown', null, null);
            Test.stopTest();
            System.assertNotEquals(null, result);
            System.assertEquals(2, result.size());
        }
    }

    @isTest
    static void testGetRunningSchemesNoPortalContext() {
        // The running admin user has no Contact → controller returns an empty list (no exception)
        Test.startTest();
        List<beatPlannerlwc.CoverageScheme> result =
            RunningSchemeController.getRunningSchemes('current', null, null);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(0, result.size());
    }
}
