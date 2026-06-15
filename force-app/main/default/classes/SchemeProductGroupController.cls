/****************************************************************
* Class Name : SchemeProductGroupController
* Company : Fingertipplus
* @description : Controller for the schemeProductGroupBuilder LWC.
*                Provides picklist values, channel-filtered SKU
*                lookup, cross-group conflict detection and the
*                New/Edit save logic for Scheme_Product_Group__c and
*                its Scheme_Product_Group_Item__c junction children.
******************************************************************/
public with sharing class SchemeProductGroupController {

    public class PicklistOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class BuilderPicklists {
        @AuraEnabled public List<PicklistOption> salesChannels { get; set; }
        @AuraEnabled public List<PicklistOption> groupPurposes { get; set; }
        @AuraEnabled public List<PicklistOption> categories { get; set; }
        @AuraEnabled public List<PicklistOption> productGroups { get; set; }
        @AuraEnabled public List<PicklistOption> productSubGroups { get; set; }
        @AuraEnabled public List<PicklistOption> varients { get; set; }
    }

    public class SkuRow {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String skuCode { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public String productGroup { get; set; }
        @AuraEnabled public String productSubGroup { get; set; }
        @AuraEnabled public String varient { get; set; }
        @AuraEnabled public Decimal netWeight { get; set; }
        @AuraEnabled public Decimal mrp { get; set; }
    }

    public class GroupHeader {
        @AuraEnabled public String groupLabel { get; set; }
        @AuraEnabled public String salesChannel { get; set; }
        @AuraEnabled public String groupPurpose { get; set; }
        @AuraEnabled public Decimal mrp { get; set; }
        @AuraEnabled public Decimal netWeight { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Boolean isActive { get; set; }
    }

    public class LoadGroupResult {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public GroupHeader header { get; set; }
        @AuraEnabled public List<Id> productIds { get; set; }
    }

    public class ConflictRow {
        @AuraEnabled public Id productId { get; set; }
        @AuraEnabled public Id groupId { get; set; }
        @AuraEnabled public String groupName { get; set; }
        public ConflictRow(Id productId, Id groupId, String groupName) {
            this.productId = productId;
            this.groupId = groupId;
            this.groupName = groupName;
        }
    }

    @AuraEnabled(cacheable=true)
    public static BuilderPicklists getPicklists() {
        BuilderPicklists result = new BuilderPicklists();
        result.salesChannels    = describePicklist(Product__c.Channel__c.getDescribe());
        result.groupPurposes    = describePicklist(Scheme_Product_Group__c.Group_Purpose__c.getDescribe());
        result.categories       = describePicklist(Product__c.Category__c.getDescribe());
        result.productGroups    = describePicklist(Product__c.Product_Group__c.getDescribe());
        result.productSubGroups = describePicklist(Product__c.Product_Sub_Group__c.getDescribe());
        result.varients         = describePicklist(Product__c.Varient__c.getDescribe());
        return result;
    }

    private static List<PicklistOption> describePicklist(Schema.DescribeFieldResult dfr) {
        List<PicklistOption> options = new List<PicklistOption>();
        for (Schema.PicklistEntry entry : dfr.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
            }
        }
        return options;
    }

    @AuraEnabled
    public static List<SkuRow> getSkusForChannel(String salesChannel) {
        if (String.isBlank(salesChannel)) {
            return new List<SkuRow>();
        }

        Set<Id> productIds = new Set<Id>();
        for (Sales_Channel_To_SKU__c link : [
            SELECT SKU__c
            FROM Sales_Channel_To_SKU__c
            WHERE Sales_Channel__c = :salesChannel
            AND SKU__c != null
        ]) {
            productIds.add(link.SKU__c);
        }
        if (productIds.isEmpty()) {
            return new List<SkuRow>();
        }

        List<SkuRow> rows = new List<SkuRow>();
        for (Product__c p : [
            SELECT Id, Name, SKU_Code__c, Category__c, Product_Group__c,
                   Product_Sub_Group__c, Varient__c, Net_Weight__c, MRP__c
            FROM Product__c
            WHERE Id IN :productIds AND Is_Active__c = true
            ORDER BY Name
            LIMIT 2000
        ]) {
            SkuRow row = new SkuRow();
            row.id              = p.Id;
            row.name            = p.Name;
            row.skuCode         = p.SKU_Code__c;
            row.category        = p.Category__c;
            row.productGroup    = p.Product_Group__c;
            row.productSubGroup = p.Product_Sub_Group__c;
            row.varient         = p.Varient__c;
            row.netWeight       = p.Net_Weight__c;
            row.mrp             = p.MRP__c;
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static LoadGroupResult loadGroup(Id groupId) {
        if (groupId == null) {
            return null;
        }
        Scheme_Product_Group__c grp = [
            SELECT Id, Name, Sales_Channel__c, Group_Purpose__c,
                   MRP__c, Net_Weight__c, Description__c, Is_Active__c
            FROM Scheme_Product_Group__c
            WHERE Id = :groupId
            LIMIT 1
        ];

        LoadGroupResult result = new LoadGroupResult();
        result.id = grp.Id;
        result.name = grp.Name;
        result.header = new GroupHeader();
        result.header.groupLabel   = grp.Name;
        result.header.salesChannel = grp.Sales_Channel__c;
        result.header.groupPurpose = grp.Group_Purpose__c;
        result.header.mrp          = grp.MRP__c;
        result.header.netWeight    = grp.Net_Weight__c;
        result.header.description  = grp.Description__c;
        result.header.isActive     = grp.Is_Active__c;

        result.productIds = new List<Id>();
        for (Scheme_Product_Group_Item__c item : [
            SELECT Product__c
            FROM Scheme_Product_Group_Item__c
            WHERE Scheme_Product_Group__c = :groupId
        ]) {
            if (item.Product__c != null) {
                result.productIds.add(item.Product__c);
            }
        }
        return result;
    }

    private static String normalizePurpose(String value) {
        if (value == null) return '';
        return value.toLowerCase().replaceAll('[\\s_\\-]', '');
    }

    private static Boolean isPriceDivision(String value) {
        return normalizePurpose(value) == 'pricedivision';
    }

    @AuraEnabled
    public static List<ConflictRow> getConflictingProductIds(
        String salesChannel,
        List<Id> productIds,
        Id excludeGroupId
    ) {
        List<ConflictRow> conflicts = new List<ConflictRow>();
        if (String.isBlank(salesChannel) || productIds == null || productIds.isEmpty()) {
            return conflicts;
        }

        for (Scheme_Product_Group_Item__c item : [
            SELECT Product__c,
                   Scheme_Product_Group__c,
                   Scheme_Product_Group__r.Name
            FROM Scheme_Product_Group_Item__c
            WHERE Product__c IN :productIds
              AND Scheme_Product_Group__r.Sales_Channel__c = :salesChannel
              AND Scheme_Product_Group__r.Is_Active__c = true
        ]) {
            if (excludeGroupId != null && item.Scheme_Product_Group__c == excludeGroupId) {
                continue;
            }
            conflicts.add(new ConflictRow(
                item.Product__c,
                item.Scheme_Product_Group__c,
                item.Scheme_Product_Group__r.Name
            ));
        }
        return conflicts;
    }

    // Scheme Task 1: a product that is the FOC giveaway product of an ACTIVE FOC
    // Giveaway scheme cannot be a member of an ACTIVE Scheme Product Group. Only
    // enforced when the group is/becomes active (symmetric with the scheme side).
    private static void validateProductsVsActiveFocSchemes(Set<Id> productIds, GroupHeader header) {
        Boolean willBeActive = (header.isActive == null) ? true : header.isActive;
        if (!willBeActive || productIds == null || productIds.isEmpty()) return;

        // product Id -> active FOC Giveaway scheme names that give it away
        Map<Id, Set<String>> schemesByProduct = new Map<Id, Set<String>>();
        Map<Id, String> productNames = new Map<Id, String>();
        for (Scheme_Slab__c sl : [
            SELECT FOC_Product__c, FOC_Product__r.Name, Scheme__r.Name
            FROM Scheme_Slab__c
            WHERE FOC_Product__c IN :productIds
              AND Scheme__r.IsActive__c = true
              AND Scheme__r.Scheme_Type__c = 'FOC Giveaway'
        ]) {
            if (!schemesByProduct.containsKey(sl.FOC_Product__c)) {
                schemesByProduct.put(sl.FOC_Product__c, new Set<String>());
            }
            schemesByProduct.get(sl.FOC_Product__c).add(sl.Scheme__r.Name);
            productNames.put(sl.FOC_Product__c, sl.FOC_Product__r.Name);
        }
        if (schemesByProduct.isEmpty()) return;

        List<String> parts = new List<String>();
        for (Id pid : schemesByProduct.keySet()) {
            parts.add('"' + productNames.get(pid) + '" (FOC product of '
                + String.join(new List<String>(schemesByProduct.get(pid)), ', ') + ')');
        }
        throw new AuraHandledException(
            'These SKUs are the FOC giveaway product of an active FOC Giveaway scheme and cannot be in an active Scheme Product Group: '
            + String.join(parts, '; ')
            + '. Deactivate the scheme or this group, or remove the SKU.');
    }

    @AuraEnabled
    public static Id saveGroup(GroupHeader header, List<Id> productIds, Id existingId) {
        if (header == null) {
            throw new AuraHandledException('Group data is missing.');
        }
        if (String.isBlank(header.groupLabel)) {
            throw new AuraHandledException('Name is required.');
        }
        if (String.isBlank(header.salesChannel)) {
            throw new AuraHandledException('Sales Channel is required.');
        }
        if (String.isBlank(header.groupPurpose)) {
            throw new AuraHandledException('Group Purpose is required.');
        }
        if (productIds == null || productIds.isEmpty()) {
            throw new AuraHandledException('Select at least one SKU.');
        }

        Set<Id> uniqueProductIds = new Set<Id>(productIds);
        if (uniqueProductIds.size() != productIds.size()) {
            throw new AuraHandledException('Duplicate SKUs are not allowed in the same group.');
        }

        Boolean isPriceDivision = isPriceDivision(header.groupPurpose);
        Decimal derivedMrp = null;
        Decimal derivedNetWeight = null;
        if (isPriceDivision) {
            Set<Decimal> mrps = new Set<Decimal>();
            Set<Decimal> weights = new Set<Decimal>();
            for (Product__c p : [
                SELECT Id, Name, MRP__c, Net_Weight__c
                FROM Product__c
                WHERE Id IN :uniqueProductIds
            ]) {
                mrps.add(p.MRP__c);
                weights.add(p.Net_Weight__c);
            }
            if (mrps.size() > 1) {
                throw new AuraHandledException('Mixed MRP not allowed for Price Division.');
            }
            if (weights.size() > 1) {
                throw new AuraHandledException('Mixed Net Weight not allowed for Price Division.');
            }
            derivedMrp = mrps.isEmpty() ? null : new List<Decimal>(mrps)[0];
            derivedNetWeight = weights.isEmpty() ? null : new List<Decimal>(weights)[0];
        }

        List<ConflictRow> conflicts = getConflictingProductIds(
            header.salesChannel,
            new List<Id>(uniqueProductIds),
            existingId
        );
        if (!conflicts.isEmpty()) {
            Set<String> groupNames = new Set<String>();
            for (ConflictRow c : conflicts) {
                groupNames.add(c.groupName);
            }
            throw new AuraHandledException(
                'One or more SKUs are already in another active group for this channel: ' +
                String.join(new List<String>(groupNames), ', ')
            );
        }

        validateProductsVsActiveFocSchemes(uniqueProductIds, header);

        Scheme_Product_Group__c grp;
        if (existingId == null) {
            grp = new Scheme_Product_Group__c();
        } else {
            grp = new Scheme_Product_Group__c(Id = existingId);
        }
        grp.Name             = header.groupLabel.trim();
        grp.Sales_Channel__c = header.salesChannel;
        grp.Group_Purpose__c = header.groupPurpose;
        grp.MRP__c           = derivedMrp;
        grp.Net_Weight__c    = derivedNetWeight;
        grp.Description__c   = header.description;
        grp.Is_Active__c     = header.isActive == null ? true : header.isActive;
        upsert grp;

        if (existingId != null) {
            delete [
                SELECT Id
                FROM Scheme_Product_Group_Item__c
                WHERE Scheme_Product_Group__c = :existingId
            ];
        }

        List<Scheme_Product_Group_Item__c> items = new List<Scheme_Product_Group_Item__c>();
        for (Id pid : uniqueProductIds) {
            items.add(new Scheme_Product_Group_Item__c(
                Scheme_Product_Group__c = grp.Id,
                Product__c = pid
            ));
        }
        insert items;

        return grp.Id;
    }
}