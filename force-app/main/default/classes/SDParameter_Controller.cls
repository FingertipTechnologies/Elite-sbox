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
            // For the multi-object unique-customer operator, generate one runnable query per
            // source (object + customer field) and store them in Source_Config__c. Otherwise the
            // single aggregate SOQL is generated; clear Source_Config__c so stale config can't run.
            if (parameter.Operator__c == 'MULTI_OBJECT_DISTINCT') {
                parameter.Source_Config__c = buildSourceConfig(parameter.Source_Config__c);
            } else {
                parameter.Source_Config__c = null;
            }
            // Always (re)generate and store the SOQL so it matches the current config.
            parameter.SOQL_Query__c = buildSoql(parameter);
            // Stable external id (Sales Channel | Name) so PBIS Target imports can match this parameter.
            parameter.External_Id__c =
                (String.isNotBlank(parameter.Sales_Channel__c) ? parameter.Sales_Channel__c + ' | ' : '')
                + parameter.Name;
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
                   SKU_Field__c, Focused_Pack__c, Focused_Pack__r.Name, Sales_Channel__c,
                   Filters__c, Filter_Logic__c, SOQL_Query__c, Source_Config__c,
                   Is_Mandatory__c, Is_Active__c
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

    /** Focused Pack options for the lookup shown on FOCUS_PACK_* operators, scoped to the
     *  chosen Sales Channel (Focused_Pack__c.Sales_Channel__c). Blank channel returns none so
     *  the user picks a channel first. */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getFocusedPacks(String salesChannel) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        if (String.isBlank(salesChannel)) return options;
        for (Focused_Pack__c fp : [
            SELECT Id, Name FROM Focused_Pack__c
            WHERE Sales_Channel__c = :salesChannel
            ORDER BY Name LIMIT 1000
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
        Boolean isFocusPack = (op == 'FOCUS_PACK_VOLUME' || op == 'FOCUS_PACK_REVENUE');

        // Multi-object unique customers: there is no single SOQL (SOQL has no cross-object
        // UNION). Show the per-source queries that PBISActuals_Service runs and unions.
        if (op == 'MULTI_OBJECT_DISTINCT') {
            return buildMultiPreview(buildSourceConfig(parameter.Source_Config__c));
        }

        if (String.isBlank(parameter.Object__c)) {
            return '-- Select an Object to generate the SOQL.';
        }

        Set<String> selfRels = selfRelationshipNames(parameter.Object__c);
        String userField = stripSelfRel(
            String.isBlank(parameter.User_Field__c) ? 'OwnerId' : parameter.User_Field__c, selfRels);
        String dateField = stripSelfRel(parameter.Date_Field__c, selfRels);
        String measureField = stripSelfRel(parameter.Field__c, selfRels);

        // Aggregate expression: COUNT counts rows; COUNT_DISTINCT counts unique values of
        // the chosen field; SUM and Focus Pack sum the measure field.
        String agg;
        if (op == 'COUNT') {
            agg = 'COUNT(Id) total';
        } else if (op == 'COUNT_DISTINCT') {
            if (String.isBlank(measureField)) {
                return '-- Select a Field to count distinct values to generate the SOQL.';
            }
            agg = 'COUNT_DISTINCT(' + measureField + ') total';
        } else {
            if (String.isBlank(measureField)) {
                return '-- Select a Field to ' + (isFocusPack ? 'aggregate' : 'SUM') + ' to generate the SOQL.';
            }
            agg = 'SUM(' + measureField + ') total';
        }

        List<String> conds = new List<String>();

        // Focus Pack: restrict to the pack's SKUs via a semi-join on Focused_Pack_Item__c.
        // The match field is the chosen SKU Field on the source object (e.g. Product__c);
        // if left blank, fall back to auto-detecting the object's lookup to Product__c.
        if (isFocusPack) {
            if (parameter.Focused_Pack__c == null) return '-- Select a Focused Pack to generate the SOQL.';
            String productField = stripSelfRel(parameter.SKU_Field__c, selfRels);
            if (String.isBlank(productField)) productField = detectProductField(parameter.Object__c);
            if (String.isBlank(productField)) {
                return '-- Select a SKU Field (product field matched to the Focused Pack) to generate the SOQL.';
            }
            conds.add(productField + ' IN (SELECT SKU__c FROM Focused_Pack_Item__c WHERE Focused_Pack__c = \''
                + parameter.Focused_Pack__c + '\')');
        }

        // Period scope
        if (String.isNotBlank(dateField)) {
            conds.add(dateField + ' >= :startDate');
            conds.add(dateField + ' <= :endDate');
        }
        // Configured filters (self-rel stripped)
        String whereClause = TAM_FilterEngine_Service.buildWhereClause(
            stripSelfRelFromFilters(parameter.Filters__c, selfRels), parameter.Filter_Logic__c);
        if (String.isNotBlank(whereClause)) conds.add(whereClause);
        // User gate
        conds.add(userField + ' IN :userIds');

        // The user field is aliased `uid` so a grouped query (one run for many users)
        // can be split back per user by PBISActuals_Service. GROUP BY stays on the raw field.
        return 'SELECT ' + userField + ' uid, ' + agg
            + ' FROM ' + parameter.Object__c
            + ' WHERE ' + String.join(conds, ' AND ')
            + ' GROUP BY ' + userField;
    }

    // ---- multi-object unique customers -----------------------------------

    /**
     * For the MULTI_OBJECT_DISTINCT operator: regenerate each source's runnable query from its
     * definition (object + customer/user/date fields + filters) and store it back on the source.
     * Input/output JSON: {"sources":[{object, customerField, userField, dateField, filters,
     * filterLogic, soql}]}. PBISActuals_Service runs each `soql` and unions the `cust` values.
     */
    private static String buildSourceConfig(String configJson) {
        if (String.isBlank(configJson)) return configJson;
        Map<String, Object> root;
        try {
            root = (Map<String, Object>) JSON.deserializeUntyped(configJson);
        } catch (Exception e) {
            return configJson;
        }
        List<Object> rows = (List<Object>) root.get('sources');
        if (rows == null) return configJson;
        for (Object r : rows) {
            Map<String, Object> src = (Map<String, Object>) r;
            src.put('soql', buildSourceSoql(src));
        }
        return JSON.serialize(root);
    }

    /**
     * One source = one (object, customer field). Mirrors buildSoql but selects the customer
     * field as `cust` and groups by user + customer so the DB de-dupes pairs:
     *   SELECT <userField> uid, <customerField> cust FROM <object>
     *   WHERE <dateField> >= :startDate AND <dateField> <= :endDate AND (<filters>)
     *     AND <userField> IN :userIds
     *   GROUP BY <userField>, <customerField>
     */
    private static String buildSourceSoql(Map<String, Object> src) {
        String objectName = (String) src.get('object');
        String customerFieldRaw = (String) src.get('customerField');
        if (String.isBlank(objectName) || String.isBlank(customerFieldRaw)) return '';

        Set<String> selfRels = selfRelationshipNames(objectName);
        String userField = stripSelfRel(
            String.isBlank((String) src.get('userField')) ? 'OwnerId' : (String) src.get('userField'), selfRels);
        String customerField = stripSelfRel(customerFieldRaw, selfRels);
        String dateField = stripSelfRel((String) src.get('dateField'), selfRels);

        List<String> conds = new List<String>();
        if (String.isNotBlank(dateField)) {
            conds.add(dateField + ' >= :startDate');
            conds.add(dateField + ' <= :endDate');
        }
        String whereClause = TAM_FilterEngine_Service.buildWhereClause(
            stripSelfRelFromFilters((String) src.get('filters'), selfRels), (String) src.get('filterLogic'));
        if (String.isNotBlank(whereClause)) conds.add(whereClause);
        conds.add(userField + ' IN :userIds');

        return 'SELECT ' + userField + ' uid, ' + customerField + ' cust'
            + ' FROM ' + objectName
            + ' WHERE ' + String.join(conds, ' AND ')
            + ' GROUP BY ' + userField + ', ' + customerField;
    }

    /** Readable preview of the per-source queries (the engine runs these and unions `cust`). */
    private static String buildMultiPreview(String sourceConfig) {
        if (String.isBlank(sourceConfig)) {
            return '-- Add at least one source (object + customer field) to generate the queries.';
        }
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(sourceConfig);
            List<Object> rows = (List<Object>) root.get('sources');
            if (rows == null || rows.isEmpty()) return '-- Add at least one source.';
            List<String> parts = new List<String>();
            Integer i = 1;
            for (Object r : rows) {
                Map<String, Object> src = (Map<String, Object>) r;
                parts.add('-- Source ' + (i++) + ' (' + src.get('object') + ' -> ' + src.get('customerField')
                    + ')\n' + (String) src.get('soql'));
            }
            return '-- Unique customers = distinct union of `cust` across these sources, per user:\n\n'
                + String.join(parts, '\n\n');
        } catch (Exception e) {
            return '-- (could not build preview)';
        }
    }

    // ---- helpers ---------------------------------------------------------

    /**
     * The object's product/SKU field for Focus-Pack matching: the lookup whose referenceTo
     * is the Product__c object (the same object Focused_Pack_Item__c.SKU__c points to).
     * Prefers a field named Product__c, then SKU__c, then the first Product__c-referencing
     * lookup. Returns null if the object has none.
     */
    private static String detectProductField(String objectName) {
        Schema.SObjectType t = Schema.getGlobalDescribe().get(objectName);
        if (t == null) return null;
        String preferred;
        String fallback;
        for (Schema.SObjectField f : t.getDescribe().fields.getMap().values()) {
            Schema.DescribeFieldResult d = f.getDescribe();
            if (d.getType() != Schema.DisplayType.Reference) continue;
            Boolean toProduct = false;
            for (Schema.SObjectType r : d.getReferenceTo()) {
                if (r != null && r.getDescribe().getName() == 'Product__c') { toProduct = true; break; }
            }
            if (!toProduct) continue;
            String api = d.getName();
            if (api == 'Product__c' || api == 'SKU__c') {
                preferred = api; // exact conventional names win
            } else if (fallback == null) {
                fallback = api;
            }
        }
        return preferred != null ? preferred : fallback;
    }

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