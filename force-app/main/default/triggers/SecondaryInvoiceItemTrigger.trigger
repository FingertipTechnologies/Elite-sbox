/**
 * Trigger for Secondary_Invoice_Item__c.
 *
 * Kept intentionally "thin" - it does no logic of its own. It only figures out
 * which Order_Item__c records are affected by this DML event and hands that
 * off to the handler class. All business logic lives in
 * SecondaryInvoiceItemTriggerHandler so it stays testable outside of a
 * trigger context.
 *
 * Only AFTER contexts are used because the handler's recalculation queries
 * Secondary_Invoice_Item__c fresh via SOQL (SUM aggregate). That query only
 * sees this record's change once it has actually been committed to the
 * (in-transaction) database, i.e. after insert/update/delete/undelete.
 */
trigger SecondaryInvoiceItemTrigger on Secondary_Invoice_Item__c (
    after insert,
    after update,
    after delete,
    after undelete
) {
    SecondaryInvoiceItemTriggerHandler.handleTrigger(
        Trigger.new,
        Trigger.old,
        Trigger.isDelete
    );
}