/**
 * Controller for the S&D Parameter Setup screen (Primary PBIS, Task 1).
 *
 * The setup LWC (sdParameterBuilder) reuses TAM_TargetCriteria_Controller.getAllObjects
 * and TAM_FieldMetadata_Service.getFields for the object/field pickers; this class adds
 * the create/edit persistence for S_D_Parameter__c plus the Focused Pack option list.
 */
public with sharing class SDParameter_Controller {

    /** Upsert an S&D Parameter and return the saved record (with Id) for navigation. */
    @AuraEnabled
    public static S_D_Parameter__c save(S_D_Parameter__c parameter) {
        if (parameter == null) {
            throw new AuraHandledException('No parameter provided to save.');
        }
        try {
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
                   Filters__c, Filter_Logic__c, Is_Active__c
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
}
