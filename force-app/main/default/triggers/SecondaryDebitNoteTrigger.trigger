trigger SecondaryDebitNoteTrigger on Secondary_Debit_Note__c (after insert) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            SecondaryCreditNoteAllocationHandler.consumeOpenCreditsForDebitNotes(Trigger.new);
        }
    }
}
