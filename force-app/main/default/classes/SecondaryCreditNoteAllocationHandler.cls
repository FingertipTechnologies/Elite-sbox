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

        // Pending documents per customer, oldest first
        Map<Id, List<Secondary_Invoice__c>> invoicesByCustomer = new Map<Id, List<Secondary_Invoice__c>>();
        for (Secondary_Invoice__c inv : [
            SELECT Id, Customer__c, Pending_Amount__c
            FROM Secondary_Invoice__c
            WHERE Customer__c IN :customerIds AND Pending_Amount__c > 0
            ORDER BY Invoice_Date__c ASC
        ]) {
            if (!invoicesByCustomer.containsKey(inv.Customer__c)) {
                invoicesByCustomer.put(inv.Customer__c, new List<Secondary_Invoice__c>());
            }
            invoicesByCustomer.get(inv.Customer__c).add(inv);
        }
        Map<Id, List<Secondary_Debit_Note__c>> debitNotesByCustomer = new Map<Id, List<Secondary_Debit_Note__c>>();
        for (Secondary_Debit_Note__c dn : [
            SELECT Id, Customer__c, Pending_Amount__c
            FROM Secondary_Debit_Note__c
            WHERE Customer__c IN :customerIds AND Pending_Amount__c > 0
            ORDER BY Note_Date__c ASC
        ]) {
            if (!debitNotesByCustomer.containsKey(dn.Customer__c)) {
                debitNotesByCustomer.put(dn.Customer__c, new List<Secondary_Debit_Note__c>());
            }
            debitNotesByCustomer.get(dn.Customer__c).add(dn);
        }

        List<Secondary_Credit_Note_Item__c> invoiceItems = new List<Secondary_Credit_Note_Item__c>();
        List<Secondary_Credit_Note_Debit_Item__c> debitItems = new List<Secondary_Credit_Note_Debit_Item__c>();
        List<Secondary_Credit_Note__c> statusUpdates = new List<Secondary_Credit_Note__c>();

        for (Secondary_Credit_Note__c cn : newNotes) {
            if (cn.Customer__c == null || cn.Amount__c == null || cn.Amount__c <= 0) {
                continue;
            }
            Decimal remaining = cn.Amount__c;

            // Invoices first, oldest first (pending decremented in memory so a
            // second credit note in the same batch cannot over-apply)
            if (invoicesByCustomer.containsKey(cn.Customer__c)) {
                for (Secondary_Invoice__c inv : invoicesByCustomer.get(cn.Customer__c)) {
                    if (remaining <= 0) { break; }
                    if (inv.Pending_Amount__c == null || inv.Pending_Amount__c <= 0) { continue; }
                    Decimal applied = Math.min(inv.Pending_Amount__c, remaining);
                    invoiceItems.add(new Secondary_Credit_Note_Item__c(
                        Secondary_Credit_Note__c = cn.Id,
                        Secondary_Invoice__c = inv.Id,
                        Amount__c = applied
                    ));
                    inv.Pending_Amount__c -= applied;
                    remaining -= applied;
                }
            }
            // Then debit notes, oldest first
            if (remaining > 0 && debitNotesByCustomer.containsKey(cn.Customer__c)) {
                for (Secondary_Debit_Note__c dn : debitNotesByCustomer.get(cn.Customer__c)) {
                    if (remaining <= 0) { break; }
                    if (dn.Pending_Amount__c == null || dn.Pending_Amount__c <= 0) { continue; }
                    Decimal applied = Math.min(dn.Pending_Amount__c, remaining);
                    debitItems.add(new Secondary_Credit_Note_Debit_Item__c(
                        Secondary_Credit_Note__c = cn.Id,
                        Secondary_Debit_Note__c = dn.Id,
                        Amount__c = applied
                    ));
                    dn.Pending_Amount__c -= applied;
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
        Map<Id, List<Secondary_Credit_Note__c>> openCredits = loadOpenCredits(customerIds);
        if (openCredits.isEmpty()) {
            return;
        }

        // Re-query so Pending_Amount__c is reliable
        List<Secondary_Credit_Note_Item__c> invoiceItems = new List<Secondary_Credit_Note_Item__c>();
        Map<Id, Secondary_Credit_Note__c> statusUpdates = new Map<Id, Secondary_Credit_Note__c>();
        for (Secondary_Invoice__c inv : [
            SELECT Id, Customer__c, Pending_Amount__c
            FROM Secondary_Invoice__c
            WHERE Id IN :newInvoices AND Pending_Amount__c > 0
            ORDER BY Invoice_Date__c ASC
        ]) {
            Decimal invPending = inv.Pending_Amount__c;
            if (!openCredits.containsKey(inv.Customer__c)) { continue; }
            for (Secondary_Credit_Note__c cn : openCredits.get(inv.Customer__c)) {
                if (invPending <= 0) { break; }
                if (cn.Unapplied_Amount__c == null || cn.Unapplied_Amount__c <= 0) { continue; }
                Decimal applied = Math.min(cn.Unapplied_Amount__c, invPending);
                invoiceItems.add(new Secondary_Credit_Note_Item__c(
                    Secondary_Credit_Note__c = cn.Id,
                    Secondary_Invoice__c = inv.Id,
                    Amount__c = applied
                ));
                cn.Unapplied_Amount__c -= applied;
                invPending -= applied;
                statusUpdates.put(cn.Id, new Secondary_Credit_Note__c(
                    Id = cn.Id,
                    Status__c = statusFor(cn.Amount__c, cn.Unapplied_Amount__c)
                ));
            }
        }

        persist(invoiceItems, new List<Secondary_Credit_Note_Debit_Item__c>(), statusUpdates.values());
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
        Map<Id, List<Secondary_Credit_Note__c>> openCredits = loadOpenCredits(customerIds);
        if (openCredits.isEmpty()) {
            return;
        }

        List<Secondary_Credit_Note_Debit_Item__c> debitItems = new List<Secondary_Credit_Note_Debit_Item__c>();
        Map<Id, Secondary_Credit_Note__c> statusUpdates = new Map<Id, Secondary_Credit_Note__c>();
        for (Secondary_Debit_Note__c dn : [
            SELECT Id, Customer__c, Pending_Amount__c
            FROM Secondary_Debit_Note__c
            WHERE Id IN :newDebitNotes AND Pending_Amount__c > 0
            ORDER BY Note_Date__c ASC
        ]) {
            Decimal dnPending = dn.Pending_Amount__c;
            if (!openCredits.containsKey(dn.Customer__c)) { continue; }
            for (Secondary_Credit_Note__c cn : openCredits.get(dn.Customer__c)) {
                if (dnPending <= 0) { break; }
                if (cn.Unapplied_Amount__c == null || cn.Unapplied_Amount__c <= 0) { continue; }
                Decimal applied = Math.min(cn.Unapplied_Amount__c, dnPending);
                debitItems.add(new Secondary_Credit_Note_Debit_Item__c(
                    Secondary_Credit_Note__c = cn.Id,
                    Secondary_Debit_Note__c = dn.Id,
                    Amount__c = applied
                ));
                cn.Unapplied_Amount__c -= applied;
                dnPending -= applied;
                statusUpdates.put(cn.Id, new Secondary_Credit_Note__c(
                    Id = cn.Id,
                    Status__c = statusFor(cn.Amount__c, cn.Unapplied_Amount__c)
                ));
            }
        }

        persist(new List<Secondary_Credit_Note_Item__c>(), debitItems, statusUpdates.values());
    }

    /** Helper: open credit notes per customer, oldest first */
    private static Map<Id, List<Secondary_Credit_Note__c>> loadOpenCredits(Set<Id> customerIds) {
        Map<Id, List<Secondary_Credit_Note__c>> openCredits = new Map<Id, List<Secondary_Credit_Note__c>>();
        if (customerIds.isEmpty()) {
            return openCredits;
        }
        for (Secondary_Credit_Note__c cn : [
            SELECT Id, Customer__c, Amount__c, Unapplied_Amount__c
            FROM Secondary_Credit_Note__c
            WHERE Customer__c IN :customerIds AND Unapplied_Amount__c > 0
            ORDER BY Credit_Date__c ASC, Name ASC
        ]) {
            if (!openCredits.containsKey(cn.Customer__c)) {
                openCredits.put(cn.Customer__c, new List<Secondary_Credit_Note__c>());
            }
            openCredits.get(cn.Customer__c).add(cn);
        }
        return openCredits;
    }

    private static String statusFor(Decimal amount, Decimal remaining) {
        if (remaining <= 0) {
            return 'Paid';
        }
        if (remaining < amount) {
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
