trigger ProductForecastTrigger on Product_Forecast__c (
    before insert,
    before update,
    after update
) {

    if (Trigger.isBefore) {

        if (Trigger.isInsert) {
            ProductForecastTriggerHandler.validateDuplicateForecast(
                Trigger.new,
                null
            );
        }

        if (Trigger.isUpdate) {
            ProductForecastTriggerHandler.validateDuplicateForecast(
                Trigger.new,
                Trigger.oldMap
            );
        }
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        ProductForecastTriggerHandler.afterUpdate(
            Trigger.new,
            Trigger.oldMap
        );
    }
}