/**
 * UI controller for the Secondary PBIS slab manager and monthly console.
 */
public with sharing class SecondaryPBIS_Controller {

    public class MonthlyTotal {
        @AuraEnabled public Id executiveId;
        @AuraEnabled public String executiveName;
        @AuraEnabled public String salesChannel;
        @AuraEnabled public Decimal total;
        @AuraEnabled public Integer lineCount;
    }

    // ===== Slab CRUD =====

    @AuraEnabled(cacheable=false)
    public static List<Incentive_Slab__c> getSlabs(String channel, String criteriaId, Boolean activeOnly) {
        String q =
            'SELECT Id, Name, Target_Criteria__c, Target_Criteria__r.Name, Target_Criteria__r.Operator__c, ' +
            'Sales_Channel__c, Focused_Pack__c, Focused_Pack__r.Name, Compare_On__c, ' +
            'Achievement_From__c, Achievement_To__c, Incentive_Amount__c, Active__c ' +
            'FROM Incentive_Slab__c WHERE Target_Criteria__c != NULL';
        if (String.isNotBlank(channel)) q += ' AND Sales_Channel__c = :channel';
        if (String.isNotBlank(criteriaId)) q += ' AND Target_Criteria__c = :criteriaId';
        if (activeOnly == true) q += ' AND Active__c = true';
        q += ' ORDER BY Target_Criteria__r.Name, Sales_Channel__c, Achievement_From__c LIMIT 1000';
        return Database.query(q);
    }

    @AuraEnabled
    public static Incentive_Slab__c saveSlab(Incentive_Slab__c slab) {
        upsert slab;
        return [
            SELECT Id, Name, Target_Criteria__c, Target_Criteria__r.Name,
                   Sales_Channel__c, Focused_Pack__c, Focused_Pack__r.Name,
                   Compare_On__c, Achievement_From__c, Achievement_To__c,
                   Incentive_Amount__c, Active__c
            FROM Incentive_Slab__c WHERE Id = :slab.Id
        ];
    }

    @AuraEnabled
    public static void deleteSlab(Id slabId) {
        delete [SELECT Id FROM Incentive_Slab__c WHERE Id = :slabId LIMIT 1];
    }

    /** Bulk insert — used by the "Bulk Add Slabs" form. Rejects an empty list. */
    @AuraEnabled
    public static Integer saveSlabs(List<Incentive_Slab__c> slabs) {
        if (slabs == null || slabs.isEmpty()) {
            throw new AuraHandledException('No slabs to save.');
        }
        insert slabs;
        return slabs.size();
    }

    // ===== Option providers (delegate to existing SecondaryTarget_Controller) =====

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCriteriaOptions() {
        return SecondaryTarget_Controller.getCriteriaOptions();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getChannelOptions() {
        return SecondaryTarget_Controller.getChannelOptions();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getFocusedPackOptions() {
        return SecondaryTarget_Controller.getFocusedPackOptions();
    }

    // ===== Run PBIS =====

    @AuraEnabled
    public static SecondaryPBIS_Service.PbisRunResult runMonth(Integer year, Integer month) {
        if (year == null || month == null || month < 1 || month > 12) {
            throw new AuraHandledException('Year and month (1-12) are required.');
        }
        return SecondaryPBIS_Service.computeForMonth(year, month);
    }

    @AuraEnabled(cacheable=false)
    public static List<SecondaryPBIS_Service.SkippedTargetInfo> getOverlappingTargets(Integer year, Integer month) {
        if (year == null || month == null || month < 1 || month > 12) return new List<SecondaryPBIS_Service.SkippedTargetInfo>();
        return SecondaryPBIS_Service.findOverlappingTargets(year, month);
    }

    @AuraEnabled
    public static Id runMonthAsync(Integer year, Integer month) {
        if (year == null || month == null || month < 1 || month > 12) {
            throw new AuraHandledException('Year and month (1-12) are required.');
        }
        return System.enqueueJob(new SecondaryPBISQueueable(year, month));
    }

    // ===== Results =====

    @AuraEnabled(cacheable=false)
    public static List<MonthlyTotal> getUserMonthlyTotals(Integer year, Integer month) {
        List<MonthlyTotal> result = new List<MonthlyTotal>();
        if (year == null || month == null) return result;

        // Aggregate per Executive + Channel.
        for (AggregateResult ar : [
            SELECT Executive__c uid, Sales_Channel__c ch,
                   SUM(Credit_Amount__c) total, COUNT(Id) lineCount
            FROM Incentive_Credit__c
            WHERE Source__c = 'Secondary PBIS'
              AND Year__c = :year AND Month__c = :month
            GROUP BY Executive__c, Sales_Channel__c
            ORDER BY Executive__c
        ]) {
            MonthlyTotal mt = new MonthlyTotal();
            mt.executiveId = (Id) ar.get('uid');
            mt.salesChannel = (String) ar.get('ch');
            mt.total = (Decimal) ar.get('total');
            mt.lineCount = (Integer) ar.get('lineCount');
            result.add(mt);
        }

        // Resolve names in one batch.
        Set<Id> ids = new Set<Id>();
        for (MonthlyTotal mt : result) if (mt.executiveId != null) ids.add(mt.executiveId);
        Map<Id, User> nameMap = new Map<Id, User>([SELECT Id, Name FROM User WHERE Id IN :ids]);
        for (MonthlyTotal mt : result) {
            if (mt.executiveId != null && nameMap.containsKey(mt.executiveId)) {
                mt.executiveName = nameMap.get(mt.executiveId).Name;
            }
        }
        return result;
    }

    /** Flat per-incentive-row export for the whole month — every user, every criterion. */
    @AuraEnabled(cacheable=false)
    public static List<Incentive_Credit__c> getAllMonthlyRows(Integer year, Integer month) {
        if (year == null || month == null) return new List<Incentive_Credit__c>();
        return [
            SELECT Id, Executive__c, Executive__r.Name, User_Name__c, Sales_Channel__c, Year__c, Month__c,
                   Target_Criteria__c, Target_Criteria__r.Name, Target_Criteria__r.Operator__c,
                   Focused_Pack__c, Focused_Pack__r.Name, Matched_Slab__c,
                   Matched_Slab__r.Achievement_From__c, Matched_Slab__r.Achievement_To__c,
                   Matched_Slab__r.Incentive_Amount__c,
                   Secondary_Target__c, Secondary_Target__r.Name,
                   Achievement_Value__c, Achievement_Percent__c, Compare_On__c,
                   Credit_Amount__c, Computed_At__c
            FROM Incentive_Credit__c
            WHERE Source__c = 'Secondary PBIS'
              AND Year__c = :year AND Month__c = :month
            ORDER BY Executive__r.Name, Target_Criteria__r.Name
        ];
    }

    @AuraEnabled(cacheable=false)
    public static List<Incentive_Credit__c> getUserMonthlyRows(Id executiveId, Integer year, Integer month) {
        return [
            SELECT Id, Executive__c, User_Name__c, Sales_Channel__c, Year__c, Month__c,
                   Target_Criteria__c, Target_Criteria__r.Name, Target_Criteria__r.Operator__c,
                   Focused_Pack__c, Focused_Pack__r.Name, Matched_Slab__c,
                   Matched_Slab__r.Achievement_From__c, Matched_Slab__r.Achievement_To__c,
                   Matched_Slab__r.Incentive_Amount__c,
                   Secondary_Target__c, Secondary_Target__r.Name,
                   Achievement_Value__c, Achievement_Percent__c,
                   Compare_On__c, Credit_Amount__c, Computed_At__c
            FROM Incentive_Credit__c
            WHERE Source__c = 'Secondary PBIS'
              AND Year__c = :year AND Month__c = :month
              AND Executive__c = :executiveId
            ORDER BY Target_Criteria__r.Name, Focused_Pack__r.Name
        ];
    }
}