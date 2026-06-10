import { LightningElement,track,api } from 'lwc';
import GET_ALL_DATA from '@salesforce/apex/EmployeeeController.getAllData';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FORM_FACTOR from '@salesforce/client/formFactor';
import DUPLICATOION_CHECK from '@salesforce/apex/EmployeeDuplicationChecker.duplicationCheck';
import SAVE_DATA from '@salesforce/apex/EmployeeeController.saveData';
import Id from '@salesforce/user/Id';
export default class NewEmployeeLwc extends LightningElement {
    @api recordId;
    userId = Id;
    title ='New Employee';
    customClass = 'slds-size_1-of-2';
    containerClass ='slds-modal__container';
    isDesktop = false;
    isPhone = false;
    isLoading = false;
    employee = {
        sObjectType: 'Employee__c',
        Id:null,
        Name :'',
        Role__c :'',
        Role_Id__c:'',
        Profile__c:'',
        Mail_Id__c:'',
        User_Name__c:'',
        Reporting_Manager__c:'',
        Reporting_Manager_Name__c:'',
        Aadhar_Number__c:'',
        Primary_Phone_Number__c:'',
        User_Type__c:'',
        Replaced_For__c:'',
        Replaced_For_Name__c:'',
        Payroll__c:'Yes',
        Payroll_Type__c:'',
        Employee_Code__c:'',
        Vendor_Code__c:'',
        Band__c:'',
        Shift_Time__c:'',
        Headquarter__c:'',
        Relieving_date__c:'',
        Designation__c:'',
        District_In_charge__c:false,
        Sales_Channel__c:'',
        Region__c:'',
        Working_District__c:'',
        Territory__c:'',
        Territory_Name__c:'',

        ASM_TSM__c:'',
        RSM__c:'',
        Employee_Approver_3_HR__c:'',
        Primary_Customer_Approver_1__c:'',
        Primary_Customer_Approver_2__c:'',
        Primary_Customer_Approver_3_CD__c:'',
        Secondary_Customer_Approver_1__c:'',
        Secondary_Customer_Approver_2__c:'',
        PJP_Approver_1__c:'',
        PJP_Approver_2__c:'',
        Expense_Approver_1__c:'',
        Expense_Approver_2_Finance_Department__c:'',

        Secondary_Customer_Approver_1_Name: '',
        Secondary_Customer_Approver_2_Name: '',
        ASM_TSM_Name: '',
        RSM_Name: '',
        Employee_Approver_3_HR_Name: '',
        Primary_Customer_Approver_1_Name: '',
        Primary_Customer_Approver_2_Name: '',
        Primary_Customer_Approver_3_CD_Name: '',
        PJP_Approver_1_Name: '',
        PJP_Approver_2_Name: '',
        Expense_Approver_1_Name: '',

        Leave_Approver_L1__c : '',
        Leave_Approver_1_Name: '',
        Leave_HR__c : '',
        Leave_HR_Name: '',

        Expense_Approver_2_Finance_Department_Name: '',
        Category__c:'',

        Basic_Pay__c:'',
        Gross_Salary__c:'',
        Minimum_Order_value__c:'',
        PAN__c:'',
        Secondary_Phone_Number__c:'',
        DOB__c:'',
        DOJ__c:'',
        State__c:'',
        District__c:'',
        Pincode__c:'',
        Street__c:'',
        IsDataUpload__c:false,

        Employee_Remarks__c:'',
        Expense_Back_Day_Entry_Limit__c:null,
        Expense_Start_Date__c:'',
        Expense_End_Date__c:''
    };

    @track userList = [];
    @track payrollList = [];
    @track profileOptions = [];

    mandateReplacedFor= false;
    mandateContractType = false;
    showEditFieds = false;

    //Role
    @track roleList = [];
    @track searchedRoleList = [];   
    @track selectedRoleName = '';
    isShowRoles = false;

    //territory
    territoryList = [];
    isShowSearchedTerritory =false;
    searchedTerritory = [];

    //Repoting Manager
    isShowReportingManager = false;
    searchedReportingMagers = [];
    hirachyNumberMap = {};
    payrollMap = {};

    //Hirachy Employees
    selectedProfileHirachyNumber = 0;

    //Replaced For
    replacedForEmployees = [];
    isshowReplaceFor = false;
    searchedReplacedForEmployees = [];

    //ReporingManager
    isReptingManagerDisabled = true;
    
    //Category Dependent Picklist
    @track categoryOptions = [];
    @track categoryMapping = [];
    isShowDistctInchage = false;

    //Primary PBIS Policy options, filtered by the employee's Sales Channel(s)
    @track pbisPolicyOptions = [];
    pbisPolicyList = [];

    //readonly
    isRoleReadOnly = false;
    isReportingManagerReadonly = false;
    isReplaceForReadOnly = false;

    //employee Access
    metadataRecordsList = [];
    isTerritoryReadOnly = false;

    isShowRegion = false;
    isShowArea = false;
    isShowDistrict = false;
    isShowTerritory = false;

    //DisabledFields
    isRegionDisabled = false;
    isAreaDisabled = false;
    isDistrictDisabled = false;
    isTerritoryDisabled = false;  

    isRegionRequired = false;
    isAreaRequired = false;
    isTerritoryRequired = false;

    //Sales Channel Related values
    regionOptions = [];
    areaOptions = [];
    areaRegionMap = {};
    currentUser = {};
    isShowAllSections = true;
    message = '';
    editaccess = false;
    isrequied = false;
    isAdminProfile = false;
    reportingmanagerRequired = true;
    isCloningCompleted = false;
    iscurrentUserAdmin = false;
    aadharNumberMandate = true;
    disableEmployeeCode = true;
    isEmployeeCodeMandate = false;

    //On loading this method will be called
    connectedCallback() {
        
        this.isLoading=true;
        this.isDesktop = FORM_FACTOR === 'Large'? true : false;
        this.isPhone = FORM_FACTOR === 'Small'? true : false;
        if (FORM_FACTOR === 'Medium') this.isDesktop = true;
        this.isLoading = true; 
        this.containerClass = this.isDesktop ? 'slds-modal__container' : '';
        this.customClass = this.isDesktop ? 'slds-size_1-of-2' : 'slds-size_1-of-1';
        if(this.recordId)
        {
            this.title ='Edit Employee';
            this.isReptingManagerDisabled = false;
            this.showEditFieds = true;
        }
        this.disablePullToRefresh();
         this.getAllData();
       
    }
    getAllData(){
        if (!navigator.onLine) {
            this.isLoading = false;
            this.showToast('Error', 'No internet connection. Please check your network and try again.', 'error');
            return;
        }
        this.isLoading = true;
        GET_ALL_DATA({recordId:this.recordId
        })
        .then(result => {
            this.userList = result.userList;
            this.roleList = result.roleList;
           /* this.payrollList = result.payrollList;
            if( this.payrollList.length === 1 && this.payrollList[0].value == 'No')
            {
                this.mandateContractType = true;
            }*/
            this.currentUser = result.currentUser;
            this.iscurrentUserAdmin = result.currentUser.isAdmin__c;
            if(this.iscurrentUserAdmin)
            {
                this.aadharNumberMandate = false;
                this.disableEmployeeCode = false;
                this.isEmployeeCodeMandate = true;
            }
            this.profileOptions = this.getPicklistValueFromList(result.profileList);
            this.hirachyNumberMap = result.hirachyNumberMap;
            this.payrollMap = result.payrollMap;
            this.replacedForEmployees = result.employeesList;
            this.territoryList =  result.territoryList;
            this.employee.Payroll__c = this.payrollList.length === 1 ? this.payrollList[0].value : '';
            this.categoryMapping = result.catoryToSalsChannelList.map(item => ({
                category: item.Category__c,
                salesChannels: item.Sales_Channel__c.split(';').map(s => s)
            }))

            this.pbisPolicyList = (result.pbisPolicyList || []).map(item => ({
                id: item.Id,
                name: item.Name,
                salesChannels: item.Sales_Channels__c ? item.Sales_Channels__c.split(';') : []
            }));
            this.updateAvailablePbisPolicies();

            this.metadataRecordsList = result.metadataRecordsList;
            //console.log('recordId -->', this.recordId);
            //console.log('employee -->', result?.employee);
            
            if (this.recordId && result?.employee) {
                this.message = result.approvalMessage;
                this.editaccess = result.editEmployee;
                if(!this.editaccess )
                {
                    this.isLoading = false;
                    return; 
                }


                const emp = result.employee;
        
                const newValues = {
                    sObjectType: 'Employee__c',
                    Id: emp.Id,
                    Name: emp.Name,
                    Role__c: emp.Role_Name__c,
                    Role_Id__c: emp.Role_Id__c,
                    Payroll__c: emp.Payroll__c,
                    Profile__c: emp.Profile__c,
                    Mail_Id__c: emp.Mail_Id__c,
                    User_Name__c: emp.User_Name__c,
                    Aadhar_Number__c: emp.Aadhar_Number__c,
                    Primary_Phone_Number__c: emp.Primary_Phone_Number__c,
                    Secondary_Phone_Number__c: emp.Secondary_Phone_Number__c,
                    PAN__c: emp.PAN__c,
                    DOB__c: emp.DOB__c,
                    DOJ__c: emp.DOJ__c,
                    User_Type__c: emp.User_Type__c,
                    Reporting_Manager__c: emp.Reporting_Manager__c,
                    Reporting_Manager_Name__c: emp.Reporting_Manager__r?.Name || '',
                    Replaced_For__c: emp.Replaced_For__c,
                    Replaced_For_Name__c: emp.Replaced_For__r?.Name || '',
                    Payroll_Type__c: emp.Payroll_Type__c,
                    Employee_Code__c: emp.Employee_Code__c,
                    Vendor_Code__c: emp.Vendor_Code__c,
                    Band__c: emp.Band__c,
                    Shift_Time__c: emp.Shift_Time__c,
                    Headquarter__c: emp.Headquarter__c,
                    Relieving_date__c: emp.Relieving_date__c,
                    Designation__c: emp.Designation__c,
                    District_In_charge__c: emp.District_In_charge__c,
                    Sales_Channel__c: emp.Sales_Channel__c,
                    Region__c: emp.Region__c,
                    Working_District__c: emp.Working_District__c,
                    Territory__c: emp.Territory__c,
                    Territory_Name__c: emp.Territory__r?.Name || '',
                    Area__c: emp.Area__c,
                    Category__c: emp.Category__c,
                    Contract_Type__c :emp.Contract_Type__c,

                    ASM_TSM__c: emp.ASM_TSM__c || '',
                    RSM__c: emp.RSM__c || '',
                    Employee_Approver_3_HR__c: emp.Employee_Approver_3_HR__c || '',
                    Primary_Customer_Approver_1__c: emp.Primary_Customer_Approver_1__c || '',
                    Primary_Customer_Approver_2__c: emp.Primary_Customer_Approver_2__c || '',
                    Primary_Customer_Approver_3_CD__c: emp.Primary_Customer_Approver_3_CD__c || '',
                    Secondary_Customer_Approver_1__c: emp.Secondary_Customer_Approver_1__c || '',
                    Secondary_Customer_Approver_2__c: emp.Secondary_Customer_Approver_2__c || '',
                    PJP_Approver_1__c: emp.PJP_Approver_1__c || '',
                    PJP_Approver_2__c: emp.PJP_Approver_2__c || '',
                    Expense_Approver_1__c: emp.Expense_Approver_1__c || '',
                    Expense_Approver_2_Finance_Department__c: emp.Expense_Approver_2_Finance_Department__c || '',

                    Secondary_Customer_Approver_1_Name: emp.Secondary_Customer_Approver_1__r?.Name || '',
                    Secondary_Customer_Approver_2_Name: emp.Secondary_Customer_Approver_2__r?.Name || '',
                    ASM_TSM_Name: emp.ASM_TSM__r?.Name || '',
                    RSM_Name: emp.RSM__r?.Name || '',
                    Employee_Approver_3_HR_Name: emp.Employee_Approver_3_HR__r?.Name || '',
                    Primary_Customer_Approver_1_Name: emp.Primary_Customer_Approver_1__r?.Name || '',
                    Primary_Customer_Approver_2_Name: emp.Primary_Customer_Approver_2__r?.Name || '',
                    Primary_Customer_Approver_3_CD_Name: emp.Primary_Customer_Approver_3_CD__r?.Name || '',
                    PJP_Approver_1_Name: emp.PJP_Approver_1__r?.Name || '',
                    PJP_Approver_2_Name: emp.PJP_Approver_2__r?.Name || '',
                    Expense_Approver_1_Name: emp.Expense_Approver_1__r?.Name || '',
                    Expense_Approver_2_Finance_Department_Name: emp.Expense_Approver_2_Finance_Department__r?.Name || '',

                    Leave_Approver_L1__c: emp.Leave_Approver_L1__c || '',
                    Leave_Approver_1_Name: emp.Leave_Approver_L1__r?.Name || '',

                    Leave_HR__c: emp.Leave_HR__c || '',
                    Leave_HR_Name: emp.Leave_HR__r?.Name || '',

                    Basic_Pay__c: emp.Basic_Pay__c,
                    Gross_Salary__c: emp.Gross_Salary__c,
                    Minimum_Order_value__c: emp.Minimum_Order_value__c,
                    State__c: emp.State__c,
                    District__c: emp.District__c,
                    Pincode__c: emp.Pincode__c,
                    Street__c: emp.Street__c,
                    IsDataUpload__c:false,

                    Employee_Remarks__c: emp.Employee_Remarks__c,
                    Expense_Back_Day_Entry_Limit__c: emp.Expense_Back_Day_Entry_Limit__c,
                    Expense_Start_Date__c: emp.Expense_Start_Date__c,
                    Expense_End_Date__c: emp.Expense_End_Date__c,
                    Alternate_Sales_Channel__c : emp.Alternate_Sales_Channel__c,
                    PBIS_Policy__c: emp.PBIS_Policy__c
                };
                this.employee = { ...this.employee, ...newValues };

            
                this.isCloningCompleted =  emp.Cloning_is_Completed__c;
                this.selectedProfileHirachyNumber = emp.Heirarchial_Number__c;
                this.isShowAllSections = (emp.Profile__c == 'SSA' || emp.Profile__c == 'DSM') ? false : true ;
                this.isAdminProfile = (emp.Profile__c == 'System Administrator') ? true : false ;
                this.reportingmanagerRequired =  !this.isAdminProfile;
                this.isRoleReadOnly = !!emp.Role__c;
                this.reportingManagerName = emp.Reporting_Manager__r?.Name || '';
                this.reprortingManagerId = emp.Reporting_Manager__c;
                this.isReportingManagerReadonly = !!emp.Reporting_Manager__c;
                this.isReplaceForReadOnly = !!emp.Replaced_For__c;
                this.isShowDistctInchage = emp.Profile__c === 'Sr. TSE';
                this.mandateContractType = emp.Payroll__c === 'No';
                this.mandateReplacedFor = emp.User_Type__c === 'Replacement';
                this.setpayrollValues(emp.Profile__c);
                this.updateAvailableCategories();
                this.updateAvailablePbisPolicies();
                this.getRelatedAreasRegions();
                this.updateProfileBasedValues(emp.Profile__c,'UserEdit');
            
              
            }
            else
            {
                this.editaccess = true;
            }
           
           
            this.isLoading = false;
        })
        .catch(error => {
            console.error(error);
            this.isLoading = false;
        });
    }  

    //Handle Profile Change
    handleProfileChange(event)
    {
        const fieldValue  = event.detail.value;
        this.setpayrollValues(fieldValue);
        this.updateProfileBasedValues(fieldValue,'ProfileChange');
      
    }

    setpayrollValues(fieldValue)
    {
        const payrollLabel = this.payrollMap?.[fieldValue] || '';
        this.payrollList = [];
        if (payrollLabel) {
            this.payrollList.push({
                label: payrollLabel,
                value: payrollLabel
            });
        }
        this.employee.Payroll__c = payrollLabel;
        if( this.employee.Payroll__c == 'No')
        {
            this.mandateContractType = true;
        }
        else
        {
            this.mandateContractType = false;
        }
    }
    updateProfileBasedValues(fieldValue,operation)
    {
        if(operation == 'ProfileChange')
        {
            this.resetFields();
            this.employee.Reporting_Manager__c  = '';
            this.employee.Reporting_Manager_Name__c = ''; 
        }
        
        this.employee.Profile__c = fieldValue;
        this.isReptingManagerDisabled = false;
        this.selectedProfileHirachyNumber = this.hirachyNumberMap[fieldValue];
        this.isShowDistctInchage = fieldValue == 'Sr. TSE' ? true: false;
        this.isShowReportingManager = false;
        this.searchedReportingMagers = [];
        this.isReportingManagerReadonly = false;
        this.isTerritoryReadOnly = false;
        this.isAdminProfile = (fieldValue== 'System Administrator' ) ? true : false ;
        this.reportingmanagerRequired =  !this.isAdminProfile;
        if(fieldValue == 'RSM' || fieldValue == 'Sr. RSM' || fieldValue == 'Deputy RSM')
        {
            this.isShowRegion = true;
            this.isRegionRequired = true;
        }
        else if(fieldValue == 'ASM' || fieldValue == 'Sr. ASM' || fieldValue == 'Deputy ASM')
        {
            this.isShowRegion = true;
            this.isShowArea = true;

            this.isAreaDisabled = false;
            this.isRegionDisabled = true;
            this.isAreaRequired = true;
        }
        else if(fieldValue == 'TSM' || fieldValue == 'Sr. TSM' || fieldValue == 'Deputy TSM' ||
            fieldValue == 'Sr. TSE' || fieldValue == 'TSE' || fieldValue == 'Jr. TSE' || 
            fieldValue == 'ISR' ||  fieldValue == 'SR')
        {
            this.isShowRegion = true;
            this.isShowArea = true;
            this.isShowDistrict = true;
            this.isShowTerritory = true;

            this.isTerritoryDisabled = false;  
            this.isAreaDisabled = true;
            this.isRegionDisabled = true;
            this.isDistrictDisabled = true;

            this.isTerritoryRequired = true;
        }
        else if(fieldValue == 'SSA' || fieldValue == 'DSM')
        {
            this.isShowRegion = true;
            this.isShowArea = true;
            this.isShowDistrict = true;

            this.isAreaDisabled = true;
            this.isRegionDisabled = true;
            this.isDistrictDisabled = true;

           
            this.isShowAllSections = false;

            
            if(operation == 'ProfileChange')
            {
                this.autoMapfields();
                this.updateAvailableCategories();
                this.getRelatedAreasRegions();
            }
        }
       
    }
    autoMapfields() {
        const { 
            Sales_Channel__c, Region__c, Area__c, 
            Working_District__c, Territory__c, 
            Territory_Name__c, Id, Name 
        } = this.currentUser;

        Object.assign(this.employee, {
            Sales_Channel__c,
            Region__c,
            Area__c,
            Working_District__c,
            Territory__c,
            Territory_Name__c,
            Reporting_Manager__c: Id,
            Reporting_Manager_Name__c: Name
        });
       

    }

   

    //Role Search
    handleRoleSearch(event){
        let searchValueName = event.target.value;
        if(searchValueName){
            let objData = this.roleList;
            let searchedData = [];
            for (let i = 0; i < objData.length; i++) {
                const objName = objData[i];
                if ((objName.Name && objName.Name.toLowerCase().indexOf(searchValueName.toLowerCase()) !== -1)) {
                    searchedData.push(objName);
                }
            }
            this.isShowRoles = searchedData != 0 ? true : false;
            this.searchedRoleList = searchedData;
        }
        else
        {
            this.isShowRoles = false;
            this.employee.Role__c = '';
            this.employee.Role_Id__c = '';
            this.isRoleReadOnly = false;
        }

    }
    selectRole(event)
    {
        this.employee.Role__c = event.currentTarget.dataset.name;
        this.employee.Role_Id__c  = event.currentTarget.dataset.id;
        this.isShowRoles = false;
        this.isRoleReadOnly = true;
    }
    
    // Reporting Manager
    handleReportingManagerSearch(event) {
        let searchValueName = event.target.value;
        if (searchValueName) {
            let objData = this.userList;
            let searchedData = [];

            for (let i = 0; i < objData.length; i++) {
                const obj = objData[i];
                const nameMatch = obj.Name && obj.Name.toLowerCase().includes(searchValueName.toLowerCase());
                const codeMatch = obj.Employee_Code__c && obj.Employee_Code__c.toLowerCase().includes(searchValueName.toLowerCase()) || false;
            
                // Convert code to number before comparing
                const empCodeNumber = Number(obj.Heirarchial_Number__c);
                const selectedHierarchy = Number(this.selectedProfileHirachyNumber);

                if ((nameMatch || codeMatch) && !isNaN(empCodeNumber) && empCodeNumber >= selectedHierarchy) {
                    searchedData.push(obj);
                }
            }

            this.isShowReportingManager = searchedData.length > 0;
            this.searchedReportingMagers = searchedData;
        } else {
            this.isShowReportingManager = false;
            this.searchedReportingMagers = [];
            this.isReportingManagerReadonly = false;
            this.employee.Reporting_Manager__c = '';
            this.employee.Reporting_Manager_Name__c = ''; 
            const profile = this.employee.Profile__c;
            if (profile === 'SSA' || profile === 'DSM') 
            {
                this.employee.Sales_Channel__c = ''; 
                this.resetTerritoryFields();
            }
          
        }
    }
    selectReprotingManager(event) {
        const index = event.currentTarget.dataset.index;
        const selectedRecord = this.searchedReportingMagers[index]; 
        this.employee.Reporting_Manager_Name__c = selectedRecord.Name;
        this.employee.Reporting_Manager__c  = selectedRecord.Id;
        const profile = this.employee.Profile__c;
        if (profile === 'SSA' || profile === 'DSM') {
            this.employee.Sales_Channel__c = selectedRecord.Sales_Channel__c;
            this.employee.Region__c = selectedRecord.Region__c;
            this.employee.Area__c = selectedRecord.Area__c;
            this.employee.Working_District__c = selectedRecord.Working_District__c;
            this.employee.Territory__c = selectedRecord.Territory__c;
            this.employee.Territory_Name__c = selectedRecord.Territory_Name__c;
            this.updateAvailableCategories();
            this.getRelatedAreasRegions(); 
        }
        this.isShowReportingManager = false;
        this.isReportingManagerReadonly = true;
    }
    
    // Replaced For
    handleReplacedForSearch(event) {
        let searchValueName = event.target.value;
        if (searchValueName) {
            let objData = this.replacedForEmployees;
            let searchedData = [];
       

            for (let i = 0; i < objData.length; i++) {
                const obj = objData[i];
                const nameMatch = obj.Name && obj.Name.toLowerCase().includes(searchValueName.toLowerCase());
                const codeMatch = obj.Employee_Code__c && obj.Employee_Code__c.toLowerCase().includes(searchValueName.toLowerCase());
                 // Only apply manager filter if employee.Reporting_Manager__c exists
                const managerMatch = obj.Reporting_Manager__c === this.employee.Reporting_Manager__c;
                if ((nameMatch || codeMatch) && managerMatch) {
                    searchedData.push(obj);
                }
            }

            this.isshowReplaceFor = searchedData.length > 0;
            this.searchedReplacedForEmployees = searchedData;
        } else {
            this.isshowReplaceFor = false;
            this.employee.Replaced_For__c = '';
            this.employee.Replaced_For_Name__c = '';
            this.searchedReplacedForEmployees = [];
            this.isReportingManagerReadonly = false;
            this.isReplaceForReadOnly = false;
        }
    }
    selectReplacedFor(event)
    {
        const selectedId = event.currentTarget.dataset.id;
        const selected = this.searchedReplacedForEmployees.find(emp => emp.Id === selectedId);
        Object.assign(this.employee, {
            Replaced_For__c: selected.Id,
            Replaced_For_Name__c: selected.Name,
            Payroll__c: selected.Payroll__c,
            Payroll_Type__c: selected.Payroll_Type__c,
            Contract_Type__c: selected.Contract_Type__c,
            Band__c:selected.Band__c,
            Shift_Time__c: selected.Shift_Time__c,
            Headquarter__c: selected.Headquarter__c,
            Designation__c: selected.Designation__c,
            District_In_charge__c: selected.District_In_charge__c,
            Sales_Channel__c: selected.Sales_Channel__c,
            Category__c: selected.Category__c,
            Region__c: selected.Region__c,
            Area__c: selected.Area__c,
            Territory_Name__c: selected.Territory__r?.Name || '',
            Territory__c: selected.Territory__c,

            Secondary_Customer_Approver_1__c: selected.Secondary_Customer_Approver_1__c,
            Secondary_Customer_Approver_2__c: selected.Secondary_Customer_Approver_2__c,
            Primary_Customer_Approver_1__c: selected.Primary_Customer_Approver_1__c,
            Primary_Customer_Approver_2__c: selected.Primary_Customer_Approver_2__c,
            Primary_Customer_Approver_3_CD__c: selected.Primary_Customer_Approver_3_CD__c,
            ASM_TSM__c: selected.ASM_TSM__c,
            RSM__c: selected.RSM__c,
            Employee_Approver_3_HR__c: selected.Employee_Approver_3_HR__c,
            PJP_Approver_1__c: selected.PJP_Approver_1__c,
            Expense_Approver_1__c: selected.Expense_Approver_1__c,
            Expense_Approver_2_Finance_Department__c : selected.Expense_Approver_2_Finance_Department__c,

            Secondary_Customer_Approver_1_Name: selected.Secondary_Customer_Approver_1__r?.Name || '',
            Secondary_Customer_Approver_2_Name: selected.Secondary_Customer_Approver_2__r?.Name || '',
            ASM_TSM_Name: selected.ASM_TSM__r?.Name || '',
            RSM_Name: selected.RSM__r?.Name || '',
            Employee_Approver_3_HR_Name: selected.Employee_Approver_3_HR__r?.Name || '',
            Primary_Customer_Approver_1_Name: selected.Primary_Customer_Approver_1__r?.Name || '',
            Primary_Customer_Approver_2_Name: selected.Primary_Customer_Approver_2__r?.Name || '',
            Primary_Customer_Approver_3_CD_Name: selected.Primary_Customer_Approver_3_CD__r?.Name || '',
            PJP_Approver_1_Name: selected.PJP_Approver_1__r?.Name || '',
            Expense_Approver_1_Name: selected.Expense_Approver_1__r?.Name || '',
            Expense_Approver_2_Finance_Department_Name: selected.Expense_Approver_2_Finance_Department__r?.Name || '',

            Minimum_Order_value__c : selected.Minimum_Order_value__c,
            Basic_Pay__c : selected.Basic_Pay__c,
            Gross_Salary__c : selected.Gross_Salary__c
        });

        this.isshowReplaceFor = false;
        this.searchedReplacedForEmployees = [];
        this.isReportingManagerReadonly = true;

        this.updateAvailableCategories();
        this.getRelatedAreasRegions();
    }

    //Territory
    handleTerritorySearch(event) {
        let searchValueName = event.target.value;
        if (searchValueName) {
            let objData = this.territoryList;
            let searchedData = [];

            for (let i = 0; i < objData.length; i++) {
                const obj = objData[i];

                const nameMatch = obj.Name && obj.Name.toLowerCase().includes(searchValueName.toLowerCase());
                //  obj.Sales_Channel__c is a single picklist value
                let channelMatch = false;
                if (this.employee.Sales_Channel__c && this.employee.Sales_Channel__c.length > 0) {
                    channelMatch = this.employee.Sales_Channel__c.includes(obj.Sales_Channel__c);
                }

                if (nameMatch && channelMatch) {
                    searchedData.push(obj);
                }
            }

            this.isShowSearchedTerritory = searchedData.length > 0;
            this.searchedTerritory = searchedData;
        } else {
            this.isShowSearchedTerritory = false;
            this.searchedTerritory = [];
            this.isTerritoryReadOnly = false;
            this.resetTerritoryFields();
        }
    }
    selectTerritory(event)
    {
        const index = event.currentTarget.dataset.index;
        const selectedRecord = this.searchedTerritory[index]; 
        this.employee.Working_District__c = selectedRecord.District__c;
        this.employee.Region__c = selectedRecord.Region__c;
        this.employee.Area__c  = selectedRecord.Area__c;
        this.employee.Territory_Name__c = selectedRecord.Name;  
        this.employee.Territory__c = selectedRecord.Id; 
        this.isShowSearchedTerritory = false;
        this.searchedTerritory = [];
        this.isTerritoryReadOnly = true;
    }

    //Handle Input change
    handleInputChangeChange(event) {
        const fieldName = event.target.fieldName;
        const fieldValue  = event.detail.value;
        console.log('fieldValue'+JSON.stringify(fieldValue));
        console.log('fieldName'+fieldName);

        // Dynamically update the field in employee Data
        this.employee = { ...this.employee, [fieldName]: fieldValue };
        if(fieldName =='User_Type__c')
        {
            if(fieldValue == 'Replacement')
            {
                this.mandateReplacedFor= true;
            }
            else
            {
                this.mandateReplacedFor = false;
                //this.resetmappings();
            }
           
        }
    
        else if(fieldName =='Mail_Id__c' && !this.recordId)
        {
            this.employee.User_Name__c = fieldValue;
        }
        else if(fieldName =='Sales_Channel__c')
        {
            this.updateAvailableCategories();
            this.updateAvailablePbisPolicies();
            this.getRelatedAreasRegions();
        }
        else if(fieldName =='Alternate_Sales_Channel__c')
        {
            this.updateAvailablePbisPolicies();
        }
    }

    // Primary PBIS Policy options are restricted to policies whose Sales Channels
    // intersect the employee's selected Sales Channel and Alternate Sales Channel
    // (both are multi-select picklists stored as ';'-separated values).
    updateAvailablePbisPolicies() {
        const channels = [];
        if (this.employee.Sales_Channel__c) {
            channels.push(...this.employee.Sales_Channel__c.split(';'));
        }
        if (this.employee.Alternate_Sales_Channel__c) {
            channels.push(...this.employee.Alternate_Sales_Channel__c.split(';'));
        }
        const employeeChannels = new Set(channels.filter(c => c));

        let options = [];
        if (employeeChannels.size > 0) {
            options = this.pbisPolicyList
                .filter(policy => policy.salesChannels.some(sc => employeeChannels.has(sc)))
                .map(policy => ({ label: policy.name, value: policy.id }));
        }
        options.unshift({ label: '--None--', value: '' });
        this.pbisPolicyOptions = options;

        // Clear the selection if it is no longer one of the available policies.
        const validValues = new Set(options.map(opt => opt.value));
        if (!validValues.has(this.employee.PBIS_Policy__c)) {
            this.employee = { ...this.employee, PBIS_Policy__c: '' };
        }
    }

    payrollOptions() {
        return [
            { label: '--None--', value: '' },
            { label: this.payrollLabel || '', value: this.selectedPayroll || '' }
        ];
    }
    resetmappings()
    {
        // If User_Type__c is set to 'New' or empty, clear the replacement fields
        this.employee = {
            ...this.employee,
            Replaced_For__c: '',
            Replaced_For_Name__c: '',
            Payroll__c: '',
            Payroll_Type__c: '',
            Contract_Type__c: '',
            Band__c: '',
            Shift_Time__c: '',
            Headquarter__c: '',
            Designation__c: '',
            District_In_charge__c: false,
            Sales_Channel__c: '',
            Category__c: '',
            Region__c: '',
            Area__c: '',
            Territory_Name__c: '',
            Territory__c: '',

            Secondary_Customer_Approver_1__c: '',
            Secondary_Customer_Approver_2__c: '',
            Primary_Customer_Approver_1__c: '',
            Primary_Customer_Approver_2__c: '',
            Primary_Customer_Approver_3_CD__c: '',
            ASM_TSM__c: '',
            RSM__c:'',
            Employee_Approver_3_HR__c: '',
            PJP_Approver_1__c: '',
            Expense_Approver_1__c: '',
            Expense_Approver_2_Finance_Department__c:'',

            Secondary_Customer_Approver_1_Name: '',
            Secondary_Customer_Approver_2_Name: '',
            ASM_TSM_Name: '',
            RSM_Name: '',
            Employee_Approver_3_HR_Name: '',
            Primary_Customer_Approver_1_Name: '',
            Primary_Customer_Approver_2_Name: '',
            Primary_Customer_Approver_3_CD_Name: '',
            PJP_Approver_1_Name: '',
            Expense_Approver_1_Name: '',
            Expense_Approver_2_Finance_Department_Name: '',

            Minimum_Order_value__c: '',
            Basic_Pay__c: '',
            Gross_Salary__c: ''
        };
    }

    // Get Product categories related
    updateAvailableCategories() {
        const matchedCategories = new Set();

        this.categoryMapping.forEach(item => {
            const matched = item.salesChannels.some(sc =>
                this.employee.Sales_Channel__c.includes(sc)
            );
            if (matched) {
                matchedCategories.add(item.category);
            }
        });

        // Convert to picklist options
        let options = Array.from(matchedCategories).map(cat => ({
            label: cat,
            value: cat
        }));

        // Add default "Select Category" at the beginning
        options.unshift({ label: '--None--', value: '' });

        this.categoryOptions = options;

        // If previous selection is invalid, clear it
        if (!matchedCategories.has(this.employee.Category__c)) {
            this.employee.Category__c = '';
        }

        // Auto-select if only one actual category (excluding default option)
        const actualCategoryOptions = options.filter(opt => opt.value);
        if (actualCategoryOptions.length === 1) {
            this.employee.Category__c = actualCategoryOptions[0].value;
        }
    }

    //get Related Areas Regions
    getRelatedAreasRegions() {
        let objData = this.territoryList;
        let areaSet = new Set();
        let regionSet = new Set();
        let areaRegionMap = new Map(); // Area → Region
       
        if (this.employee.Sales_Channel__c.length > 0) {
            if(objData)
            {
                for (let i = 0; i < objData.length; i++) {
                    const obj = objData[i];
                    const channelMatch = this.employee.Sales_Channel__c.includes(obj.Sales_Channel__c);
                    if (channelMatch) {
                        if (obj.Area__c) {
                            areaSet.add(obj.Area__c);
                        }
                        if (obj.Region__c) {
                            regionSet.add(obj.Region__c);
                        }
                        // Build mapping only if not already mapped (to prevent overwriting)
                        if (!areaRegionMap.has(obj.Area__c)) {
                            areaRegionMap.set(obj.Area__c, obj.Region__c);
                        }
                    }
                }
            }
         
        }

        // Convert sets to arrays of options (for picklist use)
        this.areaOptions = Array.from(areaSet).map(area => ({ label: area, value: area }));
        this.regionOptions = Array.from(regionSet).map(region => ({ label: region, value: region }));
        this.areaRegionMap = Object.fromEntries(areaRegionMap);
    }

    handleCustomInputChange(event) {
        const fieldName = event.target.name;
        const fieldValue = event.detail.value;

        // Update the employee field
        this.employee = {
            ...this.employee,
            [fieldName]: fieldValue
        };

        // Handle Payroll__c logic
        if (fieldName === 'Payroll__c') {
            this.mandateContractType = (fieldValue === 'No');
        }
        else if (fieldName === 'Area__c' && this.areaRegionMap) {
            const region = this.areaRegionMap[fieldValue];
            if (region) {
                this.employee.Region__c = region;
            }
        }
    }

    //Handler Approver selection
    handleApproverSelection(event)
    {
        const { id, name, fieldName } = event.detail;
        if (fieldName === 'Secondary_Customer_Approver_1__c') {
            this.employee.Secondary_Customer_Approver_1__c = id;
            this.employee.Secondary_Customer_Approver_1_Name = name;
        }
        else if(fieldName === 'Secondary_Customer_Approver_2__c')
        {
            this.employee.Secondary_Customer_Approver_2__c = id;
            this.employee.Secondary_Customer_Approver_2_Name = name;
        }

        else if(fieldName === 'Primary_Customer_Approver_1__c')
        {
            this.employee.Primary_Customer_Approver_1__c = id;
            this.employee.Primary_Customer_Approver_1_Name = name;
        }
        else if(fieldName === 'Primary_Customer_Approver_2__c')
        {
            this.employee.Primary_Customer_Approver_2__c = id;
            this.employee.Primary_Customer_Approver_2_Name = name;
        }
        else if(fieldName === 'Primary_Customer_Approver_3_CD__c')
        {
            this.employee.Primary_Customer_Approver_3_CD__c = id;
            this.employee.Primary_Customer_Approver_3_CD_Name = name;
        }

         else if(fieldName === 'ASM_TSM__c')
        {
            this.employee.ASM_TSM__c = id;
            this.employee.ASM_TSM_Name = name;
        }
        else if(fieldName === 'RSM__c')
        {
            this.employee.RSM__c = id;
            this.employee.RSM_Name = name;
        }
         else if(fieldName === 'Employee_Approver_3_HR__c')
        {
            this.employee.Employee_Approver_3_HR__c = id;
            this.employee.Employee_Approver_3_HR_Name = name;
        }

         else if(fieldName === 'PJP_Approver_1__c')
        {
            this.employee.PJP_Approver_1__c = id;
            this.employee.PJP_Approver_1_Name = name;
        }
         else if(fieldName === 'PJP_Approver_2__c')
        {
            this.employee.PJP_Approver_2__c = id;
            this.employee.PJP_Approver_2_Name = name;
        }

          else if(fieldName === 'Expense_Approver_1__c')
        {
            this.employee.Expense_Approver_1__c = id;
            this.employee.Expense_Approver_1_Name = name;
        }
         else if(fieldName === 'Expense_Approver_2_Finance_Department__c')
        {
            this.employee.Expense_Approver_2_Finance_Department__c = id;
            this.employee.Expense_Approver_2_Finance_Department_Name = name;
        }

         else if(fieldName === 'Leave_Approver_L1__c')
        {
            this.employee.Leave_Approver_L1__c = id;
            this.employee.Leave_Approver_1_Name = name;
        }

        else if(fieldName === 'Leave_HR__c')
        {
            this.employee.Leave_HR__c = id;
            this.employee.Leave_HR_Name = name;
        }

       
    
    }

    //Save 
    handleButtonClick() {
        if(this.validateEmployeeFields())
        {
            this.duplicationCheck();
        }
    }
    validateEmployeeFields()
    {
        let isAllValid = true;
        let employee = this.employee; 
        const today = new Date().toISOString().split('T')[0]; // format: 'YYYY-MM-DD'
    
        // both secoundary customer and primary customer fields
        if (!employee.Name?.trim() || !employee.Profile__c || !employee.Mail_Id__c ||
            !employee.User_Name__c  || !employee.DOB__c || !employee.DOJ__c ||
            !employee.Sales_Channel__c) {
            isAllValid = false;
            this.showFieldError('employeeFields'); 
            this.showToast('Error', 'Please fill in all the mandatory fields', 'error');
            return isAllValid;
        }
        else if(!this.isAdminProfile && (!employee.Reporting_Manager_Name__c ||
           !employee.Primary_Phone_Number__c || !employee.User_Type__c))
        {
            isAllValid = false;
            this.showFieldError('employeeFields'); 
            this.showToast('Error', 'Please fill in all the mandatory fields', 'error');
            return isAllValid;
        }
        else if(this.aadharNumberMandate && !employee.Aadhar_Number__c)
        {
            isAllValid = false;
            this.showFieldError('employeeFields'); 
            this.showToast('Error', 'Please fill in all the mandatory fields', 'error');
            return isAllValid;
        }
        else if( !this.isAdminProfile &&  !employee.Reporting_Manager__c)
        {
            this.employee.Reporting_Manager_Name__c = '';
            this.showFieldError('employeeFields'); 
            this.showToast('Error', 'Please select reporting manager', 'error');
            isAllValid = false;
            return isAllValid;
        }
        else if( !this.isAdminProfile &&  employee.User_Type__c && employee.User_Type__c == 'Replacement'
            && !employee.Replaced_For__c
        )
        {
            this.employee.Replaced_For_Name__c = '';
            this.showFieldError('employeeFields'); 
            this.showToast('Error', 'Please select Replaced For', 'error');
            isAllValid = false;
            return isAllValid;
        }
    
        if (!this.isAdminProfile &&  employee.Payroll__c && employee.Payroll__c === 'No' && !employee.Contract_Type__c) {
            this.showFieldError('employeeFields'); 
            this.showToast('Error', 'Please select Contract Type', 'error');
            isAllValid = false;
            return isAllValid;
        } 
        else if( !this.isAdminProfile &&  employee.Payroll__c  && !employee.Employee_Code__c && this.isEmployeeCodeMandate)
        {
            this.showFieldError('employeeFields'); 
            this.showToast('Error', 'Please enter employee code', 'error');
            isAllValid = false;
            return isAllValid;
        }
        else if( !this.isAdminProfile &&  employee.Payroll__c && employee.Payroll__c === 'Yes' && !employee.Vendor_Code__c)
        {
            this.showFieldError('employeeFields'); 
            this.showToast('Error', 'Please select Vendor Code', 'error');
            isAllValid = false;
            return isAllValid;
        }
        else if(this.isRegionRequired && !employee.Region__c)
        {
            this.showFieldError('employeeFields'); 
            this.showToast('Error', 'Please select Region', 'error');
            isAllValid = false;
            return isAllValid;
        }
        else if(this.isAreaRequired && !employee.Area__c)
        {
            this.showFieldError('employeeFields'); 
            this.showToast('Error', 'Please select Area', 'error');
            isAllValid = false;
            return isAllValid;
        }
        else if(this.isTerritoryRequired && (!employee.Territory_Name__c || !employee.Territory__c))
        {
             this.employee.Territory_Name__c = '';
            this.showFieldError('employeeFields'); 
            this.showToast('Error', 'Please select Territory', 'error');
            isAllValid = false;
            return isAllValid;
        }
        else if(employee.Aadhar_Number__c &&  !/^\d{12}$/.test(employee.Aadhar_Number__c))
        {
            this.showFieldError('employeeFields'); 
            this.showToast('Error', 'Please enter a valid Aadhaar Number', 'error');
            isAllValid = false;
            return isAllValid;
        }
        else if(employee.Primary_Phone_Number__c  && !/^\d{10}$/.test(employee.Primary_Phone_Number__c))
        {
            this.showFieldError('employeeFields'); 
            this.showToast('Error', 'Please enter a valid Primary Phone Number', 'error');
            isAllValid = false;
            return isAllValid;
        }
        else if(employee.PAN__c &&  !/^[0-9a-zA-Z]{10}$/.test(employee.PAN__c))
        {
            this.showFieldError('employeeFields'); 
            this.showToast('Error', 'Please enter a valid PAN Number', 'error');
            isAllValid = false;
            return isAllValid;
        }
        else if(employee.Secondary_Phone_Number__c &&  !/^\d{10}$/.test(employee.Secondary_Phone_Number__c))
        {
            this.showFieldError('employeeFields'); 
            this.showToast('Error', 'Please enter a valid Alternate Phone Number', 'error');
            isAllValid = false;
            return isAllValid;
        }  
        else if(employee.Pincode__c  && !/^\d{6}$/.test(employee.Pincode__c))
        {
            this.showFieldError('employeeFields'); 
            this.showToast('Error', 'Please enter a valid Pincode', 'error');
            isAllValid = false;
            return isAllValid;
            
        }
        if (employee.DOJ__c && employee.DOJ__c < today && !this.recordId) {
            this.showFieldError('employeeFields'); 
            this.showToast('Error', 'Please select DOJ as current or future date', 'error');
            isAllValid = false;
            return isAllValid;
        }
       
        return isAllValid; 
    }
    duplicationCheck()
    {
        if (!navigator.onLine) {
            this.showToast('Error', 'No internet connection. Please check your network and try again.', 'error');
            this.isLoading = false;
            return;
        }
        this.isLoading = true;
        DUPLICATOION_CHECK({employeeData: this.employee})
        .then(data => {
            this.isLoading = false;
            if(data.duplicateFound)
            {
                if(data.duplicateField == 'User_Name__c')
                {
                    this.showAccountScreen = true;
                    let msg = 'An employee already exists with the same username. employee Name : ' + data.employeeName;
                    this.showToast('Error', msg, 'Error');
                }
                 else if(data.duplicateField == 'Aadhar_Number__c')
                {
                    this.showAccountScreen = true;
                    let msg = 'An employee already exists with the same Aadhar number. employee Name : ' + data.employeeName;
                    this.showToast('Error', msg, 'Error');
                }
                 else if(data.duplicateField == 'Employee_Code__c')
                {
                    this.showAccountScreen = true;
                    let msg = 'An employee already exists with the same employee code. employee Name : ' + data.employeeName;
                    this.showToast('Error', msg, 'Error');
                }
            }
            else
            {
               this.handleSave();
            }
    
        })
        .catch(error => {
            console.error(error);
            this.isLoading = false;
        });
    }
    handleSave() {
        this.isLoading = true;
        SAVE_DATA({ employeeData: this.employee})
        .then((result) => {
            this.message = result.approvalMessage;
            this.editaccess = result.editEmployee;
            if(!this.editaccess )
            {
                this.isLoading = false;
                return; 
            }
            
            this.showToast('Success','Employee saved successfully', 'Success');
            this.dispatchToAura('Done',result.recordId);
        })
        .catch(error => {
            this.showToast('Error', 'Something went wrong! Please try again', 'error');
            this.isLoading = false;
            console.error(error);
        });
    }
  

    //Cancel
    cancel()
    {
        if(this.recordId)
        {
            this.dispatchToAura('Done',this.recordId);
        }
        else
        {
            this.dispatchToAura('Cancel',null);
        }
    }

    //Helper Methods
    validateEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }
    resetTerritoryFields()
    {
        //Auto populated fields
        this.employee.Working_District__c = '';
        this.employee.Region__c= '';
        this.employee.Area__c = '';
        this.employee.Territory_Name__c = '';  
        this.employee.Territory__c = ''; 
    }
    resetFields()
    {
        //Auto populated fields
        this.employee.Working_District__c = '';
        this.employee.Region__c = '';
        this.employee.Area__c = '';
        this.employee.Territory_Name__c = '';  
        this.employee.Territory__c = ''; 
        this.employee.Sales_Channel__c = '';

        //Show and hide fields
        this.isShowRegion = false;
        this.isShowArea = false;
        this.isShowDistrict = false;
        this.isShowTerritory = false;

        //disabled fields
        this.isRegionDisabled = false;
        this.isAreaDisabled = false;
        this.isDistrictDisabled = false;
        this.isTerritoryDisabled = false; 
        
        //required fields
        this.isTerritoryRequired = false;
        this.isAreaRequired = false;
        this.isRegionRequired = false;

        this.isShowAllSections = true;
    }

    //Genric method to get the picklist values
    populateOptions(dataList, labelField, valueField) {
        const options = dataList?.map(item => ({
            label: item[labelField],
            value: item[valueField]
        })) || [];
        return options;
    }
    showFieldError(fieldPrefix) {
        const inputFields = this.template.querySelectorAll(`[data-id^="${fieldPrefix}"]`); 
        if (inputFields.length > 0) {
            inputFields.forEach(input => {
                input.reportValidity(); // Show validation error
            });
        }
    }
    getPicklistValueFromList(optionsArray) {
        return optionsArray.map(option => ({ label: option, value: option }));
    }
    dispatchToAura(textMessage,expenseId){
        // Created a custom event to Pass to aura component
        const event =  new CustomEvent('closepopup', {
            detail: {
                eventType: textMessage,
                Id:expenseId,
            },
          });
          this.dispatchEvent(event);
    }
    //disable pull to refesh
    disablePullToRefresh() {
        const disableRefresh = new CustomEvent("updateScrollSettings", {
            detail: {
            isPullToRefreshEnabled: false
            },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(disableRefresh);
    }
    //Show Toast
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    } 
}