public without sharing class ForecastSubmissionController {

    public class SaveResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id recordId;
        @AuraEnabled public String message;
    }

    public class SkuOption {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String DeliveryPlant;
    }

    @AuraEnabled(cacheable=true)
    public static List<Product__c> getProductsBySubGroup(String subGroup) {
        if (String.isBlank(subGroup)) {
            return new List<Product__c>();
        }
        return [
            SELECT Id, Name, SKU_Code__c, Product_Code__c
            FROM Product__c
            WHERE Product_Sub_Group__c = :subGroup
              AND Is_Active__c = true
            ORDER BY Name ASC
            LIMIT 500
        ];
    }

    @AuraEnabled(cacheable=false)
    public static List<SkuOption> searchProducts(Id distributorId, String subGroup, String searchKey) {
        List<SkuOption> result = new List<SkuOption>();
        if (distributorId == null || String.isBlank(subGroup)) {
            return result;
        }
        system.debug('distributorId'+distributorId +'-'+'subGroup'+subGroup +'-'+'searchKey'+searchKey );

        Account dist = [
            SELECT Id, Sales_Channel__c
            FROM Account
            WHERE Id = :distributorId
            LIMIT 1
        ];
        String salesChannel = dist.Sales_Channel__c;
        if (String.isBlank(salesChannel)) {
            return result;
        }
        
        Set<String> salesChannelSet = new Set<String>();
        
        if (!String.isBlank(salesChannel)) {
            salesChannelSet.addAll(salesChannel.split(','));
        }
        system.debug('salesChannel'+salesChannel);

        String key = '%' + (searchKey == null ? '' : searchKey.trim()) + '%';

        List<Sales_Channel_To_SKU__c> channels = [
            SELECT Id, Name, SKU__c, SKU__r.Name, Delivery_Plant__c
            FROM Sales_Channel_To_SKU__c
            WHERE Sales_Channel__c In: salesChannelSet
              AND SKU__r.Product_Sub_Group__c = :subGroup
              AND SKU__r.Is_Active__c = true
              AND SKU__r.Name LIKE :key
            ORDER BY SKU__r.Name ASC
            LIMIT 50
        ];

        Set<Id> seen = new Set<Id>();
        for (Sales_Channel_To_SKU__c c : channels) {
            if (c.SKU__c == null || seen.contains(c.SKU__c)) continue;
            seen.add(c.SKU__c);
            SkuOption o = new SkuOption();
            o.Id = c.SKU__c;
            o.Name = c.SKU__r != null ? c.SKU__r.Name : null;
            o.DeliveryPlant = c.Delivery_Plant__c;
            result.add(o);
        }
        system.debug('result'+result);
        return result;
    }

    @AuraEnabled
    public static SaveResult saveAndSubmit(Product_Forecast__c record) {
        SaveResult res = new SaveResult();
        Savepoint sp = Database.setSavepoint();
        try {
            if (record == null) {
                res.success = false;
                res.message = 'Forecast record is required.';
                return res;
            }

            record.Is_Monthly_Forecast__c = true;
            record.Approval_Status__c = 'Submitted for Approval';
            record.Submitted_Date__c = System.now();

            if (record.Id == null) {
                insert record;
            } else {
                update record;
            }

            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setComments('Forecast submitted by ' + UserInfo.getName());
            req.setObjectId(record.Id);
            Approval.ProcessResult result = Approval.process(req);

            if (result.isSuccess()) {
                res.success = true;
                res.recordId = record.Id;
                res.message = 'Forecast submitted for approval.';
            } else {
                Database.rollback(sp);
                res.success = false;
                res.recordId = record.Id;
                res.message = result.getErrors().isEmpty()
                    ? 'Approval submission failed.'
                    : result.getErrors()[0].getMessage();
            }
            return res;
        } catch (Exception e) {
            Database.rollback(sp);
            res.success = false;
            res.message = e.getMessage();
            return res;
        }
    }
}