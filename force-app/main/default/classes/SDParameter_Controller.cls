/**
 * Controller for the S&D Parameter Setup screen (Primary PBIS, Task 1).
 *
 * The setup LWC (sdParameterBuilder) reuses TAM_TargetCriteria_Controller.getAllObjects
 * and TAM_FieldMetadata_Service.getFields for the object/field pickers; this class adds
 * the create/edit persistence for S_D_Parameter__c, the Focused Pack option list, and
 * generation of the aggregate SOQL used by the achievement calculation (Task 4).
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
            SELECT Id, Name, Object__c, Operator__c, Field__c, User_Field__c,
                   Focused_Pack__c, Focused_Pack__r.Name, Sales_Channel__c,
                   Filters__c, Filter_Logic__c, SOQL_Query__c, Is_Active__c
            FROM S_D_Parameter__c
            WHERE Id = :parameterId
            LIMIT 1
        ];
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
     * Build the aggregate SOQL for a parameter from its configuration so the setup
     * screen can preview the exact query the achievement engine will run.
     * The filter WHERE clause is built with TAM_FilterEngine_Service (the same one
     * the engine uses). The period date filter is injected at calculation time and
     * is shown here as a :startDate / :endDate placeholder note.
     */
    @AuraEnabled
    public static String buildSoql(S_D_Parameter__c parameter) {
        if (parameter == null) return '';
        String op = parameter.Operator__c;

        // Focus-Pack metrics are computed by the engine from the Focused Pack's SKUs,
        // not a single aggregate over a configured object/field.
        if (op == 'FOCUS_PACK_VOLUME' || op == 'FOCUS_PACK_REVENUE') {
            String measure = (op == 'FOCUS_PACK_VOLUME') ? 'quantity' : 'revenue';
            return '-- ' + op + ': computed by the achievement engine.\n'
                + '-- Sums invoice-line ' + measure + ' for SKUs in the selected Focused Pack,\n'
                + '-- grouped by salesperson, within the incentive period (:startDate .. :endDate).';
        }

        if (String.isBlank(parameter.Object__c)) {
            return '-- Select an Object to generate the SOQL.';
        }
        String userField = String.isBlank(parameter.User_Field__c) ? 'OwnerId' : parameter.User_Field__c;

        // Aggregate expression
        String agg;
        if (op == 'SUM') {
            if (String.isBlank(parameter.Field__c)) return '-- Select a Field to SUM to generate the SOQL.';
            agg = 'SUM(' + parameter.Field__c + ') total';
        } else { // COUNT
            agg = 'COUNT(Id) total';
        }

        // WHERE — reuse the engine's filter builder so preview == runtime.
        String where = TAM_FilterEngine_Service.buildWhereClause(parameter.Filters__c, parameter.Filter_Logic__c);

        String soql = 'SELECT ' + userField + ', ' + agg
            + ' FROM ' + parameter.Object__c;

        if (String.isNotBlank(where)) soql += ' WHERE ' + where;
        soql += ' GROUP BY ' + userField;
        soql += '\n-- Period filter (:startDate .. :endDate) on the date field is applied at calculation time.';

        return soql;
    }
}
