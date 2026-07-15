trigger StockAdjustmentTrigger on Stock_Adjustment__c (before insert) {

    if(trigger.isInsert)
    {
        if(trigger.isBefore)
        {
            StockAdjustmentTriggerHandler.beforeInsert(trigger.new);
        }
    }

}
