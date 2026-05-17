public class ProductForecastTriggerHandler {

    public static void validateDuplicateForecast(
        List<Product_Forecast__c> newForecastList,
        Map<Id, Product_Forecast__c> oldMap
    ) {

        Set<Id> distributorIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        Set<String> subGroups = new Set<String>();
        Set<Id> ownerIds = new Set<Id>();

        for (Product_Forecast__c forecast : newForecastList) {

            if (forecast.Distributor__c != null) {
                distributorIds.add(forecast.Distributor__c);
            }

            if (forecast.Product__c != null) {
                productIds.add(forecast.Product__c);
            }

            if (forecast.Product_Sub_Group__c != null) {
                subGroups.add(forecast.Product_Sub_Group__c);
            }

            ownerIds.add(forecast.OwnerId);
        }

        List<Product_Forecast__c> existingForecasts = [
            SELECT Id,
                   Distributor__c,
                   Product_Sub_Group__c,
                   Product__c,
                   OwnerId,
                   Forecast_Month__c,
                   Forecast_Year__c
            FROM Product_Forecast__c
            WHERE Distributor__c IN :distributorIds
            AND OwnerId IN :ownerIds
        ];

        for (Product_Forecast__c newForecast : newForecastList) {

            for (Product_Forecast__c existing : existingForecasts) {

                if (
                    oldMap != null &&
                    existing.Id == newForecast.Id
                ) {
                    continue;
                }

                Boolean isDuplicate = false;

                // Product level forecast
                if (
                    newForecast.Product__c != null &&
                    existing.Product__c != null &&
                    newForecast.Distributor__c == existing.Distributor__c &&
                    newForecast.Product__c == existing.Product__c &&
                    newForecast.OwnerId == existing.OwnerId &&
                    newForecast.Forecast_Month__c == existing.Forecast_Month__c &&
                    newForecast.Forecast_Year__c == existing.Forecast_Year__c
                ) {
                    isDuplicate = true;
                }

                // Product Sub Group level forecast
                if (
                    newForecast.Product__c == null &&
                    existing.Product__c == null &&
                    newForecast.Distributor__c == existing.Distributor__c &&
                    newForecast.Product_Sub_Group__c == existing.Product_Sub_Group__c &&
                    newForecast.OwnerId == existing.OwnerId &&
                    newForecast.Forecast_Month__c == existing.Forecast_Month__c &&
                    newForecast.Forecast_Year__c == existing.Forecast_Year__c
                ) {
                    isDuplicate = true;
                }

                if (isDuplicate) {

                    if (newForecast.Product__c != null) {

                        newForecast.addError(
                            'Forecast already exists for this Distributor, Product, Owner, Month and Year.'
                        );

                    } else {

                        newForecast.addError(
                            'Forecast already exists for this Distributor, Product Sub Group, Owner, Month and Year.'
                        );
                    }

                    break;
                }
            }
        }
    }

    public static void afterUpdate(
        List<Product_Forecast__c> newProductForecastList,
        Map<Id, Product_Forecast__c> oldProductForecastMap
    ) {

        List<Id> approvedForecastIds = new List<Id>();

        for (Product_Forecast__c forecast : newProductForecastList) {

            Product_Forecast__c oldForecast =
                oldProductForecastMap.get(forecast.Id);

            if (
                forecast.Approval_Status__c == 'Approved' &&
                oldForecast.Approval_Status__c != 'Approved'
            ) {
                approvedForecastIds.add(forecast.Id);
            }
        }

        for (Id forecastId : approvedForecastIds) {
            System.enqueueJob(
                new ForecastApprovalEmailQueueable(forecastId)
            );
        }
    }
}