trigger PBIS_TargetTrigger on PBIS_Target__c (before insert, before update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            PBIS_TargetTriggerHandler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            PBIS_TargetTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}