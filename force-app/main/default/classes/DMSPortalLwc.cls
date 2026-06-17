public without sharing class DMSPortalLwc {
    
    public class SecondaryReceiptItemWrapper {
        @AuraEnabled public String rowIndex       { get; set; }
        @AuraEnabled public String name           { get; set; }
        @AuraEnabled public String docNo          { get; set; }
        @AuraEnabled public String createdDate    { get; set; }
        @AuraEnabled public Decimal amount        { get; set; }
        @AuraEnabled public String itemType       { get; set; } // 'Invoice' or 'DebitNote'
    }
    
    @AuraEnabled 
    public static List<SecondaryReceiptItemWrapper> getSecondaryReceiptItemsByReceiptId(Id receiptId) {
        List<SecondaryReceiptItemWrapper> wrapperList = new List<SecondaryReceiptItemWrapper>();
        
        // Fetch Invoice Receipt Items
        List<Secondary_Receipt_Item__c> invoiceItems = [
            SELECT Name, Amount__c, CreatedDate, Secondary_Invoice__r.Name
            FROM Secondary_Receipt_Item__c
            WHERE Secondary_Receipt__c = :receiptId
        ];
        
        // Fetch Debit Note Receipt Items
        List<Secondary_Receipt_Debit_Item__c> debitItems = [
            SELECT Name, Amount__c, CreatedDate, Secondary_Debit_Note__r.Name
            FROM Secondary_Receipt_Debit_Item__c
            WHERE Secondary_Receipt__c = :receiptId
        ];
        
        Integer index = 1;
        
        for (Secondary_Receipt_Item__c item : invoiceItems) {
            SecondaryReceiptItemWrapper w = new SecondaryReceiptItemWrapper();
            w.name        = item.Name;
            w.docNo       = item.Secondary_Invoice__r != null ? item.Secondary_Invoice__r.Name : '';
            w.createdDate = item.CreatedDate != null ? String.valueOf(item.CreatedDate.date()) : '';
            w.amount      = item.Amount__c;
            w.itemType    = 'Invoice';
            wrapperList.add(w);
        }
        
        for (Secondary_Receipt_Debit_Item__c dn : debitItems) {
            SecondaryReceiptItemWrapper w = new SecondaryReceiptItemWrapper();
            w.name        = dn.Name;
            w.docNo       = dn.Secondary_Debit_Note__r != null ? dn.Secondary_Debit_Note__r.Name : '';
            w.createdDate = dn.CreatedDate != null ? String.valueOf(dn.CreatedDate.date()) : '';
            w.amount      = dn.Amount__c;
            w.itemType    = 'DebitNote';
            wrapperList.add(w);
        }
        
        return wrapperList;
    }
    /**
     * Fetch secondary invoices for a customer with pending amount > 0
     * @param customerId The Id of the secondary customer
     * @return List of SecInvData for invoices with Pending_Amount__c > 0
     */
    @AuraEnabled(cacheable=false)
    public static List<SecInvData> getPendingSecondaryInvoicesByCustomer(Id customerId) {
        List<SecInvData> result = new List<SecInvData>();
        if (customerId == null) return result;
        List<Secondary_Invoice__c> invoices = [
            SELECT Id, Name, Invoice_Date__c, Grand_Total__c, Paid_Invoice_Amount__c, Pending_Amount__c, Customer__c, Customer__r.Name, Total_Quantity__c, Total_Tax__c, Status__c
            FROM Secondary_Invoice__c
            WHERE Customer__c = :customerId AND Pending_Amount__c > 0
            ORDER BY Invoice_Date__c ASC
        ];
        for (Secondary_Invoice__c inv : invoices) {
            SecInvData data = new SecInvData();
            data.name = inv.Name;
            data.InvId = inv.Id;
            data.InvDate = inv.Invoice_Date__c != null ? DateTime.newInstance(inv.Invoice_Date__c.year(), inv.Invoice_Date__c.month(), inv.Invoice_Date__c.day()).format('dd/MM/yyyy') : '';
            data.accId = inv.Customer__c;
            data.accName = inv.Customer__r != null ? inv.Customer__r.Name : '';
            data.Amount = inv.Grand_Total__c;
            data.paidAmount = inv.Paid_Invoice_Amount__c;
            data.Status = inv.Status__c;
            data.pendingAmount = inv.Pending_Amount__c;
            data.tax = inv.Total_Tax__c;
            data.Quantity = inv.Total_Quantity__c;
            // Add extra fields for paid and pending amounts if needed in JS
            // You can extend SecInvData if you want to expose Paid_Invoice_Amount__c and Pending_Amount__c
            result.add(data);
        }
        return result;
    }
    // Wrapper for Secondary Receipt
    public class SecondaryReceipt {
        @AuraEnabled public String receiptNo;
        @AuraEnabled public String receiptId;
        @AuraEnabled public String customerName;
        @AuraEnabled public String customerId;
        @AuraEnabled public String paymentDate;
        @AuraEnabled public String paymentMode;
        @AuraEnabled public String referenceNumber;
        @AuraEnabled public String remarks;
        @AuraEnabled public Decimal totalAmount;
    }
    //Graph Data
    @AuraEnabled
    public static GraphData getGraphData(){
        
        GraphData dt = new GraphData();
        dt.formattedUsersSales = salesData();
        dt.formattedUsersOrder = orderData();
        dt.graphlist = targetData();
        return dt;
    }
    @AuraEnabled
    public static List<Map<String, String>> salesData() {
        // Aggregate query to sum Grand_Total__c by month for the selected user
        List<AggregateResult> results = [
            SELECT CALENDAR_MONTH(Invoice_Date__c) month,CALENDAR_YEAR(Invoice_Date__c) year, SUM(Grand_Total__c) totalGrandTotal
            FROM Invoice__c WHERE Closed_Date__c = THIS_YEAR AND OwnerId =:UserInfo.getUserId()
            GROUP BY CALENDAR_MONTH(Invoice_Date__c), CALENDAR_YEAR(Invoice_Date__c)
            ORDER BY CALENDAR_YEAR(Invoice_Date__c) ASC, CALENDAR_MONTH(Invoice_Date__c) ASC
        ];
        
        Map<Integer, String> monthNames = new Map<Integer, String>{
            1 => 'JAN', 2 => 'FEB', 3 => 'MAR', 4 => 'APR', 5 => 'MAY', 6 => 'JUN', 
                7 => 'JUL', 8 => 'AUG', 9 => 'SEP', 10 => 'OCT', 11 => 'NOV', 12 => 'DEC'
                };
                    
                    List<Map<String, String>> formattedUsersSales = new List<Map<String, String>>();
        
        for (AggregateResult ar : results) {
            Integer monthNum = (Integer) ar.get('month'); 
            Integer yearNum = (Integer) ar.get('year');    
            Decimal total = (Decimal) ar.get('totalGrandTotal'); 
            
            Map<String, String> dataMap = new Map<String, String>{
                'monthName' => monthNames.get(monthNum) + ' - ' + String.valueOf(yearNum),
                    'totalGrandTotal' => String.valueOf(total)
                    };
                        
                        formattedUsersSales.add(dataMap);
        }
        
        System.debug('dt :' + formattedUsersSales);
        return formattedUsersSales;
    }
    @AuraEnabled
    public static List<Map<String, String>> orderData(){
        
        List<AggregateResult> results = [
            SELECT CALENDAR_MONTH(Order_Date__c) month, 
            CALENDAR_YEAR(Order_Date__c) year, 
            SUM(Grand_Total__c) totalGrandTotal
            FROM Order__c
            WHERE Order_Date__c = THIS_YEAR AND OwnerId =:UserInfo.getUserId()
            GROUP BY CALENDAR_MONTH(Order_Date__c), CALENDAR_YEAR(Order_Date__c)
            ORDER BY CALENDAR_YEAR(Order_Date__c) ASC, CALENDAR_MONTH(Order_Date__c) ASC
        ];
        
        Map<Integer, String> monthNames = new Map<Integer, String>{
            1 => 'JAN', 2 => 'FEB', 3 => 'MAR', 4 => 'APR', 5 => 'MAY', 6 => 'JUN', 
                7 => 'JUL', 8 => 'AUG', 9 => 'SEP', 10 => 'OCT', 11 => 'NOV', 12 => 'DEC'
                };
                    List<Map<String, String>> formattedUsersOrder = new List<Map<String, String>>();
        for (AggregateResult ar : results) {
            Integer monthNum = (Integer) ar.get('month');  
            Integer yearNum = (Integer) ar.get('year');    
            Decimal total = (Decimal) ar.get('totalGrandTotal'); 
            
            Map<String, String> dataMap = new Map<String, String>{
                'monthName' => monthNames.get(monthNum) + ' - ' + String.valueOf(yearNum),
                    'totalGrandTotal' => String.valueOf(total)
                    };
                        
                        formattedUsersOrder.add(dataMap);
        }
        
        return formattedUsersOrder;
    }
    @AuraEnabled
    public static List<kpi_graph_target> targetData() {
        List<Target__c> tarList = [SELECT Id, Name, Achieved_Percentage__c, Executive__c, Executive__r.Name, 
                                   Account__c, Actual__c, Target__c, Period__c, Period__r.Name
                                   FROM Target__c  
                                   WHERE CreatedDate = THIS_MONTH AND OwnerId =:UserInfo.getUserId()
                                   ORDER BY Achieved_Percentage__c DESC NULLS LAST 
                                   LIMIT 5000];
        
        List<kpi_graph_target> graphlist = new List<kpi_graph_target>();
        
        for (Target__c tr : tarList) {
            kpi_graph_target graph = new kpi_graph_target();
            graph.xAxis = tr.Period__r.Name;
            graph.actual = tr.Actual__c;
            graph.target = tr.Target__c;
            graphlist.add(graph);
        }
        
        return graphlist;
    }
    
    //Order Data
    @AuraEnabled
    public static DmsData allOrderData(String status, Date frmDate, Date toDate, String orderType) {
        DmsData dt = new DmsData();
        
        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        if(partnerUser.size() >0){
            List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            accountId = contact[0].AccountId;
        }
        
        Account acc = [select Id,Name,SAP_Customer_Code__c from Account where Id =:accountId ];
        dt.customerNameWithCode = acc.Name +'( '+acc.SAP_Customer_Code__c + ')';
        
        // Build SOQL query for Order__c with Order_Items__r subquery
        String query = 'SELECT Id, Name, Account__c, Account__r.Name, Total_Quantity__c, Grand_Total__c, Order_Date__c,Total_Weight_in_KG__c,Base_Amount__c,Total_Tax_Amount__c, ' +
            '(SELECT Id, Name, Product__c, Product__r.Name, Quantity__c, Total_Amount__c, Tax_Percent__c, Unit_price__c,NET_WEIGHT__c,Non_Taxable_Order_Value__c,Tax_Amount__c FROM Order_Items__r) ' +
            'FROM Order__c ' +
            'WHERE Order_Date__c >= :frmDate AND Order_Date__c <= :toDate ' +
            'AND Account__c =: accountId ';
        
        if (status != 'All') {
            query += 'AND Order_Status__c = :status ';
        }
        
        query += 'ORDER BY CreatedDate DESC';
        List<Order__c> ord = Database.query(query);
        System.debug('Raw Orders Count: ' + ord.size());
        System.debug('Raw Orders: ' + ord);
        
        Set<Id> uniqueOrderIds = new Set<Id>();
        List<OrdData> ordDt = new List<OrdData>();
        
        for (Order__c o : ord) {
            if (uniqueOrderIds.contains(o.Id)) {
                System.debug('Duplicate Order Skipped: ' + o.Id + ' - ' + o.Name);
                continue;
            }
            uniqueOrderIds.add(o.Id);
            
            String formattedOrdDate = o.Order_Date__c != null 
                ? DateTime.newInstance(o.Order_Date__c.year(), o.Order_Date__c.month(), o.Order_Date__c.day()).format('dd/MM/yyyy') 
                : '';
            
            OrdData order = new OrdData();
            order.orderId = o.Id;
            order.orderNo = o.Name;
            order.quantity = o.Total_Quantity__c;
            order.orderDate = formattedOrdDate;
            order.amount = o.Grand_Total__c;
            order.customerId = o.Account__c;
            order.customerName = o.Account__r.Name;
            order.tax = 0;
            order.totalWeight = o.Total_Weight_in_KG__c;
            order.baseAmount = o.Base_Amount__c;
            order.taxAmount =o.Total_Tax_Amount__c;
            order.items = new List<Order_Item__c>(); // Use a custom wrapper for items
            
            for (Order_Item__c item : o.Order_Items__r) {
                order.items.add(item);
            }
            System.debug('Order ' + o.Name + ' has ' + order.items.size() + ' items: ' + order.items);
            
            ordDt.add(order);
        }
        
        System.debug('Processed Orders Count: ' + ordDt.size());
        System.debug('Processed Orders: ' + ordDt);
        
        dt.TotalOrderData = ordDt;
        dt.statusOptions = getStatusOptions('Order__c', 'Order_Status__c');
        return dt;
    }
    
    //Invoice Data
    @AuraEnabled(cacheable=true)
    public static DmsData allInvoiceData(String status, Date frmDate, Date toDate) {
        DmsData dt = new DmsData();
        List<Invoice__c> inv;
        
        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        if(partnerUser.size() >0){
            List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            accountId = contact[0].AccountId;
        }
        system.debug('frmDate '+frmDate+' toDate '+toDate);
        system.debug('statusstatus '+status);
        system.debug('accountIdaccountId '+accountId);

        if (status == 'All') {
            inv = [
                SELECT Id, Name, Store__c, Invoice_Date__c, isDisabled__c, Status__c, Total_Amount__c, Store__r.Name,
                Total_Quantity__c, Grand_Total__c, Total_Tax_Amount__c,Pending_Amount__c,GRN_Status__c,Invoice_No__c,SF_Order__r.Name,
                Company_Name__c, GST_Number__c, Non_Taxable_Amount__c, SGST_Amount__c, CGST_Amount__c, IGST_Amount__c
                FROM Invoice__c
                where Store__c =: accountId
                AND Invoice_Date__c >= :frmDate
                AND Invoice_Date__c <= :toDate
                ORDER BY Invoice_Date__c DESC
            ];
        } else if(status == 'GRN Pending'){
            inv = [
                SELECT Id, Name, Store__c, Invoice_Date__c, isDisabled__c, Status__c, Total_Amount__c, Store__r.Name,
                Total_Quantity__c, Grand_Total__c, Total_Tax_Amount__c, Pending_Amount__c,GRN_Status__c,Invoice_No__c,SF_Order__r.Name,
                Company_Name__c, GST_Number__c, Non_Taxable_Amount__c, SGST_Amount__c, CGST_Amount__c, IGST_Amount__c
                FROM Invoice__c
                WHERE (GRN_Status__c = 'GRN Pending' OR GRN_Status__c ='')
                AND Invoice_Date__c >= :frmDate
                AND Invoice_Date__c <= :toDate
                AND Store__c =: accountId
                ORDER BY Invoice_Date__c DESC
            ];
        }else if(status =='GRN Completed'){
            inv = [
                SELECT Id, Name, Store__c, Invoice_Date__c, isDisabled__c, Status__c, Total_Amount__c, Store__r.Name,
                Total_Quantity__c, Grand_Total__c, Total_Tax_Amount__c, Pending_Amount__c,GRN_Status__c,Invoice_No__c,SF_Order__r.Name,
                Company_Name__c, GST_Number__c, Non_Taxable_Amount__c, SGST_Amount__c, CGST_Amount__c, IGST_Amount__c
                FROM Invoice__c
                WHERE (GRN_Status__c = 'GRN Completed')
                AND Invoice_Date__c >= :frmDate
                AND Invoice_Date__c <= :toDate
                AND Store__c =: accountId
                ORDER BY Invoice_Date__c DESC
            ];
        }
        
        List<InvData> invDt = new List<InvData>();
        for (Invoice__c i : inv) {
            String formattedDate = i.Invoice_Date__c != null
                ? DateTime.newInstance(i.Invoice_Date__c.year(), i.Invoice_Date__c.month(), i.Invoice_Date__c.day()).format('dd/MM/yyyy')
                : '';
            InvData inD = new InvData();
            inD.name = i.Name;
            inD.InvId = i.Id;
            inD.isDisabled = i.isDisabled__c;
            inD.InvDate = formattedDate;
            inD.accId = i.Store__c;
            inD.accName = i.Store__r != null ? i.Store__r.Name : '';
            inD.Amount = i.Grand_Total__c !=null ?i.Grand_Total__c : 0  ;
            inD.Status = i.Status__c;
            inD.tax = i.Total_Tax_Amount__c != null ?  i.Total_Tax_Amount__c : 0;
            inD.TotalQuantity = i.Total_Quantity__c != null ? i.Total_Quantity__c :0 ; 
            inD.invoiceNo = i.Invoice_No__c != null ? i.Invoice_No__c: '';
            inD.orderId = i.SF_Order__r != null ? i.SF_Order__r.Name : '';
            inD.companyName = i.Company_Name__c != null ? i.Company_Name__c : '';
            inD.gstNumber = i.GST_Number__c != null ? i.GST_Number__c : '';
            inD.nonTaxableAmount = i.Non_Taxable_Amount__c != null ? i.Non_Taxable_Amount__c : 0;
            inD.sgstAmount = i.SGST_Amount__c != null ? i.SGST_Amount__c : 0;
            inD.cgstAmount = i.CGST_Amount__c != null ? i.CGST_Amount__c : 0;
            inD.igstAmount = i.IGST_Amount__c != null ? i.IGST_Amount__c : 0;
            invDt.add(inD);
        }
        dt.TotalInvoiceData = invDt;
        dt.statusOptions = getStatusOptions('Invoice__c', 'GRN_Status__c');
        return dt;
    }
    public class Invoice_Item_Data {
        @AuraEnabled public Id Id;
        @AuraEnabled public String ItemName;
        @AuraEnabled public Decimal Quantity;
        @AuraEnabled public Decimal TaxAmount;
        @AuraEnabled public Decimal TotalAmount;
        @AuraEnabled public Decimal unitPrice;
    }   
    @AuraEnabled(cacheable=true)
    public static List<Invoice_Item_Data> getInvoiceItems(String invoiceId) {
        if (String.isBlank(invoiceId)) {
            return new List<Invoice_Item_Data>();
        }
        
        List<Invoice_Item__c> invItems = [
            SELECT Id, Product__r.Name, SKU__r.Name,Qyt__c,GST_Amount__c, Tax_Amount__c, Bill_Amount__c,Price_per_unit__c
            FROM Invoice_Item__c
            WHERE Invoice__c = :invoiceId
            ORDER BY Product__r.Name
        ];
        
        List<Invoice_Item_Data> itemDataList = new List<Invoice_Item_Data>();
        for (Invoice_Item__c item : invItems) {
            
            Invoice_Item_Data data = new Invoice_Item_Data();
            data.Id = item.Id;
            data.ItemName = item.SKU__r != null ? item.SKU__r.Name : '';
            data.Quantity = item.Qyt__c;
            data.TaxAmount = item.GST_Amount__c;
            data.TotalAmount = item.Bill_Amount__c ;
            data.unitPrice = item.Price_per_unit__c ;
            itemDataList.add(data);
        }
        return itemDataList;
    }
    
    //newly added
    @AuraEnabled
    public static List<PrimaryReturnWrapper> getPrimaryReturns(Date frmDate, Date toDate) {
        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        if(partnerUser.size() >0){
            List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            accountId = contact[0].AccountId;
        }
        
        List<PrimaryReturnWrapper> results = new List<PrimaryReturnWrapper>();
        List<Return__c> returns = [
            SELECT Id, Name, Total_Quantity__c, Total_Amount__c, Return_Date__c
            FROM Return__c
            WHERE Return_Date__c >= :frmDate AND Return_Date__c <= :toDate and Customer__c =: accountId
            ORDER BY CreatedDate DESC
        ];
        
        for (Return__c ret : returns) {
            PrimaryReturnWrapper w = new PrimaryReturnWrapper();
            w.primaryReturnId = ret.Id;
            w.primaryReturnNo = ret.Name;
            w.totalQuantity = ret.Total_Quantity__c;
            w.totalAmount = ret.Total_Amount__c;
            w.returnDate = ret.Return_Date__c != null ? ret.Return_Date__c.format() : '';
            results.add(w);
        }
        return results;
    }
    
    // Fetch Primary Return Items by Primary Return Id
    @AuraEnabled
    public static List<Return_Item__c> getPrimaryReturnItems(Id primaryReturnId) {
        return [
            SELECT Id, SKU__r.Name, Unit_Price__c, Quantity__c, Reason_For_Return__c,Total_Amount__c
            FROM Return_Item__c
            WHERE Return__c = :primaryReturnId
        ];
    }
    
    // Wrapper for Primary Return Header
    public class PrimaryReturnWrapper {
        @AuraEnabled public Id primaryReturnId;
        @AuraEnabled public String primaryReturnNo;
        @AuraEnabled public Decimal totalQuantity;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public String returnDate;
    }
    
    @AuraEnabled
    public static DmsData allPaymentReceiptData(Date frmDate, Date toDate) {
        DmsData dt = new DmsData();
        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        if(partnerUser.size() >0){
            List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            accountId = contact[0].AccountId;
        }
        List<Collection_Item__c> paymentReceiptItems = [
            SELECT Id, Name, Invoice_Number__c, Collection__r.Name, 
            Collection__c, Amount_Received__c, Collection__r.Date__c
            FROM Collection_Item__c 
            WHERE Collection__r.Date__c >= :frmDate 
            AND Collection__r.Date__c <= :toDate and Collection__r.Customer__c =:accountId 
            ORDER BY CreatedDate DESC
        ];
        
        // Map to collect totals per Payment Receipt
        Map<Id, PaymentData> receiptMap = new Map<Id, PaymentData>();
        
        for (Collection_Item__c item : paymentReceiptItems) {
            Id receiptId = item.Collection__c;
            
            if (!receiptMap.containsKey(receiptId)) {
                Date paymentDate = item.Collection__r.Date__c;
                String formattedDate = paymentDate != null
                    ? DateTime.newInstance(paymentDate.year(), paymentDate.month(), paymentDate.day()).format('dd/MM/yyyy')
                    : '';
                
                PaymentData paymentData = new PaymentData();
                paymentData.paymenetId = receiptId;
                paymentData.paymenetNo = item.Collection__r.Name;
                paymentData.paymentDate = formattedDate;
                paymentData.Amount = 0;
                
                receiptMap.put(receiptId, paymentData);
            }
            
            // Add this item's amount to the total
            PaymentData existing = receiptMap.get(receiptId);
            existing.Amount += item.Amount_Received__c != null ? item.Amount_Received__c : 0;
        }
        
        dt.TotalPaymentData = receiptMap.values();
        return dt;
    }
    
    @AuraEnabled(cacheable=true)
    public static Collection_Item__c getPaymentReceiptDetails(Id receiptId) {
        return [
            SELECT Id, Name, Collection__r.Date__c, Amount_Received__c,Invoice_Number__c
            FROM Collection_Item__c
            WHERE Collection__c = :receiptId
            LIMIT 1
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Collection_Item__c> getReceiptItems(Id receiptId) {
        return [
            SELECT Id, Name, Collection__r.Date__c, Amount_Received__c,Invoice_Number__c
            FROM Collection_Item__c
            WHERE Collection__c = :receiptId
        ];
    }
    
    //GRN Data
    @AuraEnabled
    public static DmsData allGRNData(Date frmDate, date toDate){
        DmsData dt = new DmsData();
        list<Goods_Received_Note_Item__c> GRNItems= [select Id,Name,Invoice_Item__c,Invoice_Item__r.Name,Goods_Received_Note__r.Name,
                                                     Goods_Received_Note__c,Received_Quantity__c,Invoiced_Quantity__c,Product__c,
                                                     Product__r.Name,Goods_Received_Note__r.Invoice__c,Goods_Received_Note__r.Invoice__r.Name,
                                                     Goods_Received_Note__r.GRN_Date__c  from  Goods_Received_Note_Item__c WHERE
                                                     Goods_Received_Note__r.GRN_Date__c >= :frmDate AND Goods_Received_Note__r.GRN_Date__c <= :toDate ];
        
        
        
        List<GRNData> GRNDataList = new List<GRNData>();
        for(Goods_Received_Note_Item__c i:GRNItems){
            date Dateval = i.Goods_Received_Note__r.GRN_Date__c;
            String formattedOrdDate = Dateval != null ? DateTime.newInstance(Dateval.year(),Dateval.month(),Dateval.day()).format('dd/MM/yyyy') : '';
            GRNData grnData = new GRNData();
            grnData.GRNItemName = i.Name;
            grnData.GRNItemId = i.Id;
            grnData.productName = i.Product__r.Name;
            grnData.productId = i.Product__c;
            grnData.invoiceItemNo = i.Invoice_Item__r.Name;
            grnData.invoiceItemId = i.Invoice_Item__c;
            grnData.invoiceNo = i.Goods_Received_Note__r.Invoice__r.Name;
            grnData.invoiceId =i.Goods_Received_Note__r.Invoice__c;
            grnData.GRNDate = formattedOrdDate;
            grnData.invoicedQuantity = i.Invoiced_Quantity__c ;
            grnData.receivedQuantity = i.Received_Quantity__c ;
            grnData.GRNName = i.Goods_Received_Note__r.Name ;
            grnData.GRNId = i.Goods_Received_Note__c ;
            GRNDataList.add(grnData);
        }
        dt.TotalGRNData = GRNDataList;
        return dt;
    }
    
    // newly added GRN
    @AuraEnabled(cacheable=true)
    public static List<Goods_Received_Note_Item__c> getGRNItems(Id grnId) {
        return [
            SELECT Id, Name, Invoice_Item__c, Invoice_Item__r.Name, Invoiced_Quantity__c, Product__c, Product__r.Name,
            Received_Nonsaleable_Quantity__c,Received_Saleable_Quantity__c FROM Goods_Received_Note_Item__c
            WHERE Goods_Received_Note__c = :grnId
            ORDER BY Name
        ];
    }
    
    public class GRNFileWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String DistributionPublicUrl;
    }

    @AuraEnabled(cacheable=true)
    public static List<GRNFileWrapper> getGRNImages(Id grnId) {
        List<GRNFileWrapper> result = new List<GRNFileWrapper>();
        if (grnId == null) {
            return result;
        }

        Set<Id> contentDocIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :grnId
        ]) {
            contentDocIds.add(cdl.ContentDocumentId);
        }
        if (contentDocIds.isEmpty()) {
            return result;
        }

        for (ContentVersion cv : [
            SELECT Id, Title, FileExtension
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocIds AND IsLatest = true
        ]) {
            GRNFileWrapper f = new GRNFileWrapper();
            f.Id = cv.Id;
            f.Name = String.isNotBlank(cv.FileExtension)
                ? cv.Title + '.' + cv.FileExtension
                : cv.Title;
            f.DistributionPublicUrl = '/sfc/servlet.shepherd/version/download/' + cv.Id;
            result.add(f);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Goods_Received_Note__c> getGRNList(Date frmDate, Date toDate) {
        return [
            SELECT Id, Name, Invoice__c, Invoice__r.Name, Invoice__r.Invoice_No__c, GRN_Date__c
            FROM Goods_Received_Note__c
            WHERE GRN_Date__c >= :frmDate
            AND GRN_Date__c <= :toDate
            ORDER BY Name DESC
        ];
    }
    
    
    //Claim Data
    @AuraEnabled
    public static DmsData allClaimData(Date frmDate, date toDate,string status){
        DmsData dt = new DmsData();
        List<Claim__c> claims = new List<Claim__c>();
        String query = 'SELECT Id, Name, Claim_Amount__c, Claim_Date__c, Customer__c, Customer__r.Name, Description__c, Status__c ' +
            'FROM Claim__c WHERE Claim_Date__c >= :frmDate AND Claim_Date__c <= :toDate ORDER BY Name DESC';
        
        if ( status != 'All' && status != '' && status != null) {
            query += ' AND Status__c = :status';
        }
        
        claims = Database.query(query);
        
        List<ClaimData> ClaimDataList = new List<ClaimData>();
        for(Claim__c i:claims){
            date Dateval = i.Claim_Date__c;
            String formattedOrdDate = Dateval != null ? DateTime.newInstance(Dateval.year(),Dateval.month(),Dateval.day()).format('dd/MM/yyyy') : '';
            ClaimData claimData = new ClaimData();
            claimData.claimName = i.Name;
            claimData.claimId = i.Id;
            claimData.customerName = i.Customer__r.Name;
            claimData.customerId = i.Customer__c;
            claimData.description = i.Description__c;
            claimData.claimDate = formattedOrdDate;
            claimData.claimAmount = i.Claim_Amount__c;
            claimData.status = i.Status__c;
            ClaimDataList.add(claimData);
        }
        dt.totalClaimData = ClaimDataList;
        dt.statusOptions = getStatusOptions('Claim__c', 'Status__c');
        return dt;
    }
    //Distributor Stock 
    @AuraEnabled
    public static DmsData allDistributorStockData(String productCategory) {
        DmsData dt = new DmsData();
        Id accountId;
        
        // Step 1: Find the Account Id of the current partner user
        List<User> partnerUser = [
            SELECT ContactId 
            FROM User 
            WHERE Id = :UserInfo.getUserId()
        ];
        if (partnerUser.size() > 0) {
            List<Contact> contact = [
                SELECT AccountId 
                FROM Contact 
                WHERE Id = :partnerUser[0].ContactId 
                LIMIT 1
            ];
            accountId = contact[0].AccountId;
        }
        
        // Step 2: Get all stock records for that distributor
        List<Distributor_Stock__c> allStockList = [
            SELECT Id, Name, Distributor__r.Name, Distributor__c, GRN_Quantity__c,Product__c, Product__r.Name,
            Product__r.Product_Group__c, Product__r.Product_Sub_Group__c,
            GRN_Saleable_Quantity__c,GRN_Nonsaleable_Quantity__c,Secondary_Return_Saleable_Quantity__c,Secondary_Return_Nonsaleable_Quantity__c,
            Primary_Return_Quantity__c,Secondary_Invoice_Quantity__c,Available_Saleable_Quantity__c,Available_Nonsaleable_Quantity__c,
            Saleable_to_Non_Saleable_Quantity__c,Non_Saleable_to_Saleable_Quantity__c,Written_Off_Quantity__c,
            Product_Name__c FROM Distributor_Stock__c WHERE Distributor__c = :accountId
        ];
        
        // Step 3: Keep only the latest record per Product__c
        Map<String, Distributor_Stock__c> latestStockMap = new Map<String, Distributor_Stock__c>();
        for (Distributor_Stock__c stock : allStockList) {
            if (!latestStockMap.containsKey(stock.Product_Name__c)) {
                latestStockMap.put(stock.Product_Name__c, stock);
            }
        }
        
        // Collect Product IDs for price lookup
        Set<Id> productIds = new Set<Id>();
        for (Distributor_Stock__c stock : latestStockMap.values()) {
            if (stock.Product__c != null) {
                productIds.add(stock.Product__c);
            }
        }

        // Query Price_Book__c for primary customer prices
        Map<Id, Decimal> priceBookMap = new Map<Id, Decimal>();
        if (!productIds.isEmpty() && accountId != null) {
            for (Price_Book__c pb : [
                SELECT Product__c, Unit_Price__c FROM Price_Book__c
                WHERE Customer_Type__c = 'Primary Customer'
                AND Customer__c = :accountId
                AND Product__c IN :productIds
            ]) {
                priceBookMap.put(pb.Product__c, pb.Unit_Price__c);
            }
        }

        // Fallback: Query Product__c for List_Price__c
        Map<Id, Decimal> productListPriceMap = new Map<Id, Decimal>();
        if (!productIds.isEmpty()) {
            for (Product__c prod : [
                SELECT Id, List_Price__c FROM Product__c WHERE Id IN :productIds
            ]) {
                productListPriceMap.put(prod.Id, prod.List_Price__c);
            }
        }

        // Step 4: Build response list
        List<DistributorStock> distributorStockDataList = new List<DistributorStock>();
        for (Distributor_Stock__c i : latestStockMap.values()) {
            DistributorStock stockData = new DistributorStock();
            stockData.stockName = i.Name;
            stockData.stockId = i.Id;
            stockData.customerName = i.Distributor__r.Name;
            stockData.customerId = i.Distributor__c;
            stockData.productName = i.Product__r.Name;
            stockData.productId = i.Product__c;
            stockData.productGroup = i.Product__r.Product_Group__c;
            stockData.productSubGroup = i.Product__r.Product_Sub_Group__c;
            stockData.GRNSaleableQuantity = i.GRN_Saleable_Quantity__c;
            stockData.GRNNonSaleableQuantity = i.GRN_Nonsaleable_Quantity__c;
            stockData.SecondaryReturnSaleableQuantity = i.Secondary_Return_Saleable_Quantity__c;
            stockData.SecondaryReturnNonSaleableQuantity = i.Secondary_Return_Nonsaleable_Quantity__c;
            stockData.secoundryInvoiceQty = i.Secondary_Invoice_Quantity__c;
            stockData.primaryReturnQty = i.Primary_Return_Quantity__c;
            
            stockData.salebletoNonSaleableQty = i.Saleable_to_Non_Saleable_Quantity__c;
            stockData.nonSaleabletoSaleableQty = i.Non_Saleable_to_Saleable_Quantity__c;
            stockData.writtenOffQty = i.Written_Off_Quantity__c;

            stockData.availableSaleableQuantity = i.Available_Saleable_Quantity__c;
            stockData.availableNonSaleableQuantity = i.Available_Nonsaleable_Quantity__c;

            // Resolve unit price: Price_Book__c first, then Product__c fallback
            Decimal resolvedPrice = 0;
            if (priceBookMap.containsKey(i.Product__c)) {
                resolvedPrice = priceBookMap.get(i.Product__c) != null ? priceBookMap.get(i.Product__c) : 0;
            } else if (productListPriceMap.containsKey(i.Product__c)) {
                resolvedPrice = productListPriceMap.get(i.Product__c) != null ? productListPriceMap.get(i.Product__c) : 0;
            }
            stockData.unitPrice = resolvedPrice;
            Decimal availQty = i.Available_Saleable_Quantity__c != null ? i.Available_Saleable_Quantity__c : 0;
            stockData.totalAmount = availQty * resolvedPrice;

            distributorStockDataList.add(stockData);
        }
        
        dt.totalDistributorStockData = distributorStockDataList;
        return dt;
    }
    
    //Credit Notes
    @AuraEnabled
    public static DmsData allCreditNoteData(Date frmDate, date toDate,string status){

        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        if(partnerUser.size() >0){
            List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            accountId = contact[0].AccountId;
        }
        DmsData dt = new DmsData();
        List<Secondary_Credit_Note__c> creditNotesList = new List<Secondary_Credit_Note__c>();
        String query = 'SELECT Id, Name, Claim__c, Claim__r.Name, Credit_Date__c, Customer__c, Customer__r.Name, Status__c, Reason__c, Amount__c, Description__c '+
            'FROM Secondary_Credit_Note__c WHERE Distributor__c = :accountId AND Credit_Date__c >= :frmDate AND Credit_Date__c <= :toDate ';
        if (status != 'All' && status != '' && status != null) {
            query += ' AND Status__c = :status';
        }
        
        creditNotesList = Database.query(query);
        List<CreditNote> CreditNoteDataList = new List<CreditNote>();
        for(Secondary_Credit_Note__c i:creditNotesList){
            date Dateval = i.Credit_Date__c;
            String formattedDate = Dateval != null ? DateTime.newInstance(Dateval.year(),Dateval.month(),Dateval.day()).format('dd/MM/yyyy') : '';
            CreditNote creditNote = new CreditNote();
            creditNote.creditNoteNo = i.Name;
            creditNote.creditNoteId = i.Id;
            creditNote.customerName = i.Customer__r.Name;
            creditNote.customerId = i.Customer__c;
            creditNote.claimNo = i.Claim__r.Name;
            creditNote.claimId = i.Claim__c;
            creditNote.creditDate = formattedDate;
            creditNote.status = i.Status__c;
            creditNote.reason = i.Reason__c;
            creditNote.creditAmount = i.Amount__c;
            CreditNoteDataList.add(creditNote);
        }
        dt.totalCreditNoteData = CreditNoteDataList;
        dt.statusOptions = getStatusOptions('Secondary_Credit_Note__c', 'Status__c');
        dt.reasonOptions = getStatusOptions('Secondary_Credit_Note__c', 'Reason__c');
        return dt;
    }

    @AuraEnabled
    public static void saveCreditNote(String creditNoteJson) {
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(creditNoteJson);
        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        if(partnerUser.size() >0){
            List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            accountId = contact[0].AccountId;
        }
        Secondary_Credit_Note__c cn = new Secondary_Credit_Note__c();
        cn.Customer__c = (String) data.get('customerId');
        cn.Credit_Date__c = Date.valueOf((String) data.get('noteDate'));
        cn.Amount__c = Decimal.valueOf(String.valueOf(data.get('amount')));
        cn.Reason__c = (String) data.get('reason');
        cn.Distributor__c = accountId;
        if (data.get('description') != null) {
            cn.Description__c = (String) data.get('description');
        }

        insert cn;
    }

    //Secondary Debit Notes
    @AuraEnabled
    public static DmsData allDebitNoteData(Date frmDate, date toDate, String status){
        DmsData dt = new DmsData();
        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        if(partnerUser.size() >0){
            List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            accountId = contact[0].AccountId;
        }
        List<Secondary_Debit_Note__c> debitNotesList = new List<Secondary_Debit_Note__c>();
        String query = 'SELECT Id, Name, Note_Date__c, Customer__c, Customer__r.Name, Distributor__c, Distributor__r.Name, Status__c, Reason__c, Amount__c, Description__c, Secondary_Invoice__c, Secondary_Invoice__r.Name '+
            'FROM Secondary_Debit_Note__c WHERE Distributor__c = :accountId AND Note_Date__c >= :frmDate AND Note_Date__c <= :toDate ';
        if (status != 'All' && status != '' && status != null) {
            query += ' AND Status__c = :status';
        }
        
        debitNotesList = Database.query(query);
        List<DebitNote> DebitNoteDataList = new List<DebitNote>();
        for(Secondary_Debit_Note__c i : debitNotesList){
            date Dateval = i.Note_Date__c;
            String formattedDate = Dateval != null ? DateTime.newInstance(Dateval.year(),Dateval.month(),Dateval.day()).format('dd/MM/yyyy') : '';
            DebitNote debitNote = new DebitNote();
            debitNote.debitNoteNo = i.Name;
            debitNote.debitNoteId = i.Id;
            debitNote.customerName = i.Customer__r.Name;
            debitNote.customerId = i.Customer__c;
            debitNote.noteDate = formattedDate;
            debitNote.status = i.Status__c;
            debitNote.reason = i.Reason__c;
            debitNote.amount = i.Amount__c;
            debitNote.description = i.Description__c;
            DebitNoteDataList.add(debitNote);
        }
        dt.totalDebitNoteData = DebitNoteDataList;
        dt.statusOptions = getStatusOptions('Secondary_Debit_Note__c', 'Status__c');
        dt.reasonOptions = getStatusOptions('Secondary_Debit_Note__c', 'Reason__c');
        return dt;
    }

    @AuraEnabled
    public static void saveDebitNote(String debitNoteJson) {
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(debitNoteJson);
        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        if(partnerUser.size() >0){
            List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            accountId = contact[0].AccountId;
        }

        Secondary_Debit_Note__c dn = new Secondary_Debit_Note__c();
        dn.Customer__c = (String) data.get('customerId');
        dn.Note_Date__c = Date.valueOf((String) data.get('noteDate'));
        dn.Amount__c = Decimal.valueOf(String.valueOf(data.get('amount')));
        dn.Reason__c = (String) data.get('reason');
        dn.Distributor__c = accountId;
        if (data.get('description') != null) {
            dn.Description__c = (String) data.get('description');
        }

        insert dn;
    }
    
    //Secoundary Invoices
    @AuraEnabled
    public static DmsData allSecoundaryInvoiceData(String status,Date frmDate, date toDate){
        system.debug('status---'+status);
        DmsData dt = new DmsData();
        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        if(partnerUser.size() >0){
            List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            accountId = contact[0].AccountId;
        }
        List<Secondary_Invoice__c> inv = new List<Secondary_Invoice__c>();
        if (status == 'All' || status =='' || status == null) {
            inv = [
                SELECT Id, Name, Store__c, Invoice_Date__c, Status__c, Store__r.Name,Total_Quantity__c,Grand_Total__c,
                Total_Tax__c, Customer__c,Customer__r.Name,
                Beat_Name__c, Non_Taxable_Amount__c, SGST_Amount__c, CGST_Amount__c FROM Secondary_Invoice__c
                WHERE Invoice_Date__c >= :frmDate  AND Invoice_Date__c <= :toDate AND Store__c =: accountId ORDER BY Name DESC
            ];
        }
        else {
            inv = [
                SELECT Id, Name, Store__c, Invoice_Date__c, Status__c,Store__r.Name,Total_Quantity__c,Grand_Total__c,
                Customer__c,Customer__r.Name,Total_Tax__c,
                Beat_Name__c, Non_Taxable_Amount__c, SGST_Amount__c, CGST_Amount__c FROM Secondary_Invoice__c WHERE  Status__c = :status  AND Invoice_Date__c >= :frmDate
                AND Invoice_Date__c <= :toDate
                AND Store__c =: accountId
                ORDER BY Name DESC
            ];
        }
        
        
        
        List<SecInvData> invDt = new List<SecInvData>();
        for(Secondary_Invoice__c i:inv){
            String formattedOrdDate = i.Invoice_Date__c != null ? DateTime.newInstance(i.Invoice_Date__c.year(), i.Invoice_Date__c.month(), i.Invoice_Date__c.day()).format('dd/MM/yyyy') : '';
            SecInvData inD = new SecInvData();
            inD.name = i.Name;
            inD.InvId = i.Id;
            inD.InvDate = formattedOrdDate;
            inD.accId = i.Customer__c ;
            inD.accName = i.Customer__c != null ?  i.Customer__r.Name : '';
            inD.Amount = i.Grand_Total__c.setScale(2, RoundingMode.HALF_UP);
            inD.Status = i.Status__c;
            inD.tax = i.Total_Tax__c.setScale(2, RoundingMode.HALF_UP);
            inD.Quantity = i.Total_Quantity__c;
            inD.beatName = i.Beat_Name__c != null ? i.Beat_Name__c : '';
            inD.nonTaxableAmount = i.Non_Taxable_Amount__c != null ? i.Non_Taxable_Amount__c : 0;
            inD.sgstAmount = i.SGST_Amount__c != null ? i.SGST_Amount__c : 0;
            inD.cgstAmount = i.CGST_Amount__c != null ? i.CGST_Amount__c : 0;
            invDt.add(inD);
        }
        dt.totalSecoundaryInvoiceData = invDt;
        dt.orgUrl = label.orgUrl;
        dt.statusOptions = getStatusOptions('Secondary_Invoice__c', 'Status__c');
        return dt;
    }
    @AuraEnabled
    public static List<Secondary_Invoice_Item__c> getSecondaryInvoiceItems(Id invoiceId) {
        return [
            SELECT Product__r.Name, Quantity__c, Tax_Amount__c, Unit_Price__c, Total_Amount__c,Tax_Percent__c,Store__r.Name
            FROM Secondary_Invoice_Item__c
            WHERE Secondary_Invoice__c = :invoiceId
            ORDER BY Name 
        ];
    }

    @AuraEnabled
    public static List<Secondary_Invoice_Item__c> getSecondaryInvoiceItemsByReceiptId(Id receiptId) {
        // Get the customer from the receipt
        List<Secondary_Receipt__c> receipts = [SELECT Customer__c FROM Secondary_Receipt__c WHERE Id = :receiptId LIMIT 1];
        if (receipts.isEmpty() || receipts[0].Customer__c == null) {
            return new List<Secondary_Invoice_Item__c>();
        }
        Id customerId = receipts[0].Customer__c;
        // Get all secondary invoice items for that customer's invoices
        return [
            SELECT Product__r.Name, Quantity__c, Tax_Amount__c, Unit_Price__c, Total_Amount__c, Tax_Percent__c, Store__r.Name, Secondary_Invoice__r.Name
            FROM Secondary_Invoice_Item__c
            WHERE Secondary_Invoice__r.Customer__c = :customerId
            ORDER BY Name
        ];
    }
    
    
    //Secoundary Return Data
    @AuraEnabled
    public static DmsData allSecoundaryReturnsData(Date frmDate, Date toDate){
        DmsData dt = new DmsData();
        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        if(partnerUser.size() >0){
            List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            accountId = contact[0].AccountId;
        }
        // Fetch Secondary Returns with customer and amount, ordered by return date in descending order
        List<Return__c> secondaryReturns = [
            SELECT Id, Name, Total_Quantity__c,Customer__r.Name, Total_Amount__c, Return_Date__c
            FROM Return__c 
            WHERE Return_Date__c >= :frmDate 
            AND Return_Date__c <= :toDate
            AND Distributor__c =: accountId And Customer_Type__c = 'Secondary Customer'
            ORDER BY Name DESC
        ];
        
        // Remove duplicates (based on Secondary Return ID)
        Map<Id, Return__c> uniqueReturnsMap = new Map<Id, Return__c>();
        for (Return__c sr : secondaryReturns) {
            uniqueReturnsMap.put(sr.Id, sr);  // Store unique records in the map using ID as the key
        }
        
        // Create a list to hold the unique records
        List<SReturnData> SReturnDataList = new List<SReturnData>();
        for (Return__c sr : uniqueReturnsMap.values()) {
            SReturnData sRData = new SReturnData();
            
            // Format the return date
            Date returnDate = sr.Return_Date__c;
            String formattedOrdDate = returnDate != null ? DateTime.newInstance(returnDate.year(), returnDate.month(), returnDate.day()).format('dd/MM/yyyy') : '';
            
            // Map values from the Secondary Return to SReturnData
            sRData.secoundaryReturnNo = sr.Name;
            sRData.secoundaryReturnId = sr.Id;
            sRData.totalAmount = sr.Total_Amount__c != null ? sr.Total_Amount__c : 0;
            sRData.quantity = sr.Total_Quantity__c != null ? sr.Total_Quantity__c : 0;
            sRData.returnDate = formattedOrdDate;
            
            // Map customer name
            sRData.secondaryCustomer = sr.Customer__r != null ? sr.Customer__r.Name : '';
            
            // Add the mapped data to the list
            SReturnDataList.add(sRData);
        }
        
        dt.totalSecoundaryReturnData = SReturnDataList;
        return dt;
    }
    
    @AuraEnabled
    public static List<Return_Item__c> getSecondaryReturnItems(Id secondaryReturnId) {
        system.debug(secondaryReturnId);
        return [
            SELECT Id, SKU__r.Name, UOM__c,unit_price__c, Quantity__c, Reason_For_Return__c,Total_Amount__c,Nonsaleable_Quantity__c,
            Saleable_Quantity__c FROM Return_Item__c
            WHERE Return__c = :secondaryReturnId
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Secondary_Retrun__c> getSecondaryReturnItemList(Date frmDate, Date toDate) {
        return [
            SELECT Id,Name,Total_Amount__c,Total_Quantity__c,Secondary_Return_Date__c,Secondary_Customer__r.Name
            FROM Secondary_Retrun__c
            WHERE Secondary_Return_Date__c >= :frmDate
            AND Secondary_Return_Date__c <= :toDate
            ORDER BY Secondary_Return_Date__c DESC
        ];
    }
    
    //Get GRN Data
    @AuraEnabled
    public static list<Invoice_item__c> getGRNData(String invoiceId){
        list<Invoice_item__c> invoiceItems = [select Id,Name,Quantity__c,Product__c,Product__r.Name
                                              from Invoice_item__c where Invoice__c=:invoiceId];
        return invoiceItems;
    }
    
    //Get picklist values
    public static List<Map<String, String>> getStatusOptions(String objectName, String fieldName) {
        List<Map<String, String>> statusOptions = new List<Map<String, String>>();
        
        // Add "All" option
        Map<String, String> allOption = new Map<String, String>();
        allOption.put('label', 'All');
        allOption.put('value', 'All');
        statusOptions.add(allOption);
        
        // Get picklist values dynamically
        List<String> picklistValues = getPicklistValues(objectName, fieldName);
        
        for (String value : picklistValues) {
            Map<String, String> option = new Map<String, String>();
            option.put('label', value);
            option.put('value', value);
            statusOptions.add(option);
        }
        
        return statusOptions;
    }
    public static List<String> getPicklistValues(String objectName, String fieldName) {
        List<String> picklistValues = new List<String>();
        
        // Describe the object
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
        
        // Describe the field
        Schema.DescribeFieldResult fieldDescribe = objDescribe.fields.getMap().get(fieldName).getDescribe();
        
        // Get picklist values
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            picklistValues.add(entry.getLabel());
        }
        return picklistValues;
    }
    
    @AuraEnabled
    public static Id createPaymentWithItems(List<Payment_Receipt_Item__c> selectedinvoicesList, Decimal totalAmount) {
        
        system.debug('selectedinvoicesList'+ selectedinvoicesList);
        // 1. Create Payment Receipt
        Payment_Receipt__c receipt = new Payment_Receipt__c(
            Total_Amount__c = totalAmount,
            Payment_Date__c = Date.today()
        );
        insert receipt;
        
        List<Invoice__c> invoicesToUpdate = new List<Invoice__c>();
        // 2. Create Payment Receipt Items
        List<Payment_Receipt_Item__c> itemList = new List<Payment_Receipt_Item__c>();
        for (Payment_Receipt_Item__c inv : selectedinvoicesList) {
            inv.Payment_Receipt__c = receipt.Id;
            invoicesToUpdate.add(new Invoice__c(
                Id = inv.Invoice__c,
                Status__c = 'Paid'
            ));
        }
        
        
        insert selectedinvoicesList;
        update invoicesToUpdate;
        
        return receipt.Id;
        
    }
    
    @AuraEnabled
    public static Id createGRN(Id invoiceId, List<Goods_Received_Note_Item__c> items) {
        
        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        if(partnerUser.size() >0){
            List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            accountId = contact[0].AccountId;
        }
        system.debug(items);
        if (invoiceId == null || items == null || items.isEmpty()) {
            throw new AuraHandledException('Invoice and item list must be provided.');
        }
        
        // Step 1: Create GRN parent record
        Goods_Received_Note__c grn = new Goods_Received_Note__c(Invoice__c = invoiceId,    GRN_Date__c = System.today());
        insert grn;
        
        invoice__c inv =  new invoice__c();
        inv.Id = invoiceId;
        inv.GRN_Status__c = 'GRN Completed';
        update inv;
        
        // Step 3: Create a set of keys for existing stocks (accountId_productId)
        Set<String> keySet = new Set<String>();
        for (Goods_Received_Note_Item__c item : items) {
            String key = accountId + '_' + item.SKU_Name__c;
            keySet.add(key);
        }
        
        // Step 4: Query existing stock records using formula field
        Map<String, Distributor_Stock__c> existingStockMap = new Map<String, Distributor_Stock__c>();
        for (Distributor_Stock__c stock : [
            SELECT Id, Product__c, Distributor__c, DistributorWithProduct__c
            FROM Distributor_Stock__c
            WHERE DistributorWithProduct__c IN :keySet
        ]) {
            existingStockMap.put(stock.DistributorWithProduct__c, stock);
        }
        
        // Step 5: Create new stock records where necessary
        List<Distributor_Stock__c> newStocks = new List<Distributor_Stock__c>();
        for (Goods_Received_Note_Item__c item : items) {
            item.Goods_Received_Note__c = grn.Id;
            
            String key = accountId + '_' + item.SKU_Name__c;
            if (existingStockMap.containsKey(key)) { 
                item.Distributor_Stock__c = existingStockMap.get(key).Id;
            } else {
                Distributor_Stock__c newStock = new Distributor_Stock__c(
                    Product__c = item.Product__c,
                    Distributor__c = accountId 
                );
                newStocks.add(newStock);
                existingStockMap.put(key, newStock);
            }
        }
        
        if (!newStocks.isEmpty()) {
            insert newStocks;
            for (Distributor_Stock__c stock : newStocks) {
                String key = stock.Distributor__c + '_' + stock.Product__c;
                existingStockMap.put(key, stock);
            }
            
            for (Goods_Received_Note_Item__c item : items) {
                String key = accountId + '_' + item.SKU_Name__c;
                item.Distributor_Stock__c = existingStockMap.get(key).Id;
            }
        }
        
        // Step 6: Insert GRN items
        insert items;
        // Step 7: Enqueue email notification with PDF (TSE + reporting managers)
        if (!Test.isRunningTest() && accountId != null) {
            System.enqueueJob(new GRNNotificationQueueable(grn.Id, accountId));
        }
        // Step 8: Return GRN ID
        return grn.Id;
    }

    @AuraEnabled
    public static String saveGRNFile(Id grnId, String fileName, String base64Data) {
        if (grnId == null || String.isBlank(fileName) || String.isBlank(base64Data)) {
            throw new AuraHandledException('GRN Id, file name and file data are required.');
        }
        try {
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.ContentLocation = 'S';
            cv.OwnerId = UserInfo.getUserId();
            insert cv;

            ContentVersion insertedCv = [
                SELECT Id, ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ];

            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = insertedCv.ContentDocumentId;
            cdl.LinkedEntityId = grnId;
            cdl.ShareType = 'I';
            cdl.Visibility = 'AllUsers';
            insert cdl;

            return insertedCv.ContentDocumentId;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving GRN file: ' + e.getMessage());
        }
    }

    // Optional: fetch invoices and their line items for LWC display
    @AuraEnabled(cacheable=true)
    public static List<Invoice__c> getInvoicesByIds(List<Id> invoiceIds) {
        if (invoiceIds == null || invoiceIds.isEmpty()) {
            return new List<Invoice__c>();
        }
        
        return [
            SELECT Id, Name, Invoice_No__c, Store__r.Name,
            (SELECT Id, Name, Quantity__c, SKU__r.Name, SKU__c,Qyt_in_Each__c FROM Invoice_line_items__r where Pending_Quantity__c > 0)
            FROM Invoice__c
            WHERE Id IN :invoiceIds
        ];
    }
    
 
    // Fetch all products for search
    @AuraEnabled(cacheable=true)
    public static secondaryReturnData getAllProducts() {
        secondaryReturnData dt = new secondaryReturnData();
        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        if(partnerUser.size() >0){
            List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            accountId = contact[0].AccountId;
        }
        
        Set<String> channelSet = new Set<String>();
        List<Product_Mapping__c> prodMappingsFromPrimary = [SELECT Chanel__c, Customer__c 
                                                            FROM Product_Mapping__c  where Customer__c = :accountId];
        // Populate channelSet and primaryCustomerIds
        for(Product_Mapping__c prodMap : prodMappingsFromPrimary) {
            if (prodMap.Chanel__c != null) {
                channelSet.add(prodMap.Chanel__c);
            }
        }
        List<Product__c> products = new List<Product__c>();
        if (!channelSet.isEmpty()) {
            Set<String> productIds = new Set<String>();
            List<Sales_Channel_To_SKU__c> channels = [SELECT Id, Name, SKU__r.Name,SKU__c,Delivery_Plant__c,Sales_Channel__c
                                                      FROM Sales_Channel_To_SKU__c WHERE Sales_Channel__c IN: channelSet
                                                      and SKU__r.Is_Active__c = true];
            map<String,String> skuNameToSkuId = new map<String,String>();
            for (Sales_Channel_To_SKU__c channel : channels) {
                productIds.add(channel.SKU__r.Name);
                skuNameToSkuId.put(channel.SKU__r.Name,channel.SKU__c);
            }
            
            
            dt.productsList = [
                SELECT Id, Name, Channel__c, Product_Category_Name__c, Product_Category1__c,
                Product_Category1__r.Name, List_Price__c, MRP__c, Tax_Percent__c,
                Tax_Class__c, CreatedDate, UOM__c, Selling_Category__c,
                (SELECT Id, Unit_Price__c, MRP__c, UOM__c, Customer__c, 
                 Customer_Type__c, Region__c, Secondary_Customer_Category__c
                 FROM Price_Books__r where Customer_Type__c ='Secondary Customer' and Sales_Channel__c IN: channelSet)
                FROM Product__c  WHERE Is_Active__c = true AND Id IN :skuNameToSkuId.values()
                ORDER BY Channel__c ASC
            ];
            
            
        }
        dt.resonForReturn = extractPicklistValues('Return_Item__c', 'Reason_For_Return__c');
        dt.uom = extractPicklistValues('Return_Item__c', 'UOM__c');
        return dt;
        
    }
    
    
    
    @AuraEnabled
    public static void saveClaims(List<Claim__c> claimData) {
        
        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        if(partnerUser.size() >0){
            List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            accountId = contact[0].AccountId;
        }
        System.debug('>>> claimData: ' + JSON.serialize(claimData));
        if (claimData == null || claimData.isEmpty()) {
            throw new AuraHandledException('No claim data provided.');
        }
        
        List<Claim__c> claimsToInsert = new List<Claim__c>();
        for (Claim__c wrapper : claimData) {
            wrapper.Status__c = 'New';
            wrapper.Claim_Date__c = Date.today();
            wrapper.Customer__c = accountId;
        }
        
        insert claimData;
    }
    
    @AuraEnabled
    public static Id saveSecondaryReturn( List<Return_Item__c> items, Decimal totalAmount, Decimal totalQuantity,Id customerId) {
        if (items == null || items.isEmpty()) {
            throw new AuraHandledException('Item list must be provided.');
        }
        
        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        if(partnerUser.size() >0){
            List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            accountId = contact[0].AccountId;
        }
        
        
        // Create parent record and include customerId
        Return__c secReturn = new Return__c(
            Total_Amount__c = totalAmount,
            Total_Quantity__c = totalQuantity,
            Customer__c = customerId,
            Distributor__c = accountId,
            Return_Date__c = system.today()
        );
        insert secReturn;
        
        for(Return_Item__c rtnitem : items)
        {
            rtnitem.Return__c = secReturn.Id;
        }
        
        
        // Step 6: Insert items
        insert items;
        
        // Step 7: Return parent ID
        return secReturn.Id;
    }
    @AuraEnabled(cacheable=true)
    public static List<Account> getAllAccounts() {
        return [
            SELECT Id, Name
            FROM Account
            WHERE Customer_Type__c = 'Secondary Customer'
            ORDER BY Name ASC
            LIMIT 50000
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Account> searchCustomers(String searchKey) {
        
        if (String.isBlank(searchKey)) {
            return new List<Account>();
        }
        
        
        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        if(partnerUser.size() >0){
            List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            accountId = contact[0].AccountId;
        }
        
        
        
        
        list<Product_Mapping__c> mappinglist =  [
            SELECT Customer__c,Secondary_Customer_Name__c
            FROM Product_Mapping__c
            WHERE Primary_Customer__c = :accountId
            AND Customer_Type__c = 'Secondary Customer'
            AND Secondary_Customer_Name__c   LIKE :('%' + searchKey + '%')
            AND Customer__c != null
            ORDER BY Name
            LIMIT 20
        ]; 
        set<Id> CustomerIds = new set<Id>();
        for(Product_Mapping__c pm: mappinglist)
        {
            CustomerIds.add(pm.Customer__c);
        }
        
        return [
            select Id,Name,Land_Mark__c,Street__c from Account where Id IN: CustomerIds
        ]; 
        
        
    }
    
    
    
    @AuraEnabled
    public static DmsData getSecondaryOrders( String status, Date frmDate, Date toDate, String orderType ) {
        // Get logged-in user's AccountId
        Id accountId;
        User u = [
            SELECT Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        
        if (u.Contact != null) {
            accountId = u.Contact.AccountId;
        }
        
        DmsData dt = new DmsData();
        List<OrdData> ordDt = new List<OrdData>();
        
        if (accountId == null) {
            dt.TotalOrderData = ordDt;
            return dt;
        }
        
        // Base query
        String query = ' SELECT Id, Name, Account__c, Account__r.Name, '+
            'Total_Quantity__c, Grand_Total__c, Order_Date__c, '+
            'Secondary_Invoice_Status__c, Secondary_Invoice_Quantity__c '+
            'FROM Order__c WHERE Distributor__c = :accountId';
        
        // Date filters
        if (frmDate != null) {
            query += ' AND Order_Date__c >= :frmDate';
        }
        if (toDate != null) {
            query += ' AND Order_Date__c <= :toDate';
        }
        
        // Status filter (skip if All or blank)
        if (!String.isBlank(status) && status != 'All') {
            query += ' AND Secondary_Invoice_Status__c = :status';
        }
        
        List<Order__c> ord = Database.query(query);
        
        // Prepare response data
        for (Order__c o : ord) {
            OrdData order = new OrdData();
            date orderDate = o.Order_Date__c; String formattedOrdDate = orderDate!= null ? DateTime.newInstance(orderDate.year(), orderDate.month(),orderDate.day()).format('dd/MM/yyyy') : '';
            order.orderId = o.Id;
            order.orderNo = o.Name;
            order.quantity = o.Total_Quantity__c;
            order.status = o.Secondary_Invoice_Status__c;
            order.invoicedQuantity = o.Secondary_Invoice_Quantity__c != null ? o.Secondary_Invoice_Quantity__c : 0;
            order.amount = o.Grand_Total__c;
            order.customerId = o.Account__c;
            order.customerName = o.Account__r.Name;
            order.orderDate = formattedOrdDate;
            ordDt.add(order);
        }
        
        dt.TotalOrderData = ordDt;
        
        
        
        return dt;
    }
    // Method to fetch order items for selected orders
    @AuraEnabled
    public static List<Map<String, Object>> getOrderItems(String orderId) {
        List<Map<String, Object>> response = new List<Map<String, Object>>();

        Id accountId;
        User u = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (u.ContactId != null) {
            accountId = [
                SELECT AccountId FROM Contact WHERE Id = :u.ContactId LIMIT 1
            ].AccountId;
        }

        String beatName = '';
        String gstNumber = '';
        List<Order__c> orderList = [SELECT Beat_Name_New__c, Account__r.GST_Number__c  FROM Order__c WHERE Id = :orderId LIMIT 1];
        if (!orderList.isEmpty()) {
            if (orderList[0].Beat_Name_New__c != null) {
                beatName = orderList[0].Beat_Name_New__c;
            }
            if (orderList[0].Account__r.GST_Number__c != null) {
                gstNumber = orderList[0].Account__r.GST_Number__c;
            }
        }
        List<Order_Item__c> ordList = [
            SELECT Id, Name, Product__c, Product__r.Name,
            Quantity__c, Unit_Price__c,Tax__c,
            Tax_Percent__c, Tax_Amount__c, Total_Amount1__c,Secondary_Invoice_Pending_Quantity__c,
            Before_Category_Slab_Unit_Price__c,After_Category_Slab_Unit_Price__c,Before_Scheme_Unit_Price__c,After_Scheme_Unit_Price__c
            FROM Order_Item__c
            WHERE Order__c =: orderId
        ];
        
        Set<String> productNames = new Set<String>();
        for (Order_Item__c oi : ordList) {
            if (oi.Product__r.Name != null) {
                productNames.add(oi.Product__r.Name);
            }
        }
        
        Map<String, Decimal> stockMap = new Map<String, Decimal>();
        for (Distributor_Stock__c ds : [
            SELECT Product_Name__c, Available_Saleable_Quantity__c
            FROM Distributor_Stock__c
            WHERE Distributor__c = :accountId
            AND Product_Name__c IN :productNames
        ]) {
            stockMap.put(ds.Product_Name__c, ds.Available_Saleable_Quantity__c);
        }
        
        for (Order_Item__c item : ordList) {
            Map<String, Object> row = new Map<String, Object>();
            
            Decimal qty = item.Secondary_Invoice_Pending_Quantity__c != null ? item.Secondary_Invoice_Pending_Quantity__c : 0;
            Decimal price = item.Unit_Price__c != null ? item.Unit_Price__c : 0;
            Decimal taxPer = item.Tax__c != null ? item.Tax__c : 0;
            
            Decimal taxAmt = (price * qty * taxPer) / 100;
            Decimal totalAmt = (price * qty) + taxAmt;
            
            Decimal BeforeCategorySlabUnitPrice = item.Before_Category_Slab_Unit_Price__c;
            Decimal AfterCategorySlabUnitPrice =  item.After_Category_Slab_Unit_Price__c;
            Decimal BeforeSchemeUnitPrice = item.Before_Scheme_Unit_Price__c;
            Decimal AfterSchemeUnitPrice = item.After_Scheme_Unit_Price__c;
            
            row.put('OrderItemId', item.Id);
            row.put('ItemName', item.Name);
            row.put('ProductId', item.Product__c);
            row.put('ProductName', item.Product__r.Name);
            row.put('Quantity', qty);
            row.put('UnitPrice', price);
            row.put('TaxPercent', taxPer);
            row.put('TaxAmount', taxAmt);
            row.put('TotalAmount', totalAmt);
            
            row.put('BeforeCategorySlabUnitPrice', BeforeCategorySlabUnitPrice);
            row.put('AfterCategorySlabUnitPrice', AfterCategorySlabUnitPrice);
            row.put('BeforeSchemeUnitPrice', BeforeSchemeUnitPrice);
            row.put('AfterSchemeUnitPrice', AfterSchemeUnitPrice);
            row.put('BeatName', beatName);
            row.put('gstNumber', gstNumber);
            row.put(
                'availableQuantity',
                stockMap.containsKey(item.Product__r.Name)
                ? stockMap.get(item.Product__r.Name)
                : 0
            );
            
            response.add(row);
        }
        return response;
    }
    
     @AuraEnabled
    public static List<Map<String, Object>> getOrderlineItems(String orderId) {
        List<Map<String, Object>> response = new List<Map<String, Object>>();
        
        Id accountId;
        User u = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (u.ContactId != null) {
            accountId = [
                SELECT AccountId FROM Contact WHERE Id = :u.ContactId LIMIT 1
            ].AccountId;
        }
        
        List<Order_Item__c> ordList = [
            SELECT Id, Name, Product__c, Product__r.Name,
            Quantity__c, Unit_Price__c,Tax__c,
            Tax_Percent__c, Tax_Amount__c, Total_Amount1__c,Secondary_Invoice_Pending_Quantity__c
            FROM Order_Item__c
            WHERE Order__c =: orderId
        ];

        

        
        for (Order_Item__c item : ordList) {
            Map<String, Object> row = new Map<String, Object>();
            
            Decimal qty = item.Secondary_Invoice_Pending_Quantity__c != null ? item.Quantity__c : 0;
            Decimal price = item.Unit_Price__c != null ? item.Unit_Price__c : 0;
            Decimal taxPer = item.Tax__c != null ? item.Tax__c : 0;
            
            Decimal taxAmt = (price * qty * taxPer) / 100;
            Decimal totalAmt = (price * qty) + taxAmt;
            
            row.put('OrderItemId', item.Id);
            row.put('ItemName', item.Name);
            row.put('ProductId', item.Product__c);
            row.put('ProductName', item.Product__r.Name);
            row.put('Quantity', qty);
            row.put('UnitPrice', price);
            row.put('TaxPercent', taxPer);
            row.put('TaxAmount', taxAmt);
            row.put('TotalAmount', totalAmt);
   
            
            response.add(row);
        }
        return response;
    }
    
    @AuraEnabled
    public static Id saveSecondaryInvoice(List<Secondary_Invoice__c> invoices, List<Secondary_Invoice_Item__c> items) {
        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        if(partnerUser.size() >0){
            List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            accountId = contact[0].AccountId;
        }
        
        if (invoices == null || invoices.isEmpty()) {
            throw new AuraHandledException('At least one invoice must be provided.');
        }
        
        if (items == null || items.isEmpty()) {
            throw new AuraHandledException('At least one invoice item must be provided.');
        }
        
        for(Secondary_Invoice__c secInv : invoices){
            secInv.Customer__c = secInv.Store__c;
            secInv.Store__c = accountId;
        }
        // Insert the parent invoice(s)
        insert invoices;
        
        // Assuming only one parent invoice is being sent
        Id parentInvoiceId = invoices[0].Id;
        
        // Step 1: Get current user's Contact and Account
        
        
        // Step 2: Build keys for stock lookup
        Set<String> keySet = new Set<String>();
        for (Secondary_Invoice_Item__c item : items) {
            String key = accountId + '_' + item.Product_Name__c;
            keySet.add(key);
        }
        
        // Step 3: Load existing stocks
        Map<String, Distributor_Stock__c> existingStockMap = new Map<String, Distributor_Stock__c>();
        for (Distributor_Stock__c stock : [
            SELECT Id, Product__c, Distributor__c, DistributorWithProduct__c
            FROM Distributor_Stock__c
            WHERE DistributorWithProduct__c IN :keySet
        ]) {
            existingStockMap.put(stock.DistributorWithProduct__c, stock);
        }
        
        // Step 4: Create new stock records if needed
        List<Distributor_Stock__c> newStocks = new List<Distributor_Stock__c>();
        for (Secondary_Invoice_Item__c item : items) {
            item.Secondary_Invoice__c = parentInvoiceId;
            
            // Check if stock exists, else create new stock
            String key = accountId + '_' + item.Product_Name__c;
            if (existingStockMap.containsKey(key)) {
                item.Distributor_Stock__c = existingStockMap.get(key).Id;
            } else {
                Distributor_Stock__c newStock = new Distributor_Stock__c(
                    Product__c = item.Product__c,
                    Distributor__c = accountId
                );
                newStocks.add(newStock);
                existingStockMap.put(key, newStock);
            }
        }
        
        // Step 5: Insert new stocks if any
        if (!newStocks.isEmpty()) {
            insert newStocks;
            for (Distributor_Stock__c stock : newStocks) {
                String key = stock.Distributor__c + '_' + stock.Product__c;
                existingStockMap.put(key, stock);
            }
            
            // Update Distributor Stock reference in items
            for (Secondary_Invoice_Item__c item : items) {
                String key = accountId + '_' + item.Product__c;
                item.Distributor_Stock__c = existingStockMap.get(key).Id;
                
            }
        }
        
        // Step 6: Insert invoice items
        insert items;
        
        // Step 7: Return parent invoice ID
        return parentInvoiceId;
    }

    // ==================== Order -> Invoice (scheme re-evaluation) ====================
    // Engine-ready payload for the secondaryOrders invoice wizard: the order's items
    // (seeded at pending-to-invoice quantity), the account's running scheme coverage,
    // and the set of products that carried a scheme on the source order (to detect
    // "issues" when an invoiced quantity drops below a scheme threshold).
    public class InvoiceBuilderData {
        @AuraEnabled public List<Map<String, Object>> items;
        @AuraEnabled public beatPlannerlwc.CoverageDto coverage;
        @AuraEnabled public List<Id> orderSchemeProductIds;
        @AuraEnabled public String beatName;
        @AuraEnabled public String gstNumber;
        @AuraEnabled public Id accountId;
    }

    @AuraEnabled
    public static InvoiceBuilderData getOrderItemsForInvoice(String orderId) {
        InvoiceBuilderData out = new InvoiceBuilderData();
        out.items = new List<Map<String, Object>>();
        out.orderSchemeProductIds = new List<Id>();

        Id accountId;
        User u = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (u.ContactId != null) {
            accountId = [SELECT AccountId FROM Contact WHERE Id = :u.ContactId LIMIT 1].AccountId;
        }
        out.accountId = accountId;

        String beatName = '';
        String gstNumber = '';
        Id customerAccountId;
        List<Order__c> orderList = [
            SELECT Beat_Name_New__c, Account__c, Account__r.GST_Number__c
            FROM Order__c WHERE Id = :orderId LIMIT 1
        ];
        if (!orderList.isEmpty()) {
            if (orderList[0].Beat_Name_New__c != null) beatName = orderList[0].Beat_Name_New__c;
            if (orderList[0].Account__r.GST_Number__c != null) gstNumber = orderList[0].Account__r.GST_Number__c;
            customerAccountId = orderList[0].Account__c;
        }
        out.beatName = beatName;
        out.gstNumber = gstNumber;

        List<Order_Item__c> ordList = [
            SELECT Id, Name, Product__c, Product__r.Name, Product__r.Net_Weight__c,
                   Product__r.Product_Sub_Group__c, Product__r.Product_Category1__c,
                   Quantity__c, Unit_Price__c, Tax__c, Tax_Percent__c,
                   Secondary_Invoice_Pending_Quantity__c,
                   Before_Category_Slab_Unit_Price__c, After_Category_Slab_Unit_Price__c,
                   Before_Scheme_Unit_Price__c, After_Scheme_Unit_Price__c
            FROM Order_Item__c
            WHERE Order__c = :orderId
        ];

        Set<String> productNames = new Set<String>();
        for (Order_Item__c oi : ordList) {
            if (oi.Product__r.Name != null) productNames.add(oi.Product__r.Name);
        }
        Map<String, Decimal> stockMap = new Map<String, Decimal>();
        for (Distributor_Stock__c ds : [
            SELECT Product_Name__c, Available_Saleable_Quantity__c
            FROM Distributor_Stock__c
            WHERE Distributor__c = :accountId AND Product_Name__c IN :productNames
        ]) {
            stockMap.put(ds.Product_Name__c, ds.Available_Saleable_Quantity__c);
        }

        // FOC giveaway free qty recorded on the source order, so we seed only the PAID portion of a
        // giveaway product (the engine regenerates the free units as a separate zero-cost line).
        Map<Id, Decimal> focFree = new Map<Id, Decimal>();
        for (Order_Scheme_Applied__c osa : [
            SELECT FOC_Giveaway_Product__c, Free_Qty__c
            FROM Order_Scheme_Applied__c
            WHERE Order_Request__c = :orderId
            AND Scheme_Type__c = 'FOC Giveaway' AND FOC_Giveaway_Product__c != null
        ]) {
            Decimal q = (osa.Free_Qty__c != null) ? osa.Free_Qty__c : 0;
            Decimal cur = focFree.containsKey(osa.FOC_Giveaway_Product__c) ? focFree.get(osa.FOC_Giveaway_Product__c) : 0;
            focFree.put(osa.FOC_Giveaway_Product__c, cur + q);
        }

        for (Order_Item__c item : ordList) {
            Decimal pendingQty = item.Secondary_Invoice_Pending_Quantity__c != null
                ? item.Secondary_Invoice_Pending_Quantity__c : 0;
            // Seed only the paid portion for FOC giveaway products (free units re-added by the engine).
            Decimal seedQty = pendingQty - (focFree.containsKey(item.Product__c) ? focFree.get(item.Product__c) : 0);
            if (seedQty < 0) seedQty = 0;
            // Scheme-engine base price = the post-category-slab, pre-scheme unit price.
            Decimal baseScheme = item.Before_Scheme_Unit_Price__c != null
                ? item.Before_Scheme_Unit_Price__c
                : (item.After_Category_Slab_Unit_Price__c != null
                    ? item.After_Category_Slab_Unit_Price__c
                    : (item.Unit_Price__c != null ? item.Unit_Price__c : 0));
            Decimal taxPer = item.Tax__c != null ? item.Tax__c
                : (item.Tax_Percent__c != null ? item.Tax_Percent__c : 0);

            Map<String, Object> row = new Map<String, Object>();
            row.put('orderItemId', item.Id);
            row.put('id', item.Product__c);
            row.put('name', item.Product__r.Name);
            row.put('value', seedQty);
            row.put('orderedQty', item.Quantity__c);
            row.put('UnitPricePriceBook', baseScheme);
            row.put('taxPercent', taxPer);
            row.put('subGroup', item.Product__r.Product_Sub_Group__c);
            row.put('proCate', item.Product__r.Product_Category1__c);
            row.put('netWeight', item.Product__r.Net_Weight__c);
            // Quantity-independent category-slab unit prices carry through unchanged.
            row.put('beforeCategorySlabUnitPrice', item.Before_Category_Slab_Unit_Price__c);
            row.put('afterCategorySlabUnitPrice', item.After_Category_Slab_Unit_Price__c);
            row.put('beforeSchemeUnitPrice', baseScheme);
            row.put('availableQuantity',
                stockMap.containsKey(item.Product__r.Name) ? stockMap.get(item.Product__r.Name) : 0);
            out.items.add(row);
        }

        // Running scheme coverage for the account (same shape productScreen4 uses). Computed
        // locally WITHOUT sharing (this class is without sharing) so portal/distributor users
        // who lack row visibility to the store Account / Product_Mapping can still load schemes.
        // Degrade to empty coverage on any failure so the invoice screen still loads.
        if (customerAccountId != null) {
            try {
                out.coverage = getSchemeCoverageWS(customerAccountId);
            } catch (Exception e) {
                out.coverage = null;
            }
        }

        // Products that carried a scheme on the source order.
        Set<Id> schemeProductIds = new Set<Id>();
        for (Order_Scheme_Applied__c osa : [
            SELECT Order_Item__r.Product__c
            FROM Order_Scheme_Applied__c
            WHERE Order_Request__c = :orderId AND Order_Item__c != null
        ]) {
            if (osa.Order_Item__r.Product__c != null) schemeProductIds.add(osa.Order_Item__r.Product__c);
        }
        out.orderSchemeProductIds.addAll(schemeProductIds);
        return out;
    }

    @AuraEnabled
    public static Id saveSecondaryInvoiceWithSchemes(
        List<Secondary_Invoice__c> invoices,
        List<Secondary_Invoice_Item__c> items,
        String appliedSchemesJson
    ) {
        // Reuse the core save (header + stock + items). Items already carry the
        // engine-recomputed Before/After scheme prices and Scheme_Issue__c flags.
        Id parentInvoiceId = saveSecondaryInvoice(invoices, items);

        if (String.isBlank(appliedSchemesJson)) return parentInvoiceId;

        // Map productId -> inserted invoice item (one line per product on the invoice).
        Map<String, Id> lineByProduct = new Map<String, Id>();
        for (Secondary_Invoice_Item__c it : items) {
            if (it.Product__c != null) lineByProduct.put(String.valueOf(it.Product__c), it.Id);
        }

        List<Object> applied;
        try {
            applied = (List<Object>) JSON.deserializeUntyped(appliedSchemesJson);
        } catch (Exception e) {
            return parentInvoiceId;
        }

        List<Invoice_Scheme_Applied__c> rows = new List<Invoice_Scheme_Applied__c>();
        for (Object ao : applied) {
            if (!(ao instanceof Map<String, Object>)) continue;
            Map<String, Object> a = (Map<String, Object>) ao;
            Invoice_Scheme_Applied__c isa = new Invoice_Scheme_Applied__c();
            isa.Secondary_Invoice__c = parentInvoiceId;
            isa.Scheme__c            = toId(a.get('schemeId'));
            isa.Scheme_Slab__c       = toId(a.get('slabId'));
            isa.Scheme_Type__c       = (String) a.get('schemeType');
            isa.Free_Qty__c          = toDecimal(a.get('freeQty'));
            isa.Benefit_Amount__c    = toDecimal(a.get('benefitAmount'));
            isa.Discount_Percent__c  = toDecimal(a.get('discountPercent'));
            isa.Sequence__c          = toDecimal(a.get('sequence'));
            isa.FOC_Giveaway_Product__c = toId(a.get('focProductId'));
            isa.Descritption__c      = (String) a.get('description');
            Object pid = a.get('productId');
            if (pid != null && lineByProduct.containsKey(String.valueOf(pid))) {
                isa.Secondary_Invoice_Item__c = lineByProduct.get(String.valueOf(pid));
            }
            isa.Name = (a.get('schemeType') != null ? (String) a.get('schemeType') : 'Scheme');
            rows.add(isa);
        }
        if (!rows.isEmpty()) Database.insert(rows, false);
        return parentInvoiceId;
    }

    private static Id toId(Object v) {
        if (v == null) return null;
        String s = String.valueOf(v);
        return String.isBlank(s) ? null : (Id) s;
    }
    private static Decimal toDecimal(Object v) {
        if (v == null) return null;
        try { return Decimal.valueOf(String.valueOf(v)); } catch (Exception e) { return null; }
    }

    // ===== WITHOUT-SHARING scheme coverage =====
    // Self-contained copy of beatPlannerlwc's scheme-coverage logic, kept here so beatPlannerlwc
    // stays untouched. Because DMSPortalLwc is 'without sharing', these queries bypass sharing for
    // portal/distributor users (who lack row visibility to the store Account / Product_Mapping).
    // Pure helpers (anyMatch / buildSlabRows / formatDdMmYyyy) and the Coverage* DTOs are reused
    // from beatPlannerlwc; only its private logic is duplicated below.
    private class AccountGeoWS {
        Set<String> regions      = new Set<String>();
        Set<String> areas        = new Set<String>();
        Set<String> territoryIds = new Set<String>();
    }

    private static beatPlannerlwc.CoverageDto getSchemeCoverageWS(Id accountId) {
        beatPlannerlwc.CoverageDto out = new beatPlannerlwc.CoverageDto();
        out.schemes = new List<beatPlannerlwc.CoverageScheme>();
        out.productSchemeIds = new Map<Id, List<Id>>();
        if (accountId == null) return out;

        List<Account> accs = [
            SELECT Id, Secondary_Customer_Category__c, Customer_Type__c
            FROM Account WHERE Id = :accountId LIMIT 1
        ];
        if (accs.isEmpty()) return out;
        Account acc = accs[0];
        // These schemes apply ONLY to Secondary Customers
        if (acc.Customer_Type__c != 'Secondary Customer') return out;

        // Channel + geo come from the PORTAL DISTRIBUTOR account (the running user's account),
        // not the running user's Sales_Channel__c (portal users have none) or the executive
        // filter. The secondary customer (accountId) still drives the outlet-category match below.
        Id portalAccountId;
        User u = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (u.ContactId != null) {
            portalAccountId = [SELECT AccountId FROM Contact WHERE Id = :u.ContactId LIMIT 1].AccountId;
        }
        if (portalAccountId == null) return out;

        // Distributor's Product_Mapping rows carry Chanel__c + geo directly (same pattern as
        // getAllProducts / newStockAdjustment) — no executive filter.
        List<Product_Mapping__c> distMappings = [
            SELECT Chanel__c, Area__c, Area_Area_Name__c, Region_Name__c
            FROM Product_Mapping__c WHERE Customer__c = :portalAccountId
        ];
        Set<String> channelSet = new Set<String>();
        AccountGeoWS geo = new AccountGeoWS();
        for (Product_Mapping__c pm : distMappings) {
            if (pm.Chanel__c != null) channelSet.add(pm.Chanel__c);
            if (String.isNotBlank(pm.Region_Name__c))    geo.regions.add(pm.Region_Name__c);
            if (String.isNotBlank(pm.Area_Area_Name__c)) geo.areas.add(pm.Area_Area_Name__c);
            if (pm.Area__c != null)                      geo.territoryIds.add(String.valueOf(pm.Area__c));
        }
        if (channelSet.isEmpty()) return out;   // distributor has no channel mapping -> no schemes

        Date today = Date.today();
        List<Scheme__c> candidates = [
            SELECT Id, Name, Scheme_Type__c, Sales_Channel__c,
            Scheme_Start_Date__c, Scheme_End_Date__c,
            Scheme_Product_Group__c, Scheme_Product_Group__r.Name,
            Scheme_Product_Category__c,
            Apply_to_All_Regions__c, Apply_to_All_Areas__c,
            Apply_to_All_Territories__c, Apply_to_All_Outlet_Categories__c
            FROM Scheme__c
            WHERE IsActive__c = true
            AND Scheme_Start_Date__c <= :today
            AND Scheme_End_Date__c >= :today
            AND Sales_Channel__c IN :channelSet
        ];
        if (candidates.isEmpty()) return out;

        Set<Id> schemeIds = new Set<Id>();
        for (Scheme__c s : candidates) schemeIds.add(s.Id);

        Map<Id, Map<String, Set<String>>> appByScheme = new Map<Id, Map<String, Set<String>>>();
        for (Scheme_Applicability__c r : [
            SELECT Scheme__c, Level__c, Value_Text__c, Value_Lookup__c
            FROM Scheme_Applicability__c
            WHERE Scheme__c IN :schemeIds
        ]) {
            if (!appByScheme.containsKey(r.Scheme__c)) {
                appByScheme.put(r.Scheme__c, new Map<String, Set<String>>());
            }
            Map<String, Set<String>> lvls = appByScheme.get(r.Scheme__c);
            if (!lvls.containsKey(r.Level__c)) lvls.put(r.Level__c, new Set<String>());
            String v = (r.Value_Lookup__c != null) ? String.valueOf(r.Value_Lookup__c) : r.Value_Text__c;
            if (v != null) lvls.get(r.Level__c).add(v);
        }

        List<Scheme__c> matched = new List<Scheme__c>();
        Set<Id> matchedGroupIds = new Set<Id>();
        for (Scheme__c s : candidates) {
            if (s.Scheme_Product_Group__c == null && String.isBlank(s.Scheme_Product_Category__c) && s.Scheme_Type__c != 'Order Value') continue;
            Map<String, Set<String>> lvls = appByScheme.containsKey(s.Id) ? appByScheme.get(s.Id) : new Map<String, Set<String>>();

            Boolean regionOk = s.Apply_to_All_Regions__c == true
                || (lvls.containsKey('Region')   && beatPlannerlwc.anyMatch(lvls.get('Region'),   geo.regions));

            Boolean areaOk = s.Apply_to_All_Areas__c == true
                || (lvls.containsKey('Area')     && beatPlannerlwc.anyMatch(lvls.get('Area'),     geo.areas));

            Boolean territoryOk = s.Apply_to_All_Territories__c == true
                || (lvls.containsKey('Territory') && beatPlannerlwc.anyMatch(lvls.get('Territory'), geo.territoryIds));

            Boolean outletOk = s.Apply_to_All_Outlet_Categories__c == true
                || acc.Secondary_Customer_Category__c == null
                || (lvls.containsKey('Outlet Category') && lvls.get('Outlet Category').contains(acc.Secondary_Customer_Category__c));

            if (regionOk && outletOk && areaOk && territoryOk) {
                matched.add(s);
                if (s.Scheme_Product_Group__c != null) matchedGroupIds.add(s.Scheme_Product_Group__c);
            }
        }
        if (matched.isEmpty()) return out;

        Map<Id, List<beatPlannerlwc.CoverageProductRef>> productsByGroup = new Map<Id, List<beatPlannerlwc.CoverageProductRef>>();
        for (Scheme_Product_Group_Item__c it : [
            SELECT Scheme_Product_Group__c, Product__c, Product__r.Name, Product__r.SKU_Code__c
            FROM Scheme_Product_Group_Item__c
            WHERE Scheme_Product_Group__c IN :matchedGroupIds
            ORDER BY Product__r.Name
        ]) {
            if (it.Product__c == null) continue;
            if (!productsByGroup.containsKey(it.Scheme_Product_Group__c)) {
                productsByGroup.put(it.Scheme_Product_Group__c, new List<beatPlannerlwc.CoverageProductRef>());
            }
            beatPlannerlwc.CoverageProductRef p = new beatPlannerlwc.CoverageProductRef();
            p.id   = it.Product__c;
            p.name = it.Product__r.Name;
            p.sku  = it.Product__r.SKU_Code__c;
            productsByGroup.get(it.Scheme_Product_Group__c).add(p);
        }

        Set<Id> matchedSchemeIds = new Set<Id>();
        for (Scheme__c m : matched) matchedSchemeIds.add(m.Id);
        Map<Id, List<Scheme_Slab__c>> slabsByScheme = new Map<Id, List<Scheme_Slab__c>>();
        Set<Id> focProductIds = new Set<Id>();
        for (Scheme_Slab__c sl : [
            SELECT Id, Scheme__c, Slab_Sequence__c, Slab_Type__c,
            Qualifying_Qty_Min__c, Qualifying_Qty_Max__c,
            Qualifying_Value_Min__c, Qualifying_Value_Max__c,
            Free_Qty__c, Benefit_Amount_Per_EA__c, Benefit_Percent__c,
            FOC_Product__c, FOC_Product__r.Name
            FROM Scheme_Slab__c
            WHERE Scheme__c IN :matchedSchemeIds
            ORDER BY Slab_Sequence__c ASC NULLS LAST, CreatedDate ASC
        ]) {
            if (!slabsByScheme.containsKey(sl.Scheme__c)) slabsByScheme.put(sl.Scheme__c, new List<Scheme_Slab__c>());
            slabsByScheme.get(sl.Scheme__c).add(sl);
            if (sl.FOC_Product__c != null) focProductIds.add(sl.FOC_Product__c);
        }

        Map<Id, Product__c> focProducts = new Map<Id, Product__c>();
        if (!focProductIds.isEmpty()) {
            focProducts = new Map<Id, Product__c>([
                SELECT Id, Tax_Percent__c, List_Price__c, Price__c, MRP__c
                FROM Product__c WHERE Id IN :focProductIds
            ]);
        }

        for (Scheme__c s : matched) {
            beatPlannerlwc.CoverageScheme cs = new beatPlannerlwc.CoverageScheme();
            cs.id               = s.Id;
            cs.name             = s.Name;
            cs.schemeType       = s.Scheme_Type__c;
            cs.salesChannel     = s.Sales_Channel__c;
            cs.startDate        = s.Scheme_Start_Date__c;
            cs.endDate          = s.Scheme_End_Date__c;
            cs.validLabel       = beatPlannerlwc.formatDdMmYyyy(s.Scheme_Start_Date__c) + ' to ' + beatPlannerlwc.formatDdMmYyyy(s.Scheme_End_Date__c);
            cs.productGroupId   = s.Scheme_Product_Group__c;
            cs.productGroupName = s.Scheme_Product_Group__r == null ? null : s.Scheme_Product_Group__r.Name;
            cs.productCategory  = s.Scheme_Product_Category__c;
            cs.products         = productsByGroup.containsKey(s.Scheme_Product_Group__c)
                ? productsByGroup.get(s.Scheme_Product_Group__c)
                : new List<beatPlannerlwc.CoverageProductRef>();
            cs.slabRows         = beatPlannerlwc.buildSlabRows(s.Scheme_Type__c, slabsByScheme.get(s.Id));
            cs.groupProductIds  = new List<Id>();
            for (beatPlannerlwc.CoverageProductRef p : cs.products) cs.groupProductIds.add(p.id);
            cs.slabsRaw         = buildSlabsRawWS(slabsByScheme.get(s.Id), focProducts);
            out.schemes.add(cs);
            for (beatPlannerlwc.CoverageProductRef p : cs.products) {
                if (!out.productSchemeIds.containsKey(p.id)) out.productSchemeIds.put(p.id, new List<Id>());
                out.productSchemeIds.get(p.id).add(s.Id);
            }
        }
        return out;
    }

    // FOC price fallback (copy of beatPlannerlwc.resolveFocPrice).
    private static Decimal resolveFocPriceWS(Product__c p) {
        if (p == null) return 0;
        if (p.List_Price__c != null && p.List_Price__c > 0) return p.List_Price__c;
        if (p.Price__c != null && p.Price__c > 0) return p.Price__c;
        if (p.MRP__c != null) return p.MRP__c;
        return 0;
    }

    // Raw slab data for the JS engine (copy of beatPlannerlwc.buildSlabsRaw).
    private static List<beatPlannerlwc.CoverageSlabRaw> buildSlabsRawWS(List<Scheme_Slab__c> slabs, Map<Id, Product__c> focProducts) {
        List<beatPlannerlwc.CoverageSlabRaw> rows = new List<beatPlannerlwc.CoverageSlabRaw>();
        if (slabs == null || slabs.isEmpty()) return rows;
        for (Scheme_Slab__c sl : slabs) {
            beatPlannerlwc.CoverageSlabRaw r = new beatPlannerlwc.CoverageSlabRaw();
            r.slabId          = sl.Id;
            r.seq             = sl.Slab_Sequence__c;
            r.slabType        = sl.Slab_Type__c;
            r.qtyMin          = sl.Qualifying_Qty_Min__c;
            r.qtyMax          = sl.Qualifying_Qty_Max__c;
            r.valMin          = sl.Qualifying_Value_Min__c;
            r.valMax          = sl.Qualifying_Value_Max__c;
            r.freeQty         = sl.Free_Qty__c;
            r.benefitAmtPerEA = sl.Benefit_Amount_Per_EA__c;
            r.benefitPercent  = sl.Benefit_Percent__c;
            r.focProductId    = sl.FOC_Product__c;
            r.focProductName  = sl.FOC_Product__r == null ? null : sl.FOC_Product__r.Name;
            if (sl.FOC_Product__c != null && focProducts != null && focProducts.containsKey(sl.FOC_Product__c)) {
                Product__c fp  = focProducts.get(sl.FOC_Product__c);
                r.focUnitPrice = resolveFocPriceWS(fp);
                r.focTaxPercent = fp.Tax_Percent__c;
            }
            rows.add(r);
        }
        return rows;
    }

    // Scheme Issues report: invoice lines where a previously-applied scheme no longer
    // qualifies at the invoiced quantity (flagged at save time).
    @AuraEnabled
    public static List<ClaimReportItem> getSchemeIssueReport(String fromDate, String toDate) {
        Id accountId;
        User u = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (u.ContactId != null) {
            accountId = [SELECT AccountId FROM Contact WHERE Id = :u.ContactId LIMIT 1].AccountId;
        }
        Date frmDate = Date.valueOf(fromDate);
        Date toDateVal = Date.valueOf(toDate);

        List<ClaimReportItem> result = new List<ClaimReportItem>();
        for (Secondary_Invoice_Item__c item : [
            SELECT Product__r.Name, Quantity__c, Scheme_Issue_Reason__c,
                   Before_Scheme_Unit_Price__c, After_Scheme_Unit_Price__c, Total_Amount__c,
                   Secondary_Invoice__r.Name, Secondary_Invoice__r.Customer__r.Name,
                   Secondary_Invoice__r.Secondary_Customer_Category__c
            FROM Secondary_Invoice_Item__c
            WHERE Secondary_Invoice__r.Store__c = :accountId
            AND Secondary_Invoice__r.Invoice_Date__c >= :frmDate
            AND Secondary_Invoice__r.Invoice_Date__c <= :toDateVal
            AND Scheme_Issue__c = true
            ORDER BY Secondary_Invoice__r.Customer__r.Name, Product__r.Name
        ]) {
            ClaimReportItem r = new ClaimReportItem();
            r.category = item.Secondary_Invoice__r.Secondary_Customer_Category__c;
            r.customerName = item.Secondary_Invoice__r.Customer__r.Name;
            r.invoiceName = item.Secondary_Invoice__r.Name;
            r.productName = item.Product__r.Name;
            r.beforePrice = item.Before_Scheme_Unit_Price__c;
            r.afterPrice = item.After_Scheme_Unit_Price__c;
            r.quantity = item.Quantity__c;
            r.claimAmount = 0;
            r.totalAmount = item.Total_Amount__c;
            r.reason = item.Scheme_Issue_Reason__c;
            result.add(r);
        }
        return result;
    }

    // Fetch active products (renamed to avoid conflict)
    @AuraEnabled(cacheable=true)
    public static List<ProductWrapper> getActiveProducts() {
        List<Product__c> products = [
            SELECT Id, Name, List_Price__c, Product_Category1__r.Name, Tax_Percent__c, Is_Active__c
            FROM Product__c
            WHERE Is_Active__c = TRUE
        ];
        
        List<ProductWrapper> wrappers = new List<ProductWrapper>();
        for (Product__c p : products) {
            wrappers.add(new ProductWrapper(p));
        }
        return wrappers;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getProductCategories() {
        List<Product_Category__c> categoryRecords = [SELECT Name FROM Product_Category__c];
        List<String> categories = new List<String>();
        
        for (Product_Category__c cat : categoryRecords) {
            categories.add(cat.Name);
        }
        
        return categories;
    }
    
    @AuraEnabled
    public static String savePrimaryOrder(Order__c order, List<Order_Item__c> items) {
        return '';
       /* System.debug('===== Incoming Order Data =====');
        System.debug(JSON.serializePretty(order));
        
        System.debug('===== Incoming Order Items =====');
        System.debug(JSON.serialize(items));
        
        if (items == null || items.isEmpty()) {
            throw new AuraHandledException('No order items provided.');
        }
        
        User currentUser = [SELECT Contact_Id__c FROM User WHERE Id = :UserInfo.getUserId()];
        if (currentUser.Contact_Id__c == null) {
            throw new AuraHandledException('User is not linked to any Contact.');
        }
        
        Contact con = [SELECT AccountId FROM Contact WHERE Id = :currentUser.Contact_Id__c];
        if (con.AccountId == null) {
            throw new AuraHandledException('Contact is not linked to any Account.');
        }
        
        order.Account__c = con.AccountId;
        order.Visit_for__c = 'Primary Customer';
        
        if (order.Order_Date__c == null) {
            order.Order_Date__c = System.today();
        }
        
        insert order;
        
        Set<Id> productIds = new Set<Id>();
        for (Order_Item__c item : items) {
            productIds.add(item.Product__c);
        }
        
        Map<Id, Product__c> productMap = new Map<Id, Product__c>(
            [SELECT Id, List_Price__c, Product_Category__c FROM Product__c WHERE Id IN :productIds]
        );
        
        List<Order_Item__c> orderItemsToInsert = new List<Order_Item__c>();
        for (Order_Item__c item : items) {
            Product__c prod = productMap.get(item.Product__c);
            Decimal unitPrice = prod.List_Price__c != null ? prod.List_Price__c : 0;
            
            // Default tax percent to 18 if null on item
            Decimal taxPercent = item.Tax_Percent__c != null ? item.Tax_Percent__c : 18;
            Decimal taxAmount = (unitPrice * item.Quantity__c * taxPercent) / 100;
            Decimal totalAmount = (item.Quantity__c * unitPrice) + taxAmount;
            
            orderItemsToInsert.add(new Order_Item__c(
                Order__c = order.Id,
                Product__c = item.Product__c,
                Quantity__c = item.Quantity__c,
                Product_Category__c = prod.Product_Category__c,
                Unit_Price__c = unitPrice,
                Total_Amount__c = totalAmount,
                Tax_Percent__c = taxPercent,
                Tax_Amount__c = taxAmount
            ));
        }
        
        insert orderItemsToInsert;
        
        // Return the order ID for use in LWC
        return order.Id;*/
    }
    
    @AuraEnabled
    public static List<User> getUsers(String searchKey, String status) {
        
        //----------------------------------------------------
        //Get logged-in user's AccountId (Partner scenario)
        //----------------------------------------------------
        
        
        Id accountId;
        User u = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (u.ContactId != null) {
            accountId = [
                SELECT AccountId FROM Contact WHERE Id = :u.ContactId LIMIT 1
            ].AccountId;
        }
        
        System.debug('Resolved AccountId: ' + accountId);
        
        if (accountId == null) {
            System.debug('No AccountId found. Returning empty list.');
            return new List<User>();
        }
        
        //----------------------------------------------------
        //Get Executive Users from Employee_Customer_Assignment__c
        //----------------------------------------------------
        List<Employee_Customer_Assignment__c> assignments = [
            SELECT Executive__c
            FROM Employee_Customer_Assignment__c
            WHERE Customer__c = :accountId
            AND Executive__c != null
        ];
        
        System.debug('Assignments Found: ' + assignments.size());
        
        Set<Id> executiveUserIds = new Set<Id>();
        for (Employee_Customer_Assignment__c eca : assignments) {
            executiveUserIds.add(eca.Executive__c);
        }
        
        System.debug('Executive User IDs: ' + executiveUserIds);
        
        if (executiveUserIds.isEmpty()) {
            System.debug('No Executives mapped. Returning empty list.');
            return new List<User>();
        }
        
        //----------------------------------------------------
        //Build User Query
        //----------------------------------------------------
        String baseQuery =
            'SELECT Id, Name, Username,Executive_Name__c, Email, IsActive, CreatedDate,Manager_Name__c,Profile.Name ' +
            'FROM User WHERE Id IN :executiveUserIds';
        
        // Status filter
        if (status == 'Active') {
            baseQuery += ' AND IsActive = true';
        } else if (status == 'Inactive') {
            baseQuery += ' AND IsActive = false';
        }
        
        // Search filter
        if (String.isNotBlank(searchKey)) {
            String esc = String.escapeSingleQuotes(searchKey);
            baseQuery +=
                ' AND (Name LIKE \'%' + esc + '%\' ' +
                ' OR Email LIKE \'%' + esc + '%\')';
        }
        
        baseQuery += ' ORDER BY Name';
        
        System.debug('Final SOQL: ' + baseQuery);
        
        //----------------------------------------------------
        //Execute Query
        //----------------------------------------------------
        List<User> users = Database.query(baseQuery);
        
        System.debug('Final User Count: ' + users.size());
        System.debug('===== UserListController.getUsers END =====');
        
        return users;
    }
    
    /**Helper Methods **/  
    private static List<Map<String, String>> extractPicklistValues(String objectName, String fieldName) {
        // Get the global describe map
        Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        
        // Check if the object exists
        if (!schemaMap.containsKey(objectName)) {
            return new List<Map<String, String>>();
        }
        
        Schema.DescribeSObjectResult objDescribe = schemaMap.get(objectName).getDescribe();
        Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
        
        // Check if the field exists in the object
        if (!fieldMap.containsKey(fieldName)) {
            return new List<Map<String, String>>();
        }
        
        Schema.DescribeFieldResult fieldResult = fieldMap.get(fieldName).getDescribe();
        List<Map<String, String>> picklistValues = new List<Map<String, String>>();
        
        if (fieldResult != null && fieldResult.getType() == Schema.DisplayType.Picklist) {
            for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
                picklistValues.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                        'value' => entry.getValue()
                        });
            }
        }
        return picklistValues;
    }
    
    
    @AuraEnabled(cacheable=true)
    public static ReturnAccData getSecondaryCustomers(string status) {
        
        ReturnAccData rt = new ReturnAccData();
        
        // Get Logged-in User's Account 
        Id accountId;
        List<User> partnerUser = [
            SELECT ContactId 
            FROM User 
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        
        if (!partnerUser.isEmpty() && partnerUser[0].ContactId != null) {
            List<Contact> contacts = [
                SELECT AccountId 
                FROM Contact 
                WHERE Id = :partnerUser[0].ContactId
                LIMIT 1
            ];
            if (!contacts.isEmpty()) {
                accountId = contacts[0].AccountId;
            }
        }
        
        // Safety check
        if (accountId == null) {
            return rt;
        }
        
        // Get Beat Mappings
        List<Junction_Beat__c> beatItems = [
            SELECT Account__c, Child_beat__r.Name
            FROM Junction_Beat__c
            WHERE Primary_Customer_Record_Id__c = :accountId
        ];
        
        Map<Id, Set<String>> outletToBeatNames = new Map<Id, Set<String>>();
        
        for (Junction_Beat__c bt : beatItems) {
            if (!outletToBeatNames.containsKey(bt.Account__c)) {
                outletToBeatNames.put(bt.Account__c, new Set<String>());
            }
            outletToBeatNames.get(bt.Account__c).add(bt.Child_beat__r.Name);
        }
        
        String query =
            'SELECT Customer__c, ' +
            'Secondary_Customer_Outlet_Id__c, ' +
            'Secondary_Customer_Customer_Code__c, ' +
            'Customer__r.Name, ' +
            'Customer__r.State__c, ' +
            'Customer__r.District__c, ' +
            'Customer__r.Primary_Phone_Number__c, ' +
            'Customer__r.Secondary_Customer_Type__c, ' +
            'Primary_Customer__r.Name, ' +
            'Customer__r.Secondary_Customer_Category__c, ' +
            'Customer__r.Customer_Status__c, ' +
            'Sub_Stockiest__r.Name ,' +
            'Customer__r.Secondary_Outstanding_Amount__c, ' +
            'Customer__r.Email_ID__c, ' +
            'Customer__r.Aadhaar_No__c, ' +
            'Customer__r.GST_Number__c, ' +
            'Customer__r.Contact_Person_Name__c, ' +
            'Customer__r.PAN_Number__c, ' +
            'Customer__r.Payment_Type__c, ' +
            'Customer__r.Credit_Limit__c, ' +
            'Customer__r.Payment_Term__c, ' +
            'Customer__r.Credit_Description__c, ' +
            'Customer__r.Land_Mark__c, ' +
            'Customer__r.Street__c, ' +
            'Customer__r.Pincode__c, ' +
            'Customer__r.Last_Order_Date_Formula__c ' +
            'FROM Product_Mapping__c ' +
            'WHERE Primary_Customer__c = :accountId ' +
            'AND Is_Executive_Active__c = true ' +
            'AND Customer__r.Customer_Status__c != null ';

        //Add status condition only when NOT “All”
        if (status != 'All') {
            query += ' AND Customer__r.Customer_Status__c = :status';
        }

        List<Product_Mapping__c> mappings = Database.query(query);


        //Deduplication
        Set<Id> processedCustomerIds = new Set<Id>();
        Set<Id> subStockiestCustomers = new Set<Id>();

        List<AccData> uniqueSecondaryCustomers = new List<AccData>();
        Integer serialNo = 1;
        for (Product_Mapping__c pm : mappings) {

            if (pm.Customer__c == null || processedCustomerIds.contains(pm.Customer__c)) {
                continue;
            }

            processedCustomerIds.add(pm.Customer__c);

            if (pm.Customer__r.Secondary_Customer_Type__c == 'Sub Stockiest') {
                subStockiestCustomers.add(pm.Customer__c);
            }

            AccData d = new AccData();
            d.recordId = pm.Customer__c;
            d.sNumber = serialNo++;
            d.secondaryCustomerId = pm.Customer__c;
            d.secondaryCustomerName = pm.Customer__r.Name;
            d.secondaryCustomerOutletId = pm.Secondary_Customer_Outlet_Id__c;
            d.secondaryCustomerCode = pm.Secondary_Customer_Customer_Code__c;
            d.primaryPhoneNumber = pm.Customer__r.Primary_Phone_Number__c;
            d.state = pm.Customer__r.State__c;
            d.district = pm.Customer__r.District__c;
            d.primaryCustomerName = pm.Primary_Customer__r.Name;
            d.subStockiestName = pm.Sub_Stockiest__r != null ? pm.Sub_Stockiest__r.Name : '';
            d.customerType =  pm.Customer__r.Secondary_Customer_Type__c;
            d.customerCategory =  pm.Customer__r.Secondary_Customer_Category__c;
            d.status = pm.Customer__r.Customer_Status__c;
            d.outStanding=  pm.Customer__r.Secondary_Outstanding_Amount__c != null ? pm.Customer__r.Secondary_Outstanding_Amount__c : 0;
            d.beatName = outletToBeatNames.containsKey(pm.Customer__c)
                ? String.join(new List<String>(outletToBeatNames.get(pm.Customer__c)), ';')
                : '';
            d.email             = pm.Customer__r.Email_ID__c;
            d.aadhaarNo         = pm.Customer__r.Aadhaar_No__c;
            d.gstNumber         = pm.Customer__r.GST_Number__c;
            d.contactPersonName = pm.Customer__r.Contact_Person_Name__c;
            d.panNumber         = pm.Customer__r.PAN_Number__c;
            d.paymentType       = pm.Customer__r.Payment_Type__c;
            d.creditLimit       = pm.Customer__r.Credit_Limit__c != null ? pm.Customer__r.Credit_Limit__c : 0;
            d.paymentTerm       = pm.Customer__r.Payment_Term__c;
            d.creditDescription = pm.Customer__r.Credit_Description__c;
            d.landmark          = pm.Customer__r.Land_Mark__c;
            d.street            = pm.Customer__r.Street__c;
            d.pincode           = pm.Customer__r.Pincode__c;
            d.LastBilledDate =    pm.Customer__r.Last_Order_Date_Formula__c != null 
                                ? String.valueOf(pm.Customer__r.Last_Order_Date_Formula__c.day()).leftPad(2, '0')   + '-' +
                                String.valueOf(pm.Customer__r.Last_Order_Date_Formula__c.month()).leftPad(2, '0') + '-' +
                                String.valueOf(pm.Customer__r.Last_Order_Date_Formula__c.year())
                                : null;

            uniqueSecondaryCustomers.add(d);
        }

        rt.customerData = uniqueSecondaryCustomers;
        rt.subStockiestCount = subStockiestCustomers.size();
        rt.totalCustomersCount = processedCustomerIds.size();
        rt.secondaryCustomerCount = rt.totalCustomersCount - rt.subStockiestCount;

        return rt;
    }


    @AuraEnabled
    public static ReturnAccData getRefreshSecondaryCustomers(string status) {
        
        ReturnAccData rt = new ReturnAccData();
        
        // Get Logged-in User's Account 
        Id accountId;
        List<User> partnerUser = [
            SELECT ContactId 
            FROM User 
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        
        if (!partnerUser.isEmpty() && partnerUser[0].ContactId != null) {
            List<Contact> contacts = [
                SELECT AccountId 
                FROM Contact 
                WHERE Id = :partnerUser[0].ContactId
                LIMIT 1
            ];
            if (!contacts.isEmpty()) {
                accountId = contacts[0].AccountId;
            }
        }
        
        // Safety check
        if (accountId == null) {
            return rt;
        }
        
        // Get Beat Mappings
        List<Junction_Beat__c> beatItems = [
            SELECT Account__c, Child_beat__r.Name
            FROM Junction_Beat__c
            WHERE Primary_Customer_Record_Id__c = :accountId
        ];
        
        Map<Id, Set<String>> outletToBeatNames = new Map<Id, Set<String>>();
        
        for (Junction_Beat__c bt : beatItems) {
            if (!outletToBeatNames.containsKey(bt.Account__c)) {
                outletToBeatNames.put(bt.Account__c, new Set<String>());
            }
            outletToBeatNames.get(bt.Account__c).add(bt.Child_beat__r.Name);
        }
        
        String query =
            'SELECT Customer__c, ' +
            'Secondary_Customer_Outlet_Id__c, ' +
            'Secondary_Customer_Customer_Code__c, ' +
            'Customer__r.Name, ' +
            'Customer__r.State__c, ' +
            'Customer__r.District__c, ' +
            'Customer__r.Primary_Phone_Number__c, ' +
            'Customer__r.Secondary_Customer_Type__c, ' +
            'Primary_Customer__r.Name, ' +
            'Customer__r.Secondary_Customer_Category__c, ' +
            'Customer__r.Customer_Status__c, ' +
            'Sub_Stockiest__r.Name ,' +
            'Customer__r.Secondary_Outstanding_Amount__c, ' +
            'Customer__r.Email_ID__c, ' +
            'Customer__r.Aadhaar_No__c, ' +
            'Customer__r.GST_Number__c, ' +
            'Customer__r.Contact_Person_Name__c, ' +
            'Customer__r.PAN_Number__c, ' +
            'Customer__r.Payment_Type__c, ' +
            'Customer__r.Credit_Limit__c, ' +
            'Customer__r.Payment_Term__c, ' +
            'Customer__r.Credit_Description__c, ' +
            'Customer__r.Land_Mark__c, ' +
            'Customer__r.Street__c, ' +
            'Customer__r.Pincode__c, ' +
            'Customer__r.Last_Order_Date_Formula__c ' +
            'FROM Product_Mapping__c ' +
            'WHERE Primary_Customer__c = :accountId ' +
            'AND Is_Executive_Active__c = true ' +
            'AND Customer__r.Customer_Status__c != null ';

        //Add status condition only when NOT “All”
        if (status != 'All') {
            query += ' AND Customer__r.Customer_Status__c = :status';
        }

        List<Product_Mapping__c> mappings = Database.query(query);


        //Deduplication
        Set<Id> processedCustomerIds = new Set<Id>();
        Set<Id> subStockiestCustomers = new Set<Id>();

        List<AccData> uniqueSecondaryCustomers = new List<AccData>();
        Integer serialNo = 1;
        for (Product_Mapping__c pm : mappings) {

            if (pm.Customer__c == null || processedCustomerIds.contains(pm.Customer__c)) {
                continue;
            }

            processedCustomerIds.add(pm.Customer__c);

            if (pm.Customer__r.Secondary_Customer_Type__c == 'Sub Stockiest') {
                subStockiestCustomers.add(pm.Customer__c);
            }

            AccData d = new AccData();
            d.recordId = pm.Customer__c;
            d.sNumber = serialNo++;
            d.secondaryCustomerId = pm.Customer__c;
            d.secondaryCustomerName = pm.Customer__r.Name;
            d.secondaryCustomerOutletId = pm.Secondary_Customer_Outlet_Id__c;
            d.secondaryCustomerCode = pm.Secondary_Customer_Customer_Code__c;
            d.primaryPhoneNumber = pm.Customer__r.Primary_Phone_Number__c;
            d.state = pm.Customer__r.State__c;
            d.district = pm.Customer__r.District__c;
            d.primaryCustomerName = pm.Primary_Customer__r.Name;
            d.subStockiestName = pm.Sub_Stockiest__r != null ? pm.Sub_Stockiest__r.Name : '';
            d.customerType =  pm.Customer__r.Secondary_Customer_Type__c;
            d.customerCategory =  pm.Customer__r.Secondary_Customer_Category__c;
            d.status = pm.Customer__r.Customer_Status__c;
            d.outStanding=  pm.Customer__r.Secondary_Outstanding_Amount__c != null ? pm.Customer__r.Secondary_Outstanding_Amount__c : 0;
            d.beatName = outletToBeatNames.containsKey(pm.Customer__c)
                ? String.join(new List<String>(outletToBeatNames.get(pm.Customer__c)), ';')
                : '';
            d.email             = pm.Customer__r.Email_ID__c;
            d.aadhaarNo         = pm.Customer__r.Aadhaar_No__c;
            d.gstNumber         = pm.Customer__r.GST_Number__c;
            d.contactPersonName = pm.Customer__r.Contact_Person_Name__c;
            d.panNumber         = pm.Customer__r.PAN_Number__c;
            d.paymentType       = pm.Customer__r.Payment_Type__c;
            d.creditLimit       = pm.Customer__r.Credit_Limit__c != null ? pm.Customer__r.Credit_Limit__c : 0;
            d.paymentTerm       = pm.Customer__r.Payment_Term__c;
            d.creditDescription = pm.Customer__r.Credit_Description__c;
            d.landmark          = pm.Customer__r.Land_Mark__c;
            d.street            = pm.Customer__r.Street__c;
            d.pincode           = pm.Customer__r.Pincode__c;
            d.LastBilledDate =    pm.Customer__r.Last_Order_Date_Formula__c != null 
                                ? String.valueOf(pm.Customer__r.Last_Order_Date_Formula__c.day()).leftPad(2, '0')   + '-' +
                                String.valueOf(pm.Customer__r.Last_Order_Date_Formula__c.month()).leftPad(2, '0') + '-' +
                                String.valueOf(pm.Customer__r.Last_Order_Date_Formula__c.year())
                                : null;

            uniqueSecondaryCustomers.add(d);
        }

        rt.customerData = uniqueSecondaryCustomers;
        rt.subStockiestCount = subStockiestCustomers.size();
        rt.totalCustomersCount = processedCustomerIds.size();
        rt.secondaryCustomerCount = rt.totalCustomersCount - rt.subStockiestCount;
        
        return rt;
    }
    //=========================
    //Stock Adjustments
    //=========================
    @AuraEnabled
    public static StockAdjustmentBox getStockAdjustments(Date frmDate, Date toDate, String status) {
        
        // Get logged-in user's AccountId
        Id accountId;
        User u = [
            SELECT Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        
        if (u.Contact != null) {
            accountId = u.Contact.AccountId;
        }
        
        StockAdjustmentBox dt = new StockAdjustmentBox();
        List<StockAdjustmentData> sAdjustList = new List<StockAdjustmentData>();
        
        if (accountId == null) {
            return dt;
        }
        
        // Base query
        String query = 'SELECT Id, Name, Product__r.Name, Product__c, Reason__c, ' +
            'Quantity__c, Adjustment_Type__c, Stock_Adjustment_Date__c ' +
            'FROM Stock_Adjustment__c ' +
            'WHERE Distributor__c = :accountId';
        
        // Date filters
        if (frmDate != null) {
            query += ' AND Stock_Adjustment_Date__c >= :frmDate';
        }
        if (toDate != null) {
            query += ' AND Stock_Adjustment_Date__c <= :toDate';
        }
        
        // Status filter
        if (!String.isBlank(status) && status != 'All') {
            query += ' AND Adjustment_Type__c = :status';
        }
        
        // Execute query
        List<Stock_Adjustment__c> stockList = Database.query(query);
        
        for (Stock_Adjustment__c stl : stockList) {
            
            StockAdjustmentData st = new StockAdjustmentData();
            st.recordId = stl.Id;
            st.stockId = stl.Name;
            
            date stockDate = stl.Stock_Adjustment_Date__c;
            String formattedOrdDate = stockDate!= null ? DateTime.newInstance(stockDate.year(), stockDate.month(),stockDate.day()).format('dd/MM/yyyy') : '';
            st.stockDate = formattedOrdDate;
            st.productName = (stl.Product__c != null) ? stl.Product__r.Name : '';
            st.AdjustmentType = stl.Adjustment_Type__c;
            st.reason = stl.Reason__c;
            st.quantity = stl.Quantity__c;
            
            sAdjustList.add(st);
        }
        
        dt.stockAdjustmentList = sAdjustList;
        dt.adjustmentTypes = extractPicklistValues(
            'Stock_Adjustment__c',
            'Adjustment_Type__c'
        );
        
        return dt;
    }
    
    
    @AuraEnabled
    public static StockAdjustmentBox getStockData()
    {
        StockAdjustmentBox dt = new StockAdjustmentBox();
        dt.adjustmentTypes = extractPicklistValues('Stock_Adjustment__c', 'Adjustment_Type__c');
        // Get Logged-in User's Account 
        Id accountId;
        List<User> partnerUser = [
            SELECT ContactId 
            FROM User 
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        
        if (!partnerUser.isEmpty() && partnerUser[0].ContactId != null) {
            List<Contact> contacts = [
                SELECT AccountId 
                FROM Contact 
                WHERE Id = :partnerUser[0].ContactId
                LIMIT 1
            ];
            if (!contacts.isEmpty()) {
                accountId = contacts[0].AccountId;
            }
        }
		dt.distributorId = accountId;
        dt.distributorStocks = [
            SELECT Id, Name,Product__c,Product_Name__c,Available_Saleable_Quantity__c,Available_Nonsaleable_Quantity__c
            FROM Distributor_Stock__c  
            WHERE  Distributor__c =:accountId and Product__c != null
            ORDER BY Product_Name__c 
        ];
        
        return dt;
    }
    
    @AuraEnabled
    public static void saveStockAdjustments(list<Stock_Adjustment__c> stockAdjustments)
    {
        Set<String> keySet = new Set<String>();
        for(Stock_Adjustment__c stk: stockAdjustments)
        {
            String key = stk.Distributor__c + '_' + stk.Product_Name__c;
            keySet.add(key); 
        }
        // Step 3: Load existing stocks
        Map<String, Distributor_Stock__c> existingStockMap = new Map<String, Distributor_Stock__c>();
        for (Distributor_Stock__c stock : [
            SELECT Id, Product__c, Distributor__c, DistributorWithProduct__c
            FROM Distributor_Stock__c
            WHERE DistributorWithProduct__c IN :keySet
        ]) {
            existingStockMap.put(stock.DistributorWithProduct__c, stock);
        }
        
        // Step 4: Create new stock records if needed
        List<Distributor_Stock__c> newStocks = new List<Distributor_Stock__c>();
        for (Stock_Adjustment__c stkItem : stockAdjustments) {
            
            // Check if stock exists, else create new stock
            String key = stkItem.Distributor__c + '_' + stkItem.Product_Name__c;
            if (existingStockMap.containsKey(key)) {
                stkItem.Distributor_Stock__c = existingStockMap.get(key).Id;
            } else {
                Distributor_Stock__c newStock = new Distributor_Stock__c(
                    Product__c = stkItem.Product__c,
                    Distributor__c = stkItem.Distributor__c
                );
                newStocks.add(newStock);
                existingStockMap.put(key, newStock);
            }
        }
        
        // Step 5: Insert new stocks if any
        if (!newStocks.isEmpty()) {
            insert newStocks;
            for (Distributor_Stock__c stock : newStocks) {
                String key = stock.Distributor__c + '_' + stock.Product__c;
                existingStockMap.put(key, stock);
            }
            
            // Update Distributor Stock reference in items
            for (Stock_Adjustment__c item : stockAdjustments) {
                String key = item.Distributor__c + '_' + item.Product_Name__c;
                item.Distributor_Stock__c = existingStockMap.get(key).Id;
            }
        }
        insert stockAdjustments;
    }
    
    
    
    @AuraEnabled
    public static String getInvoicePdfUrl(Id recordId) {
        return '/apex/GTInvoice?id=' + recordId;
    }
    
    /* ================= WRAPPERS ================= */
    public class StockAdjustmentBox{
        @AuraEnabled public List<Map<String, String>> adjustmentTypes = new List<Map<String, String>> ();
        @AuraEnabled public List<StockAdjustmentData> stockAdjustmentList;
        @AuraEnabled public List<Distributor_Stock__c> distributorStocks;
        @AuraEnabled public String distributorId;
    }
    public class StockAdjustmentData {
        @AuraEnabled public String recordId;
        @AuraEnabled public String stockId;
        @AuraEnabled public String productName;
        @AuraEnabled public String AdjustmentType;
        @AuraEnabled public String reason;
        @AuraEnabled public String stockDate;
        @AuraEnabled public decimal quantity; 
    }
    

    public class ReturnAccData {
        @AuraEnabled public List<AccData> customerData;
        @AuraEnabled public Decimal secondaryCustomerCount;
        @AuraEnabled public Decimal subStockiestCount;
        @AuraEnabled public Decimal totalCustomersCount;
    }
    
    public class AccData {
        @AuraEnabled public String recordId;
        @AuraEnabled public String secondaryCustomerId;
        @AuraEnabled public String secondaryCustomerName;
        @AuraEnabled public String secondaryCustomerOutletId;
        @AuraEnabled public String secondaryCustomerCode;
        @AuraEnabled public String primaryPhoneNumber;
        @AuraEnabled public String primaryCustomerName;
        @AuraEnabled public String subStockiestName;
        @AuraEnabled public String state;
        @AuraEnabled public String district;
        @AuraEnabled public String beatName;
        @AuraEnabled public Integer sNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String customerType;
        @AuraEnabled public String customerCategory;
        @AuraEnabled public decimal outStanding;
        @AuraEnabled public String email;
        @AuraEnabled public String aadhaarNo;
        @AuraEnabled public String gstNumber;
        @AuraEnabled public String contactPersonName;
        @AuraEnabled public String panNumber;
        @AuraEnabled public String paymentType;
        @AuraEnabled public Decimal creditLimit;
        @AuraEnabled public String paymentTerm;
        @AuraEnabled public String creditDescription;
        @AuraEnabled public String landmark;
        @AuraEnabled public String street;
        @AuraEnabled public String pincode;
        @AuraEnabled public String LastBilledDate;
    }
    
    
    
    //==================================
    //   Wrapper Classes
    //=================================
    public class secondaryReturnData {
        @AuraEnabled public List<Product__c> productsList;
        @AuraEnabled public List<Map<String, String>> resonForReturn = new List<Map<String, String>> ();
        @AuraEnabled public List<Map<String, String>> uom = new List<Map<String, String>> ();
    }
    public class GRN_Item_Wrapper {
        @AuraEnabled public Id invoiceItemId;
        @AuraEnabled public Id productId;
        @AuraEnabled public Decimal invoicedQty;
        @AuraEnabled public Decimal receivedQty;
    }
    public class DmsData{
        @AuraEnabled public String customerNameWithCode;
        @AuraEnabled public List<ordData> TotalOrderData;
        @AuraEnabled public List<InvData> TotalInvoiceData;
        @AuraEnabled public List<Map<String, String>> statusOptions;
        @AuraEnabled public List<PReturnData> TotalPrimaryReturnDataData; 
        @AuraEnabled public List<PaymentData> TotalPaymentData; 
        @AuraEnabled public List<GRNData> TotalGRNData; 
        @AuraEnabled public List<ClaimData> totalClaimData; 
        @AuraEnabled public List<DistributorStock> totalDistributorStockData; 
        @AuraEnabled public List<Product_Category__c> productCategories;
        @AuraEnabled public List<CreditNote> totalCreditNoteData;
        @AuraEnabled public List<DebitNote> totalDebitNoteData;
        @AuraEnabled public List<SecInvData> totalSecoundaryInvoiceData;
        @AuraEnabled public List<SReturnData> totalSecoundaryReturnData;
        @AuraEnabled public List<SecondaryReceipt> totalSecondaryReceiptData;
        @AuraEnabled public String orderItemId;//added newly can remove
        @AuraEnabled public String orgUrl;
        @AuraEnabled public List<Map<String, String>> reasonOptions;
    }

    @AuraEnabled
    public static DmsData allSecondaryReceiptData(Date frmDate, Date toDate, String status) {
        DmsData dt = new DmsData();
        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        System.debug('partnerUser: ' + partnerUser);
        if(partnerUser.size() > 0 && partnerUser[0].ContactId != null){
            List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            System.debug('contact: ' + contact);
            if(contact.size() > 0 && contact[0].AccountId != null){
                accountId = contact[0].AccountId;
            }
        }

        List<Secondary_Receipt__c> receiptList = [SELECT Id, Name, Payment_Date__c, Customer__c, Customer__r.Name, Payment_Mode__c, Reference_Number__c, Remarks__c, Total_Amount__c
                                                  FROM Secondary_Receipt__c
                                                  WHERE Payment_Date__c >= :frmDate AND Payment_Date__c <= :toDate
                                                 AND Distributor__c =:accountId ];
        List<SecondaryReceipt> receiptDataList = new List<SecondaryReceipt>();
        for (Secondary_Receipt__c i : receiptList) {
            String formattedDate = i.Payment_Date__c != null ? 
                DateTime.newInstance(i.Payment_Date__c.year(), i.Payment_Date__c.month(), i.Payment_Date__c.day()).format('dd/MM/yyyy') : '';
            SecondaryReceipt rec = new SecondaryReceipt();
            rec.receiptNo = i.Name;
            rec.receiptId = i.Id;
            rec.customerName = i.Customer__r != null ? i.Customer__r.Name : '';
            rec.customerId = i.Customer__c;
            rec.paymentDate = formattedDate;
            rec.paymentMode = i.Payment_Mode__c;
            rec.referenceNumber = i.Reference_Number__c;
            rec.remarks = i.Remarks__c;
            rec.totalAmount = i.Total_Amount__c;
            receiptDataList.add(rec);
        }
        dt.totalSecondaryReceiptData = receiptDataList;
        return dt;
    }

    @AuraEnabled
    public static void saveSecondaryReceipt(Secondary_Receipt__c receiptData, list<Secondary_Receipt_Item__c> recipetItems)
    {
    	insert receiptData;
        
        for(Secondary_Receipt_Item__c rec: recipetItems)
        {
            rec.Secondary_Receipt__c = receiptData.Id;
        }
        insert recipetItems;
    }
    public class OrdData {
        @AuraEnabled public String itemName;
        @AuraEnabled public String productId;
        @AuraEnabled public String orderItemName;
        @AuraEnabled public String orderItemId;
        @AuraEnabled public String orderNo;
        @AuraEnabled public String orderId;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal invoicedQuantity;
        @AuraEnabled public String orderDate;
        @AuraEnabled public Decimal amount; 
        @AuraEnabled public Decimal totalWeight;
        @AuraEnabled public Decimal baseAmount;
        @AuraEnabled public Decimal taxAmount;
        @AuraEnabled public Decimal tax;
        @AuraEnabled public String status;
        @AuraEnabled public String customerId;
        @AuraEnabled public String customerName;
        @AuraEnabled public List<Order_Item__c> items;//added newly can remove
    }
    public class InvData {
        @AuraEnabled public String name;
        @AuraEnabled public String InvDate;
        @AuraEnabled public String accId;
        @AuraEnabled public Decimal paidAmount;
        
        @AuraEnabled public String accName;
        @AuraEnabled public Decimal Amount;
        @AuraEnabled public String InvId;
        @AuraEnabled public String Status;
        @AuraEnabled public decimal tax;
        @AuraEnabled public boolean isDisabled;
        @AuraEnabled public boolean selected = false;
        @AuraEnabled public Decimal TotalQuantity;  // <-- Add this line
        @AuraEnabled public String invoiceNo;
        @AuraEnabled public String orderId;
        @AuraEnabled public String companyName;
        @AuraEnabled public String gstNumber;
        @AuraEnabled public Decimal nonTaxableAmount;
        @AuraEnabled public Decimal sgstAmount;
        @AuraEnabled public Decimal cgstAmount;
        @AuraEnabled public Decimal igstAmount;
    }
    public class PReturnData {
        @AuraEnabled public String productName;
        @AuraEnabled public String returnItemNo;
        @AuraEnabled public String productId;
        @AuraEnabled public String primaryReturnNo;
        @AuraEnabled public String primaryReturnId;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public String returnDate;
    }
    public class PaymentData {
        @AuraEnabled public String paymenetItemNo;
        @AuraEnabled public String paymenetItemId;
        @AuraEnabled public String paymenetNo;
        @AuraEnabled public String paymenetId;
        @AuraEnabled public String invoiceNo;
        @AuraEnabled public String invoiceId;
        @AuraEnabled public String paymentDate;
        @AuraEnabled public Decimal Amount;
    }
    public class GRNData {
        @AuraEnabled public String GRNItemName;
        @AuraEnabled public String GRNItemId;
        @AuraEnabled public String invoiceNo;
        @AuraEnabled public String invoiceId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productId;
        @AuraEnabled public String invoiceItemNo;
        @AuraEnabled public String invoiceItemId;
        @AuraEnabled public String GRNDate;
        @AuraEnabled public decimal invoicedQuantity;
        @AuraEnabled public decimal receivedQuantity;
        @AuraEnabled public String GRNName;
        @AuraEnabled public String GRNId;
    }
    public class ClaimData {
        @AuraEnabled public String claimName;
        @AuraEnabled public String claimId;
        @AuraEnabled public String customerName;
        @AuraEnabled public String customerId;
        @AuraEnabled public String description;
        @AuraEnabled public String claimDate;
        @AuraEnabled public String status;
        @AuraEnabled public decimal claimAmount;
    }
    public class DistributorStock{
        @AuraEnabled public String stockName;
        @AuraEnabled public String stockId;
        @AuraEnabled public String customerName;
        @AuraEnabled public String customerId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productId;
        @AuraEnabled public String stockUOM;
        @AuraEnabled public Date stockDate;
        
        @AuraEnabled public decimal GRNSaleableQuantity;
        @AuraEnabled public decimal GRNNonSaleableQuantity;
        @AuraEnabled public decimal SecondaryReturnSaleableQuantity;
        @AuraEnabled public decimal SecondaryReturnNonSaleableQuantity;
        @AuraEnabled public decimal primaryReturnQty;
        @AuraEnabled public decimal secoundryInvoiceQty;
        
        @AuraEnabled public decimal salebletoNonSaleableQty;
        @AuraEnabled public decimal nonSaleabletoSaleableQty;
        @AuraEnabled public decimal writtenOffQty;
        
        @AuraEnabled public decimal availableSaleableQuantity;
        @AuraEnabled public decimal availableNonSaleableQuantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public String productGroup;
        @AuraEnabled public String productSubGroup;
    }
    public class CreditNote{
        @AuraEnabled public String creditNoteNo;
        @AuraEnabled public String creditNoteId;
        @AuraEnabled public String customerName;
        @AuraEnabled public String customerId;
        @AuraEnabled public String claimNo;
        @AuraEnabled public String claimId;
        @AuraEnabled public String primaryReturnNo;
        @AuraEnabled public String primaryReturnId;
        @AuraEnabled public String creditDate;
        @AuraEnabled public String status;
        @AuraEnabled public String reason;
        @AuraEnabled public decimal creditAmount;
    }
    public class DebitNote{
        @AuraEnabled public String debitNoteNo;
        @AuraEnabled public String debitNoteId;
        @AuraEnabled public String customerName;
        @AuraEnabled public String customerId;
        @AuraEnabled public String noteDate;
        @AuraEnabled public String status;
        @AuraEnabled public String reason;
        @AuraEnabled public decimal amount;
        @AuraEnabled public String description;
    }
    public class SecInvData {
        @AuraEnabled public String name;
        @AuraEnabled public String InvDate;
        @AuraEnabled public Decimal paidAmount;
        @AuraEnabled public String accId;
        @AuraEnabled public String accName;
        @AuraEnabled public Decimal Amount;
        @AuraEnabled public String InvId;
        @AuraEnabled public String Status;
        @AuraEnabled public decimal tax;
        @AuraEnabled public decimal pendingAmount;
        
        @AuraEnabled public decimal Quantity;
        @AuraEnabled public boolean selected = false;
        @AuraEnabled public String beatName;
        @AuraEnabled public Decimal nonTaxableAmount;
        @AuraEnabled public Decimal sgstAmount;
        @AuraEnabled public Decimal cgstAmount;
    }
    public class SReturnData {
        @AuraEnabled public String productName;
        @AuraEnabled public String returnItemNo;
        @AuraEnabled public String productId;
        @AuraEnabled public String secoundaryReturnNo;
        @AuraEnabled public String secoundaryReturnId;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public String returnDate;
        // Added customer and amount fields
        @AuraEnabled public String secondaryCustomer;  // Secondary customer name
        @AuraEnabled public Decimal totalAmount;  // Total amount of the secondary return
    }
    public class GraphData {
        @AuraEnabled public List<Map<String, String>> formattedUsersOrder { get; set; }
        @AuraEnabled public List<Map<String, String>> formattedUsersSales { get; set; }
        @AuraEnabled public List<kpi_graph_target> graphlist;
    }
    public class kpi_graph_target {
        @AuraEnabled
        public decimal target;
        @AuraEnabled
        public decimal actual;
        @AuraEnabled
        public String xAxis;
        
    }
    public class ProductWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal price;
        @AuraEnabled public String category;
        
        public ProductWrapper(Product__c p) {
            id = p.Id;
            name = p.Name;
            price = p.List_Price__c;
            category = p.Product_Category1__r.Name;
        }
    }
    public class OrderItemWrapper {
        @AuraEnabled public String productId;
        @AuraEnabled public Integer quantity;
        
    }

    @AuraEnabled
    public static List<Product__c> getProductGalleryData() {
        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        System.debug('partnerUser: ' + partnerUser);
        if(partnerUser.size() > 0 && partnerUser[0].ContactId != null){
            List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            System.debug('contact: ' + contact);
            if(contact.size() > 0 && contact[0].AccountId != null){
                accountId = contact[0].AccountId;
            }
        }
        System.debug('accountId: ' + accountId);

        if (accountId == null) {
            System.debug('No accountId found for community user');
            return new List<Product__c>();
        }

        // Find sales channels mapped to this distributor account
        Set<String> channelSet = new Set<String>();
        List<Product_Mapping__c> mappings = [
            SELECT Chanel__c 
            FROM Product_Mapping__c 
            WHERE Customer__c = :accountId
        ];
        for (Product_Mapping__c pm : mappings) {
            if (pm.Chanel__c != null) {
                channelSet.add(pm.Chanel__c);
            }
        }
        System.debug('channelSet from mappings: ' + channelSet);

        if (channelSet.isEmpty()) {
            System.debug('No sales channels found for account: ' + accountId);
            return new List<Product__c>();
        }

        // Get active SKU IDs for those sales channels
        Set<Id> skuIds = new Set<Id>();
        List<Sales_Channel_To_SKU__c> channels = [
            SELECT SKU__c 
            FROM Sales_Channel_To_SKU__c 
            WHERE Sales_Channel__c IN :channelSet 
            AND SKU__r.Is_Active__c = true
        ];
        for (Sales_Channel_To_SKU__c ch : channels) {
            skuIds.add(ch.SKU__c);
        }
        System.debug('skuIds count: ' + skuIds.size());

        if (skuIds.isEmpty()) {
            return new List<Product__c>();
        }

        // Query products with price books for this account
        List<Product__c> products = [
            SELECT Id, Name, Channel__c, Category__c, Product_Category_Name__c, Product_Category1__c,
            Product_Category1__r.Name, List_Price__c, MRP__c, Tax_Percent__c,
            Tax_Class__c, CreatedDate, UOM__c, Selling_Category__c, Product_Image_Url__c,SKU_Code__c,
            Product_Group__c, Product_Sub_Group__c, Alternate_UOM__c, Uom_Conversion__c,
            (SELECT Id, Unit_Price__c, MRP__c, UOM__c, Customer__c,
             Customer_Type__c, Region__c, Secondary_Customer_Category__c
             FROM Price_Books__r WHERE Customer__c = :accountId)
            FROM Product__c
            WHERE Is_Active__c = true
            AND Id IN :skuIds
            ORDER BY Channel__c ASC
        ];
        System.debug('products count: ' + products.size());
        return products;
    }

    /**-----Secondary Customer Ledger-----**/
    
    // Wrapper class for opening balance
    public class OpeningBalanceResult {
        @AuraEnabled public Decimal balance;
    } 
    
    // Wrapper class for ledger entry
    public class LedgerEntry implements Comparable {
        @AuraEnabled public String  transactionType;
        @AuraEnabled public Date    transactionDate;
        @AuraEnabled public String  transactionNo;
        @AuraEnabled public String  description;
        @AuraEnabled public String  referenceNo;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String  status;
        
        public Integer compareTo(Object compareTo) {
            Date otherDate = ((LedgerEntry) compareTo).transactionDate;
            if (transactionDate == otherDate) return 0;
            if (transactionDate == null || transactionDate < otherDate) return -1;
            return 1;
        }
    }
    
    // Wrapper class for secondary ledger result
    public class SecondaryLedgerResult {
        @AuraEnabled public List<LedgerEntry> ledgerData;
        @AuraEnabled public List<Map<String, String>> statusOptions;
    }
    
    // Get opening balance for a customer up to a specific date
    @AuraEnabled
    public static OpeningBalanceResult getOpeningBalance(String customerId, String asOfDate) {
        OpeningBalanceResult result = new OpeningBalanceResult();
        result.balance = 0;
        
        if (String.isBlank(asOfDate)) {
            return result;
        }
        
        Date cutoffDate = Date.valueOf(asOfDate);
        Decimal totalDebits = 0;
        Decimal totalCredits = 0;
        
        try {
            // Sum all Secondary Invoices before cutoff date (DEBIT - increases balance)
            List<AggregateResult> invoiceAgg = [
                SELECT SUM(Grand_Total__c) totalAmount
                FROM Secondary_Invoice__c
                WHERE Customer__c = :customerId
                AND Invoice_Date__c < :cutoffDate
            ];
            if (!invoiceAgg.isEmpty() && invoiceAgg[0].get('totalAmount') != null) {
                totalDebits += (Decimal) invoiceAgg[0].get('totalAmount');
            }
            
            // Sum all Secondary Debit Notes before cutoff date (DEBIT - increases balance)
            List<AggregateResult> debitNoteAgg = [
                SELECT SUM(Amount__c) totalAmount
                FROM Secondary_Debit_Note__c
                WHERE Customer__c = :customerId
                AND Note_Date__c < :cutoffDate
            ];
            if (!debitNoteAgg.isEmpty() && debitNoteAgg[0].get('totalAmount') != null) {
                totalDebits += (Decimal) debitNoteAgg[0].get('totalAmount');
            }
            
            // Sum all Secondary Credit Notes before cutoff date (CREDIT - decreases balance)
            List<AggregateResult> creditNoteAgg = [
                SELECT SUM(Amount__c) totalAmount
                FROM Secondary_Credit_Note__c
                WHERE Customer__c = :customerId
                AND Credit_Date__c < :cutoffDate
            ];
            if (!creditNoteAgg.isEmpty() && creditNoteAgg[0].get('totalAmount') != null) {
                totalCredits += (Decimal) creditNoteAgg[0].get('totalAmount');
            }
            
            // Sum all Secondary Returns before cutoff date (CREDIT - decreases balance)
            List<AggregateResult> returnAgg = [
                SELECT SUM(Total_Amount__c) totalAmount
                FROM Return__c
                WHERE Customer__c = :customerId
                AND Return_Date__c < :cutoffDate
                AND Customer_Type__c = 'Secondary Customer'
            ];
            if (!returnAgg.isEmpty() && returnAgg[0].get('totalAmount') != null) {
                totalCredits += (Decimal) returnAgg[0].get('totalAmount');
            }
            
            // Sum all Secondary Receipts before cutoff date (CREDIT - decreases balance)
            List<AggregateResult> receiptAgg = [
                SELECT SUM(Total_Amount__c) totalAmount
                FROM Secondary_Receipt__c
                WHERE Customer__c = :customerId
                AND Payment_Date__c < :cutoffDate
            ];
            if (!receiptAgg.isEmpty() && receiptAgg[0].get('totalAmount') != null) {
                totalCredits += (Decimal) receiptAgg[0].get('totalAmount');
            }
            
            // Calculate opening balance: Debits - Credits
            result.balance = totalDebits - totalCredits;
            
        } catch (Exception e) {
            System.debug('Error calculating opening balance: ' + e.getMessage());
        }
        
        return result;
    }
    
    // Get secondary ledger transactions within date range for a customer
    @AuraEnabled
    public static SecondaryLedgerResult getSecondaryLedger(Id customerId, String fromDate, String toDate, String status) {
        SecondaryLedgerResult result = new SecondaryLedgerResult();
        result.ledgerData = new List<LedgerEntry>();
        result.statusOptions = new List<Map<String, String>>();
        
        if (String.isBlank(fromDate) || String.isBlank(toDate)) {
            return result;
        }
        
        Date startDate = Date.valueOf(fromDate);
        Date endDate = Date.valueOf(toDate);
        
        try {
            // Fetch Secondary Invoices (DEBIT)
            List<Secondary_Invoice__c> invoices = [
                SELECT Id, Name, Invoice_Date__c, Grand_Total__c, Status__c
                FROM Secondary_Invoice__c
                WHERE Customer__c = :customerId
                AND Invoice_Date__c >= :startDate
                AND Invoice_Date__c <= :endDate
                ORDER BY Invoice_Date__c ASC
            ];
            
            for (Secondary_Invoice__c inv : invoices) {
                LedgerEntry entry = new LedgerEntry();
                entry.transactionType = 'Invoice';
                entry.transactionDate = inv.Invoice_Date__c;
                entry.transactionNo   = inv.Name;           // FIX: doc number
                entry.description     = 'Secondary Invoice';
                entry.referenceNo     = inv.Name;           // FIX: was inv.Id
                entry.amount          = inv.Grand_Total__c;
                entry.status          = inv.Status__c;
                result.ledgerData.add(entry);
            }
            
            // Fetch Secondary Returns (CREDIT)
            List<Return__c> returns = [
                SELECT Id, Name, Return_Date__c, Total_Amount__c
                FROM Return__c
                WHERE Customer__c = :customerId
                AND Return_Date__c >= :startDate
                AND Return_Date__c <= :endDate
                AND Customer_Type__c = 'Secondary Customer'
                ORDER BY Return_Date__c ASC
            ];
            
            for (Return__c ret : returns) {
                LedgerEntry entry = new LedgerEntry();
                entry.transactionType = 'Return';
                entry.transactionDate = ret.Return_Date__c;
                entry.transactionNo   = ret.Name;           // FIX: doc number
                entry.description     = 'Secondary Return';
                entry.referenceNo     = ret.Name;           // FIX: was ret.Id
                entry.amount          = ret.Total_Amount__c;
                entry.status          = 'Completed';
                result.ledgerData.add(entry);
            }
            
            // Fetch Secondary Credit Notes (CREDIT)
            List<Secondary_Credit_Note__c> creditNotes = [
                SELECT Id, Name, Credit_Date__c, Amount__c, Status__c
                FROM Secondary_Credit_Note__c
                WHERE Customer__c = :customerId
                AND Credit_Date__c >= :startDate
                AND Credit_Date__c <= :endDate
                ORDER BY Credit_Date__c ASC
            ];
            
            for (Secondary_Credit_Note__c creditNote : creditNotes) {
                LedgerEntry entry = new LedgerEntry();
                entry.transactionType = 'Credit Note';
                entry.transactionDate = creditNote.Credit_Date__c;
                entry.transactionNo   = creditNote.Name;   // FIX: doc number
                entry.description     = 'Secondary Credit Note';
                entry.referenceNo     = creditNote.Name;   // FIX: was creditNote.Id
                entry.amount          = creditNote.Amount__c;
                entry.status          = creditNote.Status__c;
                result.ledgerData.add(entry);
            }
            
            // Fetch Secondary Debit Notes (DEBIT)
            List<Secondary_Debit_Note__c> debitNotes = [
                SELECT Id, Name, Note_Date__c, Amount__c, Status__c
                FROM Secondary_Debit_Note__c
                WHERE Customer__c = :customerId
                AND Note_Date__c >= :startDate
                AND Note_Date__c <= :endDate
                ORDER BY Note_Date__c ASC
            ];
            
            for (Secondary_Debit_Note__c debitNote : debitNotes) {
                LedgerEntry entry = new LedgerEntry();
                entry.transactionType = 'Debit Note';
                entry.transactionDate = debitNote.Note_Date__c;
                entry.transactionNo   = debitNote.Name;   // FIX: doc number
                entry.description     = 'Secondary Debit Note';
                entry.referenceNo     = debitNote.Name;   // FIX: was debitNote.Id
                entry.amount          = debitNote.Amount__c;
                entry.status          = debitNote.Status__c;
                result.ledgerData.add(entry);
            }
            
            // Fetch Secondary Receipts (CREDIT)
            List<Secondary_Receipt__c> receipts = [
                SELECT Id, Name, Payment_Date__c, Total_Amount__c, Payment_Mode__c
                FROM Secondary_Receipt__c
                WHERE Customer__c = :customerId
                AND Payment_Date__c >= :startDate
                AND Payment_Date__c <= :endDate
                ORDER BY Payment_Date__c ASC
            ];
            
            for (Secondary_Receipt__c rec : receipts) {
                LedgerEntry entry = new LedgerEntry();
                entry.transactionType = 'Receipt';
                entry.transactionDate = rec.Payment_Date__c;
                entry.transactionNo   = rec.Name;            // FIX: doc number
                entry.description     = 'Secondary Receipt';
                entry.referenceNo     = rec.Name;            // FIX: was rec.Id
                entry.amount          = rec.Total_Amount__c;
                entry.status          = rec.Payment_Mode__c;
                result.ledgerData.add(entry);
            }
            
            // Sort all ledger data by transaction date
            result.ledgerData.sort();
            
            // Build status options
            Map<String, String> allOption = new Map<String, String>();
            allOption.put('label', 'All');
            allOption.put('value', '');
            result.statusOptions.add(allOption);
            
            Map<String, String> pendingOption = new Map<String, String>();
            pendingOption.put('label', 'Pending');
            pendingOption.put('value', 'Pending');
            result.statusOptions.add(pendingOption);
            
            Map<String, String> paidOption = new Map<String, String>();
            paidOption.put('label', 'Paid');
            paidOption.put('value', 'Paid');
            result.statusOptions.add(paidOption);
            
            Map<String, String> partialOption = new Map<String, String>();
            partialOption.put('label', 'Partial');
            partialOption.put('value', 'Partial');
            result.statusOptions.add(partialOption);
            
        } catch (Exception e) {
            System.debug('Error fetching secondary ledger: ' + e.getMessage());
        }
        
        return result;
    }

    // ========== Debit Note & Advance Methods for Receipt Creation ==========

    @AuraEnabled(cacheable=false)
    public static List<DebitNoteData> getPendingDebitNotesByCustomer(Id customerId) {
        List<DebitNoteData> result = new List<DebitNoteData>();
        if (customerId == null) return result;
        List<Secondary_Debit_Note__c> notes = [
            SELECT Id, Name, Note_Date__c, Amount__c, Paid_Amount__c, Pending_Amount__c,
                   Customer__c, Customer__r.Name, Status__c, Reason__c
            FROM Secondary_Debit_Note__c
            WHERE Customer__c = :customerId AND Pending_Amount__c > 0
            ORDER BY Note_Date__c ASC
        ];
        for (Secondary_Debit_Note__c dn : notes) {
            DebitNoteData data = new DebitNoteData();
            data.name = dn.Name;
            data.debitNoteId = dn.Id;
            data.noteDate = dn.Note_Date__c != null ? DateTime.newInstance(dn.Note_Date__c.year(), dn.Note_Date__c.month(), dn.Note_Date__c.day()).format('dd/MM/yyyy') : '';
            data.amount = dn.Amount__c;
            data.paidAmount = dn.Paid_Amount__c;
            data.pendingAmount = dn.Pending_Amount__c;
            data.reason = dn.Reason__c;
            result.add(data);
        }
        return result;
    }


    @AuraEnabled
    public static void saveSecondaryReceiptWithDetails(
        Secondary_Receipt__c receiptData,
        List<Secondary_Receipt_Item__c> receiptItems,
        List<Secondary_Receipt_Debit_Item__c> debitItems
    ) {
        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        System.debug('partnerUser: ' + partnerUser);
        if(partnerUser.size() > 0 && partnerUser[0].ContactId != null){
            List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            System.debug('contact: ' + contact);
            if(contact.size() > 0 && contact[0].AccountId != null){
                accountId = contact[0].AccountId;
            }
        }
        receiptData.Distributor__c = accountId;
        insert receiptData;

        if (receiptItems != null && !receiptItems.isEmpty()) {
            for (Secondary_Receipt_Item__c rec : receiptItems) {
                rec.Secondary_Receipt__c = receiptData.Id;
            }
            insert receiptItems;
        }

        if (debitItems != null && !debitItems.isEmpty()) {
            for (Secondary_Receipt_Debit_Item__c rec : debitItems) {
                rec.Secondary_Receipt__c = receiptData.Id;
            }
            insert debitItems;
        }

    }

    // Wrapper classes for Debit Note and Advance data
    public class DebitNoteData {
        @AuraEnabled public String name;
        @AuraEnabled public String debitNoteId;
        @AuraEnabled public String noteDate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Decimal paidAmount;
        @AuraEnabled public Decimal pendingAmount;
        @AuraEnabled public String reason;
    }

    public class AdvanceData {
        @AuraEnabled public String name;
        @AuraEnabled public String advanceId;
        @AuraEnabled public String advanceDate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Decimal usedAmount;
        @AuraEnabled public Decimal availableAmount;
        @AuraEnabled public String modeOfPayment;
    }

    // Aging Report wrapper classes
    public class AgingBucket {
        @AuraEnabled public String label;
        @AuraEnabled public Decimal invoiceAmount;
        @AuraEnabled public Decimal debitNoteAmount;
        @AuraEnabled public Decimal totalAmount;
    }

    public class AgingReportData {
        @AuraEnabled public List<AgingBucket> buckets;
        @AuraEnabled public Decimal totalInvoicePending;
        @AuraEnabled public Decimal totalDebitNotePending;
        @AuraEnabled public Decimal totalAgingAmount;
    }

    @AuraEnabled
    public static AgingReportData getSecondaryCustomerAgingReport(String customerId) {
        AgingReportData report = new AgingReportData();
        report.totalInvoicePending = 0;
        report.totalDebitNotePending = 0;
        report.totalAgingAmount = 0;

        // Initialize buckets: 0-15, 16-30, 31-45, 45+
        List<AgingBucket> buckets = new List<AgingBucket>();
        String[] labels = new String[]{ '0-15', '16-30', '31-45', '45+' };
        for (String lbl : labels) {
            AgingBucket b = new AgingBucket();
            b.label = lbl;
            b.invoiceAmount = 0;
            b.debitNoteAmount = 0;
            b.totalAmount = 0;
            buckets.add(b);
        }

        Date today = Date.today();

        // Query pending invoices
        List<Secondary_Invoice__c> invoices = [
            SELECT Id, Invoice_Date__c, Pending_Amount__c
            FROM Secondary_Invoice__c
            WHERE Customer__c = :customerId AND Pending_Amount__c > 0
        ];

        for (Secondary_Invoice__c inv : invoices) {
            Integer daysDiff = inv.Invoice_Date__c.daysBetween(today);
            Integer bucketIndex;
            if (daysDiff <= 15) {
                bucketIndex = 0;
            } else if (daysDiff <= 30) {
                bucketIndex = 1;
            } else if (daysDiff <= 45) {
                bucketIndex = 2;
            } else {
                bucketIndex = 3;
            }
            buckets[bucketIndex].invoiceAmount += inv.Pending_Amount__c;
            report.totalInvoicePending += inv.Pending_Amount__c;
        }

        // Query pending debit notes
        List<Secondary_Debit_Note__c> debitNotes = [
            SELECT Id, Note_Date__c, Pending_Amount__c
            FROM Secondary_Debit_Note__c
            WHERE Customer__c = :customerId AND Pending_Amount__c > 0
        ];

        for (Secondary_Debit_Note__c dn : debitNotes) {
            Integer daysDiff = dn.Note_Date__c.daysBetween(today);
            Integer bucketIndex;
            if (daysDiff <= 15) {
                bucketIndex = 0;
            } else if (daysDiff <= 30) {
                bucketIndex = 1;
            } else if (daysDiff <= 45) {
                bucketIndex = 2;
            } else {
                bucketIndex = 3;
            }
            buckets[bucketIndex].debitNoteAmount += dn.Pending_Amount__c;
            report.totalDebitNotePending += dn.Pending_Amount__c;
        }

        // Calculate totals per bucket
        for (AgingBucket b : buckets) {
            b.totalAmount = b.invoiceAmount + b.debitNoteAmount;
        }

        report.buckets = buckets;
        report.totalAgingAmount = report.totalInvoicePending + report.totalDebitNotePending;

        return report;
    }

    // ==================== Claim Reports ====================

    public class ClaimReportItem {
        @AuraEnabled public String category;
        @AuraEnabled public String customerName;
        @AuraEnabled public String productName;
        @AuraEnabled public Decimal beforePrice;
        @AuraEnabled public Decimal afterPrice;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal claimAmount;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public Decimal beforeCategorySlabPrice;
        @AuraEnabled public Decimal afterCategorySlabPrice;
        @AuraEnabled public Decimal categorySlabClaimAmount;
        @AuraEnabled public Decimal beforeSchemePrice;
        @AuraEnabled public Decimal afterSchemePrice;
        @AuraEnabled public Decimal schemeClaimAmount;
        @AuraEnabled public Decimal totalClaimAmount;
        @AuraEnabled public String reason;
        @AuraEnabled public String invoiceName;
    }

    @AuraEnabled
    public static List<ClaimReportItem> getCategorySlabClaimCategorySummary(String fromDate, String toDate) {
        Id accountId;
        User u = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (u.ContactId != null) {
            accountId = [SELECT AccountId FROM Contact WHERE Id = :u.ContactId LIMIT 1].AccountId;
        }

        Date frmDate = Date.valueOf(fromDate);
        Date toDateVal = Date.valueOf(toDate);

        List<Secondary_Invoice_Item__c> items = [
            SELECT Product__r.Name, Quantity__c, Before_Category_Slab_Unit_Price__c,
                   After_Category_Slab_Unit_Price__c, Category_Slab_Claim_Amount__c,
                   Total_Amount__c, Secondary_Invoice__r.Secondary_Customer_Category__c
            FROM Secondary_Invoice_Item__c
            WHERE Secondary_Invoice__r.Store__c = :accountId
            AND Secondary_Invoice__r.Invoice_Date__c >= :frmDate
            AND Secondary_Invoice__r.Invoice_Date__c <= :toDateVal
            AND Category_Slab_Claim_Amount__c > 0
            AND Secondary_Invoice__r.Secondary_Customer_Category__c != null
            ORDER BY Secondary_Invoice__r.Secondary_Customer_Category__c, Product__r.Name
        ];

        List<ClaimReportItem> result = new List<ClaimReportItem>();
        for (Secondary_Invoice_Item__c item : items) {
            ClaimReportItem r = new ClaimReportItem();
            r.category = item.Secondary_Invoice__r.Secondary_Customer_Category__c;
            r.productName = item.Product__r.Name;
            r.beforePrice = item.Before_Category_Slab_Unit_Price__c;
            r.afterPrice = item.After_Category_Slab_Unit_Price__c;
            r.quantity = item.Quantity__c;
            r.claimAmount = item.Category_Slab_Claim_Amount__c;
            r.totalAmount = item.Total_Amount__c;
            result.add(r);
        }
        return result;
    }

    @AuraEnabled
    public static List<ClaimReportItem> getCategorySlabClaimCategoryCustomerDetail(String fromDate, String toDate) {
        Id accountId;
        User u = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (u.ContactId != null) {
            accountId = [SELECT AccountId FROM Contact WHERE Id = :u.ContactId LIMIT 1].AccountId;
        }

        Date frmDate = Date.valueOf(fromDate);
        Date toDateVal = Date.valueOf(toDate);

        List<Secondary_Invoice_Item__c> items = [
            SELECT Product__r.Name, Quantity__c, Before_Category_Slab_Unit_Price__c,
                   After_Category_Slab_Unit_Price__c, Category_Slab_Claim_Amount__c,
                   Total_Amount__c, Secondary_Invoice__r.Secondary_Customer_Category__c,
                   Secondary_Invoice__r.Customer__r.Name
            FROM Secondary_Invoice_Item__c
            WHERE Secondary_Invoice__r.Store__c = :accountId
            AND Secondary_Invoice__r.Invoice_Date__c >= :frmDate
            AND Secondary_Invoice__r.Invoice_Date__c <= :toDateVal
            AND Category_Slab_Claim_Amount__c > 0
            AND Secondary_Invoice__r.Secondary_Customer_Category__c != null
            ORDER BY Secondary_Invoice__r.Secondary_Customer_Category__c, Secondary_Invoice__r.Customer__r.Name, Product__r.Name
        ];

        List<ClaimReportItem> result = new List<ClaimReportItem>();
        for (Secondary_Invoice_Item__c item : items) {
            ClaimReportItem r = new ClaimReportItem();
            r.category = item.Secondary_Invoice__r.Secondary_Customer_Category__c;
            r.customerName = item.Secondary_Invoice__r.Customer__r.Name;
            r.productName = item.Product__r.Name;
            r.beforePrice = item.Before_Category_Slab_Unit_Price__c;
            r.afterPrice = item.After_Category_Slab_Unit_Price__c;
            r.quantity = item.Quantity__c;
            r.claimAmount = item.Category_Slab_Claim_Amount__c;
            r.totalAmount = item.Total_Amount__c;
            result.add(r);
        }
        return result;
    }

    @AuraEnabled
    public static List<ClaimReportItem> getSchemeClaimCustomerSummary(String fromDate, String toDate) {
        Id accountId;
        User u = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (u.ContactId != null) {
            accountId = [SELECT AccountId FROM Contact WHERE Id = :u.ContactId LIMIT 1].AccountId;
        }

        Date frmDate = Date.valueOf(fromDate);
        Date toDateVal = Date.valueOf(toDate);

        List<Secondary_Invoice_Item__c> items = [
            SELECT Product__r.Name, Quantity__c, Before_Scheme_Unit_Price__c,
                   After_Scheme_Unit_Price__c, Scheme_Claim_Amount__c,
                   Total_Amount__c, Secondary_Invoice__r.Customer__r.Name
            FROM Secondary_Invoice_Item__c
            WHERE Secondary_Invoice__r.Store__c = :accountId
            AND Secondary_Invoice__r.Invoice_Date__c >= :frmDate
            AND Secondary_Invoice__r.Invoice_Date__c <= :toDateVal
            AND Scheme_Claim_Amount__c > 0
            ORDER BY Secondary_Invoice__r.Customer__r.Name, Product__r.Name
        ];

        List<ClaimReportItem> result = new List<ClaimReportItem>();
        for (Secondary_Invoice_Item__c item : items) {
            ClaimReportItem r = new ClaimReportItem();
            r.customerName = item.Secondary_Invoice__r.Customer__r.Name;
            r.productName = item.Product__r.Name;
            r.beforePrice = item.Before_Scheme_Unit_Price__c;
            r.afterPrice = item.After_Scheme_Unit_Price__c;
            r.quantity = item.Quantity__c;
            r.claimAmount = item.Scheme_Claim_Amount__c;
            r.totalAmount = item.Total_Amount__c;
            result.add(r);
        }
        return result;
    }

    @AuraEnabled
    public static List<ClaimReportItem> getCombinedClaimCategoryCustomerSummary(String fromDate, String toDate) {
        Id accountId;
        User u = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (u.ContactId != null) {
            accountId = [SELECT AccountId FROM Contact WHERE Id = :u.ContactId LIMIT 1].AccountId;
        }

        Date frmDate = Date.valueOf(fromDate);
        Date toDateVal = Date.valueOf(toDate);

        List<Secondary_Invoice_Item__c> items = [
            SELECT Product__r.Name, Quantity__c,
                   Before_Category_Slab_Unit_Price__c, After_Category_Slab_Unit_Price__c, Category_Slab_Claim_Amount__c,
                   Before_Scheme_Unit_Price__c, After_Scheme_Unit_Price__c, Scheme_Claim_Amount__c,
                   Total_Claim_Amount__c, Total_Amount__c,
                   Secondary_Invoice__r.Secondary_Customer_Category__c, Secondary_Invoice__r.Customer__r.Name
            FROM Secondary_Invoice_Item__c
            WHERE Secondary_Invoice__r.Store__c = :accountId
            AND Secondary_Invoice__r.Invoice_Date__c >= :frmDate
            AND Secondary_Invoice__r.Invoice_Date__c <= :toDateVal
            AND Category_Slab_Claim_Amount__c > 0
            AND Scheme_Claim_Amount__c > 0
            AND Secondary_Invoice__r.Secondary_Customer_Category__c != null
            ORDER BY Secondary_Invoice__r.Secondary_Customer_Category__c, Secondary_Invoice__r.Customer__r.Name, Product__r.Name
        ];

        List<ClaimReportItem> result = new List<ClaimReportItem>();
        for (Secondary_Invoice_Item__c item : items) {
            ClaimReportItem r = new ClaimReportItem();
            r.category = item.Secondary_Invoice__r.Secondary_Customer_Category__c;
            r.customerName = item.Secondary_Invoice__r.Customer__r.Name;
            r.productName = item.Product__r.Name;
            r.quantity = item.Quantity__c;
            r.beforeCategorySlabPrice = item.Before_Category_Slab_Unit_Price__c;
            r.afterCategorySlabPrice = item.After_Category_Slab_Unit_Price__c;
            r.categorySlabClaimAmount = item.Category_Slab_Claim_Amount__c;
            r.beforeSchemePrice = item.Before_Scheme_Unit_Price__c;
            r.afterSchemePrice = item.After_Scheme_Unit_Price__c;
            r.schemeClaimAmount = item.Scheme_Claim_Amount__c;
            r.totalClaimAmount = item.Total_Claim_Amount__c;
            r.totalAmount = item.Total_Amount__c;
            result.add(r);
        }
        return result;
    }

    @AuraEnabled
    public static List<ClaimReportItem> getTotalClaimCategoryCustomerSummary(String fromDate, String toDate) {
        Id accountId;
        User u = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (u.ContactId != null) {
            accountId = [SELECT AccountId FROM Contact WHERE Id = :u.ContactId LIMIT 1].AccountId;
        }

        Date frmDate = Date.valueOf(fromDate);
        Date toDateVal = Date.valueOf(toDate);

        List<Secondary_Invoice_Item__c> items = [
            SELECT Product__r.Name, Quantity__c,
                   Before_Category_Slab_Unit_Price__c, After_Category_Slab_Unit_Price__c, Category_Slab_Claim_Amount__c,
                   Before_Scheme_Unit_Price__c, After_Scheme_Unit_Price__c, Scheme_Claim_Amount__c,
                   Total_Claim_Amount__c, Total_Amount__c,
                   Secondary_Invoice__r.Secondary_Customer_Category__c, Secondary_Invoice__r.Customer__r.Name
            FROM Secondary_Invoice_Item__c
            WHERE Secondary_Invoice__r.Store__c = :accountId
            AND Secondary_Invoice__r.Invoice_Date__c >= :frmDate
            AND Secondary_Invoice__r.Invoice_Date__c <= :toDateVal
            AND (Category_Slab_Claim_Amount__c > 0 OR Scheme_Claim_Amount__c > 0)
            AND Secondary_Invoice__r.Secondary_Customer_Category__c != null
            ORDER BY Secondary_Invoice__r.Secondary_Customer_Category__c, Secondary_Invoice__r.Customer__r.Name, Product__r.Name
        ];

        List<ClaimReportItem> result = new List<ClaimReportItem>();
        for (Secondary_Invoice_Item__c item : items) {
            ClaimReportItem r = new ClaimReportItem();
            r.category = item.Secondary_Invoice__r.Secondary_Customer_Category__c;
            r.customerName = item.Secondary_Invoice__r.Customer__r.Name;
            r.productName = item.Product__r.Name;
            r.quantity = item.Quantity__c;
            r.beforeCategorySlabPrice = item.Before_Category_Slab_Unit_Price__c;
            r.afterCategorySlabPrice = item.After_Category_Slab_Unit_Price__c;
            r.categorySlabClaimAmount = item.Category_Slab_Claim_Amount__c;
            r.beforeSchemePrice = item.Before_Scheme_Unit_Price__c;
            r.afterSchemePrice = item.After_Scheme_Unit_Price__c;
            r.schemeClaimAmount = item.Scheme_Claim_Amount__c;
            r.totalClaimAmount = item.Total_Claim_Amount__c;
            r.totalAmount = item.Total_Amount__c;
            result.add(r);
        }
        return result;
    }

    // ==================== Outstanding Report ====================

    public class OutstandingReportItem implements Comparable {
        @AuraEnabled public String primaryCustomerSapCode;
        @AuraEnabled public String primaryCustomerName;
        @AuraEnabled public String secondaryCustomerCode;
        @AuraEnabled public String secondaryCustomerName;
        @AuraEnabled public String executiveCode;
        @AuraEnabled public String executiveName;
        @AuraEnabled public String beatName;
        @AuraEnabled public String documentNumber;
        @AuraEnabled public Date documentDate;
        @AuraEnabled public Decimal documentAmount;
        @AuraEnabled public Decimal collectedAmount;
        @AuraEnabled public Decimal outstandingAmount;
        @AuraEnabled public String documentType;
        @AuraEnabled public Decimal aging;
        
        public Integer compareTo(Object compareTo) {
            Date otherDate = ((OutstandingReportItem) compareTo).documentDate;
            if (documentDate == otherDate) return 0;
            if (documentDate == null || documentDate < otherDate) return -1;
            return 1;
        }
    }

    @AuraEnabled
    public static List<OutstandingReportItem> getOutstandingReport(String customerId) {
        List<OutstandingReportItem> result = new List<OutstandingReportItem>();

        // Get the primary customer (Store/Distributor) account ID for this secondary customer
        Id primaryCustomerId;
        User u = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (u.ContactId != null) {
            primaryCustomerId = [SELECT AccountId FROM Contact WHERE Id = :u.ContactId LIMIT 1].AccountId;
        }


        // Query Executive from Product_Mapping__c
        String execCode = '';
        String execName = '';
        if (primaryCustomerId != null) {
            List<Product_Mapping__c> pmList = [
                SELECT Exectuive__r.Employee_Code__c, Exectuive__r.Name,Executive_Name1__c
                FROM Product_Mapping__c
                WHERE Customer__c = :customerId
                AND Primary_Customer__c = :primaryCustomerId
                AND Exectuive__c != null  Order by Exectuive__r.Heirarchial_Number__c ASC
                LIMIT 1
            ];
            if (!pmList.isEmpty()) {
                execCode = pmList[0].Exectuive__r.Employee_Code__c;
                execName = pmList[0].Executive_Name1__c;
            }
        }

        // Query Beat Name from Junction_Beat__c
        String beatNameVal = '';
        if (primaryCustomerId != null) {
            List<Junction_Beat__c> jbList = [
                SELECT Child_beat__r.Name
                FROM Junction_Beat__c
                WHERE Account__c = :customerId
                AND Child_beat__r.Primary_Customer__c = :primaryCustomerId
                LIMIT 1
            ];
            if (!jbList.isEmpty()) {
                beatNameVal = jbList[0].Child_beat__r.Name;
            }
        }

        // Secondary Invoices with outstanding amount
        List<Secondary_Invoice__c> invoices = [
            SELECT Name, Invoice_Date__c, Grand_Total__c, Paid_Invoice_Amount__c, Pending_Amount__c,
                   Store__r.Name, Store__r.SAP_Customer_Code__c,Customer__r.Name, Customer__r.Customer_Code__c,
                   Beat_Name__c,Executive_Name__c,Executive_Employee_Code__c,Aging_in_Days__c
            FROM Secondary_Invoice__c
            WHERE Customer__c = :customerId AND Pending_Amount__c > 0
            ORDER BY Invoice_Date__c ASC
        ];

        for (Secondary_Invoice__c inv : invoices) {
            OutstandingReportItem item = new OutstandingReportItem();
            item.primaryCustomerSapCode = inv.Store__r != null ? inv.Store__r.SAP_Customer_Code__c : '';
            item.primaryCustomerName = inv.Store__r != null ? inv.Store__r.Name : '';
            item.secondaryCustomerCode = inv.Customer__r != null ? inv.Customer__r.Customer_Code__c : '';
            item.secondaryCustomerName = inv.Customer__r != null ? inv.Customer__r.Name : '';
            item.executiveCode = inv.Executive_Employee_Code__c != null ? inv.Executive_Employee_Code__c : execCode;
            item.executiveName = inv.Executive_Name__c != null ? inv.Executive_Name__c : execName;
            item.beatName = inv.Beat_Name__c != null ? inv.Beat_Name__c : beatNameVal;
            item.documentNumber = inv.Name;
            item.documentDate = inv.Invoice_Date__c;
            item.documentAmount = inv.Grand_Total__c != null ? inv.Grand_Total__c : 0;
            item.collectedAmount = inv.Paid_Invoice_Amount__c != null ? inv.Paid_Invoice_Amount__c : 0;
            item.outstandingAmount = inv.Pending_Amount__c != null ? inv.Pending_Amount__c : 0;
            item.documentType = 'Invoice';
            item.aging = inv.Aging_in_Days__c != null ? inv.Aging_in_Days__c : 0;
            result.add(item);
        }

        // Secondary Debit Notes with outstanding amount
        List<Secondary_Debit_Note__c> debitNotes = [
            SELECT Name, Note_Date__c, Amount__c, Paid_Amount__c, Pending_Amount__c,
                   Distributor__r.Name, Distributor__r.SAP_Customer_Code__c,
                   Customer__r.Name, Customer__r.Customer_Code__c,Aging_in_Days__c
            FROM Secondary_Debit_Note__c
            WHERE Customer__c = :customerId AND Pending_Amount__c > 0
            ORDER BY Note_Date__c ASC
        ];

        for (Secondary_Debit_Note__c dn : debitNotes) {
            OutstandingReportItem item = new OutstandingReportItem();
            item.primaryCustomerSapCode = dn.Distributor__r != null ? dn.Distributor__r.SAP_Customer_Code__c : '';
            item.primaryCustomerName = dn.Distributor__r != null ? dn.Distributor__r.Name : '';
            item.secondaryCustomerCode = dn.Customer__r != null ? dn.Customer__r.Customer_Code__c : '';
            item.secondaryCustomerName = dn.Customer__r != null ? dn.Customer__r.Name : '';
            item.executiveCode = execCode;
            item.executiveName = execName;
            item.beatName = beatNameVal;
            item.documentNumber = dn.Name;
            item.documentDate = dn.Note_Date__c;
            item.documentAmount = dn.Amount__c != null ? dn.Amount__c : 0;
            item.collectedAmount = dn.Paid_Amount__c != null ? dn.Paid_Amount__c : 0;
            item.outstandingAmount = dn.Pending_Amount__c != null ? dn.Pending_Amount__c : 0;
            item.documentType = 'Debit Note';
            item.aging = dn.Aging_in_Days__c != null ? dn.Aging_in_Days__c : 0;
            result.add(item);
        }

        result.sort();
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getPartnerAccountInfo() {
        Map<String, String> result = new Map<String, String>{
            'accountName' => '',
            'sapCode' => ''
        };
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (partnerUser.isEmpty() || partnerUser[0].ContactId == null) {
            return result;
        }
        List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
        if (contact.isEmpty() || contact[0].AccountId == null) {
            return result;
        }
        List<Account> accs = [
            SELECT Name, SAP_Customer_Code__c
            FROM Account
            WHERE Id = :contact[0].AccountId
            LIMIT 1
        ];
        if (accs.isEmpty()) {
            return result;
        }
        result.put('accountName', accs[0].Name);
        result.put('sapCode', accs[0].SAP_Customer_Code__c == null ? '' : String.valueOf(accs[0].SAP_Customer_Code__c));
        return result;
    }

    public class primaryLedgerEntry {
        @AuraEnabled public String postingDate;
        @AuraEnabled public String docDate;
        @AuraEnabled public String docNo;
        @AuraEnabled public String remarks;
        @AuraEnabled public String docType;
        @AuraEnabled public Decimal debit;
        @AuraEnabled public Decimal credit;
        @AuraEnabled public Decimal balance;
    }

    public class CustomerLedgerResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public String fromDate;
        @AuraEnabled public String toDate;
        @AuraEnabled public Decimal openingBalance;
        @AuraEnabled public Decimal closingBalance;
        @AuraEnabled public List<primaryLedgerEntry> data;
    }

    @AuraEnabled
    public static CustomerLedgerResult getCustomerLedger(String fromDate, String toDate) {
        CustomerLedgerResult out = new CustomerLedgerResult();
        out.success = false;
        out.data = new List<primaryLedgerEntry>();

        try {
            String sapCode = '';
            List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            if (!partnerUser.isEmpty() && partnerUser[0].ContactId != null) {
                List<Contact> contact = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
                if (!contact.isEmpty() && contact[0].AccountId != null) {
                    List<Account> accs = [
                        SELECT SAP_Customer_Code__c
                        FROM Account
                        WHERE Id = :contact[0].AccountId
                        LIMIT 1
                    ];
                    if (!accs.isEmpty() && accs[0].SAP_Customer_Code__c != null) {
                        sapCode = String.valueOf(accs[0].SAP_Customer_Code__c);
                    }
                }
            }
            if (String.isBlank(sapCode)) {
                out.errorMessage = 'No SAP Customer Code found for current user';
                return out;
            }

            External_API_Configuration__mdt config = [
                SELECT Endpoint_URL__c, API_Key__c, Method__c
                FROM External_API_Configuration__mdt
                WHERE DeveloperName = 'Customer_Record_API'
                LIMIT 1
            ];

            String boundary = '----ApexBoundary' + String.valueOf(DateTime.now().getTime());
            String body = '';
            body += '--' + boundary + '\r\n';
            body += 'Content-Disposition: form-data; name="sapCustomerCode"\r\n\r\n';
            body += sapCode + '\r\n';
            body += '--' + boundary + '\r\n';
            body += 'Content-Disposition: form-data; name="fromDate"\r\n\r\n';
            body += (fromDate == null ? '' : fromDate) + '\r\n';
            body += '--' + boundary + '\r\n';
            body += 'Content-Disposition: form-data; name="toDate"\r\n\r\n';
            body += (toDate == null ? '' : toDate) + '\r\n';
            body += '--' + boundary + '--\r\n';

            HttpRequest req = new HttpRequest();
            req.setEndpoint(config.Endpoint_URL__c);
            req.setMethod(String.isBlank(config.Method__c) ? 'POST' : config.Method__c);
            req.setHeader('X-API-KEY', config.API_Key__c);
            req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
            req.setTimeout(60000);
            req.setBody(body);

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                out.errorMessage = 'API returned status ' + res.getStatusCode() + ': ' + res.getBody();
                return out;
            }

            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            out.fromDate = (String) parsed.get('fromDate');
            out.toDate = (String) parsed.get('toDate');
            out.openingBalance = parsed.get('openingBalance') == null ? null : Decimal.valueOf(String.valueOf(parsed.get('openingBalance')));
            out.closingBalance = parsed.get('closingBalance') == null ? null : Decimal.valueOf(String.valueOf(parsed.get('closingBalance')));

            List<Object> rows = (List<Object>) parsed.get('data');
            if (rows != null) {
                for (Object o : rows) {
                    Map<String, Object> r = (Map<String, Object>) o;
                    primaryLedgerEntry e = new primaryLedgerEntry();
                    e.postingDate = (String) r.get('postingDate');
                    e.docDate = (String) r.get('docDate');
                    e.docNo = (String) r.get('docNo');
                    e.remarks = (String) r.get('remarks');
                    e.docType = (String) r.get('docType');
                    e.debit = r.get('debit') == null ? 0 : Decimal.valueOf(String.valueOf(r.get('debit')));
                    e.credit = r.get('credit') == null ? 0 : Decimal.valueOf(String.valueOf(r.get('credit')));
                    e.balance = r.get('balance') == null ? 0 : Decimal.valueOf(String.valueOf(r.get('balance')));
                    out.data.add(e);
                }
            }
            out.success = true;
        } catch (Exception ex) {
            out.errorMessage = ex.getMessage();
        }
        return out;
    }
}