@RestResource(urlMapping='/api/*')
/****************************************************************
* Class Name : getDataIntegrationController
* Company : Fingertipplus
* Created Date : 01-10-2025
* @description : Getting Integration points Invoice,Stock values from the SAP
* @author : Durga Prasad
* Used By : - 
* Change Log:
* -----------------------------------------------------------------------------
* Ver | Author | Date | Description
* -----------------------------------------------------------------------------
* 1.0 | Durga Prasad |  01-10-2025 | Initial version
* -----------------------------------------------------------------------------
******************************************************************/


global class getDataIntegrationController {
    /* Created by Durga Prasad (FTP)
    * 	Date:01-10-2025
    * 	Receiving invoice, Stock data from SAP - realtime 
    */
    @HttpPost
    global static  List<responseData>  doPost(){
        system.debug('objectName');
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String databox = req.requestBody.toString();
        String objectName = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
        system.debug(objectName);
        List<responseData> response = new List<responseData>();
        List<Apex_Log__c> logList = new List<Apex_Log__c>();
        try{
            if(objectName=='Invoice'){
                Map<String, Object> cObjMap = (Map<String,  Object>) JSON.deserializeUntyped(databox);
                system.debug(cObjMap);
                Map<String, Object> cObjMap2 = (Map<String,  Object>) cObjMap.get('Data');
                system.debug(cObjMap2);
                List<Database.upsertResult> results = new  List<Database.upsertResult>();
                
                
                List<InvoiceData> rawData = (List<InvoiceData>)JSON.deserialize(JSON.serialize(cObjMap2.get('Invoice')), List<InvoiceData>.class);
                List<Invoice__c> invList= new  List<Invoice__c>();
                List<Invoice_item__c> invLineList= new  List<Invoice_item__c>();
                List<Product__c> products = [Select Id,Name,UOM__c,Alternate_UOM__c,Uom_Conversion__c,SKU_Code__c from Product__c where SKU_Code__c != null];
                Map<String,Product__c> SkuCodeToProduct = New Map<String,Product__c>();
                for(Product__c prod : products){
                    SkuCodeToProduct.put(prod.SKU_Code__c,prod);
                }
                for(InvoiceData obj : rawData){
                    if(obj.invoiceNumber != null)
                    { 
                        Invoice__c so = new Invoice__c();
                        if (obj.invoiceDate == null || obj.invoiceDate == '') {
                            logList.add(buildLog(
                                'Invoice-Date Missing',
                                'Invoice No: ' + obj.invoiceNumber,
                                obj.invoiceNumber,
                                'Error'
                            ));
                            continue;
                        }
                        so.Invoice_Date__c = date.valueof(obj.invoiceDate);
                        so.Invoice_No__c = obj.invoiceNumber;
                        so.SAP_Order_ID__c = obj.SAPOrderId;
                        //Link Order
                        if(obj.sfOrderId != null && obj.sfOrderId != '') so.SF_Order__r = new Order__c(Order_Id_Text__c = obj.sfOrderId);
                        //Link Account to Invoice  
                        if(obj.billToParty != null) so.Store__r = new Account(SAP_Customer_Code__c = obj.billToParty);
                        //Link Ship to party to Invoice  
                        if(obj.shipToParty != null && obj.shipToParty != '') so.Ship_To_Party__r = new Account(SAP_Customer_Code__c = obj.shipToParty);
                        so.Customer_SAP_Code__c = obj.billToParty;
                        so.Ship_To_Party_Code__c = obj.shipToParty;
                        so.Company_Code__c = obj.companyCode;
                        so.Delivery_Plant__c = obj.delivaryPlant;
                        so.IGST_Amount__c = obj.igstAmount;
                        so.GST_Amount__c = obj.gstAmount;   
                        so.Grand_Total__c = obj.billAmount;    
                        if(obj.InvoiceItems.size()>0){
                            for(Invoiceitems ad : obj.InvoiceItems){
                                //Link line item to invoice record   
                                if(ad.invoiceNumber == null || ad.invoiceNumber == '')
                                {
                                    logList.add(buildLog(
                                        'Invoice Item - Parent Invoice No Missing',
                                        'SKU Code: ' + ad.material+',Serial No'+ad.serialNumber,
                                        ad.invoiceNumber,
                                        'Error'
                                    ));
                                    continue;
                                }
                                Product__c prod = SkuCodeToProduct.get(ad.material);
                                if (prod == null) {
                                    logList.add(buildLog(
                                        'Invoice-SKU Missing',
                                        'SKU not found: ' + ad.material,
                                        ad.invoiceNumber,
                                        'Error'
                                    ));
                                    continue;
                                }
                                if(prod.Uom_Conversion__c == null || prod.Uom_Conversion__c == 0){
                                    logList.add(buildLog(
                                        'UOM Conversion Missing',
                                        'SKU: ' + ad.material,
                                        ad.invoiceNumber,
                                        'Error'
                                    ));
                                    continue;
                                }
                                if(ad.pricePerUnit == null){
                                    logList.add(buildLog(
                                        'Price Missing',
                                        'SKU: ' + ad.material+',Serial No'+ad.serialNumber,
                                        ad.invoiceNumber,
                                        'Error'
                                    ));
                                    continue;
                                }
                                if(ad.serialNumber == null || ad.serialNumber == '')
                                {
                                    logList.add(buildLog(
                                        'Invoice - Serial Number Missing',
                                        'SKU Code: ' + ad.material,
                                        ad.invoiceNumber,
                                        'Error'
                                    ));
                                    continue;
                                }
                                Invoice_item__c invItem = new Invoice_item__c();
                                invItem.Invoice__r = new Invoice__c(Invoice_No__c = ad.invoiceNumber); 
                                invItem.Bill_Number__c = ad.invoiceNumber;
                                invItem.EID__c = ad.invoiceNumber+'_'+ad.serialNumber;
                                invItem.SKU__r = new Product__c(SKU_Code__c = ad.material); 
                                invItem.SKU_Code_From_API__c = ad.material; 
                                invItem.Serial_Number__c = ad.serialNumber; 
                                invItem.UOM__c = ad.uom; 
                                //When the UOM is matched with the Invoice item UOM it is Each 
                                //other wise it is not EA
                                if(prod.UOM__c == ad.uom){
                                    invItem.Qyt_in_Each__c = ad.quantity; 
                                    invItem.Price_per_unit__c = (ad.pricePerUnit).setScale(4, RoundingMode.HALF_UP);
                                    invItem.Qyt__c = ad.quantity / prod.Uom_Conversion__c; 
                                    invItem.Price_per_case__c = ad.pricePerUnit*(prod.Uom_Conversion__c);
                                }
                                else{
                                    invItem.Qyt__c = ad.quantity; 
                                    invItem.Price_per_case__c = (ad.pricePerUnit).setScale(4, RoundingMode.HALF_UP);
                                    invItem.Qyt_in_Each__c = prod.Uom_Conversion__c * ad.quantity; 
                                    Decimal uomConv = (prod.Uom_Conversion__c);
                                    invItem.Price_per_unit__c = 
                                        (ad.pricePerUnit / uomConv).setScale(4, RoundingMode.HALF_UP);
                                }
                                invItem.Bill_Amount__c = ad.billAmount; 
                                invItem.GST_Amount__c = ad.gstAmount; 
                                invItem.IGST_Amt__c = ad.igstAmount; 
                                invItem.Batch__c = ad.batch; 
                                if(ad.batchExpiry != null && ad.batchExpiry != '')
                                {
                                    invItem.Batch_Expiry__c = date.Valueof(ad.batchExpiry); 
                                }
                                //Extra paramets                             
                                invItem.SAP_Order_Id__c = obj.SAPOrderId; 
                                // Set Order__r from obj.sfOrderId if present
                                if(obj.sfOrderId != null && obj.sfOrderId != '') invItem.Order__r = new Order__c(Order_Id_Text__c = obj.sfOrderId);

                                invItem.Company_Code__c = obj.companyCode;
                                invItem.Plant__c  = obj.delivaryPlant;
                                invItem.Bill_Date__c =  date.valueof(obj.invoiceDate);
                                invLineList.add(invItem);
                            }
                        }
                        invList.add(so);
                    }
                }
                
                try {
                    Schema.SObjectField externalId = Invoice__c.Fields.Invoice_No__c;
                    results= Database.upsert(invList,externalId, false);
                    List<Database.upsertResult> results2 = new  List<Database.upsertResult>();
                    Schema.SObjectField externalLineId = Invoice_item__c.Fields.EID__c;
                    results2= Database.upsert(invLineList,externalLineId, false);
                    response= getResponseData(results,invList,'Invoice',response,logList);
                    //Apex Log to Identify Error
                    logList.add(buildLog(
                        objectName,
                        'Invoice Success Callout',
                        'API',
                        'Success'
                    ));
                    
                } 
                catch(DMLException e) {
                    system.debug('error Message :'+e.getMessage());
                    
                    //Apex Log to Identify Error
                    logList.add(buildLog(
                        objectName,
                        e.getMessage(),
                        'API',
                        'Error'
                    ));
                    
                    throw new DMLException('Unable to Perform the DML Operation on Invoice : ' +e.getMessage());
                }
            }   
            else if(objectName=='Stock')
            {
                try {
                    List<Plant_Stock__c> stockList = (List<Plant_Stock__c>) JSON.deserialize(databox, List<Plant_Stock__c>.class);
                    List<Plant_Stock__c> stocksToInsert = new List<Plant_Stock__c>();
                    for(Plant_Stock__c ps : stockList){
                        ps.External_ID__c = ps.Delivery_Plant__c + ps.SKU_Code__c;
                        ps.SKU__r = new Product__c(SKU_Code__c = ps.SKU_Code__c);
                        stocksToInsert.add(ps);
                    }
                    
                    Database.UpsertResult[] stockResults = Database.upsert(stocksToInsert, Plant_Stock__c.External_ID__c, false);
                    response= getResponseData(stockResults,stocksToInsert,'Stock',response,logList);
                    //Apex Log to Identify Error
                    logList.add(buildLog(
                        objectName,
                        'Stock Success Callout',
                        'API',
                        'Success'
                    ));
                    
                } 
                catch(DMLException e) {
                    system.debug('error Message :'+e.getMessage());
                    //Apex Log to Identify Error
                    logList.add(buildLog(
                        objectName,
                        e.getMessage(),
                        'API',
                        'Error'
                    ));

                    throw new DMLException('Unable to Perform the DML Operation on Stock : ' +e.getMessage());
                }
        }
        }
        catch(Exception e ){
            System.debug('Problem sending notification: ' + e.getMessage());
            responseData rs = new responseData();
            rs.status = 'Failed '+e.getMessage();
            response.add(rs);
           
            logList.add(buildLog(
                objectName,
                e.getMessage(),
                'API',
                'Error'
            ));

            
        }
        
        if (!logList.isEmpty()) {
            insert logList;
        }
        
        return response;
    }
    /*
    *  Method Name : getResponseData 
    *  @description : Creating a response list and give back to request 
    *  @param : Getting the success or error values from the doPost method  
    *  @returns : list<responseData>: Return the response list. 
    *  
    */
    public static list<responseData> getResponseData(List<Database.upsertResult> results,list<Sobject> objectList,String objectName, list<responseData> response,List<Apex_Log__c> logList)
    {
        for(Integer index = 0, size = results.size(); index < size; index++) {
            responseData rs = new responseData();
            if(objectName=='Invoice')
                rs.SAPId = objectList[index].get('Invoice_No__c')+'';
            else if(objectName=='Stock') 
                rs.SAPId = (String) objectList[index].get('External_ID__c');
            
            
            rs.objectName=objectName;
            if(results[index].isSuccess()) {
                system.debug(results[index].isCreated());
                rs.salesforceId = results[index].getId();
                rs.status = 'Success';
            }else {
                rs.status = 'Failed';
                List<string> erList = new List<string>();
                // iterate over the failed ones
                for(Database.Error error : results[index].getErrors()) {
                    erList.add(error.getMessage());
                    System.debug('Error Status : ' + error.getStatusCode() + ' : '+ 'Error Fields : ' + error.getFields());
                }
                rs.errorMessage =string.join(erList,',');
                
                //Apex Log to Identify Error
                logList.add(buildLog(
                    objectName,
                    rs.errorMessage,
                    rs.SAPId,
                    'Error'
                ));
                
            }
          
            response.add(rs);
        }
        
        return response;
    }
    

    
    private static Apex_Log__c buildLog(
        String requestType,
        String message,
        String ref,
        string msgType
    ) {
        Apex_Log__c log = new Apex_Log__c();
        log.Request_Type__c = requestType + '-' + ref;
        log.Error_Message__c = message;
        log.Response__c = message;
        log.Status__c = msgType;
        return log;
    }
    
    //Response Wrapper 
    global class responseData{
        Public string objectName;
        Public string salesforceId;
        Public string SAPId;
        Public string status;
        Public string errorMessage;
    }
    //Invoce wrapper   
    global class InvoiceData{
        Public string invoiceNumber;
        Public string invoiceDate;
        Public string SAPOrderId;
        Public string sfOrderId;
        Public string billToParty;
        Public string billToPartyName;
        Public string companyCode;
        Public string delivaryPlant; 
        Public string shipToParty; 
        Public string shipToPartyName;
        Public decimal totalCaseQuantity;
        Public decimal totalEachQuantity;
        Public decimal gstAmount;
        Public decimal igstAmount;
        Public decimal billAmount;
        Public string invoiceStatus;
        Public string executiveName;
        Public string executiveEmployeeCode;
        public List<Invoiceitems> InvoiceItems;
    }
    //Receive Invoice item into wrapper   
    global class Invoiceitems{
        Public string invoiceNumber;
        Public string material;
        Public string materialDesc;
        Public decimal quantity;
        Public decimal quantityInEach;
        Public string uom;
        Public decimal pricePerCase;
        Public decimal pricePerUnit;
        Public decimal billAmount;
        Public decimal gstAmount;
        Public decimal igstAmount;
        Public string batch;
        Public string batchExpiry;
        Public string serialNumber;
        Public string SAP_OrderId;
    } 
}