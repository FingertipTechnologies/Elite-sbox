/****************************************************************
* Class Name : SchemeDefinitionController
* Company : Fingertipplus
* @description : Controller for the schemeDefinitionWizard LWC.
*                Provides picklist values, scheme + slabs hydrate,
*                filtered Scheme_Product_Group__c search and the
*                atomic Scheme__c + Scheme_Slab__c save (Steps 1-3
*                of the Scheme Management spec, Section 2).
******************************************************************/
public with sharing class SchemeDefinitionController {

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
                   Scheme_Product_Category__c
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
        return result;
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
        validateSlabs(master.schemeType, slabs);

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
                if (d.qtyMax != null && d.qtyMax < d.qtyMin) {
                    throw new AuraHandledException(label + ': Max Qty must be >= Buy Qty.');
                }
            } else if (schemeType == TYPE_QPS) {
                if (d.qtyMin == null) throw new AuraHandledException(label + ': Qualifying Cases is required.');
                if (d.benefitPerEa == null) throw new AuraHandledException(label + ': Benefit per Case is required.');
                if (d.qtyMax != null && d.qtyMax < d.qtyMin) {
                    throw new AuraHandledException(label + ': Max Qty must be >= Min Qty.');
                }
            } else if (schemeType == TYPE_FOC_GIVEAWAY) {
                if (d.qtyMin == null) throw new AuraHandledException(label + ': Min Qualifying Qty is required.');
                if (d.focProductId == null) throw new AuraHandledException(label + ': FOC Product is required.');
                if (d.freeQty == null) throw new AuraHandledException(label + ': Free Qty is required.');
                if (d.qtyMax != null && d.qtyMax < d.qtyMin) {
                    throw new AuraHandledException(label + ': Max Qty must be >= Min Qty.');
                }
            } else if (schemeType == TYPE_ORDER_VALUE || schemeType == TYPE_CATEGORY) {
                if (d.valueMin == null) throw new AuraHandledException(label + ': Slab From is required.');
                if (d.benefitPercent == null) throw new AuraHandledException(label + ': Discount % is required.');
                if (d.valueMax != null && d.valueMax < d.valueMin) {
                    throw new AuraHandledException(label + ': Slab To must be >= Slab From.');
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
            Decimal currMax = sorted[i].qtyMax;
            Decimal nextMin = sorted[i + 1].qtyMin;
            if (currMax == null || nextMin == null) continue;
            if (currMax >= nextMin) {
                throw new AuraHandledException('Slab quantity ranges overlap at ' + nextMin + '.');
            }
        }
    }

    private static void assertNoValueOverlap(List<SlabDto> slabs) {
        List<SlabDto> sorted = new List<SlabDto>(slabs);
        sorted.sort(new MinValueComparator());
        for (Integer i = 0; i < sorted.size() - 1; i++) {
            Decimal currMax = sorted[i].valueMax;
            Decimal nextMin = sorted[i + 1].valueMin;
            if (currMax == null || nextMin == null) continue;
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
