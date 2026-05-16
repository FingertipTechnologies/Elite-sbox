public without sharing class ForecastApprovalEmailQueueable implements Queueable {

    private Id forecastId;

    public ForecastApprovalEmailQueueable(Id forecastId) {
        this.forecastId = forecastId;
    }

    public class InvocableInput {
        @InvocableVariable(required=true)
        public Id forecastId;
    }

    @InvocableMethod(label='Send Forecast Approval Email' description='Enqueues the Production-team email after a Product_Forecast__c is approved.')
    public static void enqueueFromFlow(List<InvocableInput> inputs) {
        if (inputs == null || inputs.isEmpty()) return;
        for (InvocableInput input : inputs) {
            if (input != null && input.forecastId != null) {
                System.enqueueJob(new ForecastApprovalEmailQueueable(input.forecastId));
            }
        }
    }

    public void execute(QueueableContext qc) {
        sendEmail(forecastId);
    }

    @TestVisible
    private static void sendEmail(Id forecastId) {
        if (forecastId == null) return;

        List<Product_Forecast__c> records = [
            SELECT Id, Name, Approval_Status__c,
                   Distributor__c, Distributor__r.Name,
                   Product__c, Product__r.Name, Product__r.SKU_Code__c,
                   Product_Sub_Group__c,
                   Forecast__c, Forecast_UOM__c, Forecast_KG__c,
                   Forecast_Month__c, Forecast_Year__c,
                   Start_Date__c, End_Date__c,
                   Owner.Name, Owner.Email,
                   Approved_Date__c
            FROM Product_Forecast__c
            WHERE Id = :forecastId
            LIMIT 1
        ];
        if (records.isEmpty()) return;
        Product_Forecast__c f = records[0];

        String toEmail = Label.Production_Team_Forecast_Email;
        if (String.isBlank(toEmail)) {
            System.debug(LoggingLevel.WARN, 'Production_Team_Forecast_Email label is blank; skipping email for ' + forecastId);
            return;
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { toEmail });
        mail.setSubject('Forecast Approved: '
            + safe(f.Distributor__r != null ? f.Distributor__r.Name : null)
            + ' / ' + safe(f.Product_Sub_Group__c)
            + ' / ' + safe(f.Forecast_Month__c) + ' ' + safe(f.Forecast_Year__c));
        mail.setHtmlBody(buildBody(f));

        List<OrgWideEmailAddress> owea = [
            SELECT Id FROM OrgWideEmailAddress
            WHERE DisplayName = 'Elite Admin'
            LIMIT 1
        ];
        if (!owea.isEmpty()) {
            mail.setOrgWideEmailAddressId(owea[0].Id);
        }

        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }

        update new Product_Forecast__c(Id = forecastId, Production_Email_Sent_At__c = System.now());
    }

    private static String buildBody(Product_Forecast__c f) {
        String body = ''
            + '<html><body>'
            + '<p>Dear Production Team,</p>'
            + '<p>A forecast has been approved and is being sent to you for production planning.</p>'
            + '<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse;">'
            + row('Distributor', f.Distributor__r != null ? f.Distributor__r.Name : null)
            + row('Product Sub Group', f.Product_Sub_Group__c)
            + row('Product / SKU', f.Product__r != null ? f.Product__r.Name : null)
            + row('SKU Code', f.Product__r != null ? f.Product__r.SKU_Code__c : null)
            + row('Forecast Quantity', f.Forecast__c)
            + row('UOM', f.Forecast_UOM__c)
            + row('Forecast (KG)', f.Forecast_KG__c)
            + row('Forecast Month', f.Forecast_Month__c)
            + row('Forecast Year', f.Forecast_Year__c)
            + row('Start Date', f.Start_Date__c)
            + row('End Date', f.End_Date__c)
            + row('Submitted By', f.Owner != null ? f.Owner.Name : null)
            + row('Approved On', f.Approved_Date__c)
            + '</table>'
            + '<br/><p>Regards,<br/>ELITE FOODS PRIVATE LIMITED</p>'
            + '</body></html>';
        return body;
    }

    private static String row(String label, Object value) {
        return '<tr><td><b>' + label + '</b></td><td>' + safe(value) + '</td></tr>';
    }

    private static String safe(Object val) {
        return val == null ? '—' : String.valueOf(val);
    }
}
