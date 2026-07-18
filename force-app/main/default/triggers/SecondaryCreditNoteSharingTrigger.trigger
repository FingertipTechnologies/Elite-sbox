trigger SecondaryCreditNoteSharingTrigger on Secondary_Credit_Note__c (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            SecondaryCreditNoteSharingHandler.handleAfterInsert(Trigger.new);
            SecondaryCreditNoteAllocationHandler.allocateCreditNotes(Trigger.new);
        }
        if (Trigger.isUpdate) {
            SecondaryCreditNoteSharingHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}