public class InvoiceHeaderTriggerHandler {

    @TestVisible
    private static Id systemAdminUserId {
        get {
            if (systemAdminUserId == null) {
                List<User> admins = [
                    SELECT Id FROM User
                    WHERE Profile.Name = 'System Administrator' AND IsActive = true
                    ORDER BY CreatedDate ASC
                    LIMIT 1
                ];
                if (!admins.isEmpty()) systemAdminUserId = admins[0].Id;
            }
            return systemAdminUserId;
        }
        set;
    }

    // SF_Order__c is no longer sent on the Invoice header; the SF Order now lives on
    // each Invoice Item (Order__c). The header therefore has no business owner and is
    // always owned by a System Administrator. Item-level ownership is set in
    // InvoiceItemTriggerHandler.mapInvoiceItemOwner.
    public static void beforeInsert(List<Invoice__c> newInvoicesList) {
        Id adminId = systemAdminUserId;
        if (adminId == null) return;
        for (Invoice__c inv : newInvoicesList) {
            inv.OwnerId = adminId;
        }
    }
}