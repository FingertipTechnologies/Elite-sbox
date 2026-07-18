trigger SecondaryInvoiceSharingTrigger on Secondary_Invoice__c (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            SecondaryInvoiceSharingHandler.handleAfterInsert(Trigger.new);
            SecondaryCreditNoteAllocationHandler.consumeOpenCreditsForInvoices(Trigger.new);
        }
        if (Trigger.isUpdate) {
            SecondaryInvoiceSharingHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}