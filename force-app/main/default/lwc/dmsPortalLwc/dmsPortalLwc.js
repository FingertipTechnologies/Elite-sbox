import { LightningElement, track, api, wire } from 'lwc';
import ORD_DATA from '@salesforce/apex/DMSPortalLwc.allOrderData';
import SEC_ORD_DATA from '@salesforce/apex/DMSPortalLwc.getSecondaryOrders';
import allInvoiceData from '@salesforce/apex/DMSPortalLwc.allInvoiceData';
import getInvoiceItems from '@salesforce/apex/DMSPortalLwc.getInvoiceItems';
import PAY_Rec_DATA from '@salesforce/apex/DMSPortalLwc.allPaymentReceiptData';
import GRN_DATA from '@salesforce/apex/DMSPortalLwc.allGRNData';
import CLAIM_DATA from '@salesforce/apex/DMSPortalLwc.allClaimData';
import STOCK_DATA from '@salesforce/apex/DMSPortalLwc.allDistributorStockData';
import CREDIT_NOTE_DATA from '@salesforce/apex/DMSPortalLwc.allCreditNoteData';
import SEC_INV_DATA from '@salesforce/apex/DMSPortalLwc.allSecoundaryInvoiceData';
import SRETURN_DATA from '@salesforce/apex/DMSPortalLwc.allSecoundaryReturnsData';
import GET_GRN_DATA from '@salesforce/apex/DMSPortalLwc.getGRNData';
import getPartnerAccountInfo from '@salesforce/apex/DMSPortalLwc.getPartnerAccountInfo';
import getCustomerLedger from '@salesforce/apex/DMSPortalLwc.getCustomerLedger';
import DMSIcon from '@salesforce/resourceUrl/DMS_LOGO';
import FORM_FACTOR from '@salesforce/client/formFactor';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import createPaymentWithItems from '@salesforce/apex/DMSPortalLwc.createPaymentWithItems';
import DMS_Home_Page_Offers from '@salesforce/resourceUrl/DMS_Home_Page_Offers';
import DMS_OFFER_COUNT from '@salesforce/label/c.DMS_Offer_Count';



import getPrimaryReturns from '@salesforce/apex/DMSPortalLwc.getPrimaryReturns';
import getPrimaryReturnItems from '@salesforce/apex/DMSPortalLwc.getPrimaryReturnItems';
import getPaymentReceiptDetails from '@salesforce/apex/DMSPortalLwc.getPaymentReceiptDetails';
import getReceiptItems from '@salesforce/apex/DMSPortalLwc.getReceiptItems';
import getGRNList from '@salesforce/apex/DMSPortalLwc.getGRNList';
import getGRNItems from '@salesforce/apex/DMSPortalLwc.getGRNItems';
import getGRNImages from '@salesforce/apex/DMSPortalLwc.getGRNImages';
import getSecondaryReturnItems from '@salesforce/apex/DMSPortalLwc.getSecondaryReturnItems';
import getSecondaryInvoiceItems from '@salesforce/apex/DMSPortalLwc.getSecondaryInvoiceItems';
import getOrderItems from '@salesforce/apex/DMSPortalLwc.getOrderItems';
import getOrderlineItems from '@salesforce/apex/DMSPortalLwc.getOrderlineItems';
import getUsers from '@salesforce/apex/DMSPortalLwc.getUsers';
import getSecondaryCustomers from '@salesforce/apex/DMSPortalLwc.getSecondaryCustomers';
import getRefreshSecondaryCustomers from '@salesforce/apex/DMSPortalLwc.getRefreshSecondaryCustomers';
import getInvoicePdfUrl from '@salesforce/apex/DMSPortalLwc.getInvoicePdfUrl';
import getStockAdjustments from '@salesforce/apex/DMSPortalLwc.getStockAdjustments';
import getSecondaryLedger from '@salesforce/apex/DMSPortalLwc.getSecondaryLedger';
import getOpeningBalance from '@salesforce/apex/DMSPortalLwc.getOpeningBalance';
import orgUrl from '@salesforce/label/c.orgUrl';
import { loadScript } from 'lightning/platformResourceLoader';
import SHEETJS from '@salesforce/resourceUrl/SheetJS';
import { refreshApex } from '@salesforce/apex';
const TAB_WIDTH = 145;     // realistic average width per tab
const RESERVED_WIDTH = 180; // logo + More button + spacing

export default class NavigationComponent extends LightningElement {
    //Varible related to tab Function
    @track selectedTab = 'Home';
    @track showMoreMenu = false;
    @track visibleTabCount = 0;

    allTabs = [
        { id: 'Home', label: 'Home' },
        { id: 'Orders', label: 'Primary Orders' },
        { id: 'Invoices', label: 'Primary Invoices' },
        { id: 'Returns', label: 'Sale Return' },
        { id: 'Payments', label: 'Receipts' },
        { id: 'GRN', label: 'GRNs' },
        { id: 'Claims', label: 'Claims' },
        { id: 'Stock', label: 'Stock' },
        { id: 'Credit Note', label: 'Secondary Credit Notes' },
        { id: 'Debit Note', label: 'Secondary Debit Notes' },
        { id: 'Secondary Receipt', label: 'Secondary Receipts' },
        { id: 'Secondary Orders', label: 'Secondary Orders' },
        { id: 'Secondary Invoices', label: 'Secondary Invoices' },
        { id: 'Secondary Returns', label: 'Secondary Returns' },
        { id: 'Secondary Customers', label: 'Secondary Customers' },
        { id: 'Secondary Customer Ledger', label: 'Secondary Customer Ledger' },
        { id: 'Users', label: 'Users' },
        { id: 'Stock Adjustment', label: 'Stock Adjustment' },
        { id: 'Product Gallery', label: 'Product Gallery' },
        { id: 'Product Master', label: 'Product Master' },
        { id: 'Schemes', label: 'Schemes' },
       /*{ id: 'Claim Reports', label: 'Claim Reports' }**/
    ];
    @track showSecondaryReceipt = false;

    //Variables related to data
    @track isNewDataUpload = false;
    @track showSecondaryOrders = true; // Show Secondary Orders table
    @track showSecondaryOrderItems = false; // Show Secondary Order Items table
    @track selectedSecondaryOrderId = ''; // Store the selected Secondary Order Id
    @track selectedSecondaryOrderNo = ''; // Store the selected Secondary Order Number
    @track secondaryOrderItems = [];
    @track hasSecondaryOrderItems = false;


    @track secondaryInvoiceItems = [];
    @track selectedSecondaryInvoiceId = null;
    @track selectedSecondaryInvoiceNo = '';
    @track showSecondaryInvoiceItems = false;
    @track hasSecondaryInvoiceItems = false;


    @track showSecondaryReturnItems = false;
    @track secondaryReturnItems = [];
    @track selectedSecondaryReturnNo = '';
    @track selectedSecondaryReturnId = null;
    @track hasSecondaryReturnItems = false;

    // Secondary Customer Ledger Tab
    @track showSecondaryCustomerLedger = false;

    // Secondary Customer Aging Report
    @track showSecondaryCustomerAgingReport = false;
    @track showOutstandingReport = false;
    @track selectedAgingCustomerId = '';
    @track selectedAgingCustomerName = '';


    @track orderItems = [];      // List of order items with Tax_Amount__c field
    @track totalTaxAmount = 0;   // Total tax amount calculated


    @track grnList = [];
    @track selectedGrnId = '';
    @track selectedGrnName = '';
    @track grnItems = [];
    @track showGrnItems = false;



    @track showReceiptItems = false;
    @track selectedReceipt = null;
    @track selectedReceiptItems = [];
    @track hasReceiptItems = false;



    @track primaryReturnItems = [];
    @track showPrimaryReturnItems = false;
    @track selectedPrimaryReturnNo = '';
    @track selectedPrimaryReturnId = null;
    @track isSubPartLoad = false;

    selectedOrderIds = [];
    selectedorderId;
    selectedCustomerName = [];
    selectedCustomerId = '';


    @track invoiceItems = [];
    @track showInvoiceItems = false;
    @track selectedInvoiceId = null;
    @track hasInvoiceItems = false;



    dmsIcon = DMSIcon;
    @track showModal = false;
    @track showOrderItems = false;
    @track hasOrderItems = false;
    @track selectedOrderItems = [];
    @track selectedOrderNo = '';
    @track isgenerateGRN = false;
    @track isNewReturn = false;
    @track isNewClaim = false;
    @track isNewOrder = false;
    @track isNewOrder2 = false;
    @track isNewOrder3 = false;


    @track isNewSecondaryReturn = false;
    @track selectedOrders = [];
    @track selectedInvoiceId;
    @track selectedInvoiceIds = [];
    @track allInvoiceItems = []; // Declare separately

    @track selectedInvoiceItems = [];

    /* secondary orders*/
    @track orderList = [];
    @track selectedOrders = [];


    /**Home header**/
    @track partnerAccountName = '';
    @track partnerSapCode = '';
    @track homeView = 'carousel';
    @track ledgerFromDate = '';
    @track ledgerToDate = '';
    @track ledgerOpeningBalance = null;
    @track ledgerClosingBalance = null;
    @track ledgerEntries = [];
    @track ledgerLoading = false;
    @track ledgerError = '';

    /**Primary**/
    showHome = true;
    showOrders = false;
    showPrimaryOrders = false;
    showPrimaryInvoices = false;
    showPrimaryReturn = false;
    showPrimaryPayments = false;
    showPrimaryGrn = false;
    showClaim = false;
    showStockAdjustment = false;
    showProductGallery = false;
    showClaimReports = false;
    showProductMatser = false;
    showSchemes = false;


    showStock = false;
    showCreditNote = false;
    showDebitNote = false;

    showCreatePrimaryGrn = false;

    /**Secoundary **/
    showSecondaryOrders = false;
    showSecoundaryInvoices = false;
    showSecoundaryReturn = false;
    isgenerateGRN = false;
    isGenerateInvoice = false;


    @track hideOrders = false;
    showCustomerDownloadMenu = false;


    @track ordFilter = {
        fromDate: '',
        srchVal: '',
        toDate: '',
        orderType: '',
        isOrderDataExisted: false,
        status: 'Invoice Pending',
        statusVal: [
            { label: 'Invoice Pending', value: 'Invoice Pending' },
            { label: 'Partially Invoiced', value: 'Partially Invoiced' },
            { label: 'Fully Invoiced', value: 'Fully Invoiced' }
        ],
        allordData: [],
        originalOrdData: []
    };
    @track InvFilter = {
        fromDate: '',
        srchVal: '',
        toDate: '',
        status: 'All',
        statusVal: [],
        allInvData: [],
        originalInvData: [],
        isInvoiceDataExisted: false,
    };



    @track primaryReturnFilter = {
        fromDate: '',
        srchVal: '',
        toDate: '',
        statusVal: [],
        allPReturnData: [],
        originalPReturnata: [],
        isDataExisted: false,
    };

    @track primaryPaymentsFilter = {
        fromDate: '',
        srchVal: '',
        toDate: '',
        statusVal: [],
        allPaymentData: [],
        originalPaymentData: [],
        isDataExisted: false,
    };
    @track GRNFilter = {
        fromDate: '',
        toDate: '',
        srchVal: '',
        allGRNData: [],
        originalGRNData: [],
        isDataExisted: false,
        allGRNList: [],
        originalGRNList: [],
        isListDataExisted: false,
        allGRNItems: [],
        isItemsDataExisted: false
    };

    @track claimFilter = {
        fromDate: '',
        srchVal: '',
        toDate: '',
        status: '',
        statusVal: [],
        allClaimData: [],
        originalClaimData: [],
        isDataExisted: false,
    };
    @track stockFilter = {
        fromDate: '',
        srchVal: '',
        toDate: '',
        status: 'All',
        statusVal: [],
        productCategories: [],
        selectedCategory: '',
        allStockData: [],
        originalStockData: [],
        isDataExisted: false,
    };
    @track creditNoteFilter = {
        fromDate: '',
        srchVal: '',
        toDate: '',
        status: '',
        statusVal: [],
        allCreditNoteData: [],
        originalCreditNoteData: [],
        isDataExisted: false,
    };
    @track secInvFilter = {
        fromDate: '',
        srchVal: '',
        toDate: '',
        status: '',
        statusVal: [],
        allSecInvData: [],
        originalSecInvData: [],
        isDataExisted: false,
    };
    @track secoundaryReturnFilter = {
        fromDate: '',
        srchVal: '',
        toDate: '',
        statusVal: [],
        allSReturnData: [],
        originalSReturnata: [],
        isDataExisted: false,
    };

    @track stockAdjustmentFilter = {
        fromDate: '',
        srchVal: '',
        toDate: '',
        statusVal: [],
        allStockAdjuments: [],
        originalStockAdjustments: [],
        isDataExisted: false,
    };

    @track secoundaryCustomerFilter = {
        allSecondaryCustomers: [],
        originalSecondaryCustomers: [],
        searchCustomer: '',
        status :'All',
        statusVal: [
            { label: 'All', value: 'All' },
            { label: 'Active', value: 'Active' },
            { label: 'Activation Pending', value: 'Activation Pending' },
            { label: 'Inactive', value: 'Inactive' },
             { label: 'Dormant', value: 'Dormant' }
        ],
        isshowData: false
    };

    SECONDARY_CUSTOMER_PAGE_SIZE = 100;
    @track visibleSecondaryCustomers = [];
    _secondaryVisibleCount = 100;
    @track showOverCreditOnly = false;

    @track showReportTypeModal = false;
    @track selectedReportType = 'outstanding';
    reportTypeOptions = [
        { label: 'Outstanding Report', value: 'outstanding' },
        { label: 'Aging Report', value: 'aging' }
    ];

    @track secondaryCustomerLedgerFilter = {
        fromDate: '',
        toDate: '',
        selectedCustomerId: '',
        selectedCustomerName: '',
        srchVal: '',
        status: '',
        statusVal: [
            { label: 'All', value: '' },
            { label: 'Pending', value: 'Pending' },
            { label: 'Paid', value: 'Paid' },
            { label: 'Partial', value: 'Partial' }
        ],
        customerOptions: [],
        allLedgerData: [],
        originalLedgerData: [],
        openingBalance: 0,
        isDataExisted: false
    };

    isSubPartLoad = false;
    isPageLoaded = false;
    isDesktop = false;
    isPhone = false;
    containerClass = 'slds-modal__container';
    isPopupLoading = false;
    userList = [];
    allUsers = [];
    searchKey = '';
    isShowSecondaryCustomers = false;


    invoiceIdToDownloadPdf = '';
    isShowNewAdjustStock = false;
    customerNameWithCode = '';

    @track showPageSizeModal = false;
    @track selectedPdfPageSize = 'A4';
    pageSizeOptions = [
        { label: 'A4', value: 'A4' },
        { label: 'A5', value: 'A5' }
    ];


    /*Dynamic Tabs */
    get primaryTabs() {
        return this.allTabs.slice(0, this.visibleTabCount).map(tab => ({
            ...tab,
            cssClass: this.selectedTab === tab.id
                ? 'nav-item selected'
                : 'nav-item'
        }));
    }

    get overflowTabs() {
        return this.allTabs.slice(this.visibleTabCount).map(tab => ({
            ...tab,
            cssClass: this.selectedTab === tab.id
                ? 'more-menu-item selected'
                : 'more-menu-item'
        }));
    }

    get hasOverflow() {
        return this.allTabs.length > this.visibleTabCount;
    }

    connectedCallback() {
        // Merge both connectedCallbacks
        try {
            this.calculateTabs();
            this.resizeHandler = this.calculateTabs.bind(this);
            window.addEventListener('resize', this.resizeHandler);
            this.isDesktop = FORM_FACTOR === 'Large' ? true : false;
            this.isPhone = FORM_FACTOR === 'Small' ? true : false;
            if (FORM_FACTOR === 'Medium') this.isDesktop = true;
            this.isPageLoaded = true;
            this.containerClass = this.isDesktop ? 'slds-modal__container' : 'mobilePopup';
            this.disablePullToRefresh();
        } catch (error) {
            console.error('Error in connectedCallback:', error);
        }
        loadScript(this, XLSX)
            .then(() => {
                this.xlsxJsLibrary = window.XLSX;
                console.log('XLSX library loaded successfully!');
            })
            .catch((error) => {
                console.error('Error loading XLSX library', error);
            });
        // Carousel logic from second connectedCallback
        this.startCarousel && this.startCarousel();
    }

    disconnectedCallback() {
        // Merge both disconnectedCallbacks
        window.removeEventListener('resize', this.resizeHandler);
        if (this._navResizeObserver) {
            this._navResizeObserver.disconnect();
            this._navResizeObserver = null;
        }
        if (this.interval) {
            clearInterval(this.interval);
        }
    }
    renderedCallback() {
        this.calculateTabs();
        if (!this._navResizeObserver) {
            const navbar = this.template.querySelector('.navbar');
            if (navbar && typeof ResizeObserver !== 'undefined') {
                this._navResizeObserver = new ResizeObserver(() => this.calculateTabs());
                this._navResizeObserver.observe(navbar);
            }
        }
    }
    /*  Calculate based on actual rendered tab widths */
    calculateTabs() {
        const navbar = this.template.querySelector('.navbar');
        const navImg = this.template.querySelector('.nav-img');
        const measureContainer = this.template.querySelector('.nav-items-measure');
        const measureItems = measureContainer
            ? measureContainer.querySelectorAll(':scope > li')
            : null;

        if (!navbar || !measureContainer || !measureItems || measureItems.length === 0) {
            return;
        }

        const outerWidth = (el) => {
            const rect = el.getBoundingClientRect();
            const style = window.getComputedStyle(el);
            const ml = parseFloat(style.marginLeft) || 0;
            const mr = parseFloat(style.marginRight) || 0;
            return rect.width + ml + mr;
        };

        const navbarStyle = window.getComputedStyle(navbar);
        const navbarPadding =
            (parseFloat(navbarStyle.paddingLeft) || 0) +
            (parseFloat(navbarStyle.paddingRight) || 0);
        const containerWidth = Math.min(
            navbar.clientWidth - navbarPadding,
            window.innerWidth || Number.MAX_SAFE_INTEGER
        );

        const navImgWidth = navImg ? outerWidth(navImg) : 0;
        // Last measure item is the sample "More" button.
        const moreBtnWidth = outerWidth(measureItems[measureItems.length - 1]);
        const safetyGap = 32;

        const availableForTabs = Math.max(
            0,
            containerWidth - navImgWidth - moreBtnWidth - safetyGap
        );

        // Use the measurement container's own layout (which already includes
        // flex gaps and per-item margins) by reading each item's right edge
        // relative to the container's left edge.
        const containerLeft = measureContainer.getBoundingClientRect().left;
        const widthsCumulative = [];
        let totalAllTabs = 0;
        for (let i = 0; i < this.allTabs.length; i++) {
            const rect = measureItems[i].getBoundingClientRect();
            const style = window.getComputedStyle(measureItems[i]);
            const mr = parseFloat(style.marginRight) || 0;
            const cumulative = rect.right + mr - containerLeft;
            widthsCumulative.push(cumulative);
            totalAllTabs = cumulative;
        }

        let newCount;
        if (totalAllTabs <= containerWidth - navImgWidth - safetyGap) {
            newCount = this.allTabs.length;
        } else {
            let count = 0;
            for (let i = 0; i < this.allTabs.length; i++) {
                if (widthsCumulative[i] > availableForTabs) break;
                count++;
            }
            newCount = Math.max(1, Math.min(count, this.allTabs.length));
        }

        if (newCount !== this.visibleTabCount) {
            this.visibleTabCount = newCount;
        }
    }
    toggleMoreMenu(event) {
        event.stopPropagation();
        this.showMoreMenu = !this.showMoreMenu;
    }
    handleOutsideClick = (event) => {
        const dropdown = this.template.querySelector('.more-dropdown');
        if (dropdown && !dropdown.contains(event.target)) {
            this.showMoreMenu = false;
        }
    };
    selectTab(event) {
        const tabId = event.currentTarget.dataset.id;
        this.selectedTab = tabId;
        this.showMoreMenu = false;

        const selectedIndex = this.allTabs.findIndex(tab => tab.id === tabId);

        // If selected tab is in overflow, bring it into visible area
        if (selectedIndex >= this.visibleTabCount) {
            const selectedTab = this.allTabs.splice(selectedIndex, 1)[0];

            // Insert selected tab at last visible position
            this.allTabs.splice(this.visibleTabCount - 1, 0, selectedTab);
        }
        const rowId = event.target.dataset.id;
        this.selectedTabFunction();
        this.dispatchEvent(new CustomEvent('tabselect', {
            detail: { tabId }
        }));
    }

    resetAllFlags() {
        this.showHome = false;
        this.showOrders = false;
        this.showPrimaryOrders = false;
        this.showPrimaryInvoices = false;
        this.showPrimaryReturn = false;
        this.showPrimaryPayments = false;
        this.showPrimaryGrn = false;
        this.showClaim = false;
        this.showStock = false;
        this.showCreditNote = false;
        this.showDebitNote = false;
        this.showSecondaryReceipt = false;

        this.showSecondaryOrders = false;
        this.showSecoundaryInvoices = false;
        this.showSecoundaryReturn = false;

        this.showOrderItems = false;
        this.showInvoiceItems = false;
        this.showPrimaryReturnItems = false;
        this.showReceiptItems = false;
        this.showGrnItems = false;
        this.showSecondaryReturnItems = false;
        this.showSecondaryInvoiceItems = false;
        this.showSecondaryOrderItems = false;

        this.isNewOrder = false;
        this.isNewOrder2 = false;
        this.isNewOrder3 = false;
        this.isNewReturn = false;
        this.isNewClaim = false;
        this.isNewSecondaryReturn = false;
        this.isGenerateInvoice = false;
        this.isgenerateGRN = false;

        this.isNewDataUpload = false;
        this.showusers = false;
        this.isShowSecondaryCustomers = false;
        this.showStockAdjustment = false;
        this.isShowNewAdjustStock = false;
        this.showProductGallery = false;
        this.showSecondaryCustomerLedger = false;
        this.showSecondaryCustomerAgingReport = false;
        this.showOutstandingReport = false;
        this.showClaimReports = false;
        this.showProductMatser = false;
        this.showSchemes = false;
    }

    selectedTabFunction() {
        this.resetAllFlags();

        switch (this.selectedTab) {
            case 'Secondary Receipt':
                this.showSecondaryReceipt = true;
                break;
            case 'Home':
                this.showHome = true;
                break;
            case 'Orders':
                this.showOrders = true;
                this.showPrimaryOrders = true;
                this.getOrderData();
                break;
            case 'Invoices':
                this.showPrimaryInvoices = true;
                this.getInvoiceData();
                break;
            case 'Returns':
                this.showPrimaryReturn = true;
                this.getPrimaryReturnData();
                break;
            case 'Payments':
                this.showPrimaryPayments = true;
                this.getPrimaryPaymemtsData();
                break;
            case 'GRN':
                this.showPrimaryGrn = true;
                this.getGRNsData();
                break;
            case 'Claims':
                this.showClaim = true;
                this.getClaimData();
                break;
            case 'Stock':
                this.showStock = true;
                this.getStockData();
                break;
            case 'Credit Note':
                this.showCreditNote = true;
                this.getCreditData();
                break;
            case 'Debit Note':
                this.showDebitNote = true;
                break;
            case 'Secondary Orders':
                this.showSecondaryOrders = true;
                this.getSecoundaryOrderData();
                break;
            case 'Secondary Invoices':
                this.showSecoundaryInvoices = true;
                this.getSecoundaryInvoiceData();
                break;
            case 'Secondary Returns':
                this.showSecoundaryReturn = true;
                this.getSecoundaryReturnData();
                break;
            case 'Users':
                this.showusers = true;
                this.getUserData();
                break;
            case 'Secondary Customers':
                this.isShowSecondaryCustomers = true;
                this.getCustomerData();
                break;
            case 'Secondary Customer Ledger':
                this.showSecondaryCustomerLedger = true;
                //this.getSecondaryLedgerData();
                break;
            case 'Stock Adjustment':
                this.showStockAdjustment = true;
                this.getStockAdjustmentsWithFilter();
                break;
            case 'Product Gallery':
                this.showProductGallery = true;
                break;
            case 'Claim Reports':
                this.showClaimReports = true;
                break;
            case 'Product Master':
                this.showProductMatser = true;
                break;    
            case 'Schemes':
                this.showSchemes = true;
                break;  
            default:
                break;
        }
    }

    /**Stock Adjustments */
    getStockAdjustmentsWithFilter() {
        const today = new Date();
        const firstDate = new Date(today.getFullYear(), today.getMonth(), 1);
        const lastDate = new Date(today.getFullYear(), today.getMonth() + 1, 0);
        const formatDate = (date) => date.toLocaleDateString('en-CA');
        this.stockAdjustmentFilter.fromDate = formatDate(firstDate);
        this.stockAdjustmentFilter.toDate = formatDate(lastDate);
        this.stockAdjustmentFilter.status = 'All';
        this.stockAdjustmentData();
    }

    stockAdjustmentData() {
        this.isSubPartLoad = true;
        const { status, fromDate, toDate } = this.stockAdjustmentFilter;
        getStockAdjustments({
            frmDate: fromDate,
            toDate: toDate,
            status: status
        })
            .then(result => {
                console.log('Data' + JSON.stringify(result.adjustmentTypes));
                this.stockAdjustmentFilter.statusVal = result.adjustmentTypes;
                this.stockAdjustmentFilter.allStockAdjuments = this.addRowIndex(result.stockAdjustmentList);
                this.stockAdjustmentFilter.originalStockAdjustments = this.addRowIndex(result.stockAdjustmentList);
                this.stockAdjustmentFilter.isDataExisted = this.stockAdjustmentFilter.allStockAdjuments.length != 0 ? true : false;
                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error(error);
                this.isSubPartLoad = false;
            });
    }


    handlestockAdjustmentChange(event) {
        this.stockAdjustmentFilter[event.target.name] = event.target.value;
        this.stockAdjustmentFilter.srchVal = '';
        this.stockAdjustmentData();
    }

    handleStockAdjustmentSerch(event) {
        const txt = event.target.value;
        console.log('Searched Value: ' + txt);

        // Create a shallow copy to trigger reactivity
        this.stockAdjustmentFilter = { ...this.stockAdjustmentFilter, srchVal: txt };

        if (txt.length > 0) {
            const dataUpdate = this.stockAdjustmentFilter.originalStockAdjustments.filter(rec =>
                (rec.productName && rec.productName.toLowerCase().includes(txt.toLowerCase()))
            );
            const indexedData = this.addRowIndex(dataUpdate);
            this.stockAdjustmentFilter = {
                ...this.stockAdjustmentFilter,
                allStockAdjuments: indexedData,
                isDataExisted: dataUpdate.length !== 0
            };
        } else {
            const indexedData = this.addRowIndex(this.stockAdjustmentFilter.originalStockAdjustments);
            this.stockAdjustmentFilter = {
                ...this.stockAdjustmentFilter,
                allStockAdjuments: indexedData,
                isDataExisted: this.stockAdjustmentFilter.originalStockAdjustments.length !== 0 ? true : false
            };
        }
    }

    handlerNewStockAdjustmentClick() {
        this.resetAllFlags();
        this.isShowNewAdjustStock = true;
    }

    handleNewStockAdjustmentCancel() {
        this.resetAllFlags();
        this.showStockAdjustment = true;
    }
    handleStockAdjustmentCreation() {
        this.resetAllFlags();
        this.showStockAdjustment = true;
        this.getStockAdjustmentsWithFilter();
    }


    /**------user Data------**/
    getUserData() {
        this.userFilter = {
            searchKey: '',
            status: 'Active'  // Active | Inactive | All
        };

        this.fetchUsers();
    }
    fetchUsers() {
        console.log('===== fetchUsers START =====');

        console.log('Search Key:', this.userFilter.searchKey);
        console.log('Status    :', this.userFilter.status);

        // Optional loader
        this.isSubPartLoad = true;

        getUsers({
            searchKey: this.userFilter.searchKey,
            status: this.userFilter.status
        })
            .then(result => {
                if (!result || result.length === 0) {
                    this.userList = [];
                    this.allUsers = [];
                    this.isSubPartLoad = false;
                    return;
                }

                const mappedUsers = result.map(u => ({
                    id: u.Id,
                    name: u.Executive_Name__c,
                    username: u.Username,
                    email: u.Email,
                    profile: u.Profile ? u.Profile.Name : '',
                    isActive: u.IsActive,
                    statusLabel: u.IsActive ? 'Active' : 'Inactive',
                    Manager: u.Manager_Name__c
                }));

                this.allUsers = mappedUsers;
                this.userList = [...mappedUsers];

                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error('Apex Error:', error);
                this.userList = [];
                this.isSubPartLoad = false;
                console.log('===== fetchUsers END (ERROR) =====');
            });
    }
    handleSearch(event) {
        this.searchKey = event.target.value || '';
        const key = this.searchKey.toLowerCase();

        if (!key) {
            this.userList = [...this.allUsers];
            return;
        }

        this.userList = this.allUsers.filter(u =>
            (u.name || '').toLowerCase().includes(key) ||
            (u.username || '').toLowerCase().includes(key)
        );
    }
    get hasUsers() {
        return this.userList && this.userList.length > 0;
    }

    /**Secondary Customer Data */
    getCustomerData() {
        this.isSubPartLoad = true;

        getSecondaryCustomers({
            status: this.secoundaryCustomerFilter.status
        })
            .then(result => {
                console.log('data' + JSON.stringify(result.customerData))
                this.secoundaryCustomerFilter.originalSecondaryCustomers = result.customerData || [];
                this.secoundaryCustomerFilter.allSecondaryCustomers = result.customerData || [];
                this.secoundaryCustomerFilter.isshowData =
                    result.customerData && result.customerData.length > 0;
                this._secondaryVisibleCount = this.SECONDARY_CUSTOMER_PAGE_SIZE;
                this._applySecondaryCustomerPagination();
            })
            .catch(error => {
                console.error('Error fetching secondary customers:', error);
            })
            .finally(() => {
                this.isSubPartLoad = false;
            });
    }
    handleCustomerRefresh() {
        this.isSubPartLoad = true;

        getRefreshSecondaryCustomers({
            status: this.secoundaryCustomerFilter.status
        })
        .then(result => {
            console.log('data' + JSON.stringify(result.customerData))
            this.secoundaryCustomerFilter.originalSecondaryCustomers = result.customerData || [];
            this.secoundaryCustomerFilter.allSecondaryCustomers = result.customerData || [];
            this.secoundaryCustomerFilter.isshowData =
                result.customerData && result.customerData.length > 0;
            this._secondaryVisibleCount = this.SECONDARY_CUSTOMER_PAGE_SIZE;
            this._applySecondaryCustomerPagination();
        })
        .catch(error => {
            console.error('Error fetching secondary customers:', error);
        })
        .finally(() => {
            this.isSubPartLoad = false;
        });
    }

    get hasMoreSecondaryCustomers() {
        return this.visibleSecondaryCustomers.length <
            this._getFilteredSecondaryCustomers().length;
    }

    get loadMoreSecondaryCustomersLabel() {
        const total = this._getFilteredSecondaryCustomers().length;
        const remaining = total - this.visibleSecondaryCustomers.length;
        const next = Math.min(this.SECONDARY_CUSTOMER_PAGE_SIZE, remaining);
        return `Load More (${next} of ${remaining} remaining)`;
    }

    _getFilteredSecondaryCustomers() {
        const src = this.secoundaryCustomerFilter.originalSecondaryCustomers || [];
        if (!this.showOverCreditOnly) {
            return src;
        }
        return src.filter(c => {
            const limit = Number(c.creditLimit) || 0;
            const outstanding = Number(c.outStanding) || 0;
            return (outstanding - limit) > 0;
        });
    }

    _applySecondaryCustomerPagination() {
        const src = this._getFilteredSecondaryCustomers();
        this.visibleSecondaryCustomers = src.slice(0, this._secondaryVisibleCount);
        this.secoundaryCustomerFilter.isshowData = this.visibleSecondaryCustomers.length > 0;
    }

    handleSecondaryCustomerLoadMore() {
        this._secondaryVisibleCount += this.SECONDARY_CUSTOMER_PAGE_SIZE;
        this._applySecondaryCustomerPagination();
    }

    handleOverCreditToggle(event) {
        this.showOverCreditOnly = event.target.checked;
        this._secondaryVisibleCount = this.SECONDARY_CUSTOMER_PAGE_SIZE;
        this._applySecondaryCustomerPagination();
    }

    handleSecondaryCustomerStatusChange(event) {
        this.secoundaryCustomerFilter.status = event.detail.value;
        // Reapply filter logic based on the selected status
        this.getCustomerData();
    }

    handleCustomerSearch(event) {
        const searchVal = event.target.value || '';
        const key = searchVal.toLowerCase();

        // Reset when search is empty
        if (!key) {
            this.secoundaryCustomerFilter.originalSecondaryCustomers = [
                ...this.secoundaryCustomerFilter.allSecondaryCustomers
            ];
            this.secoundaryCustomerFilter.isshowData =
                this.secoundaryCustomerFilter.originalSecondaryCustomers.length > 0;
            this._secondaryVisibleCount = this.SECONDARY_CUSTOMER_PAGE_SIZE;
            this._applySecondaryCustomerPagination();
            return;
        }

        // Filter data
        this.secoundaryCustomerFilter.originalSecondaryCustomers =
            this.secoundaryCustomerFilter.allSecondaryCustomers.filter(c =>
                (c.secondaryCustomerName || '').toLowerCase().includes(key) ||
                (c.secondaryCustomerCode || '').toLowerCase().includes(key) ||
                (c.primaryPhoneNumber || '').toLowerCase().includes(key)
            );

        // Show / hide data
        this.secoundaryCustomerFilter.isshowData =
            this.secoundaryCustomerFilter.originalSecondaryCustomers.length > 0;
        this._secondaryVisibleCount = this.SECONDARY_CUSTOMER_PAGE_SIZE;
        this._applySecondaryCustomerPagination();
    }

    handleAgingReportBack() {
        this.showSecondaryCustomerAgingReport = false;
        this.isShowSecondaryCustomers = true;
        this.isSubPartLoad = true;
        setTimeout(() => {
            this.isSubPartLoad = false;
        }, 3000);
        this.getCustomerData();
    }

    openReportTypeModal(event) {
        this.selectedAgingCustomerId = event.currentTarget.dataset.id;
        this.selectedAgingCustomerName = event.currentTarget.dataset.name;
        this.selectedReportType = 'outstanding';
        this.showReportTypeModal = true;
    }

    handleReportTypeChange(event) {
        this.selectedReportType = event.detail.value;
    }

    closeReportTypeModal() {
        this.showReportTypeModal = false;
    }

    confirmReportView() {
        this.showReportTypeModal = false;
        this.isShowSecondaryCustomers = false;
        if (this.selectedReportType === 'aging') {
            this.showSecondaryCustomerAgingReport = true;
        } else {
            this.showOutstandingReport = true;
        }
    }

    handleOutstandingReportBack() {
        this.showOutstandingReport = false;
        this.isShowSecondaryCustomers = true;
        this.isSubPartLoad = true;
        setTimeout(() => {
            this.isSubPartLoad = false;
        }, 3000);
        this.getCustomerData();
    }

    handleCustomerExportCsv() {
        this.showCustomerDownloadMenu = false;
        const data = this._getFilteredSecondaryCustomers();

        if (!data || data.length === 0) {
            this.showToast('Export Error', 'No customer data to export', 'error');
            return;
        }

        try {
            const headers = [
                'S.No.', 'Customer Name', 'Customer Code', 'Customer Type',
                'Customer Category', 'Status', 'Primary Phone', 'Beat Name',
                'Email ID', 'Aadhaar No', 'GST Number', 'Contact Person',
                'PAN Number', 'Payment Type', 'Credit Limit', 'Payment Term',
                'Credit Description', 'District', 'Landmark', 'Street', 'Pincode',
                'Outstanding'
            ];

            const rows = data.map(cust => [
                cust.sNumber               || '',
                cust.secondaryCustomerName || '',
                cust.secondaryCustomerCode || '',
                cust.customerType          || '',
                cust.customerCategory      || '',
                cust.status                || '',
                cust.primaryPhoneNumber    || '',
                cust.beatName              || '',
                cust.email                 || '',
                cust.aadhaarNo             || '',
                cust.gstNumber             || '',
                cust.contactPersonName     || '',
                cust.panNumber             || '',
                cust.paymentType           || '',
                cust.creditLimit           || '',
                cust.paymentTerm           || '',
                cust.creditDescription     || '',
                cust.district              || '',
                cust.landmark              || '',
                cust.street                || '',
                cust.pincode               || '',
                cust.outStanding           || ''
            ]);

            const csvContent = [headers, ...rows]
                .map(row =>
                    row.map(cell =>
                        '"' + String(cell).replace(/"/g, '""') + '"'
                    ).join(',')
                )
                .join('\r\n');

            const blob = new Blob(['\uFEFF' + csvContent], { type: 'text/plain' });
            const url  = URL.createObjectURL(blob);
            const a    = document.createElement('a');
            a.href     = url;
            const filePrefix = this.showOverCreditOnly ? 'OverCreditCustomers' : 'SecondaryCustomers';
            a.download = `${filePrefix}_${new Date().toISOString().slice(0,10)}.csv`;
            a.style.display = 'none';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            setTimeout(() => URL.revokeObjectURL(url), 1000);

        } catch (error) {
            console.error('CSV Export Error:', error);
            this.showToast('Export Error', 'Failed to export CSV: ' + error.message, 'error');
        }
    }
    toggleCustomerDownloadMenu() {
        this.showCustomerDownloadMenu = !this.showCustomerDownloadMenu;
    }
    handleCustomerExportXlsx() {
        this.showCustomerDownloadMenu = false;
        const data = this._getFilteredSecondaryCustomers();

        if (!data || data.length === 0) {
            this.showToast('Export Error', 'No customer data to export', 'error');
            return;
        }

        // If SheetJS is loaded use it, otherwise fall back to CSV with .csv extension
        const XLSX = window.XLSX;

        if (XLSX) {
            try {
                const headers = [
                    'S.No.', 'Customer Name', 'Customer Code', 'Customer Type',
                    'Customer Category', 'Status', 'Primary Phone', 'Beat Name',
                    'Email ID', 'Aadhaar No', 'GST Number', 'Contact Person',
                    'PAN Number', 'Payment Type', 'Credit Limit', 'Payment Term',
                    'Credit Description', 'District', 'Landmark', 'Street', 'Pincode',
                    'Outstanding'
                ];

                const rows = data.map(cust => [
                    cust.sNumber               || '',
                    cust.secondaryCustomerName || '',
                    cust.secondaryCustomerCode || '',
                    cust.customerType          || '',
                    cust.customerCategory      || '',
                    cust.status                || '',
                    cust.primaryPhoneNumber    || '',
                    cust.beatName              || '',
                    cust.email                 || '',
                    cust.aadhaarNo             || '',
                    cust.gstNumber             || '',
                    cust.contactPersonName     || '',
                    cust.panNumber             || '',
                    cust.paymentType           || '',
                    cust.creditLimit           || '',
                    cust.paymentTerm           || '',
                    cust.creditDescription     || '',
                    cust.district              || '',
                    cust.landmark              || '',
                    cust.street                || '',
                    cust.pincode               || '',
                    cust.outStanding           || ''
                ]);

                const ws = XLSX.utils.aoa_to_sheet([headers, ...rows]);

                // Column widths
                ws['!cols'] = [
                    { wch: 6  },  // S.No.
                    { wch: 25 },  // Customer Name
                    { wch: 15 },  // Customer Code
                    { wch: 15 },  // Customer Type
                    { wch: 18 },  // Customer Category
                    { wch: 12 },  // Status
                    { wch: 14 },  // Primary Phone
                    { wch: 18 },  // Beat Name
                    { wch: 24 },  // Email ID
                    { wch: 16 },  // Aadhaar No
                    { wch: 18 },  // GST Number
                    { wch: 20 },  // Contact Person
                    { wch: 14 },  // PAN Number
                    { wch: 14 },  // Payment Type
                    { wch: 14 },  // Credit Limit
                    { wch: 14 },  // Payment Term
                    { wch: 24 },  // Credit Description
                    { wch: 14 },  // District
                    { wch: 20 },  // Landmark
                    { wch: 24 },  // Street
                    { wch: 10 },  // Pincode
                    { wch: 14 }   // Outstanding
                ];

                const sheetName = this.showOverCreditOnly ? 'Over Credit Customers' : 'Secondary Customers';
                const filePrefix = this.showOverCreditOnly ? 'OverCreditCustomers' : 'SecondaryCustomers';
                const wb = XLSX.utils.book_new();
                XLSX.utils.book_append_sheet(wb, ws, sheetName);
                XLSX.writeFile(wb, `${filePrefix}_${new Date().toISOString().slice(0,10)}.xlsx`);

            } catch (error) {
                console.error('XLSX Export Error:', error);
                this.showToast('Export Error', 'Failed to export Excel: ' + error.message, 'error');
            }

        } else {
            // SheetJS not loaded — fall back to CSV (opens in Excel perfectly)
            this.handleCustomerExportCsv();
            this.showToast('Info', 'Downloaded as CSV — opens in Excel', 'info');
        }
    }

    /**-----Secondary Customer Ledger-----**/
    getSecondaryLedgerData() {
        const today = new Date();
        const firstDate = new Date(today.getFullYear(), today.getMonth(), 1);
        const lastDate = new Date(today.getFullYear(), today.getMonth() + 1, 0);
        const formatDate = (date) => date.toLocaleDateString('en-CA');
        this.secondaryCustomerLedgerFilter.fromDate = formatDate(firstDate);
        this.secondaryCustomerLedgerFilter.toDate = formatDate(lastDate);
        this.secondaryCustomerLedgerFilter.status = '';
        
        // Load customers and ledger data
        this.loadLedgerCustomers();
    }

    loadLedgerCustomers() {
        this.isSubPartLoad = true;
        
        getSecondaryCustomers({
            status: 'All'
        })
            .then(result => {
                console.log('Ledger Customers:', JSON.stringify(result.customerData));
                const customers = result.customerData || [];
                this.secondaryCustomerLedgerFilter.customerOptions = customers.map(c => ({
                    label: c.secondaryCustomerName,
                    value: c.Id
                }));
                
                // If customers exist, select the first one by default
                if (customers.length > 0) {
                    this.secondaryCustomerLedgerFilter.selectedCustomerId = customers[0].Id;
                    this.secondaryCustomerLedgerFilter.selectedCustomerName = customers[0].secondaryCustomerName;
                }
                
                // Now fetch ledger data
                this.fetchLedgerData();
            })
            .catch(error => {
                console.error('Error loading ledger customers:', error);
                this.isSubPartLoad = false;
            });
    }

    fetchLedgerData() {
        const { fromDate, toDate, selectedCustomerId } = this.secondaryCustomerLedgerFilter;
        
        if (!selectedCustomerId) {
            this.secondaryCustomerLedgerFilter.allLedgerData = [];
            this.secondaryCustomerLedgerFilter.isDataExisted = false;
            this.isSubPartLoad = false;
            return;
        }

        // Get opening balance
        getOpeningBalance({
            customerId: selectedCustomerId,
            asOfDate: fromDate
        })
            .then(openingBalResult => {
                console.log('Opening Balance:', openingBalResult);
                this.secondaryCustomerLedgerFilter.openingBalance = openingBalResult.balance || 0;
                
                // Now get ledger transactions
                return getSecondaryLedger({
                    customerId: selectedCustomerId,
                    fromDate: fromDate,
                    toDate: toDate,
                    status: this.secondaryCustomerLedgerFilter.status
                });
            })
            .then(ledgerResult => {
                console.log('Ledger Data:', JSON.stringify(ledgerResult));
                
                const ledgerData = ledgerResult.ledgerData || [];
                
                // Calculate running balance
                let runningBalance = this.secondaryCustomerLedgerFilter.openingBalance;
                const processedData = ledgerData.map((entry, index) => {
                    // Determine if debit or credit
                    const isDebit = entry.transactionType === 'Invoice' || entry.transactionType === 'Debit Note';
                    const isCredit = entry.transactionType === 'Receipt' || entry.transactionType === 'Return' || entry.transactionType === 'Credit Note';
                    
                    const debitAmount = isDebit ? (entry.amount || 0) : 0;
                    const creditAmount = isCredit ? (entry.amount || 0) : 0;
                    
                    runningBalance = runningBalance + debitAmount - creditAmount;
                    
                    return {
                        ...entry,
                        sNo: index + 1,
                        debit: debitAmount,
                        credit: creditAmount,
                        balance: runningBalance
                    };
                });
                
                this.secondaryCustomerLedgerFilter.allLedgerData = processedData;
                this.secondaryCustomerLedgerFilter.originalLedgerData = processedData;
                this.secondaryCustomerLedgerFilter.isDataExisted = processedData.length > 0;
                this.secondaryCustomerLedgerFilter.statusVal = ledgerResult.statusOptions || this.secondaryCustomerLedgerFilter.statusVal;
                
                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error('Error fetching ledger data:', error);
                this.isSubPartLoad = false;
            });
    }

    handleLedgerCustomerChange(event) {
        this.secondaryCustomerLedgerFilter.selectedCustomerId = event.detail.value;
        const customer = this.secondaryCustomerLedgerFilter.customerOptions.find(
            c => c.value === event.detail.value
        );
        this.secondaryCustomerLedgerFilter.selectedCustomerName = customer ? customer.label : '';
        this.secondaryCustomerLedgerFilter.srchVal = '';
        this.fetchLedgerData();
    }

    handleLedgerFromDateChange(event) {
        this.secondaryCustomerLedgerFilter.fromDate = event.target.value;
        this.secondaryCustomerLedgerFilter.srchVal = '';
        this.fetchLedgerData();
    }

    handleLedgerToDateChange(event) {
        this.secondaryCustomerLedgerFilter.toDate = event.target.value;
        this.secondaryCustomerLedgerFilter.srchVal = '';
        this.fetchLedgerData();
    }

    handleLedgerStatusChange(event) {
        this.secondaryCustomerLedgerFilter.status = event.target.value;
        this.secondaryCustomerLedgerFilter.srchVal = '';
        this.fetchLedgerData();
    }

    handleLedgerSearch(event) {
        const txt = event.target.value;
        console.log('Ledger Search Value: ' + txt);

        this.secondaryCustomerLedgerFilter = { ...this.secondaryCustomerLedgerFilter, srchVal: txt };

        if (txt.length > 0) {
            const dataUpdate = this.secondaryCustomerLedgerFilter.originalLedgerData.filter(rec =>
                (rec.transactionNo && rec.transactionNo.toLowerCase().includes(txt.toLowerCase())) ||
                (rec.description && rec.description.toLowerCase().includes(txt.toLowerCase())) ||
                (rec.referenceNo && rec.referenceNo.toLowerCase().includes(txt.toLowerCase()))
            );
            this.secondaryCustomerLedgerFilter = {
                ...this.secondaryCustomerLedgerFilter,
                allLedgerData: dataUpdate,
                isDataExisted: dataUpdate.length !== 0
            };
        } else {
            this.secondaryCustomerLedgerFilter = {
                ...this.secondaryCustomerLedgerFilter,
                allLedgerData: this.secondaryCustomerLedgerFilter.originalLedgerData,
                isDataExisted: this.secondaryCustomerLedgerFilter.originalLedgerData.length !== 0 ? true : false
            };
        }
    }

    downloadLedgerPdf() {
        console.log('Download Ledger PDF');
        // TODO: Implement PDF download functionality
    }

    exportLedgerCsv() {
        console.log('Export Ledger to CSV');
        // TODO: Implement CSV export functionality
    }

    printLedger() {
        console.log('Print Ledger');
        // TODO: Implement print functionality
    }


    /**------Order Data------**/
    getOrderData() {
        const today = new Date();
        const firstDate = new Date(today.getFullYear(), today.getMonth(), 1);
        const lastDate = new Date(today.getFullYear(), today.getMonth() + 1, 0);
        const formatDate = (date) => date.toLocaleDateString('en-CA');
        this.ordFilter.fromDate = formatDate(firstDate);
        this.ordFilter.toDate = formatDate(lastDate);
        this.ordFilter.status = 'All';
        this.ordFilter.orderType = this.selectedTab == 'Secondary Orders' ? 'Dealer' : 'Distributor';
        this.OrderData();
    }

    getSecoundaryOrderData() {
        const today = new Date();
        const firstDate = new Date(today.getFullYear(), today.getMonth(), 1);
        const lastDate = new Date(today.getFullYear(), today.getMonth() + 1, 0);
        const formatDate = (date) => date.toLocaleDateString('en-CA');
        this.ordFilter.fromDate = formatDate(firstDate);
        this.ordFilter.toDate = formatDate(lastDate);
        this.ordFilter.status = 'Invoice Pending';
        this.ordFilter.orderType = 'Dealer';
        this.secoundaryOrderData();
    }
    secoundaryOrderData() {
        this.isSubPartLoad = true;
        const { status, fromDate, toDate, orderType } = this.ordFilter;
        SEC_ORD_DATA({
            status: status,
            frmDate: fromDate,
            toDate: toDate,
            orderType: orderType
        })
            .then(result => {
                console.log('result.TotalOrderData' + result.TotalOrderData);
                this.ordFilter.allordData = this.addRowIndex(result.TotalOrderData);
                this.ordFilter.originalOrdData = this.addRowIndex(result.TotalOrderData);
                this.ordFilter.isOrderDataExisted = this.ordFilter.allordData.length != 0 ? true : false;
                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error(error);
                this.isSubPartLoad = false;
            });
    }
    OrderData() {

        this.isSubPartLoad = true;
        const { status, fromDate, toDate, orderType } = this.ordFilter;
        ORD_DATA({
            status: status,
            frmDate: fromDate,
            toDate: toDate,
            orderType: orderType
        })
            .then(result => {
                // Ensure unique orders by orderId
                const uniqueOrders = [];
                const orderIds = new Set();
                result.TotalOrderData.forEach(order => {
                    if (!orderIds.has(order.orderId)) {
                        orderIds.add(order.orderId);
                        uniqueOrders.push(order);
                    } else {
                        console.warn('Duplicate order detected in Apex response: ' + order.orderId);
                    }
                });

                //this.ordFilter.statusVal = result.statusOptions;
                this.ordFilter.allordData = this.addRowIndex(uniqueOrders);
                this.customerNameWithCode = result.customerNameWithCode;
                this.ordFilter.originalOrdData = this.addRowIndex(uniqueOrders);
                this.ordFilter.isOrderDataExisted = uniqueOrders.length !== 0;
                this.isSubPartLoad = false;
                console.log('Processed Orders in LWC: ', uniqueOrders.length);
            })
            .catch(error => {
                console.error('Error fetching orders: ', error);
                this.isSubPartLoad = false;
            });
    }
    handleSecondaryOrderStatusChange(event) {
        this.ordFilter.status = event.detail.value;
        // Reapply filter logic based on the selected status
        this.secoundaryOrderData();
    }

    get isdableSecondaryOrderbutton() {
        return this.ordFilter?.status === 'Fully Invoiced';
    }
    get secondaryOrderButtonClass() {
        return this.isdableSecondaryOrderbutton
            ? 'actionButton disabledButton'
            : 'actionButton';
    }

    // Handle filter changes
    handleOrdChange(event) {
        this.ordFilter.srchVal = '';
        this.ordFilter[event.target.name] = event.target.value;
        this.OrderData();
    }

    // Handle secondary filter changes (if applicable)
    handleSecOrdChange(event) {
        this.ordFilter.srchVal = '';
        this.ordFilter[event.target.name] = event.target.value;
        this.secoundaryOrderData();
    }

    // Handle search
    handleOrdSerch(event) {
        const txt = event.target.value;
        console.log('Searched Value: ' + txt);

        this.ordFilter = { ...this.ordFilter, srchVal: txt };

        if (txt && txt.length > 0) {
            // Filter data based on search text
            const filteredData = this.ordFilter.originalOrdData.filter(ord =>
                (ord.orderNo && ord.orderNo.toLowerCase().includes(txt.toLowerCase())) ||
                (ord.customerName && ord.customerName.toLowerCase().includes(txt.toLowerCase()))
            );

            // Remove duplicates + add rowIndex
            const uniqueOrders = [];
            const orderIds = new Set();

            filteredData.forEach((order, index) => {
                if (!orderIds.has(order.orderId)) {
                    orderIds.add(order.orderId);
                    uniqueOrders.push({
                        ...order,
                        rowIndex: uniqueOrders.length + 1
                    });
                }
            });


            this.ordFilter = {
                ...this.ordFilter,
                allordData: uniqueOrders,
                isOrderDataExisted: uniqueOrders.length !== 0
            };

        } else {
            // Reset to original data + reassign rowIndex
            const resetData = this.ordFilter.originalOrdData.map((order, index) => ({
                ...order,
                rowIndex: index + 1
            }));

            this.ordFilter = {
                ...this.ordFilter,
                allordData: resetData,
                isOrderDataExisted: resetData.length !== 0
            };
        }
    }

    addRowIndex(data) {
        return data.map((row, index) => {
            return {
                ...row,
                rowIndex: index + 1
            };
        });
    }

    // Call this method after you load or update the order items list
    calculateTotalTax() {
        if (!this.orderItems || this.orderItems.length === 0) {
            this.totalTaxAmount = 0;
            return;
        }

        this.totalTaxAmount = this.orderItems.reduce((acc, item) => {
            const taxAmount = item.Tax_Amount__c ? parseFloat(item.Tax_Amount__c) : 0;
            return acc + taxAmount;
        }, 0);
    }

    // Example: call this after fetching order items from Apex
    handleOrderItemsFetched(items) {
        this.orderItems = items;
        this.calculateTotalTax();
    }

    handleSecondaryOrderNoClick(event) {
        const orderId = event.target.dataset.id;  // Get the Order ID
        const orderNo = event.target.textContent; // Get the Order Number

        if (!orderId) {
            console.error('No order ID found in event target:', event.target);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Invalid order ID. Please try again.',
                    variant: 'error'
                })
            );
            return;
        }

        this.selectedSecondaryOrderId = orderId;
        this.selectedSecondaryOrderNo = orderNo;
        this.isSubPartLoad = true;

        // Fetch Secondary Order Items for the selected Secondary Order ID (pass it as an array)
        getOrderlineItems({ orderId: orderId })  // Pass orderId in an array to match the Apex method signature
            .then(items => {
                console.log('Loaded secondary order items:', JSON.stringify(items));
                this.secondaryOrderItems = items.map(item => ({
                    Id: item.OrderItemId,
                    Product_Name__c: item.ProductName || 'N/A',  // Product Name
                    Quantity__c: item.Quantity || 0,  // Quantity
                    Total_Amount__c: item.TotalAmount || 0,  // Total Amount
                    Tax_Amount__c: item.TaxAmount || 0,  // Tax Amount
                    Tax_Percent__c: item.TaxPercent || 0,  // Tax Percent
                    Unit_price__c: item.UnitPrice || 0  // Unit Price
                }));

                this.secondaryOrderItems = this.addRowIndex(this.secondaryOrderItems);

                this.showSecondaryOrderItems = true; // Show Order Items table
                this.showSecondaryOrders = false; // Hide Secondary Orders table
                this.isSubPartLoad = false; // Stop loading state

                this.hasSecondaryOrderItems = this.secondaryOrderItems.length > 0; // Check if items exist
                console.log('showSecondaryOrderItems:', this.showSecondaryOrderItems);
                console.log('🧾 secondaryOrderItems length:', this.secondaryOrderItems.length);
            })
            .catch(error => {
                console.error('Error loading secondary order items:', error);
                this.isSubPartLoad = false;
            });
    }

    // Close the Secondary Order Items table and go back to Secondary Orders
    closeSecondaryOrderItems() {
        this.showSecondaryOrders = true; // Show Secondary Orders table
        this.showSecondaryOrderItems = false; // Hide Secondary Order Items table
        this.selectedSecondaryOrderId = ''; // Clear the selected Order ID
        this.secondaryOrderItems = []; // Clear the Secondary Order Items
        this.selectedSecondaryOrderNo = ''; // Clear the selected Order No
    }

    get hasSecondaryOrderItems() {
        console.log(this.secondaryOrderItems.length > 0);
        return this.secondaryOrderItems.length > 0;
    }


    /** ---Invoice Data -----**/
    getInvoiceData() {
        const today = new Date();
        const firstDate = new Date(today.getFullYear(), today.getMonth(), 1);
        const lastDate = new Date(today.getFullYear(), today.getMonth() + 1, 0);
        const formatDate = (date) => date.toLocaleDateString('en-CA');
        this.InvFilter.fromDate = formatDate(firstDate);
        this.InvFilter.toDate = formatDate(lastDate);
        this.InvFilter.status = 'GRN Pending';
        this.invoiceData();
    }
    invoiceData() {
        this.isSubPartLoad = true;
        const { status, fromDate, toDate } = this.InvFilter;
        allInvoiceData({
            status: status,
            frmDate: fromDate,
            toDate: toDate
        })
            .then(result => {
                this.InvFilter.statusVal = result.statusOptions;
                this.InvFilter.allInvData = this.addRowIndex(result.TotalInvoiceData);
                this.InvFilter.originalInvData = this.addRowIndex(result.TotalInvoiceData);
                this.InvFilter.isInvoiceDataExisted = result.TotalInvoiceData.length > 0;

                // Hide invoice items table on new load
                this.showInvoiceItems = false;
                this.invoiceItems = [];
                this.selectedInvoiceId = null;

                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error(error);
                this.isSubPartLoad = false;
            });
    }

    handleInvChange(event) {
        this.InvFilter[event.target.name] = event.target.value;
        this.InvFilter.srchVal = '';
        this.invoiceData();
    }
    handleInvSerch(event) {

        const txt = (event.target.value || '').trim();
        console.log('Searched Value: ' + txt);

        // Trigger reactivity
        this.InvFilter = { ...this.InvFilter, srchVal: txt };

        const sourceData = this.InvFilter.originalInvData || [];

        if (txt.length > 0) {

            const searchKey = txt.toLowerCase();

            const dataUpdate = sourceData.filter(rec => {

                const acc = (rec.accName || '').toLowerCase();
                const inv = (rec.invoiceNo || '').toLowerCase();
                const ord = (rec.orderId || '').toLowerCase();

                return (
                    acc.includes(searchKey) ||
                    inv.includes(searchKey) ||
                    ord.includes(searchKey)
                );
            });

            const indexedData = this.addRowIndex(dataUpdate);

            this.InvFilter = {
                ...this.InvFilter,
                allInvData: indexedData,
                isInvoiceDataExisted: dataUpdate.length > 0
            };

        } else {

            const indexedData =
                this.addRowIndex(sourceData);

            this.InvFilter = {
                ...this.InvFilter,
                allInvData: indexedData,
                isInvoiceDataExisted: sourceData.length > 0
            };
        }
    }


    handleInvoiceClick(event) {
        const invoiceId = event.target.dataset.id;
        const invoiceName = event.target.textContent;
        if (!invoiceId) return;

        this.selectedInvoiceId = invoiceName;
        this.isSubPartLoad = true;
        this.showPrimaryInvoices = false;

        this.showInvoiceItems = true; // show loading if needed
        getInvoiceItems({ invoiceId })
            .then(items => {
                this.invoiceItems = this.addRowIndex(items);
                this.hasInvoiceItems = this.invoiceItems.length > 0;
                this.showInvoiceItems = true;
                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error('Error loading invoice items', error);
                this.invoiceItems = [];
                this.showInvoiceItems = false;
                this.isSubPartLoad = false;
            });
    }

    get noInvoiceItems() {
        return this.invoiceItems && this.invoiceItems.length === 0;
    }


    /**------Primary Returns-----**/
    get hasPrimaryReturnItems() {
        return this.primaryReturnItems && this.primaryReturnItems.length > 0;
    }


    handlePrimaryReturnChange(event) {
        const { name, value } = event.target;

        // Ensure the date is in 'yyyy-mm-dd' format
        if (name === 'fromDate' || name === 'toDate') {
            this.primaryReturnFilter[name] = value;
        }

        this.primaryReturnFilter.srchVal = ''; // Clear search filter
        this.loadPrimaryReturns(); // Fetch primary returns data with the new date filter
    }

    // Method to handle the search filter for Primary Returns
    handlePrimaryReturnSerch(event) {
        const txt = event.target.value;
        console.log('Searched Value: ' + txt);

        // Create a shallow copy to trigger reactivity
        this.primaryReturnFilter = { ...this.primaryReturnFilter, srchVal: txt };

        // Perform search if the text length is greater than 0
        if (txt.length > 0) {
            const dataUpdate = this.primaryReturnFilter.originalPReturnata.filter(rec =>
                (rec.productName && rec.productName.toLowerCase().includes(txt.toLowerCase())) ||
                (rec.primaryReturnNo && rec.primaryReturnNo.toLowerCase().includes(txt.toLowerCase()))
            );
            const indexedData = this.addRowIndex(dataUpdate);
            this.primaryReturnFilter = {
                ...this.primaryReturnFilter,
                allPReturnData: indexedData,
                isDataExisted: dataUpdate.length !== 0
            };
        } else {
            const indexedData = this.addRowIndex(this.primaryReturnFilter.originalPReturnata);
            // Reset to original data when search text is empty
            this.primaryReturnFilter = {
                ...this.primaryReturnFilter,
                allPReturnData: indexedData,
                isDataExisted: this.primaryReturnFilter.originalPReturnata.length !== 0 ? true : false
            };
        }
    }

    // Method to fetch Primary Return data based on date range
    getPrimaryReturnData() {
        const today = new Date();
        const firstDate = new Date(today.getFullYear(), today.getMonth(), 1); // First day of the month
        const lastDate = new Date(today.getFullYear(), today.getMonth() + 1, 0); // Last day of the month
        const formatDate = (date) => date.toLocaleDateString('en-CA');  // Format date to 'yyyy-mm-dd'

        // Set date filters
        this.primaryReturnFilter.fromDate = formatDate(firstDate);
        this.primaryReturnFilter.toDate = formatDate(lastDate);

        this.loadPrimaryReturns();
    }

    // Method to fetch Primary Returns data from Apex based on filters
    loadPrimaryReturns() {
        this.isSubPartLoad = true;
        const { fromDate, toDate } = this.primaryReturnFilter;

        // Ensure the dates are properly formatted before passing to Apex
        getPrimaryReturns({ frmDate: fromDate, toDate })
            .then(results => {
                console.log('Primary Returns loaded:', results);
                this.primaryReturnFilter.allPReturnData = this.addRowIndex(results);
                this.primaryReturnFilter.originalPReturnata = this.addRowIndex(results);
                this.primaryReturnFilter.isDataExisted = results.length > 0;
                this.isSubPartLoad = false;
                this.showPrimaryReturnItems = false;
            })
            .catch(error => {
                console.error(error);
                this.isSubPartLoad = false;
            });
    }

    // Handle click on Return No. to load return items
    handleReturnNoClick(event) {
        const returnId = event.target.dataset.id;
        if (!returnId) return;

        this.selectedPrimaryReturnId = returnId;
        this.selectedPrimaryReturnNo = event.target.textContent;

        this.isSubPartLoad = true;
        getPrimaryReturnItems({ primaryReturnId: returnId })
            .then(items => {
                console.log('Loaded primary return items:', items);
                this.primaryReturnItems = this.addRowIndex(items);;
                this.showPrimaryReturnItems = true;
                this.isSubPartLoad = false;
                this.showPrimaryReturn = false; // Hide returns list while showing items
            })
            .catch(error => {
                console.error(error);
                this.primaryReturnItems = [];
                this.showPrimaryReturnItems = false;
                this.isSubPartLoad = false;
            });
    }

    // Close return items and show returns list again
    closePrimaryReturnItems() {
        this.showPrimaryReturnItems = false;
        this.primaryReturnItems = [];
        this.selectedPrimaryReturnId = null;
        this.selectedPrimaryReturnNo = '';
        this.showPrimaryReturn = true;
    }


    /**----Primary Payments-------**/
    getPrimaryPaymemtsData() {
        const today = new Date();
        const firstDate = new Date(today.getFullYear(), today.getMonth(), 1);
        const lastDate = new Date(today.getFullYear(), today.getMonth() + 1, 0);
        const formatDate = (date) => date.toLocaleDateString('en-CA');
        this.primaryPaymentsFilter.fromDate = formatDate(firstDate);
        this.primaryPaymentsFilter.toDate = formatDate(lastDate);
        this.PrimaryPaymentsData();
    }

    PrimaryPaymentsData() {
        this.isSubPartLoad = true;
        const { fromDate, toDate } = this.primaryPaymentsFilter;
        PAY_Rec_DATA({
            frmDate: fromDate,
            toDate: toDate
        })
            .then(result => {
                const data = result.TotalPaymentData;

                // 1. Build map of receiptId => total amount
                const receiptTotals = {};
                data.forEach(item => {
                    const receiptId = item.paymenetId;
                    const itemAmount = parseFloat(item.Amount) || 0;
                    if (receiptTotals[receiptId]) {
                        receiptTotals[receiptId] += itemAmount;
                    } else {
                        receiptTotals[receiptId] = itemAmount;
                    }
                });

                // 2. Assign total amount to each item as 'receiptTotalAmount'
                const dataWithTotals = data.map(item => ({
                    ...item,
                    receiptTotalAmount: receiptTotals[item.paymenetId] || 0
                }));

                // 3. Update state with modified data
                this.primaryPaymentsFilter.allPaymentData = this.addRowIndex(dataWithTotals);
                this.primaryPaymentsFilter.isDataExisted = dataWithTotals.length > 0;
                this.primaryPaymentsFilter.originalPaymentData = this.addRowIndex(dataWithTotals);
                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error(error);
                this.isSubPartLoad = false;
            });
    }

    handlePrimaryPaymentsChange(event) {
        this.primaryPaymentsFilter[event.target.name] = event.target.value;
        this.primaryPaymentsFilter.srchVal = '';
        this.PrimaryPaymentsData();
    }

    handlePrimaryPaymentsSearch(event) {
        const txt = event.target.value.toLowerCase();
        this.primaryPaymentsFilter.srchVal = txt;

        if (txt.length > 0) {
            const filtered = this.primaryPaymentsFilter.originalPaymentData.filter(rec =>
                (rec.paymenetNo && rec.paymenetNo.toLowerCase().includes(txt)) ||
                (rec.invoiceNo && rec.invoiceNo.toLowerCase().includes(txt))
            );
            this.primaryPaymentsFilter.allPaymentData = this.addRowIndex(filtered);
            this.primaryPaymentsFilter.isDataExisted = filtered.length > 0;
        } else {
            this.primaryPaymentsFilter.allPaymentData = this.addRowIndex(this.primaryPaymentsFilter.originalPaymentData);
            this.primaryPaymentsFilter.isDataExisted = this.primaryPaymentsFilter.originalPaymentData.length > 0;
        }
    }

    /** 
     * When Payment Receipt No. clicked — show receipt detail
     */
    handlePaymentReceiptClick(event) {
        const receiptId = event.target.dataset.id;
        if (!receiptId) return;

        this.isSubPartLoad = true;
        this.showPrimaryPayments = false;

        Promise.all([
            getPaymentReceiptDetails({ receiptId }),
            getReceiptItems({ receiptId })
        ])
            .then(([receipt, items]) => {
                //alert(JSON.stringify(receipt));
                //alert(JSON.stringify(items));
                this.selectedReceipt = receipt;
                this.selectedReceiptItems = this.addRowIndex(items);
                this.hasReceiptItems = items.length > 0;
                this.showReceiptItems = true;
                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error('Failed to load payment receipt details:', error);
                this.showToast('Error', 'Failed to load payment receipt details', 'error');
                this.isSubPartLoad = false;
                this.showPrimaryPayments = true;
            });
    }

    /** 
     * Back button from receipt detail to list
     */
    closeReceiptItems() {
        this.showReceiptItems = false;
        this.selectedReceipt = null;
        this.selectedReceiptItems = [];
        this.hasReceiptItems = false;
        this.showPrimaryPayments = true;
    }
    /**-----------GRN---------**/
    // Load initial GRN date filters and load GRN list (distinct GRNs)

    getGRNsData() {
        const today = new Date();
        const firstDate = new Date(today.getFullYear(), today.getMonth(), 1);
        const lastDate = new Date(today.getFullYear(), today.getMonth() + 1, 0);
        const formatDate = (date) => date.toLocaleDateString('en-CA');
        this.GRNFilter.fromDate = formatDate(firstDate);
        this.GRNFilter.toDate = formatDate(lastDate);
        this.loadGRNList();
    }

    // Fetch distinct GRN list from Apex getGRNList method
    handleGRNDateChange(event) {
        const { name, value } = event.target;

        // Store the date in 'yyyy-mm-dd' format
        if (name === 'fromDate' || name === 'toDate') {
            this.GRNFilter[name] = value;
        }

        // Fetch GRN list based on updated dates
        this.loadGRNList();
    }

    // Method to handle Search for GRN by GRN Name or Invoice__c
    handleGRNSearch(event) {
        const txt = event.target.value.toLowerCase();
        this.GRNFilter.srchVal = txt;

        // Search the GRN list based on search value
        if (txt.length > 0) {
            const filtered = this.GRNFilter.originalGRNList.filter(grn =>
                (grn.Name && grn.Name.toLowerCase().includes(txt)) ||
                (grn.Invoice__c && grn.Invoice__c.toLowerCase().includes(txt))
            );
            this.GRNFilter.allGRNList = this.addRowIndex(filtered);
            this.GRNFilter.isListDataExisted = filtered.length > 0;
        } else {
            this.GRNFilter.allGRNList = this.addRowIndex(this.GRNFilter.originalGRNList);
            this.GRNFilter.isListDataExisted = this.GRNFilter.originalGRNList.length > 0;
        }
    }

    // Method to Load GRN List based on Date Range
    loadGRNList() {
        this.isSubPartLoad = true;
        const { fromDate, toDate } = this.GRNFilter;

        // Ensure the dates are correctly formatted and passed to Apex
        getGRNList({ frmDate: fromDate, toDate })
            .then(result => {
                this.GRNFilter.allGRNList = this.addRowIndex(result);
                this.GRNFilter.originalGRNList = this.addRowIndex(result);
                this.GRNFilter.isListDataExisted = result.length > 0;
                this.isSubPartLoad = false;
                this.showGrnItems = false; // Hide GRN Items view
                this.selectedGrnId = null;
                this.selectedGrnName = '';
                this.GRNFilter.allGRNItems = [];
                this.GRNFilter.isItemsDataExisted = false;
            })
            .catch(error => {
                console.error(error);
                this.isSubPartLoad = false;
            });
    }

    // Method to handle Click on GRN Name to Load Items for that GRN
    handleGrnNameClick(event) {
        const grnName = event.target.textContent;
        const grnId = event.target.dataset.id;

        if (!grnId) return;

        this.selectedGrnId = grnId;
        this.selectedGrnName = grnName;
        this.isSubPartLoad = true;
        this.GRNFilter.grnImages = [];

        // Fetch GRN items and images in parallel
        Promise.all([
            getGRNItems({ grnId: grnId }),
            getGRNImages({ grnId: grnId })
        ])
            .then(([items, images]) => {
                this.GRNFilter.allGRNItems = this.addRowIndex(items);
                this.GRNFilter.isItemsDataExisted = items.length > 0;
                this.GRNFilter.grnImages = (images || []).map(img => ({
                    id: img.Id,
                    name: img.Name,
                    url: img.DistributionPublicUrl
                }));
                this.showGrnItems = true;
                this.showPrimaryGrn = false;
                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error(error);
                this.isSubPartLoad = false;
                this.GRNFilter.allGRNItems = [];
                this.GRNFilter.isItemsDataExisted = false;
                this.GRNFilter.grnImages = [];
                this.showGrnItems = false;
            });
    }

    // Method to Close GRN Items View and Show GRN List
    closeGrnItems() {
        this.showGrnItems = false;
        this.showPrimaryGrn = true;
        this.selectedGrnName = '';
        this.GRNFilter.allGRNItems = [];
        this.GRNFilter.isItemsDataExisted = false;
    }

    /**----------Claim---------**/
    getClaimData() {
        console.log('Get');
        const today = new Date();
        const firstDate = new Date(today.getFullYear(), today.getMonth(), 1);
        const lastDate = new Date(today.getFullYear(), today.getMonth() + 1, 0);
        const formatDate = (date) => date.toLocaleDateString('en-CA');
        this.claimFilter.fromDate = formatDate(firstDate);
        this.claimFilter.toDate = formatDate(lastDate);
        this.claimFilter.status = '';
        this.claimData();

    }
    claimData() {
        this.isSubPartLoad = true;
        const { fromDate, toDate, status } = this.claimFilter;
        CLAIM_DATA({
            frmDate: fromDate,
            toDate: toDate,
            status: status
        })
            .then(result => {
                console.log('Data' + result.totalClaimData);
                this.claimFilter.allClaimData = this.addRowIndex(result.totalClaimData);
                this.claimFilter.statusVal = result.statusOptions;
                this.claimFilter.isDataExisted = this.claimFilter.allClaimData.length != 0 ? true : false;
                this.claimFilter.originalClaimData = this.addRowIndex(result.totalClaimData);
                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error(error);
                this.isSubPartLoad = false;
            });
    }
    handleClaimhange(event) {
        this.claimFilter[event.target.name] = event.target.value;
        this.claimFilter.srchVal = '';
        this.claimData();
    }
    handleClaimSearch(event) {
        const txt = event.target.value;
        console.log('Searched Value: ' + txt);

        // Create a shallow copy to trigger reactivity
        this.claimFilter = { ...this.claimFilter, srchVal: txt };

        if (txt.length > 0) {
            const dataUpdate = this.claimFilter.originalClaimData.filter(rec =>
                (rec.description && rec.description.toLowerCase().includes(txt.toLowerCase())) ||
                (rec.claimName && rec.claimName.toLowerCase().includes(txt.toLowerCase()))
            );
            const indexedData = this.addRowIndex(dataUpdate);
            this.claimFilter = {
                ...this.claimFilter,
                allClaimData: indexedData,
                isDataExisted: dataUpdate.length !== 0
            };
        } else {

            const indexedData = this.addRowIndex(this.claimFilter.originalClaimData);
            this.claimFilter = {
                ...this.claimFilter,
                allClaimData: indexedData,
                isDataExisted: this.claimFilter.originalClaimData.length !== 0 ? true : false
            };
        }
    }

    /**-------Stock-----------**/
    getStockData() {
        this.isSubPartLoad = true;
        this.stockFilter.selectedCategory = '';
        const { selectedCategory } = this.stockFilter;
        STOCK_DATA({
            productCategory: selectedCategory,
        })
            .then(result => {
                console.log('Data' + result.totalDistributorStockData);
                this.stockFilter.allStockData = result.totalDistributorStockData;
                this.stockFilter.isDataExisted = this.stockFilter.allStockData.length != 0 ? true : false;
                this.stockFilter.originalStockData = result.totalDistributorStockData;
                this.stockFilter.productCategories = this.populateOptions(result?.productCategories, 'Name', 'Id');
                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error(error);
                this.isSubPartLoad = false;
            });
    }
    handleStockChange(event) {
        this.stockFilter[event.target.name] = event.target.value;
        this.stockFilter.srchVal = '';
        this.getStockData();
    }
    handleStockSearch(event) {
        const txt = event.target.value;
        console.log('Searched Value: ' + txt);

        // Create a shallow copy to trigger reactivity
        this.stockFilter = { ...this.stockFilter, srchVal: txt };

        if (txt.length > 0) {
            const dataUpdate = this.stockFilter.originalStockData.filter(rec =>
                (rec.productName && rec.productName.toLowerCase().includes(txt.toLowerCase())) ||
                (rec.stockName && rec.stockName.toLowerCase().includes(txt.toLowerCase()))
            );
            this.stockFilter = {
                ...this.stockFilter,
                allStockData: dataUpdate,
                isDataExisted: dataUpdate.length !== 0
            };
        } else {
            this.stockFilter = {
                ...this.stockFilter,
                allStockData: this.stockFilter.originalStockData,
                isDataExisted: this.stockFilter.originalStockData.length !== 0 ? true : false
            };
        }
    }

    downloadStockData() {
        const data = this.stockFilter.allStockData || [];

        if (data.length === 0) {
            this.showToast('No Data Found', 'No stock data to export.', 'error');
            return;
        }

        const headers = [
            'SKU', 'GRN Sale Qty', 'GRN Non-Sale Qty', 'Secondary Invoice Qty',
            'Primary Return Qty', 'Secondary Return Sale Qty', 'Secondary Return Non-Sale Qty',
            'Sale → Non-Sale Qty', 'Non-Sale → Sale Qty', 'Written Off Qty',
            'Available Sale Qty', 'Available Non-Sale Qty', 'Unit Price', 'Total Amount'
        ];

        const rows = data.map(row => [
            row.productName || '',
            row.GRNSaleableQuantity || 0,
            row.GRNNonSaleableQuantity || 0,
            row.secoundryInvoiceQty || 0,
            row.primaryReturnQty || 0,
            row.SecondaryReturnSaleableQuantity || 0,
            row.SecondaryReturnNonSaleableQuantity || 0,
            row.salebletoNonSaleableQty || 0,
            row.nonSaleabletoSaleableQty || 0,
            row.writtenOffQty || 0,
            row.availableSaleableQuantity || 0,
            row.availableNonSaleableQuantity || 0,
            row.unitPrice || 0,
            row.totalAmount || 0
        ]);

        const XLSX = window.XLSX;

        if (XLSX) {
            try {
                const ws = XLSX.utils.aoa_to_sheet([headers, ...rows]);
                ws['!cols'] = [
                    { wch: 30 }, { wch: 12 }, { wch: 14 }, { wch: 18 },
                    { wch: 14 }, { wch: 20 }, { wch: 22 },
                    { wch: 18 }, { wch: 18 }, { wch: 12 },
                    { wch: 14 }, { wch: 16 }, { wch: 10 }, { wch: 12 }
                ];
                const wb = XLSX.utils.book_new();
                XLSX.utils.book_append_sheet(wb, ws, 'Stocks');
                XLSX.writeFile(wb, `Stocks_${new Date().toISOString().slice(0, 10)}.xlsx`);
            } catch (error) {
                console.error('XLSX Export Error:', error);
                this.showToast('Export Error', 'Failed to export Excel: ' + error.message, 'error');
            }
        } else {
            let csvContent = 'data:text/csv;charset=utf-8,' + headers.join(',') + '\n';
            rows.forEach(row => {
                csvContent += row.join(',') + '\n';
            });
            const encodedUri = encodeURI(csvContent);
            const link = document.createElement('a');
            link.setAttribute('href', encodedUri);
            link.setAttribute('download', `Stocks_${new Date().toISOString().slice(0, 10)}.csv`);
            link.click();
        }
    }

    /**-----Credit Note-----**/
    getCreditData() {
        const today = new Date();
        const firstDate = new Date(today.getFullYear(), today.getMonth(), 1);
        const lastDate = new Date(today.getFullYear(), today.getMonth() + 1, 0);
        const formatDate = (date) => date.toLocaleDateString('en-CA');
        this.creditNoteFilter.fromDate = formatDate(firstDate);
        this.creditNoteFilter.toDate = formatDate(lastDate);
        this.creditNoteFilter.status = '';
        this.creditData();
    }
    creditData() {
        this.isSubPartLoad = true;
        const { fromDate, toDate, status } = this.creditNoteFilter;
        CREDIT_NOTE_DATA({
            frmDate: fromDate,
            toDate: toDate,
            status: status
        })
            .then(result => {
                console.log('Data' + result.totalCreditNoteData);
                this.creditNoteFilter.allCreditNoteData = result.totalCreditNoteData;
                this.creditNoteFilter.isDataExisted = this.creditNoteFilter.allCreditNoteData.length != 0 ? true : false;
                this.creditNoteFilter.originalCreditNoteData = result.totalCreditNoteData;
                this.creditNoteFilter.statusVal = result.statusOptions;
                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error(error);
                this.isSubPartLoad = false;
            });
    }
    handleCreditChange(event) {
        this.creditNoteFilter[event.target.name] = event.target.value;
        this.creditNoteFilter.srchVal = '';
        this.creditData();
    }
    handleCreditSearch(event) {
        const txt = event.target.value;
        console.log('Searched Value: ' + txt);

        // Create a shallow copy to trigger reactivity
        this.creditNoteFilter = { ...this.creditNoteFilter, srchVal: txt };

        if (txt.length > 0) {
            const dataUpdate = this.creditNoteFilter.originalCreditNoteData.filter(rec =>
                (rec.claimNo && rec.claimNo.toLowerCase().includes(txt.toLowerCase())) ||
                (rec.primaryReturnNo && rec.primaryReturnNo.toLowerCase().includes(txt.toLowerCase()))
            );
            this.creditNoteFilter = {
                ...this.creditNoteFilter,
                allCreditNoteData: dataUpdate,
                isDataExisted: dataUpdate.length !== 0
            };
        } else {
            this.creditNoteFilter = {
                ...this.creditNoteFilter,
                allCreditNoteData: this.creditNoteFilter.originalCreditNoteData,
                isDataExisted: this.creditNoteFilter.originalCreditNoteData.length !== 0 ? true : false
            };
        }
    }

    /** ---Secoundary Invoice Data -----**/
    getSecoundaryInvoiceData() {
        const today = new Date();
        const firstDate = new Date(today.getFullYear(), today.getMonth(), 1);
        const lastDate = new Date(today.getFullYear(), today.getMonth() + 1, 0);
        const formatDate = (date) => date.toLocaleDateString('en-CA');
        this.secInvFilter.fromDate = formatDate(firstDate);
        this.secInvFilter.toDate = formatDate(lastDate);
        this.secInvFilter.status = '';
        this.secoundaryInvoiceData();
    }
    secoundaryInvoiceData() {
        console.log('entered');
        this.isSubPartLoad = true;
        const { status, fromDate, toDate } = this.secInvFilter;
        SEC_INV_DATA({
            status: status,
            frmDate: fromDate,
            toDate: toDate
        })
            .then(result => {
                console.log('Data' + result.totalSecoundaryInvoiceData);
                this.secInvFilter.statusVal = result.statusOptions;
                this.secInvFilter.allSecInvData = this.addRowIndex(result.totalSecoundaryInvoiceData);
                this.secInvFilter.isDataExisted = this.secInvFilter.allSecInvData.length != 0 ? true : false;
                this.secInvFilter.originalSecInvData = this.addRowIndex(result.totalSecoundaryInvoiceData);
                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error(error);
                this.isSubPartLoad = false;
            });
    }
    handleSecInvChange(event) {
        this.secInvFilter[event.target.name] = event.target.value;
        this.secInvFilter.srchVal = '';
        this.secoundaryInvoiceData();
    }
    handleSecInvSerch(event) {
        const txt = event.target.value;
        console.log('Searched Value: ' + txt);

        // Create a shallow copy to trigger reactivity
        this.secInvFilter = { ...this.secInvFilter, srchVal: txt };

        if (txt.length > 0) {
            const dataUpdate = this.secInvFilter.originalSecInvData.filter(rec =>
                (rec.accName && rec.accName.toLowerCase().includes(txt.toLowerCase())) ||
                (rec.name && rec.name.toLowerCase().includes(txt.toLowerCase()))
            );
            const indexedData = this.addRowIndex(dataUpdate);
            this.secInvFilter = {
                ...this.secInvFilter,
                allSecInvData: indexedData,
                isDataExisted: dataUpdate.length !== 0
            };
        } else {
            const indexedData = this.addRowIndex(this.secInvFilter.originalSecInvData);
            this.secInvFilter = {
                ...this.secInvFilter,
                allSecInvData: indexedData,
                isDataExisted: this.secInvFilter.originalSecInvData.length !== 0 ? true : false
            };
        }
    }



    //newly added
    handleSecondaryInvoiceNoClick(event) {
        const invoiceId = event.currentTarget.dataset.id;
        console.log(invoiceId); // Get Invoice ID
        const invoiceNo = event.currentTarget.textContent || event.currentTarget.innerText; // Get Invoice Name
        this.invoiceIdToDownloadPdf = invoiceId;
        if (!invoiceId) {
            console.error('No invoice ID found in event target:', event.currentTarget);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Invalid invoice ID. Please try again.',
                    variant: 'error'
                })
            );
            return;
        }

        this.selectedSecondaryInvoiceId = invoiceId;
        this.selectedSecondaryInvoiceNo = invoiceNo;
        this.isSubPartLoad = true;

        console.log('Fetching items for invoiceId:', invoiceId);

        getSecondaryInvoiceItems({ invoiceId: invoiceId })
            .then(items => {
                console.log('Loaded secondary invoice items:', JSON.stringify(items));
                this.secondaryInvoiceItems = items.map(item => ({
                    Id: item.Id,
                    Product__r: item.Product__r || { Name: 'N/A' },
                    Quantity__c: item.Quantity__c || 0,
                    Unit_Price__c: item.Unit_Price__c || 0,
                    Tax_Percent__c: item.Tax_Percent__c || 0,
                    Tax_Amount__c: item.Tax_Amount__c || 0,
                    Total_Amount__c: item.Total_Amount__c || 0
                }));

                this.secondaryInvoiceItems = this.addRowIndex(this.secondaryInvoiceItems);

                this.hasSecondaryInvoiceItems = this.secondaryInvoiceItems.length > 0;
                this.showSecondaryInvoiceItems = true;
                console.log(this.showSecondaryInvoiceItems);
                this.showSecoundaryInvoices = false; // Corrected variable name

                this.isSubPartLoad = false;

                console.log('State after fetch:', {
                    showSecoundaryInvoices: this.showSecoundaryInvoices,
                    showSecondaryInvoiceItems: this.showSecondaryInvoiceItems,
                    hasSecondaryInvoiceItems: this.hasSecondaryInvoiceItems,
                    secondaryInvoiceItemsLength: this.secondaryInvoiceItems.length
                });
            })
            .catch(error => {
                console.error('Error loading secondary invoice items:', error);
                this.isSubPartLoad = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Failed to load invoice items. Please try again.',
                        variant: 'error'
                    })
                );
            });
    }
    // Handle Back to Invoices
    closeSecondaryInvoiceItems() {
        this.showSecoundaryInvoices = true; // Show Secondary Invoices table
        this.showSecondaryInvoiceItems = false; // Hide Secondary Invoice Items table
        this.selectedSecondaryInvoiceId = null; // Reset selected invoice ID
        this.secondaryInvoiceItems = []; // Clear the invoice items array
        this.selectedSecondaryInvoiceNo = ''; // Reset selected invoice number
        this.hasSecondaryInvoiceItems = false;


    }



    downloadSecondaryInvoicePdf() {
        this.selectedPdfPageSize = 'A4';
        this.showPageSizeModal = true;
    }

    handlePageSizeChange(event) {
        this.selectedPdfPageSize = event.detail.value;
    }

    confirmDownloadSecondaryInvoicePdf() {
        const urlOpen = `${orgUrl}/GTInvoice?id=${this.invoiceIdToDownloadPdf}&pageSize=${this.selectedPdfPageSize}`;
        window.open(urlOpen, "_blank");
        this.showPageSizeModal = false;
    }

    closePageSizeModal() {
        this.showPageSizeModal = false;
    }




    get hasSecondaryInvoiceItems() {
        alert('hi');
        console.log(this.secondaryInvoiceItems.length > 0);
        return this.secondaryInvoiceItems.length > 0;
    }


    /**------Secoundary Returns-----**/
    handleSecoundaryReturnChange(event) {
        this.secoundaryReturnFilter[event.target.name] = event.target.value;
        this.secoundaryReturnFilter.srchVal = '';  // Reset search value
        this.secoundaryReturnData();  // Fetch new data based on filters
    }

    // Handle search changes for secondary returns
    handleSecoundaryReturnSerch(event) {
        const txt = event.target.value;
        this.secoundaryReturnFilter = { ...this.secoundaryReturnFilter, srchVal: txt };

        if (txt.length > 0) {
            const dataUpdate = this.secoundaryReturnFilter.originalSReturnata.filter(rec =>
                (rec.productName && rec.productName.toLowerCase().includes(txt.toLowerCase())) ||
                (rec.secoundaryReturnNo && rec.secoundaryReturnNo.toLowerCase().includes(txt.toLowerCase()))
            );
            const indexedData = this.addRowIndex(dataUpdate);
            this.secoundaryReturnFilter = {
                ...this.secoundaryReturnFilter,
                allSReturnData: indexedData,
                isDataExisted: dataUpdate.length !== 0
            };
        } else {
            const indexedData = this.addRowIndex(this.secoundaryReturnFilter.originalSReturnata);
            this.secoundaryReturnFilter = {
                ...this.secoundaryReturnFilter,
                allSReturnData: indexedData,
                isDataExisted: this.secoundaryReturnFilter.originalSReturnata.length !== 0
            };
        }
    }

    // Method to fetch secondary returns based on filters (date, search)
    getSecoundaryReturnData() {
        const today = new Date();
        const firstDate = new Date(today.getFullYear(), today.getMonth(), 1);
        const lastDate = new Date(today.getFullYear(), today.getMonth() + 1, 0);
        const formatDate = (date) => date.toLocaleDateString('en-CA');
        this.secoundaryReturnFilter.fromDate = formatDate(firstDate);
        this.secoundaryReturnFilter.toDate = formatDate(lastDate);
        this.secoundaryReturnData();
    }

    // Fetch secondary return data from Apex
    secoundaryReturnData() {
        this.isSubPartLoad = true;
        const { fromDate, toDate } = this.secoundaryReturnFilter;
        SRETURN_DATA({
            frmDate: fromDate,
            toDate: toDate
        })
            .then(result => {
                console.log('Data' + result.totalSecoundaryReturnData);
                this.secoundaryReturnFilter.allSReturnData = this.addRowIndex(result.totalSecoundaryReturnData);
                this.secoundaryReturnFilter.isDataExisted = this.secoundaryReturnFilter.allSReturnData.length != 0;
                this.secoundaryReturnFilter.originalSReturnata = this.addRowIndex(result.totalSecoundaryReturnData);
                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error(error);
                this.isSubPartLoad = false;
            });
    }

    showSecReturnDownloadMenu = false;

    toggleSecReturnDownloadMenu() {
        this.showSecReturnDownloadMenu = !this.showSecReturnDownloadMenu;
    }

    _getSecReturnExportData() {
        const data = this.secoundaryReturnFilter.allSReturnData || [];
        if (data.length === 0) {
            this.showToast('No Data Found', 'No secondary returns found for the selected filters.', 'error');
            return null;
        }
        const headers = ['S.No.', 'Return Name', 'Secondary Customer', 'Total Quantity', 'Total Amount', 'Return Date'];
        const rows = data.map(row => [
            row.rowIndex,
            row.secoundaryReturnNo || '',
            row.secondaryCustomer || '',
            row.quantity || 0,
            row.totalAmount || 0,
            row.returnDate || ''
        ]);
        return { headers, rows };
    }

    downloadSecondaryReturnsAsCSV() {
        this.showSecReturnDownloadMenu = false;
        const exportData = this._getSecReturnExportData();
        if (!exportData) return;

        let csvContent = 'data:text/csv;charset=utf-8,' + exportData.headers.join(',') + '\n';
        exportData.rows.forEach(row => {
            csvContent += row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(',') + '\n';
        });

        const encodedUri = encodeURI(csvContent);
        const link = document.createElement('a');
        link.setAttribute('href', encodedUri);
        link.setAttribute('download', 'secondary_returns.csv');
        link.click();
    }

    downloadSecondaryReturnsAsXLSX() {
        this.showSecReturnDownloadMenu = false;
        const exportData = this._getSecReturnExportData();
        if (!exportData) return;

        try {
            const XLSX = window.XLSX;
            if (!XLSX) {
                this.showToast('Export Error', 'Excel library not loaded yet, please retry', 'error');
                return;
            }
            const wsData = [exportData.headers, ...exportData.rows];
            const ws = XLSX.utils.aoa_to_sheet(wsData);
            ws['!cols'] = [{ wch: 6 }, { wch: 16 }, { wch: 25 }, { wch: 14 }, { wch: 14 }, { wch: 14 }];
            const wb = XLSX.utils.book_new();
            XLSX.utils.book_append_sheet(wb, ws, 'Secondary Returns');
            XLSX.writeFile(wb, `secondary_returns_${this.secoundaryReturnFilter.fromDate}_to_${this.secoundaryReturnFilter.toDate}.xlsx`);
        } catch (error) {
            console.error('XLSX Export Error:', error);
            this.showToast('Export Error', 'Failed to export: ' + error.message, 'error');
        }
    }

    downloadSecondaryReturnsAsPDF() {
        this.showSecReturnDownloadMenu = false;
        const exportData = this._getSecReturnExportData();
        if (!exportData) return;

        try {
            const title = `Secondary Returns | ${this.secoundaryReturnFilter.fromDate} to ${this.secoundaryReturnFilter.toDate}`;
            let rowsHtml = '';
            exportData.rows.forEach(row => {
                rowsHtml += `<tr>${row.map(cell => `<td>${cell}</td>`).join('')}</tr>`;
            });

            const printDiv = document.createElement('div');
            printDiv.id = 'lwc-print-overlay';
            printDiv.innerHTML = `
                <style id="lwc-print-style">
                    @media print {
                        @page { margin: 0; padding: 10mm; }
                        body * { visibility: hidden !important; }
                        #lwc-print-overlay, #lwc-print-overlay * { visibility: visible !important; }
                        #lwc-print-overlay { position: absolute !important; top: 0; left: 0; width: 100%; display: block !important; }
                    }
                </style>
                <div id="lwc-print-content">
                    <h2 style="font-size:14px;color:#02323e;margin-bottom:12px;">${title}</h2>
                    <table style="width:100%;border-collapse:collapse;font-size:12px;">
                        <thead>
                            <tr>${exportData.headers.map(h => `<th style="background:#02323e;color:#fff;padding:7px 9px;text-align:left;">${h}</th>`).join('')}</tr>
                        </thead>
                        <tbody>${rowsHtml}</tbody>
                    </table>
                </div>
                <style>
                    #lwc-print-overlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: white; z-index: 99999; padding: 20px; box-sizing: border-box; }
                    #lwc-print-content td { padding: 6px 9px; border-bottom: 1px solid #e0e0e0; }
                </style>`;

            document.body.appendChild(printDiv);
            setTimeout(() => {
                window.print();
                const cleanup = () => {
                    const overlay = document.getElementById('lwc-print-overlay');
                    if (overlay) overlay.parentNode.removeChild(overlay);
                    window.removeEventListener('afterprint', cleanup);
                };
                window.addEventListener('afterprint', cleanup);
                setTimeout(cleanup, 5000);
            }, 100);
        } catch (error) {
            console.error('PDF Export Error:', error);
            this.showToast('Export Error', 'Failed to export PDF: ' + error.message, 'error');
        }
    }

    // Method to handle click on Secondary Return Number and fetch its items
    handleSecondaryReturnNoClick(event) {
        const returnId = event.currentTarget.dataset.id;  // Use currentTarget for consistency
        const returnNo = event.currentTarget.textContent || event.currentTarget.innerText;

        if (!returnId) {
            console.error('No returnId found in event target:', event.currentTarget);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Invalid return ID. Please try again.',
                    variant: 'error'
                })
            );
            return;
        }

        this.selectedSecondaryReturnId = returnId;
        this.selectedSecondaryReturnNo = returnNo;
        this.isSubPartLoad = true;

        getSecondaryReturnItems({ secondaryReturnId: returnId })
            .then(items => {
                console.log('Loaded secondary return items:', JSON.stringify(items));
                this.secondaryReturnItems = items.map((item, index) => ({
                    rowIndex: index + 1,
                    Id: item.Id,
                    SKU__r: item.SKU__r || { Name: 'N/A' },
                    Quantity__c: item.Quantity__c || 0,
                    Reason_For_Return__c: item.Reason_For_Return__c || 'N/A',
                    Unit_Price__c: item.Unit_Price__c || 0,
                    UOM__c: item.UOM__c || 'N/A',
                    Nonsaleable_Quantity__c: item.Nonsaleable_Quantity__c || 0,
                    Saleable_Quantity__c: item.Saleable_Quantity__c || 0
                }));

                // Set the flag to check if items exist
                this.hasSecondaryReturnItems = this.secondaryReturnItems.length > 0;
                this.showSecondaryReturnItems = true;
                this.showSecoundaryReturn = false; // Hide returns list
                console.log('showSecondaryReturnItems:', this.showSecondaryReturnItems);
                console.log('🧾 secondaryReturnItems length:', this.secondaryReturnItems.length);
                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error('Error loading secondary return items:', JSON.stringify(error));
                this.hasSecondaryReturnItems = false;
                this.isSubPartLoad = false;
            });
    }

    // Method to close the Secondary Return Items view and show the return list again
    closeSecondaryReturnItems() {
        this.showSecondaryReturnItems = false;
        this.secondaryReturnItems = [];
        this.selectedSecondaryReturnNo = '';
        this.selectedSecondaryReturnId = null;
        this.showSecoundaryReturn = true;
    }

    downloadSecondaryReturnPdf() {
        const returnId = this.selectedSecondaryReturnId;
        if (!returnId) {
            this.showToast('Error', 'No return selected.', 'error');
            return;
        }
        const url = `${orgUrl}/ReturnPdf?Id=${returnId}`;
        window.open(url, '_blank');
    }

    // Check if there are secondary return items to display
    get hasSecondaryReturnItems() {
        alert('hi');
        console.log(this.secondaryReturnItems.length > 0);
        return this.secondaryReturnItems.length > 0;
    }




    // Handle "Select All" for invoices
    handleSelectAll(event) {
        const isChecked = event.target.checked;
        this.isAllSelected = isChecked;

        // Update all rows with new selection state
        this.InvFilter.allInvData = this.InvFilter.allInvData.map(row => ({
            ...row,
            isSelected: isChecked
        }));

        // Update selectedRows array
        this.selectedRows = isChecked ? [...this.InvFilter.allInvData] : [];

        this.dispatchEvent(new CustomEvent('selectionchange', {
            detail: { selectedOrders: this.selectedOrders }
        }));
    }

    // Handle "Select All" for orders
    toggleSelectAll(event) {
        const isChecked = event.target.checked;
        this.isAllSelected = isChecked;

        this.ordFilter.allordData = this.ordFilter.allordData.map(row => ({
            ...row,
            isSelected: isChecked
        }));

        // Update selectedOrders array if needed
        this.selectedOrders = isChecked ? [...this.ordFilter.allordData] : [];

        this.dispatchEvent(new CustomEvent('selectionchange', {
            detail: { selectedRows: this.selectedRows }
        }));
    }

    // Handle individual row selection
    handleRowSelection(event) {
        const rowId = event.detail.name; // Using name instead of dataset.id
        const isChecked = event.detail.checked;

        // Update the specific row
        this.InvFilter.allInvData = this.InvFilter.allInvData.map(row =>
            row.InvId === rowId ? { ...row, isSelected: isChecked } : row
        );

        // Update selectedRows array
        this.selectedRows = this.InvFilter.allInvData.filter(row => row.isSelected);

        // Update "Select All" checkbox state
        this.isAllSelected = this.selectedRows.length === this.InvFilter.allInvData.length;

        // If using a timeout is necessary for your specific case
        setTimeout(() => {
            this.dispatchEvent(new CustomEvent('selectionchange', {
                detail: { selectedRows: this.selectedRows }
            }));
        }, 0);
    }


    handleCheckboxChange(event) {
        const rowId = event.target.dataset.id;
        const isChecked = event.target.checked;

        // Use map to return a new array with updated isSelected property
        this.ordFilter.allordData = this.ordFilter.allordData.map(row => {
            if (row.orderId === rowId) {
                return { ...row, isSelected: isChecked };
            }
            return row;
        });

        // Update isAllSelected based on the updated data
        this.isAllSelected = this.ordFilter.allordData.every(row => row.isSelected);
    }

    // Generate GRN - Only one invoice allowed
    generateGRN() {
        const selectedInvoices = this.InvFilter.allInvData.filter(row => row.isSelected);
        if (selectedInvoices.length === 0) {
            this.showToast('Error', 'Please select at least one invoice.', 'Error');
            return;
        }
        if (selectedInvoices.length > 1) {
            this.showToast('Error', 'You can select only one invoice to generate GRN.', 'Error');
            return;
        }
        this.GRNData();
    }


    // Make Payment - Multiple invoices allowed

    // Removed duplicate makePaymemt() here (keep the more complete one below)
    closePayment() {
        this.showPaymentModal = false;
        this.paymentItems = [];
    }









    /**-------Helper methods--------**/

    //Genric method to get the picklist values
    populateOptions(dataList, labelField, valueField) {
        const options = dataList?.map(item => ({
            label: item[labelField],
            value: item[valueField]
        })) || [];

        // Add "All" as the first option
        return [{ label: 'All', value: 'All' }, ...options];
    }

    //Navigate to record page
    openRecord(event) {
        const recordId = event.target.dataset.id;

        // Generate URL for the record
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        }).then(url => {
            // Open the record in a new tab
            window.open(url, '_blank');
        });
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
    //Show Toast---------------
    showToast(title, message, variant) {
        const toast = this.template.querySelector('c-custom-toast'); // Query the toast component
        console.log('Custom Toast component:', toast);  // Log the reference

        if (toast) {
            toast.showToast(variant, message); // Show the toast with the correct variant
        } else {
            console.error('Custom Toast component not found!');
        }
    }

    @track showModal = false;

    openPopup() {
        this.showModal = true;
    }

    handleCancelEvent() {
        this.showModal = false;
    }

    handlePayEvent() {

        const paidInvoices = this.selectedInvoices.filter(inv => inv.Status === 'Paid');
        if (paidInvoices.length > 0) {
            const paidNames = paidInvoices.map(inv => inv.name || inv.InvoiceNumber || 'Unknown').join(', ');
            this.showToast('Error', `The following invoice(s) are already paid: ${paidNames}`, 'Error');
            return;
        }


        let paymentItemList = [];
        this.selectedInvoices.forEach(inv => {
            paymentItemList.push({ sobjectType: 'Payment_Receipt_Item__c', Invoice__c: inv.InvId, Amount__c: inv.Amount });
        });
        const total = this.selectedTotalAmount;

        createPaymentWithItems({ selectedinvoicesList: paymentItemList, totalAmount: total })
            .then((receiptId) => {
                console.log(receiptId);
                this.showToast('Success', 'Payment Receipt saved successfully', 'success');
                this.showModal = false;
                this.showPrimaryPayments = true;
                this.showPrimaryInvoices = false;
                this.getPrimaryPaymemtsData();
                this.selectedInvoices = [];
                this.selectedTotalAmount = 0;
                this.invoiceData();
            })
            .catch((error) => {
                console.error(error);
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            });
    }



    @track selectedInvoices = [];
    @track selectedTotalAmount = 0;

    makePaymemt() {
        const selectedInvoices = this.InvFilter.allInvData.filter(row => row.isSelected);
        if (selectedInvoices.length === 0) {
            this.showToast('Error', 'Please select at least one invoice.', 'error');
            return;
        }
        // Set invoice list and total
        this.selectedInvoices = selectedInvoices;
        this.selectedTotalAmount = selectedInvoices.reduce(
            (sum, inv) => sum + parseFloat(inv.Amount || 0), 0
        );
        console.log('Selected Invoices:', this.selectedInvoices);
        console.log('Total Amount:', this.selectedTotalAmount);
        //  Open modal
        this.showModal = true;
    }

    get makePaymentTooltip() {
        return this.isMakePaymentDisabled
            ? 'Select Payment pending Invoices'
            : '';
    }
    get isdableGRNbutton() {
        return this.InvFilter?.status === 'GRN Completed';
    }
    get grnButtonClass() {
        return this.isdableGRNbutton
            ? 'actionButton disabledButton'
            : 'actionButton';
    }
    get isMakePaymentDisabled() {
        return this.InvFilter?.status === 'All';
    }
    get makePaymentButtonClass() {
        return this.isMakePaymentDisabled
            ? 'actionButton disabledButton'
            : 'actionButton';
    }


    get invoiceCountForModal() {
        return this.selectedInvoices?.length || 0;
    }

    get totalAmountForModal() {
        return this.selectedTotalAmount || 0;
    }

    generateGRNpage() {
        try {


            // Get all selected invoices
            const selectedInvoices = this.InvFilter.allInvData.filter(row => row.isSelected);

            if (selectedInvoices.length === 0) {
                this.showToast('Error', 'Please select at least one invoice.', 'error');
                return;
            }
            if (selectedInvoices.length > 1) {
                this.showToast('Error', 'Please select only one invoice.', 'error');
                return;
            }



            // Hide main list and show GRN section
            this.showPrimaryInvoices = false;
            this.isgenerateGRN = true;

            // Store selected invoice IDs
            this.selectedInvoiceIds = selectedInvoices.map(inv => inv.InvId);



            // Filter invoice items related to selected invoice IDs
            const allItems = this.allInvoiceItems;
            this.selectedInvoiceItems = allItems.filter(item =>
                this.selectedInvoiceIds.includes(item.Invoice__c)
            );

        } catch (e) {
            console.error('generateGRNpage error:', e);
            this.showToast('Error', e.message || 'Unknown error', 'error');
        }
    }


    handleGRNComplete(event) {
        this.isgenerateGRN = false;
        this.showPrimaryGrn = true;
        this.getGRNsData();

        this.selectedInvoiceId = null;



    }

    handleGRNCancel() {
        this.isgenerateGRN = false;
        this.showPrimaryInvoices = true;
        this.selectedInvoiceId = null;
    }
    newreturnScreen() {
        this.showPrimaryReturn = false;
        this.isNewReturn = true;


    }
    handleReturnCreated() {
        //primary returns
        this.isNewReturn = false;
        this.loadPrimaryReturns()

        this.showPrimaryReturn = true;
        this.showPrimaryReturnItems = false;

    }
    newClaimScreen() {
        this.showClaim = false;
        this.isNewClaim = true;
    }
    handleClaimCreated() {
        this.isNewClaim = false;
        this.showClaim = true;
        this.getClaimData();

    }
    handleClaimCancel() {
        this.isNewClaim = false;
        this.showClaim = true;
    }
    handleNewPayment() {
        this.showPrimaryInvoices = true;
        this.showPrimaryPayments = false;
        this.getInvoiceData();

    }

    handleNewGRN() {
        this.showPrimaryInvoices = true;
        this.showPrimaryGrn = false;
        this.getInvoiceData();

    }

    handleNewSecondaryReturn() {
        this.showSecoundaryReturn = false;
        this.isNewSecondaryReturn = true;

    }
    handleSecondaryReturnCreated(event) {
        this.isNewSecondaryReturn = false;
        this.showSecoundaryReturn = true;
        this.showToast('Success', 'Secondary Return saved successfully', 'success');
        this.getSecoundaryReturnData();
    }

    handleSecondaryReturnCancel() {
        this.showSecoundaryReturn = true;
        this.isNewSecondaryReturn = false;


    }
    handleReturncancel() {
        this.showPrimaryReturn = true;
        this.isNewReturn = false;
        this.getPrimaryReturnData();
    }

    handleGenerateInvoice() {
        try {
            // Get all selected orders
            const selectedOrders = this.ordFilter.allordData.filter(
                row => row.isSelected
            );

            // No order selected
            if (selectedOrders.length === 0) {
                this.showToast(
                    'Error',
                    'Please select one order to generate an invoice.',
                    'error'
                );
                return;
            }

            // More than one order selected
            if (selectedOrders.length > 1) {
                this.showToast(
                    'Validation Error',
                    'Please select only one order to generate an invoice.',
                    'error'
                );
                return;
            }

            // Exactly one order selected
            const selectedOrder = selectedOrders[0];

            // Store single order details
            this.selectedorderId = selectedOrder.orderId;
            this.selectedCustomerName = selectedOrder.customerName;
            this.selectedCustomerId = selectedOrder.customerId;

            console.log('Selected Order Id:', this.selectedorderId);
            console.log('Selected Customer Name:', this.selectedCustomerName);

            // Hide order list and show invoice section
            this.showSecondaryOrders = false;
            this.isGenerateInvoice = true;

        } catch (e) {
            console.error('handleGenerateInvoice error:', e);
            this.showToast(
                'Error',
                e.message || 'Unknown error occurred',
                'error'
            );
        }
    }



    handleSecondaryOrderCancel() {
        // Back to order list
        this.isGenerateInvoice = false;
        this.showSecondaryOrders = true;
        this.getSecoundaryOrderData();
    }
    handleSecondaryorderCreated() {
        this.isGenerateInvoice = false;
        this.showSecoundaryInvoices = true;
        this.getSecoundaryInvoiceData();


    }
    get statusOptions() {
        return [
            { label: 'GRN Pending', value: 'GRN Pending' },
            { label: 'GRN Completed', value: 'GRN Completed' }
        ];
    }
    handleStatusChange(event) {
        this.InvFilter.status = event.detail.value;
        // Reapply filter logic based on the selected status
        this.invoiceData();
    }



    downloadInvoicesAsPDF() {
        const from = this.InvFilter.fromDate;
        const to = this.InvFilter.toDate;
        const status = this.InvFilter.status;

        if (!from || !to) {
            this.showToast('Error', 'Please select From and To dates.', 'error');
            return;
        }

        const url = `/apex/DMSprimaryInvoicePDF?fromDate=${from}&toDate=${to}&status=${status}`;
        window.open(url, '_blank');
    }


    downloadSecondaryInvoicesAsPDF() {
        const from = this.secInvFilter.fromDate;
        const to = this.secInvFilter.toDate;
        const status = this.secInvFilter.status;

        // Check if both from and to dates are selected
        if (!from || !to) {
            this.showToast('Error', 'Please select From and To dates.', 'error');
            return;
        }

        // Format the dates to 'yyyy-MM-dd' (exclude time part)
        const formattedFromDate = this.formatDate(from);
        const formattedToDate = this.formatDate(to);

        console.log('Formatted From Date:', formattedFromDate);
        console.log('Formatted To Date:', formattedToDate);

        // Construct the URL for the Secondary Invoices PDF page
        const url = `/apex/DMSsecondaryInvoicePDF?fromDate=${formattedFromDate}&toDate=${formattedToDate}&status=${status}`;
        window.open(url, '_blank');
    }

    //Helper function to format the date as 'yyyy-MM-dd'
    formatDate(date) {
        const d = new Date(date);
        const year = d.getFullYear();
        const month = String(d.getMonth() + 1).padStart(2, '0'); // Add leading zero if needed
        const day = String(d.getDate()).padStart(2, '0'); // Add leading zero if needed
        return `${year}-${month}-${day}`;
    }



    newPrimaryOrder() {
        this.isNewOrder = true;
        this.showPrimaryOrders = false;
    }

    handlePrimaryOrdercancel() {
        this.isNewOrder = false;
        this.showPrimaryOrders = true;

    }


    handlePrimaryOrderCreated() {
        this.isNewOrder = false;
        this.showPrimaryOrders = true;
        this.getOrderData();
    }

    newPrimaryOrder2() {
        this.isNewOrder2 = true;
        this.showPrimaryOrders = false;
    }

    handlePrimaryOrdercancel2() {
        this.isNewOrder2 = false;
        this.showPrimaryOrders = true;

    }
    handlePrimaryOrderCreated2() {
        this.isNewOrder2 = false;
        this.showPrimaryOrders = true;
        this.getOrderData();
    }


    newPrimaryOrder3() {
        this.isNewOrder3 = true;
        this.showPrimaryOrders = false;
    }

    handlePrimaryOrderCancel3() {
        this.isNewOrder3 = false;
        this.showPrimaryOrders = true;

    }

    handlePrimaryOrderCreated3() {
        this.isNewOrder3 = false;
        this.showPrimaryOrders = true;
        this.getOrderData();
    }

    images = Array.from(
        { length: parseInt(DMS_OFFER_COUNT, 10) },
        (_, i) => DMS_Home_Page_Offers + '/' + (i + 1) + '.png'
    );


    /*images = [
        DMS_Offer1,
        DMS_Offer2,
        DMS_Offer3,

    ];*/

    currentIndex = 0;

    get currentImage() {
        return this.images[this.currentIndex];
    }

    @wire(getPartnerAccountInfo)
    wiredPartnerAccount({ data }) {
        if (data) {
            this.partnerAccountName = data.accountName || '';
            this.partnerSapCode = data.sapCode || '';
        }
    }

    get partnerHeaderLabel() {
        if (!this.partnerAccountName) {
            return '';
        }
        return this.partnerSapCode
            ? this.partnerAccountName + ' (' + this.partnerSapCode + ')'
            : this.partnerAccountName;
    }

    get showCarouselView() {
        return this.homeView === 'carousel';
    }

    get showLedgerView() {
        return this.homeView === 'ledger';
    }

    get hasLedgerEntries() {
        return this.ledgerEntries && this.ledgerEntries.length > 0;
    }

    get showLedgerResults() {
        return !this.ledgerLoading
            && !this.ledgerError
            && !!this.ledgerFromDate
            && !!this.ledgerToDate
            && !this.showLedgerPrompt;
    }

    get displayOpeningBalance() {
        return this.ledgerOpeningBalance == null ? 0 : this.ledgerOpeningBalance;
    }

    get displayClosingBalance() {
        return this.ledgerClosingBalance == null ? 0 : this.ledgerClosingBalance;
    }

    handleLedgerFromDateChange(event) {
        this.ledgerFromDate = event.target.value;
    }

    handleLedgerToDateChange(event) {
        this.ledgerToDate = event.target.value;
    }

    openCustomerLedger() {
        this.homeView = 'ledger';
        this.ledgerError = '';
        this.ledgerFromDate = '';
        this.ledgerToDate = '';
        this.ledgerEntries = [];
        this.ledgerOpeningBalance = null;
        this.ledgerClosingBalance = null;
    }

    get showLedgerPrompt() {
        return !this.ledgerLoading
            && !this.ledgerError
            && !this.hasLedgerEntries
            && (!this.ledgerFromDate || !this.ledgerToDate);
    }
 
    refreshCustomerLedger() {
        this.fetchCustomerLedger();
    }

    fetchCustomerLedger() {
        if (!this.ledgerFromDate || !this.ledgerToDate) {
            this.ledgerError = 'Please select both From Date and To Date.';
            return;
        }
        this.ledgerLoading = true;
        this.ledgerError = '';
        getCustomerLedger({ fromDate: this.ledgerFromDate, toDate: this.ledgerToDate })
            .then((result) => {
                if (!result || !result.success) {
                    this.ledgerError = this.extractLedgerErrorMessage(
                        result && result.errorMessage
                    ) || 'Failed to load customer ledger.';
                    this.ledgerEntries = [];
                    this.ledgerOpeningBalance = null;
                    this.ledgerClosingBalance = null;
                    return;
                }
                this.ledgerOpeningBalance = result.openingBalance;
                this.ledgerClosingBalance = result.closingBalance;
                this.ledgerEntries = (result.data || []).map((row, i) => ({
                    key: (row.docNo || '') + '-' + i,
                    ...row
                }));
            })
            .catch((error) => {
                this.ledgerError = this.extractLedgerErrorMessage(
                    error && error.body && error.body.message
                ) || 'Unexpected error loading ledger.';
                this.ledgerEntries = [];
            })
            .finally(() => {
                this.ledgerLoading = false;
            });
    }

    extractLedgerErrorMessage(raw) {
        if (!raw) return '';
        const match = raw.match(/\{[\s\S]*\}/);
        if (match) {
            try {
                const parsed = JSON.parse(match[0]);
                if (parsed && parsed.message) {
                    return parsed.message;
                }
            } catch (e) {
                // fall through to raw
            }
        }
        return raw;
    }

    backToCarousel() {
        this.homeView = 'carousel';
    }

    connectedCallback() {
        this.startCarousel();
    }

    startCarousel() {
        this.interval = setInterval(() => {
            this.currentIndex = (this.currentIndex + 1) % this.images.length;
        }, 3000); // Change image every 3 seconds
    }

    disconnectedCallback() {
        clearInterval(this.interval);
    }



    openOrderItems(event) {
        const orderId = event.currentTarget.dataset.id; // Use currentTarget instead of target
        console.log('Order clicked, orderId:', orderId);

        // Optional: log all orders for debug
        console.log('All orders in ordFilter.allordData:', JSON.stringify(this.ordFilter.allordData.map(ord => ({
            orderId: ord.orderId,
            orderNo: ord.orderNo,
            itemsCount: ord.items ? ord.items.length : 0
        }))));

        // Find the selected order from all orders
        const selectedOrder = this.ordFilter.allordData.find(ord => ord.orderId === orderId);

        if (selectedOrder) {
            console.log('Selected order:', JSON.stringify({
                orderId: selectedOrder.orderId,
                orderNo: selectedOrder.orderNo,
                items: selectedOrder.items
            }));

            // Set order details and show items inline
            this.selectedOrderItems = this.addRowIndex(selectedOrder.items || []);
            this.selectedOrderNo = selectedOrder.orderNo;
            this.showOrderItems = true;    // Show the order item section
            this.hasOrderItems = this.selectedOrderItems.length > 0;
            this.showPrimaryOrders = false;   // Hide the primary orders table
        } else {
            console.error('No order found for orderId:', orderId);
        }
    }

    closePrimaryOrderItems() {
        this.showPrimaryOrders = true;
        this.showOrderItems = false;
        this.selectedOrderItems = [];
        this.selectedOrderNo = '';
        this.hasOrderItems = false;
    }
    closePrimaryInvoiceItems() {
        this.showPrimaryInvoices = true;
        this.showInvoiceItems = false;
        this.selectedInvoiceId = '';
        this.invoiceItems = [];
        this.hasInvoiceItems = false;
    }

    handleFocus(event) {
        try {
            event.preventDefault();
            event.stopPropagation();
            // Your blur logic here
        } catch (error) {
            console.error('Error in focus handler:', error);
        }
    }
    handleBlur(event) {
        try {
            event.preventDefault();
            event.stopPropagation();
            // Your blur logic here
        } catch (error) {
            console.error('Error in blur handler:', error);
        }
    }



    @track secinvoices = [];





    wiredSecondaryInvoices({ error, data }) {
        if (data) {
            this.secinvoices = data; // Assuming DmsData contains the list of invoices
        } else if (error) {
            console.error('Error fetching secondary invoices', error);
        }
    };



    // Method to download the CSV
    downloadSecondaryInvoicesasCSV() {


        if (!this.secInvFilter.fromDate || !this.secInvFilter.toDate) {
            alert('Please provide both From Date and To Date.');
            return;
        }

        const invoices = this.secInvFilter.allSecInvData || [];

        if (invoices.length === 0) {
            this.showToast('No Data Found', 'No invoices found for the selected filters.', 'error');
            return;
        }

        // Define CSV header
        const header = ['Invoice No.', 'Outlet', 'Beat Name', 'Invoice Date', 'Status', 'Total Quantity', 'Non Taxable Amount', 'SGST', 'CGST', 'Total Amount'];

        // Map invoices to CSV rows
        const rows = invoices.map(invoice => [
            invoice.name || '',
            invoice.accName || '',
            invoice.beatName || '',
            invoice.InvDate || '',
            invoice.Status || '',
            invoice.Quantity || '',
            invoice.nonTaxableAmount || '',
            invoice.sgstAmount || '',
            invoice.cgstAmount || '',
            invoice.Amount || ''
        ]);

        // Create CSV content
        let csvContent = 'data:text/csv;charset=utf-8,' + header.join(',') + '\n';
        rows.forEach(row => {
            csvContent += row.join(',') + '\n';
        });

        // Encode CSV content and trigger download
        const encodedUri = encodeURI(csvContent);
        const link = document.createElement('a');
        link.setAttribute('href', encodedUri);
        link.setAttribute('download', 'filtered_secondary_invoices.csv');
        link.click();
    }


    //================================================================================
    // PRIMARY INVOICES AS CSV





    // Method to download the filtered CSV and show toast on no data
    downloadPrimaryInvoicesasCSV() {
        if (!this.InvFilter.fromDate || !this.InvFilter.toDate) {
            alert('Please provide both From Date and To Date.');
            return;
        }
        var invoices = this.InvFilter.allInvData
        if (invoices.length === 0) {
            // Show toast message if no invoices are found
            this.showToast('No Data Found', 'No primary invoices found for the selected filters.', 'error');
            return;
        }

        // Define CSV header with fields as per the invoice data
        const header = ['SAP Inv No', 'SF Inv No.', 'Party Name', 'GST No.', 'Order No.', 'Invoice Date', 'Total Qty', 'Non-Taxable Amount', 'SGST', 'CGST', 'IGST', 'Total Amount'];

        // Map invoices to CSV rows
        const rows = invoices.map(invoice => [
            invoice.invoiceNo,
            invoice.name,
            invoice.companyName,
            invoice.gstNumber,
            invoice.orderId,
            invoice.InvDate,
            invoice.TotalQuantity,
            invoice.nonTaxableAmount,
            invoice.sgstAmount,
            invoice.cgstAmount,
            invoice.igstAmount,
            invoice.Amount
        ]);

        // Create CSV content
        let csvContent = 'data:text/csv;charset=utf-8,' + header.join(',') + '\n';
        rows.forEach(row => {
            csvContent += row.join(',') + '\n';
        });

        // Encode CSV content and trigger download
        const encodedUri = encodeURI(csvContent);
        const link = document.createElement('a');
        link.setAttribute('href', encodedUri);
        link.setAttribute('download', 'filtered_primary_invoices.csv');
        link.click();
    }



    handleUploadSecondaryInvoices() {
        this.showSecoundaryInvoices = false;
        this.isNewDataUpload = true;
    }

    handleUploadCancel() {
        this.isNewDataUpload = false;
        this.showSecoundaryInvoices = true;

    }

}