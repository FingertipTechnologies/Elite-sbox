/**
 * Controller for the S&D Parameter Setup screen (Primary PBIS, Task 1).
 *
 * The setup LWC (sdParameterBuilder) reuses TAM_TargetCriteria_Controller.getAllObjects
 * for the object picker; field lists come from getObjectFields here (a thin wrapper over
 * TAM_FieldMetadata_Service that drops self-referential relationship fields such as
 * MasterRecord.* / Parent.*). This class also persists S_D_Parameter__c, supplies the
 * Focused Pack option list, and generates the aggregate SOQL used by the achievement
 * calculation (Task 4).
 */
public with sharing class SDParameter_Controller {

    /** Upsert an S&D Parameter and return the saved record (with Id) for navigation. */
    @AuraEnabled
    public static S_D_Parameter__c save(S_D_Parameter__c parameter) {
        if (parameter == null) {
            throw new AuraHandledException('No parameter provided to save.');
        }
        try {
            // Always (re)generate and store the SOQL so it matches the current config.
            parameter.SOQL_Query__c = buildSoql(parameter);
            upsert parameter;
            return getParameter(parameter.Id);
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }

    /** Hydrate an existing S&D Parameter for the edit form. */
    @AuraEnabled(cacheable=false)
    public static S_D_Parameter__c getParameter(Id parameterId) {
        return [
            SELECT Id, Name, Object__c, Operator__c, Field__c, User_Field__c, Date_Field__c,
                   Focused_Pack__c, Focused_Pack__r.Name, Sales_Channel__c,
                   Filters__c, Filter_Logic__c, SOQL_Query__c, Is_Active__c
            FROM S_D_Parameter__c
            WHERE Id = :parameterId
            LIMIT 1
        ];
    }

    /**
     * Field list for the chosen object, minus self-referential relationship fields
     * (MasterRecord.*, Parent.* on the same object) which are duplicates of the object's
     * own fields. Genuine parent lookups (e.g. Order__r.*) are kept.
     */
    @AuraEnabled(cacheable=true)
    public static List<TAM_FieldMetadata_Service.FieldInfo> getObjectFields(String objectName) {
        List<TAM_FieldMetadata_Service.FieldInfo> all = TAM_FieldMetadata_Service.getFields(objectName);
        Set<String> selfRels = selfRelationshipNames(objectName);
        if (selfRels.isEmpty()) return all;

        List<TAM_FieldMetadata_Service.FieldInfo> out = new List<TAM_FieldMetadata_Service.FieldInfo>();
        for (TAM_FieldMetadata_Service.FieldInfo fi : all) {
            if (fi.apiName != null && fi.apiName.contains('.')
                && selfRels.contains(fi.apiName.substringBefore('.').toLowerCase())) {
                continue; // drop e.g. MasterRecord.Customer_Type__c
            }
            out.add(fi);
        }
        return out;
    }

    /** Focused Pack options for the lookup shown on FOCUS_PACK_* operators. */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getFocusedPacks() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (Focused_Pack__c fp : [
            SELECT Id, Name FROM Focused_Pack__c ORDER BY Name LIMIT 1000
        ]) {
            options.add(new Map<String, String>{ 'label' => fp.Name, 'value' => fp.Id });
        }
        return options;
    }

    /**
     * Build the aggregate SOQL for a parameter so the setup screen can preview the exact
     * query the achievement engine will run, e.g.:
     *   SELECT Order__r.OwnerId, SUM(Non_Taxable_Order_Value__c) total
     *   FROM order_item__c
     *   WHERE Order__r.Order_Date__c >= :startDate AND Order__r.Order_Date__c <= :endDate
     *     AND Order__r.OwnerId IN :userIds
     *   GROUP BY Order__r.OwnerId
     * Filter conditions reuse TAM_FilterEngine_Service so preview == runtime.
     */
    @AuraEnabled
    public static String buildSoql(S_D_Parameter__c parameter) {
        if (parameter == null) return '';
        String op = parameter.Operator__c;

        // Focus-Pack metrics are computed by the engine from the Focused Pack's SKUs.
        if (op == 'FOCUS_PACK_VOLUME' || op == 'FOCUS_PACK_REVENUE') {
            String measure = (op == 'FOCUS_PACK_VOLUME') ? 'quantity' : 'revenue';
            return '-- ' + op + ': computed by the achievement engine.\n'
                + '-- Sums invoice-line ' + measure + ' for SKUs in the selected Focused Pack,\n'
                + '-- grouped by salesperson, within the incentive period (:startDate .. :endDate).';
        }

        if (String.isBlank(parameter.Object__c)) {
            return '-- Select an Object to generate the SOQL.';
        }

        Set<String> selfRels = selfRelationshipNames(parameter.Object__c);
        String userField = stripSelfRel(
            String.isBlank(parameter.User_Field__c) ? 'OwnerId' : parameter.User_Field__c, selfRels);
        String dateField = stripSelfRel(parameter.Date_Field__c, selfRels);
        String sumField = stripSelfRel(parameter.Field__c, selfRels);

        // Aggregate expression
        String agg;
        if (op == 'SUM') {
            if (String.isBlank(sumField)) return '-- Select a Field to SUM to generate the SOQL.';
            agg = 'SUM(' + sumField + ') total';
        } else { // COUNT
            agg = 'COUNT(Id) total';
        }

        // Conditions: period, configured filters (self-rel stripped), then the user gate.
        List<String> conds = new List<String>();
        if (String.isNotBlank(dateField)) {
            conds.add(dateField + ' >= :startDate');
            conds.add(dateField + ' <= :endDate');
        }
        String where = TAM_FilterEngine_Service.buildWhereClause(
            stripSelfRelFromFilters(parameter.Filters__c, selfRels), parameter.Filter_Logic__c);
        if (String.isNotBlank(where)) conds.add(where);
        conds.add(userField + ' IN :userIds');

        return 'SELECT ' + userField + ', ' + agg
            + ' FROM ' + parameter.Object__c
            + ' WHERE ' + String.join(conds, ' AND ')
            + ' GROUP BY ' + userField;
    }

    // ---- helpers ---------------------------------------------------------

    /** Relationship names whose lookup points back to the same object (e.g. MasterRecord, Parent). */
    private static Set<String> selfRelationshipNames(String objectName) {
        Set<String> rels = new Set<String>();
        Schema.SObjectType t = Schema.getGlobalDescribe().get(objectName);
        if (t == null) return rels;
        for (Schema.SObjectField f : t.getDescribe().fields.getMap().values()) {
            Schema.DescribeFieldResult d = f.getDescribe();
            if (d.getType() != Schema.DisplayType.Reference) continue;
            for (Schema.SObjectType r : d.getReferenceTo()) {
                if (r == t && String.isNotBlank(d.getRelationshipName())) {
                    rels.add(d.getRelationshipName().toLowerCase());
                }
            }
        }
        return rels;
    }

    /** Drop a leading self-referential relationship prefix, e.g. MasterRecord.Customer_Type__c -> Customer_Type__c. */
    private static String stripSelfRel(String fieldPath, Set<String> selfRels) {
        if (String.isBlank(fieldPath) || !fieldPath.contains('.')) return fieldPath;
        if (selfRels.contains(fieldPath.substringBefore('.').toLowerCase())) {
            return fieldPath.substringAfter('.');
        }
        return fieldPath;
    }

    /** Rewrite each filter row's field to drop self-referential prefixes before building the WHERE. */
    private static String stripSelfRelFromFilters(String jsonFilters, Set<String> selfRels) {
        if (String.isBlank(jsonFilters) || selfRels.isEmpty()) return jsonFilters;
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(jsonFilters);
            List<Object> rows = (List<Object>) root.get('filters');
            if (rows == null) return jsonFilters;
            for (Object r : rows) {
                Map<String, Object> row = (Map<String, Object>) r;
                Object fld = row.get('field');
                if (fld != null) row.put('field', stripSelfRel((String) fld, selfRels));
            }
            return JSON.serialize(root);
        } catch (Exception e) {
            return jsonFilters; // leave untouched if anything unexpected
        }
    }
}
