public class SecondaryCreditNoteAllocationHandler {

    // Guard: item inserts recalc parent rollups which re-fire parent triggers
    public static Boolean isAllocating = false;

    /**
     * Entry 1 — after insert of Secondary_Credit_Note__c.
     * Applies each new credit note against the customer's pending documents,
     * greedy oldest-first: invoices (Invoice_Date__c ASC) then debit notes (Note_Date__c ASC).
     * Leftover credit stays on the note (Status Open / Partially Paid).
     */
    public static void allocateCreditNotes(List<Secondary_Credit_Note__c> newNotes) {
        if (isAllocating) {
            return;
        }
        Set<Id> customerIds = new Set<Id>();
        for (Secondary_Credit_Note__c cn : newNotes) {
            if (cn.Customer__c != null && cn.Amount__c != null && cn.Amount__c > 0) {
                customerIds.add(cn.Customer__c);
            }
        }
        if (customerIds.isEmpty()) {
            return;
        }

        // Pending documents per customer, oldest first. Pending_Amount__c is a
        // formula (read-only), so the running remainder lives in pendingByDoc.
        Map<Id, Decimal> pendingByDoc = new Map<Id, Decimal>();
        Map<Id, List<Id>> invoiceIdsByCustomer = new Map<Id, List<Id>>();
        for (Secondary_Invoice__c inv : [
            SELECT Id, Customer__c, Pending_Amount__c
            FROM Secondary_Invoice__c
            WHERE Customer__c IN :customerIds AND Pending_Amount__c > 0
            ORDER BY Invoice_Date__c ASC
        ]) {
            pendingByDoc.put(inv.Id, inv.Pending_Amount__c);
            if (!invoiceIdsByCustomer.containsKey(inv.Customer__c)) {
                invoiceIdsByCustomer.put(inv.Customer__c, new List<Id>());
            }
            invoiceIdsByCustomer.get(inv.Customer__c).add(inv.Id);
        }
        Map<Id, List<Id>> debitNoteIdsByCustomer = new Map<Id, List<Id>>();
        for (Secondary_Debit_Note__c dn : [
            SELECT Id, Customer__c, Pending_Amount__c
            FROM Secondary_Debit_Note__c
            WHERE Customer__c IN :customerIds AND Pending_Amount__c > 0
            ORDER BY Note_Date__c ASC
        ]) {
            pendingByDoc.put(dn.Id, dn.Pending_Amount__c);
            if (!debitNoteIdsByCustomer.containsKey(dn.Customer__c)) {
                debitNoteIdsByCustomer.put(dn.Customer__c, new List<Id>());
            }
            debitNoteIdsByCustomer.get(dn.Customer__c).add(dn.Id);
        }

        List<Secondary_Credit_Note_Item__c> invoiceItems = new List<Secondary_Credit_Note_Item__c>();
        List<Secondary_Credit_Note_Debit_Item__c> debitItems = new List<Secondary_Credit_Note_Debit_Item__c>();
        List<Secondary_Credit_Note__c> statusUpdates = new List<Secondary_Credit_Note__c>();

        for (Secondary_Credit_Note__c cn : newNotes) {
            if (cn.Customer__c == null || cn.Amount__c == null || cn.Amount__c <= 0) {
                continue;
            }
            Decimal remaining = cn.Amount__c;

            // Invoices first, oldest first (pending decremented in pendingByDoc so a
            // second credit note in the same batch cannot over-apply)
            if (invoiceIdsByCustomer.containsKey(cn.Customer__c)) {
                for (Id invId : invoiceIdsByCustomer.get(cn.Customer__c)) {
                    if (remaining <= 0) { break; }
                    Decimal pending = pendingByDoc.get(invId);
                    if (pending == null || pending <= 0) { continue; }
                    Decimal applied = Math.min(pending, remaining);
                    invoiceItems.add(new Secondary_Credit_Note_Item__c(
                        Secondary_Credit_Note__c = cn.Id,
                        Secondary_Invoice__c = invId,
                        Amount__c = applied
                    ));
                    pendingByDoc.put(invId, pending - applied);
                    remaining -= applied;
                }
            }
            // Then debit notes, oldest first
            if (remaining > 0 && debitNoteIdsByCustomer.containsKey(cn.Customer__c)) {
                for (Id dnId : debitNoteIdsByCustomer.get(cn.Customer__c)) {
                    if (remaining <= 0) { break; }
                    Decimal pending = pendingByDoc.get(dnId);
                    if (pending == null || pending <= 0) { continue; }
                    Decimal applied = Math.min(pending, remaining);
                    debitItems.add(new Secondary_Credit_Note_Debit_Item__c(
                        Secondary_Credit_Note__c = cn.Id,
                        Secondary_Debit_Note__c = dnId,
                        Amount__c = applied
                    ));
                    pendingByDoc.put(dnId, pending - applied);
                    remaining -= applied;
                }
            }

            statusUpdates.add(new Secondary_Credit_Note__c(
                Id = cn.Id,
                Status__c = statusFor(cn.Amount__c, remaining)
            ));
        }

        persist(invoiceItems, debitItems, statusUpdates);
    }

    /**
     * Entry 2a — after insert of Secondary_Invoice__c.
     * Consumes the customer's open credit notes (oldest Credit_Date__c first).
     */
    public static void consumeOpenCreditsForInvoices(List<Secondary_Invoice__c> newInvoices) {
        if (isAllocating) {
            return;
        }
        Set<Id> customerIds = new Set<Id>();
        for (Secondary_Invoice__c inv : newInvoices) {
            if (inv.Customer__c != null) {
                customerIds.add(inv.Customer__c);
            }
        }
        OpenCredits credits = loadOpenCredits(customerIds);
        if (credits.notesByCustomer.isEmpty()) {
            return;
        }

        // Re-query so Pending_Amount__c is reliable
        List<Secondary_Credit_Note_Item__c> invoiceItems = new List<Secondary_Credit_Note_Item__c>();
        for (Secondary_Invoice__c inv : [
            SELECT Id, Customer__c, Pending_Amount__c
            FROM Secondary_Invoice__c
            WHERE Id IN :newInvoices AND Pending_Amount__c > 0
            ORDER BY Invoice_Date__c ASC
        ]) {
            Decimal invPending = inv.Pending_Amount__c;
            if (!credits.notesByCustomer.containsKey(inv.Customer__c)) { continue; }
            for (Secondary_Credit_Note__c cn : credits.notesByCustomer.get(inv.Customer__c)) {
                if (invPending <= 0) { break; }
                Decimal unapplied = credits.unappliedByNote.get(cn.Id);
                if (unapplied == null || unapplied <= 0) { continue; }
                Decimal applied = Math.min(unapplied, invPending);
                invoiceItems.add(new Secondary_Credit_Note_Item__c(
                    Secondary_Credit_Note__c = cn.Id,
                    Secondary_Invoice__c = inv.Id,
                    Amount__c = applied
                ));
                credits.unappliedByNote.put(cn.Id, unapplied - applied);
                invPending -= applied;
            }
        }

        persist(invoiceItems, new List<Secondary_Credit_Note_Debit_Item__c>(), credits.buildStatusUpdates());
    }

    /**
     * Entry 2b — after insert of Secondary_Debit_Note__c.
     * Consumes the customer's open credit notes (oldest Credit_Date__c first).
     */
    public static void consumeOpenCreditsForDebitNotes(List<Secondary_Debit_Note__c> newDebitNotes) {
        if (isAllocating) {
            return;
        }
        Set<Id> customerIds = new Set<Id>();
        for (Secondary_Debit_Note__c dn : newDebitNotes) {
            if (dn.Customer__c != null) {
                customerIds.add(dn.Customer__c);
            }
        }
        OpenCredits credits = loadOpenCredits(customerIds);
        if (credits.notesByCustomer.isEmpty()) {
            return;
        }

        List<Secondary_Credit_Note_Debit_Item__c> debitItems = new List<Secondary_Credit_Note_Debit_Item__c>();
        for (Secondary_Debit_Note__c dn : [
            SELECT Id, Customer__c, Pending_Amount__c
            FROM Secondary_Debit_Note__c
            WHERE Id IN :newDebitNotes AND Pending_Amount__c > 0
            ORDER BY Note_Date__c ASC
        ]) {
            Decimal dnPending = dn.Pending_Amount__c;
            if (!credits.notesByCustomer.containsKey(dn.Customer__c)) { continue; }
            for (Secondary_Credit_Note__c cn : credits.notesByCustomer.get(dn.Customer__c)) {
                if (dnPending <= 0) { break; }
                Decimal unapplied = credits.unappliedByNote.get(cn.Id);
                if (unapplied == null || unapplied <= 0) { continue; }
                Decimal applied = Math.min(unapplied, dnPending);
                debitItems.add(new Secondary_Credit_Note_Debit_Item__c(
                    Secondary_Credit_Note__c = cn.Id,
                    Secondary_Debit_Note__c = dn.Id,
                    Amount__c = applied
                ));
                credits.unappliedByNote.put(cn.Id, unapplied - applied);
                dnPending -= applied;
            }
        }

        persist(new List<Secondary_Credit_Note_Item__c>(), debitItems, credits.buildStatusUpdates());
    }

    /**
     * Open credit notes per customer (oldest first). Unapplied_Amount__c is a
     * formula (read-only), so the running remainder lives in unappliedByNote.
     */
    private class OpenCredits {
        Map<Id, List<Secondary_Credit_Note__c>> notesByCustomer = new Map<Id, List<Secondary_Credit_Note__c>>();
        Map<Id, Decimal> unappliedByNote = new Map<Id, Decimal>();
        Map<Id, Decimal> originalUnapplied = new Map<Id, Decimal>();
        Map<Id, Decimal> amountByNote = new Map<Id, Decimal>();

        List<Secondary_Credit_Note__c> buildStatusUpdates() {
            List<Secondary_Credit_Note__c> updates = new List<Secondary_Credit_Note__c>();
            for (Id cnId : unappliedByNote.keySet()) {
                if (unappliedByNote.get(cnId) == originalUnapplied.get(cnId)) {
                    continue; // nothing newly applied to this note
                }
                updates.add(new Secondary_Credit_Note__c(
                    Id = cnId,
                    Status__c = statusFor(amountByNote.get(cnId), unappliedByNote.get(cnId))
                ));
            }
            return updates;
        }
    }

    private static OpenCredits loadOpenCredits(Set<Id> customerIds) {
        OpenCredits credits = new OpenCredits();
        if (customerIds.isEmpty()) {
            return credits;
        }
        for (Secondary_Credit_Note__c cn : [
            SELECT Id, Customer__c, Amount__c, Unapplied_Amount__c
            FROM Secondary_Credit_Note__c
            WHERE Customer__c IN :customerIds AND Unapplied_Amount__c > 0
            ORDER BY Credit_Date__c ASC, Name ASC
        ]) {
            if (!credits.notesByCustomer.containsKey(cn.Customer__c)) {
                credits.notesByCustomer.put(cn.Customer__c, new List<Secondary_Credit_Note__c>());
            }
            credits.notesByCustomer.get(cn.Customer__c).add(cn);
            credits.unappliedByNote.put(cn.Id, cn.Unapplied_Amount__c);
            credits.originalUnapplied.put(cn.Id, cn.Unapplied_Amount__c);
            credits.amountByNote.put(cn.Id, cn.Amount__c);
        }
        return credits;
    }

    private static String statusFor(Decimal amount, Decimal remaining) {
        if (remaining <= 0) {
            return 'Paid';
        }
        if (amount != null && remaining < amount) {
            return 'Partially Paid';
        }
        return 'Open';
    }

    private static void persist(List<Secondary_Credit_Note_Item__c> invoiceItems,
                                List<Secondary_Credit_Note_Debit_Item__c> debitItems,
                                List<Secondary_Credit_Note__c> statusUpdates) {
        if (invoiceItems.isEmpty() && debitItems.isEmpty()) {
            return;
        }
        isAllocating = true;
        try {
            if (!invoiceItems.isEmpty()) {
                insert invoiceItems;
            }
            if (!debitItems.isEmpty()) {
                insert debitItems;
            }
            if (!statusUpdates.isEmpty()) {
                update statusUpdates;
            }
        } finally {
            isAllocating = false;
        }
    }
}
