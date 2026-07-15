public without sharing class SecondaryInvoiceItemTriggerHandler {

    /**
     * Recursion / re-entry guard. Since this handler only writes to
     * Order_Item__c and Order__c (never back to Secondary_Invoice_Item__c),
     * true recursion isn't possible from this trigger alone - but the guard
     * is kept so that if this class is ever called a second time in the same
     * transaction (e.g. from another trigger, a batch chaining pattern, or a
     * future/queueable that fires more DML on the same records) it does not
     * needlessly re-run the full cascade for Order_Item__c ids it has
     * already processed in this transaction.
     */
    @TestVisible
    private static Set<Id> processedOrderItemIds = new Set<Id>();

    /**
     * Trigger entry point. Called directly from SecondaryInvoiceItemTrigger.
     * Bulkifies Trigger.new / Trigger.old into a single Set<Id> of affected
     * Order_Item__c records and delegates to run().
     *
     * isDelete matters because on delete, the affected parent lookup value
     * only exists on Trigger.old (Trigger.new is null/empty for deletes).
     */
    public static void handleTrigger(
        List<Secondary_Invoice_Item__c> newList,
        List<Secondary_Invoice_Item__c> oldList,
        Boolean isDelete
    ) {
        Set<Id> orderItemIds = new Set<Id>();

        List<Secondary_Invoice_Item__c> sourceList = isDelete ? oldList : newList;
        if (sourceList != null) {
            for (Secondary_Invoice_Item__c sii : sourceList) {
                if (sii.Order_Item__c != null) {
                    orderItemIds.add(sii.Order_Item__c);
                }
            }
        }

        run(orderItemIds);
    }

    /**
     * Single entry point for the cascade. Public (not just called from the
     * trigger) so it can also be invoked directly from Apex tests, batch
     * jobs, or admin tooling that needs to force a recalculation without
     * touching Secondary_Invoice_Item__c records.
     *
     * Cascades in one transaction:
     *   1) Secondary_Invoice_Item__c change -> recalc Delivered_Quantity__c /
     *      Fulfillment_Status__c on the parent Order_Item__c
     *   2) Order_Item__c change            -> recalc Total_Delivered_Quantity__c /
     *      Order_Fulfillment_Status__c on the parent Order__c
     *
     * ASSUMPTIONS (rename if these don't match your org):
     *  - Secondary_Invoice_Item__c.Order_Item__c   -> master-detail to Order_Item__c
     *  - Secondary_Invoice_Item__c.Quantity__c     -> invoiced qty per line
     *  - Order_Item__c.Order__c                    -> master-detail to Order__c
     *  - Order_Item__c.Fulfillment_Status__c       -> picklist (4 values below)
     *  - Order__c.Total_Delivered_Quantity__c      -> plain Number field (NOT a
     *    native roll-up type - Apex must be able to write to it)
     *  - Order__c.Order_Fulfillment_Status__c      -> picklist (same 4 values)
     */
    public static void run(Set<Id> orderItemIds) {
        if (orderItemIds == null || orderItemIds.isEmpty()) {
            return;
        }

        // Only process ids we haven't already handled in this transaction.
        Set<Id> idsToProcess = orderItemIds.clone();
        idsToProcess.removeAll(processedOrderItemIds);
        if (idsToProcess.isEmpty()) {
            return;
        }
        processedOrderItemIds.addAll(idsToProcess);

        Set<Id> orderIds = recalcParentOrderItems(idsToProcess);
        recalcParentOrders(orderIds);
    }

    /**
     * Recalculates Delivered_Quantity__c and Fulfillment_Status__c on
     * Order_Item__c. Returns the set of parent Order__c Ids touched, so the
     * caller can cascade one level further without an extra query round trip.
     *
     * We compute the delivered total via an aggregate query on
     * Secondary_Invoice_Item__c directly rather than reading a native
     * roll-up summary field, since roll-up recalculation on the parent isn't
     * guaranteed to be visible within the same trigger transaction that
     * caused the child change.
     */
    private static Set<Id> recalcParentOrderItems(Set<Id> orderItemIds) {
        Set<Id> orderIds = new Set<Id>();
        if (orderItemIds == null || orderItemIds.isEmpty()) {
            return orderIds;
        }

        Map<Id, Decimal> deliveredByOrderItem = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Order_Item__c oid, SUM(Quantity__c) qty
            FROM Secondary_Invoice_Item__c
            WHERE Order_Item__c IN :orderItemIds
            GROUP BY Order_Item__c
        ]) {
            deliveredByOrderItem.put((Id) ar.get('oid'), (Decimal) ar.get('qty'));
        }

        List<Order_Item__c> orderItems = [
            SELECT Id, Order__c, Quantity__c, Delivered_Quantity__c, Status__c
            FROM Order_Item__c
            WHERE Id IN :orderItemIds
        ];

        List<Order_Item__c> toUpdate = new List<Order_Item__c>();
        for (Order_Item__c oi : orderItems) {
            if (oi.Order__c != null) {
                orderIds.add(oi.Order__c);
            }

            Decimal delivered = deliveredByOrderItem.containsKey(oi.Id)
                ? deliveredByOrderItem.get(oi.Id)
                : 0;
            Decimal ordered = oi.Quantity__c == null ? 0 : oi.Quantity__c;
            String status = resolveStatus(ordered, delivered);
            system.debug('status='+status);
            system.debug('status='+ordered);
            system.debug('status='+delivered);
            
            Boolean qtyChanged = (oi.Delivered_Quantity__c == null && delivered != 0)
                || (oi.Delivered_Quantity__c != null && oi.Delivered_Quantity__c != delivered);
            Boolean statusChanged = oi.Status__c != status;

            if (qtyChanged || statusChanged) {
                oi.Delivered_Quantity__c = delivered;
                oi.Status__c = status;
                toUpdate.add(oi);
            }
        }

        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, true);
        }

        return orderIds;
    }

    /**
     * Recalculates Total_Delivered_Quantity__c and Order_Fulfillment_Status__c
     * on Order__c, summing the (just-updated) Delivered_Quantity__c across all
     * of that Order's Order_Item__c children.
     */
    private static void recalcParentOrders(Set<Id> orderIds) {
        if (orderIds == null || orderIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> deliveredByOrder = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Order__c oid, SUM(Delivered_Quantity__c) qty
            FROM Order_Item__c
            WHERE Order__c IN :orderIds
            GROUP BY Order__c
        ]) {
            deliveredByOrder.put((Id) ar.get('oid'), (Decimal) ar.get('qty'));
        }

        List<Order__c> orders = [
            SELECT Id, Total_Quantity__c, DB_Bill_Quantity__c, Order_Fulfillment_Status__c
            FROM Order__c
            WHERE Id IN :orderIds
        ];

        List<Order__c> toUpdate = new List<Order__c>();
        for (Order__c ord : orders) {
            Decimal delivered = deliveredByOrder.containsKey(ord.Id)
                ? deliveredByOrder.get(ord.Id)
                : 0;
            Decimal ordered = ord.Total_Quantity__c == null ? 0 : ord.Total_Quantity__c;
            String status = resolveStatus(ordered, delivered);

            Boolean qtyChanged = (ord.DB_Bill_Quantity__c == null && delivered != 0)
                || (ord.DB_Bill_Quantity__c != null && ord.DB_Bill_Quantity__c != delivered);
            Boolean statusChanged = ord.Order_Fulfillment_Status__c != status;

            if (qtyChanged || statusChanged) {
                ord.DB_Bill_Quantity__c = delivered;
                ord.Order_Fulfillment_Status__c = status;
                toUpdate.add(ord);
            }
        }

        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, true);
        }
    }

    /**
     * Not Fulfilled   -> delivered == 0
     * Back-To-Back    -> ordered == delivered
     * Under-Fulfilled -> ordered > delivered   (shipped less than ordered)
     * Over-Fulfilled  -> ordered < delivered   (shipped more than ordered)
     */
    private static String resolveStatus(Decimal ordered, Decimal delivered) {
        if (delivered == 0) {
            return 'Not Fulfilled';
        }
        if (ordered == delivered) {
            return 'Back-To-Back';
        }
        if (ordered > delivered) {
            return 'Under-Fulfilled';
        }
        return 'Over-Fulfilled';
    }
}