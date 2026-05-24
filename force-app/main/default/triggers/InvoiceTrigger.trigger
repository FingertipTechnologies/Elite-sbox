trigger InvoiceTrigger on Invoice_item__c (before insert,after insert) {
    if(Trigger.isInsert) {
        if(Trigger.isBefore)
        {
            InvoiceItemTriggerHandler.mapInvoiceItemOwner(Trigger.new);
            InvoiceItemTriggerHandler.linkOrderItems(Trigger.new);
        }
        else
        {
            InvoiceItemTriggerHandler.handleAfterInsert(Trigger.new);
        }
    }
}