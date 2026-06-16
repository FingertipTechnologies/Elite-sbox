@RestResource(urlMapping='/apis/*')
global with sharing class beatPlannerlwc {
    
    /**Myvisit beatPlannerLwc Data **/
    /* Daily log data */
    @AuraEnabled(cacheable=false)
    global static data getDailyLog(){
        data db = new data();
        List<Daily_Log__c> clockinClockout = [SELECT Id,User__c,Todays_Plan__c,Colleague_Name__c,With_Companion__c,Mode_of_transport__c,
                                              Vehicle_Used__c,Clock_In_Location__Latitude__s,Clock_In_Location__Longitude__s,
                                              Clock_Out_Location__Latitude__s,Clock_Out_Location__Longitude__s,Day_started_time__c,
                                              Day_ended_time__c,Travel_Type__c,Purpose_of_Visit__c,Start_Day_Odometer_Reading_KM__c,
                                              Beat_Switch_History__c,Current_Beat__c,Comments__c from  Daily_Log__c  WHERE
                                              Day_started_time__c = TODAY AND OwnerId =:UserInfo.getUserId()  ORDER BY createddate desc limit 1]; 
        if(clockinClockout.size() != 0){
            db.dailyLog = clockinClockout[0];
        }
        
        User currentUser = [SELECT Id,Name,Is_SSA_DSM__c,Is_Promoter__c,Profile.Name FROM User WHERE Id = :UserInfo.getUserId()];
        db.currentUser = currentUser;
        // Query Custom Metadata records for Employee_Creation_Access__mdt
        List<Employee_Creation_Access__mdt> metadataRecordsList = [
            SELECT Show_Reportee_View__c
            FROM Employee_Creation_Access__mdt where Label =:currentUser.Profile.Name
            ORDER BY Hierarchy_Number__c ASC
        ];
        db.showRepoteeView = !metadataRecordsList.isEmpty() ? metadataRecordsList[0].Show_Reportee_View__c : false;
        db.travelType = extractPicklistValues('Daily_Log__c','Travel_Type__c'); 
        db.vehicleUsed = extractPicklistValues('Daily_Log__c','Vehicle_Used__c'); 
        db.purposeofVisit = extractPicklistValues('Daily_Log__c','Purpose_of_Visit__c'); 
        List<Leaves__c> lv = [
            SELECT Id, Name
            FROM Leaves__c
            WHERE From_Date__c <= TODAY
            AND To_Date__c >= TODAY
            AND ApprovalStatus__c IN ('Leave Approved','Submitted for Approval','Not Submitted')
            AND Leave_Cancellation_Status__c != 'Submitted for Cancellation' 
            AND Session_Type__c = null 
            AND OwnerId = :UserInfo.getUserId()
        ];
        
        db.isLeaveExisted = !lv.isEmpty();
        
        List<Employee_Creation_Access__mdt> metaList = [
            SELECT Id, DeveloperName, Allow_Mobile_Access__c, Allow_Desktop_Access__c
            FROM Employee_Creation_Access__mdt where Label =:currentUser.Profile.Name Limit 1
        ];
        
        db.isDesktopAllowed = !metaList.isEmpty() ? metaList[0].Allow_Desktop_Access__c : false;
        db.isMobileAllowed = !metaList.isEmpty() ?  metaList[0].Allow_Mobile_Access__c :false;
        return db;
    }
    @AuraEnabled
    public static void updateDocument(List<String> idList, string uniqueId){
        system.debug('uniqueId'+uniqueId);
        list<ContentVersion> versionlist = [SELECT Id, Title,Description FROM ContentVersion WHERE ContentDocumentId IN :idList ORDER BY CreatedDate];
        if(uniqueId != null && uniqueId != '')
        {
            for(integer i=0;i<versionlist.size();i++){
                versionlist[i].Description = uniqueId;
            }
            update versionlist;
        }
    }
    @AuraEnabled  
    public static List<ContentDocument> getFiles(string uniqueId){ 
        return [SELECT Id, Title, FileType,SystemModStamp FROM ContentDocument 
                WHERE Id IN (SELECT ContentDocumentId FROM ContentVersion WHERE Description = :uniqueId)
                AND ContentAssetId = null]; 
    } 
    @AuraEnabled  
    public static void deleteFile(String contentDocumentId){ 
        delete [SELECT Id from ContentDocument WHERE Id = :contentDocumentId];       
    }
    @AuraEnabled
    public static String validateFileUpload(String uniqueFileId) {
        // Query ContentDocuments using Description (mapped to unique ID)
        List<ContentDocument> uploadedDocs =  [SELECT Id, Title, FileType,SystemModStamp FROM ContentDocument 
                                               WHERE Id IN (SELECT ContentDocumentId FROM ContentVersion WHERE Description = :uniqueFileId)
                                               AND ContentAssetId = null]; 
        return !uploadedDocs.isEmpty() ? 'Success' : 'Upload needed';
    }
    //Save Daily log 
    @AuraEnabled
    public static dailyLogBox upsertDailyLog(Daily_Log__c dailylog,string operation){ 
        system.debug(dailylog);
        String success = 'false';
        string currentUserId = UserInfo.getUserId();
        if(dailylog !=null ){
            system.debug('StatrtTime'+dailylog.Day_started_time__c );
            system.debug('system.today()'+system.today() );
            Date dailylogDate = dailylog.Day_started_time__c.date();
            if(dailylogDate == system.today())
            {
                
                Daily_Log__c dlNew = new  Daily_Log__c();
                try {
                    dlNew = [SELECT Id, Day_started_time__c,Day_ended_time__c FROM Daily_Log__c WHERE 
                             Day_started_time__c = TODAY AND OwnerId = :currentUserId LIMIT 1];
                } 
                catch (QueryException e) {
                    dlNew = null;
                }
                
                if(operation == 'Startday' && dlNew != null )
                {
                    success ='daystarted';
                }
                else if(operation == 'EndDay' && dlNew != null && dlNew.Day_ended_time__c !=null)
                {
                    success ='endstarted';
                }
                else
                {
                    
                    if(operation == 'Startday')
                    {
                        
                        //Why we are adding the time from apex if user system
                        // time is worng it will take user system time only
                        dailylog.Day_started_time__c = System.now();
                        
                    }
                    else if(operation == 'EndDay')
                    {
                        dailylog.Day_ended_time__c = System.now();
                    }
                    upsert dailylog;
                    success ='true';
               
                }
                
                
                
            } 
        }
        dailyLogBox dgbox = new dailyLogBox();
        
        Daily_Log__c dl = [SELECT Id,User__c,Clock_In_Location__Latitude__s,Clock_In_Location__Longitude__s,
                           Clock_Out_Location__Latitude__s,Clock_Out_Location__Longitude__s,Day_started_time__c,
                           Day_ended_time__c,Travel_Type__c,Purpose_of_Visit__c,Start_Day_Odometer_Reading_KM__c,
                           Comments__c,Beat_Switch_History__c,Current_Beat__c,Vehicle_Used__c from  Daily_Log__c  WHERE
                           Day_started_time__c = TODAY AND OwnerId =:currentUserId  ORDER BY createddate desc limit 1];
        
        if(dl != null)
        {
            dgbox.Dailylog= dl;
        }
        else
        {
            dgbox.Dailylog= null;
        }
        dgbox.IsSuccess=success;
        
        
        
        list<Daily_Log__c> yesterdayLogList = [select id from Daily_Log__c where Day_started_time__c = YESTERDAY AND OwnerId =:currentUserId limit 1];
        if(!yesterdayLogList.isEmpty())
        {
            list<Expenses_Line_Item__c> expLineItemList = [select id from Expenses_Line_Item__c where Daily_Log__c =: yesterdayLogList[0].Id limit 1];
            if(expLineItemList.isEmpty())
            {
                CustomNotificationType notificationType = [
                    SELECT Id FROM CustomNotificationType  WHERE DeveloperName = 'Expense_Approval_Notification' LIMIT 1
                ];
                string loggedInUserId = UserInfo.getUserId();
                user currentUser = [select Id,Name,Profile.Name from User where Id =:loggedInUserId ];
                // ---- Notification for Owner----
                CustomNotificationService.notificationSendPageRef(
                    'Reminder: Pending Expense Entry', 
                    'Your expense entry for yesterday is pending. Please submit it at the earliest',
                    new Set<String>{ loggedInUserId }, 
                    notificationType.Id
                );
            }
        }
        
        return dgbox;
    }
    
    /*New visit popup */
    @AuraEnabled
    global static data getVisitCreateData(){
        data db = new data();
        db.visitTypes = extractPicklistValues('Visit__c','Visit_for__c'); 
        db.primaryCustomers = [SELECT Id,Name,City__c,Customer_Type__c,Customer_Preference__c from account WHERE 
                               Customer_Type__c = 'Primary Customer' and Customer_Status__c ='Active'];
        db.secoundaryCustomers = [SELECT Id,City__c,Name,Customer_Type__c,Customer_Preference__c,State__c 
                                  from account WHERE  Customer_Type__c = 'Secondary Customer' and Customer_Status__c ='Active'];
        return db;
    }
    
    /**Outlet screen 2 data **/
    //Get Visit data
    @AuraEnabled
    global static data getVisitData(string currentBeatId){
        data dta = new data();
        
        string currentUserId = UserInfo.getUserId();
        User us = [select Id,Name,Is_SSA_DSM__c from User where Id =:currentUserId];
        List<Daily_Log__c> dailyLog = [SELECT Id,Name,User__c,Sales_App_id__c,Day_ended_time__c,PJP_Item__c
                                       from  Daily_Log__c  WHERE Day_started_time__c = TODAY
                                       AND OwnerId =:currentUserId  ORDER BY createddate desc limit 1]; 
        
        List<visitData> visdata = new List<visitData>();
        map<String,String> beatItemVisitMap = new map<String,String>();
        boolean isPrimaryCustomerVisitExisted = false;
        boolean isSubstockiesBeatExisted = false;
        if(string.isNotBlank(currentBeatId))
        {
            //Getting the existing Visits Data
            List<Visit__c> vs = [SELECT id, Name, createdDate, AccountName__c, Actual_End_Time__c, Actual_Start_Time__c, Beat__c, Beat_Name__c,
                                 App_visitPlan_Id__c, Beat__r.Name,Status__c,  Missed_PostPone_Reason__c,  Visit_Date__c,Sales_App_ID__c,
                                 Visit_for__c,Clockin_Date__c, Clockout_Date__c, Account1__c, Account1__r.Name, Daily_Log__r.Name, Daily_Log__c,
                                 Dealer__c, Dealer__r.Name, Miss_visit__c, PostPoned__c, Total_Travel_Distance__c, Type_of_Visit__c,
                                 Vehicle_Used__c, Distributor__c, Distributor__r.Name, Other_Visit__c, Companion_name__c, Account1__r.Outstanding__c,
                                 Companion_name__r.Name, Lead__c, Lead__r.Name, Opportunity__c, Opportunity__r.Name, CheckedInLongitude__c,
                                 CheckedInLatitude__c,Comments__c, Planned_End_Time__c, Planned_Start_Time__c, Daily_log__r.Sales_App_id__c,
                                 Account1__r.accountId__c,ClockIn_Latitude__c,Clockin_Longitude__c,Clockout_Latitude__c,Clockout_Longitude__c,
                                 Account1__r.GeoLocation__c,Is_Substockist_VIsit__c,
                                 Approval_Status__c,Beat_Item__c,PJP_Item__c,Location_Type__c FROM Visit__c WHERE OwnerId = :userinfo.getUserId()
                                 AND Visit_Date__c = TODAY AND  Approval_Status__c ='Approved' and Child_beat__c =: currentBeatId AND
                                 PJP_Item__c =:dailyLog[0].PJP_Item__c
                                 ORDER BY status__c asc, createddate desc 
                                ];
            for(Visit__c vis : vs){
                String formattedVisitDate = vis.Visit_Date__c != null ? DateTime.newInstance(vis.Visit_Date__c.year(), vis.Visit_Date__c.month(), vis.Visit_Date__c.day()).format('dd/MM/yyyy') : 
                DateTime.newInstance(vis.Planned_Start_Time__c.year(), vis.Planned_Start_Time__c.month(), vis.Planned_Start_Time__c.day()).format('dd/MM/yyyy') ;
                String formattedActualStartDateTime = vis.Actual_Start_Time__c != null 
                    ? DateTime.newInstance(vis.Actual_Start_Time__c.year(), vis.Actual_Start_Time__c.month(), vis.Actual_Start_Time__c.day(),
                                           vis.Actual_Start_Time__c.hour(), vis.Actual_Start_Time__c.minute(),0).format('dd/MM/yyyy HH:mm:') : '';
                String formattedActualEndDateTime = vis.Actual_End_Time__c != null 
                    ? DateTime.newInstance(vis.Actual_End_Time__c.year(), vis.Actual_End_Time__c.month(), vis.Actual_End_Time__c.day(),
                                           vis.Actual_End_Time__c.hour(), vis.Actual_End_Time__c.minute(),0).format('dd/MM/yyyy HH:mm') : '';
                visitData ad = new visitData();
                ad.id = vis.Id;
                ad.approvalStatus = vis.Approval_Status__c;
                ad.actualStartDateTimeString = formattedActualStartDateTime;
                ad.actualEndtDateTimeString = formattedActualEndDateTime;
                ad.Name = vis.Name;
                ad.salesAppId = vis.Sales_App_ID__c;
                if(vis.Account1__c != null){
                    ad.acccountId=vis.Account1__c;
                    ad.accountName = vis.Account1__r.Name;
                }
                ad.appAccountId=vis.Account1__r.accountId__c;
                ad.dailyLogName =vis.Daily_log__r.Name;
                ad.dailyLogId=vis.Daily_log__c;
                ad.dailylogAppId=vis.Daily_log__r.Sales_App_id__c;
                ad.plannedStartTime=vis.Planned_Start_Time__c;
                ad.plannedEndTime=vis.Planned_End_Time__c;
                ad.actualStartTime=vis.Actual_Start_Time__c;
                ad.actualEndTime=vis.Actual_End_Time__c;
                ad.comments=vis.Comments__c;
                ad.typeofVisit=vis.Type_of_Visit__c;
                ad.missedReason = vis.Missed_PostPone_Reason__c;
                ad.status=vis.Status__c;
                ad.appVisitPlanId=vis.App_visitPlan_Id__c;
                ad.visitPlanId=vis.Beat__c;
                ad.visitPlanName=vis.Beat__r.Name;
                ad.outstanding=vis.Account1__r.Outstanding__c;
                ad.checkinlatti = vis.CheckedInLatitude__c; 
                ad.checkinlongi = vis.CheckedInLongitude__c;
                ad.createdDate = vis.createdDate;
                ad.lastVisitComment='';
                ad.lastvisitorder=0;
                ad.VisitDate = vis.Visit_Date__c;
                ad.formattedVisitDate = formattedVisitDate;
                ad.ClockInLatitude = vis.ClockIn_Latitude__c;
                ad.ClockinLongitude = vis.Clockin_Longitude__c;
                ad.ClockoutLatitude = vis.Clockout_Latitude__c;
                if(vis.Account1__r.GeoLocation__c != null){
                    ad.customerLocationLattitude = vis.Account1__r.GeoLocation__c.getLatitude();
                    ad.customerLocationLongitude = vis.Account1__r.GeoLocation__c.getLongitude();
                }
                ad.ClockoutLongitude = vis.Clockout_Longitude__c;system.debug('visitfor: '+vis.Visit_for__c);
                ad.visitTypes = vis.Visit_for__c;
                ad.beatItemId =vis.Beat_Item__c;  
                ad.pjpItemId = vis.PJP_Item__c;
                ad.inLocation = vis.Location_Type__c == 'In Location' ? true : false;
                visdata.add(ad);
                if(vis.Account1__c != null && vis.Beat_Item__c != null ){
                    beatItemVisitMap.put(vis.Beat_Item__c,vis.Account1__c); 
                }  
                if(vis.Visit_for__c == 'Primary Customer' )
                {
                    isPrimaryCustomerVisitExisted = true;
                }
                if(vis.Is_Substockist_VIsit__c)
                {
                    isSubstockiesBeatExisted = true;
                }
            }
            Set<Id> allAccountIds = new Set<Id>();
            
            //Get the current beat and it's Primary customer and substockiest
            list<Child_beat__c> currentBeat = [select Id,Primary_Customer__c,Sub_Stockist__c,Primary_Customer__r.Name,
                                               Primary_Customer__r.Customer_Type__c,Primary_Customer__r.Outstanding__c,
                                               Primary_Customer__r.GeoLocation__c,Sub_Stockist__r.Name,Sub_Stockist__r.Customer_Type__c,
                                               Sub_Stockist__r.Outstanding__c,Sub_Stockist__r.GeoLocation__c
                                               from Child_beat__c where Id =:currentBeatId];
            
            if(currentBeat[0].Sub_Stockist__c != null){
                allAccountIds.add(currentBeat[0].Sub_Stockist__c);
            }
            if(currentBeat[0].Primary_Customer__c != null){
                allAccountIds.add(currentBeat[0].Primary_Customer__c);
            }  
            
            //Getting the customer data from beat Items
            list<Junction_Beat__c> beatItems = [select Id,Name,Account__c,Account__r.Name,Account__r.accountId__c,Account__r.Customer_Type__c,
                                                Account__r.GeoLocation__c,
                                                Account__r.Outstanding__c,Child_Beat__r.Sub_Stockist__c,Child_Beat__r.Sub_Stockist__r.Name,
                                                Child_Beat__r.Sub_Stockist__r.Customer_Type__c,Child_Beat__r.Sub_Stockist__r.GeoLocation__c,
                                                Child_Beat__r.Sub_Stockist__r.Outstanding__c,
                                                Child_Beat__r.Primary_Customer__c,Child_Beat__r.Primary_Customer__r.Name,
                                                Child_Beat__r.Primary_Customer__r.Customer_Type__c,
                                                Child_Beat__r.Primary_Customer__r.GeoLocation__c,
                                                Child_Beat__r.Primary_Customer__r.Outstanding__c from Junction_Beat__c where 
                                                Child_beat__c =: currentBeatId and Active__c = true
                                                order by Order_Number__c ASC]; 
            
            if(!beatItems.isEmpty())
            {
                // Step 1: Get all Account Ids from beatItems
                for (Junction_Beat__c bItem : beatItems) {
                    if (bItem.Account__c != null) {
                        allAccountIds.add(bItem.Account__c);
                    }
                }
            }   
            
            List<Account> accessibleAccounts = [
                SELECT Id FROM Account  WHERE Id IN :allAccountIds AND
                ((Customer_Type__c = 'Primary Customer' AND Customer_Status__c = 'Active')
                 Or (Customer_Type__c ='Secondary Customer' AND Customer_Status__c = 'Active'))
            ];
            if(!accessibleAccounts.isEmpty())
            {
                Set<Id> accessibleAccountIds = new Set<Id>();
                for (Account acc : accessibleAccounts) {
                    accessibleAccountIds.add(acc.Id);
                }
                String formattedVisitDate = DateTime.newInstance( Date.today().year(), Date.today().month(),  Date.today().day()).format('dd/MM/yyyy'); 
                
                // -----------------------
                //Primary Customer of this Beat
                // -----------------------
                if(!currentBeat.isEmpty() && currentBeat[0].Primary_Customer__c != null && !isPrimaryCustomerVisitExisted && !us.Is_SSA_DSM__c && accessibleAccountIds.contains(currentBeat[0].Primary_Customer__c)){
                    system.debug('Enteredd---------------------------');
                    visitData ad = new visitData();
                    ad.id = null;
                    ad.pjpItemId = dailyLog[0].PJP_Item__c;
                    ad.approvalStatus = 'Approved';
                    if(beatItems[0].Account__c != null){
                        ad.acccountId= currentBeat[0].Primary_Customer__c;
                        ad.accountName = currentBeat[0].Primary_Customer__r.Name;
                        ad.typeofVisit= currentBeat[0].Primary_Customer__r.Customer_Type__c;
                        ad.visitTypes = currentBeat[0].Primary_Customer__r.Customer_Type__c;
                    }
                    if(!dailyLog.isEmpty())
                    {
                        ad.dailyLogName =dailyLog[0].Name;
                        ad.dailyLogId=dailyLog[0].Id;   
                    }
                    ad.plannedStartTime= Date.today();
                    ad.status='Planned';
                    ad.visitPlanId=currentBeatId;
                    ad.outstanding= currentBeat[0].Primary_Customer__r.Outstanding__c;
                    ad.createdDate =  Date.today();
                    ad.lastvisitorder = 0;
                    ad.VisitDate =  Date.today();
                    ad.formattedVisitDate = formattedVisitDate; 
                    if(currentBeat[0].Primary_Customer__r.GeoLocation__c != null){
                        ad.customerLocationLattitude = currentBeat[0].Primary_Customer__r.GeoLocation__c.getLatitude();
                        ad.customerLocationLongitude = currentBeat[0].Primary_Customer__r.GeoLocation__c.getLongitude();
                    }
                    
                    visdata.add(ad);
                }
                
                // -----------------------
                //Sub stockiest of this Beat
                // -----------------------
                if( !currentBeat.isEmpty() &&  currentBeat[0].Sub_Stockist__c != null && !isSubstockiesBeatExisted &&
                   accessibleAccountIds.contains(currentBeat[0].Sub_Stockist__c)){
                       visitData ad = new visitData();
                       ad.id = null;
                       ad.pjpItemId = dailyLog[0].PJP_Item__c;
                       ad.approvalStatus = 'Approved';
                       if(beatItems[0].Account__c != null){
                           ad.acccountId= currentBeat[0].Sub_Stockist__c;
                           ad.accountName = currentBeat[0].Sub_Stockist__r.Name;
                           ad.typeofVisit= currentBeat[0].Sub_Stockist__r.Customer_Type__c;
                           ad.visitTypes = currentBeat[0].Sub_Stockist__r.Customer_Type__c;
                       }
                       if(!dailyLog.isEmpty())
                       {
                           ad.dailyLogName =dailyLog[0].Name;
                           ad.dailyLogId=dailyLog[0].Id;   
                       }
                       ad.plannedStartTime= Date.today();
                       ad.status='Planned';
                       ad.visitPlanId=currentBeatId;
                       ad.outstanding= currentBeat[0].Sub_Stockist__r.Outstanding__c;
                       ad.createdDate =  Date.today();
                       ad.lastvisitorder = 0;
                       ad.VisitDate =  Date.today();
                       ad.formattedVisitDate = formattedVisitDate; 
                       if(currentBeat[0].Sub_Stockist__r.GeoLocation__c != null){
                           ad.customerLocationLattitude = currentBeat[0].Sub_Stockist__r.GeoLocation__c.getLatitude();
                           ad.customerLocationLongitude = currentBeat[0].Sub_Stockist__r.GeoLocation__c.getLongitude();
                       }
                       
                       visdata.add(ad);
                   }
                
                // -----------------------
                //Beat Items
                // -----------------------
                if(!beatItems.isEmpty())
                {
                    for(Junction_Beat__c bItem :beatItems)
                    {
                        if(!beatItemVisitMap.containskey(bItem.Id) && bItem.Account__c != null && accessibleAccountIds.contains(bItem.Account__c))
                        {
                            visitData ad = new visitData();
                            ad.id = null;
                            ad.beatItemId = bItem.Id;
                            ad.pjpItemId = dailyLog[0].PJP_Item__c;
                            ad.approvalStatus = 'Approved';
                            if(bItem.Account__c != null){
                                ad.acccountId=bItem.Account__c;
                                ad.accountName = bItem.Account__r.Name;
                                ad.typeofVisit=bItem.Account__r.Customer_Type__c;
                                ad.visitTypes = bItem.Account__r.Customer_Type__c;
                            }
                            if(!dailyLog.isEmpty())
                            {
                                ad.dailyLogName =dailyLog[0].Name;
                                ad.dailyLogId=dailyLog[0].Id;   
                            }
                            ad.plannedStartTime= Date.today();
                            ad.status='Planned';
                            ad.visitPlanId=currentBeatId;
                            ad.outstanding=bItem.Account__r.Outstanding__c;
                            ad.createdDate =  Date.today();
                            ad.lastvisitorder = 0;
                            ad.VisitDate =  Date.today();
                            ad.formattedVisitDate = formattedVisitDate; 
                            if(bItem.Account__r.GeoLocation__c != null){
                                ad.customerLocationLattitude = bItem.Account__r.GeoLocation__c.getLatitude();
                                ad.customerLocationLongitude = bItem.Account__r.GeoLocation__c.getLongitude();
                            }
                            
                            visdata.add(ad);
                            
                        }
                    }
                }
            }
            
            
            
        }
        dta.visit = visdata;
        List<Leaves__c> lv = [
            SELECT Id, Name
            FROM Leaves__c
            WHERE From_Date__c <= TODAY
            AND To_Date__c >= TODAY
            AND ApprovalStatus__c IN ('Leave Approved','Submitted for Approval','Not Submitted')
            AND Leave_Cancellation_Status__c != 'Submitted for Cancellation' 
            AND Session_Type__c = null 
            AND OwnerId = :UserInfo.getUserId()
        ];
        
        dta.isLeaveExisted = !lv.isEmpty();
        dta.isDayStarted = !dailyLog.isEmpty() && dailyLog[0].Day_ended_time__c == null; 
        return dta;
    }
    //Preview Beat Customers
    @AuraEnabled
    public static list<Account> getPreviewBeatCustomers(string beatId)
    {
        //Getting the customer data from beat Items
        list<Junction_Beat__c> beatItems = [select Id,Name,Account__c,Account__r.Name,Account__r.accountId__c,Account__r.Customer_Type__c,
                                            Account__r.Outstanding__c,Order_Number__c,Child_beat__r.Sub_Stockist__c from Junction_Beat__c where  Child_beat__c =: beatId
                                            order by Order_Number__c ASC]; 
        Set<Id> allAccountIds = new Set<Id>();
        for (Junction_Beat__c bItem : beatItems) {
            if (bItem.Account__c != null) {
                allAccountIds.add(bItem.Account__c);
            }
            if(bItem.Child_beat__r.Sub_Stockist__c != null){
                allAccountIds.add(bItem.Child_beat__r.Sub_Stockist__c);
            }
        }
        List<Account> AccountList = [SELECT Id,Name,SAP_Customer_Code__c,Customer_Type__c,Street__c FROM Account WHERE Id IN :allAccountIds];
        return AccountList;
        
    }
    
    /**Start Visit **/
    @AuraEnabled
    public static List<ContentDocument> getVisitFiles(String uniqueId) {
        return [SELECT Id, Title, FileType,SystemModStamp FROM ContentDocument 
                WHERE Id IN (SELECT ContentDocumentId FROM ContentVersion WHERE Description = :uniqueId)
                AND ContentAssetId = null]; 
    }
    @AuraEnabled
    public static String validateVisitFileUpload(String uniqueId) {
        List<ContentDocument> contentDocuments = [SELECT Id FROM ContentDocument  WHERE Id IN
                                                  (SELECT ContentDocumentId FROM ContentVersion WHERE Description = :uniqueId ) 
                                                  AND ContentAssetId = NULL LIMIT 1 ];
        return !contentDocuments.isEmpty() ? 'Success' : 'Upload needed';
        
    }
    @AuraEnabled
    public static Boolean getGeoFencing(String accountId, Decimal visitLat, Decimal visitLon) { 
        
        Boolean isWithinRange = true;
        
        if (String.isNotBlank(accountId)) {
            List<Account> accountList = [
                SELECT Id, GeoLocation__Latitude__s, GeoLocation__Longitude__s 
                FROM Account 
                WHERE Id = :accountId
            ];
            
            if (!accountList.isEmpty()) {
                Decimal storeLat = accountList[0].GeoLocation__Latitude__s;
                Decimal storeLon = accountList[0].GeoLocation__Longitude__s;
                
                if (storeLat != null && storeLon != null) {
                    Decimal radStoreLat = Math.PI / 180 * storeLat;
                    Decimal radStoreLon = Math.PI / 180 * storeLon;
                    Decimal radVisitLat = Math.PI / 180 * visitLat;
                    Decimal radVisitLon = Math.PI / 180 * visitLon;
                    
                    Decimal dLat = radVisitLat - radStoreLat;
                    Decimal dLon = radVisitLon - radStoreLon;
                    
                    Decimal a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                        Math.cos(radStoreLat) * Math.cos(radVisitLat) *
                        Math.sin(dLon / 2) * Math.sin(dLon / 2);
                    
                    Decimal c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
                    Decimal earthRadius = 6371000; // in meters
                    Decimal distance = earthRadius * c;
                    
                    System.debug('Calculated Distance (meters): ' + distance);
                    
                    Decimal geoFencingInMeters = 100;
                    
                    if (String.isNotBlank(Label.geoFencingInMeters)) {
                        geoFencingInMeters = Decimal.valueOf(Label.geoFencingInMeters);
                    }
                    
                    if (distance > geoFencingInMeters) {
                        isWithinRange = false;
                    }
                }
                else
                {
                    accountList[0].GeoLocation__Latitude__s = visitLat;
                    accountList[0].GeoLocation__Longitude__s = visitLon;
                    database.update(accountList,false);
                }
            }
        }
        
        return isWithinRange;
    }
    
    /**Complete Visit **/
    @AuraEnabled
    public static Visit__c completeVisit(Visit__c visitData, String beatId) {
        system.debug('visitData'+visitData);
        system.debug('beatId'+beatId);
        // Check for related Order__c records
        List<Order__c> orders = [
            SELECT Id
            FROM Order__c
            WHERE Visit__c = :visitData.Id
            LIMIT 1
        ];
        List<Visit__c> previousVisits = [
            SELECT Id, CreatedDate
            FROM Visit__c
            WHERE OwnerId = :UserInfo.getUserId()
            AND Id != :visitData.Id
            AND CreatedDate = TODAY
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        Boolean hasOrder = !orders.isEmpty();
        
        String result;
        if (hasOrder) {
            result = 'PJP Successful';
        } else {
            result = 'PJP Unsuccessful'; 
        }
        visitData.Visit_Output__c = result;
        if(!previousVisits.isEmpty())
        {
            visitData.Previous_Visit__c = previousVisits[0].Id;
        }
        update visitData;
        return visitData;
    }
    /**Validate Competitor to Complete Visit **/
    @AuraEnabled
    global static list<Competition__c> getComptitionData(string visitId){ 
        return [select Id from Competition__c where 	Visit__c =:visitId];
    }
    
    
    /*Executive screen 3 data*/
    @AuraEnabled
    global static data getAllVisitData(string recordId){
        data dt = new data();
        visit__c vs = [select id, Visit_for__c,Status__c,Lead__c,Distributor__c,Dealer__c,Account1__c,Daily_Log__c 
                       from visit__c where id=:recordId];
        string ids;
        List<Visit__c> allVisit = new List<Visit__c>();
        
        //Dear Stock Indication and Visit Count for Month
        if(vs.Visit_for__c == 'Primary Customer' || vs.Visit_for__c == 'Secondary Customer'){
            ids = vs.Account1__c;
            allVisit = [select id from Visit__c where Account1__c =:ids and CreatedDate = This_Month];
            Date firstDayOfMonth;
            Date lastDayOfMonth;
            DateTime endDate;
            Integer currentDay = Date.today().day();
          
            if (vs.Visit_for__c == 'Primary Customer') {
                if (currentDay == 1) {
                    // On the 1st, check for *last month's* stock entry
                    Date today = Date.today();
                    Date lastMonth = today.addMonths(-1);
                    firstDayOfMonth = lastMonth.toStartOfMonth();
                    lastDayOfMonth = lastMonth.toStartOfMonth().addMonths(1).addDays(-1);
                    endDate = DateTime.newInstance(lastDayOfMonth, Time.newInstance(23, 59, 59, 999));
                } else if (currentDay >= 25) {
                    // From 25th to end of month, check *current month's* stock entry
                    firstDayOfMonth = Date.today().toStartOfMonth();
                    endDate = System.now();
                }
                
                if (firstDayOfMonth != null && endDate != null) {
                    List<Dealer_Stock__c> currentMonthDealerStock = [
                        SELECT Id 
                        FROM Dealer_Stock__c 
                        WHERE Store__c = :ids
                        AND CreatedDate >= :firstDayOfMonth 
                        AND CreatedDate <= :endDate 
                        LIMIT 1
                    ];
                    
                    dt.currentMonthStockExisted = !currentMonthDealerStock.isEmpty();
                    
                    
                }
            }
            else
            {
                list<Product_Mapping__c> secondaryMapping = new list<Product_Mapping__c>();
                secondaryMapping = [Select Id,Name,Primary_Customer__c from Product_Mapping__c where Customer__c =:ids And Exectuive__c =: userInfo.getUserId() AND Primary_Customer__c != null limit 1];
                if(secondaryMapping.isEmpty())
                {
                    secondaryMapping = [Select Id,Name,Primary_Customer__c from Product_Mapping__c where Customer__c =:ids AND Primary_Customer__c != null  limit 1];
                }
                dt.primaryCustmerId = !secondaryMapping.isEmpty() && String.isNotBlank(secondaryMapping[0].Primary_Customer__c)
                    ? secondaryMapping[0].Primary_Customer__c
                    : null;
                   system.debug(' dt.secondaryMapping==>'+secondaryMapping);
                system.debug(' dt.primaryCustmerId==>'+ dt.primaryCustmerId);
                dt.currentMonthStockExisted = true;
            }
            
        }
        
        //Bussiness Summary
        List<Invoice__c> inv = new List<Invoice__c>();
        List<Sale__c> sales = new List<Sale__c>();
        List<Order__c> allOrders = new List<Order__c>();
        List<Return__c> allRetunrs = new List<Return__c>();
        Decimal totalOrderAmt = 0, totalSalesAmt = 0, totalSumOutStanding = 0, totalReturnAmount = 0, totalReturnQty =0;
        
        if(ids != null){
            inv = [Select id, name,Grand_Total__c from Invoice__c where Store__c =: ids];
            sales = [Select id, Total_Amount__c from Sale__c where Account__c =: ids];
            allOrders = [SELECT  Id, Name,Account__r.Name,
                         Order_Type__c, Order_Fulfillment_Status__c, 
                         Grand_Total__c FROM Order__c WHERE Account__c = :ids
                         and CreatedDate = This_Month];
            
            allRetunrs = [select Id,Name,Total_Amount__c,Total_Quantity__c,Return_Date__c from 
                         Return__c where Customer__c =:ids AND Return_Date__c = This_Month ];
        }
        
        if(!sales.isEmpty()){
            for(Sale__c sl: sales){
                Decimal sum = (sl.Total_Amount__c != null) ? sl.Total_Amount__c : 0;
                totalSalesAmt = totalSalesAmt + sum;
            }
        }
        if(!allOrders.isEmpty()){
            for(Order__c o:allOrders){
                Decimal sum = (o.Grand_Total__c != null) ? o.Grand_Total__c : 0;
                totalOrderAmt = totalOrderAmt + sum;
            }
        }
        if(!inv.isEmpty()){
            for(Invoice__c Invoice:inv){
                Decimal sum = (invoice.Grand_Total__c != null) ? invoice.Grand_Total__c : 0;
                totalSumOutStanding = totalSumOutStanding + sum;
            }
        }
        if(!allRetunrs.isEmpty())
        {
            for(Return__c ret:allRetunrs){
                Decimal amt = (ret.Total_Amount__c != null) ? ret.Total_Amount__c : 0;
                Decimal qty = (ret.Total_Quantity__c != null) ? ret.Total_Quantity__c : 0;
                totalReturnAmount = totalReturnAmount + amt;
                totalReturnQty = totalReturnQty + qty;
            }
        }
        
        dt.totalOutStanding = totalSumOutStanding; 
        dt.totalOrderAmt = totalOrderAmt; 
        dt.totalSalesAmt = totalSalesAmt;
        dt.totalReturnQty = totalReturnQty; 
        dt.totalReturnAmount = totalReturnAmount;
        dt.AllVisit = (!allVisit.isEmpty()) ? allVisit.size() : 0;
        
        //Summary Expand Collapse
        dt.currentMonthStockExisted = true;
        List<Order__c> ordList = [SELECT Id,Name,Grand_Total__c,Total_Quantity__c FROM Order__c WHERE Visit__c = :recordId];
        List<Order__c> unfulfilledOrders = [SELECT Id, Name,Account__r.Name,Order_Type__c,
                                            Order_Fulfillment_Status__c, Grand_Total__c FROM Order__c WHERE Order_Fulfillment_visit__c = :recordId];
        dt.orderList = ordList;
        if (!ordList.isEmpty()) {
            // Extract Order__c Ids
            List<Id> orderIds = new List<Id>();
            for (Order__c ord : ordList) {
                orderIds.add(ord.Id);
            }
            
            // Fetch related Order_Item__c records
            dt.orList = [SELECT Id, Name, Product__c, Product__r.Name, Product_Category__c, Product_Category__r.Name,
                         Total_Amount__c, Account__r.Name, Visit__c, Visit__r.Name, Daily_log__r.Name, Quantity__c
                         FROM Order_Item__c 
                         WHERE Order__c IN :orderIds];
        }
        
        dt.Competition = [SELECT id,name,Product_Category__c,Product_Category__r.Name, Product__r.Name,Product__c,Display_boards__c,
                          Competitor_Name__c,Product_Category_Text__c,Product_Text__c,Special_offer_going_on__c,	Remarks__c
                          from Competition__c where visit__c =: recordid];

        dt.visitForm = [
            SELECT Id,Name,Customer_Name__c, Product_Categories__c
            FROM Visit_Form__c
            WHERE CreatedById = :UserInfo.getUserId()
                AND CreatedDate = TODAY
                AND (
                    Visit__c = :recordId
                )
            ORDER BY CreatedDate DESC
        ];
        dt.displayFormat=[SELECT Id, SKU__r.Name,skuName__c, Display__c FROM Display_Format__c WHERE Visit__c = :recordId
                          ORDER BY CreatedDate DESC ];
        dt.ShelfStocks= [SELECT Id,Name, Visit__c,Total_Stock_Level__c,Total_Sales_Quantity__c FROM Shelf_Stock__c  WHERE Visit__c = :recordId
                         ORDER BY CreatedDate DESC ];
        /*dt.returnItems = [select Id,Name,Batch_Number__c,Quantity__c,Reason_For_Return__c,Return__c,SKU__c,SKU_Name__c,UOM__c from 
                          Return_Item__c WHERE Return__r.Visit__c = :recordId
                          ORDER BY CreatedDate DESC];*/
        dt.returnList = [select Id,Name,Total_Amount__c,Total_Quantity__c,Return_Date__c from 
                         Return__c where Visit__c = :recordId ORDER BY CreatedDate DESC];
        dt.collectionItems = [ SELECT Id, Name,Amount_Received__c,Collection__c,Mode_of_Payment__c,	UTR_Number__c,	Remarks__c,
                              Invoice_Number__c,Collection__r.Mode_of_Payment__c,Collection__r.Reference_Number__c, 
                              Collection__r.UTR_Number__c,Collection__r.Remarks__c 
                              FROM Collection_Item__c WHERE Collection__r.Visit__c = :recordId];
        dt.VisitPhoto = LightningFileUploadHandler.getFiles(recordId);
        dt.Stock = [select Id,name,Product__c,Product__r.Name,Product__r.Channel__c,Product_Category__c,Product_Category__r.Name,	UOM__c,
                    Quantity__c, Unit_Price__c from Dealer_Stock__c where Visit__c =:recordId ];
        dt.paymentFollowUp = getPaymentDestails(recordId).paymentFollowUp;
        dt.orderfulfillments = unfulfilledOrders;
        
        return dt;
    }
    
    /**Stock Data**/
    @AuraEnabled 
    public static data getStockProducts(String accountId) {
        data dt = new data();
        Account acc = [
            SELECT Id, Name, Region__c, Customer_Type__c, Secondary_Customer_Category__c 
            FROM Account 
            WHERE Id = :accountId
        ];
        // Fetch products linked to the account's executive
        List<Product__c> products = getProducts(accountId,acc.Customer_Type__c);
        
        // Change: Now group by Channel__c
        Map<String, List<productData>> channelToProductsMap = new Map<String, List<productData>>();
        Integer index2 = 0;
        
        for (Product__c pro : products) {
            // Create product data
            productData p = new productData();
            p.id = pro.Id;
            p.name = pro.Name;
            p.category = pro.Product_Category_Name__c;
            p.unitPrice = pro.List_Price__c;
            p.taxPercent = pro.Tax_Percent__c;
            p.taxClass = pro.Tax_Class__c;
            p.uom = pro.UOM__c;
            p.createdDate = pro.CreatedDate.format('dd/MM/yyyy');
            p.value = 0;
            p.index2 = index2++;
            
            // Group by Channel__c
            if (!channelToProductsMap.containsKey(pro.Channel__c)) {
                channelToProductsMap.put(pro.Channel__c, new List<productData>());
            }
            channelToProductsMap.get(pro.Channel__c).add(p);
        }
        
        // Prepare final list
        Integer index1 = 0;
        List<categoryData> categoryList = new List<categoryData>();
        for (String channelName : channelToProductsMap.keySet()) {
            categoryData category = new categoryData();
            category.index1 = index1++;
            category.categoryName = channelName; 
            category.products = channelToProductsMap.get(channelName);
            categoryList.add(category);
        }
        
        dt.productCategories = categoryList;
        return dt;
    }
    @AuraEnabled
    global static data upsertStock(List<Dealer_Stock__c> stocks) {
        data dt = new data();
        upsert stocks;
        dt.stock = stocks;
        return dt;
    }
    
    /**Collection Data**/
    @AuraEnabled
    public static Data getCollectionsData(String accountId, boolean isPrimaryCustomer) 
    {
        Data dt = new Data();
        dt.modeOfPayment = extractPicklistValues('Collection_Item__c','Mode_of_Payment__c');
        if(isPrimaryCustomer)
        {
            dt.invoiceData =  [select Id,Name,Invoice_Date__c,Outstanding_Amount__c from Invoice__c
                               where Store__c =: accountId and Outstanding_Amount__c > 0];
        }
        return dt;  
    }
    @AuraEnabled
    public static void saveCollections(Collection__c collectionData, List<Collection_Item__c> collectionItems) 
    { 
        insert collectionData;
        for(Collection_Item__c cItem : collectionItems)
        {
            cItem.Collection__c = collectionData.Id;
        }
        insert collectionItems;
    }
    
    /**Competion Data**/
    @AuraEnabled
    public static CompetitionData getCompetions(String recordId, string visitId) 
    {
        CompetitionData  cd = new CompetitionData();
        cd.competitionList = [select Id,Name, Competitor__c,Competitor_Name__c,Account__c,Product__c,Product_Text__c,Product_Category__c,
                              Product_Category_Text__c,Display_boards__c,Special_offer_going_on__c,Special_offer_details__c,Remarks__c,	UniqueFileId__c,
                              Visit__c,Visit_for__c from Competition__c where Visit__c=: visitId and Visit__c != null order by createdDate];
        cd.productCategoryList = [select Id,Name from Product_Category__c where Active__c = true];
        Account acc = [
            SELECT Id, Name, Region__c, Customer_Type__c, Secondary_Customer_Category__c 
            FROM Account 
            WHERE Id = :recordId
        ];
        cd.productList = getProducts(recordId,acc.Customer_Type__c);
        cd.competitorList = [select Id,Name from Competitor__c];
        return cd;
    }
    @AuraEnabled
    public static CompetitionData saveCompetition(Competition__c cmp, string visitId) 
    {
        CompetitionData  cd = new CompetitionData();
        if(cmp.Competitor__c == null || String.isEmpty(cmp.Competitor__c))
        {
            Competitor__c competitor = new Competitor__c();
            competitor.Name = cmp.Competitor_Name__c;
            insert competitor;
            cmp.Competitor__c= competitor.Id;
        }
        upsert cmp;
        cd.competitorList = [select Id,Name from Competitor__c];
        cd.competitionList  = [SELECT  Product_Category__c,	Product__c, Special_offer_details__c, Special_offer_going_on__c, Visit__c,
                               Visit_for__c, Account__c,  Competitor_Name__c, Competitor__c, Display_boards__c,Product_Text__c,
                               Product_Category_Text__c,Remarks__c,	UniqueFileId__c,
                               Id,Name FROM Competition__c where Visit__c =:visitId and Visit__c != null order by createdDate  ];
        return cd;
        
    }
    @AuraEnabled  
    public static List<ContentDocument> getFilescompetetion(string uniqueId,string recordId){ 
        
        if(uniqueId !=  null && uniqueId != '')
        { 
            return [SELECT Id, Title, FileType,SystemModStamp FROM ContentDocument 
                    WHERE Id IN (SELECT ContentDocumentId FROM ContentVersion WHERE Description = :uniqueId)
                    AND ContentAssetId = null]; 
        }
        else
        {
            Set<Id> documentIds = new Set<Id>();
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :recordId
            ];
            
            for (ContentDocumentLink link : links) {
                documentIds.add(link.ContentDocumentId);
            }
            
            List<ContentDocument> docs = [
                SELECT Id, Title, SystemModStamp 
                FROM ContentDocument 
                WHERE Id IN :documentIds
            ]; 
            return docs;
        } 
    } 
    
    /**Return Data**/
    @AuraEnabled
    public static Data getReturnData(String accountId) {
        Data dt = new Data();
        
        Account acc = [
            SELECT Id, Name, Region__c, Customer_Type__c, Secondary_Customer_Category__c 
            FROM Account 
            WHERE Id = :accountId
        ];
        
        //Getting the Products
        list<Product__c> productList = getProducts(accountId, acc.Customer_Type__c);
        dt.productList = productList;
        
        //Map to store the final Price for each Product
        Map<String, Decimal> allProductwithPrice = new Map<String, Decimal>();
        //Map to store the original unit price before category slab discount
        Map<String, Decimal> originalUnitPriceMap = new Map<String, Decimal>();
        
        //Price change Map
        Map<String, Price_Change__c> priceChangeMap = new Map<String, Price_Change__c>();
        List<Price_Change__c> priceChanges = [SELECT customer_category__c,Type__c, Off__c, Sales_Channel__c FROM 
                                              Price_Change__c WHERE IsActive__c = true ];
        for (Price_Change__c pc : priceChanges) {
            priceChangeMap.put(pc.customer_category__c, pc);
        }
        if(!productList.isEmpty()){
            for (Product__c p : productList) {
                Price_Book__c bestPB;
                for (Price_Book__c pb : p.Price_Books__r) {
                    Boolean matched = false;
                    
                    if (acc.Customer_Type__c == 'Primary Customer') {
                        if (pb.Customer__c == acc.Id) {
                            matched = true;
                        }
                    } 
                    else if (acc.Customer_Type__c == 'Secondary Customer') 
                    {
                        if (pb.Customer__c == acc.Id ||
                            pb.Secondary_Customer_Category__c == acc.Secondary_Customer_Category__c ||
                            pb.Region__c == acc.Region__c)
                        {
                            matched = true;
                        }
                    }
                    
                    if (matched) {
                        bestPB = pb;
                        break;
                    }
                }
                
                Decimal finalPrice = 0;
                Decimal origUnitPrice = 0;

                if (bestPB != null) {
                    origUnitPrice = bestPB.Unit_Price__c != null ? bestPB.Unit_Price__c : 0;

                    if (priceChangeMap.containsKey(acc.Secondary_Customer_Category__c)) {
                        Price_Change__c priceChange = priceChangeMap.get(acc.Secondary_Customer_Category__c);
                        Decimal discountPercent = priceChange.Off__c;
                        String typeOf = priceChange.Type__c;

                        if(typeOf == 'MRP' && bestPB.MRP__c != null){
                            finalPrice = (bestPB.MRP__c * (1 - discountPercent / 100)).setScale(2, RoundingMode.HALF_UP);
                        }
                        else if(typeOf == 'Unit Price' && bestPB.Unit_Price__c != null){
                            finalPrice = (bestPB.Unit_Price__c * (1 - discountPercent / 100)).setScale(2, RoundingMode.HALF_UP);
                        }
                        else if (bestPB.Unit_Price__c != null) {
                            finalPrice = bestPB.Unit_Price__c;
                        }

                    }
                    else if (bestPB.Unit_Price__c != null) {
                        finalPrice = bestPB.Unit_Price__c;
                    }
                }
                else {
                    origUnitPrice = p.List_Price__c != null ? p.List_Price__c : 0;

                    if (priceChangeMap.containsKey(acc.Secondary_Customer_Category__c)) {
                        Price_Change__c priceChange = priceChangeMap.get(acc.Secondary_Customer_Category__c);
                        Decimal discountPercent = priceChange.Off__c;
                        String typeOf = priceChange.Type__c;

                        if(typeOf == 'MRP' && p.MRP__c != null){
                            finalPrice = (p.MRP__c * (1 - discountPercent / 100)).setScale(2, RoundingMode.HALF_UP);
                        }
                        else if(typeOf == 'Unit Price' && p.List_Price__c != null){
                            finalPrice = (p.List_Price__c * (1 - discountPercent / 100)).setScale(2, RoundingMode.HALF_UP);
                        }
                        else if (p.List_Price__c != null) {
                            finalPrice = p.List_Price__c;
                        }

                    }
                    else if (p.List_Price__c != null) {
                        finalPrice = p.List_Price__c;
                    }
                }

                allProductwithPrice.put(p.Id, finalPrice);
                originalUnitPriceMap.put(p.Id, origUnitPrice);
            }
        }

        dt.productIdWithMrp = allProductwithPrice;
        dt.productIdWithOriginalUnitPrice = originalUnitPriceMap;
        dt.isUomDisabled = true;
        
        if (acc != null && acc.Customer_Type__c == 'Primary Customer') {
            // Step 1: Get all related Product Mappings
            List<Product_Mapping__c> productMappings = [ SELECT Id, Name, Chanel__c, Customer__c FROM Product_Mapping__c
                                                        WHERE Customer__c = :acc.Id];
            
            // Step 2: Get enabled channels from Custom Label (comma-separated string)
            Set<String> uomEnabledChannels = new Set<String>();
            for (String val : Label.Enable_UOM_Sales_Channels.split(',')) {
                uomEnabledChannels.add(val.trim());
            }
            
            // Step 3: Check if any channel matches
            for (Product_Mapping__c pm : productMappings) {
                if (uomEnabledChannels.contains(pm.Chanel__c)) {
                    dt.isUomDisabled = false;
                    break; 
                }
            }
        }
        
        
        dt.resonForReturn = extractPicklistValues('Return_Item__c', 'Reason_For_Return__c');
        dt.uom = extractPicklistValues('Return_Item__c', 'UOM__c');
        
        return dt;
    }
    
    @AuraEnabled
    public static void saveReturn(Return__c returnData, List<Return_Item__c> returnItems) {
        insert returnData;
        for (Return_Item__c rtnItem : returnItems) {
            rtnItem.Return__c = returnData.Id;
        }
        insert returnItems;
    }
    
    /** Get Beat Data **/
    @AuraEnabled
    public static data getBeatData() {
        data dt = new data();
        Id currentUserId = UserInfo.getUserId();
        
        // Determine day limit based on profile
        String profileName = [SELECT Profile.Name FROM User WHERE Id = :currentUserId].Profile.Name;
        list<Employee_Creation_Access__mdt> employeeCreationAceess = [select Id,Beat_Days_Limit__c from Employee_Creation_Access__mdt 
                                                                      where Label =:profileName limit 1];
        Integer dayLimit = Integer.valueOf(employeeCreationAceess[0].Beat_Days_Limit__c);
        
        // Fetch PJP items within date range
        List<PJP_Item__c> pjpItemsList = [
            SELECT Id,Beat__c, Date__c,Beat__r.Name FROM PJP_Item__c
            WHERE PJP__r.User__c = :currentUserId AND Date__c >= TODAY AND Date__c <= :System.today().addDays(dayLimit)
            AND Status__c ='Approved' and Beat__r.Active__c = true
        ];

        if (pjpItemsList.size() < dayLimit) {
            Integer remainingRecordsNeeded = dayLimit - pjpItemsList.size();
            
            List<PJP_Item__c> pastPjpItems = [
                SELECT Id, Beat__c, Date__c, Beat__r.Name 
                FROM PJP_Item__c
                WHERE PJP__r.User__c = :currentUserId 
                AND Date__c < TODAY
                AND Status__c = 'Approved' 
                AND Beat__r.Active__c = true
                ORDER BY Date__c DESC
                LIMIT :remainingRecordsNeeded
            ];
            
            // Combine FUTURE + PAST records (prioritizing future ones)
            pjpItemsList.addAll(pastPjpItems);
        }
        
        
        
        // Get current beat info from Daily Log
        List<Daily_Log__c> logs = [
            SELECT Current_Beat__c, Day_started_time__c, Day_ended_time__c,PJP_Item__c	
            FROM Daily_Log__c
            WHERE Day_started_time__c = TODAY AND OwnerId = :currentUserId
            LIMIT 1
        ];
        
        String currentBeatId = logs.isEmpty() ? null : logs[0].Current_Beat__c;
        String currentPjpItemId = logs.isEmpty() ? null : logs[0].PJP_Item__c;
        dt.currentBeatExisted =  currentBeatId != null ? true : false;
        List<BeatData> beatDataList = new List<BeatData>();
        
        
        for (PJP_Item__c item : pjpItemsList) {
            if (item.Beat__c != null) {
                String formattedDate = DateTime.newInstance(item.Date__c.year(), item.Date__c.month(), item.Date__c.day()).format('dd/MM/yyyy');
                BeatData data = new BeatData();
                data.beatId = item.Beat__c;
                data.beatName = item.Beat__r.Name;
                data.pjpDate = formattedDate;
                data.pjpId = item.Id;
                data.istodayBeat = item.Date__c == Date.today();
                data.isCurrentBeat = item.Id == currentPjpItemId;
                data.openPopup = false;
                beatDataList.add(data);
            }
        }

        
        List<Leaves__c> lv = [
            SELECT Id, Name
            FROM Leaves__c
            WHERE From_Date__c <= TODAY
            AND To_Date__c >= TODAY
            AND ApprovalStatus__c IN ('Leave Approved','Submitted for Approval','Not Submitted')
            AND Leave_Cancellation_Status__c != 'Submitted for Cancellation' 
            AND Session_Type__c = null 
            AND OwnerId = :UserInfo.getUserId()
        ];
        
        dt.isLeaveExisted = !lv.isEmpty();
        dt.beatDataList = beatDataList;
        dt.isDayStarted = !logs.isEmpty() && logs[0].Day_ended_time__c == null;
        
        // Fetch shared beats
        dt.sharedBeatDataList = getSharedBeatData(currentUserId);
        
        return dt;
    }
    
    private static List<BeatData> getSharedBeatData(Id currentUserId) {
        List<BeatData> sharedBeats = new List<BeatData>();
        
        List<Child_beat__Share> beatShares = [SELECT ParentId FROM Child_beat__Share 
                                              WHERE UserOrGroupId = :currentUserId 
                                              AND RowCause = 'Manual'];
        
        if (beatShares.isEmpty()) {
            return sharedBeats;
        }
        
        Set<Id> sharedBeatIds = new Set<Id>();
        for (Child_beat__Share bs : beatShares) {
            sharedBeatIds.add(bs.ParentId);
        }
        
        List<Child_Beat__c> childBeats = [SELECT Id, Name, Owner.Name
                                          FROM Child_Beat__c
                                          WHERE Id IN :sharedBeatIds AND Active__c = true AND OwnerId != :currentUserId];
        
        for (Child_Beat__c cb : childBeats) {
            BeatData data = new BeatData();
            data.beatId = cb.Id;
            data.beatName = cb.Name;
            data.pjpDate = '';
            data.pjpId = null;
            data.istodayBeat = false;
            data.isCurrentBeat = false;
            data.openPopup = false;
            data.ownerName = cb.Owner.Name;
            sharedBeats.add(data);
        }
        
        return sharedBeats;
    } 
    @AuraEnabled
    public static void updateCurrentBeatAndSwitchHistory(string beatId,string currentBeatName,string switchBeatName,string reason,string currentPJPId) {
        List<Daily_Log__c> logs = [
            SELECT Id, Beat_Switch_History__c
            FROM Daily_Log__c
            WHERE Day_started_time__c = TODAY AND OwnerId = :UserInfo.getUserId()
            LIMIT 1
        ];
        
        if (!logs.isEmpty()) {
            Daily_Log__c log = logs[0];
            log.Current_Beat__c = beatId;
            log.PJP_Item__c = currentPJPId;
            if(String.isNotBlank(currentBeatName) && String.isNotBlank(switchBeatName))
            {
                String existingHistory = log.Beat_Switch_History__c;
                //String newEntry = currentBeatName + ' to ' + switchBeatName + ' - ' + reason;
                String newEntry;
                if (String.isNotBlank(reason)) {
                    newEntry = currentBeatName + ' to ' + switchBeatName + ' - ' + reason;
                } else {
                    newEntry = currentBeatName + ' to ' + switchBeatName;
                }
                
                
                if (String.isNotBlank(existingHistory)) {
                    log.Beat_Switch_History__c = existingHistory + '; ' + newEntry;
                }
                else {
                    log.Beat_Switch_History__c = newEntry;
                }
            }
            update log;
        }
    }
    
    
    
    /**Bussiness Summary Data **/
    @AuraEnabled
    public static Map<String, data> getSummeryData(String ids, String objName) {
        Map<String, data> groupedData = new Map<String, data>();
        string recordIs;
        Visit__c vs = [Select id,name,Account1__c, Dealer__c, Distributor__c, Visit_for__c from Visit__c where id =: ids];
        if(vs.Account1__c != null)
            recordIs = vs.Account1__c;
       
        if(recordIs == null)
            return null;
        
        if (objName == 'outstanding') {
            List<invoice__c> invList = [SELECT Id, Name, Invoice_Date__c, Total_Amount__c 
                                        FROM invoice__c WHERE Store__c = :recordIs LIMIT 10000];
            
            for (invoice__c inv : invList) {
                if (inv.Invoice_Date__c != null) {
                    String formattedDate = DateTime.newInstance(inv.Invoice_Date__c.year(), inv.Invoice_Date__c.month(), inv.Invoice_Date__c.day()).format('dd/MM/yyyy');
                    
                    // Fetch or create data instance for this date
                    if (!groupedData.containsKey(formattedDate)) {
                        groupedData.put(formattedDate, new data());
                    }
                    
                    outstanding outRecord = new outstanding();
                    outRecord.invoiceId = inv.Id;
                    outRecord.invNo = inv.Name;
                    outRecord.invDate = formattedDate;
                    outRecord.invAmt = inv.Total_Amount__c;
                    
                    groupedData.get(formattedDate).outData.add(outRecord);
                }
            }
        } 
        else if (objName == 'order') {
            List<Order__c> ordList = [SELECT Id, Name, Account__c, Order_Date__c, Grand_Total__c,Order_Type__c 
                                      FROM Order__c WHERE Account__c = :recordIs AND CreatedDate = This_Month];
            
            for (Order__c ord : ordList) {
                if (ord.Order_Date__c != null) {
                    String formattedDate = DateTime.newInstance(ord.Order_Date__c.year(), ord.Order_Date__c.month(), ord.Order_Date__c.day()).format('dd/MM/yyyy');
                    
                    if (!groupedData.containsKey(formattedDate)) {
                        groupedData.put(formattedDate, new data());
                    }
                    
                    Orders od = new Orders();
                    od.OrdNo = ord.Name;
                    od.OrderType = ord.Order_Type__c;
                    od.OrdDate = formattedDate;
                    od.OrdAmt = ord.Grand_Total__c;
                    
                    groupedData.get(formattedDate).ordData.add(od);
                }
            }
        } 
        else if (objName == 'visit') {
            // Fetch all visits related to the given record
            List<Visit__C> visList = [SELECT Id, Account1__c, Dealer__c,Location_Type__c,Visit_Duration__c,Status__c, Distributor__c, Visit_for__c, OwnerId, Actual_Start_Time__c,createdBy.Name
                                      FROM Visit__c 
                                      WHERE (Account1__c = :recordIs) and Actual_Start_Time__c != null
                                     and CreatedDate = This_Month];
            
            // Fetch all orders related to the given record
            List<Order__c> ordList = [SELECT Id, Name, Account__c, Order_Date__c, Grand_Total__c,createdBy.Name 
                                      FROM Order__c 
                                      WHERE Account__c = :recordIs AND Order_Date__c != NULL  and CreatedDate = This_Month];
            
            for (Visit__C vis : visList) {
                if (vis.Actual_Start_Time__c != null) {
                    String formattedDate = vis.Actual_Start_Time__c.format('dd/MM/yyyy');
                    
                    // Filter orders that match this visit date
                    Integer orderCount = 0;
                    for (Order__c ord : ordList) {
                        String formattedOrdDate = DateTime.newInstance(ord.Order_Date__c.year(), ord.Order_Date__c.month(), ord.Order_Date__c.day()).format('dd/MM/yyyy');
                        if (formattedOrdDate == formattedDate) {
                            orderCount++;
                        }
                    }
                    
                    if (!groupedData.containsKey(formattedDate)) {
                        groupedData.put(formattedDate, new data());
                    }
                    
                    VisitDataSummary vData = new VisitDataSummary();
                    vData.visitId = vis.Id;
                    vData.visDate = formattedDate;
                    vData.ExeName = vis.createdBy.Name;
                    vData.visitType = vis.Visit_for__c;
                    vData.Status = vis.Status__c;
                    vData.VisitDuration = vis.Visit_Duration__c;
                    vData.LocationType = vis.Location_Type__c;
                    
                    
                    
                    vData.ownerId = vis.OwnerId;
                    vData.TotalOrd = orderCount; // Assign the counted orders for this visit date
                    
                    groupedData.get(formattedDate).SummaryvisitData.add(vData);
                }
            }
        }
        else if(objName == 'sales'){
            List<Sale__c> saleList = [Select id, name,Invoice__c,Invoice__r.Name,Account__c,Total_Amount__c,Invoice__r.Invoice_Date__c, 
                                      Invoice__r.Total_Amount__c 
                                      from Sale__c where Account__c =: recordIs];
            for(Sale__c sl:saleList){
                if(sl.Invoice__r.Invoice_Date__c != null){
                    String formattedDate = DateTime.newInstance(sl.Invoice__r.Invoice_Date__c.year(), sl.Invoice__r.Invoice_Date__c.month(), sl.Invoice__r.Invoice_Date__c.day()).format('dd/MM/yyyy');
                    if (!groupedData.containsKey(formattedDate)) {
                        groupedData.put(formattedDate, new data());
                    }
                    salesSummery sale = new salesSummery();
                    sale.SalesId = sl.Id;
                    sale.salesInvoice = sl.Invoice__r.Name;
                    sale.salesDate = formattedDate;
                    sale.Amount = sl.Invoice__r.Total_Amount__c;
                    
                    groupedData.get(formattedDate).sales.add(sale);
                }
            } 
        }
        else if(objName == 'return'){
            list<Return__c> rtnlist = [select Id,Name,Customer__r.Name,Return_Date__c,
                                       Total_Quantity__c,Total_Amount__c,CreatedDate
                                       from Return__c where  Customer__c = :recordIs  AND Return_Date__c = This_Month];
            for (Return__c rtn : rtnlist) {
                if (rtn.Return_Date__c != null) {
                    String formattedDate = DateTime.newInstance(rtn.Return_Date__c.year(), rtn.Return_Date__c.month(), rtn.Return_Date__c.day()).format('dd/MM/yyyy');
                    if (!groupedData.containsKey(formattedDate)) {
                        groupedData.put(formattedDate, new data());
                    }
                    
                    ReturnDataSummary returndata = new ReturnDataSummary();
                    returndata.returnId = rtn.Id;
                    returndata.returnName = rtn.Name;
                    returndata.customerName = rtn.Customer__r != null ?  rtn.Customer__r.Name : '';
                    returndata.quantity = rtn.Total_Quantity__c;    
                    returndata.amount = rtn.Total_Amount__c; 
                    groupedData.get(formattedDate).summaryReturnData.add(returndata);
                }
            }
        }
        
        return groupedData;
    }
    @AuraEnabled
    public static void pushToLogistics(Id recId){
        Order__c ord = [Select Id,Name,Push_to_Logistics__c,Status__c,Delivery_Plant__c from Order__c where Id=:recId];
        List<Employee__c> empList = [Select Id,Delivery_Plant__c,User__c from Employee__c where Profile__c = 'Logistics Team' and User__r.isActive = true and Delivery_Plant__c =: ord.Delivery_Plant__c LIMIT 1];
        CustomNotificationType closedWonNotification = [SELECT Id,DeveloperName FROM CustomNotificationType WHERE DeveloperName = 'Order_Notification' LIMIT 1]; 
        Messaging.CustomNotification Notification = new Messaging.CustomNotification(); 
        Notification.setNotificationTypeId(closedWonNotification.id); 
        Notification.setSenderId(Userinfo.getUserId()); 
        Notification.setBody('Order has been pushed to Logistics'+ord.Name); 
        Notification.setTitle('Order Confirmation'); 
        Notification.setTargetId(recId); 
        if(empList != null && !empList.isEmpty()){
            Notification.send(new Set<String>{empList[0].User__c});
        }
        else{
            Notification.send(new Set<String>{'005IR00000GESufYAH'});
        }
        
        ord.Push_to_Logistics__c = 'Yes';
        ord.Status__c = 'Push to Logistics';
        update ord;
        sendListEmail(ord.Id);
    }
    
    
    public static void sendListEmail(Id orderId){
        try {
            // Get the order to include its name/number in the subject
            Order__c orderRecord = [SELECT Id, Name,Account__c,Account__r.Email_ID__c,Account__r.Secondary_Customer_Type__c,Account__r.Customer_Type__c FROM Order__c WHERE Id = :orderId LIMIT 1];
            
            if((orderRecord.Account__r.Secondary_Customer_Type__c == 'Sub Stockiest' || orderRecord.Account__r.Customer_Type__c == 'Primary Customer') && orderRecord.Account__r.Email_ID__c != null){
                // Create the email
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                
                // Set email properties
                email.setSubject('Order Summary - ' + orderRecord.Name);
                email.setPlainTextBody('Please find attached the order summary.');
                
                // Render Visualforce page as PDF
                PageReference pdfPage = Page.OrderPdf; // Your VF page name
                pdfPage.getParameters().put('id', orderId);
                Blob pdfBlob;
                
                if (Test.isRunningTest()) {
                    pdfBlob = Blob.valueOf('Test PDF Content');
                } else {
                    pdfBlob = pdfPage.getContentAsPDF();
                }
                
                // Create PDF attachment
                Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                attachment.setFileName('OrderSummary_' + orderRecord.Name + '.pdf');
                attachment.setBody(pdfBlob);
                attachment.setContentType('application/pdf');
                
                // Add attachment to email
                email.setFileAttachments(new Messaging.EmailFileAttachment[]{attachment});
                
                // Set recipient (modify as needed)
                email.setToAddresses(new String[]{orderRecord.Account__r.Email_ID__c});
                
                // Send email
                Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
            }
            
            
        } catch(Exception e) {
            System.debug('Error sending order summary email: ' + e.getMessage());
            // Consider adding error handling logic here
        }
    }
    
    //-----------------------------------------------Order Related Methods---------------------------------------
    //Separate Order Tab first called to get 25 accounts
    @AuraEnabled
    public static data getAccountData(String areaFilter){
        data dt = new data();

        // Fetch the ListView record as before
        List<ListView> listViewRecords = [SELECT Id FROM ListView WHERE SObjectType = 'Order__c' AND DeveloperName = 'Today' LIMIT 1];
        dt.ListViewDetails = (!listViewRecords.isEmpty()) ? listViewRecords[0] : null;

        // SSA/DSM users only see Secondary Customers. Resolve the flag here (initial
        // account load) and return it so the client can reuse it for getAccountsByArea.
        User u = [SELECT Id, Is_SSA_DSM__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        Boolean secOnly = (u.Is_SSA_DSM__c == true);
        dt.isDSM_SSA = secOnly;

        // Modify the query to handle the case where areaFilter is null or empty
        String areaFilterCondition = (String.isEmpty(areaFilter)) ? '' : areaFilter;

        if (String.isEmpty(areaFilterCondition)) {
            if (secOnly) {
                dt.Account = [SELECT Id, Name, SAP_Customer_Code__c,Account_Type_Of__c,Account_Type_With_Code__c,Delivery_Plant__c FROM Account
                              WHERE Customer_Type__c = 'Secondary Customer' AND Customer_Status__c != 'Inactive'
                              LIMIT 20];
            } else {
                // If no area filter is provided, get all accounts
                dt.Account = [SELECT Id, Name, SAP_Customer_Code__c,Account_Type_Of__c,Account_Type_With_Code__c,Delivery_Plant__c FROM Account
                              WHERE
                              (
                                  (Customer_Type__c = 'Primary Customer' AND Customer_Status__c = 'Active')
                                  OR
                                  (Customer_Type__c = 'Secondary Customer' AND Customer_Status__c != 'Inactive')
                              )
                              LIMIT 20
                             ];
            }
        } else {
            // If area filter is provided, filter accounts by the related Product_Mapping__c area
            String custType = secOnly ? 'Secondary Customer' : 'Primary Customer';
            dt.Account = [SELECT id, name, Customer_Type__c, customer_code__c,SAP_Customer_Code__c
                          FROM Account
                          WHERE Customer_Type__c = :custType and  Customer_Status__c != 'Inactive'
                          AND Id IN (SELECT Customer__c FROM Product_Mapping__c WHERE Area__c = :areaFilter) limit 10];
        }

        return dt;
    }
    
    //Search Account by Name and Sap code
    @AuraEnabled(cacheable=true)
    public static List<Account> getAccountsByArea(String area, String searchTerm, Boolean onlySecondary) {
        // SSA/DSM users (flag resolved during screen load and passed in) only see Secondary Customers
        Boolean secOnly = (onlySecondary == true);
        String baseWhere = secOnly
            ? '(Customer_Type__c = \'Secondary Customer\' AND Customer_Status__c != \'Inactive\')'
            : '((Customer_Type__c = \'Primary Customer\' AND Customer_Status__c = \'Active\') ' +
              'OR (Customer_Type__c = \'Secondary Customer\' AND Customer_Status__c != \'Inactive\'))';

        // Initial query for Account records
        String query =
            'SELECT Id, Name, Customer_Type__c, Account_Type_Of__c, SAP_Customer_Code__c, ' +
            'Account_Type_With_Code__c, Delivery_Plant__c ' +
            'FROM Account ' +
            'WHERE ' + baseWhere;
        
        
        
        List<String> conditions = new List<String>();
        Set<Id> accountIds = new Set<Id>();
        
        // Add area filter if specified
        if (String.isNotBlank(area)) {
            // Query Product_Mapping__c to find related Customer__c accounts by area
            List<Product_Mapping__c> productMappings = [SELECT Customer__c FROM Product_Mapping__c WHERE Area_Area_Name__c = :area];
            
            // Add the Customer__c ids to the set
            for (Product_Mapping__c pm : productMappings) {
                accountIds.add(pm.Customer__c);
            }
            
            // If there are matching accounts, add the condition
            if (!accountIds.isEmpty()) {
                conditions.add('Id IN :accountIds');
            }
        }
        
        // Add search term filter if specified
        if (String.isNotBlank(searchTerm)) {
            String likeTerm = '%' + String.escapeSingleQuotes(searchTerm) + '%';
            conditions.add('(Account_Type_With_Code__c LIKE :likeTerm)');
        }
        
        // If no filters were added, just limit the records
        if (conditions.isEmpty()) {
            return Database.query(query + ' LIMIT 25');
        }
        
        // Combine the conditions into the query
        query += ' AND ' + String.join(conditions, ' AND ') + ' LIMIT 25';
        
        // Return the results of the final query
        return Database.query(query);
    }
    
    //to get Products
    @AuraEnabled
    public static Data getSchemeWiseOrderData(String visitId, String AccountId, String orderRecordId) {
        Data responseData = new Data();
        Id currentUserId = UserInfo.getUserId();
        List<ListView> listViewRecords = [SELECT Id FROM ListView WHERE SObjectType = 'Order__c' AND DeveloperName = 'Today' LIMIT 1];
        responseData.ListViewDetails = (!listViewRecords.isEmpty()) ? listViewRecords[0]: null;
        User us = [Select Id,Name,Minimum_Order_value__c,Profile.Name,Category__c From User where Id=:currentUserId];
        // Step 1: Determine Account
        String accId;
        if (visitId != null) {
            Visit__c visit = [SELECT Account1__c, Account1__r.Name FROM Visit__c WHERE Id = :visitId LIMIT 1];
            accId = visit.Account1__c;
            responseData.accountName = visit.Account1__r.Name;
        } 
        else if (AccountId != null) {
            accId = AccountId;
        } 
        else if (orderRecordId != null) {
            List<Order_Item__c> items = [
                SELECT Order__r.Account__c,Product__c,Order__r.PO_DATE__c,Order__r.PO_NUM__c,Order__r.Account__r.Customer_Type__c,Order__r.Delivery_To__c,Order__r.Expected_Delivery_Date__c,Order__r.OwnerId,Order__r.Owner.Name,Quantity__c, Order__r.Account__r.Name,Case_Qyt__c,Each_Qyt__c FROM Order_Item__c WHERE Order__c = :orderRecordId
            ];
            if (!items.isEmpty()) {
                accId = items[0].Order__r.Account__c;
                responseData.accountName = items[0].Order__r.Account__r.Name;
                responseData.accountType = items[0].Order__r.Account__r.Customer_Type__c;
                responseData.deliveryTo = items[0].Order__r.Delivery_To__c;
                responseData.estimatedDeliveryDate = items[0].Order__r.Expected_Delivery_Date__c;
                responseData.PoNum = items[0].Order__r.PO_NUM__c;
                responseData.PoDate = items[0].Order__r.PO_DATE__c;
                responseData.orderOwnerId = items[0].Order__r.OwnerId;
                responseData.orderOwnerName = items[0].Order__r.Owner.Name;
            }
            Map<Id, Order_Item__c> productIdToQty = new Map<Id, Order_Item__c>();
            for(Order_Item__c item : items){
                productIdToQty.put(item.Product__c, item);
            }
            
            responseData.existingOrderProductQuantities = productIdToQty;
        }
        if (String.isBlank(accId)) throw new AuraHandledException('Account not found.');
        
        Account acc = [
            SELECT Id, Name, Account_Type_With_Code__c,Region__c,Account_Type_Of__c, Primary_Customer_Type__c,Customer_Type__c,Secondary_Customer_Type__c, Secondary_Customer_Category__c,customer_code__c FROM Account WHERE Id = :accId
        ];
        responseData.currentAccountRec = acc;
        responseData.isShowOwner = false;
        if(us.Profile.Name == 'Logistics Team' || us.Profile.Name == 'System Administrator'){
            responseData.isShowOwner = true;
        }
        responseData.accountName = acc.Name;
        responseData.accountType = acc.Customer_Type__c;
        responseData.orderAccountId = accId;
        responseData.Account = new List<Account>{acc};
            responseData.isModerTrade = false;
        if(acc.Primary_Customer_Type__c == 'Modern Trade'){
            responseData.isModerTrade = true;
        }
            
            
        Set<String> channelSet = getProductsForSure(acc.Id,acc.Customer_Type__c);
        system.debug('channelSet'+channelSet);
        Set<String> areList = getProductsForArea(acc.Id,acc.Customer_Type__c);
        
        List<Product_Mapping__c> prdMapList = new List<Product_Mapping__c>();
        Set<String> delivaryPlantSet = new Set<String> ();
        if(acc.Customer_Type__c == 'Primary Customer'){
            prdMapList = getProductMappins(acc.Id);
            if(!prdMapList.isEmpty())
            {
                for(Product_Mapping__c pm : prdMapList) {
                    if(pm != null && String.isNotBlank(pm.Child_Depot__c)) {
                        delivaryPlantSet.add(pm.Child_Depot__c);
                    }
                }
            }
        }
        
        Map<String, Price_Change__c> priceChangeMap = new Map<String, Price_Change__c>();
        List<Price_Change__c> priceChanges = [
            SELECT customer_category__c, Off__c, Sales_Channel__c,Type__c
            FROM Price_Change__c 
            WHERE IsActive__c = true
        ];
        for (Price_Change__c pc : priceChanges) {
            priceChangeMap.put(pc.customer_category__c, pc);
        }
        system.debug('getAllPriceschnage '+priceChangeMap);
        
        // Step 3: Get Active Products with PriceBooks
        Map<Id, productData> allProducts = new Map<Id, productData>();
        List<Sales_Channel_To_SKU__c> channels = new  List<Sales_Channel_To_SKU__c>();
        if(us.Category__c == null || us.Category__c == '')
        {
            channels = [SELECT Id, Name, SKU__c,SKU__r.Name,Delivery_Plant__c,Sales_Channel__c,
                        SKU__r.Is_Active__c FROM Sales_Channel_To_SKU__c WHERE Sales_Channel__c IN :channelSet AND SKU__r.Is_Active__c = true];
        }
        else
        {
            channels = [SELECT Id, Name, SKU__c,SKU__r.Name,Delivery_Plant__c,Sales_Channel__c,
                        SKU__r.Is_Active__c FROM Sales_Channel_To_SKU__c WHERE Sales_Channel__c IN :channelSet 
                        and SKU__r.Is_Active__c = true AND SKU__r.Category__c =: us.Category__c];
        }
        
        Map<String,Id> skuNameToId = new Map<String,Id>();
        Set<String> productIds = new Set<String>();
        Map<Id, List<Sales_Channel_To_SKU__c>> productToChannelsMap = new Map<Id, List<Sales_Channel_To_SKU__c>>();
        
        for (Sales_Channel_To_SKU__c channel : channels) {
            productIds.add(channel.SKU__r.Name);
            skuNameToId.put(channel.SKU__r.Name,channel.SKU__c);
            if(channel.Delivery_Plant__c != null){
                if (!productToChannelsMap.containsKey(channel.SKU__c)) {
                    productToChannelsMap.put(channel.SKU__c, new List<Sales_Channel_To_SKU__c>());
                }
                productToChannelsMap.get(channel.SKU__c).add(channel);
            }
            
        }
        List<Product__c> products = new List<Product__c>();
        if(acc.Customer_Type__c == 'Primary Customer'){
            products = [
                SELECT Id, Name, Channel__c, Net_Weight__c,Product_Category_Name__c,Product_Sub_Group__c,Delivery_Plant__c,Alternate_UOM__c,Uom_Conversion__c, Product_Category1__c, List_Price__c,
                MRP__c, Tax_Percent__c, Tax_Class__c, CreatedDate, UOM__c,
                (SELECT Id, Unit_Price__c, MRP__c,Tax__c, UOM__c, Customer__c, Customer_Type__c, Region__c, Secondary_Customer_Category__c,Sales_Channel__c
                 FROM Price_Books__r where Customer_Type__c =:acc.Customer_Type__c and Customer__c =: acc.Id Order by LastModifiedDate Desc LIMIT 1),(select Id,Name,Bill_Date__c,Price_per_unit__c,Product__c from Invoice_items__r where Invoice__r.Store__c =:acc.Id and FOC_Price__c = false and Bill_Date__c >= 2025-09-22 Order By Bill_Date__c Desc LIMIT 1)
                FROM Product__c
                WHERE Is_Active__c = true AND Id IN :skuNameToId.values()
            ];
        }
        else{
            products = [
                SELECT Id, Name, Channel__c, Net_Weight__c,Product_Category_Name__c,Product_Sub_Group__c,Delivery_Plant__c,Alternate_UOM__c,Uom_Conversion__c, Product_Category1__c, List_Price__c,
                MRP__c, Tax_Percent__c, Tax_Class__c, CreatedDate, UOM__c,
                (SELECT Id, Unit_Price__c, MRP__c,Tax__c, UOM__c, Customer__c, Customer_Type__c, Region__c, Secondary_Customer_Category__c,Sales_Channel__c
                 FROM Price_Books__r where Customer_Type__c =:acc.Customer_Type__c and Sales_Channel__c IN: channelSet)
                FROM Product__c
                WHERE Is_Active__c = true AND Id IN :skuNameToId.values()
            ];
        }
         
        
        system.debug('ProductMapping Start');
        Integer index2 = 0;
        for (Product__c p : products) {
            Price_Book__c bestPB;
            for (Price_Book__c pb : p.Price_Books__r) {
                Boolean matched = false;
                if (acc.Customer_Type__c == 'Primary Customer') {
                    if (pb.Customer__c == acc.Id){
                        matched = true;
                    } 
                } 
                else if (acc.Customer_Type__c == 'Secondary Customer') {
                    if (pb.Customer__c == acc.Id) {
                        bestPB = pb;
                    }
                    else if (pb.Secondary_Customer_Category__c == acc.Secondary_Customer_Category__c) {
                        bestPB = pb; 
                    }
                    else if (pb.Sales_Channel__c != null && channelSet.contains(pb.Sales_Channel__c)) {
                        bestPB = pb;
                    }
                }
                if (matched == true) {
                    bestPB = pb;
                }
            }
            
            productData pd = new productData();
            pd.id = p.Id;
            pd.name = p.Name;
            pd.category = p.Product_Category_Name__c;
            pd.subGroup = p.Product_Sub_Group__c;
            pd.UnitPricePriceBook = 0;
            pd.originalUnitPrice = 0;
           
            if(p.Invoice_items__r.size() > 0){
                pd.UnitPricePriceBook = p.Invoice_items__r[0].Price_per_unit__c;
                pd.originalUnitPrice = p.Invoice_items__r[0].Price_per_unit__c;
                pd.MRP = p.MRP__c;
            }
            else if (bestPB != null) {
                pd.originalUnitPrice = bestPB.Unit_Price__c != null ? bestPB.Unit_Price__c : 0;

                if (priceChangeMap.containsKey(acc.Secondary_Customer_Category__c)) {
                    Price_Change__c priceChange = priceChangeMap.get(acc.Secondary_Customer_Category__c);
                    Decimal discountPercent = priceChange.Off__c;
                    String typeOf = priceChange.Type__c;
                    if(typeOf == 'MRP' && bestPB.MRP__c != null){
                        pd.UnitPricePriceBook = (bestPB.MRP__c * (1 - discountPercent / 100)).setScale(2, RoundingMode.HALF_UP);
                    }
                    else if(typeOf == 'Unit Price' && bestPB.Unit_Price__c != null){
                        pd.UnitPricePriceBook = (bestPB.Unit_Price__c * (1 - discountPercent / 100)).setScale(2, RoundingMode.HALF_UP);
                    }
                    else if(bestPB.Unit_Price__c != null){
                        pd.UnitPricePriceBook = bestPB.Unit_Price__c;
                    }
                }
                else if(bestPB.Unit_Price__c != null){
                    pd.UnitPricePriceBook = bestPB.Unit_Price__c;
                }

                pd.MRP = bestPB.MRP__c != null ? bestPB.MRP__c : 0;
                pd.taxPercent = bestPB.Tax__c;
            }
            else {
                pd.originalUnitPrice = p.List_Price__c != null ? p.List_Price__c : 0;

                if (priceChangeMap.containsKey(acc.Secondary_Customer_Category__c)) {
                    Price_Change__c priceChange = priceChangeMap.get(acc.Secondary_Customer_Category__c);
                    Decimal discountPercent = priceChange.Off__c;
                    String typeOf = priceChange.Type__c;
                    if(typeOf == 'MRP' && p.MRP__c != null){
                        pd.UnitPricePriceBook = (p.MRP__c * (1 - discountPercent / 100)).setScale(2, RoundingMode.HALF_UP);
                    }
                    else if(typeOf == 'Unit Price' && p.List_Price__c != null){
                        pd.UnitPricePriceBook = (p.List_Price__c * (1 - discountPercent / 100)).setScale(2, RoundingMode.HALF_UP);
                    }
                    else if(p.List_Price__c != null){
                        pd.UnitPricePriceBook = p.List_Price__c;
                    }
                }
                else if(p.List_Price__c != null){
                    pd.UnitPricePriceBook = p.List_Price__c;
                }

                pd.MRP = p.MRP__c != null ? p.MRP__c : 0;
                pd.uom = p.UOM__c;
                pd.taxPercent = p.Tax_Percent__c;
            }
            
            pd.discountedPrice = 0;
            pd.discountedUnitPrice = 0;
            if(acc.Customer_Type__c == 'Primary Customer') {
                pd.deliveryPlant = null;
                if(p != null && p.Id != null && productToChannelsMap != null) {
                    List<Sales_Channel_To_SKU__c> channelMappings = productToChannelsMap.get(p.Id);
                    if(channelMappings != null && !channelMappings.isEmpty()) {
                        for(Sales_Channel_To_SKU__c mapping : channelMappings) {
                            if(mapping != null && String.isNotBlank(mapping.Delivery_Plant__c) && channelSet.Contains(mapping.Sales_Channel__c)
                              && delivaryPlantSet.Contains(mapping.Delivery_Plant__c)) {
                                pd.deliveryPlant = mapping.Delivery_Plant__c;
                                break;
                            }
                        }
                    }
                }
                
                if(pd.deliveryPlant == null && prdMapList != null && !prdMapList.isEmpty()) {
                    for(Product_Mapping__c pm : prdMapList) {
                        if(pm != null && String.isNotBlank(pm.Child_Depot__c)) {
                            pd.deliveryPlant = pm.Child_Depot__c;
                            break; 
                        }
                    }
                }
                
            }
            pd.uom = p.UOM__c;
            //pd.deliveryPlant = null;
            pd.uomConversion = p.Uom_Conversion__c;
            pd.netWeight = p.Net_Weight__c;
            pd.AlterNateUOM = p.Alternate_UOM__c;
            pd.taxClass = p.Tax_Class__c;
            pd.createdDate = p.CreatedDate.format('dd/MM/yyyy');
            pd.value = 0;
            pd.total = 0;
            pd.taxPercent = p.Tax_Percent__c;
            pd.hasApplicableSchemes = false;
            pd.appliedScheme = false;
            pd.index2 = index2++;
            allProducts.put(p.Id, pd);
            
        }
        
        String accSecCategory = acc.Secondary_Customer_Category__c;

        List<Scheme__c> schemes = [
            SELECT Id, Name, Description__c, Scheme_Start_Date__c, Scheme_End_Date__c,
            (SELECT Id, Product__c, Min__c, Sale_Value__c,Sale_Value_Threshold__c,Discount__c,Buy_Quantity__c, Product__r.Name
             FROM Buy_Products__r where Sales_Channel__c in:channelSet AND 
             (Secondary_Customer_Category__c = :accSecCategory) )
            FROM Scheme__c
            WHERE Scheme_Start_Date__c <= :Date.today()
            AND Scheme_End_Date__c >= :Date.today()
        ];
        List<schemeData> schemeList = new List<schemeData>();
        for (Scheme__c sch : schemes) {
            schemeData wrapper = new schemeData();
            wrapper.id = sch.Id;
            wrapper.name = sch.Name;
            wrapper.isSchemeSelected = false;
            wrapper.description = sch.Description__c;
            system.debug('sch.Buy_Products__r '+sch.Buy_Products__r);
            for (Buy_Product__c sli : sch.Buy_Products__r) {
                // Only attach schemes relevant to our products
                
                schemeLineItemData line = new schemeLineItemData();
                
                line.id = sli.Id;
                line.productId = sli.Product__c;
                line.offerProductId = sli.Product__c;
                line.offerProductName = sli.Product__r != null ? sli.Product__r.Name : null;
                line.isSelected = false;
                line.discountedPrice = 0;
                
                
                
                // 🔁 Determine scheme type
                if (sli.Buy_Quantity__c != 0 && sli.Min__c != 0) {
                    line.minQty = Integer.valueOf(sli.Min__c);
                    line.freeQty = Integer.valueOf(sli.Buy_Quantity__c);
                    line.schemeCategory = 'Free Product';
                    line.isFreeProduct = true;
                } else if (sli.Discount__c != 0) {
                    line.saleValueThreshold = sli.Sale_Value_Threshold__c;
                    line.discountPerUOM = sli.Discount__c;
                    line.schemeCategory = 'Per UOM Discount';
                    line.isPerUOMDiscount = true;
                } else if (sli.Sale_Value_Threshold__c != 0 && sli.Sale_Value__c != 0) {
                    line.saleValueThreshold = sli.Sale_Value_Threshold__c;
                    line.discountPercentOnSale = sli.Sale_Value__c;
                    line.schemeCategory = 'Sale Value Discount';
                    line.isSaleValueDiscount = true;
                }
                
                wrapper.lineItems.add(line);
            }
            
            if (!wrapper.lineItems.isEmpty()) {
                schemeList.add(wrapper);
            }
        }
        
        system.debug('schemeList.size() '+schemeList.size());
        system.debug('schemeList '+schemeList);
        
        Set<Id> allProductIds = new Set<Id>(allProducts.keySet());

        Map<String, List<productData>> strategyGroups = new Map<String, List<productData>>();
        Set<Id> coveredProductIds = new Set<Id>();
        
        // Step 4: Get Valid Strategies for those Products
        List<Sales_Strategy__c> strategies = [
            SELECT Id, Product__c, Type__c, Account__c, Region__c, User__c,Customer_Category__c, Must_Focused__c,Area__c
            FROM Sales_Strategy__c
            WHERE Product__c IN :allProductIds
            AND From_Date__c <= TODAY
            AND To_Date__c >= TODAY
        ];
        for (Sales_Strategy__c s : strategies) {
            Boolean match = false;
            if (s.Type__c == 'Customer' && s.Account__c == acc.Id){
                match = true;
            } 
            else if (s.Type__c == 'User' && s.User__c == currentUserId){
                match = true;
            } 
            else if (s.Type__c == 'Customer Category' && s.Customer_Category__c == acc.Secondary_Customer_Category__c){
                match = true;
            } 
            else if(s.Type__c == 'Area'){
                if(s.Area__c == 'All'){
                    match = true;
                }
                else{
                    if(areList != null && areList.size() > 0){
                        if(areList.contains(s.Area__c)){
                            match = true;
                        }
                    }
                    
                }
            }
            
            if (match && allProducts.containsKey(s.Product__c)) {
                String grp = String.isNotBlank(s.Must_Focused__c) ? s.Must_Focused__c : 'Others';
                if (!strategyGroups.containsKey(grp)) strategyGroups.put(grp, new List<productData>());
                strategyGroups.get(grp).add(allProducts.get(s.Product__c));
                coveredProductIds.add(s.Product__c);
            }
        }
        
        // Step 5: Remaining products => Others
        for (Id pid : allProductIds) {
            if (!coveredProductIds.contains(pid)) {
                if (!strategyGroups.containsKey('Others')) strategyGroups.put('Others', new List<productData>());
                strategyGroups.get('Others').add(allProducts.get(pid));
            }
        }
        
        // Step 6: Convert to grouped format
        List<strategyProductMapData> schemeProList = new List<strategyProductMapData>();
        Integer i = 0;
        for (String groupName : strategyGroups.keySet()) {
            schemeProList.add(new strategyProductMapData(
                String.valueOf(i++),
                groupName,
                null,
                null,
                strategyGroups.get(groupName)
            ));
        }
        
        responseData.strategyProductMapList = schemeProList;
        responseData.allProDtas = new List<productData>(allProducts.values());
        responseData.minumumOrderValue = us.Minimum_Order_value__c;
        responseData.schemessss = schemeList;
        return responseData;
    }
   
    //Get Sales Channel of Customer  
    public static Set<String> getProductsForSure(String accountId, String customerType) 
    {
        
        Id currentUserId = UserInfo.getUserId();
        User us = [
            SELECT Id, Name, Sales_Channel__c, Alternate_Sales_Channel__c 
            FROM User 
            WHERE Id = :currentUserId
        ];
        
        // Build the user's sales channel set
        Set<String> salesChannelList = new Set<String>();
        if (us.Alternate_Sales_Channel__c != null) {
            salesChannelList.addAll(us.Alternate_Sales_Channel__c.split(';'));
        } else if (us.Sales_Channel__c != null) {
            salesChannelList.addAll(us.Sales_Channel__c.split(';'));
        }
        
        Set<String> channelSet = new Set<String>();
        
        if (customerType == 'Primary Custmer') {
            channelSet = getPrimaryCustomerChannels(accountId, currentUserId, salesChannelList, us.Alternate_Sales_Channel__c);
        } else if (customerType == 'Secondary Customer') {
            channelSet = getSecondaryCustomerChannels(accountId, currentUserId, salesChannelList);
        }
        
        // Final fallback — return user's sales channel if nothing resolved
        if (channelSet.isEmpty()) {
            channelSet = salesChannelList;
        }
        
        return channelSet;
    }

    // PRIMARY: Direct query on Customer__c = accountId
    private static Set<String> getPrimaryCustomerChannels(String accountId, Id currentUserId,Set<String> salesChannelList, String alternateSalesChannel) {
        Set<String> channelSet = new Set<String>();
        
        List<Product_Mapping__c> primaryMappings;
        
        if (alternateSalesChannel == null) {
            // When no alternate channel, filter by executive
            primaryMappings = [
                SELECT Chanel__c 
                FROM Product_Mapping__c 
                WHERE Customer__c = :accountId 
                AND Exectuive__c = :currentUserId
            ];
            
            if(primaryMappings.isEmpty())
            {
                primaryMappings = [
                    SELECT Chanel__c 
                    FROM Product_Mapping__c 
                    WHERE Customer__c = :accountId 
                    AND Chanel__c IN :salesChannelList
                ];
            }
        }
        else {
            // When alternate channel exists, broader query with channel filter
            primaryMappings = [
                SELECT Chanel__c 
                FROM Product_Mapping__c 
                WHERE Customer__c = :accountId 
                AND Chanel__c IN :salesChannelList
            ];
        }
        
        for (Product_Mapping__c prodMap : primaryMappings) {
            if (prodMap.Chanel__c != null) {
                channelSet.add(prodMap.Chanel__c);
            }
        }
        
        return channelSet;
    }
    
    // SECONDARY: First get Primary Customer Ids, then resolve channels from those
    private static Set<String> getSecondaryCustomerChannels( String accountId,  Id currentUserId,  Set<String> salesChannelList ) 
    {
        Set<String> channelSet = new Set<String>();
        // Step 1: Get Primary Customer Ids linked to this Secondary Customer
        List<Product_Mapping__c> secondaryMappings = [
            SELECT Primary_Customer__c 
            FROM Product_Mapping__c 
            WHERE Customer__c = :accountId 
            AND Exectuive__c = :currentUserId
        ];
        
        if(secondaryMappings.isEmpty())
        {
            secondaryMappings = [
                SELECT Primary_Customer__c 
                FROM Product_Mapping__c 
                WHERE Customer__c = :accountId 
                AND Exectuive__r.Sales_Channel__c IN :salesChannelList
            ];
        }
        
        system.debug('secondaryMappings '+secondaryMappings);
        
        Set<String> primaryCustomerIds = new Set<String>();
        for (Product_Mapping__c prodMap : secondaryMappings) {
            if (prodMap.Primary_Customer__c != null) {
                primaryCustomerIds.add(prodMap.Primary_Customer__c);
            }
        }
        
        if (primaryCustomerIds.isEmpty()) {
            return channelSet; // Nothing to resolve
        }
        
        // Step 2: Query Product_Mapping__c using those Primary Customer Ids (with executive filter)
        List<Product_Mapping__c> primaryChannelMappings = [
            SELECT Chanel__c 
            FROM Product_Mapping__c 
            WHERE Customer__c IN :primaryCustomerIds 
            AND Chanel__c IN :salesChannelList 
            AND Exectuive__c = :currentUserId
        ];
        
        // Step 3: Fallback — same query without executive filter
        if (primaryChannelMappings.isEmpty()) {
            primaryChannelMappings = [
                SELECT Chanel__c 
                FROM Product_Mapping__c 
                WHERE Customer__c IN :primaryCustomerIds 
                AND Chanel__c IN :salesChannelList
            ];
        }
        
        for (Product_Mapping__c prodMap : primaryChannelMappings) {
            if (prodMap.Chanel__c != null) {
                channelSet.add(prodMap.Chanel__c);
            }
        }
        
        return channelSet;
    }
        
    //Area List to Filterout Price Books
    public static Set<String> getProductsForArea(string accountId,string customerType) {
        
        if(customerType == 'Secondary Customer'){
            Id currentUserId = UserInfo.getUserId();
            User us = [SELECT Id, Name, Sales_Channel__c FROM User WHERE Id = :currentUserId];
            
            set<String> sendBackAreaList = new Set<String>();
            Set<String> salesChannelList = new Set<String>();
            salesChannelList.addAll(us.Sales_Channel__c.split(';'));
            
            Set<String> channelSet = new Set<String>();
            Set<String> primaryCustomerIds = new Set<String>();
            
            List<Product_Mapping__c> prodMappingsFromPrimary = [SELECT Chanel__c, Primary_Customer__c ,Area__c,Area__r.Area__c
                                                                FROM Product_Mapping__c 
                                                                WHERE Exectuive__c = :currentUserId 
                                                                AND Customer__c = :accountId];
            
            // Populate channelSet and primaryCustomerIds
            for(Product_Mapping__c prodMap : prodMappingsFromPrimary) {
                if (prodMap.Chanel__c != null) {
                    channelSet.add(prodMap.Chanel__c);
                }
                if(prodMap.Area__c != null){
                    sendBackAreaList.add(prodMap.Area__r.Area__c);
                }
                if (prodMap.Primary_Customer__c != null) {
                    primaryCustomerIds.add(prodMap.Primary_Customer__c);
                }
                
            }
            
            if (!sendBackAreaList.isEmpty()) {
                return sendBackAreaList;
            } else {
                List<Product_Mapping__c> secondaryProductMappings = [
                    SELECT Chanel__c, Primary_Customer__c ,Area__c,Area__r.Area__c
                    FROM Product_Mapping__c 
                    WHERE Customer__c IN :primaryCustomerIds 
                    AND Chanel__c IN :salesChannelList 
                    AND Exectuive__c = :currentUserId
                ];
                
                // If no records found, use a broader query
                if (secondaryProductMappings.isEmpty()) {
                    secondaryProductMappings = [
                        SELECT Chanel__c, Primary_Customer__c,Area__c,Area__r.Area__c
                        FROM Product_Mapping__c 
                        WHERE Customer__c IN :primaryCustomerIds 
                        AND Chanel__c IN :salesChannelList
                    ];
                }
                
                // Populate the channelSet again
                for(Product_Mapping__c prodMap : secondaryProductMappings) {
                    if (prodMap.Chanel__c != null) {
                        channelSet.add(prodMap.Chanel__c);
                    }
                    if(prodMap.Area__c != null){
                        sendBackAreaList.add(prodMap.Area__r.Area__c);
                    }
                }
                if (!sendBackAreaList.isEmpty()) {
                    
                    return sendBackAreaList;
                } else {
                    return null;
                }
            }
            
            
        }
        else{
            return null;
        }
        
        
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAreaOptions() {
        // Create a list to hold the area options
        List<Map<String, String>> areaOptions = new List<Map<String, String>>();
        
        // Fetching the picklist values for the Area__c field in Territory__c
        Schema.DescribeFieldResult areaField = Area__c.Area__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = areaField.getPicklistValues();
        
        // Add a default "Select Area" option
        Map<String, String> defaultOption = new Map<String, String>();
        defaultOption.put('label', 'Select Area');
        defaultOption.put('value', '');
        areaOptions.add(defaultOption);
        
        // Add each available Territory picklist value as an object with 'label' and 'value'
        for (Schema.PicklistEntry entry : picklistValues) {
            Map<String, String> areaOption = new Map<String, String>();
            areaOption.put('label', entry.getLabel());
            areaOption.put('value', entry.getValue());
            areaOptions.add(areaOption);
        }
        
        return areaOptions;
    }
    
    //Getting Schemes
    @AuraEnabled(cacheable=true)
    global static CoverageDto getSchemeCoverageForAccount(Id accountId) {
        CoverageDto out = new CoverageDto();
        out.schemes = new List<CoverageScheme>();
        out.productSchemeIds = new Map<Id, List<Id>>();
        if (accountId == null) return out;
        
        Account acc = [
            SELECT Id, Secondary_Customer_Category__c, Customer_Type__c
            FROM Account WHERE Id = :accountId LIMIT 1
        ];
        // These schemes apply ONLY to Secondary Customers
        if (acc.Customer_Type__c != 'Secondary Customer') return out;

        Id currentUserId = UserInfo.getUserId();
        User us = [SELECT Id, Sales_Channel__c, Alternate_Sales_Channel__c
                   FROM User WHERE Id = :currentUserId];
        Set<String> salesChannelList = new Set<String>();
        if (us.Alternate_Sales_Channel__c != null) {
            salesChannelList.addAll(us.Alternate_Sales_Channel__c.split(';'));
        } else if (us.Sales_Channel__c != null) {
            salesChannelList.addAll(us.Sales_Channel__c.split(';'));
        }

        // channels of this secondary customer (reuses existing resolver)
        Set<String> channelSet = getSecondaryCustomerChannels(accountId, currentUserId, salesChannelList);
        if (channelSet.isEmpty()) channelSet = salesChannelList;

        // Region/Area/Territory from this customer's Product_Mapping rows
        AccountGeo geo = getSecondaryCustomerGeo(accountId, currentUserId, salesChannelList);
        if (geo == null) return out;   // no Product_Mapping at all -> no schemes

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
            // skip schemes that have no membership signal at all (no group + no category),
            // except Order Value which applies to the whole order
            if (s.Scheme_Product_Group__c == null && String.isBlank(s.Scheme_Product_Category__c) && s.Scheme_Type__c != 'Order Value') continue;
            Map<String, Set<String>> lvls = appByScheme.containsKey(s.Id) ? appByScheme.get(s.Id) : new Map<String, Set<String>>();
            
            Boolean regionOk = s.Apply_to_All_Regions__c == true
                || (lvls.containsKey('Region')   && anyMatch(lvls.get('Region'),   geo.regions));

            Boolean areaOk = s.Apply_to_All_Areas__c == true
                || (lvls.containsKey('Area')     && anyMatch(lvls.get('Area'),     geo.areas));

            Boolean territoryOk = s.Apply_to_All_Territories__c == true
                || (lvls.containsKey('Territory') && anyMatch(lvls.get('Territory'), geo.territoryIds));

            Boolean outletOk = s.Apply_to_All_Outlet_Categories__c == true
                || acc.Secondary_Customer_Category__c == null
                || (lvls.containsKey('Outlet Category') && lvls.get('Outlet Category').contains(acc.Secondary_Customer_Category__c));
            
            if (regionOk && outletOk && areaOk && territoryOk) {
                matched.add(s);
                if (s.Scheme_Product_Group__c != null) matchedGroupIds.add(s.Scheme_Product_Group__c);
            }
        }
        if (matched.isEmpty()) return out;
        
        Map<Id, List<CoverageProductRef>> productsByGroup = new Map<Id, List<CoverageProductRef>>();
        for (Scheme_Product_Group_Item__c it : [
            SELECT Scheme_Product_Group__c, Product__c, Product__r.Name, Product__r.SKU_Code__c
            FROM Scheme_Product_Group_Item__c
            WHERE Scheme_Product_Group__c IN :matchedGroupIds
            ORDER BY Product__r.Name
        ]) {
            if (it.Product__c == null) continue;
            if (!productsByGroup.containsKey(it.Scheme_Product_Group__c)) {
                productsByGroup.put(it.Scheme_Product_Group__c, new List<CoverageProductRef>());
            }
            CoverageProductRef p = new CoverageProductRef();
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

        // FOC giveaway products carry their own price/tax so the engine can add a free line.
        Map<Id, Product__c> focProducts = new Map<Id, Product__c>();
        if (!focProductIds.isEmpty()) {
            focProducts = new Map<Id, Product__c>([
                SELECT Id, Tax_Percent__c, List_Price__c, Price__c, MRP__c
                FROM Product__c WHERE Id IN :focProductIds
            ]);
        }

        for (Scheme__c s : matched) {
            CoverageScheme cs = new CoverageScheme();
            cs.id               = s.Id;
            cs.name             = s.Name;
            cs.schemeType       = s.Scheme_Type__c;
            cs.salesChannel     = s.Sales_Channel__c;
            cs.startDate        = s.Scheme_Start_Date__c;
            cs.endDate          = s.Scheme_End_Date__c;
            cs.validLabel       = formatDdMmYyyy(s.Scheme_Start_Date__c) + ' to ' + formatDdMmYyyy(s.Scheme_End_Date__c);
            cs.productGroupId   = s.Scheme_Product_Group__c;
            cs.productGroupName = s.Scheme_Product_Group__r == null ? null : s.Scheme_Product_Group__r.Name;
            cs.productCategory  = s.Scheme_Product_Category__c;
            cs.products         = productsByGroup.containsKey(s.Scheme_Product_Group__c)
                ? productsByGroup.get(s.Scheme_Product_Group__c)
                : new List<CoverageProductRef>();
            cs.slabRows         = buildSlabRows(s.Scheme_Type__c, slabsByScheme.get(s.Id));
            cs.groupProductIds  = new List<Id>();
            for (CoverageProductRef p : cs.products) cs.groupProductIds.add(p.id);
            cs.slabsRaw         = buildSlabsRaw(slabsByScheme.get(s.Id), focProducts);
            out.schemes.add(cs);
            for (CoverageProductRef p : cs.products) {
                if (!out.productSchemeIds.containsKey(p.id)) out.productSchemeIds.put(p.id, new List<Id>());
                out.productSchemeIds.get(p.id).add(s.Id);
            }
        }
        return out;
    }
    
    private class AccountGeo {
        Set<String> regions      = new Set<String>();
        Set<String> areas        = new Set<String>();
        Set<String> territoryIds = new Set<String>();
    }

    // Region/Area/Territory for a Secondary Customer from its own Product_Mapping rows.
    // Mirrors getSecondaryCustomerChannels: executive filter first, sales-channel fallback.
    private static AccountGeo getSecondaryCustomerGeo(Id accountId, Id currentUserId,
                                                      Set<String> salesChannelList) {
        List<Product_Mapping__c> mappings = [
            SELECT Area__c, Area_Area_Name__c, Region_Name__c
            FROM Product_Mapping__c
            WHERE Customer__c = :accountId AND Exectuive__c = :currentUserId
        ];
        if (mappings.isEmpty()) {
            mappings = [
                SELECT Area__c, Area_Area_Name__c, Region_Name__c
                FROM Product_Mapping__c
                WHERE Customer__c = :accountId
                AND Exectuive__r.Sales_Channel__c IN :salesChannelList
            ];
        }
        if (mappings.isEmpty()) return null;   // signal: no mapping -> no schemes

        AccountGeo geo = new AccountGeo();
        for (Product_Mapping__c pm : mappings) {
            if (String.isNotBlank(pm.Region_Name__c))    geo.regions.add(pm.Region_Name__c);
            if (String.isNotBlank(pm.Area_Area_Name__c)) geo.areas.add(pm.Area_Area_Name__c);
            if (pm.Area__c != null)                      geo.territoryIds.add(String.valueOf(pm.Area__c));
        }
        return geo;
    }

    public static Boolean anyMatch(Set<String> allowed, Set<String> have) {
        if (allowed == null || have == null) return false;
        for (String v : have) { if (allowed.contains(v)) return true; }
        return false;
    }

    // Resolve a FOC product's own selling price (mirrors line-item price fallback).
    private static Decimal resolveFocPrice(Product__c p) {
        if (p == null) return 0;
        if (p.List_Price__c != null && p.List_Price__c > 0) return p.List_Price__c;
        if (p.Price__c != null && p.Price__c > 0) return p.Price__c;
        if (p.MRP__c != null) return p.MRP__c;
        return 0;
    }

    private static List<CoverageSlabRaw> buildSlabsRaw(List<Scheme_Slab__c> slabs, Map<Id, Product__c> focProducts) {
        List<CoverageSlabRaw> rows = new List<CoverageSlabRaw>();
        if (slabs == null || slabs.isEmpty()) return rows;
        for (Scheme_Slab__c sl : slabs) {
            CoverageSlabRaw r = new CoverageSlabRaw();
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
                r.focUnitPrice = resolveFocPrice(fp);
                r.focTaxPercent = fp.Tax_Percent__c;
            }
            rows.add(r);
        }
        return rows;
    }

    public static List<CoverageSlabRow> buildSlabRows(String schemeType, List<Scheme_Slab__c> slabs) {
        List<CoverageSlabRow> rows = new List<CoverageSlabRow>();
        if (slabs == null || slabs.isEmpty()) return rows;
        Boolean multi = slabs.size() > 1;
        Integer i = 1;
        for (Scheme_Slab__c sl : slabs) {
            String label = multi ? 'Tier ' + i : 'Offer';
            String sentence = slabSentence(schemeType, sl);
            if (sentence != null) rows.add(new CoverageSlabRow(label, sentence));
            i++;
        }
        return rows;
    }
    
    public static String slabSentence(String schemeType, Scheme_Slab__c sl) {
        if (schemeType == 'Free Quantity') {
            String buy = buyThresholdClause(sl.Qualifying_Qty_Min__c, sl.Qualifying_Qty_Max__c);
            if (buy == null || sl.Free_Qty__c == null) return null;
            return '🛒 ' + buy + ' → 🎁 Get ' + decToStr(sl.Free_Qty__c) + ' EA Free';
        } else if (schemeType == 'QPS') {
            String buy = buyQtyClause(sl.Qualifying_Qty_Min__c, sl.Qualifying_Qty_Max__c);
            if (buy == null || sl.Benefit_Amount_Per_EA__c == null) return null;
            return '🛒 ' + buy + ' → 💰 ₹' + decToStr(sl.Benefit_Amount_Per_EA__c) + ' off per EA';
        } else if (schemeType == 'FOC Giveaway') {
            String buy = buyThresholdClause(sl.Qualifying_Qty_Min__c, sl.Qualifying_Qty_Max__c);
            if (buy == null || sl.Free_Qty__c == null) return null;
            String focName = (sl.FOC_Product__c != null && sl.FOC_Product__r != null) ? sl.FOC_Product__r.Name : 'free product';
            return '🛒 ' + buy + ' → 🎁 Get ' + decToStr(sl.Free_Qty__c) + ' EA of ' + focName + ' Free';
        } else if (schemeType == 'Order Value' || schemeType == 'Category Value') {
            String order = orderValueClause(sl.Qualifying_Value_Min__c, sl.Qualifying_Value_Max__c);
            if (order == null || sl.Benefit_Percent__c == null) return null;
            return '🛒 ' + order + ' → 💰 ' + decToStr(sl.Benefit_Percent__c) + '% Off';
        }
        return null;
    }
    
    public static String buyThresholdClause(Decimal mn, Decimal mx) {
        if (mn == null) return null;
        if (mx == null || mn == mx) return 'Buy ' + decToStr(mn) + ' EA';
        return 'Buy ' + decToStr(mn) + ' to ' + decToStr(mx) + ' EA';
    }
    
    public static String buyQtyClause(Decimal mn, Decimal mx) {
        if (mn == null) return null;
        if (mx == null) return 'Buy ' + decToStr(mn) + ' EA';
        if (mn == mx)   return 'Buy ' + decToStr(mn) + ' EA';
        return 'Buy ' + decToStr(mn) + ' to ' + decToStr(mx) + ' EA';
    }
    
    public static String orderValueClause(Decimal mn, Decimal mx) {
        if (mn == null) return null;
        if (mx == null) return 'Order ₹' + decToStr(mn) + ' or more';
        return 'Order ₹' + decToStr(mn) + ' to ₹' + decToStr(mx);
    }
    public static String decToStr(Decimal d) {
        if (d == null) return '';
        if (d == d.setScale(0)) return String.valueOf(d.setScale(0));
        return String.valueOf(d);
    }
    public static String formatDdMmYyyy(Date d) {
        if (d == null) return '';
        String dd = String.valueOf(d.day()).leftPad(2, '0');
        String mm = String.valueOf(d.month()).leftPad(2, '0');
        return dd + '-' + mm + '-' + String.valueOf(d.year());
    }
    
    

    /*
    public static Set<String> getProductsForSure1(string accountId,string customerType) {
        
        Id currentUserId = UserInfo.getUserId();
        User us = [SELECT Id, Name, Sales_Channel__c,Alternate_Sales_Channel__c FROM User WHERE Id = :currentUserId];
        
        Set<String> salesChannelList = new Set<String>();
        if(us.Alternate_Sales_Channel__c != null)
        {
            salesChannelList.addAll(us.Alternate_Sales_Channel__c.split(';'));
        }
        else if(us.Sales_Channel__c != null){
            salesChannelList.addAll(us.Sales_Channel__c.split(';'));
        }
        
        
        Set<String> channelSet = new Set<String>();
        Set<String> primaryCustomerIds = new Set<String>();
        if(us.Alternate_Sales_Channel__c == null){
            List<Product_Mapping__c> prodMappingsFromPrimary = [SELECT Chanel__c, Primary_Customer__c 
                                                                FROM Product_Mapping__c 
                                                                WHERE Exectuive__c = :currentUserId 
                                                                AND Customer__c = :accountId];
            
            // Populate channelSet and primaryCustomerIds
            for(Product_Mapping__c prodMap : prodMappingsFromPrimary) {
                if (prodMap.Chanel__c != null) {
                    channelSet.add(prodMap.Chanel__c);
                }
                if (prodMap.Primary_Customer__c != null) {
                    primaryCustomerIds.add(prodMap.Primary_Customer__c);
                }
            }
        }
        
        if (!channelSet.isEmpty()) {
            return channelSet;
        }
        else {
            List<Product_Mapping__c> secondaryProductMappings = [
                SELECT Chanel__c, Primary_Customer__c 
                FROM Product_Mapping__c 
                WHERE Customer__c IN :primaryCustomerIds 
                AND Chanel__c IN :salesChannelList 
                AND Exectuive__c = :currentUserId
            ];
            
            // If no records found, use a broader query
            if (secondaryProductMappings.isEmpty()) {
                secondaryProductMappings = [
                    SELECT Chanel__c, Primary_Customer__c 
                    FROM Product_Mapping__c 
                    WHERE Customer__c IN :primaryCustomerIds 
                    AND Chanel__c IN :salesChannelList
                ];
            }
            
            // Populate the channelSet again
            for(Product_Mapping__c prodMap : secondaryProductMappings) {
                if (prodMap.Chanel__c != null) {
                    channelSet.add(prodMap.Chanel__c);
                }
            }
            if (!channelSet.isEmpty()) {
                return channelSet;
            } else {
                List<Product_Mapping__c> primaryCustomerMapping = [
                    SELECT Chanel__c, Primary_Customer__c 
                    FROM Product_Mapping__c 
                    WHERE Customer__c =:accountId 
                    AND Chanel__c IN :salesChannelList 
                ];
                
                // Populate the channelSet again
                for(Product_Mapping__c prodMap : primaryCustomerMapping) {
                    if (prodMap.Chanel__c != null) {
                        channelSet.add(prodMap.Chanel__c);
                    }
                }
                if (!channelSet.isEmpty()) {
                    return channelSet;
                }
                else
                {
                    channelSet = salesChannelList;
                    return channelSet;
                }
                
                
            }
        }
        
        
        
    }
	*/
    

    /**Display Format Data **/
    @AuraEnabled
    public static LeadWrapper createLead(String name, String phone, String location, List<String> photoDocIds, Id visitId) {
        system.debug('===> ' + name + phone + location);
        
        Lead newLead = new Lead(
            LastName = name,
            Phone = phone,
            Street = location,
            Company = 'Temp Company',
            Visit__c = visitId 
        );
        insert newLead;
        
        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
        List<String> photoUrls = new List<String>();
        
        if (photoDocIds != null && !photoDocIds.isEmpty()) {
            for (String docId : photoDocIds) {
                linksToInsert.add(new ContentDocumentLink(
                    ContentDocumentId = docId,
                    LinkedEntityId = newLead.Id,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                ));
                photoUrls.add('/sfc/servlet.shepherd/document/download/' + docId);
            }
            insert linksToInsert;
        }
        
        return new LeadWrapper(newLead, photoUrls, photoDocIds);
    }
    @AuraEnabled
    public static data getDisplayFormats(id visitId,String accountId) {
        data db = new data();
        db.displayformatData =  [SELECT Id,SKU__c,SKU__r.Name, Display__c FROM Display_Format__c where Visit__c =:visitId];
        db.shelfStockdata = [
            SELECT Id, Visit__c, SKU__c,skuName__c,SKU__r.Name,Stock_Level__c
            FROM Shelf_Stock__c 
            WHERE Visit__c =:visitId
        ];
        Account acc = [
            SELECT Id, Name, Region__c, Customer_Type__c, Secondary_Customer_Category__c 
            FROM Account 
            WHERE Id = :accountId
        ];
        
        db.productList = getProducts(accountId,acc.Customer_Type__c); 
        return db;
    }
    @AuraEnabled
    public static Display_Format__c saveDisplayFormat(Display_Format__c format) {
        upsert format;
        Display_Format__c savedFormat = [
            SELECT Id, Display__c, Visit__c, SKU__c, SKU__r.Name 
            FROM Display_Format__c 
            WHERE Id = :format.Id 
            LIMIT 1
        ];
        return savedFormat;
    }
    @AuraEnabled
    public static void deleteDisplayFormat(Id recordId) {
        delete [SELECT Id FROM Display_Format__c WHERE Id = :recordId];
    }
    @AuraEnabled
    public static Display_Format__c getDisplayFormatDetails(Id recordId) {
        return [SELECT Id, SKU__c,SKU__r.Name, Display__c FROM Display_Format__c WHERE Id = :recordId LIMIT 1];
    }
    @AuraEnabled
    public static List<ContentDocumentLink> getFilesForDisplayFormat(String recordId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ];
        
        return links;
    }
    
    /**Order fulfilment Data **/
    @AuraEnabled
    public static List<Order__c> getUnfulfilledOrders(id accountid) {
        return [SELECT Id, Name,Account__r.Name,Order_Type__c, Order_Fulfillment_Status__c,Order_Date__c FROM Order__c WHERE Account__c =:accountid AND Order_Fulfillment_Status__c = 'Not Fulfilled'];
    }
    @AuraEnabled
    public static List<Order_Item__c> getOrderLineItems(Id orderId) {
        return [
            SELECT Id, Name, Product__r.Name, Quantity__c,Status__c,Delivered_Quantity__c ,Unit_Price__c, Total_Amount__c, Tax_Amount__c
            FROM Order_Item__c
            WHERE Order__c = :orderId
        ];
    }
    @AuraEnabled
    public static void saveOrderLineItems(List<Order_Item__c> updatedItems, Date billDate, Decimal billQuantity, decimal billValue,string billNumber,id orderId,id visitId,string status) {
        if (updatedItems == null || updatedItems.isEmpty())
            return;
        
        
        update updatedItems;
        system.debug('status'+status);
        
        List<Order_Item__c> orderItems = [
            SELECT Id, Status__c
            FROM Order_Item__c
            WHERE Order__c = :orderId
        ];
        
        
        if (status != null) {
            // Step 4: Fetch the Order record to check mandatory fields
            Order__c orderRecord = [
                SELECT Id, DB_Bill_Date__c, DB_Bill_Quantity__c, DB_Bill_Value__c,DB_Bill_Number__c
                FROM Order__c
                WHERE Id = :orderId
                LIMIT 1
            ];
            
            // Step 5: Update Order with new Billing info
            orderRecord.DB_Bill_Date__c = billDate;
            orderRecord.DB_Bill_Quantity__c = billQuantity;
            orderRecord.DB_Bill_Value__c = billValue;
            orderRecord.DB_Bill_Number__c = billNumber;
            
            
            // Validate mandatory fields
            if (orderRecord.DB_Bill_Date__c == null ||
                orderRecord.DB_Bill_Quantity__c == null ||
                orderRecord.DB_Bill_Value__c == null || orderRecord.DB_Bill_Number__c == null) {
                    throw new AuraHandledException('Please fill Billing Date, Billing Amount, and Distributor before saving the Order.');
                }
            
            orderRecord.Orderfulfilment_Date__c = System.now().date();
            orderRecord.Order_Fulfillment_Status__c = status;
            orderRecord.Order_Fulfillment_visit__c =visitId;
            update orderRecord;
        }
    }
    
    /**Shelf Stock **/
    @AuraEnabled
    public static Shelf_Stock__c saveShelfStock(Shelf_Stock__c ShelfStock, List<Shelf_Stock_Items__c> ShelfStockItems, List<String> uploadedFileIds) {
        system.debug('ShelfStock'+ ShelfStock);
        system.debug('ShelfStockItems' + ShelfStockItems);
        system.debug('uploadedFileIds' +uploadedFileIds);
        insert ShelfStock;
        
        // 2. Link uploaded files to the main Shelf_Stock__c record
        if (uploadedFileIds != null && !uploadedFileIds.isEmpty()) {
            List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
            for (String docId : uploadedFileIds) {
                linksToInsert.add(new ContentDocumentLink(
                    ContentDocumentId = docId,
                    LinkedEntityId = ShelfStock.Id,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                ));
            }
            insert linksToInsert;
        }
        
        // 3. Handle ShelfStockItems (child list)
        if (ShelfStockItems != null && !ShelfStockItems.isEmpty()) {
            for (Shelf_Stock_Items__c item : ShelfStockItems) {
                item.Shelf_Stock__c = ShelfStock.Id;
                
            }
            insert ShelfStockItems;
        }
        
        // 4. Return the latest version of the parent record
        Shelf_Stock__c updatedRecord = [
            SELECT Id, Visit__c
            FROM Shelf_Stock__c
            WHERE Id = :ShelfStock.Id
            LIMIT 1
        ];
        return updatedRecord;
    }
    @AuraEnabled    
    public static Shelf_Stock__c getshelfstockDetails(Id recordId) {
        return [
            SELECT Id, Visit__c, SKU__c,skuName__c,SKU__r.Name,Stock_Level__c,Sales_Quantity__c,Comments_Compition_Remarks__c
            FROM Shelf_Stock__c 
            WHERE Id = :recordId
            LIMIT 1
        ];
    }
    
    
    
    
    
    
    
    public static void updateTargetTotals(Set<Id> targetIds) {
        // Maps to store aggregated sums for Actual__c and Target_Value__c
        Map<Id, Decimal> actualSumMap = new Map<Id, Decimal>();
        Map<Id, Decimal> targetSumMap = new Map<Id, Decimal>();
        
        // Aggregate SUM of Actual_Value__c and Target_Value__c for each Target__c
        for (AggregateResult result : [
            SELECT Target__c, SUM(Actual_Value__c) totalActualValue, SUM(Target_Value__c) totalTarget
            FROM Target_Item__c
            WHERE Target__c IN :targetIds
            GROUP BY Target__c
        ]) {
            actualSumMap.put((Id) result.get('Target__c'), (Decimal) result.get('totalActualValue'));
            targetSumMap.put((Id) result.get('Target__c'), (Decimal) result.get('totalTarget'));
        }
        
        // Prepare list of Target__c records to update
        List<Target__c> targetsToUpdate = new List<Target__c>();
        for (Id targetId : targetIds) {
            Target__c targetRecord = new Target__c(
                Id = targetId,
                Actual__c = actualSumMap.containsKey(targetId) ? actualSumMap.get(targetId) : 0,
                Target__c = targetSumMap.containsKey(targetId) ? targetSumMap.get(targetId) : 0
            );
            targetsToUpdate.add(targetRecord);
        }
        
        // Update the Target__c records
        if (!targetsToUpdate.isEmpty()) {
            update targetsToUpdate;
        }
    }
    /* Saving Photo images */
    @AuraEnabled
    global static String saveFile(String parentId, String fileName, String base64Data) {
        return FileController.saveFile(parentId, fileName, base64Data,'');
    }
    /* inserting order */
    @AuraEnabled
    global static data upsertOrder(String accId, String visId, String logId, String ordersData, String orderRecordId,decimal ClockInLocationLongitude, decimal ClockInLocationLatitude ) {
        data dt = new data();
        List<Order__c> createdOrders = new List<Order__c>();
        List<Order_Item__c> allOrderItems = new List<Order_Item__c>();
        Date today = Date.today();
        AggregateResult[] maxSNumResult = [
            SELECT MAX(SNUM__c) maxSNum
            FROM Order__c
            WHERE Order_Date__c = :today with SYSTEM_MODE
        ];
        
        //Added Durga Getting the SaleOrganization to Delivary Plant dependency Map - 20/12/2025
        Map<String, Map<String, String>> salesOranizationToDelivaryPlant = newCustomerLwcController.getDependentMap(new Product_Mapping__c(), 'Parent_Depot__c', 'Child_Depot__c');
        Map<String, String> deliveryPlantToSalesOrg = new Map<String, String>();
        
        for (String salesOrg : salesOranizationToDelivaryPlant.keySet()) {
            for (String plant : salesOranizationToDelivaryPlant.get(salesOrg).keySet()) {
                deliveryPlantToSalesOrg.put(plant, salesOrg);
            }
        }

        
        list<Visit__c> visits = [select Id,OrderCreated__c,Beat_Name__c from Visit__c where Id =:visId];
        if(!visits.isEmpty())
        {
            Visit__c vs = new Visit__c();
            vs.Id = visits[0].Id;
            vs.OrderCreated__c = true;
            update vs;
        }
        
        // Resolve Beat Name for order
        String beatNameVal = '';
        if (!visits.isEmpty() && visits[0].Beat_Name__c != null) {
            beatNameVal = visits[0].Beat_Name__c;
        } else if (accId != null) {
            Id currentUserId = UserInfo.getUserId();
            List<Junction_Beat__c> jbList = [
                SELECT Child_beat__r.Name
                FROM Junction_Beat__c
                WHERE Account__c = :accId
                AND Child_beat__r.OwnerId = :currentUserId
                LIMIT 1
            ];
            if (!jbList.isEmpty()) {
                beatNameVal = jbList[0].Child_beat__r.Name;
            } else {
                List<Junction_Beat__c> jbListAll = [
                    SELECT Child_beat__r.Name
                    FROM Junction_Beat__c
                    WHERE Account__c = :accId
                    LIMIT 1
                ];
                if (!jbListAll.isEmpty()) {
                    beatNameVal = jbListAll[0].Child_beat__r.Name;
                }
            }
        }

        // Step 1: Deserialize ordersData into List<Object>
        List<Object> rawList = (List<Object>) JSON.deserializeUntyped(ordersData);
        
        // Step 2: Initialize plantOrders to hold the parsed data
        List<Map<String, Object>> plantOrders = new List<Map<String, Object>>();
        
        // Step 3: Safely cast each item in rawList into a Map<String, Object> if it is indeed a map
        for (Object o : rawList) {
            if (o instanceof Map<String, Object>) {
                plantOrders.add((Map<String, Object>) o);
            } else {
                // If the item is not a Map, log it and handle appropriately
                System.debug('Unexpected type in rawList: ' + o);
                throw new AuraHandledException('Unexpected data format in ordersData.');
            }
        }
        
        // Step 4: Debugging the structure of plantOrders
        System.debug('plantOrders after deserialization: ' + JSON.serialize(plantOrders));
        
        // Step 5: Get Account and Visit details
        Account acc = [SELECT Id, Name, Customer_Type__c,GeoLocation__Longitude__s,GeoLocation__Latitude__s  FROM Account WHERE Id = :accId];
        
        // Get the PDP days for this account - may return null
        Set<String> pdpDays = getPDPDays(acc.Id, 'Primary Customer');
        Map<String,Product_Mapping__c> channltoPM = new Map<String,Product_Mapping__c>();
        List<Product_Mapping__c> prdMapList = new List<Product_Mapping__c>();
        if(acc.Customer_Type__c == 'Primary Customer'){
            prdMapList = getProductMappins(acc.Id);
            system.debug('prdMapList '+prdMapList);
        }
        if(prdMapList != null && !prdMapList.isEmpty()){
            for(Product_Mapping__c pm : prdMapList){
                channltoPM.put(pm.Chanel__c,pm);
            }
        }
        system.debug('channltoPM '+channltoPM);
        List<Sales_Channel_To_SKU__c> channels = [SELECT Id, Name, SKU__c,Delivery_Plant__c,Sales_Channel__c,UOM__c FROM Sales_Channel_To_SKU__c WHERE Sales_Channel__c IN :channltoPM.keySet()];
        Map<Id, List<Sales_Channel_To_SKU__c>> productToChannelsMap = new Map<Id, List<Sales_Channel_To_SKU__c>>();
        Map<Id, String> skuToSKU = new Map<Id, String>();
        for (Sales_Channel_To_SKU__c channel : channels) {
            skuToSKU.put(channel.SKU__c,channel.UOM__c);
            if(channel.Delivery_Plant__c != null){
                if (!productToChannelsMap.containsKey(channel.SKU__c)) {
                    productToChannelsMap.put(channel.SKU__c, new List<Sales_Channel_To_SKU__c>());
                }
                productToChannelsMap.get(channel.SKU__c).add(channel);
            }
            
        }
        // Default to Non-PDP day if we have no PDP days defined
        Boolean isPDPOrderDay = false;
        
        // Only proceed with day checking if we have valid PDP days
        if (pdpDays != null && !pdpDays.isEmpty()) {
            // Get today's and tomorrow's day names in lowercase for case-insensitive comparison
            String todayDay = DateTime.now().format('EEEE').toLowerCase();
            String tomorrowDay = DateTime.now().addDays(1).format('EEEE').toLowerCase();
            
            // Convert PDP days to lowercase for consistent comparison
            Set<String> pdpDaysLower = new Set<String>();
            for (String day : pdpDays) {
                if (day != null) {
                    pdpDaysLower.add(day.toLowerCase());
                }
            }
            
            // Check if either today or tomorrow is a PDP day
            isPDPOrderDay = pdpDaysLower.contains(todayDay) || 
                pdpDaysLower.contains(tomorrowDay);
        }
        
        // Now use the flag appropriately
        if (isPDPOrderDay) {
            isPDPOrderDay = true;
            // PDP day logic here
        } else {
            isPDPOrderDay = false;
            // Non-PDP day logic here
        }
        
        Visit__c vis = visId != null ? [SELECT Id, Visit_for__c FROM Visit__c WHERE Id = :visId LIMIT 1] : null;
        
        // Check if we're updating an existing order
        Boolean isUpdate = String.isNotBlank(orderRecordId);
        
        // Step 6: Loop through each plant order
        for (Map<String, Object> plantOrder : plantOrders) {
            // Create/update the Order__c record
            Order__c ord;
            
            if (isUpdate) {
                // Get existing order for update
                ord = [SELECT Id, Order_Date__c, Delivery_To__c, Expected_Delivery_Date__c, 
                       OwnerId, PO_DATE__c, PO_NUM__c, Delivery_Plant__c, PDP_Other_Type__c,
                       Account__c, Lead__c, Visit__c, Customer_Type__c, Order_Type__c,
                       Order_Type1__c, Division__c, Sales_Organization__c, Distribution_Channel__c
                       FROM Order__c WHERE Id = :orderRecordId LIMIT 1];
            } else {
                // Create new order
                ord = new Order__c();
                ord.Order_Date__c = System.today();
            }
            
            // Update order fields (for both new and existing orders)
            ord.Delivery_To__c = (String)plantOrder.get('deliveryTo');
            ord.Expected_Delivery_Date__c = Date.valueOf((String)plantOrder.get('expectedDate'));
            if (plantOrder.get('orderOwnerId') != null && plantOrder.get('orderOwnerId') != '') {
                ord.OwnerId = (Id) String.valueOf(plantOrder.get('orderOwnerId'));
                ord.Executive__c = (String)plantOrder.get('orderOwnerId');
            }
            
            String rawDate = String.valueOf(plantOrder.get('poDate'));
            System.debug('rawDate: ' + rawDate);
            ord.PO_DATE__c = String.isNotBlank(rawDate) ? Date.valueOf(rawDate) : null;
            
            ord.PO_NUM__c = plantOrder.get('poNum') != null ? String.valueOf(plantOrder.get('poNum')) : null;
            String plantName = (String)plantOrder.get('plantName');
            ord.Delivery_Plant__c = (plantName == 'All Products') ? null : plantName.replace('Delivery Plant : ', '').trim();
            ord.PDP_Other_Type__c = null;

            // Scheme engine (productScreen4) header-level discounts
            ord.Category_Discount__c = asDecimal(plantOrder.get('categoryDiscount'));
            ord.Order_Value_Discount__c = asDecimal(plantOrder.get('orderValueDiscount'));
            
            // Set Account and Visit relationships (only for new orders)
            if (!isUpdate) {
                if (vis != null) {
                    if (vis.Visit_for__c == 'Lead') {
                        ord.Lead__c = accId;
                    } else {
                        ord.Account__c = accId;
                    }
                    ord.Visit__c = visId;
                } else {
                    ord.Account__c = accId;
                }
                ord.Clock_In_Location__Longitude__s = ClockInLocationLongitude;
                ord.Clock_In_Location__Latitude__s = ClockInLocationLatitude;
                if(acc.GeoLocation__Latitude__s != null && acc.GeoLocation__Longitude__s != null &&
                  ClockInLocationLongitude != null && ClockInLocationLatitude != null)
                {
                    ord.Customer_Location__Longitude__s = acc.GeoLocation__Longitude__s;
                    ord.Customer_Location__Latitude__s = acc.GeoLocation__Latitude__s;
                    
                    Decimal radStoreLat = Math.PI / 180 * acc.GeoLocation__Latitude__s;
                    Decimal radStoreLon = Math.PI / 180 * acc.GeoLocation__Longitude__s;
                    Decimal radVisitLat = Math.PI / 180 * ClockInLocationLatitude;
                    Decimal radVisitLon = Math.PI / 180 * ClockInLocationLongitude;
                    
                    Decimal dLat = radVisitLat - radStoreLat;
                    Decimal dLon = radVisitLon - radStoreLon;
                    
                    Decimal a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                        Math.cos(radStoreLat) * Math.cos(radVisitLat) *
                        Math.sin(dLon / 2) * Math.sin(dLon / 2);
                    
                    Decimal c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
                    Decimal earthRadius = 6371000; // in meters
                    Decimal distance = earthRadius * c;
                    
                    System.debug('Calculated Distance (meters): ' + distance);
                    
                    Decimal geoFencingInMeters = 100;
                    
                    if (String.isNotBlank(Label.geoFencingInMeters)) {
                        geoFencingInMeters = Decimal.valueOf(Label.geoFencingInMeters);
                    }
                    
                    if (distance > geoFencingInMeters) {
                        ord.Location_Type__c = 'Out Location';
                    }
                    else
                    {
                        ord.Location_Type__c = 'In Location';
                    } 
                }
                else
                {
                    ord.Location_Type__c = 'Out Location';
                }
            }
            
            ord.Customer_Type__c = acc.Customer_Type__c;
            ord.Order_Type__c = acc.Customer_Type__c == 'Primary Customer' ? 'Primary Order' : 'Secondary Order';
            if(isPDPOrderDay == true){
                ord.PDP_Other_Type__c = 'PDP Day Order';
            }
            else{
                ord.PDP_Other_Type__c = 'Non PDP Day Order';
            }
            if (prdMapList != null && !prdMapList.isEmpty()){
                ord.Order_Type1__c = prdMapList[0].Order_Type__c;
                ord.Division__c = prdMapList[0].Division__c;
                
                //Getting Sales Organzation based on delivary plant - added on 20/12/2025
                if(deliveryPlantToSalesOrg.containsKey(ord.Delivery_Plant__c))
                {
                    ord.Sales_Organization__c = deliveryPlantToSalesOrg.get(ord.Delivery_Plant__c);
                }
                else
                {
                    ord.Sales_Organization__c = prdMapList[0].Parent_Depot__c;
                }
                ord.Distribution_Channel__c = prdMapList[0].Distribution_Channel__c;
            }
            ord.Beat_Name_New__c = beatNameVal;
            createdOrders.add(ord);
        }

        // Upsert all orders
        upsert createdOrders;
        
        // If updating, delete existing order items first
        if (isUpdate) {
            List<Order_Item__c> existingItems = [SELECT Id FROM Order_Item__c WHERE Order__c = :orderRecordId];
            if (!existingItems.isEmpty()) {
                delete existingItems;
            }
            // Order_Scheme_Applied__c is master-detail to Order__c, not Order_Item__c — clear it too
            List<Order_Scheme_Applied__c> existingApplied = [SELECT Id FROM Order_Scheme_Applied__c WHERE Order_Request__c = :orderRecordId];
            if (!existingApplied.isEmpty()) {
                delete existingApplied;
            }
        }
        
        // Scheme engine: applied-scheme audit rows (Order_Scheme_Applied__c)
        List<Order_Scheme_Applied__c> allAppliedSchemes = new List<Order_Scheme_Applied__c>();
        // product id per OSA row (same index) so Order_Item__c can be resolved after items insert
        List<Id> osaProductIds = new List<Id>();

        // Step 7: Process the products for each plant order
        for (Integer i = 0; i < plantOrders.size(); i++) {
            // Here, we retrieve the 'products' as a List<Object> and manually convert each to Map<String, Object>
            List<Object> rawProducts = (List<Object>) plantOrders[i].get('products');
            
            // Now, we process rawProducts to ensure it's a List<Map<String, Object>>
            List<Map<String, Object>> products = new List<Map<String, Object>>();
            
            for (Object p : rawProducts) {
                if (p instanceof Map<String, Object>) {
                    products.add((Map<String, Object>) p);
                } else {
                    // If the item is not a Map, log it and handle appropriately
                    System.debug('Unexpected type in products: ' + p);
                    throw new AuraHandledException('Unexpected data format in products.');
                }
            }
            
            Id orderId = createdOrders[i].Id;
            Integer orderItemNu = 0;
            List<Order_Item__c> orderItemsToSort = new List<Order_Item__c>();

            // Build Order_Scheme_Applied__c audit rows for this order (header-level)
            Object appliedRaw = plantOrders[i].get('appliedSchemes');
            if (appliedRaw instanceof List<Object>) {
                for (Object ao : (List<Object>) appliedRaw) {
                    if (!(ao instanceof Map<String, Object>)) continue;
                    Map<String, Object> a = (Map<String, Object>) ao;
                    Order_Scheme_Applied__c osa = new Order_Scheme_Applied__c();
                    osa.Order_Request__c = orderId;
                    Object sId = a.get('schemeId');
                    if (sId != null && String.isNotBlank(String.valueOf(sId))) osa.Scheme__c = (Id) String.valueOf(sId);
                    Object slId = a.get('slabId');
                    if (slId != null && String.isNotBlank(String.valueOf(slId))) osa.Scheme_Slab__c = (Id) String.valueOf(slId);
                    osa.Scheme_Type__c = (String) a.get('schemeType');
                    osa.Free_Qty__c = asDecimal(a.get('freeQty'));
                    osa.Benefit_Amount__c = asDecimal(a.get('benefitAmount'));
                    osa.Discount_Percent__c = asDecimal(a.get('discountPercent'));
                    osa.Sequence__c = asDecimal(a.get('sequence'));
                    Object focId = a.get('focProductId');
                    if (focId != null && String.isNotBlank(String.valueOf(focId))) osa.FOC_Giveaway_Product__c = (Id) String.valueOf(focId);
                    osa.Descritption__c = (String) a.get('description');
                    allAppliedSchemes.add(osa);
                    Object pId = a.get('productId');
                    osaProductIds.add((pId != null && String.isNotBlank(String.valueOf(pId)))
                        ? (Id) String.valueOf(pId) : null);
                }
            }
            
            for (Map<String, Object> product : products) {
                Order_Item__c item = new Order_Item__c();
                item.Order__c = orderId;
                item.Product__c = (String)product.get('Product__c');
                item.Product_Category__c = (String)product.get('Product_Category__c');
                item.Quantity__c = (Decimal)product.get('Quantity__c');
                if (product.get('SKU_Weight__c') != null) {
                    item.SKU_Weight__c = (Decimal)product.get('SKU_Weight__c');
                }
                
                // Get UOM from the map (default to empty string if not found)
                Decimal eachQty = (Decimal)product.get('Each_Qyt__c');
                if (eachQty != null && eachQty > 0) {
                    item.Alternate_UOM__c = 'EA';
                } else {
                    item.Alternate_UOM__c = skuToSKU.containsKey(item.Product__c) ? skuToSKU.get(item.Product__c) : '';
                }
                
                Object unitPriceObj = product.get('Unit_price__c');
                if (unitPriceObj instanceof Decimal) {
                    item.Unit_price__c = (Decimal)unitPriceObj;
                } else if (unitPriceObj instanceof String) {
                    String priceStr = (String)unitPriceObj;
                    if (String.isNotBlank(priceStr)) {
                        item.Unit_price__c = Decimal.valueOf(priceStr);
                    }
                } else if (unitPriceObj instanceof Integer) {
                    item.Unit_price__c = Decimal.valueOf(((Integer)unitPriceObj));
                }

                // Category Slab: Set before and after slab unit prices
                Object beforeSlabObj = product.get('Before_Category_Slab_Unit_Price__c');
                if (beforeSlabObj instanceof Decimal) {
                    item.Before_Category_Slab_Unit_Price__c = (Decimal)beforeSlabObj;
                } else if (beforeSlabObj instanceof String && String.isNotBlank((String)beforeSlabObj)) {
                    item.Before_Category_Slab_Unit_Price__c = Decimal.valueOf((String)beforeSlabObj);
                } else if (beforeSlabObj instanceof Integer) {
                    item.Before_Category_Slab_Unit_Price__c = Decimal.valueOf((Integer)beforeSlabObj);
                }

                Object afterSlabObj = product.get('After_Category_Slab_Unit_Price__c');
                if (afterSlabObj instanceof Decimal) {
                    item.After_Category_Slab_Unit_Price__c = (Decimal)afterSlabObj;
                } else if (afterSlabObj instanceof String && String.isNotBlank((String)afterSlabObj)) {
                    item.After_Category_Slab_Unit_Price__c = Decimal.valueOf((String)afterSlabObj);
                } else if (afterSlabObj instanceof Integer) {
                    item.After_Category_Slab_Unit_Price__c = Decimal.valueOf((Integer)afterSlabObj);
                }

                // Scheme: Set before and after scheme unit prices
                Object beforeSchemeObj = product.get('Before_Scheme_Unit_Price__c');
                if (beforeSchemeObj instanceof Decimal) {
                    item.Before_Scheme_Unit_Price__c = (Decimal)beforeSchemeObj;
                } else if (beforeSchemeObj instanceof String && String.isNotBlank((String)beforeSchemeObj)) {
                    item.Before_Scheme_Unit_Price__c = Decimal.valueOf((String)beforeSchemeObj);
                } else if (beforeSchemeObj instanceof Integer) {
                    item.Before_Scheme_Unit_Price__c = Decimal.valueOf((Integer)beforeSchemeObj);
                }

                Object afterSchemeObj = product.get('After_Scheme_Unit_Price__c');
                if (afterSchemeObj instanceof Decimal) {
                    item.After_Scheme_Unit_Price__c = (Decimal)afterSchemeObj;
                } else if (afterSchemeObj instanceof String && String.isNotBlank((String)afterSchemeObj)) {
                    item.After_Scheme_Unit_Price__c = Decimal.valueOf((String)afterSchemeObj);
                } else if (afterSchemeObj instanceof Integer) {
                    item.After_Scheme_Unit_Price__c = Decimal.valueOf((Integer)afterSchemeObj);
                }

                Object schemeItemObj = product.get('Scheme_Item__c');
                if (schemeItemObj != null && String.isNotBlank(String.valueOf(schemeItemObj))) {
                    item.Scheme_Item__c = (Id) String.valueOf(schemeItemObj);
                }

                // Scheme engine: net per-line discount (Free Quantity / QPS / FOC).
                // The applied schemes themselves are recorded as Order_Scheme_Applied__c
                // rows, since one order item can have multiple schemes applied.
                Decimal discVal = asDecimal(product.get('Discount__c'));
                if (discVal != null) {
                    item.Discount__c = discVal;
                }

                item.Tax__c = (Decimal)product.get('Tax__c');
                item.Tax_Amount__c = (Decimal)product.get('Tax_Amount__c');
                item.Total_Amount__c = (Decimal)product.get('Total_Amount__c');
                item.Case_Qyt__c = (Decimal)product.get('Case_Qyt__c');
                item.Each_Qyt__c = (Decimal)product.get('Each_Qyt__c');
                
                List<Sales_Channel_To_SKU__c> salesChannels = productToChannelsMap.get((String)product.get('Product__c'));
                system.debug('SC  '+salesChannels);
                if (salesChannels != null && !salesChannels.isEmpty()) {
                    Sales_Channel_To_SKU__c firstSalesChannel = salesChannels[0];
                    system.debug('SCTSKU  '+firstSalesChannel);
                    String channelKey = firstSalesChannel.Sales_Channel__c; 
                    Product_Mapping__c productMapping = channltoPM.get(channelKey);
                    system.debug('SCTSKUPDM  '+productMapping);
                    if (productMapping != null) {
                        item.Order_Type__c = productMapping.Order_Type__c;
                        item.Division__c = productMapping.Division__c;
                        item.Sales_Organization_c__c = productMapping.Parent_Depot__c;
                        
                       
                        item.Distribution_Channel__c = productMapping.Distribution_Channel__c;
                    }
                }
                
                orderItemsToSort.add(item);
            }
            
            orderItemsToSort.sort(new OrderItemUOMComparator());
            
            // Assign sequential item codes (10, 20, 30...) in sorted order
            Integer itemCode = 10;
            for (Order_Item__c item : orderItemsToSort) {
                item.Item_Code__c = itemCode;
                itemCode += 10;
                allOrderItems.add(item);
            }
        }
        
        // Step 9: Insert all Order_Items
        insert allOrderItems;

        // Link each line-level audit row to the order item it affected (Free Quantity /
        // QPS / FOC). Aggregate rows (Category/Order Value) carry no product -> stay blank.
        if (!allAppliedSchemes.isEmpty()) {
            Map<String, Order_Item__c> itemByOrderProduct = new Map<String, Order_Item__c>();
            for (Order_Item__c it : allOrderItems) {
                if (it.Product__c != null) {
                    itemByOrderProduct.put(String.valueOf(it.Order__c) + '|' + String.valueOf(it.Product__c), it);
                }
            }
            for (Integer j = 0; j < allAppliedSchemes.size(); j++) {
                Id pid = osaProductIds[j];
                if (pid != null) {
                    Order_Item__c oi = itemByOrderProduct.get(
                        String.valueOf(allAppliedSchemes[j].Order_Request__c) + '|' + String.valueOf(pid));
                    if (oi != null) {
                        // Order_Item__c link only; Benefit_Amount__c is the engine's
                        // per-scheme amount (set in the OSA-build from the payload).
                        allAppliedSchemes[j].Order_Item__c = oi.Id;
                    }
                }
            }
        }

        // Step 9b: Insert applied-scheme audit rows.
        // Drop stale lookups (a Scheme/Slab/Product deleted after coverage loaded — e.g.
        // the scheme wizard re-creates slabs on edit) and insert with partial success so
        // these secondary audit rows can never block the order save.
        if (!allAppliedSchemes.isEmpty()) {
            Set<Id> schemeRefs = new Set<Id>();
            Set<Id> slabRefs   = new Set<Id>();
            Set<Id> prodRefs   = new Set<Id>();
            for (Order_Scheme_Applied__c osa : allAppliedSchemes) {
                if (osa.Scheme__c != null)               schemeRefs.add(osa.Scheme__c);
                if (osa.Scheme_Slab__c != null)          slabRefs.add(osa.Scheme_Slab__c);
                if (osa.FOC_Giveaway_Product__c != null) prodRefs.add(osa.FOC_Giveaway_Product__c);
            }
            Set<Id> liveSchemes = schemeRefs.isEmpty() ? new Set<Id>()
                : new Map<Id, Scheme__c>([SELECT Id FROM Scheme__c WHERE Id IN :schemeRefs]).keySet();
            Set<Id> liveSlabs = slabRefs.isEmpty() ? new Set<Id>()
                : new Map<Id, Scheme_Slab__c>([SELECT Id FROM Scheme_Slab__c WHERE Id IN :slabRefs]).keySet();
            Set<Id> liveProds = prodRefs.isEmpty() ? new Set<Id>()
                : new Map<Id, Product__c>([SELECT Id FROM Product__c WHERE Id IN :prodRefs]).keySet();
            for (Order_Scheme_Applied__c osa : allAppliedSchemes) {
                if (osa.Scheme__c != null && !liveSchemes.contains(osa.Scheme__c))                         osa.Scheme__c = null;
                if (osa.Scheme_Slab__c != null && !liveSlabs.contains(osa.Scheme_Slab__c))                 osa.Scheme_Slab__c = null;
                if (osa.FOC_Giveaway_Product__c != null && !liveProds.contains(osa.FOC_Giveaway_Product__c)) osa.FOC_Giveaway_Product__c = null;
            }
            // Capture row-level failures (partial-success insert swallows them) so the
            // real org-side blocker (validation rule / required field / flow) is visible.
            List<Database.SaveResult> osaResults = Database.insert(allAppliedSchemes, false);
            Integer osaFailed = 0;
            for (Database.SaveResult sr : osaResults) {
                if (!sr.isSuccess()) {
                    osaFailed++;
                    for (Database.Error e : sr.getErrors()) {
                        System.debug(LoggingLevel.ERROR,
                            'OSA_INSERT_ERROR: ' + e.getStatusCode() + ' | ' + e.getMessage()
                            + ' | fields=' + e.getFields());
                    }
                }
            }
            System.debug(LoggingLevel.ERROR,
                'OSA_INSERT_SUMMARY total=' + allAppliedSchemes.size() + ' failed=' + osaFailed);
        } else {
            System.debug(LoggingLevel.ERROR, 'OSA_INSERT_SKIPPED: appliedSchemes payload was empty');
        }

        // Prepare response
        dt.orList = [
            SELECT Id, Name, Product__c, Product__r.Name, Order__r.Delivery_Plant__c,
            Product_Category__c, Total_Amount__c, Quantity__c, Unit_price__c
            FROM Order_Item__c 
            WHERE Id IN :allOrderItems
        ];
        
        dt.ordRecData = createdOrders;
        return dt;
    }
    
    // Safely coerce a JSON.deserializeUntyped value (Decimal/Integer/Double/String) into a Decimal.
    private static Decimal asDecimal(Object o) {
        if (o == null) return null;
        if (o instanceof Decimal) return (Decimal) o;
        if (o instanceof Integer) return Decimal.valueOf((Integer) o);
        if (o instanceof Long)    return Decimal.valueOf((Long) o);
        if (o instanceof Double)  return Decimal.valueOf(String.valueOf((Double) o));
        if (o instanceof String) {
            String s = (String) o;
            return String.isBlank(s) ? null : Decimal.valueOf(s);
        }
        return null;
    }

    public class OrderItemUOMComparator implements Comparator<Order_Item__c> {
        public Integer compare(Order_Item__c a, Order_Item__c b) {
            if (a.Alternate_UOM__c == b.Alternate_UOM__c) return 0;
            if (a.Alternate_UOM__c == null) return -1;
            if (b.Alternate_UOM__c == null) return 1;
            return a.Alternate_UOM__c.compareTo(b.Alternate_UOM__c);
        }
    }
    
    
    public static List<Product_Mapping__c> getProductMappins(String accountId) {
        Id currentUserId = UserInfo.getUserId();
        User us = [SELECT Id, Name, Sales_Channel__c FROM User WHERE Id = :currentUserId];
        
        Set<String> salesChannelList = new Set<String>();
        if (String.isNotBlank(us.Sales_Channel__c)) {
            salesChannelList.addAll(us.Sales_Channel__c.split(';'));
        }
        
        // 1) Primary query: current user + account
        List<Product_Mapping__c> prodMapping = [
            SELECT Chanel__c, Primary_Customer__c, Order_Type__c, Division__c,
            Distribution_Channel__c, Parent_Depot__c, Child_Depot__c
            FROM Product_Mapping__c
            WHERE Exectuive__c = :currentUserId
            AND Customer__c = :accountId
        ];
        
        if (!prodMapping.isEmpty()) return prodMapping;
        
        // 2) If nothing found -> get subordinate user ids and query again
        Set<Id> subordinateUserIds = RoleHeirarchyUtility.getRoleSubordinateUsers(currentUserId);
        subordinateUserIds.remove(currentUserId); 
        
        if (!subordinateUserIds.isEmpty()) {
            prodMapping = [
                SELECT Chanel__c, Primary_Customer__c, Order_Type__c, Division__c,
                Distribution_Channel__c, Parent_Depot__c, Child_Depot__c
                FROM Product_Mapping__c
                WHERE Exectuive__c IN :subordinateUserIds
                AND Customer__c = :accountId
            ];
            
            if (!prodMapping.isEmpty()) return prodMapping;
        }
        
        // 3) Still nothing -> final fallback (sales channel based) LIMIT 1
        if (!salesChannelList.isEmpty()) {
            prodMapping = [
                SELECT Chanel__c, Primary_Customer__c, Order_Type__c, Division__c,
                Distribution_Channel__c, Parent_Depot__c, Child_Depot__c
                FROM Product_Mapping__c
                WHERE Customer__c = :accountId
                AND Chanel__c IN :salesChannelList
                AND Chanel__c != null
                LIMIT 1
            ];
            if (!prodMapping.isEmpty()) return prodMapping;
        }
        
        // Prefer returning empty list over null (callers avoid null checks)
        return new List<Product_Mapping__c>();
    }
    
    public static Set<String> getPDPDays(string accountId,string customerType) {
        
        Id currentUserId = UserInfo.getUserId();
        User us = [Select Id,Name,Sales_Channel__c,ManagerId from User where Id=:currentUserId];
        Set<String> salesChannels = new Set<String>();
        
        if (us.Sales_Channel__c != null) {
            salesChannels.addAll(us.Sales_Channel__c.split(';'));
        }
        set<String> channelSet = new set<String>();
        set<String> primaryCustomerIds = new set<String>();
        if(customerType =='Primary Customer')
        {
            primaryCustomerIds.add(accountId);
        }
        
        for (Product_Mapping__c pm : [SELECT PDP_Day__c FROM Product_Mapping__c WHERE (Exectuive__c = :us.ManagerId or Exectuive__c =: currentUserId)
                                      AND Customer__c In:primaryCustomerIds and Chanel__c in: salesChannels
                                     ]) 
        {
            if (String.isNotBlank(pm.PDP_Day__c)) {
                channelSet.add(pm.PDP_Day__c);
            }
        }
        
        if (!channelSet.isEmpty()) {
            return channelSet;
        }
        else{
            return null;
        } 
        
        
    }
    
    
    
    
    
    @AuraEnabled
    global static data getData(Integer isoffSet, Integer isLimit,string objName, Date fromDate, Date toDate){
        data dta = new data();
        
        if(objName == 'My Target'){
            return getTargetData(isoffSet, isLimit);
        }
        else if(objName == 'Expense'){
            return getExpenseData( isoffSet,  isLimit);
            //return getExpenseLineData(isoffSet,  isLimit);
        }
        else if (objName == 'BeatPlan'){
            //return getBeatPlanData(fromDate,toDate);
        }
        else if (objName == 'Product'){
            return getProductData();
        }
        else if (objName == 'getOrderProductivityforMonth'){
            // Date startOfMonth = Date.today().toStartOfMonth();
            // Date endOfMonth = startOfMonth.addMonths(1).addDays(-1);
            date todays = Date.today();
            return getOrderProductivity(todays,todays);
        }
        else if (objName == 'getOrderProductivityforToday'){
            date todays = Date.today();
            return getOrderProductivity(todays,todays);
            //integer visCount = [select count() from visit ];
        }
        return dta;
    }
    @AuraEnabled
    global static data getDataRecordById(string ids,string objName){
        data dta = new data();
        if (objName == 'getOrderDetails'){
            date todays = Date.today();
            return getOrderDestails(ids);
            //integer visCount = [select count() from visit ];
        }
        else if(objName == 'getPaymentDetails'){
            return getPaymentDestails(ids);
        }
        return dta;
    }
    //Order
    @AuraEnabled
    global static data getOrderDestails(string ids){
        
        data dta = new data();
        List<order__c> ord = [SELECT id,name,Grand_Total__c,Visit__c from order__c where Visit__c =: ids];
        map<Id,List<Order_Item__c>> mapOrd = new map<Id,List<Order_Item__c>>();
        for(order__c ords:ord){
            
            if(mapOrd.containsKey(ords.Id)){
                
            }else{
                List<Order_Item__c> ordItms = [select id,name,Product__c,Product__r.Name,Quantity__c,Unit_Price__c,Tax_Amount__c,Tax_Percent__c,
                                               Total_Amount__c,Grant_Total__c from Order_Item__c where Order__c=:ords.Id ];
                mapOrd.put(ords.Id,ordItms);
            }
        }
        
        return dta;
    }
    //Task
    @AuraEnabled
    global static data getPaymentDestails(string ids){
        
        system.debug(ids);
        data dta = new data();
        List<Payment_follow_up__c> payment = [SELECT id,name,Account__c,Account__r.Name,Expected_Amount__c,Visit__c,Comments__c,Expected_Payment_Date__c
                                              from Payment_follow_up__c where Visit__c =: ids];
        List<paymentFollowUpData> pData = new List<paymentFollowUpData>();
        
        for(Payment_follow_up__c pay:payment){
            string formattedDate;
            if (pay.Expected_Payment_Date__c != null) {
                Date myDate = pay.Expected_Payment_Date__c;
                formattedDate = myDate.format();
            } 
            paymentFollowUpData p = new paymentFollowUpData();
            p.Name = pay.Name;
            p.accName = pay.Account__r.Name;
            p.expectedAmount = pay.Expected_Amount__c;
            p.id = pay.Id;
            p.accId = pay.Account__c;
            p.expctedDate = formattedDate;
            p.comments = pay.Comments__c;
            pData.add(p);
        }
        dta.paymentFollowUp = pData;
        return dta;
    }
    //Month product data
    @AuraEnabled
    global static data getOrderProductivity(date toDate, date fromDate) {
        
        data dta = new data();
        List<productive> proList = new List<productive>();
        
        // Date startOfMonth = Date.today().toStartOfMonth();
        // Date endOfMonth = startOfMonth.addMonths(1).addDays(-1);
        Date startOfMonth = toDate;
        Date endOfMonth = fromDate;
        // Fetch Visits for the current user within the month
        List<Visit__c> vs = [SELECT Id, Visit_Date__c 
                             FROM Visit__c 
                             WHERE OwnerId = :userinfo.getUserId()
                             AND Visit_Date__c >= :startOfMonth 
                             AND Visit_Date__c <= :endOfMonth 
                             ORDER BY Visit_Date__c DESC];
        
        Set<Id> visitIds = new Set<Id>();
        Map<Date, Set<Id>> visitDateMap = new Map<Date, Set<Id>>(); // Map to store visit ids by date
        
        for (Visit__c visit : vs) {
            visitIds.add(visit.Id);
            if (!visitDateMap.containsKey(visit.Visit_Date__c)) {
                visitDateMap.put(visit.Visit_Date__c, new Set<Id>());
            }
            visitDateMap.get(visit.Visit_Date__c).add(visit.Id);
        }
        
        // Fetch Order Items associated with these visits
        List<Order_Item__c> ord = [SELECT Id, Quantity__c, Order__r.Visit__c, Order__r.Visit__r.Visit_Date__c 
                                   FROM Order_Item__c 
                                   WHERE Order__r.Visit__c IN :visitIds];
        
        Map<Date, Decimal> dailyTSL = new Map<Date, Decimal>();
        Map<Date, Integer> dailyProductiveCalls = new Map<Date, Integer>();
        
        // Calculate TSL and productive calls for each date
        for (Order_Item__c ordItem : ord) {
            Date visDate = ordItem.Order__r.Visit__r.Visit_Date__c;
            
            // Update the TSL for each day
            if (dailyTSL.containsKey(visDate)) {
                dailyTSL.put(visDate, dailyTSL.get(visDate) + ordItem.Quantity__c);
            } else {
                dailyTSL.put(visDate, ordItem.Quantity__c);
            }
            
            // Mark as productive call if there are orders for that visit date
            if (dailyProductiveCalls.containsKey(visDate)) {
                dailyProductiveCalls.put(visDate, dailyProductiveCalls.get(visDate) + 1);
            } else {
                dailyProductiveCalls.put(visDate, 1);
            }
        }
        
        // Iterate over each date in the month and calculate TSL, LPPC, and productiveCalls for each day
        for (Date day = startOfMonth; day <= endOfMonth; day = day.addDays(1)) {
            productive pro = new productive();
            
            String formattedDate = DateTime.newInstance(day.year(), day.month(), day.day()).format('dd/MM/yyyy');
            pro.formattedDate = formattedDate;
            
            // TSL for the day
            Decimal TSL = dailyTSL.containsKey(day) ? dailyTSL.get(day) : 0;
            pro.TSL = TSL.setScale(2, RoundingMode.HALF_UP);
            
            // Productive Calls (number of distinct orders/visits with orders)
            Integer productiveCalls = dailyProductiveCalls.containsKey(day) ? dailyProductiveCalls.get(day) : 0;
            pro.productiveCalls = productiveCalls;
            
            // LPPC (Lines Per Productive Call)
            decimal pdCalls= productiveCalls > 0 ? TSL / productiveCalls : 0;
            pro.LPPC = pdCalls.setScale(2, RoundingMode.HALF_UP);
            // Add the productive object to the list
            proList.add(pro);
        }
        
        if(!vs.isEmpty()){
            integer visCount = vs.size();
            dta.visCount = visCount;
            //Daily_Log__c dly = [SLECT ];
            List<Expense__c> ex = new  List<Expense__c>();/*[SELECT Id, Total_Amount__c,Total_Km__c FROM Expense__c WHERE CreatedDate = THIS_MONTH LIMIT 1];*/
            
            // Check if the list is not empty to avoid accessing an element that doesn't exist
            if (!ex.isEmpty()) {
                //dta.TotalAmount = ex[0].Total_Amount__c;
                //dta.totalKm = ex[0].Total_Km__c.setScale(2, RoundingMode.HALF_UP);
            } else {
                dta.TotalAmount = 0;
                dta.totalKm = 0;
            }
            dta.productiveData = proList[0].productiveCalls;
            system.debug(dta.visCount);
            system.debug(dta.TotalAmount);
            system.debug(dta.totalKm);
            system.debug(visCount);
        }
        // Assign the list of productive data to the data object
        dta.productive = proList;
        system.debug(dta.productive);
        return dta;
    }
    //Product
    @AuraEnabled
    global static data getProductData() {
        data dt = new data();
        
        // Fetch products separately
        List<Product__c> products = [
            SELECT Id, Name, Product_Category_Name__c, List_Price__c, Tax_Percent__c, CreatedDate, Product_Category1__r.Selling_Category__c,
            Product_Category1__r.Selling_Category__r.Name,
            Product_Category1__c, Product_Category1__r.Name, CGST__c, Discount__c, Tax_Class__c,Selling_Category__c,Selling_Category__r.Name
            FROM Product__c
            WHERE Product_Category1__c != NULL order by Product_Category1__r.name asc
        ];
        
        // Process and structure the daupsertOrderta
        dt.productCategories = setOrder(products);
        
        List<Product_Category__c> proCat = [
            SELECT Id, Name ,Selling_Category__c,Selling_Category__r.Name
            FROM Product_Category__c 
            WHERE Id IN (SELECT Product_Category1__c FROM Product__c) 
            ORDER BY Name ASC
        ];
        List<Map<String, String>> formattedSalesData = new List<Map<String, String>>();
        Map<String, String> allOptionsales = new Map<String, String>();
        allOptionsales.put('label', 'All');
        allOptionsales.put('value', 'All');
        formattedSalesData.add(allOptionsales);
        List<Selling_Category__c> sales = [select id, name from Selling_Category__c];
        for(Selling_Category__c sl:sales){
            Map<String, String> dataMap = new Map<String, String>();
            dataMap.put('label', sl.Name);
            dataMap.put('value', sl.Id);
            formattedSalesData.add(dataMap);
        }
        List<Map<String, String>> formattedData = new List<Map<String, String>>();
        Map<String, String> allOption = new Map<String, String>();
        allOption.put('label', 'All');
        allOption.put('value', 'All');
        formattedData.add(allOption);
        for (Product_Category__c pc : proCat) {
            Map<String, String> dataMap = new Map<String, String>();
            dataMap.put('label', pc.Name);
            dataMap.put('value', pc.Id);
            formattedData.add(dataMap);
        }
        dt.productCatDropdown = formattedData;
        dt.formattedSalesData = formattedSalesData;
        System.debug('Product Categories: ' + dt.productCategories);
        
        return dt;
    }
    public static List<categoryData> setOrder(List<Product__c> products) {
        Map<Id, List<productData>> proLine = new Map<Id, List<productData>>();
        Map<Id, String> categoryNames = new Map<Id, String>(); // To store category names
        Map<Id, String> salesId = new Map<Id, String>();
        Map<id,map<id,String>> focusSell = new Map<Id, map<id,String>>();
        
        Integer index1 = 0;
        Integer index2 = 0;
        
        for (Product__c pro : products) {
            // Format the creation date
            String formattedProdDate = DateTime.newInstance(pro.CreatedDate.year(), pro.CreatedDate.month(), pro.CreatedDate.day()).format('dd/MM/yyyy');
            
            // Create a new productData object
            productData p = new productData();
            p.id = pro.Id;
            p.name = pro.Name;
            p.category = pro.Product_Category_Name__c; // Individual product category name
            p.unitPrice = pro.List_Price__c;
            p.taxPercent = pro.Tax_Percent__c;
            p.taxClass = pro.Tax_Class__c;
            p.createdDate = formattedProdDate;
            p.value = 0;
            p.index2 = index2;
            p.salesId = pro.Selling_Category__c;
            index2++;
            
            Id sellingCategoryId = (pro.Product_Category1__c != null) ? pro.Product_Category1__r.Selling_Category__c : null;
            String sellingCategoryName = (pro.Product_Category1__c != null && pro.Product_Category1__r.Selling_Category__r != null) ?
                pro.Product_Category1__r.Selling_Category__r.Name : null;
            
            // Efficiently store products under their categories
            if (!proLine.containsKey(pro.Product_Category1__c)) {
                proLine.put(pro.Product_Category1__c, new List<productData>());
                categoryNames.put(pro.Product_Category1__c, pro.Product_Category1__r.Name);
                salesId.put(pro.Product_Category1__c, pro.Selling_Category__c);
                if (!focusSell.containsKey(pro.Product_Category1__c)) {
                    focusSell.put(pro.Product_Category1__c, new Map<Id, String>());
                }
            }
            if (sellingCategoryId != null && sellingCategoryName != null) {
                focusSell.get(pro.Product_Category1__c).put(sellingCategoryId, sellingCategoryName);
            }
            proLine.get(pro.Product_Category1__c).add(p);
        }
        
        // Convert map to list
        List<categoryData> categoryList = new List<categoryData>();
        for (Id categoryId : proLine.keySet()) {
            
            categoryData category = new categoryData();
            category.categoryId = categoryId;
            category.index1 = index1;
            
            if (focusSell.containsKey(categoryId) && !focusSell.get(categoryId).isEmpty()) {
                Map<Id, String> innerMap = focusSell.get(categoryId);
                Id firstKey = innerMap.keySet().iterator().next();
                category.focusSellId = firstKey;
                category.focusSellName = innerMap.get(firstKey);
            }else{
                category.focusSellId = 'null';
                category.focusSellName = 'null';
            }
            
            category.salesId = salesId.get(categoryId);
            category.categoryName = categoryNames.get(categoryId);
            category.products = proLine.get(categoryId);
            categoryList.add(category);
            index1++;
        }
        
        return categoryList;
    }
    @AuraEnabled
    global static data searchProducts(string srchString){
        data dt = new data();
        List<Product__c> products = new List<product__c>();
        Map<Id, Product__c> uniqueProducts = new Map<Id, Product__c>();
        if (String.isBlank(srchString)) {
            
            // Fetch products separately
            products  = [
                SELECT Id, Name, Product_Category_Name__c, List_Price__c, Tax_Percent__c, CreatedDate, 
                Product_Category1__c, Product_Category1__r.Name, CGST__c, Discount__c, Tax_Class__c
                FROM Product__c
                WHERE Product_Category1__c != NULL
            ];
        }else{
            List<List<SObject>> productSrch = [ 
                FIND :srchString 
                IN ALL FIELDS 
                RETURNING Product__c (
                    Id, Name, Product_Category_Name__c, List_Price__c, Tax_Percent__c, CreatedDate, 
                    Product_Category1__c, Product_Category1__r.Name, CGST__c, Discount__c, Tax_Class__c
                    WHERE Product_Category1__c != NULL
                )
            ];
            if (!productSrch.isEmpty() && !productSrch[0].isEmpty()) {
                for (SObject result : productSrch[0]) {
                    Product__c product = (Product__c) result;
                    uniqueProducts.put(product.Id, product); // Add unique products to the map
                }
            }
            products = uniqueProducts.values();
            // system.debug('srh:'+productSrch[0]);
        }
        
        // Process and structure the data
        dt.productCategories = setOrder(products);
        
        // System.debug('Product Categories: ' + dt.productCategories);
        
        return dt;
    }
    //Expense line item wise data
    @AuraEnabled
    global static data getExpenseLineData(Integer offset, Integer islimit) {
        
        data dta = new data();
  
        system.debug('dta '+dta);
        return dta;
    }
    //Expense data
    @AuraEnabled
    global static data getExpenseData(Integer offset, Integer islimit) {
        
        // Wrapper class to hold data for Expenses and KPIs
        data dataWrapper = new data();
        system.debug('dataWrapper'+dataWrapper);
        // Return the wrapper object
        return dataWrapper; 
    }
    //Target Data
    @AuraEnabled
    global static data getTargetData(Integer isoffSet, Integer isLimit) {
        data dta = new data();
        kpiData kData = new kpiData();
        List<String> colHeadList = new List<String>();
        system.debug('ggg'+isoffSet+isLimit);
        // Fetch Targets with offset and limit
        List<Target__c> tarList = [SELECT Id, Name, Achieved_Percentage__c, Executive__c, Executive__r.Name, Account__c,Actual__c,Target__c,
                                   Period__c,Period__r.Name
                                   FROM Target__c  
                                   WHERE CreatedDate = THIS_MONTH AND  OwnerId =:userinfo.getUserId()  
                                   ORDER BY Achieved_Percentage__c DESC NULLS LAST 
                                   Limit 5000];//CreatedDate = THIS_MONTH AND Executive__c != null
        
        System.debug(tarList + ' tarList');
        
        Date currentDate = Date.today();
        DateTime currentDateTime = DateTime.newInstance(currentDate.year(), currentDate.month(), currentDate.day());
        String formattedDate = currentDateTime.format('MMM yyyy');
        List<String> topsellers = new List<String>();
        
        for (Target__c tar : tarList) {
            topsellers.add(tar.Executive__r.Name);
        }
        
        kData.names = topsellers;
        List<cls_kpi_sections> listSection = new List<cls_kpi_sections>();
        cls_kpi_sections sec = new cls_kpi_sections();
        
        sec.sectionHeader = 'KPI for - ' + formattedDate;
        colHeadList.add('Type');
        colHeadList.add('Target');
        colHeadList.add('Actual');
        
        sec.columnHeaders = colHeadList;
        
        List<cls_rows> rowList = new List<cls_rows>();
        
        cls_rows r = new cls_rows();
        r.rowName = 'Dealer Visit';
        r.targetValue = 10000;
        r.actualValue = 20000;
        rowList.add(r);
        
        cls_rows r1 = new cls_rows();
        r1.rowName = 'Distributor Visit';
        r1.targetValue = 50000;
        r1.actualValue = 70000;
        rowList.add(r1);
        
        sec.rows = rowList;
        listSection.add(sec);
        
        kData.sections = listSection;
        dta.kpi = kData; // Assign kpi data to the main data object
        
        List<kpi_target> targlist = new List<kpi_target>();
        
        List<kpi_graph_target> graphlist = new List<kpi_graph_target>();
        integer ctr = 1;
        if (!tarList.isEmpty()) {
            // Get all the Target__c Ids from tarList
            Set<Id> targetIds = new Set<Id>();
            for (Target__c tr : tarList) {
                targetIds.add(tr.Id);
                kpi_graph_target graph = new kpi_graph_target();
                graph.xAxis = tr.Period__r.Name;
                graph.actual = tr.Actual__c;
                graph.target = tr.Target__c;
                graphlist.add(graph);
            }
            
            // Query all Target_Item__c records that match the Target__c Ids in the tarList
            List<Target_Item__c> allTargetItems = [SELECT Id, Target__c, Target_Value__c, Actual_Value__c,Name, Self_Target__c,//Owner.Name,
                                                   Target_Logic__c, Target_Logic__r.Name, Achieved_Percentage__c 
                                                   FROM Target_Item__c 
                                                   WHERE Target__c IN :targetIds
                                                   ORDER BY Target_Logic__r.Name LIMIT 5000];//:isLimit OFFSET :isoffSet];
            System.debug(allTargetItems + ' allTargetItems');
            // Process Target_Item__c records
            for (Target_Item__c item : allTargetItems) {
                kpi_target t = new kpi_target();
                t.kpiName = 'KPI' + ctr;
                t.targetName = item.Target_Logic__r.Name;
                t.Name = item.Name;
                // t.ownerName = item.Owner.Name;
                t.target = item.Self_Target__c;
                t.actual = item.Actual_Value__c == null ? 0 : item.Actual_Value__c;
                t.achivedPer = item.Achieved_Percentage__c;
                targlist.add(t);
                ctr++;
            }
        }
        System.debug(targlist + ' targlist');
        // If you need to do something with targlist, you can assign it to dta or kData here
        kData.targlist = targlist; // Assuming you want to add this to kData
        kData.graphlist = graphlist;
        // dta.kpi = kData;
        return dta; // Return the populated data object
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
    
    

    
    /** Fetch products based on executive and account linked channels */
    public static List<Product__c> getProducts(String accountId, String customerType) {
        Id currentUserId = UserInfo.getUserId();
        User us = [SELECT Id, Name, Sales_Channel__c,Alternate_Sales_Channel__c FROM User WHERE Id = :currentUserId];
        
        Set<String> salesChannelList = new Set<String>();
        if(us.Alternate_Sales_Channel__c != null)
        {
            salesChannelList.addAll(us.Alternate_Sales_Channel__c.split(';'));
        }
        else if(us.Sales_Channel__c != null){
            salesChannelList.addAll(us.Sales_Channel__c.split(';'));
        }
        
        
        Set<String> channelSet = new Set<String>();
        Set<String> primaryCustomerIds = new Set<String>();
        if(us.Alternate_Sales_Channel__c == null){
            List<Product_Mapping__c> prodMappingsFromPrimary = [SELECT Chanel__c, Primary_Customer__c 
                                                                FROM Product_Mapping__c 
                                                                WHERE Exectuive__c = :currentUserId 
                                                                AND Customer__c = :accountId];
            
            // Populate channelSet and primaryCustomerIds
            for(Product_Mapping__c prodMap : prodMappingsFromPrimary) {
                if (prodMap.Chanel__c != null) {
                    channelSet.add(prodMap.Chanel__c);
                }
                if (prodMap.Primary_Customer__c != null) {
                    primaryCustomerIds.add(prodMap.Primary_Customer__c);
                }
            }
        }
        
        if (!channelSet.isEmpty()) {
            Set<String> productIds = new Set<String>();
            List<Sales_Channel_To_SKU__c> channels = [SELECT Id, Name, SKU__r.Name,SKU__c,Delivery_Plant__c,Sales_Channel__c
                                                      FROM Sales_Channel_To_SKU__c WHERE Sales_Channel__c IN :channelSet and SKU__r.Is_Active__c = true];
            map<String,String> skuNameToSkuId = new map<String,String>();
            for (Sales_Channel_To_SKU__c channel : channels) {
                productIds.add(channel.SKU__r.Name);
                skuNameToSkuId.put(channel.SKU__r.Name,channel.SKU__c);
            }
            List<Product__c> products = new List<Product__c>();
            if(customerType == 'Primary Customer')
            {
                 products = [
                    SELECT Id, Name, Channel__c, Product_Category_Name__c, Product_Category1__c,
                    Product_Category1__r.Name, List_Price__c, MRP__c, Tax_Percent__c,
                    Tax_Class__c, CreatedDate, UOM__c, Selling_Category__c,
                    (SELECT Id, Unit_Price__c, MRP__c, UOM__c, Customer__c, 
                     Customer_Type__c, Region__c, Secondary_Customer_Category__c
                     FROM Price_Books__r where Customer__c =:accountId )
                    FROM Product__c  WHERE Is_Active__c = true AND Id IN :skuNameToSkuId.values()
                    ORDER BY Channel__c ASC
                ];
            }
            else
            {
                products = [
                    SELECT Id, Name, Channel__c, Product_Category_Name__c, Product_Category1__c,
                    Product_Category1__r.Name, List_Price__c, MRP__c, Tax_Percent__c,
                    Tax_Class__c, CreatedDate, UOM__c, Selling_Category__c,
                    (SELECT Id, Unit_Price__c, MRP__c, UOM__c, Customer__c, 
                     Customer_Type__c, Region__c, Secondary_Customer_Category__c
                     FROM Price_Books__r where Customer_Type__c =:customerType and Sales_Channel__c IN: channelSet)
                    FROM Product__c  WHERE Is_Active__c = true AND Id IN :skuNameToSkuId.values()
                    ORDER BY Channel__c ASC
                ];
            }
         
            return products;
        }
        else {
            List<Product_Mapping__c> secondaryProductMappings = [
                SELECT Chanel__c, Primary_Customer__c 
                FROM Product_Mapping__c 
                WHERE Customer__c IN :primaryCustomerIds 
                AND Chanel__c IN :salesChannelList 
                AND Exectuive__c = :currentUserId
            ];
            
            
            // If no records found, use a broader query
            if (secondaryProductMappings.isEmpty()) {
                secondaryProductMappings = [
                    SELECT Chanel__c, Primary_Customer__c 
                    FROM Product_Mapping__c 
                    WHERE Customer__c IN :primaryCustomerIds 
                    AND Chanel__c IN :salesChannelList
                ];
            }
            
            // Populate the channelSet again
            for(Product_Mapping__c prodMap : secondaryProductMappings) {
                if (prodMap.Chanel__c != null) {
                    channelSet.add(prodMap.Chanel__c);
                }
            }
            
            if (!channelSet.isEmpty()) {
                Set<String> productIds = new Set<String>();
                map<String,String> skuNameToSkuId = new map<String,String>();
                List<Sales_Channel_To_SKU__c> channels = [SELECT Id, Name, SKU__c,SKU__r.Name,Delivery_Plant__c,Sales_Channel__c
                                                          FROM Sales_Channel_To_SKU__c WHERE Sales_Channel__c IN :channelSet];
                for (Sales_Channel_To_SKU__c channel : channels) {
                    productIds.add(channel.SKU__r.Name);
                    skuNameToSkuId.put(channel.SKU__r.Name,channel.SKU__c);
                }
                
                List<Product__c> products = new List<Product__c>();
                if(customerType == 'Primary Customer')
                {
                    products = [
                        SELECT Id, Name, Channel__c, Product_Category_Name__c, Product_Category1__c,
                        Product_Category1__r.Name, List_Price__c, MRP__c, Tax_Percent__c,
                        Tax_Class__c, CreatedDate, UOM__c, Selling_Category__c,
                        (SELECT Id, Unit_Price__c, MRP__c, UOM__c, 
                         Customer__c, Customer_Type__c, Region__c, Secondary_Customer_Category__c
                         FROM Price_Books__r  where Customer__c =:accountId)
                        FROM Product__c 
                        WHERE Is_Active__c = true 
                        AND Id IN :skuNameToSkuId.values()
                        ORDER BY Channel__c ASC
                    ];
                }
                else
                {
                    products = [
                        SELECT Id, Name, Channel__c, Product_Category_Name__c, Product_Category1__c,
                        Product_Category1__r.Name, List_Price__c, MRP__c, Tax_Percent__c,
                        Tax_Class__c, CreatedDate, UOM__c, Selling_Category__c,
                        (SELECT Id, Unit_Price__c, MRP__c, UOM__c, 
                         Customer__c, Customer_Type__c, Region__c, Secondary_Customer_Category__c
                         FROM Price_Books__r where Customer_Type__c =:customerType and Sales_Channel__c IN: channelSet)
                        FROM Product__c 
                        WHERE Is_Active__c = true 
                        AND Id IN :skuNameToSkuId.values()
                        ORDER BY Channel__c ASC
                    ];
                }
               
                return products;
            } else {
                Set<String> productIds = new Set<String>();
                map<String,String> skuNameToSkuId = new map<String,String>();
                List<Sales_Channel_To_SKU__c> channels = [SELECT Id, Name, SKU__c,SKU__r.Name,Delivery_Plant__c,Sales_Channel__c
                                                          FROM Sales_Channel_To_SKU__c WHERE Sales_Channel__c IN :salesChannelList and SKU__r.Is_Active__c = true];
                for (Sales_Channel_To_SKU__c channel : channels) {
                    productIds.add(channel.SKU__r.Name);
                    skuNameToSkuId.put(channel.SKU__r.Name,channel.SKU__c);
                }
                
                List<Product__c> products = new List<Product__c>();
                if(customerType == 'Primary Customer')
                {
                    products = [
                        SELECT Id, Name, Channel__c, Product_Category_Name__c, Product_Category1__c,
                        Product_Category1__r.Name, List_Price__c, MRP__c, Tax_Percent__c,
                        Tax_Class__c, CreatedDate, UOM__c, Selling_Category__c,
                        (SELECT Id, Unit_Price__c, MRP__c, UOM__c, 
                         Customer__c, Customer_Type__c, Region__c, Secondary_Customer_Category__c
                         FROM Price_Books__r  where Customer__c =:accountId)
                        FROM Product__c 
                        WHERE Is_Active__c = true 
                        AND Id IN :skuNameToSkuId.values()
                        ORDER BY Channel__c ASC
                    ];
                }
                else
                {
                    products = [
                        SELECT Id, Name, Channel__c, Product_Category_Name__c, Product_Category1__c,
                        Product_Category1__r.Name, List_Price__c, MRP__c, Tax_Percent__c,
                        Tax_Class__c, CreatedDate, UOM__c, Selling_Category__c,
                        (SELECT Id, Unit_Price__c, MRP__c, UOM__c, 
                         Customer__c, Customer_Type__c, Region__c, Secondary_Customer_Category__c
                         FROM Price_Books__r where Customer_Type__c =:customerType and Sales_Channel__c IN: salesChannelList)
                        FROM Product__c 
                        WHERE Is_Active__c = true 
                        AND Id IN :skuNameToSkuId.values()
                        ORDER BY Channel__c ASC
                    ];
                }
               
                return products;
            }
        }
    }
    
    
    
    /**Main Data **/
    global class data {
        @AuraEnabled public User currentUser{get;set;}
        @AuraEnabled public List<BuyProductData> BuyProData{get;set;}
        @AuraEnabled public List<strategyData> strategies { get; set; }
        @AuraEnabled public List<productData> allOtherProducts { get; set; }
        @AuraEnabled public List<productData> allProDtas { get; set; }
        @AuraEnabled public Map<Id, strategyProductMapData> strategyProductMap { get; set; }
        @AuraEnabled public List<strategyProductMapData> strategyProductMapList { get; set; }
        @AuraEnabled public List<outstanding> outData { get; set; }
        @AuraEnabled public List<Orders> ordData { get; set; }
        @AuraEnabled public List<VisitDataSummary> SummaryvisitData { get; set; }
        @AuraEnabled public List<ReturnDataSummary> summaryReturnData { get; set; }
        @AuraEnabled public List<salesSummery> sales { get; set; }
        @AuraEnabled public Map<Id, Order_Item__c> existingOrderProductQuantities{get;set;}
        @AuraEnabled public Decimal minumumOrderValue{get;set;}
        @AuraEnabled public String deliveryTo{get;set;}
        @AuraEnabled public Date estimatedDeliveryDate{get;set;}
        @AuraEnabled public Date PoDate{get;set;}
        @AuraEnabled public String PoNum{get;set;}
        @AuraEnabled public Boolean isModerTrade{get;set;}
        @AuraEnabled public Boolean isShowOwner{get;set;}
        @AuraEnabled public Boolean isDSM_SSA{get;set;}
        @AuraEnabled public Id orderOwnerId{get;set;}
        @AuraEnabled public String orderOwnerName{get;set;}
        @AuraEnabled public Account currentAccountRec{get;set;}
        @AuraEnabled public List<SchemeStrategy> scheme { get; set; }
        @AuraEnabled public List<schemeData> schemessss{get;set;}
        @AuraEnabled public String primaryCustmerId{get;set;}
        @AuraEnabled public Boolean showRepoteeView{get;set;}
        public data() {
            outData = new List<outstanding>();
            ordData = new List<Orders>();
            SummaryvisitData = new List<VisitDataSummary>();
            summaryReturnData = new List<ReturnDataSummary>();
            sales = new List<salesSummery>();  
            this.strategyProductMapList = new List<strategyProductMapData>();
            this.strategies = new List<strategyData>();
            this.allOtherProducts = new List<productData>();
            this.strategyProductMap = new Map<Id, strategyProductMapData>();
            this.existingOrderProductQuantities = new Map<Id, Order_Item__c>();
            scheme = new List<SchemeStrategy>();
            schemessss = new List<schemeData>();
        }
        
        @AuraEnabled public Decimal totalOutStanding{get; set;}
        @AuraEnabled public ListView ListViewDetails { get; set; }
        @AuraEnabled public List<account> Account { get; set; }
        @AuraEnabled public Decimal totalOrderAmt{get; set;}
        @AuraEnabled public List<Order__c> orderfulfillments{get; set;}
        @AuraEnabled public Decimal totalSalesAmt{get; set;}
        @AuraEnabled public Decimal totalReturnAmount{get; set;}
        @AuraEnabled public Decimal totalReturnQty{get; set;}
        @AuraEnabled public Integer AllVisit{get; set;}
        @AuraEnabled public boolean isDayStarted{get; set;}
        @AuraEnabled public List<ContentDocument> VisitPhoto{get; set;}
        @AuraEnabled public List<Dealer_Stock__c> Stock{get; set;}
        @AuraEnabled public List<Competition__c> Competition{get; set;}
        @AuraEnabled public List<Visit_Form__c> visitForm{get; set;}
        @AuraEnabled public List<Display_Format__c> displayFormat{get; set;}
        @AuraEnabled public List<Shelf_Stock__c> ShelfStocks{get; set;}
        @AuraEnabled public List<Outlet_Task__c> outletTask{get; set;}
        @AuraEnabled public List<Map<String, String>> productCatDropdown{get; set;}
        @AuraEnabled public List<Map<String, String>> formattedSalesData{get; set;}
        @AuraEnabled public List<Order_Item__c> orList{get; set;}
        @AuraEnabled public List<Order__c> ordRecData {get;set;} 
        @AuraEnabled public Daily_Log__c dailyLog{get; set;}
        @AuraEnabled public List<Account> Dealer {get; set;}
        @AuraEnabled public List<Account> Distributor {get; set;}
        @AuraEnabled public List<Account> ModrenTrade {get; set;}
        @AuraEnabled public List<Lead__c> lead {get; set;}
        @AuraEnabled public kpiData kpi;
        @AuraEnabled public List<expenseData> expense;
        @AuraEnabled public List<visitPlanData> visitPlan;
        @auraEnabled public List<visitData> visit;
        @AuraEnabled public List<Map<String, String>> routeDropdown{get; set;}
        @AuraEnabled public List<categoryData> productCategories; 
        @AuraEnabled public integer visCount;
        @AuraEnabled public Decimal TotalAmount;
        @AuraEnabled public Decimal totalKm;
        @AuraEnabled public Decimal productiveData;
        @AuraEnabled public String accountName{get;set;}
        @AuraEnabled public String accountType{get;set;}
        @AuraEnabled public List<productive> productive;
        @AuraEnabled Public List<paymentFollowUpData> paymentFollowUp;
        @AuraEnabled public List<Map<String, String>> purposeofVisit = new List<Map<String, String>> ();
        @AuraEnabled public List<Map<String, String>> travelType = new List<Map<String, String>> ();
        @AuraEnabled public List<Map<String, String>> vehicleUsed = new List<Map<String, String>> ();
        @AuraEnabled public List<Map<String, String>> visitTypes = new List<Map<String, String>> ();
        @AuraEnabled public boolean isPromoter{get; set;}
        @AuraEnabled public boolean isLeaveExisted{get; set;}
        @AuraEnabled public List<Account> primaryCustomers {get; set;}
        @AuraEnabled public List<Account> secoundaryCustomers {get; set;}
        @AuraEnabled public List<Return_Item__c> returnItems{get; set;}
        @AuraEnabled public List<Collection_Item__c> collectionItems{get; set;}
        @AuraEnabled public List<Map<String, String>> modeOfPayment = new List<Map<String, String>> ();
        @AuraEnabled public List<Invoice__c> invoiceData{get; set;}
        @AuraEnabled public List<Display_Format__c> displayformatData{get; set;}
        @AuraEnabled public List<Shelf_Stock__c> shelfStockdata{get; set;}
        @AuraEnabled public list<Product__c> productList { get; set; }
        @AuraEnabled public boolean currentMonthStockExisted { get; set; }
        @AuraEnabled public list<Return__c> returnList { get; set; }
        @AuraEnabled public List<Map<String, String>> resonForReturn = new List<Map<String, String>> ();
        @AuraEnabled public List<Map<String, String>> uom = new List<Map<String, String>> ();
        @AuraEnabled public Map<String, Decimal> productIdWithMrp = new Map<String, Decimal>();
        @AuraEnabled public Map<String, Decimal> productIdWithOriginalUnitPrice = new Map<String, Decimal>();
        @AuraEnabled public list<Order__c> orderList { get; set; }
        @AuraEnabled public list<BeatData> beatDataList { get; set; }
        @AuraEnabled public list<BeatData> sharedBeatDataList { get; set; }
        @AuraEnabled public boolean currentBeatExisted { get; set; }
        @AuraEnabled public boolean isUomDisabled { get; set; }
        @AuraEnabled public boolean isDesktopAllowed { get; set; }
        @AuraEnabled public boolean isMobileAllowed { get; set; }
        @AuraEnabled public string orderAccountId { get; set; }
        
    }
    /**Daily log Reurn Data **/
    public class dailyLogBox{
        @AuraEnabled
        public Daily_Log__c Dailylog {get; set;}
        @AuraEnabled
        public String IsSuccess {get; set;} 
    }
    
    /**Order Scheme Data **/
    public class BuyProductData {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public Id productId { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public Decimal buyQuantity { get; set; }
        @AuraEnabled public Decimal buyValue { get; set; }
        @AuraEnabled public Decimal offerQuantity { get; set; }
        @AuraEnabled public Decimal offerValue { get; set; }
        @AuraEnabled public Decimal offerPercent { get; set; }
        @AuraEnabled public Decimal min { get; set; }
        @AuraEnabled public Decimal max { get; set; }
        
        @AuraEnabled public Decimal SaleValue { get; set; }
        @AuraEnabled public Decimal PerKg { get; set; }
        @AuraEnabled public Decimal Discount { get; set; }
        
    }
    public class SchemeStrategy {
        @AuraEnabled public Strategy strategy { get; set; }
    }
    public class Strategy {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String productCategory { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public String Description { get; set; }
        @AuraEnabled public List<BuyProductData> buyProduct { get; set; }
    }
    public class strategyData {
        @AuraEnabled public Sales_Strategy__c strategy { get; set; }
        @AuraEnabled public List<productData> Products { get; set; }
        public strategyData(Sales_Strategy__c strategy, List<productData> mappedProducts) {
            this.strategy = strategy;
            this.Products = mappedProducts;
        }
    }    
    public class strategyProductMapData {
        @AuraEnabled public String index { get; set; }
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Sales_Strategy__c strategy { get; set; }
        @AuraEnabled public List<productData> products { get; set; }
        public strategyProductMapData(String index, string name,string id,Sales_Strategy__c strategy, List<productData> products) {
            this.index = index;
            this.name = name;
            this.id = id;
            this.strategy = strategy;
            this.products = products;
        }
    }
    public class schemeLineItemData {
        @AuraEnabled public Id id;
        @AuraEnabled public Id productId;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean isSelected;
        @AuraEnabled public Integer minQty;
        @AuraEnabled public Integer freeQty;
        @AuraEnabled public Id offerProductId;
        @AuraEnabled public String offerProductName;
        @AuraEnabled public Decimal discountPerUOM;
        @AuraEnabled public Decimal saleValueThreshold;
        @AuraEnabled public Decimal discountPercentOnSale;
        @AuraEnabled public Decimal discountedPrice;
        @AuraEnabled public String schemeCategory;
        @AuraEnabled public Boolean isFreeProduct;
        @AuraEnabled public Boolean isPerUOMDiscount;
        @AuraEnabled public Boolean isSaleValueDiscount;
    }
    public class schemeData {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public Boolean isSchemeSelected;
        @AuraEnabled public List<schemeLineItemData> lineItems;
        
        public schemeData() {
            lineItems = new List<schemeLineItemData>();
        }
    }
    
    global class VisitDataSummary {
        @AuraEnabled public String visitId { get; set; }
        @AuraEnabled public String visitType { get; set; }
        @AuraEnabled public String ownerId { get; set; }
        @AuraEnabled public String visDate { get; set; }
        @AuraEnabled public Integer TotalOrd { get; set; }
        @AuraEnabled public string Status { get; set; }
        @AuraEnabled public string VisitDuration { get; set; }
        @AuraEnabled public string LocationType { get; set; }
        @AuraEnabled public String ExeName { get; set; }
    }
    
    global class ReturnDataSummary {
        @AuraEnabled public String returnId { get; set; }
        @AuraEnabled public String returnName { get; set; }
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
    }
    
    
    global class salesSummery{
        @AuraEnabled
        public String salesDate { get; set; }
        @AuraEnabled
        public String SalesId { get; set; }
        @AuraEnabled
        public String salesInvoice { get; set; }
        @AuraEnabled
        public Decimal Amount { get; set; }
    }
    global class Orders{
        @AuraEnabled
        public String OrdNo { get; set; }
        @AuraEnabled
        public String OrderType { get; set; }
        @AuraEnabled
        public String OrdDate { get; set; }       
        @AuraEnabled
        public Decimal OrdAmt { get; set; }
    }
    global class CompetitionData {
        @AuraEnabled
        public list<Competition__c> competitionList { get; set; }
        @AuraEnabled
        public list<Product_Category__c> productCategoryList { get; set; }
        @AuraEnabled
        public list<Product__c> productList { get; set; }
        @AuraEnabled
        public list<Competitor__c> competitorList { get; set; }
    }
    global class taskData {
        @AuraEnabled
        public String id { get; set; }
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public String status { get; set; }
        @AuraEnabled
        public Boolean checked { get; set; }
        @AuraEnabled
        public String icon { get; set; }
        @AuraEnabled
        public String classtoggle { get; set; }
        @AuraEnabled
        public String description { get; set; }
    }
    global class outstanding{
        @AuraEnabled
        public String invoiceId { get; set; }
        @AuraEnabled
        public String invoiceItemId { get; set; }
        @AuraEnabled
        public String invDate { get; set; }
        @AuraEnabled
        public String invNo { get; set; }
        @AuraEnabled
        public Decimal invAmt { get; set; }
    }
    global class paymentFollowUpData{
        @AuraEnabled public String Name;
        @AuraEnabled public String accName ;
        @AuraEnabled public decimal expectedAmount;
        @AuraEnabled public String id;
        @AuraEnabled public String comments;
        @AuraEnabled public String expctedDate;
        @AuraEnabled public String accId;
    }
    global class productive{
        @AuraEnabled public Decimal TSL;
        @AuraEnabled public Decimal LPPC;
        @AuraEnabled public Decimal productiveCalls;
        @AuraEnabled public String formattedDate;
        
    }
    global class categoryData {
        @AuraEnabled  public Id categoryId; // Category ID
        @AuraEnabled public String categoryName;
        @AuraEnabled public String salesId;
        @AuraEnabled public integer index1;
        @AuraEnabled public String focusSellId; // Selling Category ID
        @AuraEnabled public String focusSellName;
        @AuraEnabled public List<productData> products; // List of products in this category
    }
    global class visitData{
        @AuraEnabled public string Name;
        @AuraEnabled public date VisitDate;
        @AuraEnabled public String formattedVisitDate;
        @AuraEnabled public String actualEndtDateTimeString;
        @AuraEnabled public String actualStartDateTimeString;
        @AuraEnabled public String id;   
        @AuraEnabled public datetime createdDate;
        @AuraEnabled public String accountName;  
        @AuraEnabled public String acccountId;   
        @AuraEnabled public String appAccountId;
        @AuraEnabled public String dailyLogName;  
        @AuraEnabled public String dailyLogId;   
        @AuraEnabled public String dailylogAppId;
        @AuraEnabled public datetime plannedStartTime;   
        @AuraEnabled public datetime plannedEndTime; 
        @AuraEnabled public datetime actualStartTime;    
        @AuraEnabled public datetime actualEndTime;  
        @AuraEnabled public string salesAppId;
        @AuraEnabled public String comments; 
        @AuraEnabled public String missedReason;
        @AuraEnabled public String appVisitPlanId;
        @AuraEnabled public String visitPlanId;
        @AuraEnabled public String visitPlanName;
        @AuraEnabled public String typeofVisit;  
        @AuraEnabled public String status;   
        @AuraEnabled public Decimal checkinlatti;
        @AuraEnabled public Decimal checkinlongi;
        @AuraEnabled public Decimal outstanding; 
        @AuraEnabled public String lastVisitComment; 
        @AuraEnabled public double ClockInLatitude;
        @AuraEnabled public double ClockinLongitude;
        @AuraEnabled public double ClockoutLatitude;
        @AuraEnabled public double ClockoutLongitude;
        @AuraEnabled public string visitTypes;
        @AuraEnabled public string approvalStatus;
        @AuraEnabled public Integer lastvisitorder;
        @AuraEnabled public String beatId;
        @AuraEnabled public String beatItemId;
        @AuraEnabled public String pjpItemId;
        @AuraEnabled public boolean inLocation;
        @AuraEnabled public double customerLocationLattitude;
        @AuraEnabled public double customerLocationLongitude;
    }
    global class productData{
        @AuraEnabled public String id;
        @AuraEnabled public String proCate;
        @AuraEnabled public String name; 
        @AuraEnabled public String category;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal taxPercent;
        @AuraEnabled public String taxClass;
        @AuraEnabled public string createdDate;
        @AuraEnabled public integer value;
        @AuraEnabled public integer index2;
        @AuraEnabled public String salesId;
        @AuraEnabled public boolean offer;
        @AuraEnabled public boolean onHover;
        @AuraEnabled public String uom;        
        @AuraEnabled public String CustomerCode;
        @AuraEnabled public Decimal MRP;
        @AuraEnabled public String SKUCodeId;
        @AuraEnabled public String chevronIcon;
        @AuraEnabled public String classDropDown ;
        @AuraEnabled public boolean isDropdownTargetOpen;
        @AuraEnabled public String SKUCodeName;
        @AuraEnabled public Decimal UnitPricePriceBook;
        @AuraEnabled public Decimal originalUnitPrice;
        @AuraEnabled public Decimal discountedPrice;
        @AuraEnabled public Decimal discountedUnitPrice;
        @AuraEnabled public String categoryId;
        @AuraEnabled public String deliveryPlant;
        @AuraEnabled public String AlterNateUOM;
        @AuraEnabled public Decimal uomConversion;
        @AuraEnabled public boolean hasApplicableSchemes;
        @AuraEnabled public boolean appliedScheme;
        @AuraEnabled public Decimal total;
        @AuraEnabled public Decimal netWeight;
        @AuraEnabled public String subGroup;   // Product_Sub_Group__c, used for Category Value schemes

    }
    global class visitPlanData{
        @AuraEnabled public String appVisitPlanid;
        @AuraEnabled public String id;
        @AuraEnabled public datetime createdDate;
        @AuraEnabled public String month;
        @AuraEnabled public String year;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public String name;
        @AuraEnabled public String frequency;
        @AuraEnabled public String executiveId;
        @AuraEnabled public String executiveName;
        @AuraEnabled public visitPlan_visits[] visits;
    }
    global class visitPlan_visits {
        @AuraEnabled public datetime selectedDate;   
        @AuraEnabled public String visitPlanId;
        @AuraEnabled public String salesAppId;
        @AuraEnabled public String visitType;
        @AuraEnabled public String accountId;
        @AuraEnabled public String accountName;
        
    }
    global class expenseData{
        
        @AuraEnabled public decimal TAAMount;
        @AuraEnabled public decimal totalOtherAmount;
        @AuraEnabled public decimal totalKm;
        @AuraEnabled public decimal DtAmount;
        @AuraEnabled public decimal lineItemCount;
        @AuraEnabled public decimal TotalAmount;
        @AuraEnabled public String id;
        @AuraEnabled public Datetime expenseDate; 
        @AuraEnabled public String expenseName;
        @AuraEnabled public String executiveName; 
        @AuraEnabled public String executiveId;
        @AuraEnabled public String appExpId;
        @AuraEnabled public String approvalStatus;
        @AuraEnabled public String modeoftransport;
        @AuraEnabled public String comments;
        @AuraEnabled public String createdBy;
        @AuraEnabled public datetime createdDate;
        @AuraEnabled public cls_expenseItems[] expenseItems;
    }
    global class cls_expenseItems {
        @AuraEnabled public String allowanceType;
        @AuraEnabled public String ExpenseDate;
        @AuraEnabled public String FromCity;
        @AuraEnabled public String ToCity;
        @AuraEnabled public String expenseType;
        @AuraEnabled public String type;
        @AuraEnabled public String appExpItemId;
        @AuraEnabled public Decimal amount;  
        @AuraEnabled public String description;  
        @AuraEnabled public String ExpIDs; 
    }
    global class kpiData {
        @AuraEnabled
        public String pageHeader = 'Best Performer of the month';
        @AuraEnabled
        public List<String> names;
        @AuraEnabled
        public List<cls_kpi_sections> sections;
        @AuraEnabled
        public List<kpi_graph_target> graphlist;
        @AuraEnabled
        public List<kpi_target> targlist; // Add this if you want to return targets
    }
    global class kpi_graph_target {
        @AuraEnabled
        public decimal target;
        @AuraEnabled
        public decimal actual;
        @AuraEnabled
        public String xAxis;
    }
    global class cls_kpi_sections {
        @AuraEnabled
        public String sectionHeader;
        @AuraEnabled
        public List<String> columnHeaders;
        @AuraEnabled
        public List<cls_rows> rows;
    }
    global class cls_rows {
        @AuraEnabled
        public String rowName;
        @AuraEnabled
        public Decimal targetValue;
        @AuraEnabled
        public Decimal actualValue;
    }
    global class kpi_target {
        @AuraEnabled
        public String targetName;
        @AuraEnabled
        public Decimal target;
        @AuraEnabled
        public Decimal actual;
        @AuraEnabled
        public String Name;
        @AuraEnabled
        public String ownerName;
        @AuraEnabled
        public string kpiName;
        @AuraEnabled
        public decimal achivedPer;
    }
    global class LeadWrapper {
        @AuraEnabled public Lead lead;
        @AuraEnabled public List<String> photoUrls;
        @AuraEnabled public List<String> photoDocIds;
        
        public LeadWrapper(Lead l, List<String> urls, List<String> docIds) {
            lead = l;
            photoUrls = urls;
            photoDocIds = docIds;
        }
    }
    global class InvoiceData{
        string invoiceNumber;
        date invoiceDate;
        decimal outstandingAmount;
    }
    global class BeatData {
        @AuraEnabled public Id beatId;
        @AuraEnabled public String beatName;
        @AuraEnabled public Boolean istodayBeat;
        @AuraEnabled public Boolean isCurrentBeat;
        @AuraEnabled public Boolean isShowStartBeat;
        @AuraEnabled public Boolean openPopup;
        @AuraEnabled public String pjpDate;
        @AuraEnabled public String pjpId;
        @AuraEnabled public String ownerName;
    }

    /** ============ Scheme Coverage view (productScreen4 Task 3) ============ **/

    global class CoverageProductRef {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String sku { get; set; }
    }

    global class CoverageScheme {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String schemeType { get; set; }
        @AuraEnabled public String salesChannel { get; set; }
        @AuraEnabled public Date startDate { get; set; }
        @AuraEnabled public Date endDate { get; set; }
        @AuraEnabled public String validLabel { get; set; }
        @AuraEnabled public Id productGroupId { get; set; }
        @AuraEnabled public String productGroupName { get; set; }
        @AuraEnabled public String productCategory { get; set; }
        @AuraEnabled public List<CoverageProductRef> products { get; set; }
        @AuraEnabled public List<CoverageSlabRow> slabRows { get; set; }
        // Raw data consumed by the JS scheme engine (productScreen4)
        @AuraEnabled public List<Id> groupProductIds { get; set; }
        @AuraEnabled public List<CoverageSlabRaw> slabsRaw { get; set; }
    }

    global class CoverageSlabRow {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        public CoverageSlabRow(String l, String v) { this.label = l; this.value = v; }
    }

    // Raw numeric slab values for client-side scheme calculation.
    global class CoverageSlabRaw {
        @AuraEnabled public Id slabId { get; set; }
        @AuraEnabled public Decimal seq { get; set; }
        @AuraEnabled public String slabType { get; set; }
        @AuraEnabled public Decimal qtyMin { get; set; }
        @AuraEnabled public Decimal qtyMax { get; set; }
        @AuraEnabled public Decimal valMin { get; set; }
        @AuraEnabled public Decimal valMax { get; set; }
        @AuraEnabled public Decimal freeQty { get; set; }
        @AuraEnabled public Decimal benefitAmtPerEA { get; set; }
        @AuraEnabled public Decimal benefitPercent { get; set; }
        @AuraEnabled public Id focProductId { get; set; }
        @AuraEnabled public String focProductName { get; set; }
        @AuraEnabled public Decimal focUnitPrice { get; set; }
        @AuraEnabled public Decimal focTaxPercent { get; set; }
    }

    global class CoverageDto {
        @AuraEnabled public List<CoverageScheme> schemes { get; set; }
        @AuraEnabled public Map<Id, List<Id>> productSchemeIds { get; set; }
    }

  
}