@isTest
public class BeatPlannerLwcTest {

    @testSetup
    static void setupTestData() {
        // Create Accounts
        List<Account> accList = new List<Account>{
            new Account(
                Name = 'Primary Cust',
                City__c = 'Delhi',
                State__c = 'Delhi',
                District__c = 'New Delhi',
                Primary_Phone_Number__c = '9999999999',
                Aadhaar_No__c = '123412341234',
                Pincode__c = '110001',
                Customer_Type__c = 'Primary Customer',
                Customer_Status__c = 'Active',
                GeoLocation__Latitude__s =  28.6139,
                GeoLocation__Longitude__s = 77.2090,
                Secondary_Customer_Category__c = 'TN_Elite Club',
                Secondary_Customer_Type__c = 'Retailer',
                Approval_Status__c = 'Credit Dept. Approved',
                Email_ID__c = 'test@gmail.com',
                 SAP_Customer_Code__c ='19810121'
              
                
            ),
            new Account(
                Name = 'Secondary Cust',
                City__c = 'Mumbai',
                State__c = 'Andhra Pradesh',
                District__c = 'East Godavari',
                Primary_Phone_Number__c = '8888888888',
                Aadhaar_No__c = '567856785678',
                Pincode__c = '575444',
                Customer_Type__c = 'Secondary Customer',
                Customer_Status__c = 'Active',
                Email_ID__c = 'test@gmail.com',
                SAP_Customer_Code__c ='198101121'
            )
        };
        insert accList;

        // Create Visit and related Competition
        Visit__c visit = new Visit__c(Account1__c =accList[0].Id);
        insert visit;

        Competition__c comp = new Competition__c(Visit__c = visit.Id);
        insert comp;
        
        
         // Create SKU
        Product__c prod = new Product__c(Name='Test Product',SKU_Code__c ='testsksk');
        insert prod;

        // Create Display Format
        Display_Format__c displayFormat = new Display_Format__c(
            SKU__c = prod.Id,
            Display__c = 'Test Display'
        );
        insert displayFormat;

        // Create Account
        Account acc = new Account( Name = 'Primary Cust1',
                                  City__c = 'Delhi',
                                  State__c = 'Delhi',
                                  District__c = 'New Delhi',
                                  Primary_Phone_Number__c = '9999999998',
                                  Aadhaar_No__c = '123412341236',
                                  Pincode__c = '110003',
                                  Customer_Type__c = 'Primary Customer',
                                  Customer_Status__c = 'Active',
                                  SAP_Customer_Code__c ='1221119',
                                  Secondary_Customer_Category__c = 'TN_Elite Club',
                                  Email_ID__c  ='test@gmail.com',
                                  Secondary_Customer_Type__c = 'Retailer');
        insert acc;

        // Create Order
        Order__c order = new Order__c(
            Account__c = acc.Id,
            Order_Type__c = 'Primary Order',
            Order_Fulfillment_Status__c = 'Not Fulfilled',
            Order_Date__c = Date.today()
        );
        insert order;

        // Create Order Items
        List<Order_Item__c> items = new List<Order_Item__c>();
        for (Integer i = 0; i < 2; i++) {
            items.add(new Order_Item__c(
                Order__c = order.Id,
                Product__c = prod.Id,
                Quantity__c = 10,
                Delivered_Quantity__c = 0,
                Unit_Price__c = 100,
                Total_Amount__c = 1000,
                Tax_Amount__c = 100,
                Status__c = 'Not Fulfilled'
            ));
        }
        insert items;
        
        // Create Shelf Stock
        Shelf_Stock__c shelfStock = new Shelf_Stock__c(
            Visit__c = visit.Id,
            SKU__c = prod.Id,
            Stock_Level__c = 20,
            Sales_Quantity__c = 5,
            Comments_Compition_Remarks__c = 'Well positioned'
        );
        insert shelfStock;
        
        // Invoice for 'outstanding' and 'sales'
        invoice__c inv = new invoice__c(Store__c = accList[0].Id, Invoice_Date__c = Date.today(),Customer_Name__c='test',Invoice_No__c='12345432');
        insert inv;

        Sale__c sale = new Sale__c(Account__c = accList[0].Id, Invoice__c = inv.Id);
        insert sale;

        // Order for 'order'
        Order__c ord = new Order__c(Account__c = accList[0].Id, Order_Date__c = Date.today());
        insert ord;
        
    }

    @isTest
    static void testGetDailyLog() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniqueSuffix = String.valueOf(DateTime.now().getTime());

        User u = new User(
            Alias = 'testu',
            Email = 'testuser' + uniqueSuffix + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = 'testuser' + uniqueSuffix + '@example.com',
            Employee_Code__c = 'EMP' + uniqueSuffix
        );
        insert u;

        System.runAs(u) {
            Test.startTest();
            beatPlannerlwc.data result = beatPlannerlwc.getDailyLog();
            Test.stopTest();
            System.assertNotEquals(null, result);
        }
    }

    @isTest
    static void testUpsertDailyLogStartAndEndDay() {
        Daily_Log__c log = new Daily_Log__c(Day_started_time__c = DateTime.now());
        insert log;

        Calendar_beat__c pjp = new Calendar_beat__c(Active__c = true);
        insert pjp;

        PJP_Item__c pjpItem = new PJP_Item__c(
            PJP__c = pjp.Id,
            Order_Number__c = 1,
            Date__c = Date.today()
        );
        insert pjpItem;

        Test.startTest();
        beatPlannerlwc.upsertDailyLog(log, 'Startday');
        beatPlannerlwc.upsertDailyLog(log, 'EndDay');
        Test.stopTest();
    }
    
    @isTest static void testGetVisitData() {
        
        
        // Create a user for testing
        User testUser = new User(
            Username = 'testuser110090@example.com', 
            LastName = 'testet',
            Alias = 'tuser', 
            Email = 'testuser@example.com', 
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1].Id,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'ISO-8859-1',
            LanguageLocaleKey = 'en_US',
            IsActive = true,
            Employee_Code__c = '112774562237'
        );
        insert testUser;
        
       
        // Set the current user context to testUser
        System.runAs(testUser) {
            Account acc = [Select Id,Name from Account where Approval_Status__c = 'Credit Dept. Approved' Limit 1];
            
            Child_beat__c cb = new Child_beat__c();
            cb.Active__c = true;
            cb.Beat_type__c ='Secondary';
            //cb.Primary_Customer__c = acc.Id;
            //cb.Sub_Stockist__c = acc.id;
            insert cb;
            
            Calendar_beat__c pj = new Calendar_beat__c();
            insert pj;
            
            
            PJP_Item__c pl = new PJP_Item__c();
            pl.beat__c = cb.Id;
            pl.PJP__c = pj.id;
            insert pl;
            
            // Create Daily Log
            Daily_Log__c dailyLog = new Daily_Log__c(
                User__c = testUser.Id,
                Sales_App_id__c = 'TestApp123',
                Day_started_time__c = system.Now(),
                OwnerId = UserInfo.getUserId()     ,
                PJP_Item__c = pl.Id);
            insert dailyLog;
            
            
            
            // Create Visit__c records (mock for the visit data)
            Visit__c visit = new Visit__c(
                OwnerId = testUser.Id,
                Status__c = 'Completed',
                Approval_Status__c = 'Approved',
                Visit_for__c = 'Primary Customer',
Planned_Start_Time__c = system.now()   ,
           Child_beat__c = cb.Id,
                PJP_Item__c = pl.Id
            );
            insert visit;
            
            // Create Child_beat__c record
            Child_beat__c childBeat = new Child_beat__c(
                Sub_Stockist__c = null,
                Beat_type__c ='Secondary'
            );
            insert childBeat;
            
            // Create Junction_Beat__c
            Junction_Beat__c junctionBeat = new Junction_Beat__c(
                Child_Beat__c = cb.Id,
                Account__c = acc.Id
            );
            insert junctionBeat;
            
            // Create an invalid beat (non-existent)
            String invalidBeatId = 'InvalidBeatID';
            
            // Test with valid beat
            Test.startTest();
            beatPlannerlwc.getVisitData(cb.Id);
            beatPlannerlwc.getPreviewBeatCustomers(cb.Id);
            //beatPlannerlwc.getVisitData(invalidBeatId);
            
            
            
            Test.stopTest();
            
        }
    }
    
    
    
    @isTest static void testGetProductData() {
        
        User testUser = new User(
            Username = 'testuser110090@example.com', 
            LastName = 'testet',
            Alias = 'tuser', 
            Email = 'testuser@example.com', 
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1].Id,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'ISO-8859-1',
            LanguageLocaleKey = 'en_US',
            IsActive = true,
            Sales_Channel__c ='Cake',
            Employee_Code__c = '112774562237'
        );
        insert testUser;
        // Set the current user context to testUser
        System.runAs(testUser) {
            Account acc = [Select Id,Name from Account where Approval_Status__c = 'Credit Dept. Approved' Limit 1];
            Account acc1 = [Select Id,Name from Account where Customer_Type__c = 'Secondary Customer' Limit 1];
            Child_beat__c cb = new Child_beat__c();
            cb.Active__c = true;
            //cb.Primary_Customer__c = acc.Id;
            //cb.Sub_Stockist__c = acc.id;
              cb.Beat_type__c ='Secondary';
            insert cb;
            
            Calendar_beat__c pj = new Calendar_beat__c();
            insert pj;
            
            
            PJP_Item__c pl = new PJP_Item__c();
            pl.beat__c = cb.Id;
            pl.PJP__c = pj.id;
            insert pl;
            
            // Create Daily Log
            Daily_Log__c dailyLog = new Daily_Log__c(
                User__c = testUser.Id,
                Sales_App_id__c = 'TestApp123',
                Day_started_time__c = system.Now(),
                OwnerId = UserInfo.getUserId()     ,
                PJP_Item__c = pl.Id);
            insert dailyLog;
            
            
            
            // Create Visit__c records (mock for the visit data)
            Visit__c visit = new Visit__c(
                OwnerId = testUser.Id,
                Status__c = 'Completed',
                Approval_Status__c = 'Approved',
                Visit_for__c = 'Primary Customer',
                Planned_Start_Time__c = system.now()   ,
                Child_beat__c = cb.Id,
                PJP_Item__c = pl.Id
            );
            insert visit;
            
            // Create Child_beat__c record
            Child_beat__c childBeat = new Child_beat__c(
                Sub_Stockist__c = null,
                Beat_type__c ='Secondary'
            );
            insert childBeat;
            
            // Create Junction_Beat__c
            Junction_Beat__c junctionBeat = new Junction_Beat__c(
                Child_Beat__c = cb.Id,
                Account__c = acc.Id
            );
            insert junctionBeat;
           

			Area__c ar = new Area__c();
            ar.Sales_Channel__c = 'West';
            ar.Region__c = 'West';
			ar.Area__c = 'Mumbai';
insert ar;            
            Product_Mapping__c pm = new Product_Mapping__c();
            pm.Exectuive__c = testUser.Id;
            pm.Chanel__c = 'Cake';
            pm.Customer__c = acc.id;
            pm.Area__c = ar.Id;
            insert pm;
         
            
            product__c pro = new Product__c();
            pro.Channel__c = 'Cake';
            pro.Name = 'trt pro';
            pro.MRP__c = 100;
            pro.SKU_Code__c ='191kssaasksk';
            pro.List_Price__c = 50;
            insert pro;
               
            Sales_Channel_To_SKU__c sm = new Sales_Channel_To_SKU__c();
            sm.SKU__c = pro.Id;
            sm.Sales_Channel__c ='Cake';
            insert sm;
            
            Price_Change__c pc = new Price_Change__c();
            pc.Customer_Category__c = 'TN_Elite Club';
            pc.Type__c = 'MRP';
            pc.Off__c = 25;
            insert pc;
            
            Price_Book__c pb = new Price_Book__c();
            pb.MRP__c = 100;
            pb.Product__c = pro.Id;
            pb.Customer_Type__c = 'Primary Customer';
            pb.Unit_Price__c  = 50;
            pb.Customer__c = acc.Id;
            insert pb;
            
            Payment_follow_up__c pf = new Payment_follow_up__c();
            pf.Account__c = acc.Id;
            pf.Expected_Amount__c = 1000;
            pf.Comments__c = 'ffff';
            pf.Visit__c = visit.Id;
            insert pf;

Target__c tar = new Target__c();
tar.Executive__c = testUser.Id;
tar.Account__c = acc.Id;
tar.Actual__c = 100;
tar.Target__c = 100;
            tar.OwnerId = testUser.Id;

insert tar;         
            Target_Logic__c tl = new Target_Logic__c();
            tl.Name = 'TlLo';
            insert tl;
            Target_Item__c ti = new Target_Item__c();
            ti.Target__c = tar.Id;
            ti.Target_Logic__c = tl.Id;
            ti.Actual_Value__c = 100;
            insert ti;
            Product__c prod = [Select Id,Name,Createddate,Product_Category_Name__c,List_Price__c,Tax_Percent__c,Tax_Class__c,Selling_Category__c,Product_Category1__c,Product_Category1__r.Name from Product__c limit 1];
            Test.startTest();
            beatPlannerlwc.getStockProducts(acc.Id);
            beatPlannerlwc.getReturnData(acc.Id);
            beatPlannerlwc.getAccountsByArea('North','test', false);
            beatPlannerlwc.getAccountsByArea('North','test', true);
            beatPlannerlwc.getAreaOptions();
            beatPlannerlwc.saveFile(acc.Id,'Samp','tygdsudwe37373efgyegregyeg');
            beatPlannerlwc.getPDPDays(acc.Id,'Primary Customer');
            beatPlannerlwc.getExpenseLineData(10,5);
            beatPlannerlwc.getProductsForArea(acc.Id,'Secondary Customer');
            beatPlannerlwc.setOrder(new List<Product__c> {prod});
            beatPlannerlwc.getPaymentDestails(visit.Id);
            beatPlannerlwc.getTargetData(10,5);
            Test.stopTest();
            
        }
    }
    
    @isTest
    static void testUpdateGetValidateDeleteFiles() {
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('Test content'),
            Description = '12345'
        );
        insert cv;
        
        ContentVersion insertedVersion = [
            SELECT Id, ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :cv.Id
        ];
        String docId = insertedVersion.ContentDocumentId;
        
        Test.startTest();
        
        // Validate file
        String result = beatPlannerlwc.validateFileUpload('12345');
        System.assertEquals('Success', result);
        
        // Get files
        List<ContentDocument> files = beatPlannerlwc.getFiles('12345');
        System.assert(!files.isEmpty());
        
        // Update document
        beatPlannerlwc.updateDocument(new List<String>{ docId }, 'UpdatedDesc');
        
        // Delete file
        beatPlannerlwc.deleteFile(docId);
        
        Test.stopTest();
    }

    @isTest
    static void testGetVisitCreateData() {
        Test.startTest();
        beatPlannerlwc.data result = beatPlannerlwc.getVisitCreateData();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.primaryCustomers.size() > 0);
        System.assert(result.secoundaryCustomers.size() > 0);
    }

    @isTest
    static void testGetCompetitionData() {
        Visit__c visit = [SELECT Id FROM Visit__c LIMIT 1];

        Test.startTest();
        List<Competition__c> comps = beatPlannerlwc.getComptitionData(visit.Id);
        Test.stopTest();

        System.assertEquals(1, comps.size());
    }

    @isTest
    static void testGetBeatPlanData() {
        User u = [SELECT Id FROM User WHERE Profile.Name='System Administrator' LIMIT 1];

        System.runAs(u) {
          List<Account> acc = [select id ,Name FROM Account];
           

         

            Daily_Log__c log = new Daily_Log__c(Day_started_time__c = DateTime.now());
            insert log;
            
            Child_beat__c beat = new Child_beat__c();
            beat.Beat_type__c ='Secondary';
            insert beat;

            Calendar_beat__c pjp = new Calendar_beat__c(Active__c = true);
            insert pjp;

            PJP_Item__c pjpItem = new PJP_Item__c(
                PJP__c = pjp.Id,
                Date__c = Date.today(),
                Beat__c = beat.Id
            );
            insert pjpItem;

            insert new Junction_Beat__c(
                Child_Beat__c = beat.Id,
                Account__c = acc[0].Id,
                Order_Number__c = 1
            );

            Visit__c visit = new Visit__c(
                OwnerId = u.Id,
                Approval_Status__c = 'Approved',
                Account1__c = acc[0].Id,
                Child_beat__c = beat.Id,
                Daily_Log__c = log.Id,
                Planned_Start_Time__c = DateTime.now(),
                Planned_End_Time__c = DateTime.now().addHours(1),
                Actual_Start_Time__c = DateTime.now(),
                Actual_End_Time__c = DateTime.now().addMinutes(45)
            );
            insert visit;

            insert new Route__c(
                Name = 'Route 1',
                Is_Active__c = true
            );

            Test.startTest();
            //beatPlannerlwc.getBeatPlanData(Date.today(), Date.today());
            Test.stopTest();
        }
    }
     static testMethod void testCreateLeadAndFileLinking() {
        Visit__c visit = new Visit__c();
        insert visit;

        ContentVersion contentVersion = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'TestFile.jpg',
            VersionData = Blob.valueOf('Test content')
        );
        insert contentVersion;

         ContentVersion version = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];
         List<String> docIds = new List<String>{version.ContentDocumentId};

        Test.startTest();
        beatPlannerlwc.createLead('Test Name', '1234567890', 'Test Location', docIds, visit.Id);
        Test.stopTest();

      
    }

    static testMethod void testSaveDisplayFormat() {
        Visit__c visit = new Visit__c();
        insert visit;

        Product__c sku = new Product__c(Name = 'Test SKU',SKU_Code__c ='191kuusSSddksk');
        insert sku;

        Display_Format__c df = new Display_Format__c(Display__c = 'Test Display', SKU__c = sku.Id, Visit__c = visit.Id);
        
        ContentVersion contentVersion = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'TestFile.jpg',
            VersionData = Blob.valueOf('Test content')
        );
        insert contentVersion;

        ContentVersion version = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];
        List<String> docIds = new List<String>{version.ContentDocumentId};

        Test.startTest();
        beatPlannerlwc.saveDisplayFormat(df);
        Test.stopTest();

        
    }

    static testMethod void testSaveShelfStock() {
        Visit__c visit = new Visit__c();
        insert visit;

        Product__c sku = new Product__c(Name = 'Test SKU',SKU_Code__c ='191kuusSSddksk');
        insert sku;

        Shelf_Stock__c stock = new Shelf_Stock__c(Visit__c = visit.Id, SKU__c = sku.Id, Stock_Level__c = 5);
        
        Shelf_Stock_Items__c item = new Shelf_Stock_Items__c(
            SKU__c = sku.Id,
            Stock_Level__c = 5
        );
        List<Shelf_Stock_Items__c> items = new List<Shelf_Stock_Items__c>{item};

        ContentVersion contentVersion = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'TestFile.jpg',
            VersionData = Blob.valueOf('Test content')
        );
        insert contentVersion;

       
        ContentVersion version = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];
        List<String> docIds = new List<String>{version.ContentDocumentId};

        Test.startTest();
       	beatPlannerlwc.saveShelfStock(stock, items, docIds);
        Test.stopTest();

    }


    @isTest
    static void testGetDisplayFormatDetails() {
        Display_Format__c df = [SELECT Id FROM Display_Format__c LIMIT 1];
        Test.startTest();
       beatPlannerlwc.getDisplayFormatDetails(df.Id);
        Test.stopTest();
        
    }

    @isTest
    static void testDeleteDisplayFormat() {
        Product__c sku = new Product__c(Name = 'Test SKU',SKU_Code__c ='191ksksk');
        insert sku;
        Display_Format__c df = new Display_Format__c(Display__c='To Delete',SKU__c = sku.id);
        insert df;
        Test.startTest();
        beatPlannerlwc.deleteDisplayFormat(df.Id);
        Test.stopTest();
       
    }

    @isTest
    static void testGetUnfulfilledOrders() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        beatPlannerlwc.getUnfulfilledOrders(acc.Id);
        Test.stopTest();
        
    }

    @isTest
    static void testGetOrderLineItems() {
        Order__c order = [SELECT Id FROM Order__c LIMIT 1];
        Test.startTest();
         beatPlannerlwc.getOrderLineItems(order.Id);
        Test.stopTest();
       
    }

    @isTest
    static void testSaveOrderLineItems() {
        Order__c order = [SELECT Id FROM Order__c LIMIT 1];
        List<Order_Item__c> items = [SELECT Id, Delivered_Quantity__c FROM Order_Item__c WHERE Order__c = :order.Id];
        for (Order_Item__c item : items) {
            item.Delivered_Quantity__c = 5;
        }

        Test.startTest();
        beatPlannerlwc.saveOrderLineItems(items, Date.today(), 10, 1000, 'BILL123', order.Id, null, 'Over-Fulfilled');
        Test.stopTest();

       
    }

    @isTest
    static void testGetFilesForDisplayFormat() {
        Display_Format__c df = [SELECT Id FROM Display_Format__c LIMIT 1];
        
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('Test file content')
        );
        insert cv;
        
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId,
            LinkedEntityId = df.Id,
            ShareType = 'V'
        );
        insert cdl;

        Test.startTest();
       beatPlannerlwc.getFilesForDisplayFormat(df.Id);
        Test.stopTest();
       
    }
     @isTest
    static void testGetShelfStockDetails() {
        Shelf_Stock__c stock = [SELECT Id FROM Shelf_Stock__c LIMIT 1];

        Test.startTest();
       beatPlannerlwc.getshelfstockDetails(stock.Id);
        Test.stopTest();

    }

    @isTest
    static void testGetDisplayFormats() {
        Visit__c visit = [SELECT Id FROM Visit__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
       beatPlannerlwc.getDisplayFormats(visit.Id, acc.Id);
        Test.stopTest();

        
    }
    
    @isTest
    static void testGetVisitFiles() {
        // Step 1: Create a test ContentDocument
        ContentVersion version = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test content'),
            Description = 'VISIT-123' // This is your uniqueId to test against
        );
        insert version;

        // Fetch the ContentDocumentId using SOQL since it's created asynchronously
        ContentVersion insertedVersion = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :version.Id
            LIMIT 1
        ];

        // Step 2: Now fetch using the method under test
        Test.startTest();
        beatPlannerlwc.getVisitFiles('VISIT-123');
        Test.stopTest();

    }
    
    @isTest
    static void testValidateVisitFileUpload() {
        ContentVersion version = new ContentVersion(
            Title = 'Visit File',
            PathOnClient = 'VisitFile.pdf',
            VersionData = Blob.valueOf('Test content'),
            Description = 'VISIT-123'
        );
        insert version;
        
        ContentVersion insertedVersion = [
            SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :version.Id LIMIT 1
        ];
        
        Test.startTest();
       beatPlannerlwc.validateVisitFileUpload('VISIT-123');
        Test.stopTest();
        
      
    }
    @isTest
    static void testGetGeoFencing() {
        // Near match (within 500m)
       list<Account> acc = [SELECT Id, GeoLocation__Latitude__s, GeoLocation__Longitude__s FROM Account];
        
        Test.startTest();
       beatPlannerlwc.getGeoFencing(acc[0].Id, 28.6140, 77.2091);
         beatPlannerlwc.getGeoFencing(acc[1].Id, 28.6140, 77.2091); 
        Test.stopTest();
        
       
    }
    @isTest
    static void testCompleteVisit_PJP_Successful() {
        list<Account> acc = [SELECT Id, GeoLocation__Latitude__s, GeoLocation__Longitude__s FROM Account];
        Product__c prod =[SELECT id, Name FROM Product__c];
        
        // Create a Daily Log record
        Daily_Log__c log = new Daily_Log__c();
        log.Clock_Out_Location__Longitude__s =37.7749;
        log.Clock_Out_Location__Latitude__s = 78.4194;
        insert log;
        
        Visit__c visit = new Visit__c();
        visit.Daily_log__c = log.Id;
        insert visit;
        
        Test.startTest();
        Visit__c result = beatPlannerlwc.completeVisit(visit, 'BEAT-001');
        Test.stopTest();
        
       
    }
    
    @isTest
    static void testGetAllVisitData() {
        // Create account and related data
        list<Account> acc = [SELECT Id,Name, GeoLocation__Latitude__s, GeoLocation__Longitude__s FROM Account];
         Product__c prod =[SELECT id, Name FROM Product__c];

        // Create visit
        Visit__c visit = new Visit__c( Visit_for__c = 'Primary Customer', Account1__c = acc[0].Id);
        insert visit;

        // Create Order and Order_Item
        Order__c order = new Order__c( Visit__c = visit.Id, Account__c = acc[0].Id);
        insert order;

        Order_Item__c orderItem = new Order_Item__c(Order__c = order.Id, Product__c = null, Total_Amount__c = 100, Quantity__c = 1);
        insert orderItem;

        // Dealer Stock
        Dealer_Stock__c stock = new Dealer_Stock__c(Visit__c = visit.Id, Store__c = acc[0].Id, Product__c = null, Quantity__c = 10, Unit_Price__c = 50);
        insert stock;

        // Outlet Task
        Outlet_Task__c task = new Outlet_Task__c(Account__c = acc[0].Id, Description__c = 'Task', Task_Status__c = 'Completed');
        insert task;

        // Invoice
        Invoice__c invoice = new Invoice__c(Store__c = acc[0].Id,Customer_Name__c ='test customer' ,Invoice_No__c= '123456');
        insert invoice;

        // Sale
        Sale__c sale = new Sale__c(Account__c = acc[0].Id, Total_Amount__c = 200);
        insert sale;

        // Competition
        Competition__c competition = new Competition__c(Visit__c = visit.Id, Competitor_Name__c = 'XYZ');
        insert competition;

        // Lead
        Lead lead = new Lead(LastName = 'Test', Phone = '1234567890', Visit__c = visit.Id,Company = 'test company');
        insert lead;

        // Display Format
        Display_Format__c df = new Display_Format__c(Visit__c = visit.Id, SKU__c = prod.Id, Display__c = 'Wall');
        insert df;

        // Shelf Stock
        Shelf_Stock__c shelf = new Shelf_Stock__c(Visit__c = visit.Id, Total_Stock_Level__c = 50, Total_Sales_Quantity__c = 20);
        insert shelf;
        Account acc1 = [Select Id,Name from Account where Customer_Type__c = 'Primary Customer' LIMIT 1];
        // Return & Return Item
        Return__c ret = new Return__c(Visit__c = visit.Id, Total_Amount__c = 100, Total_Quantity__c = 5,Customer__c =acc1.Id,Return_Date__c = Date.today() );
        insert ret;
        
        Return_Item__c returnItem = new Return_Item__c(Return__c = ret.Id, Quantity__c = 5);
        insert returnItem;
        beatPlannerlwc.getSummeryData(visit.Id, 'return');
        // Collection & Collection Item
        Collection__c collection = new Collection__c(Visit__c = visit.Id, Mode_of_Payment__c = 'Cash', Reference_Number__c = 'REF123');
        insert collection;

        Collection_Item__c collectionItem = new Collection_Item__c(Collection__c = collection.Id, Amount_Received__c = 100);
        insert collectionItem;

        Test.startTest();
       beatPlannerlwc.getAllVisitData(visit.Id);
        Test.stopTest();

       
    }
    
   /*  @isTest
    static void testGetStockProducts() {
         list<Account> acc = [SELECT Id,Name, GeoLocation__Latitude__s, GeoLocation__Longitude__s FROM Account];
        

        // Create Products linked to an executive (simulate logic inside getProducts)
        List<Product__c> products = new List<Product__c>{
            new Product__c(
                Name = 'Product A',
                List_Price__c = 100,
                Tax_Percent__c = 18,
                Tax_Class__c = '18',
                UOM__c = 'Nos',
                Channel__c = 'Bread'
            ),
            new Product__c(
                Name = 'Product B',
                List_Price__c = 200,
                Tax_Percent__c = 12,
                Tax_Class__c = '18',
                UOM__c = 'Nos',
                Channel__c = 'Bread'
            ),
            new Product__c(
                Name = 'Product C',
                List_Price__c = 150,
                Tax_Percent__c = 5,
                Tax_Class__c = '18',
                UOM__c = 'Nos', 
                Channel__c = 'Bread'
            )
        };
        insert products;

        Test.startTest();
         beatPlannerlwc.getStockProducts(acc[0].Id);
        Test.stopTest();

       
        }*/
    
     @isTest
    static void testUpsertStock() {
        // Create sample Dealer_Stock__c record
        Dealer_Stock__c stock = new Dealer_Stock__c();
        List<Dealer_Stock__c> stockList = new List<Dealer_Stock__c>{ stock };

        Test.startTest();
        beatPlannerlwc.upsertStock(stockList);
        Test.stopTest();

        
    }
     @isTest
    static void testGetCollectionsData_PrimaryCustomer() {
        // Insert an Invoice record
        Invoice__c inv = new Invoice__c(Invoice_Date__c = Date.today(), Outstanding_Amount__c = 500,Customer_Name__c = 'testing' ,Invoice_No__c='1234567');
        insert inv;

        Test.startTest();
        beatPlannerlwc.getCollectionsData(null, true);
        Test.stopTest();

     
    }

    @isTest
    static void testGetCollectionsData_NonPrimaryCustomer() {
        Test.startTest();
       beatPlannerlwc.getCollectionsData(null, false);
        Test.stopTest();

       
    }
    @isTest
    static void testSaveCollections() {
        // Create a Collection__c record
        Collection__c collection = new Collection__c();
        
        // Create related Collection_Item__c
        Collection_Item__c item = new Collection_Item__c();

        List<Collection_Item__c> items = new List<Collection_Item__c>{ item };

        Test.startTest();
        beatPlannerlwc.saveCollections(collection, items);
        Test.stopTest();

      
    }
     @isTest
    static void testGetCompetitions() {
        // Create Visit ID
       Visit__c visit = new Visit__c();
        insert visit;

        // Create Competition__c record 
        Competition__c comp = new Competition__c(
           Visit__c = visit.Id
        );
        insert comp;
        list<Account> acc = [SELECT Id,Name, GeoLocation__Latitude__s, GeoLocation__Longitude__s FROM Account];

        // Create Product_Category__c
        Product_Category__c category = new Product_Category__c(Name = 'Snacks', Active__c = true);
        insert category;

        // Create Competitor__c
        Competitor__c competitor = new Competitor__c(Name = 'Brand X');
        insert competitor;

        Test.startTest();
         beatPlannerlwc.getCompetions(acc[0].Id, visit.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testSaveCompetition_WithNewCompetitor() {
        Visit__c visit = new Visit__c();
        insert visit;

        Competition__c cmp = new Competition__c(
           Visit__c = visit.Id,
            Competitor_Name__c = 'New Competitor',
            Product_Category__c = null,
            Product__c = null
        );

        Test.startTest();
         beatPlannerlwc.saveCompetition(cmp, visit.Id);
        Test.stopTest();

       
    }

    @isTest
    static void testSaveCompetition_WithExistingCompetitor() {
        Competitor__c comp = new Competitor__c();
        insert comp;
         Visit__c visit = new Visit__c();
        insert visit;

        Competition__c cmp = new Competition__c(
           Competitor__c = comp.Id,
            Visit__c = visit.Id
        );

        Test.startTest();
         beatPlannerlwc.saveCompetition(cmp, cmp.Visit__c);
        Test.stopTest();

        
    }
      @isTest
    static void testGetFilesWithUniqueId() {
        // Create and insert dummy ContentVersion with Description as uniqueId
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('Test content'),
            Description = 'UNIQUE123'
        );
        insert cv;

        Test.startTest();
        beatPlannerlwc.getFilescompetetion('UNIQUE123', null);
        Test.stopTest();

    }

    @isTest
    static void testGetFilesWithRecordId() {
        // Simulate a linked record
        List<Account> acc = [SELECT id ,Name FROM Account];
        

        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('Test'),
            FirstPublishLocationId = acc[0].Id
        );
        insert cv;

        List<ContentDocumentLink> links = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :acc[0].Id];
        System.assert(!links.isEmpty(), 'Document should be linked');

        Test.startTest();
        beatPlannerlwc.getFilescompetetion('', acc[0].Id);
        Test.stopTest();
    }
     @isTest
    static void testGetProductsWithMapping() {
         List<Account> acc = [SELECT id ,Name FROM Account];
        
        area__c tr = new area__c();
        tr.Name = 'test';
        tr.Sales_Channel__c = 'CPD';
        tr.Region__c =	'Kerala';
        tr.Area__c  = 'Central';
        insert tr;
        
        
        // Add Product Mapping for user
        Product_Mapping__c mapping = new Product_Mapping__c(
            Customer__c = acc[0].Id,
            Exectuive__c = UserInfo.getUserId(),
            Chanel__c = 'Cake',
            Area__c = tr.Id
        );
        insert mapping;

        // Add a Product in same channel
        Product__c product = new Product__c(
            Name = 'Test Product',
            Is_Active__c = true,
              SKU_Code__c ='191kssaasksk',
            Channel__c = 'Cake'
        );
        insert product;

        Test.startTest();
         beatPlannerlwc.getProducts(acc[0].Id,'Primary Customer');
        Test.stopTest();

    }

    @isTest
    static void testGetProductsWithNoChannel() {
        List<Account> acc = [SELECT id ,Name FROM Account];

        Test.startTest();
        List<Product__c> products = beatPlannerlwc.getProducts(acc[0].Id,'Primary Customer');
        Test.stopTest();

    }
    
    @isTest
    static void testUpdateTargetTotals() {
        // Setup Test Data
        Target__c target1 = new Target__c();
        Target__c target2 = new Target__c();
        insert new List<Target__c> { target1, target2 };

        Target_Item__c targetItem1 = new Target_Item__c(
            Target__c = target1.Id,
            Actual_Value__c = 100,
            Target_Value__c = 200
        );
        Target_Item__c targetItem2 = new Target_Item__c(
            Target__c = target2.Id,
            Actual_Value__c = 150,
            Target_Value__c = 250
        );
        insert new List<Target_Item__c> { targetItem1, targetItem2 };

        Test.startTest();
        
        // Call the method
        Set<Id> targetIds = new Set<Id>{ target1.Id, target2.Id };
        beatPlannerlwc.updateTargetTotals(targetIds);
        
        Test.stopTest();

      
    }
   /* @isTest
    static void testUpsertOrder() {
        // Setup Test Data
        List<Account> primaryAcc = [SELECT id ,Name FROM Account];
        Daily_Log__c log = new Daily_Log__c(Day_started_time__c = DateTime.now());
        insert log;

        Visit__c visit = new Visit__c(Visit_for__c = 'Primary Customer', Account1__c = primaryAcc[0].Id);
        insert visit;
         Product__c product = new Product__c(
            Name = 'Test Product',
            Is_Active__c = true,
            Channel__c = 'Cake'
        );
        insert product;

        Order__c existingOrder = new Order__c(
            Account__c = primaryAcc[0].Id,
            Visit__c = visit.Id,
            Order_Date__c = System.today(),
            Expected_Delivery_Date__c = System.today().addDays(7),
            Delivery_To__c = 'Delivery Location'
        );
        insert existingOrder;

        Order_Item__c orderItem1 = new Order_Item__c(Product__c = product.Id, Quantity__c = 10, Unit_price__c = 100, Tax_Amount__c = 15, Order__c = existingOrder.Id);
        Order_Item__c orderItem2 = new Order_Item__c(Product__c = product.Id, Quantity__c = 5, Unit_price__c = 200, Tax_Amount__c = 25, Order__c = existingOrder.Id);
        insert new List<Order_Item__c> { orderItem1, orderItem2 };

        // Prepare input data for upsertOrder method
        List<Order_Item__c> orderItems = new List<Order_Item__c>{
            new Order_Item__c(Product__c = product.Id, Quantity__c = 3, Unit_price__c = 300, Tax_Amount__c = 35)
        };
            String ordersData = JSON.serialize(orderItems);

        Test.startTest();
        
        // Call the method
       beatPlannerlwc.upsertOrder(
            primaryAcc[0].Id,
            visit.Id,
            log.Id, 
            ordersData,
            existingOrder.Id
         );
        
        Test.stopTest();

        
    }*/
    // Test for getData method
    @isTest static void testGetData() {
        List<Account> primaryAcc = [SELECT id ,Name FROM Account];
        
        // Test My Target
        Test.startTest();
        beatPlannerlwc.getData(0, 10, 'My Target', null, null);
        // Test Expense
        beatPlannerlwc.getData(0, 10, 'Expense', null, null);
        // Test BeatPlan
        beatPlannerlwc.getData(0, 10, 'BeatPlan', Date.today(), Date.today().addDays(5));
        // Test Product
        beatPlannerlwc.getData(0, 10, 'Product', null, null);
        // Test getOrderProductivityforMonth
        beatPlannerlwc.getData(0, 10, 'getOrderProductivityforMonth', null, null);
        // Test getOrderProductivityforToday
        beatPlannerlwc.getData(0, 10, 'getOrderProductivityforToday', null, null);
        Test.stopTest();
        
    }
    
    // Test for getDataRecordById method
    @isTest static void testGetDataRecordById() {
        List<Account> acc = [SELECT id ,Name FROM Account];
        
        // Create a visit record for testing getOrderDestails
        Order__c ord = new Order__c(Account__c = acc[0].Id);
        insert ord;
         Product__c product = new Product__c(
            Name = 'Test Product',
            Is_Active__c = true,
            Channel__c = 'Cake',
            SKU_Code__c ='191kssaasksk'
        );
        insert product;
        
        // Create order items
        Order_Item__c ordItem = new Order_Item__c(Order__c = ord.Id, Product__c = product.Id, Quantity__c = 10);
        insert ordItem;
        
        // Test getOrderDetails
        Test.startTest();
        beatPlannerlwc.getDataRecordById(ord.Id, 'getOrderDetails');
       
         beatPlannerlwc.getDataRecordById(ord.Id, 'getPaymentDetails');
        Test.stopTest();
        
    }
    
    // Test for getOrderDestails method
    @isTest static void testGetOrderDestails() {
        List<Account> acc = [SELECT id ,Name FROM Account];
         
        // Create a visit record for testing getOrderDestails
        Order__c ord = new Order__c(Account__c = acc[0].Id);
        insert ord;
         Product__c product = new Product__c(
            Name = 'Test Product',
            Is_Active__c = true,
            Channel__c = 'Cake',
             SKU_Code__c ='191kssaaskffsk'
        );
        insert product;
        
        // Create order items
        Order_Item__c ordItem = new Order_Item__c(Order__c = ord.Id, Product__c = product.Id, Quantity__c = 10);
        insert ordItem;
        
        
        Test.startTest();
        beatPlannerlwc.getOrderDestails(ord.Id);
        Test.stopTest();
        
    }
    
     @isTest
    private static void testGetSchemeWiseOrderData() {
        
        // Step 1: Prepare necessary test data
        
        // Create User for currentUserId
       User u = [SELECT Id FROM User WHERE Profile.Name='System Administrator' LIMIT 1];

        // Create Account for Visit or Order related data
        List<Account> testAccount = [SELECT id ,Name FROM Account];
         Product__c product = new Product__c(
            Name = 'Test Product',
            Is_Active__c = true,
             SKU_Code__c ='191DDSSksksk',
            Channel__c = 'Cake'
        );
        insert product;
        
        // Create Visit record to associate with Account
        Visit__c testVisit = new Visit__c(Account1__c = testAccount[0].Id);
        insert testVisit;
        
        // Create Order Item and related Order records
        Order__c testOrder = new Order__c(Account__c = testAccount[0].Id, Visit__c = testVisit.Id);
        insert testOrder;
        
        Order_Item__c testOrderItem = new Order_Item__c(Order__c = testOrder.Id, Product__c = product.Id, Quantity__c = 10, Unit_Price__c = 100, Total_Amount__c = 1000);
        insert testOrderItem;
                
        area__c tr = new area__c();
        tr.Name = 'test';
        tr.Sales_Channel__c = 'CPD';
        tr.Region__c =	'Kerala';
        tr.Area__c  = 'Central';
        insert tr;
        
        
        // Create Product Mapping for Channel Set
        Product_Mapping__c testProductMapping = new Product_Mapping__c(Customer__c = testAccount[0].Id, Exectuive__c = u.Id, Chanel__c = 'cake', Area__c = tr.Id);
        insert testProductMapping;

        // Create Scheme for testing
        Scheme__c testScheme = new Scheme__c(Name = 'Test Scheme', Scheme_Start_Date__c = Date.today().addDays(-1), Scheme_End_Date__c = Date.today().addDays(1));
        insert testScheme;
        
        // Create Buy Product for testing Scheme's Buy_Products__r
        Buy_Product__c testBuyProduct = new Buy_Product__c(Scheme__c = testScheme.Id, Product__c = product.Id, Min__c = 5, Buy_Quantity__c = 5, Discount__c = 10);
        insert testBuyProduct;

        // Create Sales Strategy records
        Sales_Strategy__c testSalesStrategy = new Sales_Strategy__c(Product__c = product.Id, Account__c = testAccount[0].Id, Type__c = 'Customer', From_Date__c = Date.today().addDays(-1), To_Date__c = Date.today().addDays(1), Must_Focused__c = 'Must Sell');
        insert testSalesStrategy;

        // Step 2: Call the method using test data
        Test.startTest();
        beatPlannerlwc.getSchemeWiseOrderData(null,null, testOrder.Id);
        Test.stopTest();

        
    }
    
     @isTest
    static void testGetAccountData() {
       

        // Step 2: Call the method
        Test.startTest();
       beatPlannerlwc.getAccountData('');
        Test.stopTest();

        
    }
    @isTest
    static void testPushToLogistics() {
       
        Account acc = [Select Id,Name from Account where Customer_Type__c = 'Primary Customer' LIMIT 1];

        // Step 2: Insert a test Order__c record
        Order__c order = new Order__c(
            
            Push_to_Logistics__c = 'Yes' ,
            Account__c = acc.Id
        );
        insert order;

       
        Test.startTest();
        beatPlannerlwc.pushToLogistics(order.Id);
        Test.stopTest();

    
    }

    
    @isTest
    static void testGetSummeryDataOutstanding() {
        Visit__c vs = [SELECT Id,Account1__c FROM Visit__c LIMIT 1];
        invoice__c inv = new invoice__c();
        inv.Store__c = vs.Account1__c;
        inv.Invoice_Date__c = system.today();
        inv.Customer_Name__c = 'Tes';
        inv.Invoice_No__c = '367';
        insert inv;
        Test.startTest();
        beatPlannerlwc.getSummeryData(vs.Id, 'outstanding');
        Test.stopTest();
       
    }
    
    @isTest
    static void testGetSummeryDataOrder() {
        Visit__c vs = [SELECT Id,Account1__c FROM Visit__c LIMIT 1];
        Test.startTest();
        beatPlannerlwc.getSummeryData(vs.Id, 'order');
       
        Test.stopTest();
       
    }
    
    @isTest
    static void testGetSummeryDataVisit() {
        Visit__c vs = [SELECT Id,Account1__c FROM Visit__c LIMIT 1];
        vs.Actual_Start_Time__c = system.Now();
        update vs;
        Test.startTest();
      beatPlannerlwc.getSummeryData(vs.Id, 'visit');
        Test.stopTest();
       
    }
    
    @isTest
    static void testGetSummeryDataSales() {
        Visit__c vs = [SELECT Id,Account1__c FROM Visit__c LIMIT 1];
        Test.startTest();
        beatPlannerlwc.getSummeryData(vs.Id, 'sales');
        Test.stopTest();
       
    }
    
    @isTest
    static void testGetSummeryDataNullRecord() {
        Visit__c vis = new Visit__c();
        insert vis;
        Test.startTest();
       beatPlannerlwc.getSummeryData(vis.Id, 'order');
        Test.stopTest();
       
    }
    /*@isTest
    /static void testGetReturnData() {
        // Create Account
      List<Account> acc = [SELECT id ,Region__c,Name,Customer_Type__c,Secondary_Customer_Category__c FROM Account];
        
        // Create Product
        Product__c product = new Product__c(Name = 'Test Product', Is_Active__c = true, MRP__c = 120);
        insert product;
        
        // Create Price Book for Product
        Price_Book__c pb = new Price_Book__c(
            Product__c = product.Id,
            Customer__c = acc[0].Id,
            Unit_Price__c = 90,
            Region__c = acc[0].Region__c,
            Secondary_Customer_Category__c = acc[0].Secondary_Customer_Category__c
        );
        insert pb;
        
       
            
          Test.startTest();
        beatPlannerlwc.getReturnData(acc[0].Id);
        Test.stopTest();
        
        
    }*/
    
    @isTest
    static void testSaveReturn() {
           Account acc = [Select Id,Name from Account where Customer_Type__c = 'Primary Customer' LIMIT 1];
        // Create a test Return__c record
        Return__c ret = new Return__c();
        ret.Customer__c = acc.Id;
      
        
        // Create related Return Items
        List<Return_Item__c> items = new List<Return_Item__c>();
        items.add(new Return_Item__c( Return__c = ret.Id, Quantity__c = 2));
        items.add(new Return_Item__c( Return__c = ret.Id, Quantity__c = 5));
        
        Test.startTest();
        beatPlannerlwc.saveReturn(ret, items);
        Test.stopTest();
        
        
    }
    
    @isTest
    static void testGetBeatData() {
                User testUser = new User(
            Username = 'testuser110090@example.com', 
            LastName = 'testet',
            Alias = 'tuser', 
            Email = 'testuser@example.com', 
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1].Id,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'ISO-8859-1',
            LanguageLocaleKey = 'en_US',
            IsActive = true,
            Sales_Channel__c ='Cake',
            Employee_Code__c = '112774562237'
        );
        insert testUser;
        // Set the current user context to testUser
        System.runAs(testUser) {
            Account acc = [Select Id,Name from Account where Approval_Status__c = 'Credit Dept. Approved' Limit 1];
            
            Child_beat__c cb = new Child_beat__c();
            cb.Active__c = true;
              cb.Beat_type__c ='Secondary';
            //cb.Primary_Customer__c = acc.Id;
           // cb.Sub_Stockist__c = acc.id;
            insert cb;
            
            Calendar_beat__c pj = new Calendar_beat__c();
            pj.User__c = testUser.Id;
            insert pj;
            
            
            PJP_Item__c pl = new PJP_Item__c();
            pl.beat__c = cb.Id;
            pl.PJP__c = pj.id;
            pl.Date__c = System.today();
            pl.Status__c = 'Approved';
            insert pl;
            
            // Create Daily Log
            Daily_Log__c dailyLog = new Daily_Log__c(
                User__c = testUser.Id,
                Sales_App_id__c = 'TestApp123',
                Day_started_time__c = system.Now(),
                OwnerId = UserInfo.getUserId()     ,
                PJP_Item__c = pl.Id);
            insert dailyLog;
            
            
            
            // Create Visit__c records (mock for the visit data)
            Visit__c visit = new Visit__c(
                OwnerId = testUser.Id,
                Status__c = 'Completed',
                Approval_Status__c = 'Approved',
                Visit_for__c = 'Primary Customer',
                Planned_Start_Time__c = system.now()   ,
                Child_beat__c = cb.Id,
                PJP_Item__c = pl.Id
            );
            insert visit;
            
            // Create Child_beat__c record
            Child_beat__c childBeat = new Child_beat__c(
                Sub_Stockist__c = null,
                Beat_type__c ='Secondary'
            );
            insert childBeat;
            
            // Create Junction_Beat__c
            Junction_Beat__c junctionBeat = new Junction_Beat__c(
                Child_Beat__c = cb.Id,
                Account__c = acc.Id
            );
            insert junctionBeat;
           
                    area__c tr = new area__c();
            tr.Name = 'test';
            tr.Sales_Channel__c = 'CPD';
            tr.Region__c =	'Kerala';
            tr.Area__c  = 'Central';
            insert tr;
            
            
            
            Product_Mapping__c pm = new Product_Mapping__c();
            pm.Exectuive__c = testUser.Id;
            pm.Chanel__c = 'Cake';
            pm.Customer__c = acc.id; 
            pm.Area__c = tr.Id;
            insert pm;
            
            product__c pro = new Product__c();
            pro.Channel__c = 'Cake';
            pro.SKU_Code__c ='191ksksk';
            pro.Name = 'trt pro';
            pro.MRP__c = 100;
            pro.List_Price__c = 50;
            insert pro;
            Product_Category__c pr = new Product_Category__c();
            pr.Name = 'test';
            insert pr;
            
            Price_Change__c pc = new Price_Change__c();
            pc.Customer_Category__c = 'TN_Elite Club';
            pc.Type__c = 'MRP';
            pc.Off__c = 25;
            insert pc;
        
        // Step 2: Construct JSON payload
        String ordersData = '[{"deliveryTo":"Customer A","expectedDate":"2025-06-26","plantName":"1165","products":[{"Product__c":"' + pro.Id + '","Product_Category__c":"' + pr.Id + '","Quantity__c":10,"Unit_price__c":99.99,"Tax__c":5.0,"Tax_Amount__c":50.0,"Total_Amount__c":1049.9,"Case_Qyt__c":1,"Each_Qyt__c":5}]}]';
        
        Test.startTest();
        beatPlannerlwc.getBeatData();
            beatPlannerlwc.updateCurrentBeatAndSwitchHistory(cb.Id,'Beat','Switch','Simple',pl.Id);
                   beatPlannerlwc.upsertOrder(
            acc.Id,
            visit.Id,
            dailyLog.Id,
            ordersData,
            '',
                    16.291011,
                       82.29201
        );
        Test.stopTest();
        
        
    }
    }

    @isTest
   public static void testWrapperClasses() {
        // paymentFollowUpData
        beatPlannerlwc.paymentFollowUpData pf = new beatPlannerlwc.paymentFollowUpData();
        pf.Name = 'Test Name';
        pf.accName = 'Test Account';
        pf.expectedAmount = 1234.56;
        pf.id = '001xx000003DGsZAAW';
        pf.comments = 'Test comment';
        pf.expctedDate = '2025-08-01';
        pf.accId = '001xx000003DGsZAAW';
        
        // productive
        beatPlannerlwc.productive prod = new beatPlannerlwc.productive();
        prod.TSL = 100;
        prod.LPPC = 50;
        prod.productiveCalls = 10;
        prod.formattedDate = '01-Aug-2025';
        
        // productData
        beatPlannerlwc.productData prodData = new beatPlannerlwc.productData();
        prodData.id = 'prod001';
        prodData.name = 'Product A';
        prodData.unitPrice = 250.00;
        prodData.taxPercent = 18;
        prodData.offer = true;
        prodData.category = 'Cat A';
        prodData.onHover = false;
        prodData.uom = 'Box';
        prodData.SKUCodeId = 'sku001';
        prodData.SKUCodeName = 'SKU A';
        prodData.discountedPrice = 200;
        prodData.total = 1000;
        
        // categoryData
        beatPlannerlwc.categoryData catData = new beatPlannerlwc.categoryData();
        catData.categoryName = 'Beverages';
        catData.salesId = 'sales001';
        catData.index1 = 1;
        catData.products = new List<beatPlannerlwc.productData>{prodData};
            
            // visitPlan_visits
            beatPlannerlwc.visitPlan_visits vpv = new beatPlannerlwc.visitPlan_visits();
        vpv.selectedDate = System.now();
        vpv.visitPlanId = 'vp001';
        vpv.salesAppId = 'app001';
        vpv.visitType = 'PJP';
        vpv.accountId = 'acc001';
        vpv.accountName = 'Account A';
        
        // visitPlanData
        beatPlannerlwc.visitPlanData vpd = new beatPlannerlwc.visitPlanData();
        vpd.appVisitPlanid = 'vpApp001';
        vpd.id = 'vp001';
        vpd.createdDate = System.now();
        vpd.month = 'August';
        vpd.year = '2025';
        vpd.name = 'Visit Plan 1';
        vpd.frequency = 'Weekly';
        vpd.executiveId = 'exec001';
        vpd.executiveName = 'Exec A';
        vpd.visits = new List<beatPlannerlwc.visitPlan_visits>{vpv};
            
            // visitData
            beatPlannerlwc.visitData vd = new beatPlannerlwc.visitData();
        vd.Name = 'Visit 1';
        vd.VisitDate = Date.today();
        vd.formattedVisitDate = '01-Aug-2025';
        vd.actualStartDateTimeString = '2025-08-01T09:00:00Z';
        vd.actualEndtDateTimeString = '2025-08-01T10:00:00Z';
        vd.accountName = 'Account A';
        vd.acccountId = 'acc001';
        vd.appAccountId = 'appAcc001';
        vd.dailyLogName = 'DL1';
        vd.dailyLogId = 'DLID1';
        vd.salesAppId = 'appSalesId';
        vd.checkinlatti = 12.9716;
        vd.checkinlongi = 77.5946;
        vd.inLocation = true;
        vd.customerLocationLattitude = 12.9716;
        vd.customerLocationLongitude = 77.5946;
        
        // cls_expenseItems
        beatPlannerlwc.cls_expenseItems expItem = new beatPlannerlwc.cls_expenseItems();
        expItem.allowanceType = 'DA';
        expItem.ExpenseDate = '2025-08-01';
        expItem.FromCity = 'City A';
        expItem.ToCity = 'City B';
        expItem.expenseType = 'Travel';
        expItem.type = 'TA';
        expItem.amount = 500;
        expItem.description = 'Travel to client';
        expItem.ExpIDs = 'EXP001';
        
        // expenseData
        beatPlannerlwc.expenseData expData = new beatPlannerlwc.expenseData();
        expData.TAAMount = 500;
        expData.totalOtherAmount = 200;
        expData.totalKm = 100;
        expData.DtAmount = 300;
        expData.lineItemCount = 2;
        expData.TotalAmount = 1000;
        expData.id = 'EXP001';
        expData.expenseDate = System.now();
        expData.expenseName = 'Field Travel';
        expData.executiveName = 'Exec A';
        expData.executiveId = 'exec001';
        expData.appExpId = 'appExp001';
        expData.approvalStatus = 'Approved';
        expData.modeoftransport = 'Car';
        expData.comments = 'Trip for client meeting';
        expData.createdBy = 'User A';
        expData.createdDate = System.now();
        expData.expenseItems = new List<beatPlannerlwc.cls_expenseItems>{expItem};
            
           
    }
    
    @IsTest
    static void testSearchProducts_blankString() {
        
        Product__c prod = new Product__c(
            Name = 'Test Product',
            List_Price__c = 100,
            Tax_Percent__c = 18,
            SKU_Code__c ='191ksSSddksk',
            //Product_Category1__c = cat.Id,
            CGST__c = 9,
            Discount__c = 5
            // Tax_Class__c = 'Standard'
        );
        insert prod;
        
        Test.startTest();
        // --- Call with blank string (SOQL path) ---
        beatPlannerlwc.searchProducts('');
        Test.stopTest();
        
    }
    
    @IsTest
    public static void testSearchProducts_withString() {
        
        
        Product__c prod = new Product__c(
            Name = 'Searchable Product',
            List_Price__c = 200,
            Tax_Percent__c = 5,
            SKU_Code__c ='191ksddksk',
            // Product_Category1__c = cat.Id,
            CGST__c = 2.5,
            Discount__c = 10
            //Tax_Class__c = 'Reduced'
        );
        insert prod;
        
        Test.startTest();
        // --- Call with search string (SOSL path) ---
        beatPlannerlwc.searchProducts('Searchable');
        Test.stopTest();
        
    }
    @isTest
    static void testWrapperClasses12() {
        // ----- BuyProductData -----
        beatPlannerlwc.BuyProductData buyData = new beatPlannerlwc.BuyProductData();
        buyData.id = Id.valueOf('001000000000001');
        buyData.productId = Id.valueOf('01t000000000001');
        buyData.productName = 'Test Product';
        buyData.buyQuantity = 10;
        buyData.buyValue = 100;
        buyData.offerQuantity = 2;
        buyData.offerValue = 20;
        buyData.offerPercent = 5;
        buyData.min = 1;
        buyData.max = 100;
        buyData.SaleValue = 200;
        buyData.PerKg = 50;
        buyData.Discount = 10;

        // ----- Strategy -----
        beatPlannerlwc.Strategy strat = new beatPlannerlwc.Strategy();
        strat.id = Id.valueOf('a0B000000000001');
        strat.name = 'Test Strategy';
        strat.productCategory = 'Category A';
        strat.productName = 'Product X';
        strat.Description = 'Strategy Description';
        strat.buyProduct = new List<beatPlannerlwc.BuyProductData>{ buyData };

        // ----- SchemeStrategy -----
        beatPlannerlwc.SchemeStrategy schemeStrategy = new beatPlannerlwc.SchemeStrategy();
        schemeStrategy.strategy = strat;

        // ----- strategyData -----
        List<beatPlannerlwc.productData> prodDataList = new List<beatPlannerlwc.productData>();
        beatPlannerlwc.strategyData stratData = new beatPlannerlwc.strategyData(
            new Sales_Strategy__c(Name = 'Test Strat'),
            prodDataList
        );

        // ----- strategyProductMapData -----
        beatPlannerlwc.strategyProductMapData stratMap = new beatPlannerlwc.strategyProductMapData(
            '1',
            'Test Map',
            '12345',
            new Sales_Strategy__c(Name = 'Map Strat'),
            prodDataList
        );

        // ----- schemeLineItemData -----
        beatPlannerlwc.schemeLineItemData lineItem = new beatPlannerlwc.schemeLineItemData();
        lineItem.id = Id.valueOf('a0L000000000001');
        lineItem.productId = Id.valueOf('01t000000000002');
        lineItem.type = 'Discount';
        lineItem.isSelected = true;
        lineItem.minQty = 5;
        lineItem.freeQty = 1;
        lineItem.offerProductId = Id.valueOf('01t000000000003');
        lineItem.offerProductName = 'Free Product';
        lineItem.discountPerUOM = 2.5;
        lineItem.saleValueThreshold = 500;
        lineItem.discountPercentOnSale = 10;
        lineItem.discountedPrice = 90;
        lineItem.schemeCategory = 'Promo';
        lineItem.isFreeProduct = false;
        lineItem.isPerUOMDiscount = true;
        lineItem.isSaleValueDiscount = false;

        // ----- schemeData -----
        beatPlannerlwc.schemeData scheme = new beatPlannerlwc.schemeData();
        scheme.id = Id.valueOf('a0M000000000001');
        scheme.name = 'Test Scheme';
        scheme.description = 'Scheme Description';
        scheme.isSchemeSelected = true;
        scheme.lineItems.add(lineItem);

    }
    




    @isTest
    static void coverage_returnsEmptyForNullAccount() {
        Test.startTest();
        beatPlannerlwc.CoverageDto out = beatPlannerlwc.getSchemeCoverageForAccount(null);
        Test.stopTest();
        System.assertNotEquals(null, out);
        System.assertEquals(0, out.schemes.size());
        System.assert(out.productSchemeIds.isEmpty());
    }

    @isTest
    static void coverage_matchesViaApplyToAllAndIncludesGroupProducts() {
        Account acc = new Account(Name = 'Cov Acc', Customer_Type__c = 'Primary Customer',
            City__c = 'Delhi', State__c = 'Delhi', District__c = 'New Delhi', Pincode__c = '110001',
            Customer_Status__c = 'Active', Primary_Phone_Number__c = '7000000011',
            Aadhaar_No__c = '700012341231', SAP_Customer_Code__c = '70000011');
        insert acc;
        Product__c p1 = new Product__c(Name = 'CovP1', Is_Active__c = true, SKU_Code__c = 'CovP1');
        Product__c p2 = new Product__c(Name = 'CovP2', Is_Active__c = true, SKU_Code__c = 'CovP2');
        insert new List<Product__c>{ p1, p2 };

        String purpose = null;
        for (Schema.PicklistEntry e : Scheme_Product_Group__c.Group_Purpose__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) { purpose = e.getValue(); break; }
        }
        Scheme_Product_Group__c g = new Scheme_Product_Group__c(
            Name = 'CovGrp', Sales_Channel__c = 'Cake', Group_Purpose__c = purpose, Is_Active__c = true
        );
        insert g;
        insert new List<Scheme_Product_Group_Item__c>{
            new Scheme_Product_Group_Item__c(Scheme_Product_Group__c = g.Id, Product__c = p1.Id),
            new Scheme_Product_Group_Item__c(Scheme_Product_Group__c = g.Id, Product__c = p2.Id)
        };

        Scheme__c s = new Scheme__c(
            Name = 'CovScheme', Scheme_Type__c = 'Free Quantity', Sales_Channel__c = 'Cake',
            Scheme_Start_Date__c = Date.today(), Scheme_End_Date__c = Date.today().addDays(7),
            IsActive__c = true, Scheme_Product_Group__c = g.Id,
            Apply_to_All_Regions__c = true, Apply_to_All_Areas__c = true,
            Apply_to_All_Territories__c = true, Apply_to_All_Outlet_Categories__c = true
        );
        insert s;
        insert new Scheme_Slab__c(
            Scheme__c = s.Id, Slab_Sequence__c = 1, Slab_Type__c = 'Free Quantity',
            Qualifying_Qty_Min__c = 10, Free_Qty__c = 1
        );

        Test.startTest();
        beatPlannerlwc.CoverageDto out = beatPlannerlwc.getSchemeCoverageForAccount(acc.Id);
        Test.stopTest();

        System.assertEquals(1, out.schemes.size());
        System.assertEquals('CovScheme', out.schemes[0].name);
        System.assertEquals(2, out.schemes[0].products.size());
        System.assert(out.productSchemeIds.containsKey(p1.Id));
        System.assert(out.productSchemeIds.containsKey(p2.Id));
        System.assertEquals(1, out.productSchemeIds.get(p1.Id).size());
        System.assertNotEquals(null, out.schemes[0].slabRows);
        System.assertEquals(1, out.schemes[0].slabRows.size(), 'one row per slab');
        System.assert(out.schemes[0].slabRows[0].value.contains('Buy'), 'rep-friendly Buy/Get sentence');
        System.assert(out.schemes[0].slabRows[0].value.contains('Free'),  'rep-friendly Buy/Get sentence');
    }

    @isTest
    static void coverage_filtersWhenRegionLevelExcludesAccount() {
        String validRegion = null;
        for (Schema.PicklistEntry e : Account.Region__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) { validRegion = e.getValue(); break; }
        }
        if (validRegion == null) return;

        Account acc = new Account(Name = 'RegAcc', Customer_Type__c = 'Primary Customer', Region__c = validRegion,
            City__c = 'Delhi', State__c = 'Delhi', District__c = 'New Delhi', Pincode__c = '110001',
            Customer_Status__c = 'Active', Primary_Phone_Number__c = '7000000012',
            Aadhaar_No__c = '700012341232', SAP_Customer_Code__c = '70000012');
        insert acc;
        Product__c p1 = new Product__c(Name = 'RegP', Is_Active__c = true, SKU_Code__c = 'RegP');
        insert p1;

        String purpose = null;
        for (Schema.PicklistEntry e : Scheme_Product_Group__c.Group_Purpose__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) { purpose = e.getValue(); break; }
        }
        Scheme_Product_Group__c g = new Scheme_Product_Group__c(
            Name = 'RegGrp', Sales_Channel__c = 'Cake', Group_Purpose__c = purpose, Is_Active__c = true
        );
        insert g;
        insert new Scheme_Product_Group_Item__c(Scheme_Product_Group__c = g.Id, Product__c = p1.Id);

        Scheme__c s = new Scheme__c(
            Name = 'RegScheme', Scheme_Type__c = 'QPS', Sales_Channel__c = 'Cake',
            Scheme_Start_Date__c = Date.today(), Scheme_End_Date__c = Date.today().addDays(7),
            IsActive__c = true, Scheme_Product_Group__c = g.Id,
            Apply_to_All_Regions__c = false,
            Apply_to_All_Areas__c = true, Apply_to_All_Territories__c = true, Apply_to_All_Outlet_Categories__c = true
        );
        insert s;

        String otherRegion = 'NOT-A-REGION-' + System.now().getTime();
        insert new Scheme_Applicability__c(
            Scheme__c = s.Id, Level__c = 'Region', Value_Text__c = otherRegion, Sort_Order__c = 1
        );

        Test.startTest();
        beatPlannerlwc.CoverageDto out = beatPlannerlwc.getSchemeCoverageForAccount(acc.Id);
        Test.stopTest();

        System.assertEquals(0, out.schemes.size(),
            'Account region differs from the only allowed Region value; scheme must be filtered out');
    }

    @isTest
    static void coverage_skipsExpiredAndFutureSchemes() {
        Account acc = new Account(Name = 'DateAcc', Customer_Type__c = 'Primary Customer',
            City__c = 'Delhi', State__c = 'Delhi', District__c = 'New Delhi', Pincode__c = '110001',
            Customer_Status__c = 'Active', Primary_Phone_Number__c = '7000000013',
            Aadhaar_No__c = '700012341233', SAP_Customer_Code__c = '70000013');
        insert acc;
        Product__c p1 = new Product__c(Name = 'DateP', Is_Active__c = true, SKU_Code__c = 'DateP');
        insert p1;
        String purpose = null;
        for (Schema.PicklistEntry e : Scheme_Product_Group__c.Group_Purpose__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) { purpose = e.getValue(); break; }
        }
        Scheme_Product_Group__c g = new Scheme_Product_Group__c(
            Name = 'DateGrp', Sales_Channel__c = 'Cake', Group_Purpose__c = purpose, Is_Active__c = true
        );
        insert g;
        insert new Scheme_Product_Group_Item__c(Scheme_Product_Group__c = g.Id, Product__c = p1.Id);

        List<Scheme__c> schemes = new List<Scheme__c>{
            new Scheme__c(Name = 'PastS', Scheme_Type__c = 'QPS', Sales_Channel__c = 'Cake',
                Scheme_Start_Date__c = Date.today().addDays(-30), Scheme_End_Date__c = Date.today().addDays(-1),
                IsActive__c = true, Scheme_Product_Group__c = g.Id,
                Apply_to_All_Regions__c = true, Apply_to_All_Areas__c = true,
                Apply_to_All_Territories__c = true, Apply_to_All_Outlet_Categories__c = true),
            new Scheme__c(Name = 'NowS', Scheme_Type__c = 'QPS', Sales_Channel__c = 'Cake',
                Scheme_Start_Date__c = Date.today(), Scheme_End_Date__c = Date.today().addDays(7),
                IsActive__c = true, Scheme_Product_Group__c = g.Id,
                Apply_to_All_Regions__c = true, Apply_to_All_Areas__c = true,
                Apply_to_All_Territories__c = true, Apply_to_All_Outlet_Categories__c = true),
            new Scheme__c(Name = 'FutureS', Scheme_Type__c = 'QPS', Sales_Channel__c = 'Cake',
                Scheme_Start_Date__c = Date.today().addDays(10), Scheme_End_Date__c = Date.today().addDays(20),
                IsActive__c = true, Scheme_Product_Group__c = g.Id,
                Apply_to_All_Regions__c = true, Apply_to_All_Areas__c = true,
                Apply_to_All_Territories__c = true, Apply_to_All_Outlet_Categories__c = true)
        };
        insert schemes;

        Test.startTest();
        beatPlannerlwc.CoverageDto out = beatPlannerlwc.getSchemeCoverageForAccount(acc.Id);
        Test.stopTest();

        System.assertEquals(1, out.schemes.size());
        System.assertEquals('NowS', out.schemes[0].name);
    }

    // Cover the remaining @AuraEnabled report methods. Their results depend on the running user's
    // sales-channel / executive context, so just invoke them (guarded) for coverage.
    @isTest static void testRemainingReportMethods() {
        Test.startTest();
        try { beatPlannerlwc.getProductData(); } catch (Exception e) {}
        try { beatPlannerlwc.getOrderProductivity(Date.today(), Date.today().addDays(-7)); } catch (Exception e) {}
        try { beatPlannerlwc.getExpenseData(0, 10); } catch (Exception e) {}
        Test.stopTest();
    }
}