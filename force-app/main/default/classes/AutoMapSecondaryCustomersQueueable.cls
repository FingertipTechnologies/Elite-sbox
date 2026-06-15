public class AutoMapSecondaryCustomersQueueable implements Queueable {
    private Set<Id> primaryCustomerIds;
    private Set<Id> subStockiestIds;
    private Map<Id, Id> customerToExecutiveMap;
    private Map<Id, Id> customerToEmployeeMap;

    public AutoMapSecondaryCustomersQueueable(
        Set<Id> primaryCustomerIds, Set<Id> subStockiestIds,
        Map<Id, Id> customerToExecutiveMap, Map<Id, Id> customerToEmployeeMap) {
        this.primaryCustomerIds = primaryCustomerIds;
        this.subStockiestIds = subStockiestIds;
        this.customerToExecutiveMap = customerToExecutiveMap;
        this.customerToEmployeeMap = customerToEmployeeMap;
    }

    public void execute(QueueableContext context) {
        try {
            ProductMappingTriggerHandler.autoMapSecondaryCustomers(
                primaryCustomerIds, subStockiestIds,
                customerToExecutiveMap, customerToEmployeeMap);
        } catch (Exception ex) {
            System.debug('AutoMapSecondaryCustomersQueueable error: ' + ex.getMessage());
        }
    }
}