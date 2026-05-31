/****************************************************************
* Class Name : userProfileLWC
* Company : Fingertipplus
* Created Date : 26-03-2025
* @description : This class handles user activity dashboard
* @author : Abhinav Singh / Mayuri Patel
* Used By : - userProfileLWC
* Change Log:
* -----------------------------------------------------------------------------
* Ver | Author | Date | Description
* -----------------------------------------------------------------------------
* 1.0 | Abhinav Singh |  23-03-2025 | Initial version
* 2.0 | Mayuri Patel  |  07-04-2025 | Updated Version
* -----------------------------------------------------------------------------
******************************************************************/
public with sharing class userProfileLWC {
    
    public class userData {
        @AuraEnabled public List<User> users { get; set; }
        @AuraEnabled public List<Map<String, String>> userDetails;
        @AuraEnabled public String userName;
        @AuraEnabled public String userId;
        @AuraEnabled public List<Junction_Beat__c> JunctionList { get; set; }
        @AuraEnabled public List<Holiday__c> holiday { get; set; }
        @AuraEnabled public List<Visit__c> Visit { get; set; }
        @AuraEnabled public List<Visit__c> Productive { get; set; }
        @AuraEnabled public List<Visit__c> nonProductive { get; set; }
        @AuraEnabled public List<Account> acc { get; set; }
        @AuraEnabled public List<Account> accounts {get; set;}
        // @AuraEnabled public List<Junction_Beat__c> junctonBeat { get; set; }
        @AuraEnabled public List<Map<String, String>> formattedUsersData { get; set; }
        @AuraEnabled public List<Map<String, String>> formattedUsersSales { get; set; }
        @AuraEnabled public List<Map<String, String>> addVisitAccountData { get; set; }
        @AuraEnabled public List<Map<String, String>> addVisitPicklistData { get; set; }
        @AuraEnabled public List<Map<String, String>> formattedUsersOrder { get; set; }
        @AuraEnabled public List<Map<String, String>> visitGraphlist { get; set; }
        @AuraEnabled public List<Map<String, String>> formattedUsersExp { get; set; }
        @AuraEnabled public List<Map<String, String>> statusOptions { get; set; }
        @AuraEnabled public List<Map<String, String>> attendanceData { get; set; }
        @AuraEnabled public List<Map<String, String>> duration { get; set; }
        @AuraEnabled public List<String> categoryPickList { get; set; }
        @AuraEnabled public List<String> regionPickList { get; set; }
        @AuraEnabled public List<String> primTypePickList { get; set; }
        @AuraEnabled public List<String> typePickList { get; set; }
        @AuraEnabled public User LoggedInUser { get; set; }
        @AuraEnabled public User SelectedUser { get; set; }
        //@AuraEnabled public List<kpi_graph_target> graphlist;
        @AuraEnabled public List<Map<String, Object>> graphlist;
        @AuraEnabled public List<VisData> visitData;
        @AuraEnabled public List<ordData> TotalOrderData;
        @AuraEnabled public List<invData> TotalInvoiceData;
        @AuraEnabled public List<BeatVisitWrapper> beatVisitList;
        @AuraEnabled public List<chBeatVisitWrapper> chBeatVisitList;
        @AuraEnabled public List<JnBeatWrapper> beatList;
        @AuraEnabled public List<jDBeatVisitWrapper> jDbeatList;
        @AuraEnabled public List<jDBeatVisitWrapper> sharedBeatList;
        @AuraEnabled public List<jDBeatVisitWrapper> HolidayList;
        @AuraEnabled public List<DateGroup> junctionBeat { get; set; }
        @AuraEnabled public List<dateWiseExpenseWrapper> dateWiseExpenses { get; set; }
        //@AuraEnabled public List<Map<String, String>> IncentiveData { get; set; }
        @AuraEnabled public List<incData> IncentiveData { get; set; }
        @AuraEnabled public List<AggregateData> agg { get; set; }
        @AuraEnabled public Map<String, Decimal> monthlyTotals { get; set; }
        @AuraEnabled public List<Visit__c> NonPjpVisit {get; set;}
        @AuraEnabled public List<Visit__c> PjpVisit {get; set;}
        @AuraEnabled public List<Account> newStores { get; set; }
        @AuraEnabled public List<Daily_Log__c> officeLocation { get; set; }
        @AuraEnabled public Calendar_beat__c calenderBeat { get; set; }
        
        @AuraEnabled public decimal exTotalAmt { get; set; }
        @AuraEnabled public string workingHrs { get; set; }
        @AuraEnabled public decimal kmTravel { get; set; }
        @AuraEnabled public Employee__c employeeRecord { get; set; }
        
        public userData() {
            this.agg = new List<AggregateData>();
        }
    }
    public class AggregateData {
        @AuraEnabled public String periodId;  // Period ID
        @AuraEnabled public String period;    // Period Name
        @AuraEnabled public String targetType;
        @AuraEnabled public Double totalActual = 0;
        @AuraEnabled public Double totalTarget = 0;
        @AuraEnabled public Double sumIncentive = 0;
        
        // Constructor to initialize Period ID and Name
        public AggregateData(String periodId, String periodName) {
            this.periodId = periodId;
            this.period = periodName;
        }
    }
    public class incData{
        @AuraEnabled public String period { get; set; }
        @AuraEnabled public String monthName { get; set; }
        @AuraEnabled public String amt { get; set; }
        @AuraEnabled public String exeId { get; set; }
        @AuraEnabled public String exeName { get; set; }
        @AuraEnabled public String incId { get; set; }
        @AuraEnabled public String startDt { get; set; }
        @AuraEnabled public String endDt { get; set; }
        @AuraEnabled public String creditDt { get; set; }
    }
    public class DateGroup {
        @AuraEnabled public String chBeatId { get; set; }
        @AuraEnabled public boolean isHoliday { get; set; }
        @AuraEnabled public String commonId { get; set; }
        @AuraEnabled public String BeatId { get; set; }
        @AuraEnabled public String JnId { get; set; }
        @AuraEnabled public String color { get; set; }
        @AuraEnabled public String dates { get; set; }  // The date in "YYYY-MM-DD" format
        @AuraEnabled public String name { get; set; }  // The child beat name
        @AuraEnabled public List<CalendarEvent> events { get; set; }  // List of events for this date
    }
    
    public class CalendarEvent {
        @AuraEnabled public String type { get; set; } // "Beat" or "Holiday"
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }  // Name of beat or holiday
        @AuraEnabled public Date visitDate { get; set; }
        @AuraEnabled public String color { get; set; }
        @AuraEnabled public String accName { get; set; }
        @AuraEnabled public String accId { get; set; }
        @AuraEnabled public String description { get; set; } // Only for Holidays
    }
    //when visit is used for pjp
    public class chBeatVisitWrapper {
        @AuraEnabled public String beatId;
        @AuraEnabled public String beatName;
        @AuraEnabled public date beatDate;
        @AuraEnabled public String formattedDate;
        @AuraEnabled public List<VisData> visits;
        @AuraEnabled public Integer orderNumber;
        
        public chBeatVisitWrapper(String beatId, String beatName,date beatDate, string formattedDate, Integer orderNumber ) {
            this.beatId = beatId;
            this.beatName = beatName;
            this.beatDate = beatDate;
            this.formattedDate = formattedDate;
            this.visits = new List<VisData>();
            this.orderNumber = orderNumber;
        }
    }
    
    public class jDBeatVisitWrapper {
        @AuraEnabled public String beatId;
        @AuraEnabled public String assbeatId;
        @AuraEnabled public String beatName;
        @AuraEnabled public String assbeatName;
        @AuraEnabled public boolean approvedBeat;
        @AuraEnabled public Date beatDate;
        @AuraEnabled public boolean isRepeat;
        @AuraEnabled public String formattedDate;
        //@AuraEnabled public String formattedDate;
        @AuraEnabled public List<junData> jdData;
        @AuraEnabled public List<accData> accountList;
        @AuraEnabled public Child_Beat__c mainBeat;
        @AuraEnabled public Integer orderNumber;
        @AuraEnabled public String pjpItemId;
        @AuraEnabled public String assignId;
        @AuraEnabled public String ApprovalStatus;
        
        public jDBeatVisitWrapper(String beatId, String beatName, Date beatDate, String formattedDate,boolean isRepeat, Integer orderNumber,String pjpItemId, String assignId) {
            this.beatId = beatId;
            this.beatName = beatName;
            this.beatDate = beatDate;
            this.formattedDate = formattedDate;
            this.isRepeat = isRepeat;
            this.jdData = new List<junData>();
            this.accountList = new List<accData>();
            this.mainBeat = new Child_Beat__c();
            this.orderNumber = orderNumber;
            this.pjpItemId = pjpItemId;
            this.assignId = assignId;
            this.ApprovalStatus = '';
        }
    }
    public class accData{
        @AuraEnabled public string accName;
        @AuraEnabled public string accId;
        @AuraEnabled public string JuncId;
        @AuraEnabled public string JuncName;
        @AuraEnabled public boolean isRepeat;
        @AuraEnabled public Integer orderNumber;
    }
    
    public class junData {
        @AuraEnabled public String jDId;
        @AuraEnabled public String Name;
        @AuraEnabled public string plannedDate;
        @AuraEnabled public String accId;
        @AuraEnabled public String accName;
        @AuraEnabled public string Childbeat;
        @AuraEnabled public String ownerId;
        @AuraEnabled public String VisitPlan;
    }
    
    public class JnBeatWrapper {
        @AuraEnabled public String Name;
        @AuraEnabled public String AccId;
        @AuraEnabled public String AccName;
        @AuraEnabled public String childBeatId;
        @AuraEnabled public String childBeatName;
        @AuraEnabled public Date visDate;
        @AuraEnabled public String visDateStr;
        @AuraEnabled public String visPlanID;
        @AuraEnabled public String visPlanName;
    }
    public class BeatVisitWrapper {
        @AuraEnabled public String beatId;
        @AuraEnabled public String beatName;
        @AuraEnabled public String monthYear;
        @AuraEnabled public date beatStartdate;
        @AuraEnabled public date beatEnddate;
        @AuraEnabled public List<VisData> visits;
        
        public BeatVisitWrapper(String beatId, String beatName,date beatEnddate, date beatStartdate,string monthYear ) {
            this.beatId = beatId;
            this.beatName = beatName;
            this.beatStartdate = beatStartdate;
            this.beatEnddate = beatEnddate;
            this.monthYear = monthYear;
            this.visits = new List<VisData>();
        }
    }
    public class kpi_graph_target {
        @AuraEnabled
        public decimal target;
        @AuraEnabled
        public decimal actual;
        @AuraEnabled
        public String xAxis;
    }
    public class VisData {
        @AuraEnabled public String name;
        @AuraEnabled public String plannedDate;
        @AuraEnabled public String ownerId;
        @AuraEnabled public String Productive;
        @AuraEnabled public String Childbeat;
        @AuraEnabled public String JunctionBeat;
        @AuraEnabled public String accId;
        @AuraEnabled public String accName;
        @AuraEnabled public String duration;
        @AuraEnabled public String visId;
        @AuraEnabled public String Status;
        
        @AuraEnabled public String startTime;
        @AuraEnabled public String endTime;
        @AuraEnabled public String visitType;
        @AuraEnabled public String customerType;
        @AuraEnabled public String locationType;
        
        
    }
    public class ordData {
        @AuraEnabled public String name;
        @AuraEnabled public String orderDate;
        @AuraEnabled public String accId;
        @AuraEnabled public String accName;
        @AuraEnabled public String customerCode;  
        @AuraEnabled public String sapCode;  
        @AuraEnabled public String orderfulfilmentStatus;  
        @AuraEnabled public Decimal Amount;
        @AuraEnabled public String ordId;
        @AuraEnabled public String Status;
        @AuraEnabled public integer ordItems;
        @AuraEnabled public String customerType;  
        @AuraEnabled public String visitName;  
        @AuraEnabled public String visitId;  
    }
    public class dateWiseExpenseWrapper {
        @AuraEnabled public Date beatDate { get; set; }
        @AuraEnabled public String formattedDate { get; set; }
        @AuraEnabled public List<expData> expData { get; set; }
        
        public dateWiseExpenseWrapper(Date beatDate, String formattedDate) {
            this.beatDate = beatDate;
            this.formattedDate = formattedDate;
            this.expData = new List<expData>();
        }
    }
    public class expData {
        @AuraEnabled public String name;
        @AuraEnabled public String expId;
        @AuraEnabled public Decimal Amount;
        @AuraEnabled public Decimal TA;
        @AuraEnabled public String Status;
        @AuraEnabled public Decimal DA;
        @AuraEnabled public date expDate;
        @AuraEnabled public string expDateStr;
        @AuraEnabled public Decimal otherAmt;
    }
    public class expSummary {
        @AuraEnabled public Decimal Total_TA = 0;
        @AuraEnabled public Decimal Total_DA = 0;
        @AuraEnabled public Decimal Total_Amount = 0;
        @AuraEnabled public Decimal Total_Other = 0;
    }
    
    public class invData {
        @AuraEnabled public String name;
        @AuraEnabled public String InvDate;
        @AuraEnabled public String accId;
        @AuraEnabled public String accName;
        @AuraEnabled public String customerCode;
        @AuraEnabled public String billNumber;
        @AuraEnabled public String SapOrderId;
        @AuraEnabled public String SalesforceOrderId;
        @AuraEnabled public String SalesforceOrderName;
        @AuraEnabled public String shipToPartyName;
        @AuraEnabled public String billtopartyGSTIN;
        @AuraEnabled public Decimal Amount;
        @AuraEnabled public String InvId;
        @AuraEnabled public String Status;
        @AuraEnabled public decimal InvItems;
        @AuraEnabled public decimal qtyEach;
        @AuraEnabled public decimal qtyCase;
    }
    
    @AuraEnabled
    public static userData getUserData(String empId) {
        userData dt = new userData();
        
        // Fetch active users with the specified licenses
        /*  dt.users = [SELECT Id, Name FROM User WHERE IsActive = true
            AND (Profile.UserLicense.Name = 'Salesforce Platform' OR Profile.UserLicense.Name = 'Salesforce')]; */
        string currentUserId = userinfo.getUserId();
        
        dt.LoggedInUser = [Select id,name,Profile.Name,User_Id__c,isActive from user where id =:currentUserId ];
        
        if(empId != null && empId != ''){
            dt.employeeRecord = [select id,name,User__c, PJP_Approver_1__c,PJP_Approver_2__c from Employee__c
                                 where Id =: empId];
            if(dt.employeeRecord.User__c != null)
            {
                dt.SelectedUser = [Select id,name,Profile.Name,User_Id__c,isActive from user where id =:dt.employeeRecord.User__c ];
            }
        }
        
        
        if(dt.LoggedInUser.Profile.Name == 'System Administrator'){
            dt.users = [SELECT Id, Name,Profile.Name,User_Id__c,isActive,Employee_Code__c,Profile_Name__c FROM User WHERE IsActive = true
                        AND (Profile.UserLicense.Name = 'Salesforce Platform' OR Profile.UserLicense.Name = 'Salesforce')];
        }
        else{
            Set<ID> UserIds = RoleHeirarchyUtility.getUsersUnderRoleHierarchy(currentUserId); 
            
            dt.users = [SELECT Id, Name,Profile.Name,User_Id__c,isActive,Employee_Code__c,Profile_Name__c FROM User WHERE IsActive = true
                        AND Id IN:UserIds ];
        }
        
        if (!dt.users.isEmpty()) {
            List<Map<String, String>> formattedUsersData = new List<Map<String, String>>();
            
            for (User us : dt.users) {
                Map<String, String> dataMap = new Map<String, String>();
                dataMap.put('label', us.Name);
                dataMap.put('value', us.Id);
                dataMap.put('profile', us.Profile.Name);
                formattedUsersData.add(dataMap);
            }
            
            dt.formattedUsersData = formattedUsersData;
        }
        dt.formattedUsersSales = salesData(userinfo.getUserId());
        dt.formattedUsersOrder = orderData(userinfo.getUserId());
        //  dt.formattedUsersExp = ExpenseData(userinfo.getUserId());
        dt.graphlist = targetData(userinfo.getUserId());
        dt.visitGraphlist = visitDataGraph(userinfo.getUserId());
        dt.regionPickList = getPicklistValues('User','Region__c');
        return dt;
    }
    
    @AuraEnabled
    public static userData AddVisitData(string ownerId){
        system.debug(ownerId);
        userData dt = new userData();
        dt.LoggedInUser = [Select id,name,Profile.Name,User_Id__c,isActive from user where id =:userinfo.getUserId() ];
        
        List<Account> accList = new  List<Account>();
        
        dt.SelectedUser = [Select id,name,Profile.Name,User_Id__c,isActive from user where id =:ownerId];
        
        if(dt.SelectedUser.Profile.Name == 'DSM' || dt.SelectedUser.Profile.Name == 'SSA'){
            accList = [SELECT Id, Name, Area__c, City__c, Customer_Category__c,Region__c,Division__c,
                       Phone, Customer_Type__c,SAP_Customer_Code__c,Primary_Customer_Business_Type__c,Primary_Customer_Type__c,
                       Secondary_Customer_Business_Type__c,Secondary_Customer_Type__c,Customer_Code__c,Primary_Phone_Number__c
                       FROM Account where Id IN  ( SELECT Customer__c
                                                  FROM Employee_Customer_Assignment__c
                                                  WHERE Executive__c = :ownerId) and Customer_Status__c != 'Inactive'   order by Name asc];
        }
        else{
            accList = [SELECT Id, Name, Area__c, City__c, Customer_Category__c,Region__c,Division__c,
                       Phone, Customer_Type__c,SAP_Customer_Code__c,Primary_Customer_Business_Type__c,Primary_Customer_Type__c,
                       Secondary_Customer_Business_Type__c,Secondary_Customer_Type__c,Customer_Code__c,Primary_Phone_Number__c
                       FROM Account where Id IN  ( SELECT Customer__c
                                                  FROM Product_Mapping__c
                                                  WHERE Exectuive__c = :ownerId) and Customer_Status__c != 'Inactive'  order by Name asc];
        }
        
        dt.accounts = accList;
        
        dt.categoryPickList = getPicklistValues('Account','Customer_Category__c');
        dt.regionPickList = getPicklistValues('Account','Region__c');
        dt.typePickList = getPicklistValues('Account','Secondary_Customer_Type__c');
        dt.primTypePickList = getPicklistValues('Account','Primary_Customer_Type__c');
        return dt;
            
            /* //List<Junction_Beat__c> jnBt = [Select id,name,Child_Beat__c];
        Set<String> uniqueAreas = new Set<String>();
        Set<String> uniqueCities = new Set<String>();
        List<Map<String, String>> formattedAccounts = new List<Map<String, String>>();
        for (Account acc : accList) {
        String formattedCreatedtDate = DateTime.newInstance(acc.createdDate.year(), acc.createdDate.month(), acc.createdDate.day()).format('dd/MM/yyyy');
        if(acc.Area__c != null){
        uniqueAreas.add(acc.Area__c);
        }
        if(acc.City__c != null){
        uniqueCities.add(acc.City__c);
        }
        Decimal totalSales = 0;
        Decimal totalOutstanding = 0;

        // Aggregate sales amount
        if (acc.Sales__r != null) {
        for (Sale__c sale : acc.Sales__r) {
        totalSales += sale.Total_Amount__c;
        }
        }

        // Aggregate outstanding amount
        if (acc.Outstandings__r != null) {
        for (Outstanding__c outstanding : acc.Outstandings__r) {
        totalOutstanding += outstanding.Amount__c;
        }
        }

        // Store formatted account data
        Map<String, String> accData = new Map<String, String>();
        accData.put('Id', acc.Id);
        accData.put('Name', acc.Name);
        accData.put('CustomerCode', acc.Customer_Code__c);
        accData.put('createdDate',formattedCreatedtDate);
        accData.put('Area', acc.Area__c != null ? acc.Area__c : null);
        accData.put('City', acc.City__c != null ? acc.City__c : null);
        accData.put('CustomerCategory', acc.Customer_Category__c != null ? acc.Customer_Category__c : null);
        accData.put('TotalSales', totalSales > 0 ? String.valueOf(totalSales.setScale(2)) : '0');
        accData.put('TotalOutstanding', totalOutstanding > 0 ? String.valueOf(totalOutstanding.setScale(2)) : '0');
        accData.put('Region', acc.Region__c != null ? acc.Region__c : null);
        accData.put('Division', acc.Division__c != null ? acc.Division__c : null);
        accData.put('Phone', acc.Primary_Phone_Number__c != null ? acc.Primary_Phone_Number__c : null);
        accData.put('CustomerType', acc.Customer_Type__c != null ? acc.Customer_Type__c : null);
        accData.put('SapCode', acc.SAP_Customer_Code__c != null ? acc.SAP_Customer_Code__c : null);
        accData.put('PrimaryCustomerType', acc.Primary_Customer_Type__c != null ? acc.Primary_Customer_Type__c : null);
        accData.put('PrimBusinessType', acc.Primary_Customer_Business_Type__c != null ? acc.Primary_Customer_Business_Type__c : null);
        accData.put('SecCustomerType', acc.Secondary_Customer_Type__c != null ? acc.Secondary_Customer_Type__c : null);
        accData.put('SecBusinessType', acc.Secondary_Customer_Business_Type__c != null ? acc.Secondary_Customer_Business_Type__c : null);

        formattedAccounts.add(accData);

        }
        system.debug('uniqueAreas :'+uniqueAreas);
        system.debug('uniqueCities :'+uniqueCities);
        dt.addVisitPicklistData = new List<Map<String, String>>();

        dt.addVisitPicklistData.add(
        new Map<String, String>{
        'Areas' => JSON.serialize(new List<String>(uniqueAreas )),
        'Cities' => JSON.serialize(new List<String>(uniqueCities))
        }
        );

        dt.addVisitAccountData = formattedAccounts; */
            
        
    }
    
    @AuraEnabled
    public static userData getRelatedAccs(String accId, String ownerId) {
        userData data = new userData();
        List<Account> accList = [SELECT Id, Name, Area__c, City__c, Customer_Category__c,Region__c,Division__c,
                                 Phone, Customer_Type__c,SAP_Customer_Code__c,Primary_Customer_Business_Type__c,Primary_Customer_Type__c,
                                 Secondary_Customer_Business_Type__c,Secondary_Customer_Type__c,Customer_Code__c,Primary_Phone_Number__c
                                 FROM Account where Id IN  ( SELECT Customer__c
                                                            FROM Product_Mapping__c
                                                            WHERE (Primary_Customer__c = :accId OR Sub_Stockiest__c = :accId) AND Exectuive__c = :ownerId)
                                 and Customer_Status__c != 'Inactive'  order by Name asc];
        
        data.accounts = accList;
        
        
        return data;
    }
    
    @AuraEnabled
    public static userData beatPlan(String ids, String beatTab) {
        
        userData dt = new userData();
        /*  dt.JunctionList = [SELECT Id, Name, Account__c, Account__r.Name,
        Child_beat__c, Child_beat__r.Name,ownerId,
        Visit_Date__c, Visit_Plan__c, Visit_Plan__r.Name,isRepeat__c,Order_Number__c
        FROM Junction_Beat__c
        WHERE Child_beat__c IN (select Beat__c from Beat_Assignment__c where User__c=: ids and Active__c = 'Yes')
        order by Order_Number__c asc nulls last]; */
        
        dt.JunctionList = [SELECT Id, Name, Account__c, Account__r.Name,
                           Child_beat__c, Child_beat__r.Name,
                           Visit_Date__c, Visit_Plan__c, Visit_Plan__r.Name,isRepeat__c,Order_Number__c
                           FROM Junction_Beat__c
                           WHERE Child_Beat__r.OwnerId =: ids and Active__c = true
                           order by Order_Number__c asc nulls last];
        
        if(beatTab == 'CalendarView'){
            dt.jDbeatList = calViewBeatData(ids);
        }
        else{
            dt.jDbeatList = pjpViewBeatData(ids);
        }
        
        // Fetch shared beats for the user
        dt.sharedBeatList = getSharedBeats(ids);
        
        dt.HolidayList = holidayBeatData(ids);
        List<Calendar_beat__c> beats = [SELECT Id,Start_Month__c,Next_Start_Date__c,Approval_Status__c,Recurring_Frequency__c,
                                        Next_PJP_Run__c,Last_PJP_Run__c FROM Calendar_beat__c
                                        WHERE OwnerId = :ids AND Active__c = true order by createddate desc limit 1];
        system.debug('beats :'+beats);
        if (!beats.isEmpty()) {
            dt.calenderBeat = beats[0]; // Assign the first record's ID
        } else {
            dt.calenderBeat = null; // Or handle the case when no record is found
            System.debug('No Calendar Beat records found for this month.');
        }
        return dt;
    }
    
    public static List<jDBeatVisitWrapper> pjpViewBeatData(String ids) {
        List<jDBeatVisitWrapper> beatList = new List<jDBeatVisitWrapper>();
        
        if (String.isBlank(ids)) {
            return beatList;
        }
        
        // Fetch Child_Beat__c records for the user in the current month, ordered by Name ASC
        /*  List<Child_Beat__c> childBeats = [SELECT Id, Name,isRepeat__c,Order_Number__c,
        (select Beat__c,Order_Number__c from Beat_Assignment__r where  User__c =:ids and Active__c = 'Yes'
        order by createddate desc limit 1)
        FROM Child_Beat__c
        WHERE Id IN (select Beat__c from Beat_Assignment__c where User__c =:ids and Active__c = 'Yes') 
        AND Active__c = true]; */
        List<Child_Beat__c> childBeats = [SELECT Id, Name,isRepeat__c,Order_Number__c,Beat_Type__c,
                                          Primary_Customer__c, Sub_Stockist__c,Primary_Customer__r.Name, Sub_Stockist__r.Name
                                          FROM Child_Beat__c
                                          WHERE OwnerId =:ids AND Active__c = true];
        
        
        if (childBeats.isEmpty()) {
            return beatList; // No child beats found, return empty list
        }
        
        // Collect Child_Beat__c IDs
        Set<Id> childBeatIds = new Set<Id>();
        for (Child_Beat__c cb : childBeats) {
            childBeatIds.add(cb.Id);
        }
        
        // Fetch Junction_Beat__c records related to Child_Beat__c
        List<Junction_Beat__c> junctionBeats = [SELECT Id, Name, Visit_Date__c, Child_Beat__c, Child_Beat__r.Name,
                                                Account__c, Account__r.Name,isRepeat__c,Order_Number__c
                                                FROM Junction_Beat__c
                                                WHERE Child_Beat__c IN :childBeatIds and Active__c = true ORDER BY Order_Number__c ASC nulls last];
        
        // Map Child_Beat__c IDs to related Junction_Beat__c records
        Map<Id, List<Junction_Beat__c>> childToJunctionMap = new Map<Id, List<Junction_Beat__c>>();
        for (Junction_Beat__c jb : junctionBeats) {
            if (!childToJunctionMap.containsKey(jb.Child_Beat__c)) {
                childToJunctionMap.put(jb.Child_Beat__c, new List<Junction_Beat__c>());
            }
            childToJunctionMap.get(jb.Child_Beat__c).add(jb);
        }
        
        // Process each Child_Beat__c in ASCENDING order
        for (Child_Beat__c cb : childBeats) {
            /* jDBeatVisitWrapper wrapper = new jDBeatVisitWrapper(cb.Id, cb.Name, null, '',cb.isRepeat__c,
        (Integer)cb.Beat_Assignment__r[0].Order_Number__c,null, cb.Beat_Assignment__r[0].Id); */ // Always use Child_Beat__c ID & Name
            
            jDBeatVisitWrapper wrapper = new jDBeatVisitWrapper(cb.Id, cb.Name, null, '',cb.isRepeat__c,
                                                                (Integer)cb.Order_Number__c, null, null);
            wrapper.mainBeat = cb;
            wrapper.accountList = new List<accData>(); // Initialize empty account list
            
            if (childToJunctionMap.containsKey(cb.Id)) {
                // If Child_Beat__c has related Junction_Beat__c records, add account details
                for (Junction_Beat__c jb : childToJunctionMap.get(cb.Id)) {
                    String formattedDate = jb.Visit_Date__c != null ? jb.Visit_Date__c.format() : '';
                    wrapper.beatDate = jb.Visit_Date__c;
                    wrapper.formattedDate = formattedDate;
                    
                    if (jb.Account__c != null) {
                        accData acc = new accData();
                        acc.accId = jb.Account__c;
                        acc.accName = jb.Account__r != null ? jb.Account__r.Name : '';
                        acc.JuncId = jb.Id;
                        acc.JuncName = jb.Name;
                        acc.isRepeat = jb.isRepeat__c;
                        acc.orderNumber = (Integer)jb.Order_Number__c;
                        wrapper.accountList.add(acc);
                    }
                }
            }
            
            beatList.add(wrapper);
        }
        
        return beatList;
    }
    
    // Get beats shared with the user via Child_beat__Share
    public static List<jDBeatVisitWrapper> getSharedBeats(String ids) {
        List<jDBeatVisitWrapper> sharedBeatList = new List<jDBeatVisitWrapper>();
        
        if (String.isBlank(ids)) {
            return sharedBeatList;
        }
        
        // Get beat IDs shared with this user (exclude owned beats)
        List<Child_beat__Share> beatShares = [SELECT ParentId FROM Child_beat__Share 
                                              WHERE UserOrGroupId = :ids 
                                              AND RowCause = 'Manual'];
        
        if (beatShares.isEmpty()) {
            return sharedBeatList;
        }
        
        Set<Id> sharedBeatIds = new Set<Id>();
        for (Child_beat__Share bs : beatShares) {
            sharedBeatIds.add(bs.ParentId);
        }
        
        // Fetch the shared Child_Beat__c records (exclude owned ones)
        List<Child_Beat__c> childBeats = [SELECT Id, Name, isRepeat__c, Order_Number__c, Beat_Type__c,
                                          Primary_Customer__c, Sub_Stockist__c, Primary_Customer__r.Name, Sub_Stockist__r.Name,
                                          Owner.Name
                                          FROM Child_Beat__c
                                          WHERE Id IN :sharedBeatIds AND Active__c = true AND OwnerId != :ids];
        
        if (childBeats.isEmpty()) {
            return sharedBeatList;
        }
        
        // Collect Child_Beat__c IDs
        Set<Id> childBeatIds = new Set<Id>();
        for (Child_Beat__c cb : childBeats) {
            childBeatIds.add(cb.Id);
        }
        
        // Fetch Junction_Beat__c records related to shared Child_Beat__c
        List<Junction_Beat__c> junctionBeats = [SELECT Id, Name, Visit_Date__c, Child_Beat__c, Child_Beat__r.Name,
                                                Account__c, Account__r.Name, isRepeat__c, Order_Number__c
                                                FROM Junction_Beat__c
                                                WHERE Child_Beat__c IN :childBeatIds AND Active__c = true 
                                                ORDER BY Order_Number__c ASC NULLS LAST];
        
        Map<Id, List<Junction_Beat__c>> childToJunctionMap = new Map<Id, List<Junction_Beat__c>>();
        for (Junction_Beat__c jb : junctionBeats) {
            if (!childToJunctionMap.containsKey(jb.Child_Beat__c)) {
                childToJunctionMap.put(jb.Child_Beat__c, new List<Junction_Beat__c>());
            }
            childToJunctionMap.get(jb.Child_Beat__c).add(jb);
        }
        
        Integer orderNum = 1;
        for (Child_Beat__c cb : childBeats) {
            jDBeatVisitWrapper wrapper = new jDBeatVisitWrapper(cb.Id, cb.Name, null, '', cb.isRepeat__c,
                                                                orderNum, null, null);
            wrapper.mainBeat = cb;
            wrapper.accountList = new List<accData>();
            
            if (childToJunctionMap.containsKey(cb.Id)) {
                for (Junction_Beat__c jb : childToJunctionMap.get(cb.Id)) {
                    String formattedDate = jb.Visit_Date__c != null ? jb.Visit_Date__c.format() : '';
                    wrapper.beatDate = jb.Visit_Date__c;
                    wrapper.formattedDate = formattedDate;
                    
                    if (jb.Account__c != null) {
                        accData acc = new accData();
                        acc.accId = jb.Account__c;
                        acc.accName = jb.Account__r != null ? jb.Account__r.Name : '';
                        acc.JuncId = jb.Id;
                        acc.JuncName = jb.Name;
                        acc.isRepeat = jb.isRepeat__c;
                        acc.orderNumber = (Integer)jb.Order_Number__c;
                        wrapper.accountList.add(acc);
                    }
                }
            }
            
            sharedBeatList.add(wrapper);
            orderNum++;
        }
        
        return sharedBeatList;
    }
    
    public static List<jDBeatVisitWrapper> calViewBeatData(String ids) {
        List<jDBeatVisitWrapper> beatList = new List<jDBeatVisitWrapper>();
        
        if (String.isBlank(ids)) {
            return beatList;
        }
        
        // Fetch Child_Beat__c records for the user in the current month, ordered by Name ASC
        /*  List<Child_Beat__c> childBeats = [SELECT Id, Name,isRepeat__c,Order_Number__c
                FROM Child_Beat__c
                WHERE OwnerId = :ids AND Active__c = true
                ORDER BY Order_Number__c ASC];*/
        
        List<PJP_Item__c> childBeats = [select Id,Name,Beat__c,Assigned_Beat__c,Date__c,PJP__c, Order_Number__c,Status__c,
                                        Beat__r.Name,Assigned_Beat__r.Name from PJP_Item__c where PJP__r.Active__c = true and PJP__R.OwnerId =: ids];
        
        if (childBeats.isEmpty()) {
            beatList = pjpViewBeatData(ids);
        }
        
        // Collect Child_Beat__c IDs
        Set<Id> childBeatIds = new Set<Id>();
        /* for (Child_Beat__c cb : childBeats) {
                childBeatIds.add(cb.Id);
                }*/
        for (PJP_Item__c cb : childBeats) {
            /* childBeatIds.add(cb.Status__c == 'Approved' ? cb.Beat__c : cb.Assigned_Beat__c); */
            if(cb.Beat__c != null) childBeatIds.add(cb.Beat__c);
            if(cb.Assigned_Beat__c != null) childBeatIds.add(cb.Assigned_Beat__c);
        }
        
        // Fetch Junction_Beat__c records related to Child_Beat__c
        List<Junction_Beat__c> junctionBeats = [SELECT Id, Name, Visit_Date__c, Child_Beat__c, Child_Beat__r.Name,
                                                Account__c, Account__r.Name,isRepeat__c,Order_Number__c
                                                FROM Junction_Beat__c
                                                WHERE Child_Beat__c IN :childBeatIds and Active__c = true ORDER BY Order_Number__c ASC nulls last];
        
        // Map Child_Beat__c IDs to related Junction_Beat__c records
        Map<Id, List<Junction_Beat__c>> childToJunctionMap = new Map<Id, List<Junction_Beat__c>>();
        for (Junction_Beat__c jb : junctionBeats) {
            if (!childToJunctionMap.containsKey(jb.Child_Beat__c)) {
                childToJunctionMap.put(jb.Child_Beat__c, new List<Junction_Beat__c>());
            }
            childToJunctionMap.get(jb.Child_Beat__c).add(jb);
        }
        
        // Process each Child_Beat__c in ASCENDING order
        //  for (Child_Beat__c cb : childBeats) {
        for (PJP_Item__c cb : childBeats) {
            // jDBeatVisitWrapper wrapper = new jDBeatVisitWrapper(cb.Id, cb.Name, null, '',cb.isRepeat__c, (Integer)cb.Order_Number__c); // Always use Child_Beat__c ID & Name
            /*  jDBeatVisitWrapper wrapper = new jDBeatVisitWrapper(cb.Status__c == 'Approved' ? cb.Beat__c : cb.Assigned_Beat__c,
                cb.Status__c == 'Approved' ? cb.Beat__r.Name : cb.Assigned_Beat__r.Name,
                cb.Date__c, '',false, (Integer)cb.Order_Number__c,cb.Id, null); // Always use Child_Beat__c ID & Name */
                            
            
            
            if(cb.Status__c == 'Approved' ){
                
                jDBeatVisitWrapper wrapper = new jDBeatVisitWrapper(cb.Beat__c ,  cb.Beat__r.Name,
                                                                    cb.Date__c, '',false, (Integer)cb.Order_Number__c,cb.Id, null); // Always use Child_Beat__c ID & Name
                
                wrapper.ApprovalStatus = cb.Status__c;
                wrapper.approvedBeat = true;
                
                wrapper.beatId = cb.Beat__c;
                wrapper.beatName = cb.Beat__r.Name;
                wrapper.accountList = new List<accData>(); // Initialize empty account list
                
                String formattedDate =  cb.Date__c != null ?  cb.Date__c.format() : '';
                wrapper.beatDate =  cb.Date__c;
                wrapper.formattedDate = formattedDate;
                
                
                if (childToJunctionMap.containsKey(cb.Beat__c)) {
                    
                    // If Child_Beat__c has related Junction_Beat__c records, add account details
                    for (Junction_Beat__c jb : childToJunctionMap.get(cb.Beat__c)) {
                        
                        System.debug(jb.Account__c);
                        
                        if (jb.Account__c != null) {
                            accData acc = new accData();
                            acc.accId = jb.Account__c;
                            acc.accName = jb.Account__r != null ? jb.Account__r.Name : '';
                            acc.JuncId = jb.Id;
                            acc.JuncName = jb.Name;
                            acc.isRepeat = jb.isRepeat__c;
                            acc.orderNumber = (Integer)jb.Order_Number__c;
                            
                            wrapper.accountList.add(acc);
                        }
                    }
                    
                }
                beatList.add(wrapper);
                
            }
            else{
                if(cb.Assigned_Beat__c != null){
                    jDBeatVisitWrapper wrapper2 = new jDBeatVisitWrapper(cb.Assigned_Beat__c ,  cb.Assigned_Beat__r.Name,
                                                                         cb.Date__c, '',false, (Integer)cb.Order_Number__c,cb.Id, null); // Always use Child_Beat__c ID & Name
                    
                    wrapper2.ApprovalStatus = cb.Status__c;
                    wrapper2.approvedBeat = false;
                    
                    wrapper2.beatId = cb.Assigned_Beat__c;
                    wrapper2.beatName = cb.Assigned_Beat__r.Name;
                    wrapper2.accountList = new List<accData>(); // Initialize empty account list
                    
                    String formattedDate =  cb.Date__c != null ?  cb.Date__c.format() : '';
                    wrapper2.beatDate =  cb.Date__c;
                    wrapper2.formattedDate = formattedDate;
                    
                    
                    
                    if (childToJunctionMap.containsKey(cb.Assigned_Beat__c)) {
                        
                        
                        // If Child_Beat__c has related Junction_Beat__c records, add account details
                        for (Junction_Beat__c jb : childToJunctionMap.get(cb.Assigned_Beat__c)) {
                            
                            
                            if (jb.Account__c != null) {
                                accData acc = new accData();
                                acc.accId = jb.Account__c;
                                acc.accName = jb.Account__r != null ? jb.Account__r.Name : '';
                                acc.JuncId = jb.Id;
                                acc.JuncName = jb.Name;
                                acc.isRepeat = jb.isRepeat__c;
                                acc.orderNumber = (Integer)jb.Order_Number__c;
                                
                                wrapper2.accountList.add(acc);
                            }
                        }
                        
                    }
                    beatList.add(wrapper2);
                }
                
                if(cb.Beat__c != null){
                    
                    jDBeatVisitWrapper wrapper = new jDBeatVisitWrapper(cb.Beat__c ,  cb.Beat__r.Name,
                                                                        cb.Date__c, '',false, (Integer)cb.Order_Number__c,cb.Id, null); // Always use Child_Beat__c ID & Name
                    
                    wrapper.ApprovalStatus = cb.Status__c;
                    wrapper.approvedBeat = true;
                    
                    wrapper.beatId = cb.Beat__c;
                    wrapper.beatName = cb.Beat__r.Name;
                    wrapper.accountList = new List<accData>(); // Initialize empty account list
                    
                    String formattedDate2 =  cb.Date__c != null ?  cb.Date__c.format() : '';
                    wrapper.beatDate =  cb.Date__c;
                    wrapper.formattedDate = formattedDate2;
                    
                    if (childToJunctionMap.containsKey(cb.Beat__c)) {
                        
                        
                        
                        // If Child_Beat__c has related Junction_Beat__c records, add account details
                        for (Junction_Beat__c jb : childToJunctionMap.get(cb.Beat__c)) {
                            
                            System.debug(jb.Account__c);
                            
                            if (jb.Account__c != null) {
                                accData acc = new accData();
                                acc.accId = jb.Account__c;
                                acc.accName = jb.Account__r != null ? jb.Account__r.Name : '';
                                acc.JuncId = jb.Id;
                                acc.JuncName = jb.Name;
                                acc.isRepeat = jb.isRepeat__c;
                                acc.orderNumber = (Integer)jb.Order_Number__c;
                                
                                wrapper.accountList.add(acc);
                            }
                        }
                        
                    }
                    beatList.add(wrapper);
                }
            }
        }
        
        return beatList;
    }
    
    public static List<jDBeatVisitWrapper> holidayBeatData(String ids) {
        List<jDBeatVisitWrapper> beatList = new List<jDBeatVisitWrapper>();
        
        if (String.isBlank(ids)) {
            return beatList;
        }
        List<User> selUser = [SELECT Id, Name, Region__c
                              FROM User
                              WHERE Id = :ids];
        
        
        
        String userRegion = selUser[0].Region__c;
        
        
        List<Holiday__c> holi = [SELECT id, name,Date__c from Holiday__c  WHERE Region__c INCLUDES (:userRegion)
                                 ORDER BY CreatedDate ASC];
        
        if (holi.isEmpty()) {
            return beatList; // No child beats found, return empty list
        }
        
        for(Holiday__c h:holi){
            String formattedDate = h.Date__c != null ? DateTime.newInstance(h.Date__c.year(), h.Date__c.month(), h.Date__c.day()).format('dd/MM/yyyy') : '';
            jDBeatVisitWrapper wrapper = new jDBeatVisitWrapper(h.Id, h.Name, h.Date__c, formattedDate,null,null,null,null);
            beatList.add(wrapper);
        }
        return beatList;
    }
    
    
    @AuraEnabled
    public static userData createPJP(String ids, Date startdate, String startBeat){
        
        
        List<Calendar_beat__c> pjps = [SELECT Id,Start_Month__c,Next_Start_Date__c,Recurring_Frequency__c,
                                       Next_PJP_Run__c,Last_PJP_Run__c FROM Calendar_beat__c
                                       WHERE OwnerId = :ids AND Active__c = true order by createddate desc limit 1];
        if (!pjps.isEmpty()) {
            List<PJP_Item__c> items = [select Id,Name,Beat__c,Assigned_Beat__c,Date__c,PJP__c, Order_Number__c,Status__c from PJP_Item__c
                                       where PJP__c = : pjps[0].Id and Date__c >=:System.TODAY()];
            
            Child_Beat__c selBeat = [SELECT Id, Name,isRepeat__c,Order_Number__c,Beat_Type__c,
                                     Primary_Customer__c, Sub_Stockist__c
                                     FROM Child_Beat__c WHERE id=:startBeat];
            
            List<Child_Beat__c> childBeats = [SELECT Id, Name,isRepeat__c,Order_Number__c,
                                              Primary_Customer__c, Sub_Stockist__c,Beat_Type__c
                                              FROM Child_Beat__c
                                              WHERE OwnerId =:ids AND  Active__c = true and Order_Number__c >= :selBeat.Order_Number__c order by Order_Number__c];
            
            
            
            
            
            List<User> selUser = [SELECT Id, Name, Region__c
                                  FROM User
                                  WHERE Id = :ids];
            
            String userRegion = selUser[0].Region__c;
            
            List<Holiday__c> holi = [SELECT id, name,Date__c from Holiday__c  WHERE Region__c INCLUDES (:userRegion)
                                     ORDER BY CreatedDate ASC];
            
            Set<Date> dates = new Set<Date>();
            
            for(Holiday__c hd: holi){
                dates.add(hd.Date__c);
            }
            
            if(!items.isEmpty()){
                try{
                    delete items;
                    items.clear();
                }
                catch(Exception e){
                    ExceptionHandler.addLog(e, String.valueOf(items), 'userProfileLWC.createPJP');
                }
                
            }
            
            List<PJP_Item__c> itemsToCreate = new List<PJP_Item__c>();
            if(items.isEmpty()){
                
                //Date dt = Date.today();
                Date dt = startdate;
                
                for(Child_Beat__c cb: childBeats){
                    
                    Integer dayOfWeek = dt.toStartOfWeek().daysBetween(dt);
                    
                    if(dayOfWeek == 0){
                        dt = dt.addDays(1);
                    }
                    else{
                        while(dates.contains(dt)){
                            dt = dt.addDays(1);
                        }
                    }
                    
                    
                    PJP_Item__c item = new PJP_Item__c();
                    item.PJP__c = pjps[0].Id;
                    item.Date__c = dt;
                    item.Beat__c = cb.Id;
                    item.Assigned_Beat__c = cb.Id;
                    //item.Beat__c = cb.Id;
                    /*  item.Order_Number__c = cb.Beat_Assignment__r[0].Order_Number__c; */
                    item.Order_Number__c = cb.Order_Number__c;
                    item.Status__c = 'Approved';
                    itemsToCreate.add(item);
                    dt = dt.addDays(1);
                }
            }
            if(!itemsToCreate.isEmpty()){
                try{
                    insert itemsToCreate;
                }
                catch(Exception e){
                    ExceptionHandler.addLog(e, String.valueOf(itemsToCreate), 'userProfileLWC.createPJP');
                }
                
            }
            
            
        }
        
        return beatPlan(ids,'CalendarView');
        
    }
    
    @AuraEnabled
    public static userData RotateBeats(String ids, Integer frequency){
        
        List<Calendar_beat__c> pjps = [SELECT Id,Start_Month__c,Next_Start_Date__c,Recurring_Frequency__c,
                                       Next_PJP_Run__c,Last_PJP_Run__c FROM Calendar_beat__c
                                       WHERE OwnerId = :ids AND Active__c = true order by createddate desc limit 1];
        
        
        if (!pjps.isEmpty()) {
            
            Date today = Date.today();
            Date newStartDate = today.addDays(-frequency); // Start from the next day after the last item
            
            List<PJP_Item__c> items = [select Id,Name,Beat__c,Assigned_Beat__c,Date__c,PJP__c, Order_Number__c,
                                       Status__c from PJP_Item__c
                                       where PJP__c = : pjps[0].Id and (Date__c <:System.TODAY() and Date__c >= :newStartDate) order by Date__c asc];     
            
            if (!items.isEmpty()) {
                
                pjps[0].Next_PJP_Run__c = today.addDays(frequency);
                pjps[0].Last_PJP_Run__c = today;
                pjps[0].Recurring_Frequency__c = frequency;
                // Create a map to store unique items by date
                Map<Date,PJP_Item__c> itemsMap = new Map<Date,PJP_Item__c>();
                for(PJP_Item__c itm : items){
                    if(!itemsMap.containsKey(itm.Date__c)){
                        itemsMap.put(itm.Date__c, itm);
                    }
                }
                Date pjpDate = today;
                List<PJP_Item__c> itemsToCreate = new List<PJP_Item__c>();
                while(newStartDate <= today){
                    if(itemsMap.containsKey(newStartDate)){
                        PJP_Item__c newItem = new PJP_Item__c();
                        newItem.PJP__c = pjps[0].Id;
                        newItem.Date__c = pjpDate;
                        newItem.Beat__c = itemsMap.get(newStartDate).Beat__c; // Set to null or appropriate value
                        newItem.Assigned_Beat__c = itemsMap.get(newStartDate).Beat__c; // Set to null or appropriate value
                        newItem.Order_Number__c = 1; // Set to default or appropriate value
                        newItem.Status__c = 'Approved'; // Set to default or appropriate value
                        itemsToCreate.add(newItem);
                    }
                    newStartDate = newStartDate.addDays(1);
                    pjpDate = pjpDate.addDays(1);
                }
                
                if(!itemsToCreate.isEmpty()){
                    try{
                        
                        delete [select Id from PJP_Item__c where PJP__c = :pjps[0].Id and Date__c >=:System.TODAY()];
                        
                        database.insert(itemsToCreate, false);
                        
                        update pjps[0];
                    }
                    catch(Exception e){
                        ExceptionHandler.addLog(e, String.valueOf(pjps), 'userProfileLWC.createPJP');
                    }
                    
                }
                
                
                
            }
            
            
        }
        
        
        return beatPlan(ids,'CalendarView');
        
    }
    
    @AuraEnabled
    public static void savePjpItems(String userId, List<PJP_Item__c> pjpItems) {
        
        List<Calendar_beat__c> beats = [SELECT Id,Start_Month__c,Next_Start_Date__c,Recurring_Frequency__c,
                                        Next_PJP_Run__c,Last_PJP_Run__c FROM Calendar_beat__c
                                        WHERE OwnerId = :userId AND Active__c = true order by createddate desc limit 1];
        
        Calendar_beat__c pjp;
        if (beats.isEmpty()) {
            
            Date dt = pjpItems[0].Date__c;
            
            // Create new PJP if none exists
            pjp = new Calendar_beat__c(
                OwnerId = userId,
                Start_Month__c = Date.newInstance(dt.year(), 1, 1),
                Next_Start_Date__c = Date.newInstance(dt.year(), 12, 31)
            );
            
            try{
                insert pjp;
            }
            catch(Exception e){
                ExceptionHandler.addLog(e, String.valueOf(pjp), 'userProfileLWC.savePjpItems');
            }
            
            
            
            for (PJP_Item__c itm : pjpItems) {
                itm.PJP__c = pjp.Id;
            }
            
        } else {
            pjp = beats[0];
        }
        
        
        if (!pjpItems.isEmpty()) {
            
            try{
                upsert pjpItems;
            }
            catch(Exception e){
                ExceptionHandler.addLog(e, String.valueOf(pjpItems), 'userProfileLWC.savePjpItems');
            }
        }
        
        
    }
    
    @AuraEnabled
    public static void deletePJPItem(Id pjpItemId) {
        try {
            // Find the record by Id
            PJP_Item__c itemToDelete = [SELECT Id FROM PJP_Item__c WHERE Id = :pjpItemId LIMIT 1];
            
            // Perform the delete operation
            delete itemToDelete;
        } catch (Exception e) {
            ExceptionHandler.addLog(e, pjpItemId, 'userProfileLWC.deletePJPItem');
            throw new AuraHandledException('Error deleting PJP_Item__c record: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void submitApprovalProcess(String userId, String pjpId) {
        
        if(pjpId == null){
            List<Calendar_beat__c> beats = [SELECT Id,Start_Month__c,Next_Start_Date__c,Recurring_Frequency__c,
                                            Next_PJP_Run__c,Last_PJP_Run__c FROM Calendar_beat__c
                                            WHERE OwnerId = :userId AND Active__c = true order by createddate desc limit 1];
            
            pjpId = beats[0].Id;
        }
        
        // 1. Submit the PJP record for approval
        Approval.ProcessSubmitRequest approvalRequest = new Approval.ProcessSubmitRequest();
        approvalRequest.setObjectId(pjpId);
        approvalRequest.setComments('Submitting for approval via PJP Calendar');
        
        // Submit the record for approval
        Approval.ProcessResult result = Approval.process(approvalRequest);
        
        if (result.isSuccess()) {
            System.debug('PJP submitted for approval');
            
            try{
                PJPItemHandler.updatePjpItemsAfterApproval(pjpId);
            }
            catch(Exception e){
                ExceptionHandler.addLog(e, pjpId, 'userProfileLWC.submitApprovalProcess');
            }
        } else {
            ExceptionHandler.addLog(null,String.valueof(result.getErrors()),'','','PJPID:'+pjpId+ '--' + 'UserId:'+userId, 'userProfileLWC.submitApprovalProcess');
            System.debug('Approval submission failed: ' + result.getErrors());
            throw new AuraHandledException('Failed to submit PJP for approval');
        }
       
    }
    
    
    @AuraEnabled
    public static void saveBeat(List<string> deleteIds,List<Junction_Beat__c> jnB){
        List<Junction_Beat__c> jn = [Select id from Junction_Beat__c where id=:deleteIds];
        system.debug('jun'+jn);
        system.debug('deleteJun'+deleteIds);
        if(!jn.isEmpty()){
            delete jn;
        }
        upsert jnB;
    }
    
    @AuraEnabled
    public static userData getAcc(){
        userData dt = new userData();
        dt.acc = [Select id,name from Account];
        
        return dt;
    }
    
    @AuraEnabled
    public static userData getHoliday(string ids){
        List<User> selUser = [SELECT Id, Name, Region__c
                              FROM User
                              WHERE Id = :ids];
        
        userData dt = new userData();
        
        // Ensure that selUser is not empty, and then get the Region__c from the first user
        if (!selUser.isEmpty()) {
            String userRegion = selUser[0].Region__c;
            
            dt.holiday = [SELECT Id, Name, Date__c, Description__c, Region__c, OwnerId
                          FROM Holiday__c
                          WHERE Region__c INCLUDES (:userRegion)
                          ORDER BY Date__c ASC];
        }
        
        return dt;
    }
    
    @AuraEnabled
    public static userData getAllUserDatas(String ids) {
        userData dt = new userData();
        
        List<User> users = [SELECT Id, Name, ProfileId, Username, Profile.Name, UserRoleId, UserRole.Name,
                            Alias, Address, ManagerId, Manager.Name, State__c, City, PostalCode, email,Street,
                            State, Country,User_Id__c
                            FROM User
                            WHERE Id = :ids];
        
        List<Employee__c> employees = [SELECT Id, Name,Employee_Code__c,Profile__c,User_Name__c,Mail_Id__c,Primary_Phone_Number__c,
                                       Role__c,Reporting_Manager__c,Reporting_Manager__r.Name ,Sales_Channel__c,State__c,District__c,Region__c,Pincode__c
                                       FROM Employee__c WHERE User__c = :ids LIMIT 1];
        
        if (!employees.isEmpty()) {
            Employee__c user = employees[0];
            dt.employeeRecord = employees[0];
            dt.userName = user.Name;
            dt.userId = user.Id;
            // Creating key-value pairs for iteration
            dt.userDetails = new List<Map<String, String>>();
            
            dt.userDetails.add(new Map<String, String>{
                'label' => 'Code', 'value' => user.Employee_Code__c
                    });
            dt.userDetails.add(new Map<String, String>{
                'label' => 'Profile', 'value' => user.Profile__c
                    });
            dt.userDetails.add(new Map<String, String>{
                'label' => 'Username', 'value' => user.User_Name__c
                    });
            dt.userDetails.add(new Map<String, String>{
                'label' => 'Email', 'value' => user.Mail_Id__c
                    });
            dt.userDetails.add(new Map<String, String>{
                'label' => 'Phone', 'value' => user.Primary_Phone_Number__c
                    });
            dt.userDetails.add(new Map<String, String>{
                'label' => 'User Role', 'value' => user.Role__c
                    });
            dt.userDetails.add(new Map<String, String>{
                'label' => 'Manager', 'value' => user.Reporting_Manager__c != null ? user.Reporting_Manager__r.Name : ''
                    });
            
            dt.userDetails.add(new Map<String, String>{
                'label' => 'Sales Channel', 'value' => user.Sales_Channel__c
                    });
            
            
            
            dt.userDetails.add(new Map<String, String>{
                'label' => 'State', 'value' => user.State__c
                    });
            dt.userDetails.add(new Map<String, String>{
                'label' => 'District', 'value' => user.District__c
                    });
            dt.userDetails.add(new Map<String, String>{
                'label' => 'Region', 'value' => user.Region__c
                    });
            dt.userDetails.add(new Map<String, String>{
                'label' => 'Pin Code', 'value' => user.Pincode__c
                    });
        }
        
                        /*   if (!users.isEmpty()) {
                User user = users[0];
                dt.userName = user.Name;
                dt.userId = user.Id;
                // Creating key-value pairs for iteration
                dt.userDetails = new List<Map<String, String>>();

                dt.userDetails.add(new Map<String, String>{
                'label' => 'Profile', 'value' => user.Profile.Name
                });
                dt.userDetails.add(new Map<String, String>{
                'label' => 'Username', 'value' => user.Username
                });
                dt.userDetails.add(new Map<String, String>{
                'label' => 'Email', 'value' => user.Email
                });
                dt.userDetails.add(new Map<String, String>{
                'label' => 'User Role', 'value' => user.UserRole.Name
                });
                dt.userDetails.add(new Map<String, String>{
                'label' => 'Alias', 'value' => user.Alias
                });
                dt.userDetails.add(new Map<String, String>{
                'label' => 'Manager', 'value' => user.Manager != null ? user.Manager.Name : ''
                });

                dt.userDetails.add(new Map<String, String>{
                'label' => 'Street', 'value' => user.Street
                });

                dt.userDetails.add(new Map<String, String>{
                'label' => 'State', 'value' => user.State__c
                });
                dt.userDetails.add(new Map<String, String>{
                'label' => 'City', 'value' => user.City
                });
                dt.userDetails.add(new Map<String, String>{
                'label' => 'Postal Code', 'value' => user.PostalCode
                });
                dt.userDetails.add(new Map<String, String>{
                'label' => 'Country', 'value' => user.Country
                });
                }*/
        
        return dt;
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
    public static userData graphDataDetails(id ids){
        
        userData dt = new userData();
        dt.formattedUsersSales = salesData(ids);
        dt.formattedUsersOrder = orderData(ids);
        // dt.formattedUsersExp = ExpenseData(ids);
        dt.graphlist = targetData(ids);
        dt.visitGraphlist = visitDataGraph(ids);
        return dt;
    }
    @AuraEnabled
    public static List<Map<String, String>> salesData(Id userId) {
        // Aggregate query to sum Grand_Total__c by month for the selected user
        List<AggregateResult> results = [
            SELECT CALENDAR_MONTH(Invoice_Date__c) month,
            CALENDAR_YEAR(Invoice_Date__c) year,
            SUM(Grand_Total__c) totalGrandTotal
            FROM Invoice__c
            WHERE Closed_Date__c = THIS_YEAR AND OwnerId =:userId
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
    public static List<Map<String, String>> orderData(Id userId){
        
        List<AggregateResult> results = [
            SELECT CALENDAR_MONTH(Order_Date__c) month,
            CALENDAR_YEAR(Order_Date__c) year,
            SUM(Grand_Total__c) totalGrandTotal
            FROM Order__c
            WHERE Order_Date__c = THIS_YEAR AND OwnerId =:userId
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
    public static List<Map<String, Object>> targetData(Id userId) {
        List<Target__c> tarList = [SELECT Id, Name, Achieved_Percentage__c, Executive__c, Executive__r.Name,
                                   Account__c, Actual__c, Target__c, Period__c, Period__r.Name
                                   FROM Target__c
                                   WHERE CreatedDate = THIS_YEAR AND OwnerId = :userId
                                   ORDER BY Achieved_Percentage__c DESC NULLS LAST
                                   LIMIT 5000];
        
        List<Map<String, Object>> graphList = new List<Map<String, Object>>();
        
        for (Target__c tr : tarList) {
            Map<String, Object> graph = new Map<String, Object>();
            graph.put('xAxis', tr.Period__r.Name);
            graph.put('actual', tr.Actual__c);
            graph.put('target', tr.Target__c);
            graphList.add(graph);
        }
        
        return graphList;
    }
    @AuraEnabled
    public static List<kpi_graph_target> targetData1(Id userId) {
        List<Target__c> tarList = [SELECT Id, Name, Achieved_Percentage__c, Executive__c, Executive__r.Name,
                                   Account__c, Actual__c, Target__c, Period__c, Period__r.Name
                                   FROM Target__c
                                   WHERE CreatedDate = THIS_YEAR AND OwnerId = :userId
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
    
    @AuraEnabled
    public static List<Map<String, String>> visitDataGraph(Id userId) {
        // Aggregate query to count visits per month for the selected user
        List<AggregateResult> results = [
            SELECT CALENDAR_MONTH(Planned_Start_Time__c) month,
            CALENDAR_YEAR(Planned_Start_Time__c) year,
            COUNT(Id) totalVisits
            FROM Visit__c
            WHERE Planned_Start_Time__c = THIS_YEAR
            AND OwnerId = :userId
            GROUP BY CALENDAR_MONTH(Planned_Start_Time__c), CALENDAR_YEAR(Planned_Start_Time__c)
            ORDER BY CALENDAR_YEAR(Planned_Start_Time__c) ASC, CALENDAR_MONTH(Planned_Start_Time__c) ASC
        ];
        
        // Month names mapping
        Map<Integer, String> monthNames = new Map<Integer, String>{
            1 => 'JAN', 2 => 'FEB', 3 => 'MAR', 4 => 'APR', 5 => 'MAY', 6 => 'JUN',
                7 => 'JUL', 8 => 'AUG', 9 => 'SEP', 10 => 'OCT', 11 => 'NOV', 12 => 'DEC'
                };
                    
                    List<Map<String, String>> formattedUsersVisits = new List<Map<String, String>>();
        
        for (AggregateResult ar : results) {
            Integer monthNum = (Integer) ar.get('month');
            Integer yearNum = (Integer) ar.get('year');
            Integer totalVisits = (Integer) ar.get('totalVisits'); // Get total visit count
            
            Map<String, String> dataMap = new Map<String, String>{
                'monthName' => monthNames.get(monthNum) + ' - ' + String.valueOf(yearNum),
                    'totalVisits' => String.valueOf(totalVisits)
                    };
                        
                        formattedUsersVisits.add(dataMap);
        }
        
        System.debug('Visit Data: ' + formattedUsersVisits);
        return formattedUsersVisits;
    }
    
    @AuraEnabled
    public static userData visitData(string ids,date frmDate, date toDate,string status,string duration){
        userData dt = new userData();
        List<Visit__c> vis = new List<Visit__c>();
        if(status == 'All' && duration == 'All'){
            vis = [SELECT id, name,Planned_start_Date__c,Account1__c,Account1__r.Name,Status__c,Actual_Start_Time__c,
                   Actual_End_Time__c,Duration__c,Lead__c,Lead__r.Name,Visit_for__c,OrderCreated__c,Visit_Output__c,
                   Location_Type__c,End_Time__c,Start_Time__c,Customer_Type__c,Child_beat__r.Name,Child_beat__c
                   from Visit__c
                   where ownerid=:ids and Status__c != null
                   AND Planned_start_Date__c >= :frmDate
                   AND Planned_start_Date__c <= :toDate order by Planned_start_Date__c desc];
        }
        else if (status != 'All' && duration == 'All'){
            vis = [SELECT id, name,Planned_start_Date__c,Account1__c,Account1__r.Name,Status__c,Actual_Start_Time__c,
                   Actual_End_Time__c,Duration__c,Lead__c,Lead__r.Name,Visit_for__c,OrderCreated__c,Visit_Output__c,
                   Location_Type__c,End_Time__c,Start_Time__c,Customer_Type__c,Child_beat__r.Name,Child_beat__c
                   from Visit__c
                   where ownerid=:ids and Status__c =: status
                   AND Planned_start_Date__c >= :frmDate
                   AND Planned_start_Date__c <= :toDate
                   order by Planned_start_Date__c desc];
        }
        else if (status != 'All' && duration != 'All'){
            vis = [SELECT id, name,Planned_start_Date__c,Account1__c,Account1__r.Name,Status__c,Actual_Start_Time__c,
                   Actual_End_Time__c,Duration__c,Lead__c,Lead__r.Name,Visit_for__c,OrderCreated__c,Visit_Output__c,
                   Location_Type__c,End_Time__c,Start_Time__c,Customer_Type__c,Child_beat__r.Name,Child_beat__c
                   from Visit__c
                   where ownerid=:ids and Status__c =: status
                   AND Planned_start_Date__c >= :frmDate
                   AND Planned_start_Date__c <= :toDate
                   AND Duration__c =:duration
                   order by Planned_start_Date__c desc];
        }
        else if (status == 'All' && duration != 'All'){
            vis = [SELECT id, name,Planned_start_Date__c,Account1__c,Account1__r.Name,Status__c,Actual_Start_Time__c,
                   Actual_End_Time__c,Duration__c,Lead__c,Lead__r.Name,Visit_for__c,OrderCreated__c,Visit_Output__c,
                   Location_Type__c,End_Time__c,Start_Time__c,Customer_Type__c,Child_beat__r.Name,Child_beat__c
                   from Visit__c
                   where ownerid=:ids and Status__c != null
                   AND Planned_start_Date__c >= :frmDate
                   AND Planned_start_Date__c <= :toDate
                   AND Duration__c =:duration
                   order by Planned_start_Date__c desc];
        }
        List<Map<String, String>> DurationOptions = new List<Map<String, String>>();
        Map<String, String> durOption = new Map<String, String>();
        durOption.put('label', 'All');
        durOption.put('value', 'All');
        DurationOptions.add(durOption);
        List<VisData> visDt = new List<VisData>();
        for(Visit__c v:vis){
            String formattedPlannedDate = v.Planned_start_Date__c != null ? DateTime.newInstance(v.Planned_start_Date__c.year(), v.Planned_start_Date__c.month(), v.Planned_start_Date__c.day()).format('dd/MM/yyyy') : '';
            VisData vD = new VisData();
            vD.name = v.Name;
            vD.visId = v.Id;
            vD.plannedDate = formattedPlannedDate;
            vD.accId = v.Account1__c != null ? v.Account1__c : v.Lead__c;
            vD.accName = v.Account1__c != null ? v.Account1__r.Name : v.Lead__r.Name;
            vD.duration = v.Duration__c;
            vD.Productive = v.Visit_Output__c =='PJP Successful' ? 'Yes' : 'No';
            vD.Status = v.Status__c;
            vD.startTime = v.Start_Time__c;
            vD.endTime = v.End_Time__c;
            vD.visitType = v.Visit_for__c;  
            vD.customerType = v.Customer_Type__c;  
            vD.locationType = v.Location_Type__c;  
            vD.Childbeat = v.Child_beat__c != null ? v.Child_beat__r.Name : ''; 
            
            
            visDt.add(vD);
            if(v.Duration__c != null){
                Map<String, String> dataMap = new Map<String, String>();
                dataMap.put('label', v.Duration__c);
                dataMap.put('value', v.Duration__c);
                DurationOptions.add(dataMap);
            }
        }
        dt.visitData = visDt;
        dt.duration = DurationOptions;
        List<Map<String, String>> statusOptions = new List<Map<String, String>>();
        List<String> ordStatus = getPicklistValues('Visit__c', 'Status__c');
        
        Map<String, String> allOption = new Map<String, String>();
        allOption.put('label', 'All');
        allOption.put('value', 'All');
        statusOptions.add(allOption);
        
        for (String str : ordStatus) {
            Map<String, String> dataMap = new Map<String, String>();
            dataMap.put('label', str);
            dataMap.put('value', str);
            statusOptions.add(dataMap);
        }
        
        dt.statusOptions = statusOptions;
        
        return dt;
    }
    
    @AuraEnabled
    public static userData allOrderData(string ids,String status,Date frmDate, date toDate){
        userData dt = new userData();
        List<Order__c> ord = new List<Order__c>();
        if (status == 'All') {
            ord = [
                SELECT Id, Name, Account__c, Order_Date__c, Order_Status__c, Grand_Total__c, Account__r.Name,Account__r.Customer_Type__c,
                Status__c,Order_Fulfillment_Status__c,Delivery_Plant__c,Account__r.SAP_Customer_Code__c,Account__r.Customer_Code__c,Visit__c,
                Visit__r.Name, (SELECT Id FROM Order_Items__r)
                FROM Order__c
                WHERE OwnerId = :ids
                AND Order_Date__c >= :frmDate
                AND Order_Date__c <= :toDate
                AND Account__c != null
                Order By Account__c
               
            ];
        } else {
            ord = [
                SELECT Id, Name, Account__c, Order_Date__c, Order_Status__c, Grand_Total__c,Account__r.Name,Account__r.Customer_Type__c,
                Status__c,Order_Fulfillment_Status__c,Delivery_Plant__c,Account__r.SAP_Customer_Code__c,Account__r.Customer_Code__c,Visit__c,
                Visit__r.Name,(SELECT Id FROM Order_Items__r)
                FROM Order__c
                WHERE OwnerId = :ids
                AND Order_Status__c = :status
                AND Order_Date__c >= :frmDate
                AND Order_Date__c <= :toDate
                AND Account__c != null
                Order By Account__c
            ];
        }
        
        
        List<ordData> ordDt = new List<ordData>();
        for(Order__c o:ord){
            String formattedOrdDate = o.Order_Date__c != null ? DateTime.newInstance(o.Order_Date__c.year(), o.Order_Date__c.month(), o.Order_Date__c.day()).format('dd/MM/yyyy') : '';
            ordData oD = new ordData();
            oD.name = o.Name;
            oD.ordId = o.Id;
            oD.orderDate = formattedOrdDate;
            oD.customerType = o.Account__r != null? o.Account__r.Customer_Type__c : '';
            oD.accId = o.Account__c ;
            oD.accName =  o.Account__r.Name ;
            oD.Amount = o.Grand_Total__c;
            oD.customerCode = o.Account__r != null? o.Account__r.Customer_Code__c : '';
            oD.sapCode =  o.Account__r != null? o.Account__r.SAP_Customer_Code__c : '';
            oD.orderfulfilmentStatus = o.Order_Fulfillment_Status__c; 
            oD.Status = o.Status__c;
            oD.visitId = o.Visit__c;
            oD.visitName = o.Visit__r != null ? o.Visit__r.Name : '';
            oD.ordItems = o.Order_Items__r.size();
            ordDt.add(oD);
        }
        dt.TotalOrderData = ordDt;
        List<Map<String, String>> statusOptions = new List<Map<String, String>>();
        List<string> ordStatus = getPicklistValues('Order__c','Order_Status__c');
        Map<String, String> allOption = new Map<String, String>();
        allOption.put('label', 'All');
        allOption.put('value', 'All');
        statusOptions.add(allOption);
        for(String str: ordStatus){
            Map<String, String> dataMap = new Map<String, String>();
            dataMap.put('label', str);
            dataMap.put('value', str);
            statusOptions.add(dataMap);
        }
        dt.statusOptions = statusOptions;
        return dt;
    }
    
    @AuraEnabled
    public static userData allInvoiceData(string ids,String status,Date frmDate, date toDate){
        userData dt = new userData();
        List<Invoice_item__c> invItems = new List<Invoice_item__c>();
        invItems = [
            SELECT Id, Name, Store__c,Bill_Date__c,Bill_Amount__c,Bill_to_Party__c,Bill_to_party_name__c,
            Bill_Number__c,	SAP_Order_Id__c,Order__c,Ship_to_party_name__c,Bill_to_party_GSTIN__c,Order__r.Name,
            Qyt_in_Each__c,	Qyt__c,Invoice__r.Name,Invoice__c
            FROM Invoice_item__c WHERE OwnerId = :ids
            AND Bill_Date__c >= :frmDate AND Bill_Date__c <= :toDate AND Invoice__c != null
        ];  
        
        Map<String, invData> invoiceMap = new Map<String, invData>();
        
        for (Invoice_item__c i : invItems) {
            // Format date
            String formattedOrdDate = i.Bill_Date__c != null 
                ? DateTime.newInstance(i.Bill_Date__c.year(), i.Bill_Date__c.month(), i.Bill_Date__c.day()).format('dd/MM/yyyy') 
                : '';
            
            // Check if invoice already exists for this Bill Number
            if (!invoiceMap.containsKey(i.Bill_Number__c)) {
                invData inD = new invData();
                inD.name = i.Invoice__r.Name;
                inD.InvDate = formattedOrdDate;
                inD.InvId = i.Invoice__c;
                inD.accName = i.Bill_to_party_name__c;
                inD.customerCode = i.Bill_to_Party__c; 
                inD.billNumber = i.Bill_Number__c; 
                inD.SapOrderId = i.SAP_Order_Id__c; 
                inD.SalesforceOrderId = i.Order__c; 
                inD.SalesforceOrderName = i.Order__r != null ? i.Order__r.Name : null;
                inD.shipToPartyName = i.Ship_to_party_name__c;
                inD.billtopartyGSTIN = i.Bill_to_party_GSTIN__c;
                inD.qtyCase = 0;
                inD.qtyEach = 0;
                inD.InvItems = 0; 
                inD.Amount = 0;   
                invoiceMap.put(i.Bill_Number__c, inD);
            }
            
            // Update invoice aggregation
            invData existing = invoiceMap.get(i.Bill_Number__c);
            existing.Amount += (i.Bill_Amount__c != null ? i.Bill_Amount__c : 0);
            existing.qtyEach += (i.Qyt_in_Each__c != null ? i.Qyt_in_Each__c : 0);
            existing.qtyCase += (i.Qyt__c != null ? i.Qyt__c : 0);
            existing.InvItems += 1;
        }
        
        dt.TotalInvoiceData =  new List<invData>(invoiceMap.values());
        List<Map<String, String>> statusOptions = new List<Map<String, String>>();
        List<string> ordStatus = getPicklistValues('Invoice__c','Status__c');
        Map<String, String> allOption = new Map<String, String>();
        allOption.put('label', 'All');
        allOption.put('value', 'All');
        statusOptions.add(allOption);
        for(String str: ordStatus){
            Map<String, String> dataMap = new Map<String, String>();
            dataMap.put('label', str);
            dataMap.put('value', str);
            statusOptions.add(dataMap);
        }
        dt.statusOptions = statusOptions;
        return dt;
    }
    @AuraEnabled
    public static userData allExpData(String ids, String status, Date frmDate, Date toDate) {
        userData dt = new userData();
                    /*   List<Expense__c> expList = new List<Expense__c>();

            if (status == 'All') {
            expList = [
            SELECT Id, Name, Total_TA_amount__c, Approval_Status__c, Total_DA_amount__c,Total_Amount_DA__c,
            Expense_From_Date__c, Expense_To_Date__c, Other_Expenses__c,Total_Amount_TA__c,
            Total_Amount__c, Total_other_amount__c
            FROM Expense__c
            WHERE OwnerId = :ids
            AND Expense_From_Date__c >= :frmDate
            AND Expense_To_Date__c <= :toDate
            ];
            } else {
            expList = [
            SELECT Id, Name, Total_TA_amount__c, Approval_Status__c, Total_DA_amount__c,Total_Amount_DA__c,
            Expense_From_Date__c, Expense_To_Date__c, Other_Expenses__c,Total_Amount_TA__c,
            Total_Amount__c, Total_other_amount__c
            FROM Expense__c
            WHERE OwnerId = :ids
            AND Approval_Status__c = :status
            AND Expense_From_Date__c >= :frmDate
            AND Expense_To_Date__c <= :toDate
            ];
            }

            // Map to group expenses by date
            Map<String, dateWiseExpenseWrapper> expensesByDate = new Map<String, dateWiseExpenseWrapper>();

            for (Expense__c ex : expList) {
            if (ex.Expense_From_Date__c == null) continue; // Skip null dates

            // Convert date to 'DD/MM/YYYY' format
            String formattedDate = ex.Expense_From_Date__c != null ? DateTime.newInstance(ex.Expense_From_Date__c.year(), ex.Expense_From_Date__c.month(), ex.Expense_From_Date__c.day()).format('dd/MM/yyyy') : '';


            // If this date is not in the map, create a new wrapper
            if (!expensesByDate.containsKey(formattedDate)) {
            expensesByDate.put(formattedDate, new dateWiseExpenseWrapper(ex.Expense_From_Date__c, formattedDate));
            }

            // Create expData object
            expData expD = new expData();
            expD.name = ex.Name;
            expD.expId = ex.Id;
            expD.expDate = ex.Expense_From_Date__c;
            expD.expDateStr = formattedDate;
            expD.Amount = ex.Total_Amount__c;
            expD.Status = ex.Approval_Status__c;
            expD.TA = ex.Total_Amount_TA__c;
            expD.DA = ex.Total_Amount_DA__c;
            expD.otherAmt = ex.Total_other_amount__c;

            // Add expense data to the respective date group
            expensesByDate.get(formattedDate).expData.add(expD);
            }

            // Set the final list in userData
            dt.dateWiseExpenses = new List<dateWiseExpenseWrapper>(expensesByDate.values());

            // Status options for filtering
            List<Map<String, String>> statusOptions = new List<Map<String, String>>();
            List<String> ordStatus = getPicklistValues('Expense__c', 'Approval_Status__c');

            Map<String, String> allOption = new Map<String, String>();
            allOption.put('label', 'All');
            allOption.put('value', 'All');
            statusOptions.add(allOption);

            for (String str : ordStatus) {
            Map<String, String> dataMap = new Map<String, String>();
            dataMap.put('label', str);
            dataMap.put('value', str);
            statusOptions.add(dataMap);
            }

            dt.statusOptions = statusOptions;*/
        
        return dt;
    }
    
    
    @AuraEnabled
    public static userData attendance(String ids, Date frmDate, Date toDate, String status) {
        
        userData dt = new userData();
        List<Map<String, String>> formattedAttendanceData = new List<Map<String, String>>();
        
        // ========================================================
        //FETCH DAILY LOGS
        //========================================================== 
        List<Daily_Log__c> logs = [
            SELECT Id, Name, Total_Working_Hours__c, Day_started_time__c,
            Start_time__c, End_Time__c,
            First_Visit_Time1__c, Last_Visit_Time1__c,
            Total_Order_Amount__c, Primary_Order_Amount__c, Secondary_Order_Amont__c,
            TLSD__c, TLSD_Primary__c, TLSD_Retailers_Outlets__c, TLSD_Sub_Stockist__c,
            Assigned_Beat_Name__c, Worked_Beat_Name__c,
            Beat_Switch_History__c, Distributor_Id__c, Distributor_Name__c,
            New_Calls__c, Collection_Calls__c, Stock_Calls__c,
            Total_Visits__c, Outlets_Not_Visited__c, Total_Productive_Calls__c,
            Prouctive_Calls_Made__c, Total_Outlets__c,
            Distance_Travelled__c, Distance_Travelled_by_Odometer__c,
            Total_Calls__c, Non_PJP_Order_Calls__c,
            Total_Productive_Calls_Made__c, Non_PJP_Productive_Calls__c,
            No_Of_Outlets_from_Non_PJP_Order__c,
            Total_No_of_Outlets__c, Calls_Made__c, Return_Calls__c,No_of_Outlets_from_Visit_forms__c,
            Total_No_of_Beat_Non_PJP_Order__c,Visit_Form_Total_Calls__c,Visit_Form_Unique_Calls__c,
            (SELECT minute_duration__c FROM Visits__r WHERE status__c = 'Completed')
            FROM Daily_Log__c
            WHERE DAY_ONLY(Day_started_time__c) >= :frmDate
            AND DAY_ONLY(Day_started_time__c) <= :toDate
            AND OwnerId = :ids
            ORDER BY Day_started_time__c ASC
        ];
        
        //=========================================================
        // CONVERT LOGS TO MAP (Date → Log)
        //========================================================== 
        Map<Date, Daily_Log__c> logMap = new Map<Date, Daily_Log__c>();
        
        for (Daily_Log__c log : logs) {
            logMap.put(log.Day_started_time__c.date(), log);
        }
        
        //=========================================================
        //FETCH LEAVES FOR USER IN DATE RANGE
        //========================================================== 
        List<Leaves__c> leaveList = [
            SELECT Id, User__c, From_Date__c, To_Date__c
            FROM Leaves__c
            WHERE User__c = :ids
            AND From_Date__c <= :toDate
            AND To_Date__c >= :frmDate
            AND ApprovalStatus__c IN ('Leave Approved','Submitted for Approval','Not Submitted')
            AND Leave_Cancellation_Status__c != 'Submitted for Cancellation' AND Leave_Cancellation_Status__c != 'Cancellation Approved'
            AND Session_Type__c = null
        ];
        
        
        // LEAVE MAP (Date → Leave Record)
        // ======================================================== 
        Map<Date, Leaves__c> leaveMap = new Map<Date, Leaves__c>();
        
        for (Leaves__c lv : leaveList) {
            for (Date d = lv.From_Date__c; d <= lv.To_Date__c; d = d.addDays(1)) {
                leaveMap.put(d, lv);
            }
        }
        
        //=========================================================
        // LOOP DATE RANGE
        //========================================================== 
        for (Date currentDate = frmDate; currentDate <= toDate; currentDate = currentDate.addDays(1)) {
            
            Map<String, String> record = new Map<String, String>();
            record.put('Date', String.valueOf(currentDate));
            
            Datetime dtTime = Datetime.newInstance(currentDate.year(), currentDate.month(), currentDate.day());
            String dayOfWeek = dtTime.format('EEEE');
            
            // =====================================================
            //  PRESENT
            // =====================================================
            if (logMap.containsKey(currentDate)) {
                
                Daily_Log__c log = logMap.get(currentDate);
                record.put('Id', log.Id);
                record.put('Name', log.Name);
                record.put('Status', 'Present');
                record.put('StartTime', String.valueOf(log.Start_time__c));
                record.put('EndTime', String.valueOf(log.End_Time__c));
                record.put('TotalHours', String.valueOf(log.Total_Working_Hours__c));
                record.put('First_Visit_Time1__c', String.valueOf(log.First_Visit_Time1__c));
                record.put('Last_Visit_Time1__c', String.valueOf(log.Last_Visit_Time1__c));
                record.put('Total_Order_Amount__c', String.valueOf(log.Total_Order_Amount__c));
                record.put('Primary_Order_Amount__c', String.valueOf(log.Primary_Order_Amount__c));
                record.put('Secondary_Order_Amont__c', String.valueOf(log.Secondary_Order_Amont__c));
                record.put('TLSD__c', String.valueOf(log.TLSD__c));
                record.put('TLSD_Primary__c', String.valueOf(log.TLSD_Primary__c));
                record.put('TLSD_Retailers_Outlets__c', String.valueOf(log.TLSD_Retailers_Outlets__c));
                record.put('TLSD_Sub_Stockist__c', String.valueOf(log.TLSD_Sub_Stockist__c));
                record.put('Assigned_Beat_Name__c', String.valueOf(log.Assigned_Beat_Name__c));
                record.put('Worked_Beat_Name__c', String.valueOf(log.Worked_Beat_Name__c));
                record.put('Beat_Switch_History__c', String.valueOf(log.Beat_Switch_History__c));
                record.put('Distributor_Id__c', String.valueOf(log.Distributor_Id__c));
                record.put('Distributor_Name__c', String.valueOf(log.Distributor_Name__c));
                record.put('New_Calls__c', String.valueOf(log.New_Calls__c));
                record.put('Collection_Calls__c', String.valueOf(log.Collection_Calls__c));
                record.put('Stock_Calls__c', String.valueOf(log.Stock_Calls__c));
                record.put('Total_Visits__c', String.valueOf(log.Total_Visits__c));
                record.put('Outlets_Not_Visited__c', String.valueOf(log.Outlets_Not_Visited__c));
                record.put('Total_Productive_Calls__c', String.valueOf(log.Total_Productive_Calls__c));
                record.put('Prouctive_Calls_Made__c', String.valueOf(log.Prouctive_Calls_Made__c));
                record.put('Total_Outlets__c', String.valueOf(log.Total_Outlets__c));
                record.put('Distance_Travelled__c', String.valueOf(log.Distance_Travelled__c));
                record.put('Distance_Travelled_by_Odometer__c', String.valueOf(log.Distance_Travelled_by_Odometer__c));
                record.put('Total_Calls__c', String.valueOf(log.Total_Calls__c));
                record.put('Non_PJP_Order_Calls__c', String.valueOf(log.Non_PJP_Order_Calls__c));
                record.put('Total_Productive_Calls_Made__c', String.valueOf(log.Total_Productive_Calls_Made__c));
                record.put('Non_PJP_Productive_Calls__c', String.valueOf(log.Non_PJP_Productive_Calls__c));
                record.put('No_Of_Outlets_from_Non_PJP_Order__c', String.valueOf(log.No_Of_Outlets_from_Non_PJP_Order__c));
                record.put('Total_No_of_Outlets__c', String.valueOf(log.Total_No_of_Outlets__c));
                record.put('Calls_Made__c', String.valueOf(log.Calls_Made__c));
                record.put('Return_Calls__c', String.valueOf(log.Return_Calls__c));
                
                record.put('No_of_Outlets_from_Visit_forms__c', String.valueOf(log.No_of_Outlets_from_Visit_forms__c));
                record.put('Total_No_of_Beat_Non_PJP_Order__c', String.valueOf(log.Total_No_of_Beat_Non_PJP_Order__c));
                record.put('Visit_Form_Unique_Calls__c', String.valueOf(log.Visit_Form_Unique_Calls__c));
                record.put('Visit_Form_Total_Calls__c', String.valueOf(log.Visit_Form_Total_Calls__c));
                
                
                Decimal totalVisitMinutes = 0;
                for (Visit__c visit : log.Visits__r) {
                    if (visit.minute_duration__c != null) {
                        totalVisitMinutes += visit.minute_duration__c;
                    }
                }
                
                record.put('TotalVisits', String.valueOf(totalVisitMinutes) + ' min');
            }
            
            // =====================================================
            // HOLIDAY (Sunday)
            // =====================================================
            else if (dayOfWeek == 'Sunday') {
                
                record.put('Status', 'Holiday');
                record.put('TotalVisits', '0 min');
            }
            
            
            // LEAVE (UPDATED)
            // =====================================================
            else if (leaveMap.containsKey(currentDate)) {
                
                Leaves__c leave = leaveMap.get(currentDate);
                
                record.put('Id', leave.Id); // ✅ Added
                record.put('Status', 'Leave');
                record.put('TotalVisits', '0 min');
            }
            
            
            // =====================================================
            // ABSENT
            // =====================================================
            else {
                
                record.put('Status', 'Absent');
                record.put('TotalVisits', '0 min');
            }
            
            formattedAttendanceData.add(record);
        }
        
        dt.formattedUsersData = formattedAttendanceData;
        return dt;
    }
    @AuraEnabled
    public static userData repeatDays(string ids){
        // Query existing Child_Beat__c records for the given owner and created this month
        List<Child_Beat__c> chBt = [Select id, name,Order_Number__c from Child_Beat__c where OwnerId =: ids and CreatedDate = THIS_MONTH];
        
        // If no Child_Beat__c records are found, return
        if(chBt.isEmpty()){
            return null;
        }
        
        // List to hold the IDs of Child_Beat__c records
        List<Id> chId = new List<Id>();
        for(Child_Beat__c c: chBt){
            chId.add(c.Id);
        }
        
        // Query Junction_Beat__c records related to the Child_Beat__c records
        List<Junction_Beat__c> jn = [SELECT id, name, Account__c, Child_Beat__c,Order_Number__c FROM Junction_Beat__c WHERE Child_Beat__c IN :chId];
        
        // Map to store the original Child_Beat__c ID to the new cloned Child_Beat__c record
        Map<Id, Child_Beat__c> clonedChildBeatMap = new Map<Id, Child_Beat__c>();
        
        // Clone Child_Beat__c records
        for(Child_Beat__c cb : chBt){
            Child_Beat__c clonedCB = cb.clone(false, true, false, false);
            clonedCB.OwnerId = ids;
            clonedCB.isRepeat__c = true;
            clonedChildBeatMap.put(cb.Id, clonedCB);
        }
        
        // Insert the cloned Child_Beat__c records
        insert clonedChildBeatMap.values();
        
        // List to hold the new Junction_Beat__c records
        List<Junction_Beat__c> newJnList = new List<Junction_Beat__c>();
        
        // Clone Junction_Beat__c records
        for(Junction_Beat__c jb : jn){
            Junction_Beat__c clonedJB = jb.clone(false, true, false, false);
            
            // If the Junction_Beat__c has a lookup to Child_Beat__c, update it to the new cloned Child_Beat__c
            if(jb.Child_Beat__c != null && clonedChildBeatMap.containsKey(jb.Child_Beat__c)){
                clonedJB.Child_Beat__c = clonedChildBeatMap.get(jb.Child_Beat__c).Id;
            }
            
            // If the Junction_Beat__c has a lookup to Account, keep it the same
            if(jb.Account__c != null){
                clonedJB.Account__c = jb.Account__c;
                /*   clonedJB.OwnerId = ids; */
                clonedJB.isRepeat__c = true;
            }
            
            newJnList.add(clonedJB);
        }
        
        // Insert the cloned Junction_Beat__c records
        if(!newJnList.isEmpty()){
            insert newJnList;
        }
        userData dt = new userData();
        dt.JunctionList = [SELECT Id, Name, Account__c, Account__r.Name,
                           Child_beat__c, Child_beat__r.Name,
                           Visit_Date__c, Visit_Plan__c, Visit_Plan__r.Name ,Order_Number__c
                           FROM Junction_Beat__c
                           WHERE Visit_Date__c = THIS_MONTH and Child_beat__r.ownerId =:ids ORDER BY Order_Number__c ASC ];
        dt.jDbeatList = pjpViewBeatData(ids);
        dt.HolidayList = holidayBeatData(ids);
        return dt;
    }
    @AuraEnabled
    public static userData Incentive(String ids, Date fromDt, Date toDate) {
        userData dt = new userData();  // Correctly initializing userData
        
        // Fetch Target Plans (Limit 1 as we assume there's only one applicable plan per owner)
        List<Target_Plan__c> tarPlan = [SELECT Id, Name, Division__c, Incentive_Type__c
                                        FROM Target_Plan__c WHERE OwnerId = :ids LIMIT 1];
        
        System.debug('tarPlan: ' + tarPlan);
        
        // Fetch Targets within the given period range
        List<Target__c> tar = [SELECT Id, Name, Executive__c, Executive__r.Name,
                               Period__c, Period__r.Name
                               FROM Target__c
                               WHERE Executive__c = :ids
                               AND Period__r.Start_Date__c >= :fromDt
                               AND Period__r.Start_Date__c <= :toDate];
        
        System.debug('tar: ' + tar);
        System.debug('ids: ' + ids);
        
        // Map Period Id to Period Name
        Map<Id, AggregateData> periodMap = new Map<Id, AggregateData>();
        for (Target__c t : tar) {
            if (t.Period__c != null) {
                periodMap.put(t.Id, new AggregateData(t.Period__c, t.Period__r.Name));
            }
        }
        
        // Fetch Target Items for the retrieved Targets
        List<Id> tarIds = new List<Id>();
        for (Target__c t : tar) {
            tarIds.add(t.Id);
        }
        
        List<Target_Item__c> tarLine = [SELECT Id, Target__c, Actual_Value__c, Total_Actual__c,Self_Target__c,
                                        Amount__c, Team_s_Actual__c,Target_Value__c
                                        FROM Target_Item__c
                                        WHERE Target__c IN :tarIds];
        
        System.debug('tarLine: ' + tarLine);
        
        // Aggregate Data by Period Name
        for (Target_Item__c item : tarLine) {
                            /*  system.debug('item.Self_Target__c: '+item.Self_Target__c);
                Decimal targetValue = (item.Target_Value__c != null) ? item.Target_Value__c : 0;
                Decimal teamTargetValue = (item.Team_s_Target__c != null) ? item.Team_s_Target__c : 0;

                Decimal sub = targetValue - teamTargetValue;
                sub = Math.abs(sub).setScale(2, System.RoundingMode.HALF_UP);
                */
            AggregateData periodData = periodMap.get(item.Target__c);
            if (periodData != null) {
                periodData.targetType = tarPlan.isEmpty() ? null : tarPlan[0].Incentive_Type__c;
                periodData.totalTarget += (item.Self_Target__c != null) ? Math.abs(item.Self_Target__c) : 0;
                periodData.totalActual += (item.Total_Actual__c != null) ? item.Total_Actual__c : 0;
                periodData.sumIncentive += (item.Amount__c != null) ? item.Amount__c : 0;
            }
        }
        
        // Convert to List and assign to `agg`
        dt.agg = new List<AggregateData>(periodMap.values());
        
        return dt;
    }
    
    @AuraEnabled
    public static userData getMapLocationDta(string ids, date fromDate, date toDate) {
        userData dt = new userData();
        dt.NonPjpVisit = nonPjpVisit(ids,fromDate,toDate);
        dt.PjpVisit = PjpVisit(ids,fromDate,toDate);
        dt.Productive = Productive(ids,fromDate,toDate);
        dt.nonProductive = NonProductive(ids,fromDate,toDate);
        dt.newStores = [
            SELECT Id, Name, GeoLocation__Longitude__s, GeoLocation__Latitude__s
            FROM Account
            WHERE DISTANCE(GeoLocation__c, GEOLOCATION(0, 0), 'km') > 0
            AND OwnerId = :ids
            AND DAY_ONLY(CreatedDate) >= :fromDate
            AND DAY_ONLY(CreatedDate) <= :toDate
            AND Id NOT IN (SELECT Account1__c FROM Visit__c)
            ORDER BY CreatedDate ASC
        ];
        dt.officeLocation = [SELECT id,name ,Clock_In_Location__Latitude__s,Clock_In_Location__Longitude__s,Total_Working_Hours__c,
                             Distance_Travelled_Map__c
                             from Daily_Log__c where
                             ownerId=:ids
                             and DAY_ONLY(createdDate) >= :fromDate
                             and DAY_ONLY(createdDate) <= :toDate
                             Limit 1
                            ];
        List<Expense__c> ex= new  List<Expense__c>();/*[select id,name,Expense_start_day__c ,Total_Amount__c
                                                                            from Expense__c
                                                                            where ownerId=:ids
                                                                            and Expense_start_day__c >= :fromDate
                                                                            and Expense_start_day__c <= :toDate LIMIT 1];*/
        dt.exTotalAmt = 0.0;
        dt.workingHrs = '0 Hrs';
        dt.kmTravel = 0.0;
        if (!ex.isEmpty()) {
            // dt.exTotalAmt = ex[0].Total_Amount__c != null ? ex[0].Total_Amount__c.setScale(2) : 0.0;
        }
        if (!dt.officeLocation.isEmpty()) {
            dt.kmTravel = dt.officeLocation[0].Distance_Travelled_Map__c != null ? dt.officeLocation[0].Distance_Travelled_Map__c.setScale(2) : 0;
            dt.workingHrs = dt.officeLocation[0].Total_Working_Hours__c != null ? dt.officeLocation[0].Total_Working_Hours__c : '0 Hrs';
        }
        return dt;
    }
    
    @AuraEnabled
    public static List<Visit__c> nonPjpVisit(string ids, date fromDate, date toDate) {
        List<Visit__c> vis = new List<Visit__c>();
        //  List<Account> accVisits = new List<Account>();
        Date actualFromDate = (date) fromDate;
        List<Daily_Log__c> l = [SELECT id, name,Child_beat__c from Daily_Log__c where ownerid =:ids and DAY_ONLY(convertTimezone(Day_started_time__c)) = :actualFromDate];
        system.debug(ids +' llllllll: '+actualFromDate);
        
        if(l.isEmpty()){
            return null;
        }
        Daily_Log__c log = l[0];
        if(log.Child_beat__c == null){
            
            vis = [SELECT id, name,Child_beat__c,Account1__c,ClockIn_Latitude__c,Clockin_Longitude__c from Visit__c
                   where Daily_log__c = :log.id and Child_beat__c = null and Child_beat__c = null and status__c = 'In Progress'];
            system.debug(' llllllll: '+vis);
        }
        return vis;
    }
    
    @AuraEnabled
    public static List<Visit__c> PjpVisit(string ids, date fromDate, date toDate) {
        List<Visit__c> vis = new List<Visit__c>();
        //  List<Account> accVisits = new List<Account>();
        List<Daily_Log__c> l = [SELECT id, name,Child_beat__c from Daily_Log__c where ownerid =:ids and DAY_ONLY(convertTimezone(Day_started_time__c)) = :fromDate];
        if(l.isEmpty()){
            return null;
        }
        Daily_Log__c log = l[0];
        // if(log.Child_beat__c != null){
        system.debug('vis pjp '+vis);
        vis = [SELECT id, name,Child_beat__c,Account1__c,ClockIn_Latitude__c,Clockin_Longitude__c from Visit__c
               where Daily_log__c = :log.id and Child_beat__c != null and status__c = 'In Progress'];
        system.debug('vis pjp '+vis);
        // }
        return vis;
    }
    
    @AuraEnabled
    public static List<Visit__c> Productive(string ids, date fromDate, date toDate) {
        List<Visit__c> vis = new List<Visit__c>();
        List<Daily_Log__c> l = [SELECT id, name,Child_beat__c from Daily_Log__c where ownerid =:ids and DAY_ONLY(convertTimezone(Day_started_time__c)) = :fromDate];
        if(l.isEmpty()){
            return null;
        }
        Daily_Log__c log = l[0];
        // if(log.Child_beat__c != null){
        List<Visit__c>  Allvis = [SELECT id, name,Child_beat__c,Account1__c,ClockIn_Latitude__c,Clockin_Longitude__c from Visit__c
                                  where Daily_log__c = :log.id and Status__c = 'Completed'];
        Set<Id> visitIdsWithOrders = new Set<Id>();
        
        // Query orders linked to visits
        for (Order__c ord : [SELECT Visit__c FROM Order__c WHERE Visit__c IN :Allvis]) {
            visitIdsWithOrders.add(ord.Visit__c);
        }
        for (Visit__c v : Allvis) {
            if (visitIdsWithOrders.contains(v.Id)) {
                vis.add(v);
            }
        }
        system.debug('visPro '+vis);
        // }
        return vis;
    }
    
    public static List<Visit__c> NonProductive(string ids, date fromDate, date toDate) {
        List<Visit__c> vis = new List<Visit__c>();
        List<Daily_Log__c> l = [SELECT id, name,Child_beat__c from Daily_Log__c where ownerid =:ids and DAY_ONLY(convertTimezone(Day_started_time__c)) = :fromDate];
        if(l.isEmpty()){
            return null;
        }
        Daily_Log__c log = l[0];
        // if(log.Child_beat__c != null){
        List<Visit__c> Allvis = [SELECT Id, Name, Child_beat__c, Account1__c, ClockIn_Latitude__c, Clockin_Longitude__c
                                 FROM Visit__c
                                 WHERE Daily_log__c = :log.id and Status__c = 'Completed'];
        
        Set<Id> visitIdsWithOrders = new Set<Id>();
        
        // Query orders linked to visits
        for (Order__c ord : [SELECT Visit__c FROM Order__c WHERE Visit__c IN :Allvis]) {
            visitIdsWithOrders.add(ord.Visit__c);
        }
        
        // Filter visits that do NOT have an order
        List<Visit__c> visitsWithoutOrders = new List<Visit__c>();
        for (Visit__c v : Allvis) {
            if (!visitIdsWithOrders.contains(v.Id)) {
                visitsWithoutOrders.add(v);
            }
        }
        
        // Now, 'visitsWithoutOrders' contains only visits that do NOT have an order
        
        system.debug('visPro '+vis);
        // }
        return visitsWithoutOrders;
    }

    
    @AuraEnabled
    public static void shareAccountAccess(String recId, String objectName) {
        if (String.isBlank(recId) || String.isBlank(objectName)) { return; }
        
        String userId;
        
        //Resolve userId
        if (objectName == 'Employee') {
            Employee__c emp = [ SELECT User__c  FROM Employee__c  WHERE Id = :recId   LIMIT 1];
            userId = emp.User__c;
        } else if (objectName == 'User') { userId = recId; }
        
        if (String.isBlank(userId)) { return; }
        
        List<AccountShare> sharesToInsert = new List<AccountShare>();
        
        //Collect from Product Mapping
        for (Product_Mapping__c pm : [  SELECT Customer__c  FROM Product_Mapping__c  WHERE Exectuive__c = :userId AND Customer__c != null
        ]) {
            sharesToInsert.add(CustomSharingService.buildAccountShare(pm.Customer__c, userId));
        }
        
        //Collect from Employee-Customer Assignment
        for (Employee_Customer_Assignment__c emp : [ SELECT Customer__c FROM Employee_Customer_Assignment__c WHERE Executive__c = :userId AND Customer__c != null
        ]) {
            sharesToInsert.add(CustomSharingService.buildAccountShare(emp.Customer__c, userId));
        }
        
        //Perform sharing if needed
        if (!sharesToInsert.isEmpty()) {
            CustomSharingService.shareAccounts(sharesToInsert);
        }
    }
    
    @AuraEnabled
    public static List<OutletRow> getBeatVisitSummaries(String userId, Date startDate, Date endDate) {
        // Step 1: Get Visits
        List<Visit__c> visits = [
            SELECT Id, Visit_Date__c, Account1__c, Account1__r.Name,
            Child_Beat__c, Child_Beat__r.Name
            FROM Visit__c
            WHERE Visit_Date__c >= :startDate
            AND Visit_Date__c <= :endDate
            AND OwnerId = :userId
        ];
        
        // Build maps: Date → Visited Accounts, Date → Beats
        Map<Date, Set<Id>> dateToAccountMap = new Map<Date, Set<Id>>();
        Set<Id> allBeats = new Set<Id>();
        for (Visit__c v : visits) {
            if (!dateToAccountMap.containsKey(v.Visit_Date__c)) {
                dateToAccountMap.put(v.Visit_Date__c, new Set<Id>());
            }
            if (v.Account1__c != null) {
                dateToAccountMap.get(v.Visit_Date__c).add(v.Account1__c);
            }
            if (v.Child_Beat__c != null) {
                allBeats.add(v.Child_Beat__c);
            }
        }
        
        // Step 2: Query Beat Items once
        Map<Id, List<Junction_Beat__c>> beatToItemsMap = new Map<Id, List<Junction_Beat__c>>();
        if (!allBeats.isEmpty()) {
            for (Junction_Beat__c bi : [
                SELECT Id, Account__c, Account__r.Name,
                Account__r.Customer_Code__c, Account__r.Outlet_Id__c,
                Child_beat__c, Child_beat__r.Name, Child_beat__r.Beat_Id_Text__c,
                Child_beat__r.Primary_Customer_Name__c,
                Child_beat__r.Primary_Customer_Code__c
                FROM Junction_Beat__c
                WHERE Child_beat__c IN :allBeats
            ]) {
                if (!beatToItemsMap.containsKey(bi.Child_beat__c)) {
                    beatToItemsMap.put(bi.Child_beat__c, new List<Junction_Beat__c>());
                }
                beatToItemsMap.get(bi.Child_beat__c).add(bi);
            }
        }
        
        // Step 3: Flatten → Date → Beat Items
        Map<Date, List<Junction_Beat__c>> dateToBeatItemsMap = new Map<Date, List<Junction_Beat__c>>();
        for (Visit__c v : visits) {
            if (v.Child_Beat__c != null && beatToItemsMap.containsKey(v.Child_Beat__c)) {
                if (!dateToBeatItemsMap.containsKey(v.Visit_Date__c)) {
                    dateToBeatItemsMap.put(v.Visit_Date__c, new List<Junction_Beat__c>());
                }
                dateToBeatItemsMap.get(v.Visit_Date__c).addAll(beatToItemsMap.get(v.Child_Beat__c));
            }
        }
        // Step 4: Build only Not Worked Outlets (Unique by AccountId + Date)
        List<OutletRow> finalList = new List<OutletRow>();
        Set<String> uniqueKeys = new Set<String>(); // to avoid duplicates
        
        for (Date d : dateToBeatItemsMap.keySet()) {
            Set<Id> visitedAccs = dateToAccountMap.get(d);
            
            for (Junction_Beat__c bi : dateToBeatItemsMap.get(d)) {
                if (bi.Account__c == null) continue;
                
                Boolean visited = visitedAccs != null && visitedAccs.contains(bi.Account__c);
                
                if (!visited) { // Only not worked outlets
                    String uniqueKey = bi.Account__c + '-' + String.valueOf(d);
                    
                    if (!uniqueKeys.contains(uniqueKey)) {
                        uniqueKeys.add(uniqueKey);
                        
                        OutletRow row = new OutletRow();
                        row.workDate = d;
                        row.outletName = (bi.Account__r != null) ? bi.Account__r.Name : '';
                        row.customerCode = (bi.Account__r != null) ? bi.Account__r.Customer_Code__c : '';
                        row.primaryCustomerCode = (bi.Child_beat__r != null) ? bi.Child_beat__r.Primary_Customer_Code__c : '';
                        row.primaryCustomerName = (bi.Child_beat__r != null) ? bi.Child_beat__r.Primary_Customer_Name__c : '';
                        row.outletCode = (bi.Account__r != null) ? bi.Account__r.Outlet_Id__c : '';
                        row.beatCode = (bi.Child_beat__r != null) ? bi.Child_beat__r.Beat_Id_Text__c : '';
                        row.beatName = (bi.Child_beat__r != null) ? bi.Child_beat__r.Name : '';
                        
                        finalList.add(row);
                    }
                }
            }
        }
        
        return finalList;
    }
    
    // Wrapper for final response
    public class OutletRow {
        @AuraEnabled public Date workDate { get; set; }
        @AuraEnabled public String outletName { get; set; }
        @AuraEnabled public String customerCode { get; set; }
        @AuraEnabled public String primaryCustomerCode { get; set; }
        @AuraEnabled public String primaryCustomerName { get; set; }
        @AuraEnabled public String outletCode { get; set; }
        @AuraEnabled public String beatCode { get; set; }
        @AuraEnabled public String beatName { get; set; }
    }

    
     /*   @AuraEnabled
public static List<Map<String, String>> ExpenseData(Id userId){

List<AggregateResult> results = [
SELECT CALENDAR_MONTH(Expense_To_Date__c) month,
CALENDAR_YEAR(Expense_To_Date__c) year,
SUM(Total_Expense_Amount__c) totalGrandTotal
FROM Expense__c
WHERE Expense_To_Date__c = THIS_YEAR AND OwnerId =:userId
GROUP BY CALENDAR_MONTH(Expense_To_Date__c), CALENDAR_YEAR(Expense_To_Date__c)
ORDER BY CALENDAR_YEAR(Expense_To_Date__c) ASC, CALENDAR_MONTH(Expense_To_Date__c) ASC
];

Map<Integer, String> monthNames = new Map<Integer, String>{
1 => 'JAN', 2 => 'FEB', 3 => 'MAR', 4 => 'APR', 5 => 'MAY', 6 => 'JUN',
7 => 'JUL', 8 => 'AUG', 9 => 'SEP', 10 => 'OCT', 11 => 'NOV', 12 => 'DEC'
};
List<Map<String, String>> formattedUsersExp = new List<Map<String, String>>();
for (AggregateResult ar : results) {
Integer monthNum = (Integer) ar.get('month');
Integer yearNum = (Integer) ar.get('year');
Decimal total = (Decimal) ar.get('totalGrandTotal');

Map<String, String> dataMap = new Map<String, String>{
'monthName' => monthNames.get(monthNum) + ' - ' + String.valueOf(yearNum),
'totalGrandTotal' => String.valueOf(total)
};

formattedUsersExp.add(dataMap);
}

return formattedUsersExp;
}*/
    
    /*
public static List<DateGroup> calendarView(String ids) {
Map<String, DateGroup> dateToEventsMap = new Map<String, DateGroup>();



// Fetch Junction_Beat__c records
List<Junction_Beat__c> jnBt = [SELECT Id, Name, Visit_Date__c
FROM Junction_Beat__c
WHERE OwnerId = :ids AND CreatedDate = THIS_MONTH
ORDER BY Name ASC];
if (String.isBlank(ids)) {
return beatList;
}
if (jnBt.isEmpty()) {
return beatList;
}
List<Holiday__c> holidays = [SELECT Id, Name, Date__c, Region__c, Description__c
FROM Holiday__c
WHERE Date__c = THIS_MONTH AND OwnerId = :ids
LIMIT 500];
List<Account> accList = [SELECT Id, Name, Junction_Beat__c
FROM Account
WHERE Junction_Beat__c IN :jnIds];
for (Holiday__c h : holidays) {
CalendarEvent holidayEvent = new CalendarEvent();
holidayEvent.type = 'Holiday';
holidayEvent.id = h.Id;
holidayEvent.name = h.Name;
holidayEvent.visitDate = h.Date__c;
holidayEvent.color = '#f7caac'; // Holiday color
holidayEvent.description = h.Description__c;

// Store the holiday date in Set to track it
holidayDates.add(h.Date__c);

// Create a unique key for the DateGroup (only one holiday per date)
String key = String.valueOf(h.Date__c) + '-Holiday';

// Create a DateGroup if it doesn't exist
if (!dateToEventsMap.containsKey(key)) {
DateGroup holidayGroup = new DateGroup();
holidayGroup.dates = String.valueOf(h.Date__c);
holidayGroup.name = h.name;
holidayGroup.isHoliday = true;
holidayGroup.color = '#f7caac';
holidayGroup.BeatId = h.Id;
holidayGroup.commonId = h.Id;
holidayGroup.events = new List<CalendarEvent>();
dateToEventsMap.put(key, holidayGroup);
}
// Add the holiday event
dateToEventsMap.get(key).events.add(holidayEvent);
}

return dateToEventsMap;
}*/
    /*@AuraEnabled
public static List<DateGroup> calendarView(String ids) {
Map<String, DateGroup> dateToEventsMap = new Map<String, DateGroup>();
Set<Date> holidayDates = new Set<Date>(); // To track dates with holidays

// Fetch holidays first
List<Holiday__c> holidays = [SELECT Id, Name, Date__c, Region__c, Description__c
FROM Holiday__c
WHERE Date__c = THIS_MONTH AND OwnerId = :ids
LIMIT 500];

for (Holiday__c h : holidays) {
CalendarEvent holidayEvent = new CalendarEvent();
holidayEvent.type = 'Holiday';
holidayEvent.id = h.Id;
holidayEvent.name = h.Name;
holidayEvent.visitDate = h.Date__c;
holidayEvent.color = '#f7caac'; // Holiday color
holidayEvent.description = h.Description__c;

// Store the holiday date in Set to track it
holidayDates.add(h.Date__c);

// Create a unique key for the DateGroup (only one holiday per date)
String key = String.valueOf(h.Date__c) + '-Holiday';

// Create a DateGroup if it doesn't exist
if (!dateToEventsMap.containsKey(key)) {
DateGroup holidayGroup = new DateGroup();
holidayGroup.dates = String.valueOf(h.Date__c);
holidayGroup.name = h.name;
holidayGroup.isHoliday = true;
holidayGroup.color = '#f7caac';
holidayGroup.BeatId = h.Id;
holidayGroup.commonId = h.Id;
holidayGroup.events = new List<CalendarEvent>();
dateToEventsMap.put(key, holidayGroup);
}
// Add the holiday event
dateToEventsMap.get(key).events.add(holidayEvent);
}

// Fetch beats in one efficient query
List<Junction_Beat__c> beats = [SELECT Id, Name, Account__c, Account__r.Name, Visit_Date__c,
child_beat__c, child_beat__r.Name,Visit_Plan__c
FROM Junction_Beat__c
WHERE Visit_Date__c = THIS_MONTH
AND OwnerId = :ids
LIMIT 500];

// Process beats and group them by child_beat__r.Name under the same Visit_Date__c
for (Junction_Beat__c b : beats) {
// Skip adding beats if a holiday exists on this date
if (holidayDates.contains(b.Visit_Date__c)) {
continue; // Ignore this beat, as the holiday takes priority
}

// Create a unique key based on date and child beat name
String key = String.valueOf(b.Visit_Date__c) + '-' + b.child_beat__r.Name;

// Get or create a DateGroup entry for this date and child beat
if (!dateToEventsMap.containsKey(key)) {
DateGroup beatGroup = new DateGroup();
beatGroup.dates = String.valueOf(b.Visit_Date__c);
beatGroup.name = b.child_beat__r.Name;

beatGroup.color = '#ffffff';
beatGroup.JnId = b.id;
beatGroup.BeatId = b.Visit_Plan__c;
beatGroup.commonId = b.id;
beatGroup.chBeatId = b.Child_beat__c;
beatGroup.isHoliday = false;

beatGroup.events = new List<CalendarEvent>();
dateToEventsMap.put(key, beatGroup);
}

// Create a CalendarEvent entry for the beat
CalendarEvent beatEvent = new CalendarEvent();
beatEvent.type = 'Beat';
beatEvent.id = b.Id;
beatEvent.name = b.Name; // Beat name
beatEvent.accName = b.Account__r.Name;
beatEvent.accId = b.Account__c;
beatEvent.visitDate = b.Visit_Date__c;
beatEvent.color = '#ffffff'; // Default beat color

// Add the beat event to the correct DateGroup
dateToEventsMap.get(key).events.add(beatEvent);
}

// Convert map values to a list
return dateToEventsMap.values();
}
*/
    
}