/****************************************************************
* Class Name : FocusedPackController
* Company : Fingertipplus
* @description : Controller for the focusedPackForm LWC. Provides
*                picklist values, channel-filtered SKU lookup and
*                save logic for the Focused Pack header & line items.
******************************************************************/
public with sharing class FocusedPackController {

    public class FocusedPackPicklists {
        @AuraEnabled public List<PicklistOption> salesChannels { get; set; }
        @AuraEnabled public List<PicklistOption> categories { get; set; }
        @AuraEnabled public List<PicklistOption> productGroups { get; set; }
        @AuraEnabled public List<PicklistOption> productSubGroups { get; set; }
    }

    public class PicklistOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class SkuRow {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String skuCode { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public String productGroup { get; set; }
        @AuraEnabled public String productSubGroup { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static FocusedPackPicklists getPicklists() {
        FocusedPackPicklists result = new FocusedPackPicklists();
        result.salesChannels    = describePicklist(Focused_Pack__c.Sales_Channel__c.getDescribe());
        result.categories       = describePicklist(Product__c.Category__c.getDescribe());
        result.productGroups    = describePicklist(Product__c.Product_Group__c.getDescribe());
        result.productSubGroups = describePicklist(Product__c.Product_Sub_Group__c.getDescribe());
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
    public static Boolean isNameAvailable(String name) {
        if (String.isBlank(name)) {
            return false;
        }
        Integer count = [
            SELECT COUNT()
            FROM Focused_Pack__c
            WHERE Name = :name.trim()
            LIMIT 1
        ];
        return count == 0;
    }

    @AuraEnabled
    public static List<SkuRow> getSkusForChannel(
        String salesChannel,
        String category,
        String productGroup,
        String productSubGroup,
        String searchTerm
    ) {
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

        String soql =
            'SELECT Id, Name, SKU_Code__c, Category__c, ' +
            'Product_Group__c, Product_Sub_Group__c ' +
            'FROM Product__c ' +
            'WHERE Id IN :productIds AND Is_Active__c = true';

        if (String.isNotBlank(category)) {
            soql += ' AND Category__c = :category';
        }
        if (String.isNotBlank(productGroup)) {
            soql += ' AND Product_Group__c = :productGroup';
        }
        if (String.isNotBlank(productSubGroup)) {
            soql += ' AND Product_Sub_Group__c = :productSubGroup';
        }

        String likeTerm;
        if (String.isNotBlank(searchTerm)) {
            likeTerm = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
            soql += ' AND (Name LIKE :likeTerm OR SKU_Code__c LIKE :likeTerm)';
        }

        soql += ' ORDER BY Name LIMIT 1000';

        List<SkuRow> rows = new List<SkuRow>();
        for (Product__c p : (List<Product__c>) Database.query(soql)) {
            SkuRow row = new SkuRow();
            row.id              = p.Id;
            row.name            = p.Name;
            row.skuCode         = p.SKU_Code__c;
            row.category        = p.Category__c;
            row.productGroup    = p.Product_Group__c;
            row.productSubGroup = p.Product_Sub_Group__c;
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled
    public static Id saveFocusedPack(
        String name,
        String salesChannel,
        Decimal minimumQuantity,
        List<Id> skuIds
    ) {
        if (String.isBlank(name)) {
            throw new AuraHandledException('Focused Pack Name is required.');
        }
        if (String.isBlank(salesChannel)) {
            throw new AuraHandledException('Sales Channel is required.');
        }
        if (skuIds == null || skuIds.isEmpty()) {
            throw new AuraHandledException('Select at least one SKU.');
        }
        if (!isNameAvailable(name)) {
            throw new AuraHandledException('A Focused Pack with this name already exists.');
        }

        Focused_Pack__c header = new Focused_Pack__c(
            Name = name.trim(),
            Sales_Channel__c = salesChannel,
            Minimum_Qualifying_Quantity__c = minimumQuantity
        );
        insert header;

        List<Focused_Pack_Item__c> items = new List<Focused_Pack_Item__c>();
        for (Id skuId : new Set<Id>(skuIds)) {
            items.add(new Focused_Pack_Item__c(
                Focused_Pack__c = header.Id,
                SKU__c = skuId
            ));
        }
        insert items;

        return header.Id;
    }
}