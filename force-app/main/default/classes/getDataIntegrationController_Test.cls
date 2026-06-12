@isTest
private class getDataIntegrationController_Test {

    // ---------------------------------------------------------
    // HELPER: Create Test Product
    // ---------------------------------------------------------
    private static Product__c createProduct(String sku, String uom, Decimal conv) {
        Product__c p = new Product__c(
            Name = 'Test Prod ' + sku,
            SKU_Code__c = sku,
            Uom_Conversion__c = conv
        );
        insert p;
        return p;


    }

    // ---------------------------------------------------------
    // HELPER: Create Test Product with a Base UOM (picklist)
    // SKUUOM value set -> 'EA','Nos' are valid restricted values
    // ---------------------------------------------------------
    private static Product__c createProductWithUom(String sku, String prodUom, Decimal conv) {
        Product__c p = new Product__c(
            Name = 'Test Prod ' + sku,
            SKU_Code__c = sku,
            UOM__c = prodUom,
            Uom_Conversion__c = conv
        );
        insert p;
        return p;
    }

    // ---------------------------------------------------------
    // HELPER: Create a Store/Account resolvable by SAP_Customer_Code__c
    // Customer_Type__c picklist -> 'Primary Customer' is a valid value
    // ---------------------------------------------------------
    private static Account createStore(String sapCode) {
        Account acc = new Account(
            Name = 'Test Store ' + sapCode,
            Customer_Type__c = 'Primary Customer',
            Primary_Phone_Number__c = '3121212112',
            State__c = 'Kerala',
            District__c = 'Kozhikode',
            Email_ID__c = 'abc@gmail.com',
            SAP_Customer_Code__c = sapCode
        );
        insert acc;
        return acc;
    }

    // ---------------------------------------------------------
    // TEST CASE: Invoice Integration
    // ---------------------------------------------------------
    @isTest
    static void testInvoicePost() {

        // Products used by line items
        createProduct('SKU100', 'EA', 1);
        createProduct('SKU200', 'CS', 12);

        // JSON Body for Invoice
        String body = '{'+
            '"Data": {'+
            '"Invoice":[{'+
                '"invoiceNumber":"INV001",'+
                '"invoiceDate":"2025-01-01",'+
                '"SAPOrderId":"SO123",'+
                '"sfOrderId":"ORD001",'+
                '"billToParty":"CUST01",'+
                '"shipToParty":"CUST02",'+
                '"companyCode":"1000",'+
                '"delivaryPlant":"PL01",'+
                '"gstAmount":10,'+
                '"igstAmount":5,'+
                '"billAmount":100,'+
                '"InvoiceItems":['+
                    '{'+
                        '"invoiceNumber":"INV001",'+
                        '"material":"SKU100",'+
             		'"serialNumber":"111",'+
                        '"materialDesc":"Desc1",'+
                        '"quantity":2,'+
                        '"pricePerUnit":50,'+
                        '"billAmount":100,'+
                        '"gstAmount":10,'+
                        '"igstAmount":5,'+
                        '"batch":"B1",'+
                        '"batchExpiry":"2025-12-31"'+
                    '}'+
                ']'+
            '}]'+
            '} }';

        // Setting Request Context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/api/Invoice';
        req.requestBody = Blob.valueOf(body);

        RestContext.request = req;
        RestContext.response = res;

        // Call Method
        List<getDataIntegrationController.responseData> responseList =
            getDataIntegrationController.doPost();



    }
     @isTest
    static void testInvoicePost2() {

        // Products used by line items
        createProduct('SKU100', 'EA', 1);
        createProduct('SKU200', 'CS', 12);

        // JSON Body for Invoice
        String body = '{'+
            '"Data": {'+
            '"Invoice":[{'+
                '"invoiceNumber":"INV001",'+
                '"invoiceDate":"2025-01-01",'+
                '"SAPOrderId":"SO123",'+
                '"sfOrderId":"ORD001",'+
                '"billToParty":"CUST01",'+
                '"shipToParty":"CUST02",'+
                '"companyCode":"1000",'+
                '"delivaryPlant":"PL01",'+
                '"gstAmount":10,'+
                '"igstAmount":5,'+
                '"billAmount":100,'+
                '"InvoiceItems":['+
                    '{'+
                        '"invoiceNumber":"",'+
                        '"material":"SKU100",'+
                        '"materialDesc":"Desc1",'+
                        '"quantity":2,'+
                        '"pricePerUnit":50,'+
                        '"billAmount":100,'+
                        '"gstAmount":10,'+
                        '"igstAmount":5,'+
                        '"batch":"B1",'+
                        '"batchExpiry":"2025-12-31"'+
                    '}'+
                ']'+
            '}]'+
            '} }';

        // Setting Request Context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/api/Invoice';
        req.requestBody = Blob.valueOf(body);

        RestContext.request = req;
        RestContext.response = res;

        // Call Method
        List<getDataIntegrationController.responseData> responseList =
            getDataIntegrationController.doPost();



    }
    
    @isTest
    static void testInvoicePost4() {

        // Products used by line items
        createProduct('SKU100', 'EA', 1);
        createProduct('SKU200', 'CS', 12);

        // JSON Body for Invoice
        String body = '{'+
            '"Data": {'+
            '"Invoice":[{'+
                '"invoiceNumber":"INV001",'+
                '"invoiceDate":"2025-01-01",'+
                '"SAPOrderId":"SO123",'+
                '"sfOrderId":"ORD001",'+
                '"billToParty":"CUST01",'+
                '"shipToParty":"CUST02",'+
                '"companyCode":"1000",'+
                '"delivaryPlant":"PL01",'+
                '"gstAmount":10,'+
                '"igstAmount":5,'+
                '"billAmount":100,'+
                '"InvoiceItems":['+
                    '{'+
                        '"invoiceNumber":"INV001",'+
                        '"material":"SKU100",'+
                        '"materialDesc":"Desc1",'+
                        '"quantity":2,'+
                        '"pricePerUnit":null,'+
                        '"billAmount":100,'+
                        '"gstAmount":10,'+
                        '"igstAmount":5,'+
                        '"batch":"B1",'+
                        '"batchExpiry":"2025-12-31"'+
                    '}'+
                ']'+
            '}]'+
            '} }';

        // Setting Request Context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/api/Invoice';
        req.requestBody = Blob.valueOf(body);

        RestContext.request = req;
        RestContext.response = res;

        // Call Method
        List<getDataIntegrationController.responseData> responseList =
            getDataIntegrationController.doPost();



    }
    
     
    @isTest
    static void testInvoicePost5() {

        // Products used by line items
        createProduct('SKU100', 'EA', 1);
        createProduct('SKU200', 'CS', 12);

        // JSON Body for Invoice
        String body = '{'+
            '"Data": {'+
            '"Invoice":[{'+
                '"invoiceNumber":"INV001",'+
                '"invoiceDate":"2025-01-01",'+
                '"SAPOrderId":"SO123",'+
                '"sfOrderId":"ORD001",'+
                '"billToParty":"CUST01",'+
                '"shipToParty":"CUST02",'+
                '"companyCode":"1000",'+
                '"delivaryPlant":"PL01",'+
                '"gstAmount":10,'+
                '"igstAmount":5,'+
                '"billAmount":100,'+
                '"InvoiceItems":['+
                    '{'+
                        '"invoiceNumber":"INV001",'+
                        '"material":"SKU100",'+
                        '"materialDesc":"Desc1",'+
                 		'"serialNumber":"",'+
                        '"quantity":2,'+
                        '"pricePerUnit":102,'+
                        '"billAmount":100,'+
                        '"gstAmount":10,'+
                        '"igstAmount":5,'+
                        '"batch":"B1",'+
                        '"batchExpiry":"2025-12-31"'+
                    '}'+
                ']'+
            '}]'+
            '} }';

        // Setting Request Context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/api/Invoice';
        req.requestBody = Blob.valueOf(body);

        RestContext.request = req;
        RestContext.response = res;

        // Call Method
        List<getDataIntegrationController.responseData> responseList =
            getDataIntegrationController.doPost();



    }
    
     @isTest
    static void testInvoicePost6() {

        // Products used by line items
        createProduct('SKU100', 'EA', 1);
        createProduct('SKU200', 'CS', 12);

        // JSON Body for Invoice
        String body = '{'+
            '"Data": {'+
            '"Invoice":[{'+
                '"invoiceNumber":"INV001",'+
                '"invoiceDate":"2025-01-01",'+
                '"SAPOrderId":"SO123",'+
                '"sfOrderId":"ORD001",'+
                '"billToParty":"CUST01",'+
                '"shipToParty":"CUST02",'+
                '"companyCode":"1000",'+
                '"delivaryPlant":"PL01",'+
                '"gstAmount":10,'+
                '"igstAmount":5,'+
                '"billAmount":100,'+
                '"InvoiceItems":['+
                    '{'+
                        '"invoiceNumber":"INV001",'+
                        '"material":"SKU10011",'+
                        '"materialDesc":"Desc1",'+
                 		'"serialNumber":"",'+
                        '"quantity":2,'+
                        '"pricePerUnit":102,'+
                        '"billAmount":100,'+
                        '"gstAmount":10,'+
                        '"igstAmount":5,'+
                        '"batch":"B1",'+
                        '"batchExpiry":"2025-12-31"'+
                    '}'+
                ']'+
            '}]'+
            '} }';

        // Setting Request Context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/api/Invoice';
        req.requestBody = Blob.valueOf(body);

        RestContext.request = req;
        RestContext.response = res;

        // Call Method
        List<getDataIntegrationController.responseData> responseList =
            getDataIntegrationController.doPost();



    }
    
        // ---------------------------------------------------------
    // TEST CASE: Invoice Integration
    // ---------------------------------------------------------
    @isTest
    static void testInvoicePost1() {
        
        // Products used by line items
        createProduct('SKU100', 'EA', 1);
        createProduct('SKU200', 'CS', 12);
        
        // JSON Body for Invoice
        String body = '{'+
            '"Data": {'+
            '"Invoice":[{'+
            '"invoiceNumber":"INV001",'+
            '"invoiceDate":"",'+
            '"SAPOrderId":"SO123",'+
            '"sfOrderId":"ORD001",'+
            '"billToParty":"CUST01",'+
            '"shipToParty":"CUST02",'+
            '"companyCode":"1000",'+
            '"delivaryPlant":"PL01",'+
            '"gstAmount":10,'+
            '"igstAmount":5,'+
            '"billAmount":100,'+
            '"InvoiceItems":['+
            '{'+
            '"invoiceNumber":"INV001",'+
            '"material":"SKU100",'+
            '"materialDesc":"Desc1",'+
            '"quantity":2,'+
            '"pricePerUnit":50,'+
            '"billAmount":100,'+
            '"gstAmount":10,'+
            '"igstAmount":5,'+
            '"batch":"B1",'+
            '"batchExpiry":"2025-12-31"'+
            '}'+
            ']'+
            '}]'+
            '} }';
        
        // Setting Request Context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/api/Invoice';
        req.requestBody = Blob.valueOf(body);
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call Method
        List<getDataIntegrationController.responseData> responseList =
            getDataIntegrationController.doPost();
        
        
        
    }
    

    // ---------------------------------------------------------
    // TEST CASE: Stock Integration
    // ---------------------------------------------------------
    @isTest
    static void testStockPost() {

        // Create product for stock mapping
        createProduct('SKU300', 'EA', 1);

        // JSON Body for Stock
        String body = '['+
            '{'+
                '"Delivery_Plant__c":"P1",'+
                '"SKU_Code__c":"SKU300",'+
                '"Quantity__c":20'+
            '}'+
        ']';

        // Set request context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/api/Stock';
        req.requestBody = Blob.valueOf(body);

        RestContext.request = req;
        RestContext.response = res;

        // Call method
        List<getDataIntegrationController.responseData> responseList =
            getDataIntegrationController.doPost();



    }

    // ---------------------------------------------------------
    // TEST CASE: Invoice Integration - Successful line items
    // Exercises both UOM branches (matching / non-matching) and
    // the success response path with resolvable Account lookups.
    // ---------------------------------------------------------
    @isTest
    static void testInvoicePostSuccess() {

        // Stores resolvable via SAP_Customer_Code__c external id lookup
        createStore('CUST01');
        createStore('CUST02');

        // SKU100 UOM matches the line item UOM -> "Each" branch
        // SKU200 UOM differs from the line item UOM -> alternate branch
        createProductWithUom('SKU100', 'EA', 1);
        createProductWithUom('SKU200', 'Nos', 12);

        // JSON Body for Invoice with two valid line items
        String body = '{'+
            '"Data": {'+
            '"Invoice":[{'+
                '"invoiceNumber":"INV001",'+
                '"invoiceDate":"2025-01-01",'+
                '"SAPOrderId":"SO123",'+
                '"sfOrderId":"ORD001",'+
                '"billToParty":"CUST01",'+
                '"shipToParty":"CUST02",'+
                '"companyCode":"1000",'+
                '"delivaryPlant":"PL01",'+
                '"gstAmount":10,'+
                '"igstAmount":5,'+
                '"billAmount":100,'+
                '"InvoiceItems":['+
                    '{'+
                        '"invoiceNumber":"INV001",'+
                        '"material":"SKU100",'+
                        '"serialNumber":"111",'+
                        '"materialDesc":"Desc1",'+
                        '"quantity":2,'+
                        '"uom":"EA",'+
                        '"pricePerUnit":50,'+
                        '"billAmount":100,'+
                        '"gstAmount":10,'+
                        '"igstAmount":5,'+
                        '"batch":"B1",'+
                        '"batchExpiry":"2025-12-31"'+
                    '},'+
                    '{'+
                        '"invoiceNumber":"INV001",'+
                        '"material":"SKU200",'+
                        '"serialNumber":"222",'+
                        '"materialDesc":"Desc2",'+
                        '"quantity":3,'+
                        '"uom":"EA",'+
                        '"pricePerUnit":120,'+
                        '"billAmount":360,'+
                        '"gstAmount":18,'+
                        '"igstAmount":9,'+
                        '"batch":"B2",'+
                        '"sfOrderId":"ORD001"'+
                    '}'+
                ']'+
            '}]'+
            '} }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/api/Invoice';
        req.requestBody = Blob.valueOf(body);

        RestContext.request = req;
        RestContext.response = res;

        List<getDataIntegrationController.responseData> responseList =
            getDataIntegrationController.doPost();

    }

    // ---------------------------------------------------------
    // TEST CASE: Invoice Integration - Line item error branches
    // Covers SKU-missing, UOM-conversion-missing, price-missing
    // and serial-number-missing validation paths (uom supplied so
    // each item reaches the deeper checks).
    // ---------------------------------------------------------
    @isTest
    static void testInvoicePostItemErrors() {

        createStore('CUST01');
        createStore('CUST02');

        createProductWithUom('SKU100', 'EA', 1);     // valid product, conversion present
        createProductWithUom('SKUNULL', 'EA', null); // conversion missing

        String body = '{'+
            '"Data": {'+
            '"Invoice":[{'+
                '"invoiceNumber":"INV001",'+
                '"invoiceDate":"2025-01-01",'+
                '"SAPOrderId":"SO123",'+
                '"sfOrderId":"ORD001",'+
                '"billToParty":"CUST01",'+
                '"shipToParty":"CUST02",'+
                '"companyCode":"1000",'+
                '"delivaryPlant":"PL01",'+
                '"gstAmount":10,'+
                '"igstAmount":5,'+
                '"billAmount":100,'+
                '"InvoiceItems":['+
                    '{'+
                        '"invoiceNumber":"INV001",'+
                        '"material":"SKUXXX",'+
                        '"serialNumber":"a1",'+
                        '"quantity":2,'+
                        '"uom":"EA",'+
                        '"pricePerUnit":10'+
                    '},'+
                    '{'+
                        '"invoiceNumber":"INV001",'+
                        '"material":"SKUNULL",'+
                        '"serialNumber":"a2",'+
                        '"quantity":2,'+
                        '"uom":"EA",'+
                        '"pricePerUnit":10'+
                    '},'+
                    '{'+
                        '"invoiceNumber":"INV001",'+
                        '"material":"SKU100",'+
                        '"serialNumber":"a3",'+
                        '"quantity":2,'+
                        '"uom":"EA",'+
                        '"pricePerUnit":null'+
                    '},'+
                    '{'+
                        '"invoiceNumber":"INV001",'+
                        '"material":"SKU100",'+
                        '"serialNumber":"",'+
                        '"quantity":2,'+
                        '"uom":"EA",'+
                        '"pricePerUnit":10'+
                    '}'+
                ']'+
            '}]'+
            '} }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/api/Invoice';
        req.requestBody = Blob.valueOf(body);

        RestContext.request = req;
        RestContext.response = res;

        List<getDataIntegrationController.responseData> responseList =
            getDataIntegrationController.doPost();

    }

    // ---------------------------------------------------------
    // TEST CASE: Invoice Integration - Bill To Party missing
    // Covers the bill-to-party validation branch on the header.
    // ---------------------------------------------------------
    @isTest
    static void testInvoicePostBillToMissing() {

        createProductWithUom('SKU100', 'EA', 1);

        String body = '{'+
            '"Data": {'+
            '"Invoice":[{'+
                '"invoiceNumber":"INV001",'+
                '"invoiceDate":"2025-01-01",'+
                '"SAPOrderId":"SO123",'+
                '"billToParty":"",'+
                '"companyCode":"1000",'+
                '"delivaryPlant":"PL01",'+
                '"gstAmount":10,'+
                '"igstAmount":5,'+
                '"billAmount":100,'+
                '"InvoiceItems":[]'+
            '}]'+
            '} }';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/api/Invoice';
        req.requestBody = Blob.valueOf(body);

        RestContext.request = req;
        RestContext.response = res;

        List<getDataIntegrationController.responseData> responseList =
            getDataIntegrationController.doPost();

    }

    // ---------------------------------------------------------
    // TEST CASE: Stock Integration - DML failure path
    // SKU_Code__c is null so the External_ID__c becomes invalid and
    // the upsert reports a failure, exercising the error response.
    // ---------------------------------------------------------
    @isTest
    static void testStockPostError() {

        String body = '['+
            '{'+
                '"Delivery_Plant__c":"P1",'+
                '"Quantity__c":20'+
            '}'+
        ']';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/api/Stock';
        req.requestBody = Blob.valueOf(body);

        RestContext.request = req;
        RestContext.response = res;

        List<getDataIntegrationController.responseData> responseList =
            getDataIntegrationController.doPost();

    }

    // ---------------------------------------------------------
    // TEST CASE: Unknown object name -> no branch executed
    // Covers the default flow where neither Invoice nor Stock runs.
    // ---------------------------------------------------------
    @isTest
    static void testUnknownObject() {

        String body = '{}';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/api/Unknown';
        req.requestBody = Blob.valueOf(body);

        RestContext.request = req;
        RestContext.response = res;

        List<getDataIntegrationController.responseData> responseList =
            getDataIntegrationController.doPost();

    }
}