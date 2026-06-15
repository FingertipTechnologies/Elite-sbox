/****************************************************************
* Class Name : SchemeDefinitionController
* Company : Fingertipplus
* @description : Controller for the schemeDefinitionWizard LWC.
*                Provides picklist values, scheme + slabs hydrate,
*                filtered Scheme_Product_Group__c search and the
*                atomic Scheme__c + Scheme_Slab__c save (Steps 1-3
*                of the Scheme Management spec, Section 2).
******************************************************************/
public without sharing class SchemeDefinitionController {

    private static final String TYPE_FREE_QTY     = 'Free Quantity';
    private static final String TYPE_QPS          = 'QPS';
    private static final String TYPE_FOC_GIVEAWAY = 'FOC Giveaway';
    private static final String TYPE_ORDER_VALUE  = 'Order Value';
    private static final String TYPE_CATEGORY     = 'Category Value';

    public class PicklistOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class WizardPicklists {
        @AuraEnabled public List<PicklistOption> salesChannels { get; set; }
        @AuraEnabled public List<PicklistOption> schemeTypes { get; set; }
        @AuraEnabled public List<PicklistOption> productCategories { get; set; }
    }

    public class MasterDto {
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String schemeType { get; set; }
        @AuraEnabled public String salesChannel { get; set; }
        @AuraEnabled public Date startDate { get; set; }
        @AuraEnabled public Date endDate { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Id productGroupId { get; set; }
        @AuraEnabled public String productCategory { get; set; }
        @AuraEnabled public Boolean isActive { get; set; }
    }

    public class LevelStateDto {
        @AuraEnabled public Boolean applyToAll { get; set; }
        @AuraEnabled public List<String> values { get; set; }
    }

    public class ApplicabilityDto {
        @AuraEnabled public LevelStateDto regions { get; set; }
        @AuraEnabled public LevelStateDto areas { get; set; }
        @AuraEnabled public LevelStateDto territories { get; set; }
        @AuraEnabled public LevelStateDto outletCategories { get; set; }
    }

    public class TerritoryOption {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String region { get; set; }
        @AuraEnabled public String area { get; set; }
    }

    public class ApplicabilityOptions {
        @AuraEnabled public List<String> regions { get; set; }
        @AuraEnabled public List<String> areas { get; set; }
        @AuraEnabled public List<TerritoryOption> territories { get; set; }
        @AuraEnabled public List<String> outletCategories { get; set; }
    }

    public class SlabDto {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public Integer sequence { get; set; }
        @AuraEnabled public String slabType { get; set; }
        @AuraEnabled public Decimal qtyMin { get; set; }
        @AuraEnabled public Decimal qtyMax { get; set; }
        @AuraEnabled public Decimal valueMin { get; set; }
        @AuraEnabled public Decimal valueMax { get; set; }
        @AuraEnabled public Decimal freeQty { get; set; }
        @AuraEnabled public Decimal benefitPerEa { get; set; }
        @AuraEnabled public Decimal benefitPercent { get; set; }
        @AuraEnabled public Id focProductId { get; set; }
        @AuraEnabled public String focProductName { get; set; }
    }

    public class ProductGroupRow {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String salesChannel { get; set; }
        @AuraEnabled public String groupPurpose { get; set; }
        @AuraEnabled public Boolean isActive { get; set; }
    }

    public class LoadSchemeResult {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public MasterDto master { get; set; }
        @AuraEnabled public List<SlabDto> slabs { get; set; }
        @AuraEnabled public String productGroupName { get; set; }
        @AuraEnabled public ApplicabilityDto applicability { get; set; }
        @AuraEnabled public List<TerritoryOption> savedTerritoryOptions { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static WizardPicklists getPicklists() {
        WizardPicklists r = new WizardPicklists();
        r.salesChannels     = describePicklist(Scheme__c.Sales_Channel__c.getDescribe());
        r.schemeTypes       = describePicklist(Scheme__c.Scheme_Type__c.getDescribe());
        r.productCategories = describePicklist(Scheme__c.Scheme_Product_Category__c.getDescribe());
        return r;
    }

    private static List<PicklistOption> describePicklist(Schema.DescribeFieldResult dfr) {
        List<PicklistOption> opts = new List<PicklistOption>();
        for (Schema.PicklistEntry e : dfr.getPicklistValues()) {
            if (e.isActive()) {
                opts.add(new PicklistOption(e.getLabel(), e.getValue()));
            }
        }
        return opts;
    }

    @AuraEnabled(cacheable=true)
    public static LoadSchemeResult loadScheme(Id schemeId) {
        if (schemeId == null) {
            return null;
        }
        Scheme__c s = [
            SELECT Id, Name, Description__c, Sales_Channel__c, Scheme_Type__c,
                   Scheme_Start_Date__c, Scheme_End_Date__c, IsActive__c,
                   Scheme_Product_Group__c, Scheme_Product_Group__r.Name,
                   Scheme_Product_Category__c,
                   Apply_to_All_Regions__c, Apply_to_All_Areas__c,
                   Apply_to_All_Territories__c, Apply_to_All_Outlet_Categories__c
            FROM Scheme__c
            WHERE Id = :schemeId
            LIMIT 1
        ];

        LoadSchemeResult result = new LoadSchemeResult();
        result.id = s.Id;
        result.master = new MasterDto();
        result.master.name            = s.Name;
        result.master.description     = s.Description__c;
        result.master.salesChannel    = s.Sales_Channel__c;
        result.master.schemeType      = s.Scheme_Type__c;
        result.master.startDate       = s.Scheme_Start_Date__c;
        result.master.endDate         = s.Scheme_End_Date__c;
        result.master.productGroupId  = s.Scheme_Product_Group__c;
        result.master.productCategory = s.Scheme_Product_Category__c;
        result.master.isActive        = s.IsActive__c;
        result.productGroupName = s.Scheme_Product_Group__c == null
            ? null : s.Scheme_Product_Group__r.Name;

        result.slabs = new List<SlabDto>();
        for (Scheme_Slab__c sl : [
            SELECT Id, Slab_Sequence__c, Slab_Type__c,
                   Qualifying_Qty_Min__c, Qualifying_Qty_Max__c,
                   Qualifying_Value_Min__c, Qualifying_Value_Max__c,
                   Free_Qty__c, Benefit_Amount_Per_EA__c, Benefit_Percent__c,
                   FOC_Product__c, FOC_Product__r.Name
            FROM Scheme_Slab__c
            WHERE Scheme__c = :schemeId
            ORDER BY Slab_Sequence__c ASC NULLS LAST, CreatedDate ASC
        ]) {
            SlabDto d = new SlabDto();
            d.id             = sl.Id;
            d.sequence       = sl.Slab_Sequence__c == null ? null : sl.Slab_Sequence__c.intValue();
            d.slabType       = sl.Slab_Type__c;
            d.qtyMin         = sl.Qualifying_Qty_Min__c;
            d.qtyMax         = sl.Qualifying_Qty_Max__c;
            d.valueMin       = sl.Qualifying_Value_Min__c;
            d.valueMax       = sl.Qualifying_Value_Max__c;
            d.freeQty        = sl.Free_Qty__c;
            d.benefitPerEa   = sl.Benefit_Amount_Per_EA__c;
            d.benefitPercent = sl.Benefit_Percent__c;
            d.focProductId   = sl.FOC_Product__c;
            d.focProductName = sl.FOC_Product__c == null ? null : sl.FOC_Product__r.Name;
            result.slabs.add(d);
        }

        result.applicability        = loadApplicabilityFor(s);
        result.savedTerritoryOptions = hydrateSavedTerritoryOptions(result.applicability);
        return result;
    }

    private static ApplicabilityDto loadApplicabilityFor(Scheme__c s) {
        ApplicabilityDto a = new ApplicabilityDto();
        a.regions          = newLevelState(s.Apply_to_All_Regions__c);
        a.areas            = newLevelState(s.Apply_to_All_Areas__c);
        a.territories      = newLevelState(s.Apply_to_All_Territories__c);
        a.outletCategories = newLevelState(s.Apply_to_All_Outlet_Categories__c);

        for (Scheme_Applicability__c row : [
            SELECT Level__c, Value_Text__c, Value_Lookup__c
            FROM Scheme_Applicability__c
            WHERE Scheme__c = :s.Id
            ORDER BY Level__c, Sort_Order__c NULLS LAST
        ]) {
            if (row.Level__c == 'Region' && row.Value_Text__c != null) {
                a.regions.values.add(row.Value_Text__c);
            } else if (row.Level__c == 'Area' && row.Value_Text__c != null) {
                a.areas.values.add(row.Value_Text__c);
            } else if (row.Level__c == 'Territory' && row.Value_Lookup__c != null) {
                a.territories.values.add(String.valueOf(row.Value_Lookup__c));
            } else if (row.Level__c == 'Outlet Category' && row.Value_Text__c != null) {
                a.outletCategories.values.add(row.Value_Text__c);
            }
        }
        return a;
    }

    private static LevelStateDto newLevelState(Boolean applyToAll) {
        LevelStateDto st = new LevelStateDto();
        st.applyToAll = applyToAll == true;
        st.values = new List<String>();
        return st;
    }

    private static List<TerritoryOption> hydrateSavedTerritoryOptions(ApplicabilityDto a) {
        List<TerritoryOption> out = new List<TerritoryOption>();
        if (a == null || a.territories == null || a.territories.values == null || a.territories.values.isEmpty()) {
            return out;
        }
        Set<Id> ids = new Set<Id>();
        for (String v : a.territories.values) {
            try { ids.add((Id) v); } catch (Exception ignored) {}
        }
        if (ids.isEmpty()) return out;
        for (Area__c t : [
            SELECT Id, Name, Region__c, Area__c
            FROM Area__c
            WHERE Id IN :ids
        ]) {
            TerritoryOption o = new TerritoryOption();
            o.id     = t.Id;
            o.name   = t.Name;
            o.region = t.Region__c;
            o.area   = t.Area__c;
            out.add(o);
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static ApplicabilityOptions getApplicabilityOptions(
        String salesChannel, List<String> regions, List<String> areas
    ) {
        ApplicabilityOptions r = new ApplicabilityOptions();
        r.regions          = new List<String>();
        r.areas            = new List<String>();
        r.territories      = new List<TerritoryOption>();
        r.outletCategories = new List<String>();

        if (String.isBlank(salesChannel)) return r;

        Set<String> regionSet = new Set<String>();
        Set<String> areaSet   = new Set<String>();
        Boolean filterRegions = regions != null && !regions.isEmpty();
        Boolean filterAreas   = areas != null && !areas.isEmpty();

        List<Area__c> all = [
            SELECT Id, Name, Region__c, Area__c
            FROM Area__c
            WHERE Sales_Channel__c = :salesChannel
            ORDER BY Region__c NULLS LAST, Area__c NULLS LAST, Name
        ];
        for (Area__c t : all) {
            if (String.isNotBlank(t.Region__c)) regionSet.add(t.Region__c);
            Boolean regionOk = !filterRegions || regions.contains(t.Region__c);
            if (regionOk && String.isNotBlank(t.Area__c)) areaSet.add(t.Area__c);
            Boolean areaOk = !filterAreas || areas.contains(t.Area__c);
            if (regionOk && areaOk) {
                TerritoryOption o = new TerritoryOption();
                o.id     = t.Id;
                o.name   = t.Name;
                o.region = t.Region__c;
                o.area   = t.Area__c;
                r.territories.add(o);
            }
        }
        r.regions.addAll(regionSet);
        r.regions.sort();
        r.areas.addAll(areaSet);
        r.areas.sort();

        for (Schema.PicklistEntry pe : Buy_Product__c.Secondary_Customer_Category__c.getDescribe().getPicklistValues()) {
            if (pe.isActive()) r.outletCategories.add(pe.getValue());
        }
        return r;
    }

    @AuraEnabled
    public static List<ProductGroupRow> searchProductGroups(
        String salesChannel,
        String groupPurpose,
        String searchTerm,
        Id excludeId
    ) {
        List<ProductGroupRow> rows = new List<ProductGroupRow>();
        if (String.isBlank(salesChannel) || String.isBlank(groupPurpose)) {
            return rows;
        }
        String resolvedPurpose = resolveGroupPurposeValue(groupPurpose);
        if (resolvedPurpose == null) {
            return rows;
        }
        String searchPattern = '%' + String.escapeSingleQuotes((searchTerm == null ? '' : searchTerm.trim())) + '%';
        for (Scheme_Product_Group__c g : [
            SELECT Id, Name, Sales_Channel__c, Group_Purpose__c, Is_Active__c
            FROM Scheme_Product_Group__c
            WHERE Sales_Channel__c = :salesChannel
              AND Group_Purpose__c = :resolvedPurpose
              AND Is_Active__c = true
              AND Name LIKE :searchPattern
            ORDER BY Name
            LIMIT 50
        ]) {
            if (excludeId != null && g.Id == excludeId) {
                continue;
            }
            ProductGroupRow r = new ProductGroupRow();
            r.id           = g.Id;
            r.name         = g.Name;
            r.salesChannel = g.Sales_Channel__c;
            r.groupPurpose = g.Group_Purpose__c;
            r.isActive     = g.Is_Active__c;
            rows.add(r);
        }
        return rows;
    }

    @AuraEnabled
    public static Id saveSchemeWithSlabs(MasterDto master, List<SlabDto> slabs, Id existingId) {
        return saveSchemeWithApplicability(master, slabs, null, existingId);
    }

    @AuraEnabled
    public static Id saveSchemeWithApplicability(MasterDto master, List<SlabDto> slabs, ApplicabilityDto applicability, Id existingId) {
        if (master == null) {
            throw new AuraHandledException('Scheme data is missing.');
        }

        Date savedStartDate = null;
        if (existingId != null) {
            List<Scheme__c> existing = [
                SELECT Scheme_Start_Date__c
                FROM Scheme__c
                WHERE Id = :existingId
                LIMIT 1
            ];
            if (!existing.isEmpty()) {
                savedStartDate = existing[0].Scheme_Start_Date__c;
            }
        }
        validateMaster(master, savedStartDate);
        if (slabs == null || slabs.isEmpty()) {
            throw new AuraHandledException('At least one slab is required.');
        }
        validateLinkage(master);
        validateActiveDuplicate(master, existingId);
        validateSlabs(master.schemeType, slabs);
        validateFocVsActiveGroups(master, slabs);
        if (applicability != null) {
            validateApplicability(applicability);
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Scheme__c s = existingId == null
                ? new Scheme__c()
                : new Scheme__c(Id = existingId);
            s.Name                       = master.name.trim();
            s.Description__c             = master.description;
            s.Sales_Channel__c           = master.salesChannel;
            s.Scheme_Type__c             = master.schemeType;
            s.Scheme_Start_Date__c       = master.startDate;
            s.Scheme_End_Date__c         = master.endDate;
            s.Scheme_Product_Group__c    = master.productGroupId;
            s.Scheme_Product_Category__c = master.productCategory;
            s.IsActive__c                = master.isActive == null ? true : master.isActive;
            if (applicability != null) {
                s.Apply_to_All_Regions__c           = applicability.regions != null          && applicability.regions.applyToAll == true;
                s.Apply_to_All_Areas__c             = applicability.areas != null            && applicability.areas.applyToAll == true;
                s.Apply_to_All_Territories__c       = applicability.territories != null      && applicability.territories.applyToAll == true;
                s.Apply_to_All_Outlet_Categories__c = applicability.outletCategories != null && applicability.outletCategories.applyToAll == true;
                s.Applicability_Summary__c          = buildApplicabilitySummary(master.salesChannel, applicability);
            }
            upsert s;

            if (existingId != null) {
                delete [SELECT Id FROM Scheme_Slab__c WHERE Scheme__c = :existingId];
            }

            List<Scheme_Slab__c> toInsert = new List<Scheme_Slab__c>();
            Integer idx = 1;
            for (SlabDto d : slabs) {
                toInsert.add(buildSlab(s.Id, master.schemeType, idx, d));
                idx++;
            }
            insert toInsert;

            if (applicability != null) {
                delete [SELECT Id FROM Scheme_Applicability__c WHERE Scheme__c = :s.Id];
                List<Scheme_Applicability__c> appRows = buildApplicabilityRows(s.Id, applicability);
                if (!appRows.isEmpty()) insert appRows;
            }

            return s.Id;
        } catch (DmlException dx) {
            Database.rollback(sp);
            throw new AuraHandledException(dx.getDmlMessage(0));
        } catch (AuraHandledException ax) {
            Database.rollback(sp);
            throw ax;
        } catch (Exception ex) {
            Database.rollback(sp);
            throw new AuraHandledException(ex.getMessage());
        }
    }

    private static void validateApplicability(ApplicabilityDto a) {
        if (a == null) return;
        assertLevelFilled('Region',          a.regions);
        assertLevelFilled('Area',            a.areas);
        assertLevelFilled('Territory',       a.territories);
        assertLevelFilled('Outlet Category', a.outletCategories);
        if (a.territories != null && a.territories.applyToAll != true && a.territories.values != null) {
            for (String v : a.territories.values) {
                try { Id.valueOf(v); } catch (Exception ex) {
                    throw new AuraHandledException('Territory selection contains an invalid Id: ' + v);
                }
            }
        }
    }

    private static void assertLevelFilled(String label, LevelStateDto st) {
        if (st == null) {
            throw new AuraHandledException(label + ': selection is missing.');
        }
        if (st.applyToAll == true) return;
        if (st.values == null || st.values.isEmpty()) {
            throw new AuraHandledException('Pick at least one ' + label + ', or toggle Apply to all ' + label + '.');
        }
    }

    private static List<Scheme_Applicability__c> buildApplicabilityRows(Id schemeId, ApplicabilityDto a) {
        List<Scheme_Applicability__c> out = new List<Scheme_Applicability__c>();
        if (a == null) return out;
        appendTextLevel(out, schemeId, 'Region',          a.regions);
        appendTextLevel(out, schemeId, 'Area',            a.areas);
        appendTerritoryLevel(out, schemeId, a.territories);
        appendTextLevel(out, schemeId, 'Outlet Category', a.outletCategories);
        return out;
    }

    private static void appendTextLevel(List<Scheme_Applicability__c> out, Id schemeId, String level, LevelStateDto st) {
        if (st == null || st.applyToAll == true || st.values == null) return;
        Integer i = 1;
        Set<String> seen = new Set<String>();
        for (String v : st.values) {
            if (String.isBlank(v) || seen.contains(v)) continue;
            seen.add(v);
            Scheme_Applicability__c row = new Scheme_Applicability__c(
                Scheme__c     = schemeId,
                Level__c      = level,
                Value_Text__c = v,
                Sort_Order__c = i++
            );
            out.add(row);
        }
    }

    private static void appendTerritoryLevel(List<Scheme_Applicability__c> out, Id schemeId, LevelStateDto st) {
        if (st == null || st.applyToAll == true || st.values == null) return;
        Integer i = 1;
        Set<Id> seen = new Set<Id>();
        for (String v : st.values) {
            if (String.isBlank(v)) continue;
            Id tid;
            try { tid = (Id) v; } catch (Exception ex) { continue; }
            if (seen.contains(tid)) continue;
            seen.add(tid);
            Scheme_Applicability__c row = new Scheme_Applicability__c(
                Scheme__c       = schemeId,
                Level__c        = 'Territory',
                Value_Lookup__c = tid,
                Sort_Order__c   = i++
            );
            out.add(row);
        }
    }

    private static String buildApplicabilitySummary(String channel, ApplicabilityDto a) {
        if (a == null) return null;
        List<String> parts = new List<String>();
        if (String.isNotBlank(channel)) parts.add('Channel: ' + channel);
        parts.add(levelSummary('Regions',           a.regions));
        parts.add(levelSummary('Areas',             a.areas));
        parts.add(levelSummary('Territories',       a.territories));
        parts.add(levelSummary('Outlet Categories', a.outletCategories));
        return String.join(parts, ' | ');
    }

    private static String levelSummary(String label, LevelStateDto st) {
        if (st == null) return label + ': —';
        if (st.applyToAll == true) return label + ': All';
        Integer n = st.values == null ? 0 : st.values.size();
        return label + ': ' + n;
    }

    private static void validateMaster(MasterDto m, Date savedStartDate) {
        if (String.isBlank(m.name))         throw new AuraHandledException('Name is required.');
        if (String.isBlank(m.schemeType))   throw new AuraHandledException('Scheme Type is required.');
        if (String.isBlank(m.salesChannel)) throw new AuraHandledException('Sales Channel is required.');
        if (m.startDate == null)            throw new AuraHandledException('Start Date is required.');
        if (m.endDate == null)              throw new AuraHandledException('End Date is required.');
        if (m.endDate < m.startDate)        throw new AuraHandledException('End Date cannot be before Start Date.');

        Date today = Date.today();
        Boolean startChanged = (savedStartDate == null) || (m.startDate != savedStartDate);
        if (startChanged && m.startDate < today) {
            throw new AuraHandledException('Start Date cannot be in the past.');
        }
        if (m.endDate < today) {
            throw new AuraHandledException('End Date cannot be in the past.');
        }
    }

    private static void validateLinkage(MasterDto m) {
        String t = m.schemeType;
        if (t == TYPE_FREE_QTY || t == TYPE_QPS || t == TYPE_FOC_GIVEAWAY) {
            if (m.productGroupId == null) {
                throw new AuraHandledException('Scheme Product Group is required for this scheme type.');
            }
            String expectedPurpose = (t == TYPE_FOC_GIVEAWAY) ? 'FOC Qualifier' : 'Price Division';
            String resolved = resolveGroupPurposeValue(expectedPurpose);
            Scheme_Product_Group__c g = [
                SELECT Id, Sales_Channel__c, Group_Purpose__c, Is_Active__c
                FROM Scheme_Product_Group__c
                WHERE Id = :m.productGroupId
                LIMIT 1
            ];
            if (g.Is_Active__c != true) {
                throw new AuraHandledException('The linked Scheme Product Group is inactive.');
            }
            if (g.Sales_Channel__c != m.salesChannel) {
                throw new AuraHandledException('Linked group sales channel does not match scheme sales channel.');
            }
            if (resolved != null && g.Group_Purpose__c != resolved) {
                throw new AuraHandledException('Linked group purpose does not match the scheme type.');
            }
        } else if (t == TYPE_CATEGORY) {
            if (String.isBlank(m.productCategory)) {
                throw new AuraHandledException('Product Category is required for Category Value schemes.');
            }
        }
    }

    private static void validateActiveDuplicate(MasterDto m, Id existingId) {
        // No two ACTIVE schemes may match the same selling context with
        // overlapping date ranges. Match fields vary by scheme type.
        Boolean willBeActive = (m.isActive == null) ? true : m.isActive;
        if (!willBeActive) return; // inactive saves never conflict

        String t = m.schemeType;
        List<Scheme__c> dupes = null;
        String criteria = null;

        // Overlap: existing.start <= new.end AND existing.end >= new.start
        if (t == TYPE_FREE_QTY || t == TYPE_QPS || t == TYPE_FOC_GIVEAWAY) {
            if (m.productGroupId == null) return;
            criteria = 'Scheme Type, Product Group and Sales Channel';
            dupes = [
                SELECT Id, Name FROM Scheme__c
                WHERE Scheme_Type__c = :t
                  AND Scheme_Product_Group__c = :m.productGroupId
                  AND Sales_Channel__c = :m.salesChannel
                  AND IsActive__c = true
                  AND Id != :existingId
                  AND Scheme_Start_Date__c <= :m.endDate
                  AND Scheme_End_Date__c   >= :m.startDate
                LIMIT 1
            ];
        } else if (t == TYPE_CATEGORY) {
            if (String.isBlank(m.productCategory)) return;
            criteria = 'Scheme Type, Product Category and Sales Channel';
            dupes = [
                SELECT Id, Name FROM Scheme__c
                WHERE Scheme_Type__c = :t
                  AND Scheme_Product_Category__c = :m.productCategory
                  AND Sales_Channel__c = :m.salesChannel
                  AND IsActive__c = true
                  AND Id != :existingId
                  AND Scheme_Start_Date__c <= :m.endDate
                  AND Scheme_End_Date__c   >= :m.startDate
                LIMIT 1
            ];
        } else if (t == TYPE_ORDER_VALUE) {
            criteria = 'Scheme Type and Sales Channel';
            dupes = [
                SELECT Id, Name FROM Scheme__c
                WHERE Scheme_Type__c = :t
                  AND Sales_Channel__c = :m.salesChannel
                  AND IsActive__c = true
                  AND Id != :existingId
                  AND Scheme_Start_Date__c <= :m.endDate
                  AND Scheme_End_Date__c   >= :m.startDate
                LIMIT 1
            ];
        } else {
            return;
        }

        if (dupes != null && !dupes.isEmpty()) {
            throw new AuraHandledException(
                'An active scheme with the same ' + criteria
                + ' and an overlapping date range already exists ("'
                + dupes[0].Name + '"). Deactivate it or use non-overlapping dates.');
        }
    }

    // Scheme Task 1: a FOC giveaway product cannot also be a member of an ACTIVE
    // Scheme Product Group. Only enforced when this scheme is/becomes active.
    private static void validateFocVsActiveGroups(MasterDto m, List<SlabDto> slabs) {
        if (m.schemeType != TYPE_FOC_GIVEAWAY) return;
        Boolean willBeActive = (m.isActive == null) ? true : m.isActive;
        if (!willBeActive) return;

        Set<Id> focIds = new Set<Id>();
        if (slabs != null) {
            for (SlabDto d : slabs) {
                if (d != null && d.focProductId != null) focIds.add(d.focProductId);
            }
        }
        if (focIds.isEmpty()) return;

        // product Id -> active group names it already belongs to
        Map<Id, Set<String>> groupsByProduct = new Map<Id, Set<String>>();
        Map<Id, String> productNames = new Map<Id, String>();
        for (Scheme_Product_Group_Item__c item : [
            SELECT Product__c, Product__r.Name, Scheme_Product_Group__r.Name
            FROM Scheme_Product_Group_Item__c
            WHERE Product__c IN :focIds
              AND Scheme_Product_Group__r.Is_Active__c = true
        ]) {
            if (!groupsByProduct.containsKey(item.Product__c)) {
                groupsByProduct.put(item.Product__c, new Set<String>());
            }
            groupsByProduct.get(item.Product__c).add(item.Scheme_Product_Group__r.Name);
            productNames.put(item.Product__c, item.Product__r.Name);
        }
        if (groupsByProduct.isEmpty()) return;

        List<String> parts = new List<String>();
        for (Id pid : groupsByProduct.keySet()) {
            parts.add('"' + productNames.get(pid) + '" (in '
                + String.join(new List<String>(groupsByProduct.get(pid)), ', ') + ')');
        }
        throw new AuraHandledException(
            'These FOC giveaway products are already members of an active Scheme Product Group: '
            + String.join(parts, '; ')
            + '. Remove them from the group or deactivate the group before activating this FOC Giveaway scheme.');
    }

    private static void validateSlabs(String schemeType, List<SlabDto> slabs) {
        Set<Integer> seenSeq = new Set<Integer>();
        for (Integer i = 0; i < slabs.size(); i++) {
            SlabDto d = slabs[i];
            String label = 'Slab ' + (i + 1);
            if (d.slabType != null && d.slabType != schemeType) {
                throw new AuraHandledException(label + ': type does not match parent scheme.');
            }
            if (schemeType == TYPE_FREE_QTY) {
                if (d.qtyMin == null) throw new AuraHandledException(label + ': Buy Qty is required.');
                if (d.freeQty == null) throw new AuraHandledException(label + ': Free Qty is required.');
                if (d.qtyMin <= 0) throw new AuraHandledException(label + ': Min Qty must be greater than 0.');
                if (d.freeQty <= 0) throw new AuraHandledException(label + ': Free Qty must be greater than 0.');
                if (d.qtyMax != null) {
                    if (d.qtyMax <= 0) throw new AuraHandledException(label + ': Max Qty must be greater than 0.');
                    if (d.qtyMax < d.qtyMin) throw new AuraHandledException(label + ': Max Qty must be >= Buy Qty.');
                }
            } else if (schemeType == TYPE_QPS) {
                if (d.qtyMin == null) throw new AuraHandledException(label + ': Qualifying Cases is required.');
                if (d.benefitPerEa == null) throw new AuraHandledException(label + ': Benefit per Case is required.');
                if (d.qtyMin <= 0) throw new AuraHandledException(label + ': Min Qty must be greater than 0.');
                if (d.benefitPerEa <= 0) throw new AuraHandledException(label + ': Benefit / EA must be greater than 0.');
                if (d.qtyMax != null) {
                    if (d.qtyMax <= 0) throw new AuraHandledException(label + ': Max Qty must be greater than 0.');
                    if (d.qtyMax < d.qtyMin) throw new AuraHandledException(label + ': Max Qty must be >= Min Qty.');
                }
            } else if (schemeType == TYPE_FOC_GIVEAWAY) {
                if (d.qtyMin == null) throw new AuraHandledException(label + ': Min Qualifying Qty is required.');
                if (d.focProductId == null) throw new AuraHandledException(label + ': FOC Product is required.');
                if (d.freeQty == null) throw new AuraHandledException(label + ': Free Qty is required.');
                if (d.qtyMin <= 0) throw new AuraHandledException(label + ': Min Qty must be greater than 0.');
                if (d.freeQty <= 0) throw new AuraHandledException(label + ': Free Qty must be greater than 0.');
                if (d.qtyMax != null) {
                    if (d.qtyMax <= 0) throw new AuraHandledException(label + ': Max Qty must be greater than 0.');
                    if (d.qtyMax < d.qtyMin) throw new AuraHandledException(label + ': Max Qty must be >= Min Qty.');
                }
            } else if (schemeType == TYPE_ORDER_VALUE || schemeType == TYPE_CATEGORY) {
                if (d.valueMin == null) throw new AuraHandledException(label + ': Slab From is required.');
                if (d.benefitPercent == null) throw new AuraHandledException(label + ': Discount % is required.');
                if (d.valueMin <= 0) throw new AuraHandledException(label + ': Min Value must be greater than 0.');
                if (d.benefitPercent <= 0) throw new AuraHandledException(label + ': Discount % must be greater than 0.');
                if (d.benefitPercent > 100) throw new AuraHandledException(label + ': Discount % cannot exceed 100.');
                if (d.valueMax != null) {
                    if (d.valueMax <= 0) throw new AuraHandledException(label + ': Max Value must be greater than 0.');
                    if (d.valueMax < d.valueMin) throw new AuraHandledException(label + ': Slab To must be >= Slab From.');
                }
            } else {
                throw new AuraHandledException('Unsupported scheme type: ' + schemeType);
            }
            if (d.sequence != null) {
                if (seenSeq.contains(d.sequence)) {
                    throw new AuraHandledException(label + ': duplicate slab sequence ' + d.sequence + '.');
                }
                seenSeq.add(d.sequence);
            }
        }

        assertSlabsAscending(schemeType, slabs);
        assertBenefitsIncrease(schemeType, slabs);

        if (schemeType == TYPE_FREE_QTY || schemeType == TYPE_QPS || schemeType == TYPE_FOC_GIVEAWAY) {
            assertAtMostOneOpenTopQty(slabs);
            assertUniqueQtyMin(slabs);
            assertNoQtyOverlap(slabs);
        } else if (schemeType == TYPE_ORDER_VALUE || schemeType == TYPE_CATEGORY) {
            assertAtMostOneOpenTopValue(slabs);
            assertUniqueValueMin(slabs);
            assertNoValueOverlap(slabs);
        }
    }

    private static Boolean isQtyType(String t) {
        return t == TYPE_FREE_QTY || t == TYPE_QPS || t == TYPE_FOC_GIVEAWAY;
    }
    private static Boolean isValueType(String t) {
        return t == TYPE_ORDER_VALUE || t == TYPE_CATEGORY;
    }
    private static Decimal slabMin(SlabDto d, String t) {
        return isQtyType(t) ? d.qtyMin : d.valueMin;
    }
    private static Decimal slabBenefit(SlabDto d, String t) {
        if (t == TYPE_FREE_QTY || t == TYPE_FOC_GIVEAWAY) return d.freeQty;
        if (t == TYPE_QPS) return d.benefitPerEa;
        return d.benefitPercent;
    }
    private static String benefitLabelFor(String t) {
        if (t == TYPE_FREE_QTY || t == TYPE_FOC_GIVEAWAY) return 'Free Qty';
        if (t == TYPE_QPS) return 'Benefit / EA';
        return 'Discount %';
    }
    private static String minLabelFor(String t) {
        return isQtyType(t) ? 'Min Qty' : 'Min Value';
    }

    private static void assertSlabsAscending(String schemeType, List<SlabDto> slabs) {
        for (Integer i = 1; i < slabs.size(); i++) {
            Decimal prev = slabMin(slabs[i - 1], schemeType);
            Decimal cur  = slabMin(slabs[i], schemeType);
            if (prev == null || cur == null) continue;
            if (cur <= prev) {
                throw new AuraHandledException(
                    'Slab ' + (i + 1) + '\'s ' + minLabelFor(schemeType) + ' (' + cur +
                    ') must be greater than Slab ' + i + '\'s ' + minLabelFor(schemeType) + ' (' + prev +
                    '). Enter slabs in ascending order.');
            }
        }
    }

    private static void assertBenefitsIncrease(String schemeType, List<SlabDto> slabs) {
        for (Integer i = 1; i < slabs.size(); i++) {
            Decimal prev = slabBenefit(slabs[i - 1], schemeType);
            Decimal cur  = slabBenefit(slabs[i], schemeType);
            if (prev == null || cur == null) continue;
            if (cur <= prev) {
                throw new AuraHandledException(
                    'Slab ' + (i + 1) + '\'s ' + benefitLabelFor(schemeType) + ' (' + cur +
                    ') must be greater than Slab ' + i + '\'s ' + benefitLabelFor(schemeType) + ' (' + prev +
                    '). Higher slabs should give a better deal.');
            }
        }
    }

    private static void assertAtMostOneOpenTopQty(List<SlabDto> slabs) {
        Integer openTops = 0;
        for (SlabDto d : slabs) {
            if (d.qtyMax == null) openTops++;
        }
        if (openTops > 1) {
            throw new AuraHandledException('Only one slab can leave Max Qty blank (the open-top slab).');
        }
    }

    private static void assertUniqueQtyMin(List<SlabDto> slabs) {
        Set<Decimal> seen = new Set<Decimal>();
        for (SlabDto d : slabs) {
            if (d.qtyMin == null) continue;
            if (seen.contains(d.qtyMin)) {
                throw new AuraHandledException('Duplicate Min Qty ' + d.qtyMin + '.');
            }
            seen.add(d.qtyMin);
        }
    }

    private static void assertAtMostOneOpenTopValue(List<SlabDto> slabs) {
        Integer openTops = 0;
        for (SlabDto d : slabs) {
            if (d.valueMax == null) openTops++;
        }
        if (openTops > 1) {
            throw new AuraHandledException('Only one slab can leave Max Value blank (the open-top slab).');
        }
    }

    private static void assertUniqueValueMin(List<SlabDto> slabs) {
        Set<Decimal> seen = new Set<Decimal>();
        for (SlabDto d : slabs) {
            if (d.valueMin == null) continue;
            if (seen.contains(d.valueMin)) {
                throw new AuraHandledException('Duplicate Min Value ' + d.valueMin + '.');
            }
            seen.add(d.valueMin);
        }
    }

    private static void assertNoQtyOverlap(List<SlabDto> slabs) {
        List<SlabDto> sorted = new List<SlabDto>(slabs);
        sorted.sort(new MinQtyComparator());
        for (Integer i = 0; i < sorted.size() - 1; i++) {
            if (sorted[i].qtyMax == null) {
                throw new AuraHandledException('Only the last slab can leave Max Qty blank — Min ' + sorted[i].qtyMin + ' has no Max but is followed by another slab.');
            }
            Decimal currMax = sorted[i].qtyMax;
            Decimal nextMin = sorted[i + 1].qtyMin;
            if (nextMin == null) continue;
            if (currMax >= nextMin) {
                throw new AuraHandledException('Slab quantity ranges overlap at ' + nextMin + '.');
            }
        }
    }

    private static void assertNoValueOverlap(List<SlabDto> slabs) {
        List<SlabDto> sorted = new List<SlabDto>(slabs);
        sorted.sort(new MinValueComparator());
        for (Integer i = 0; i < sorted.size() - 1; i++) {
            if (sorted[i].valueMax == null) {
                throw new AuraHandledException('Only the last slab can leave Max Value blank — Min ' + sorted[i].valueMin + ' has no Max but is followed by another slab.');
            }
            Decimal currMax = sorted[i].valueMax;
            Decimal nextMin = sorted[i + 1].valueMin;
            if (nextMin == null) continue;
            if (currMax >= nextMin) {
                throw new AuraHandledException('Slab value ranges overlap at ' + nextMin + '.');
            }
        }
    }

    public class MinQtyComparator implements Comparator<SlabDto> {
        public Integer compare(SlabDto a, SlabDto b) {
            Decimal av = a.qtyMin == null ? 0 : a.qtyMin;
            Decimal bv = b.qtyMin == null ? 0 : b.qtyMin;
            if (av < bv) return -1;
            if (av > bv) return 1;
            return 0;
        }
    }

    public class MinValueComparator implements Comparator<SlabDto> {
        public Integer compare(SlabDto a, SlabDto b) {
            Decimal av = a.valueMin == null ? 0 : a.valueMin;
            Decimal bv = b.valueMin == null ? 0 : b.valueMin;
            if (av < bv) return -1;
            if (av > bv) return 1;
            return 0;
        }
    }

    private static Scheme_Slab__c buildSlab(Id schemeId, String schemeType, Integer seq, SlabDto d) {
        Scheme_Slab__c sl = new Scheme_Slab__c();
        sl.Scheme__c       = schemeId;
        sl.Slab_Sequence__c = seq;
        sl.Slab_Type__c    = schemeType;
        if (schemeType == TYPE_FREE_QTY) {
            sl.Qualifying_Qty_Min__c = d.qtyMin;
            sl.Qualifying_Qty_Max__c = d.qtyMax;
            sl.Free_Qty__c           = d.freeQty;
        } else if (schemeType == TYPE_QPS) {
            sl.Qualifying_Qty_Min__c    = d.qtyMin;
            sl.Qualifying_Qty_Max__c    = d.qtyMax;
            sl.Benefit_Amount_Per_EA__c = d.benefitPerEa;
        } else if (schemeType == TYPE_FOC_GIVEAWAY) {
            sl.Qualifying_Qty_Min__c = d.qtyMin;
            sl.Qualifying_Qty_Max__c = d.qtyMax;
            sl.Free_Qty__c           = d.freeQty;
            sl.FOC_Product__c        = d.focProductId;
        } else if (schemeType == TYPE_ORDER_VALUE || schemeType == TYPE_CATEGORY) {
            sl.Qualifying_Value_Min__c = d.valueMin;
            sl.Qualifying_Value_Max__c = d.valueMax;
            sl.Benefit_Percent__c      = d.benefitPercent;
        }
        return sl;
    }

    private static String normalizePurpose(String value) {
        if (value == null) return '';
        return value.toLowerCase().replaceAll('[\\s_\\-]', '');
    }

    private static String resolveGroupPurposeValue(String target) {
        String normalized = normalizePurpose(target);
        for (Schema.PicklistEntry e : Scheme_Product_Group__c.Group_Purpose__c.getDescribe().getPicklistValues()) {
            if (!e.isActive()) continue;
            if (normalizePurpose(e.getValue()) == normalized) {
                return e.getValue();
            }
        }
        return null;
    }
}