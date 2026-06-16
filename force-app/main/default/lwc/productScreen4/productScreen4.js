import { LightningElement, api, track, wire } from 'lwc';
import getApexData from '@salesforce/apex/beatPlannerlwc.getSchemeWiseOrderData';
import getAccountData from '@salesforce/apex/beatPlannerlwc.getAccountData';
import getAccountsByArea from '@salesforce/apex/beatPlannerlwc.getAccountsByArea';
import saveOrderItemData from '@salesforce/apex/beatPlannerlwc.upsertOrder';
import saveStockItem from '@salesforce/apex/beatPlannerlwc.upsertStock';
import getAreaOptions from '@salesforce/apex/beatPlannerlwc.getAreaOptions';
import getSchemeCoverageForAccount from '@salesforce/apex/beatPlannerlwc.getSchemeCoverageForAccount';
import PLANNER_ICON from '@salesforce/resourceUrl/planner';
import FORM_FACTOR from '@salesforce/client/formFactor';
import GOOGLE_ICONS from '@salesforce/resourceUrl/googleIcons';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getLocationService } from 'lightning/mobileCapabilities';

export default class ProductScreen4 extends LightningElement {

    ice = PLANNER_ICON + "/planner/screen-4-ice.png";
    @api recordId;
    @api index;
    @api acccountId;
    @api logId;
    @api visitData;
    @api objType;
    @api orderRecordId;
    @api heading;
    @api isOrderTrue = false;

    @track productValue = 0;
    @track totalSelectedQuantity = 0;
    @track totalSelectedAmount = 0;

    @track showAreaSearch = false;
    @track isModerTrade = false;
    @track isPrimaryAccount = false;
    @track isSecondaryAccount = false;
    isSSADSM = false;   // current user flagged SSA/DSM -> account picker shows Secondary only
    @track isShowOwner = false;
    @track productData = [];
    @track getSelectedProduct = [];
    @track coverageSchemes = [];
    coverageProductSchemeIds = {};
    @track expandedProductIds = [];
    @track breakupExpandedIds = [];   // lines whose scheme price breakup is expanded
    @track collapsedSchemeIds = [];
    @track coverageSearch = '';
    @track deliveryTo = '';
    @track expectedDeliveryDate = '';
    @track OrderOwnerId = '';
    @track OrderOwnerName = '';
    @track poNum = '';
    @track poDate = '';
    @track minumumOrderValue = '';
    @track isSchemeView = false;
    @track areaFilter = '';  // Default to no filter
    @track accounts = [];    // Accounts data from Apex
    @track areaOptions = []; // Dropdown options for Area
    @track isLoading = false;
    @track isContentLoading = false; // Skeleton while account data loads after selection
    @track isDropdownOpen = true;  // By default, the dropdown is open
    dropdownClass = 'slds-dropdown-trigger slds-dropdown-trigger_click';
    productCatDropdown = [];
    orderSummery = [];
    originalSelectedProduct = [];
    proCatVal = 'All';
    salesCat = 'All';
    orderData = [];
    formattedSalesData = [];
    isProductAdded = false; isFieldsDisabled = true;
    isDropdownOrderOpen = true; isPageLoaded = false; isSummaryProduct = false;
    totalTaxAmt = 0; grandTotal = 0; totalQnt = 0;
    isAllOrder = true; isCategorySelected = true; isOrder = true; isSpecialOffer = false;
    searchPro = '';
    customOrderButton; isDesktop = false; isPhone = false;
    OrderDate; subTotalAmt = 0; grandTotalAmt = 0; Discount = 0; changePro;
    indexProSc1; indexProSc2; indexPro; customClass_Grid;
    indexProScOffer1; indexProScOffer2; indexProScOffer3;
    @track showAccountSearch = true;
    @track resultData; @track originalResultData; schemeOffer;
    @track schemePro; @track originalSchemePro; @track allProDtas; filterVal = 'All'; @track originalSchemeOffer;
    @track accountData = null; accountDataOriginal;
    @track accNam = ''; forceHeight = false; finalOrderPlace; listView
    currentLocationRequestId = '';

    // ===== Scheme engine (Scheme__c / Scheme_Slab__c) — secondary accounts =====
    @track focLines = [];               // synthetic FOC giveaway lines (net 0)
    @track categoryValueDiscount = 0;   // -> Order__c.Category_Discount__c
    @track orderValueDiscount = 0;      // -> Order__c.Order_Value_Discount__c
    @track netPayable = 0;              // grand total minus header discounts
    appliedSchemeRecords = [];          // -> Order_Scheme_Applied__c rows
    _lastInvalidSig = '';               // throttles the "schemes skipped" toast

    renderedCallback() {
        if (this.forceHeight) {
            if (this.orderRecordId == undefined && this.isOrderTrue) {
                const classAdd = this.template.querySelector('.tasks');
                if (classAdd) {
                    classAdd.classList.add('force-height');
                    this.forceHeight = false;
                }
            }
        }

    }
    connectedCallback() {
        this.fetchAreaOptions();
        this.disablePullToRefresh();
        this.isDesktop = FORM_FACTOR === 'Large';
        this.isPhone = FORM_FACTOR === 'Small';
        if (FORM_FACTOR === 'Medium') this.isDesktop = true;

        this.isPageLoaded = true;
        this.customClass_Grid = this.isDesktop
            ? 'slds-col slds-size_1-of-2 custom_Css'
            : 'slds-col slds-size_1-of-1';

        this.initLoadFlow();
    }

    initLoadFlow() {
        // CASE 1: Create Mode + accountId (from related list New override)
        if (!this.orderRecordId && this.isOrderTrue && this.acccountId) {
            console.log('My Visit Order');
            this.isFieldsDisabled = false;
            this.forceHeight = true;
            return; // prevent going below
        }

        // CASE 2: Create Mode + No accountId
        if (!this.orderRecordId && this.isOrderTrue) {
            console.log('Separate Order Tab');
            this.isFieldsDisabled = true;
            this.forceHeight = true;
            this.showAreaSearch = true;
            this.getAccountData();
            return;
        }

        // CASE 3: Edit Mode
        if (this.orderRecordId && this.isOrderTrue) {
            console.log('Edit Mode');
            this.isFieldsDisabled = false;
            this.showAreaSearch = false;
            this.getAccountData(); // for fetching account name
            this.getData();
            return;
        }

        // CASE 4: Non-order flow
        if (!this.isOrderTrue) {
            console.log('My Visit Order 2');
            this.isFieldsDisabled = false;
            this.customClass_Grid = this.isDesktop
                ? 'slds-col slds-size_1-of-2 custom_Css'
                : 'slds-col slds-size_1-of-1';
            this.getData();
        }

        this.isOrder = true;
        this.customOrderButton = 'Save Order';
    }

    fetchAreaOptions() {
        this.isLoading = true; // Show loading spinner

        getAreaOptions()
            .then(result => {
                this.areaOptions = result;
                this.isLoading = false; // Hide loading spinner
            })
            .catch(error => {
                this.isLoading = false; // Hide loading spinner
                console.error("Error fetching area options:", error);
            });
    }

    handleAreaChange(event) {
        // Set the area filter to the selected value
        this.areaFilter = event.target.value;
        //alert(this.areaFilter);

        // Close the dropdown after selection
        this.isDropdownOpen = false;
        this.dropdownClass = 'slds-dropdown-trigger slds-dropdown-trigger_click slds-is-open';  // Adjust this to control visibility

        //this.getFilteredAccounts(); // Fetch accounts based on selected area
    }
    openDropdown() {
        this.isDropdownOpen = true;
        this.dropdownClass = 'slds-dropdown-trigger slds-dropdown-trigger_click slds-is-open';  // Open the dropdown
    }

    getFilteredAccounts() {
        this.isLoading = true; // Show loading spinner
        // Call your Apex method to fetch accounts based on areaFilter
        //alert(this.areaFilter);
        getAccountsByArea({ area: this.areaFilter, searchTerm: this.accNam, onlySecondary: this.isSSADSM })
            .then(result => {
                //alert('result '+result);
                this.accountDataOriginal = result;  // Store the filtered accounts
                this.isLoading = false;  // Hide the loading spinner
            })
            .catch(error => {
                this.isLoading = false;  // Hide the loading spinner
                this.showToast('Error', 'Failed to fetch accounts', 'error');  // Show error toast
                console.error('Error fetching accounts:', error);
            });
    }


    applyCategoryStyles(groupList) {
        if (!groupList) return groupList;
        const baseHeader = 'task-head slds-align_absolute-center';
        return groupList.map(group => {
            const groupName = (group && group.name) ? group.name.toLowerCase() : '';
            let cardClass = 'product-card others-card';
            if (groupName.includes('focused')) {
                cardClass = 'product-card focused-card';
            } else if (groupName.includes('must')) {
                cardClass = 'product-card must-card';
            }
            return { ...group, headerClass: baseHeader, cardClass };
        });
    }

    syncQuantityToSchemePro(productId, newQty) {
        if (!productId || !this.schemePro) return;
        let changed = false;

        for (let group of this.schemePro) {
            for (let prod of group.products) {
                if (prod.id === productId) {
                    prod.value = newQty;
                    changed = true;
                }
            }
        }

        if (changed) {
            // Force LWC reactivity
            this.schemePro = [...this.schemePro];
        }
    }

    handleDeliveryToChange(event) {
        this.deliveryTo = event.target.value;
    }

    handleExpectedDeliveryChange(event) {
        this.expectedDeliveryDate = event.target.value;
    }

    handlePoNumChange(event) {
        this.poNum = event.target.value;
    }

    handlePoDateChange(event) {
        this.poDate = event.target.value;
    }
    handleLookupChange(event) {
        this.OrderOwnerId = event.detail.value;
    }
    getAccountData() {
        this.isPageLoaded = false;
        getAccountData({ areaFilter: this.areaFilter })
            .then(result => {
                this.isSSADSM = result.isDSM_SSA === true;
                this.accountDataOriginal = result.Account;
                this.listView = (result.ListViewDetails && result.ListViewDetails.Id) || this.listView;
            })
            .catch(error => {
                console.error(error);
                this.isPageLoaded = false;
            });
    }
    getData() {
        this.isContentLoading = true;
        getApexData({
            visitId: this.recordId,
            AccountId: this.acccountId,
            orderRecordId: this.orderRecordId
        })
            .then(result => {
                this.resultData = result;
                this.originalResultData = result;
                this.acccountId = result.orderAccountId;
                this.listView = (result.ListViewDetails && result.ListViewDetails.Id) || this.listView;
                this.productData = result.allOtherProducts.length !== 0 ? result.allOtherProducts : null;
                this.originalSelectedProduct = result.allOtherProducts.length !== 0 ? result.allOtherProducts : null;

                this.schemePro = result.strategyProductMapList.length !== 0 ? this.applyCategoryStyles(result.strategyProductMapList) : null;
                this.originalSchemePro = result.strategyProductMapList.length !== 0 ? this.applyCategoryStyles(result.strategyProductMapList) : null;
                this.minumumOrderValue = result.minumumOrderValue || 0;
                this.allProDtas = result.allProDtas;
                this.deliveryTo = result.deliveryTo || '';
                this.expectedDeliveryDate = result.estimatedDeliveryDate || '';
                this.poNum = result.PoNum || '';
                this.poDate = result.PoDate || '';
                this.schemeOffer = result.schemessss;
                this.originalSchemeOffer = result.schemessss;
                this.isModerTrade = result.isModerTrade;
                this.productCatDropdown = result.productCatDropdown;
                this.isShowOwner = result.isShowOwner;
                this.OrderOwnerId = result.orderOwnerId || '';
                this.OrderOwnerName = result.orderOwnerName || '';

                this.loadCoverage();

                if (result.Account) {
                    const acc = result.Account.find(a => a.Id === this.acccountId);
                    if (acc) {
                        this.accNam = acc.Name;
                        this.isPrimaryAccount = acc.Customer_Type__c === 'Primary Customer';
                        this.isSecondaryAccount = acc.Customer_Type__c === 'Secondary Customer';
                    }
                }

                if (this.allProDtas && this.allProDtas.length > 0) {
                    for (let prod of this.allProDtas) {
                        if (prod.value && prod.value > 0) {
                            this.autoSelectBestScheme(prod.id);
                        }
                    }
                }

                // ✅ Set Account name if record is coming from override or edit
                if (this.accountDataOriginal && this.acccountId) {
                    const acc = this.accountDataOriginal.find(a => a.Id === this.acccountId);
                    if (acc) {
                        this.accNam = acc.Name;
                        this.isPrimaryAccount = acc.Customer_Type__c === 'Primary Customer';
                        this.isSecondaryAccount = acc.Customer_Type__c === 'Secondary Customer';
                    }
                }
                if (!this.acccountId && result.accountName) {
                    this.accNam = result.accountName;
                    this.isPrimaryAccount = result.accountType === 'Primary Customer';
                    this.isSecondaryAccount = result.accountType === 'Secondary Customer';
                }



                this.isPageLoaded = false;

                if (this.orderRecordId && result.existingOrderProductQuantities) {
                    const existingQty = result.existingOrderProductQuantities;

                    // Restore the ORDERED qty from the split fields. Quantity__c includes
                    // merged FOC giveaway free units, so using it would inflate the order
                    // (and the engine would re-add the free on top).
                    const applyOrdered = (product) => {
                        const oi = existingQty[product.id];
                        if (!oi) return;
                        const crate = parseInt(oi.Case_Qyt__c) || 0;
                        const each  = parseInt(oi.Each_Qyt__c) || 0;
                        const uomConv = parseFloat(product.uomConversion) || 1;
                        product.crateQty = crate;
                        product.eachQty  = each;
                        product.value = (crate * uomConv) + each;
                    };

                    if (this.schemePro) {
                        this.schemePro.forEach((schemeGroup) => {
                            (schemeGroup.products || []).forEach(applyOrdered);
                        });
                    }

                    if (this.productData) {
                        this.productData.forEach(applyOrdered);
                    }

                    if (this.allProDtas) {
                        this.allProDtas.forEach(applyOrdered);
                    }
                }

                if (this.schemeOffer && this.schemePro) {
                    this.schemePro.forEach(group => {
                        group.products.forEach(product => {
                            // Mark if product has applicable schemes
                            product.hasApplicableSchemes = this.schemeOffer.some(scheme =>
                                scheme.lineItems.some(item => item.productId === product.id)
                            );

                            // Store applicable schemes directly on product
                            product.applicableSchemes = this.schemeOffer
                                .flatMap(scheme => scheme.lineItems)
                                .filter(item => item.productId === product.id);
                        });
                    });
                }

                if (this.orderRecordId === undefined && this.isOrderTrue) {
                    const classAdd = this.template.querySelector('.tasks');
                    if (classAdd) {
                        classAdd.classList.remove('force-height');
                        this.forceHeight = false;
                        this.isFieldsDisabled = false;
                    }
                    this.isAllOrder = true;
                    this.isProductAdded = false;
                    this.isSummaryProduct = false;
                }
                this.isContentLoading = false;
            })
            .catch(error => {
                console.error(error);
                this.isPageLoaded = false;
                this.isContentLoading = false;
            });
    }



    incProd(event) {
        // const index1 = parseInt(event.target.dataset.index);
        // const index2 = parseInt(event.target.dataset.id);
        const index2 = parseInt(event.currentTarget.dataset.index);
        const index1 = parseInt(event.currentTarget.dataset.id);
        //this.productData[index].value = this.productValue;
        let inc = this.schemePro[index1].products[index2].value;
        inc++;
        this.schemePro[index1].products[index2].value = inc;//.products[index2].value = inc;
        this.syncQuantityToSchemeOffer(this.schemePro[index1].products[index2].id, inc);
        this.autoSelectBestScheme(this.schemePro[index1].products[index2].id);
        /*if(inc >= 0){
            var offerDta = this.handleOfferDta(this.schemePro[index1].products[index2]);
            // var offerDta.buyQuantity
            if(offerDta != undefined){
                this.schemePro[index1].products[index2].offer = offerDta.length > 0  ? true : false;
                this.schemePro[index1].products[index2].hoverDta = offerDta.length > 0 ? offerDta : [];
            }else{
                this.schemePro[index1].products[index2].offer = false;
                this.schemePro[index1].products[index2].hoverDta = [];
            }
        } */
        // if(this.searchPro != ''){
        //this.sendUpdatedValue(index1,index2);
        var dta = this.schemePro[index1].products[index2];
        for (var i = 0; i < this.allProDtas.length; i++) {

            if (dta.id == this.allProDtas[i].id) {
                this.allProDtas[i].value = inc;
                this.allProDtas[i].hoverDta = this.schemePro[index1].products[index2].hoverDta;
                this.allProDtas[i].offer = this.schemePro[index1].products[index2].offer;
                if (inc > 0)
                    this.allProDtas[i].schemeIds = this.schemePro[index1].id;
                else if (inc <= 0)
                    this.allProDtas[i].schemeIds = null;
                break;
            }
        }
        // }
    }
    handleOfferDta(dta) {
        const data = this.schemeOffer;
        var offerDta = [];
        for (var i = 0; i < data.length; i++) {
            for (var j = 0; j < data[i].strategy.buyProduct.length; j++) {
                if (dta.id == data[i].strategy.buyProduct[j].productId) {
                    const shemeDt = data[i].strategy;
                    offerDta.push({
                        ...data[i].strategy.buyProduct[j],
                        shemenDescription: shemeDt.Description,
                        schemeName: shemeDt.name,
                        schemeParentId: shemeDt.id,
                        schemeProCate: shemeDt.productCategory,
                        schemeProId: shemeDt.productName,
                        onHover: false
                    });
                }
            }
        }
        return offerDta;
    }
    incProdPro(event) {

        const index1 = parseInt(event.currentTarget.dataset.index);

        //this.productData[index].value = this.productValue;
        let inc = this.productData[index1].value//.products[index2].value;
        inc++;
        this.productData[index1].value = inc//.products[index2].value = inc;
        this.syncQuantityToSchemeOffer(this.productData[index1].id, this.productData[index1].value);
        this.autoSelectBestScheme(this.productData[index1].id);
        //this.sendUpdatedValue(index1)
        /*if(inc > 0){
            var offerDta = this.handleOfferDta(this.productData[index1]);
            // var offerDta.buyQuantity
            if(offerDta != undefined){
                this.productData[index1].offer = offerDta.length > 0 ? true : false;
                this.productData[index1].hoverDta = offerDta.length > 0 ? offerDta : [];
            }else{
                this.productData[index1].offer = false;
                this.productData[index1].hoverDta = [];
            }
        } */
        var dta = this.productData[index1];
        for (var i = 0; i < this.allProDtas.length; i++) {
            if (dta.id == this.allProDtas[i].id) {
                this.allProDtas[i].value = inc;
                this.allProDtas[i].hoverDta = this.productData[index1].hoverDta;
                this.allProDtas[i].offer = this.productData[index1].offer;
                break;
            }
        }
    }

    decProd(event) {
        const index2 = parseInt(event.currentTarget.dataset.index);
        const index1 = parseInt(event.currentTarget.dataset.id);

        // Guard against invalid index
        if (!this.schemePro || !this.schemePro[index1] || !this.schemePro[index1].products[index2]) {
            console.warn('Invalid index in decProd', { index1, index2 });
            return;
        }

        let dec = this.schemePro[index1].products[index2].value;
        dec--;
        if (dec < 0) return;

        const product = this.schemePro[index1].products[index2];
        product.value = dec;

        this.syncQuantityToSchemeOffer(product.id, dec);
        this.autoSelectBestScheme(product.id);

        const dta = product;
        for (let i = 0; i < this.allProDtas.length; i++) {
            if (dta.id === this.allProDtas[i].id) {
                this.allProDtas[i].value = dec;
                this.allProDtas[i].hoverDta = dta.hoverDta;
                this.allProDtas[i].offer = dta.offer;
                this.allProDtas[i].schemeIds = dec > 0 ? this.schemePro[index1].id : null;
                break;
            }
        }
    }

    get minExpectedDeliveryDate() {
        const today = new Date();
        today.setDate(today.getDate() + 1); // If you want only *future* dates (exclude today)
        return today.toISOString().split('T')[0]; // Format as yyyy-MM-dd
    }
    decProdPro(event) {
        const index1 = parseInt(event.currentTarget.dataset.index);

        //this.productData[index].value = this.productValue;
        let dec = this.productData[index1].value//.products[index2].value;
        dec--;
        if (dec < 0) {
            return;
        }
        this.productData[index1].value = dec//.products[index2].value = inc;
        this.syncQuantityToSchemeOffer(this.productData[index1].id, this.productData[index1].value);
        this.autoSelectBestScheme(this.productData[index1].id);
        //this.sendUpdatedValue(index1);

        /*if(dec >= 0){
            var offerDta = this.handleOfferDta(this.productData[index1]);
            if(offerDta != undefined){
                this.productData[index1].offer = offerDta.length > 0 ? true : false;
                this.productData[index1].hoverDta = offerDta.length > 0 ? offerDta : [];
            }else{
                this.productData[index1].offer = false;
                this.productData[index1].hoverDta = [];
            }
            // this.productData[index1].offer = offerDta.buyQuantity < inc ? true : false;
            // this.schemePro[index1].hoverDta = offerDta.buyQuantity < inc ? offerDta : [];
        } */
        var dta = this.productData[index1];
        for (var i = 0; i < this.allProDtas.length; i++) {
            if (dta.id == this.allProDtas[i].id) {
                this.allProDtas[i].value = dec;
                this.allProDtas[i].hoverDta = this.productData[index1].hoverDta;
                this.allProDtas[i].offer = this.productData[index1].offer;
                break;
            }
        }
    }
    handleMouseOverProSch(event) {

        const index2 = parseInt(event.currentTarget.dataset.index);
        const index1 = parseInt(event.currentTarget.dataset.id);
        this.schemePro[index1].products[index2].onHover = true;
        this.indexProSc1 = index1;
        this.indexProSc2 = index2;
    }
    handleMouseOverProSchOffer(event) {

        const index2 = parseInt(event.currentTarget.dataset.index2);
        const index1 = parseInt(event.currentTarget.dataset.index1);
        const index3 = parseInt(event.currentTarget.dataset.index3);
        this.schemePro[index1].products[index2].hoverDta[index3].onHover = true;
        this.indexProScOffer1 = index1;
        this.indexProScOffer2 = index2;
        this.indexProScOffer3 = index3;
    }
    handleMouseOverProOffer(event) {

        const index2 = parseInt(event.currentTarget.dataset.index2);
        // const index1 = parseInt(event.currentTarget.dataset.index1);
        const index3 = parseInt(event.currentTarget.dataset.index3);
        this.schemePro[index1].products[index2].hoverDta[index3].onHover = true;
        this.indexProScOffer1 = index1;
        this.indexProScOffer2 = index2;
        this.indexProScOffer3 = index3;
    }

    handleMouseOutProSch(event) {

        if (this.indexProSc1 != null && this.indexProSc2 != null) {
            this.schemePro[this.indexProSc1].products[this.indexProSc2].onHover = false;
            this.indexProSc1 = null;
            this.indexProSc2 = null;
        }
    }
    handleMouseOutProSchOffer(event) {

        if (this.indexProScOffer1 != null && this.indexProScOffer2 != null && this.indexProScOffer3 != null) {
            this.schemePro[this.indexProScOffer1].products[this.indexProScOffer2].hoverDta[this.indexProScOffer3].onHover = false;
            this.indexProScOffer1 = null;
            this.indexProScOffer2 = null;
            this.indexProScOffer3 = null;
        }
    }
    handleMouseOver(event) {

        const index2 = parseInt(event.currentTarget.dataset.index);
        this.productData[index2].onHover = true;
        this.indexPro = index2;
    }
    handleMouseOut(event) {

        if (this.indexPro != null) {
            this.productData[this.indexPro].onHover = false;
            this.indexPro = null;
        }
    }
    sendUpdatedValue(i, j) {
        const srchPro = this.productData;
        const totalPro = this.originalSelectedProduct;

        // Create a Map for faster lookups
        const totalProMap = new Map();
        totalPro.forEach((category, index) => {
            category.products.forEach(product => {
                totalProMap.set(product.id, product.value);
            });
        });

        // Update srchPro using the Map
        srchPro.forEach((category, index) => {
            category.products.forEach(product => {
                if (totalProMap.has(product.id)) {
                    product.value = totalProMap.get(product.id);
                }
            });
        });
    }

    prodChange(event) {
        const index2 = parseInt(event.target.dataset.index);
        const index1 = parseInt(event.target.dataset.id);
        const value = parseInt(event.target.value);

        if (value >= 0) {
            const product = this.schemePro[index1].products[index2];
            const productId = product.id; // ✅ Fix

            product.value = value;

            const dta = product;
            for (let i = 0; i < this.allProDtas.length; i++) {
                if (dta.id === this.allProDtas[i].id) {
                    this.allProDtas[i].value = value;
                    break;
                }
            }

            this.syncQuantityToSchemeOffer(productId, value);  // ✅ Use defined productId
            this.autoSelectBestScheme(productId);              // ✅ Use defined productId

        } else {
            const product = this.schemePro[index1].products[index2];
            product.value = 0;
            product.offer = false;
            product.hoverDta = [];

            const productId = product.id; // ✅ Fix
            this.syncQuantityToSchemeOffer(productId, 0);
            this.autoSelectBestScheme(productId);
        }
    }



    prodChangePro(event) {
        //const index = parseInt(event.target.dataset.index);
        const index1 = parseInt(event.currentTarget.dataset.index);

        const value = parseInt(event.target.value);
        if (value >= 0) {
            var offerDta = this.handleOfferDta(this.productData[index1]);

            if (offerDta != undefined) {
                this.productData[index1].offer = offerDta.length > 0 ? true : false;
                this.productData[index1].hoverDta = offerDta.length > 0 ? offerDta : [];
            } else {
                this.productData[index1].offer = false;
                this.productData[index1].hoverDta = [];
            }
            this.productData[index1].value = value;
            this.syncQuantityToSchemeOffer(this.productData[index1].id, this.productData[index1].value);
            this.autoSelectBestScheme(this.productData[index1].id);
            var dta = this.productData[index1];
            for (var i = 0; i < this.allProDtas.length; i++) {
                if (dta.id == this.allProDtas[i].id) {
                    this.allProDtas[i].value = value;
                    this.allProDtas[i].hoverDta = this.productData[index1].hoverDta;
                    this.allProDtas[i].offer = this.productData[index1].offer;
                    break;
                }
            }
        } else {
            this.productData[index1].value = 0;
            this.allProDtas[index1].hoverDta = [];
            this.allProDtas[index1].offer = false;
        }
    }

    resetAllOptions() {
        this.onChangeProducts();
        this.isSummaryProduct = false;
        this.isProductAdded = false;
        this.isAllOrder = false;
    }
    dailyOffers(event) {
        const selectedName = event.target.dataset.name;
        const originalProducts = this.originalSelectedProduct;
        var dta = [];
        for (var i = 0; i < originalProducts.length; i++) {
            if (originalProducts[i].focusSellName != 'null') {
                dta.push(originalProducts[i]);
            }
        }
        this.isSpecialOffer = true;
        this.productData = dta;
        // var storePro = this.setProducts();
    }
    calculateTotal() {
        const orderLineItem = this.allProDtas;
        var dt = [];
        for (let i = 0; i < orderLineItem.length; i++) {
            if (orderLineItem[i].value != 0) {
                var data = {
                    Product__c: orderLineItem[i].id,
                    Product_Category__c: orderLineItem[i].proCate,
                    Total_Amount__c: orderLineItem[i].unitPrice,
                    Account__c: this.acccountId,
                    Visit__c: this.recordId,
                    // Daily_log__c : this.logId,
                    Quantity__c: orderLineItem[i].value,
                    Tax__c: orderLineItem[i].taxClass || 0
                }
                dt.push(data);
            }

        }
        if (dt.length == 0) {
            this.genericDispatchToastEvent('', 'Select order', 'warning');
            return;
        }
        //this.isSummaryProduct = true;
    }
    selectedProduct(event) {

        const selectedName = event.target.dataset.name;

        this.resetAllOptions();
        this.isSchemeView = false;
        this.showAccountSearch = false;
        this.isSummaryProduct = false;
        this.isProductAdded = false;

        if (selectedName == 'Summary') {
            if (this.deliveryTo == '' || this.deliveryTo == null) {
                this.deliveryTo = this.accNam;
            }
            if (this.expectedDeliveryDate == '' || this.expectedDeliveryDate == null) {
                const today = new Date();
                const tomorrow = new Date(today);
                tomorrow.setDate(today.getDate() + 1);
                this.expectedDeliveryDate = tomorrow.toISOString().split('T')[0];
            }

            this.showAccountSearch = false;
            //this.calculateTotal();
            // Recompute scheme state before rendering so the summary never shows stale engine output
            if (this.isSecondaryAccount) this.applySchemeEngine();
            var storePro = this.setProducts();
            /*if(storePro.length == 0){
                this.genericDispatchToastEvent('','Select order','warning');
                return;
            }*/
            this.resetAllOptions();
            this.orderSummery = storePro;
            this.isSummaryProduct = true;
            this.isSchemeView = false;

        }
        else if (selectedName == 'SelectedItems' && this.schemePro) {
            this.showAccountSearch = false;
            var addedProduct = [];
            const dts = this.schemePro;
            for (let i = 0; i < dts.length; i++) {
                for (let j = 0; j < dts[i].products.length; j++) {
                    if (dts[i].products[j].value != 0) {
                        addedProduct.push(dts[i].products[j]);
                    }
                }
            }

            const datas = this.productData != null ? this.productData : [];
            for (let i = 0; i < datas.length; i++) {
                if (datas[i].value != 0) {
                    addedProduct.push(datas[i]);
                }
            }

            if (addedProduct.length == 0) {
                this.genericDispatchToastEvent('', 'Select order', 'warning');
                return;
            }
            this.finalOrderPlace = addedProduct;
            this.resetAllOptions();
            this.getSelectedProduct = addedProduct;
            this.isProductAdded = true;
            this.isSchemeView = false;
        }
    }
    getFormattedDate() {
        const today = new Date();
        const day = String(today.getDate()).padStart(2, '0'); // Adds leading zero if day < 10
        const month = String(today.getMonth() + 1).padStart(2, '0'); // Months are 0-based
        const year = today.getFullYear();

        return `${day}/${month}/${year}`;
    }

    // Modify the setProducts method to group by Delivery Plan



    toggleTargetDropdown() {
        this.isDropdownOrderOpen = !this.isDropdownOrderOpen; // Toggles the boolean value
        const dropdownBody = this.template.querySelector('.dropdown-body-ord');
        const chevronIcon = this.template.querySelector('.chevron-icon');

        if (dropdownBody) {
            if (this.isDropdownOrderOpen) {
                dropdownBody.classList.add('deactive');
                chevronIcon.iconName = 'utility:chevronup'; // Switch to chevron up
                if (this.targetData.length == 0) {
                    this.offSet = 0;
                    this.getAttendanceData('My Target');

                }
            } else {
                dropdownBody.classList.remove('deactive');
                chevronIcon.iconName = 'utility:chevrondown'; // Switch back to chevron down
            }
        }
    }
    updateOriginalProductData() {
        this.isSummaryProduct = false;
        this.isProductAdded = false;
        this.isAllOrder = true;
        this.showAccountSearch = true;
        //this.productData = [...this.originalSelectedProduct];
        this.isSpecialOffer = false;
        this.isSchemeView = false;
    }

    onSaveOrder(event) {
        if (!this.deliveryTo || !this.expectedDeliveryDate) {
            this.genericDispatchToastEvent(
                'Validation Error',
                'Please fill in both "Delivery To" and "Expected Delivery Date"',
                'error'
            );
            this.isPageLoaded = false;
            return;
        }

        if (this.isModerTrade == true && !this.poDate) {
            this.genericDispatchToastEvent(
                'Validation Error',
                'Please fill "PO Date"',
                'error'
            );
            this.isPageLoaded = false;
            return;
        }

        if (this.isShowOwner == true && !this.OrderOwnerId) {
            this.isPageLoaded = false;
            this.genericDispatchToastEvent(
                'Validation Error',
                'Please fill the owner name',
                'error'
            );
            return;
        }

        const selectedDate = new Date(this.expectedDeliveryDate);
        const today = new Date();
        today.setHours(0, 0, 0, 0); // Remove time component
        selectedDate.setHours(0, 0, 0, 0);

        if (selectedDate < today) {
            this.genericDispatchToastEvent(
                'Invalid Date',
                'Expected Delivery Date must be in the future',
                'error'
            );
            this.isPageLoaded = false;
            return;
        }

        if (parseFloat(this.subTotalAmt) < parseFloat(this.minumumOrderValue)) {
            this.genericDispatchToastEvent(
                'Order Value Error',
                `The total order value must be greater than ₹${this.minumumOrderValue}. Current total (excluding tax) is ₹${this.subTotalAmt}.`,
                'error'
            );
            this.isPageLoaded = false;
            return; // Prevent saving the order if the total is less than the minimum order value
        }

        this.isPageLoaded = true;


        // Prepare order data
        const ordersData = this.plantGroups.map(plantGroup => ({
            plantName: plantGroup.plantName,
            products: plantGroup.products.map(item => {
                // Round base/before prices to 2dp so they match the already-rounded
                // discounted price; avoids spurious +/-0.01 claim amounts on no-scheme lines.
                const base2 = (this._round2(parseFloat(item.UnitPricePriceBook) || 0)).toFixed(2);
                const orig2 = (this._round2(parseFloat(item.originalUnitPrice || item.UnitPricePriceBook) || 0)).toFixed(2);
                const disc2 = item.discountedUnitPrice || base2; // already 2dp from the engine
                return {
                    Product__c: item.id,
                    Product_Category__c: item.proCate,
                    Quantity__c: (parseInt(item.value) || 0) + (parseInt(item._focMergeQty) || 0),
                    Case_Qyt__c: item.crateQty,
                    Each_Qyt__c: item.eachQty,
                    Unit_price__c: disc2,
                    Before_Category_Slab_Unit_Price__c: orig2,
                    After_Category_Slab_Unit_Price__c: base2,
                    Before_Scheme_Unit_Price__c: base2,
                    After_Scheme_Unit_Price__c: disc2,
                    Scheme_Item__c: item.schemeItemId || null,
                    Discount__c: item._lineDiscount || 0,
                    Tax__c: item.taxPercent || 0,
                    Tax_Amount__c: parseFloat(item.taxAmt),
                    Total_Amount__c: parseFloat(item.netValue),
                    SKU_Weight__c : parseFloat(item.netWeight)
                };
            }),
            categoryDiscount: this.categoryValueDiscount || 0,
            orderValueDiscount: this.orderValueDiscount || 0,
            appliedSchemes: this.appliedSchemeRecords || [],
            deliveryTo: this.deliveryTo,
            expectedDate: this.expectedDeliveryDate,
            poNum: this.poNum,
            poDate: this.poDate,
            orderOwnerId: this.OrderOwnerId
        }));
        let details = JSON.parse(JSON.stringify(event.detail));

        saveOrderItemData({
            ordersData: JSON.stringify(ordersData),
            accId: this.acccountId,
            visId: this.recordId,
            logId: this.logId,
            orderRecordId: this.orderRecordId,
            ClockInLocationLongitude: details.lon,
            ClockInLocationLatitude: details.lat,
        })
            .then(result => {
                this.genericDispatchToastEvent('Success', 'Orders saved successfully', 'success');

                // CASE 1: Called from Order object's New button
                if (this.isOrderTrue) {
                    const msg = {
                        message: 'close',
                        id: this.listView
                    };
                    const event = new CustomEvent('ClickAction', {
                        detail: msg
                    });
                    this.dispatchEvent(event);
                }
                // CASE 2: Called from parent component flow
                else {
                    const message = {
                        message: 'executeScreen',
                        screen: 3.2, // Go back to execute screen
                        orderData: result.orderData // Pass any needed data
                    };
                    this.dispatchEvent(new CustomEvent('screen4', { detail: message }));
                }
            })
            .catch(error => {
                console.error(error);
                this.genericDispatchToastEvent('Error', 'Failed to save orders', 'error');
            })
            .finally(() => {
                this.isPageLoaded = false;
            });
    }

    handleGetLatLon() {
        this.isPageLoaded = true;
        let isResolved = false;
        this.currentLocationRequestId = null;

        const requestId = Math.random().toString(36).substring(2);
        this.currentLocationRequestId = requestId;

        // Timeout fallback (applies to both mobile and browser)
        const timeoutTimer = setTimeout(() => {
            if (!isResolved) {
                this.isPageLoaded = false;

                this.currentLocationRequestId = null;
                this.genericDispatchToastEvent('Error', 'Please enable location permission to create order', 'error');
                return;
            }
        }, 30000);

        if (this.isMobilePublisher) {
            // Mobile Publisher: use Nimbus Location Service
            getLocationService().getCurrentPosition({
                enableHighAccuracy: true
            }).then((result) => {
                // Only process if this is the latest request
                if (this.currentLocationRequestId !== requestId || isResolved) return;
                isResolved = true;
                clearTimeout(timeoutTimer);
                this.currentLocationRequestId = null;

                const newEvent = new CustomEvent('locationPharmacySearch:getLatLonResponse', { detail: {} });
                newEvent.detail.lat = result.coords.latitude;
                newEvent.detail.lon = result.coords.longitude;
                newEvent.detail.latlonsource = 'nimbus';
                newEvent.detail.status = 'success';

                console.log('newEvent: ' + JSON.stringify(newEvent));
                this.onSaveOrder(newEvent);

            }).catch((error) => {
                // Only process if this is the latest request
                if (this.currentLocationRequestId !== requestId || isResolved) return;
                isResolved = true;
                clearTimeout(timeoutTimer);
                this.currentLocationRequestId = null; // Clear the request ID
                console.error('Mobile location error:', error);
                this.isPageLoaded = false;
                this.genericDispatchToastEvent('Error', 'Unable to fetch location. Please ensure location is enabled.', 'error');
            });

        } else if (window.navigator && window.navigator.geolocation) {
            // Browser: use native geolocation
            window.navigator.geolocation.getCurrentPosition(
                (r) => {
                    // Only process if this is the latest request
                    if (this.currentLocationRequestId !== requestId || isResolved) return;
                    isResolved = true;
                    clearTimeout(timeoutTimer);
                    this.currentLocationRequestId = null; // Clear the request ID

                    const newEvent = new CustomEvent('locationPharmacySearch:getLatLonResponse', { detail: {} });
                    newEvent.detail.lat = r.coords.latitude;
                    newEvent.detail.lon = r.coords.longitude;
                    newEvent.detail.latlonsource = 'browser';
                    newEvent.detail.status = 'success';

                    this.onSaveOrder(newEvent);
                },
                (err) => {
                    // Only process if this is the latest request
                    if (this.currentLocationRequestId !== requestId || isResolved) return;
                    isResolved = true;
                    clearTimeout(timeoutTimer);
                    this.currentLocationRequestId = null;
                    console.error('Browser location error:', err);
                    this.isPageLoaded = false;
                    this.genericDispatchToastEvent('Error', 'Please enable location permission to create Order', 'error');
                },
                { enableHighAccuracy: true }
            );

        } else {
            isResolved = true;
            clearTimeout(timeoutTimer);
            this.currentLocationRequestId = null; // Clear the request ID
            console.log('Location not supported');
            this.isPageLoaded = false;
            this.genericDispatchToastEvent('Error', 'Location not supported on this device.', 'error');
        }
    }

    closeModal() {
        const closeEvent = new CustomEvent('close'); // You can send a close event to the parent
        this.dispatchEvent(closeEvent);
    }

    saveStockItemList(orderLineItem) {
        saveStockItem({

            stocks: orderLineItem
        })
            .then(result => {
                this.genericDispatchToastEvent('Success', 'Stock has been saved successfully', 'success');
                const message = {
                    message: 'executeScreen',
                    screen: 3.2,
                    //orderData : this.orderData
                };
                this.genericDispatchEvent(message);
            })
            .catch(error => console.error(error))
            .finally(() => {
                this.isPageLoaded = false;
            });
    }
    saveOrderItem(orderLineItem) {
        this.isPageLoaded = true;

        saveOrderItemData({
            accId: this.acccountId,
            visId: this.recordId,
            logId: this.logId,
            ordItm: orderLineItem,
            orderRecordId: this.orderRecordId,
            deliveryTo: this.deliveryTo,
            expectedDate: this.expectedDeliveryDate,
            orderOwnerId: this.OrderOwnerId
        })
            .then(result => {
                this.orderData = result.orList;
                var message;
                if (this.isOrderTrue) {
                    const msg = {
                        message: 'Done',
                        id: result.ordRecData.Id
                    }
                    const event = new CustomEvent('ClickAction', {
                        detail: msg
                    });
                    this.dispatchEvent(event);
                }
                else if (!this.isOrderTrue) {

                    message = {
                        message: 'executeScreen',
                        screen: 3.2,
                        orderData: this.orderData
                    };
                    this.genericDispatchEvent(message);
                }
                this.genericDispatchToastEvent('Success', 'Order has been saved successfully', 'success');


            })
            .catch(error => console.error(error))
            .finally(() => {
                this.isPageLoaded = false;
            });
    }
    handleClickCancel() {
        const msg = {
            message: 'close',
            id: this.listView
        }
        const event = new CustomEvent('ClickAction', {
            detail: msg
        });
        this.dispatchEvent(event);
    }
    genericDispatchToastEvent(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
    genericDispatchEvent(message) {
        // Creating a custom event with a payload (optional)
        const event = new CustomEvent('screen4', {
            detail: message
        });

        // Dispatching the event
        this.dispatchEvent(event);
    }

    @api onChangeProducts(event) {
        const rawInput = event?.target?.value;
        const searchTerm = rawInput ? rawInput.toLowerCase().trim() : '';

        if (!searchTerm) {
            this.schemePro = this.originalSchemePro ? this.applyCategoryStyles([...this.originalSchemePro]) : [];
            return;
        }

        if (!this.originalSchemePro) {
            this.schemePro = [];
            return;
        }

        const searchWords = searchTerm.split(/\s+/).filter(word => word.length > 0);

        const filteredSchemePro = this.originalSchemePro
            .map(group => {
                const filteredProducts = group.products.filter(prod => {
                    // Check each field for ALL search words
                    const nameMatch = this.fuzzyMatch(prod.name, searchWords);
                    const mrpMatch = this.fuzzyMatch(prod.MRP?.toString(), searchWords);
                    const unitPriceMatch = this.fuzzyMatch(prod.UnitPricePriceBook?.toString(), searchWords);

                    return nameMatch || mrpMatch || unitPriceMatch;
                });

                return filteredProducts.length > 0 ? {
                    ...group,
                    products: filteredProducts
                } : null;
            })
            .filter(group => group !== null);

        this.schemePro = this.applyCategoryStyles(filteredSchemePro);
    }

    fuzzyMatch(text, searchWords) {
        if (!text) return false;

        const textLower = text.toLowerCase();
        return searchWords.every(word => textLower.includes(word));
    }
    @api onSchemeSearch(event) {
        const rawInput = event?.target?.value;
        const searchTerm = rawInput ? rawInput.toLowerCase().trim() : '';

        // Reset to original schemes if no search term
        if (!searchTerm && this.schemeOffer) {
            this.schemeOffer = [...this.originalSchemeOffer];
            return;
        }

        // Clone the original schemeOffer
        let filteredSchemeOffer = [];

        if (this.originalSchemeOffer) {
            this.originalSchemeOffer.forEach(scheme => {
                const filteredLineItems = scheme.lineItems.filter(item => {
                    // Search in Scheme Name or SKU Name (offerProductName)
                    const schemeNameMatch = scheme.name?.toLowerCase().includes(searchTerm);
                    const skuMatch = item.offerProductName?.toLowerCase().includes(searchTerm);

                    return schemeNameMatch || skuMatch;
                });

                // Add scheme to filtered list if any line items match
                if (filteredLineItems.length > 0) {
                    filteredSchemeOffer.push({
                        ...scheme,
                        lineItems: filteredLineItems
                    });
                }
            });

            this.schemeOffer = filteredSchemeOffer;
        }
    }




    handleChangeSales(event) {
        const val = event.detail.value;
        this.filterVal = val;
        if (val != 'All') {
            const foundItem = this.originalSelectedProduct.find(item => item.salesId === val);
            this.productData = foundItem ? [foundItem] : []; // Store the found item in an array or empty if not found
            this.isCategorySelected = true;

        } else {
            this.isCategorySelected = false;
            this.productData = [...this.originalSelectedProduct];
        }
    }

    @api handleChangeCategory(event) {
        // const val = event.detail.value;
        const val = event;
        this.filterVal = val;
        if (val !== 'All') {
            var foundItem = [];
            for (var i = 0; i < this.allProDtas.length; i++) {
                if (this.allProDtas[i].proCate === val) {
                    foundItem.push(this.allProDtas[i]);
                }
            }
            this.changePro = foundItem;
            // const foundItem = this.allProDtas.find(item => item.proCate === val);
            this.productData = foundItem;//? [foundItem] : []; // Store the found item in an array or empty if not found
            this.isCategorySelected = false;
            //this.proCatVal = foundItem.categoryName ?;
        } else {
            this.isCategorySelected = true;
            // this.proCatVal = 'All';
            // this.schemePro 
            this.productData = [...this.originalSelectedProduct]; // Reset to original data
        }
    }
    toggleOfferDropdown(event) {
        const index1 = parseInt(event.currentTarget.dataset.id);
        const index2 = parseInt(event.currentTarget.dataset.index);

        // Toggle the dropdown state
        this.schemePro[index1].products[index2].isDropdownTargetOpen =
            !this.schemePro[index1].products[index2].isDropdownTargetOpen;

        // Update the class and icon based on the new state
        if (this.schemePro[index1].products[index2].isDropdownTargetOpen) {
            this.schemePro[index1].products[index2].classDropDown = 'dropdown-body active';
            this.schemePro[index1].products[index2].chevronIcon = 'utility:chevronup';
        } else {
            this.schemePro[index1].products[index2].classDropDown = 'dropdown-body';
            this.schemePro[index1].products[index2].chevronIcon = 'utility:chevrondown';
        }

        // Force reactivity since we're modifying nested objects
        this.schemePro = [...this.schemePro];
    }
    handleSearch(event) {
        this.accNam = event.target.value;
        if (this.accNam !== '') {
            this.getFilteredAccounts();
            if (this.accountDataOriginal && this.accountDataOriginal.length > 0) {
                this.accountData = this.accountDataOriginal;
            } else {
                this.accountData = []; // Set empty array if no original data
            }
        } else {
            this.accountData = null;  // Reset if search term is empty
            this.schemePro = null;
            this.getSelectedProduct = null;
            this.orderSummery = null;
            // Customer removed: content collapses, so keep the card tall enough
            // that the customer search dropdown isn't clipped by .tasks overflow.
            const tasksEl = this.template.querySelector('.tasks');
            if (tasksEl) tasksEl.classList.add('force-height');
        }
    }
    handleOnBlur() {
        setTimeout(() => {
            this.accountData = null;
        }, 1000);
    }
    selectObjName(event) {
        this.acccountId = event.currentTarget.dataset.id;
        this.accNam = event.currentTarget.dataset.name;
        this.accountData = null; // close the customer search popup immediately
        this.isContentLoading = true; // show the loading screen while data loads
        this.getData();
    }
    handleCheckBoxProSceme(event) {
        const index1 = parseInt(event.currentTarget.dataset.index);
        const index2 = parseInt(event.currentTarget.dataset.index1);
        const index3 = parseInt(event.currentTarget.dataset.index1);
        this.schemePro[index1].products[index2].hoverDta[index3].isChecked = event.currentTarget.checked;
        const dt = this.schemePro[index1].products[index2].hoverDta[index3];
        for (let i = 0; i < dt.length; i++) {
            if (i != index3) {
                this.schemePro[index1].products[index2].hoverDta[index3].isChecked = false;
            }
        }

    }

    viewSchemeScreen() {
        this.resetAllOptions();
        this.isSchemeView = true;
        this.showAccountSearch = false;
        this.isSummaryProduct = false;
        this.isProductAdded = false;
    }

    loadCoverage() {
        if (!this.acccountId) return;
        getSchemeCoverageForAccount({ accountId: this.acccountId })
            .then(result => {
                this.coverageSchemes = (result && result.schemes) ? result.schemes : [];
                this.coverageProductSchemeIds = (result && result.productSchemeIds) ? result.productSchemeIds : {};
                // Recompute prices now that scheme data is available
                this.applySchemeEngine();
            })
            .catch((error) => {
                // eslint-disable-next-line no-console
                console.error('getSchemeCoverageForAccount failed', error);
                this.coverageSchemes = [];
                this.coverageProductSchemeIds = {};
            });
    }

    get hasCoverageSchemes() {
        return Array.isArray(this.coverageSchemes) && this.coverageSchemes.length > 0;
    }

    get hasHeaderDiscounts() {
        return (parseFloat(this.categoryValueDiscount) || 0) > 0
            || (parseFloat(this.orderValueDiscount) || 0) > 0;
    }

    get displayCoverageSchemes() {
        const collapsed = new Set(this.collapsedSchemeIds);
        const term = (this.coverageSearch || '').trim().toLowerCase();
        return (this.coverageSchemes || [])
            .filter(s => {
                if (!term) return true;
                if ((s.name || '').toLowerCase().includes(term)) return true;
                return (s.products || []).some(p =>
                    (p.name || '').toLowerCase().includes(term)
                    || (p.sku || '').toLowerCase().includes(term));
            })
            .map(s => {
                const isExpanded = !collapsed.has(s.id);
                return {
                    ...s,
                    isExpanded,
                    expandIcon: isExpanded ? 'utility:chevronup' : 'utility:chevrondown'
                };
            });
    }

    handleCoverageSearch(event) {
        this.coverageSearch = event.target.value || '';
    }

    get displaySchemePro() {
        if (!Array.isArray(this.schemePro)) return this.schemePro;
        const psm = this.coverageProductSchemeIds || {};
        const schemesById = {};
        for (const s of (this.coverageSchemes || [])) schemesById[s.id] = s;
        const expanded = new Set(this.expandedProductIds);
        const breakupOpen = new Set(this.breakupExpandedIds);
        return this.schemePro.map(itm => ({
            ...itm,
            products: (itm.products || []).map(p => {
                const sids = psm[p.id] || [];
                const isExpanded = expanded.has(p.id);
                const showBreakup = breakupOpen.has(p.id);
                return {
                    ...p,
                    hasSchemeGroupMatch: sids.length > 0,
                    isSchemeExpanded: isExpanded,
                    schemeExpandIcon: isExpanded ? 'utility:chevrondown' : 'utility:chevronright',
                    coveringSchemes: sids.map(id => schemesById[id]).filter(Boolean),
                    priceSteps: Array.isArray(p._priceSteps) ? p._priceSteps : [],
                    showBreakup: showBreakup,
                    breakupIcon: showBreakup ? 'utility:chevrondown' : 'utility:chevronright'
                };
            })
        }));
    }

    toggleSchemeBreakup(event) {
        const pid = event.currentTarget.dataset.productId;
        if (!pid) return;
        const next = new Set(this.breakupExpandedIds);
        if (next.has(pid)) next.delete(pid); else next.add(pid);
        this.breakupExpandedIds = Array.from(next);
    }

    toggleProductSchemes(event) {
        const pid = event.currentTarget.dataset.productId;
        if (!pid) return;
        const next = new Set(this.expandedProductIds);
        if (next.has(pid)) next.delete(pid); else next.add(pid);
        this.expandedProductIds = Array.from(next);
    }

    toggleCoverageScheme(event) {
        const sid = event.currentTarget.dataset.schemeId;
        if (!sid) return;
        const next = new Set(this.collapsedSchemeIds);
        if (next.has(sid)) next.delete(sid); else next.add(sid);
        this.collapsedSchemeIds = Array.from(next);
    }

    selectScheme(event) {
        const schemeLineId = event.currentTarget.dataset.id;

        const schemeIndex = this.schemeOffer.findIndex(s =>
            s.lineItems.some(l => l.id === schemeLineId)
        );
        const scheme = this.schemeOffer[schemeIndex];
        const lineIndex = scheme.lineItems.findIndex(l => l.id === schemeLineId);
        const lineItem = scheme.lineItems[lineIndex];
        if (lineItem) {
            const product = this.allProDtas.find(p => p.id === lineItem.productId);
            const quantity = parseInt(lineItem?.selectedQty || 0);
            const unitPrice = parseFloat(product?.UnitPricePriceBook || 0);

            if (lineItem.schemeCategory === 'Sale Value Discount') {
                const totalValue = quantity * unitPrice;
                if (totalValue < lineItem.saleValueThreshold) {
                    this.genericDispatchToastEvent(
                        'Sale Value Not Achieved',
                        `You must reach ₹${lineItem.saleValueThreshold} to avail this scheme.`,
                        'warning'
                    );
                    return;
                }
            }

            // Clear previous selections
            for (let sch of this.schemeOffer) {
                for (let li of sch.lineItems) {
                    if (li.productId === lineItem.productId) {
                        li.isSelected = false;
                        li.schemeSelected = false;
                    }
                }
            }

            lineItem.isSelected = true;
            lineItem.schemeSelected = true;
            lineItem.selectedQty = quantity || 0;

            // Update matching product in allProDtas
            if (product) {
                product.value = lineItem.selectedQty;
            }

            // ✅ Sync to schemePro also
            //this.syncQuantityToSchemePro(lineItem.productId, lineItem.selectedQty);

            // Force reactivity
            const updatedScheme = { ...scheme };
            updatedScheme.lineItems = [...scheme.lineItems];
            this.schemeOffer.splice(schemeIndex, 1, updatedScheme);
            this.schemeOffer = [...this.schemeOffer];

            // Refresh summary immediately
            this.setProducts();

            this.genericDispatchToastEvent(
                'Scheme Selected',
                `Scheme applied successfully for ${lineItem.offerProductName}`,
                'success'
            );
        }
    }



    handleSchemeQtyChange(event) {
        const lineId = event.target.dataset.id;
        const value = parseInt(event.detail.value);

        const scheme = this.schemeOffer.find(s =>
            s.lineItems.some(l => l.id === lineId)
        );
        const line = scheme?.lineItems.find(l => l.id === lineId);

        if (line && value >= line.minQty) {
            line.selectedQty = value;
            this.syncQuantityToSchemePro(line.productId, value);
        } else if (line) {
            this.genericDispatchToastEvent(
                'Invalid Quantity',
                `Please enter at least ${line.minQty}`,
                'warning'
            );
        }
    }



    handleCrateQtyChange(event) {
        const index1 = parseInt(event.target.dataset.id);
        const index2 = parseInt(event.target.dataset.index);
        const value = parseInt(event.target.value) || 0;
        const product = this.schemePro[index1].products[index2];

        product.crateQty = value;
        const totalQty = (value * (product.uomConversion || 1)) + (product.eachQty || 0);
        product.value = totalQty;
        if (value > 0 && !product.firstEntryTimestamp) {
            product.firstEntryTimestamp = new Date().getTime();
        }
        // Calculate line-wise tax and net value
        const unitPrice = product.UnitPricePriceBook;
        const netValue = (unitPrice * totalQty);

        product.total = netValue.toFixed(2);  // Rounded net value

        this._scheduleRecalc();
    }
    handleEachQtyChange(event) {
        const index1 = parseInt(event.target.dataset.id);
        const index2 = parseInt(event.target.dataset.index);
        const value = parseInt(event.target.value) || 0;
        const product = this.schemePro[index1].products[index2];

        //alert(JSON.stringify(product));
        product.eachQty = value;
        const totalQty = ((product.crateQty || 0) * (product.uomConversion || 1)) + value;
        product.value = totalQty;
        if (value > 0 && !product.firstEntryTimestamp) {
            product.firstEntryTimestamp = new Date().getTime();
        }
        // Calculate line-wise tax and net value
        const unitPrice = product.UnitPricePriceBook;
        const netValue = (unitPrice * totalQty);

        product.total = netValue.toFixed(2);  // Rounded net value

        // Debounce the heavy re-render + scheme recompute so per-keystroke typing
        // stays responsive on mobile (the native number input shows digits instantly).
        this._scheduleRecalc();
    }

    // Coalesce quantity-entry recomputes: run the scheme engine / totals + list
    // re-render once shortly after the user stops typing instead of every keystroke.
    _scheduleRecalc() {
        clearTimeout(this._recalcTimer);
        this._recalcTimer = setTimeout(() => {
            if (this.isSecondaryAccount) {
                // New Scheme__c engine owns secondary-account pricing (reassigns
                // schemePro and recalculates totals internally).
                this.applySchemeEngine();
            } else {
                if (this.schemePro) this.schemePro = [...this.schemePro];
                this.recalculateTotals();
            }
        }, 300);
    }

    syncQuantityToSchemeOffer(productId, newQty, totalValue) {
        if (this.isSecondaryAccount) return; // new Scheme__c engine handles secondary pricing
        if (!this.schemeOffer) return;

        let changed = false;

        // Loop through schemeOffer and update selectedQty for the product
        for (let scheme of this.schemeOffer) {
            for (let lineItem of scheme.lineItems) {
                if (lineItem.productId === productId) {

                    lineItem.selectedQty = newQty;



                    /*if(lineItem.schemeCategory  === 'Free Product'){
    
                        if (newQty >= lineItem.minQty) {
                        lineItem.isSelected = true;
                        lineItem.isSchemeSelected = true;
                    } else {
                        lineItem.isSelected = false;
                        lineItem.isSchemeSelected = false;
                    }
    
                    }
                    else if(lineItem.schemeCategory === 'Per UOM Discount'){
    
                         if (newQty >= lineItem.saleValueThreshold) {
                        lineItem.isSelected = true;
                        lineItem.isSchemeSelected = true;
                    } else {
                        lineItem.isSelected = false;
                        lineItem.isSchemeSelected = false;
                    }
                    }
                    else if(lineItem.schemeCategory === 'Sale Value Discount'){
    
                         if (totalValue >= lineItem.saleValueThreshold) {
                        lineItem.isSelected = true;
                        lineItem.isSchemeSelected = true;
                    } else {
                        lineItem.isSelected = false;
                        lineItem.isSchemeSelected = false;
                    }
                    }*/
                    // Apply scheme selection if the quantity is above minimum


                    // Update the product's unit price after applying the scheme
                    /*const product = this.allProDtas.find(p => p.id === productId);
                    if (product) {
                        const discountedPrice = lineItem.discountedPrice || product.UnitPricePriceBook;
                        product.UnitPricePriceBook = discountedPrice; // Update with discounted price
                        product.discountedPrice = discountedPrice; // Store discounted price
                    }*/

                    changed = true;
                }
            }
        }

        // Force reactivity by updating schemeOffer
        if (changed) {
            this.schemeOffer = [...this.schemeOffer];
        }


        this.recalculateTotals(); // Recalculate the totals after applying the discount
    }

    // LEGACY Buy_Product__c scheme engine — primary accounts only.
    // Secondary accounts are priced by the new Scheme__c engine (applySchemeEngine).
    autoSelectBestScheme(productId) {
        if (this.isSecondaryAccount) { this.applySchemeEngine(); return; }
        if (!productId) return;

        const product = this.allProDtas.find(p => p.id === productId);
        if (!product) return;

        let bestScheme = null;
        let maxSavings = 0;
        let bestSchemeDetails = null;

        // Loop through schemes and find the best one based on savings
        for (let scheme of this.schemeOffer) {
            for (let lineItem of scheme.lineItems) {
                if (lineItem.productId === productId) {
                    const savings = this.calculateSchemeBenefit(product, lineItem);
                    //alert('hello'+JSON.stringify(savings));
                    if (savings && savings.isSchemeApplied && savings.discountAmount >= maxSavings) {
                        maxSavings = savings.discountAmount;
                        bestScheme = lineItem;
                        bestSchemeDetails = savings;
                    }
                    /*else{
                        maxSavings = savings.discountAmount;
                        bestScheme = null;
                        bestSchemeDetails = savings;
                    }*/
                }
            }
        }

        // Deselect all previous schemes for the product
        for (let scheme of this.schemeOffer) {
            for (let lineItem of scheme.lineItems) {
                if (lineItem.productId === productId) {
                    lineItem.isSelected = false;
                    lineItem.schemeSelected = false;
                }
            }
        }

        // Apply the best scheme to the product
        if (bestScheme) {

            bestScheme.isSelected = true;
            bestScheme.schemeSelected = true;
            bestScheme.selectedQty = product.value || 0;

            // Track the Buy_Product__c id so it can be persisted on the Order_Item__c
            product.schemeItemId = bestScheme.id;

            // Update the product's discountedPrice with maxSavings
            //product.discountedPrice = maxSavings;
            //alert(JSON.stringify(product));

            // Now update the matching product's discountedPrice in schemePro
            for (let schemeGroup of this.schemePro) {
                for (let lineItem of schemeGroup.products) {
                    if (lineItem.id === productId) {

                        lineItem.discountedPrice = maxSavings;
                        lineItem.discountedUnitPrice = (bestSchemeDetails.finalUnitPrice).toFixed(2) || product.UnitPricePriceBook;
                        lineItem.quantity = product.quantity;
                        lineItem.appliedScheme = bestSchemeDetails.isSchemeApplied;
                        lineItem.actualQuantity = bestSchemeDetails.newQuantityFromScheme || product.quantity;// Set the discounted price for the matching product in schemePro
                        lineItem.schemeItemId = bestScheme.id;
                    }

                }
            }

            // Force reactivity by updating schemePro
            this.schemePro = [...this.schemePro];

            // Debugging: Check the updated product in schemePro
            //alert(JSON.stringify(this.schemePro)); // You can remove this after debugging
        }
        else {
            product.schemeItemId = null;
            for (let schemeGroup of this.schemePro) {
                for (let lineItem of schemeGroup.products) {
                    if (lineItem.id === productId) {

                        lineItem.discountedPrice = 0;
                        lineItem.discountedUnitPrice = product.UnitPricePriceBook;
                        lineItem.quantity = product.quantity;
                        lineItem.appliedScheme = false;
                        lineItem.actualQuantity = product.quantity;// Set the discounted price for the matching product in schemePro
                        lineItem.schemeItemId = null;
                    }

                }
            }

            // Force reactivity by updating schemePro
            this.schemePro = [...this.schemePro];
        }

        // Force reactivity by updating schemeOffer
        this.schemeOffer = [...this.schemeOffer];

        // Debugging: Check the updated schemeOffer
        //alert(JSON.stringify(this.schemeOffer)); // You can remove this after debugging
    }


    calculateSchemeBenefit(product, schemeLineItem) {

        // Define an object to hold the calculated values
        const schemeDetails = {
            isSchemeApplied: false,
            discountAmount: 0,
            newQuantityFromScheme: 0,
            finalUnitPrice: parseFloat(product.UnitPricePriceBook || 0),
            totalPrice: 0,
            discountDetails: {}
        };


        const quantity = parseInt(schemeLineItem.selectedQty || 0);
        const unitPrice = parseFloat(product.UnitPricePriceBook || 0);


        if (!quantity || !unitPrice) return schemeDetails;

        const baseTotal = quantity * unitPrice;

        // Handle Free Product Scheme
        if (schemeLineItem.schemeCategory === 'Free Product') {

            const minQty = schemeLineItem.minQty;
            const freeQty = schemeLineItem.freeQty;
            if (!minQty || !freeQty) return schemeDetails;
            if (quantity >= minQty) {
                schemeDetails.isSchemeApplied = true;
                const multiplier = Math.floor(quantity / minQty);
                const totalFree = multiplier * freeQty;
                const totalQty = quantity + totalFree;
                //Total Free quantity
                schemeDetails.newQuantityFromScheme = totalFree;
                //new unit price
                schemeDetails.finalUnitPrice = (unitPrice * quantity) / totalQty;
                //Actuall savings from this
                schemeDetails.discountAmount = (unitPrice * totalQty) - (schemeDetails.finalUnitPrice * totalQty);
                //total new price which will be equal to actual amount
                schemeDetails.totalPrice = schemeDetails.finalUnitPrice * totalQty;

                schemeDetails.discountDetails = {
                    schemeCategory: 'Free Product',
                    freeQty: totalFree,
                    discountAmount: schemeDetails.discountAmount
                };

                //product.discountedUnitPrice = schemeDetails.finalUnitPrice;
                product.quantity = totalQty;
            } else {
                product.quantity = quantity;
            }

        }
        // Handle Per UOM Discount Scheme
        else if (schemeLineItem.schemeCategory === 'Per UOM Discount') {
            const discountPerUnit = parseFloat(schemeLineItem.discountPerUOM || 0);
            if (!discountPerUnit) return null;
            if (quantity >= schemeLineItem.saleValueThreshold) {
                schemeDetails.isSchemeApplied = true;
                schemeDetails.discountAmount = discountPerUnit * quantity;
                schemeDetails.finalUnitPrice = unitPrice - discountPerUnit;
                schemeDetails.totalPrice = schemeDetails.finalUnitPrice * quantity;
                schemeDetails.discountDetails = {
                    schemeCategory: 'Per UOM Discount',
                    discountAmount: schemeDetails.discountAmount
                };

            }
            product.quantity = quantity;

        }
        // Handle Sale Value Discount Scheme
        else if (schemeLineItem.schemeCategory === 'Sale Value Discount') {

            const discountPercent = parseFloat(schemeLineItem.discountPercentOnSale || 0);
            if (!discountPercent) return null;
            if (baseTotal >= schemeLineItem.saleValueThreshold) {
                schemeDetails.isSchemeApplied = true;
                const discountedTotal = baseTotal * (1 - discountPercent / 100);
                schemeDetails.discountAmount = baseTotal - discountedTotal;
                schemeDetails.finalUnitPrice = discountedTotal / quantity;
                schemeDetails.totalPrice = discountedTotal;

                schemeDetails.discountDetails = {
                    schemeCategory: 'Sale Value Discount',
                    discountAmount: schemeDetails.discountAmount
                };

                //product.discountedUnitPrice = schemeDetails.finalUnitPrice;
                product.quantity = quantity;
            }
        }


        // Return the object with all the details
        //alert(JSON.stringify(schemeDetails));
        return schemeDetails;
    }


    recalculateTotals() {
        let totalQty = 0;
        let totalAmt = 0;
        let totalTaxAmt = 0;

        const allProducts = [...(this.schemePro || []), ...(this.productData ? [{ products: this.productData }] : [])];

        // Loop through all products and calculate totals
        for (const group of allProducts) {
            for (const item of group.products) {
                const quantity = parseFloat(item.value || 0);
                // Secondary accounts: use the scheme engine's discounted price; primary keeps base.
                const price = this.isSecondaryAccount
                    ? parseFloat(item.discountedUnitPrice || item.UnitPricePriceBook)
                    : parseFloat(item.UnitPricePriceBook);

                totalQty += quantity;
                totalAmt += quantity * price;

                // Calculate tax based on the discounted price
                const taxAmt = (price * quantity) * (parseFloat(item.taxPercent || 0) / 100);
                totalTaxAmt += taxAmt;
            }
        }

        // Update the summary values
        this.totalSelectedQuantity = totalQty;
        this.totalSelectedAmount = totalAmt.toFixed(2);
        this.totalTaxAmt = totalTaxAmt.toFixed(2);
        this.grandTotalAmt = (totalAmt + totalTaxAmt).toFixed(2);
        this.subTotalAmt = totalAmt.toFixed(2);
        // Net payable after order-wide scheme discounts (category value + order value)
        const headerDisc = (parseFloat(this.categoryValueDiscount) || 0) + (parseFloat(this.orderValueDiscount) || 0);
        this.netPayable = Math.max(0, (totalAmt + totalTaxAmt) - headerDisc).toFixed(2);
    }

    /* =========================================================================
     * Scheme engine (Scheme__c / Scheme_Slab__c / Scheme_Product_Group__c).
     * Runs only for Secondary accounts. Applies five passes in fixed order over
     * the live order items, sets per-line discounted prices (Free Quantity /
     * QPS), adds FOC giveaway lines, and computes order-wide Category Value /
     * Order Value discounts. Idempotent: every run resets to base price first.
     * ========================================================================= */

    _round2(n) {
        const v = parseFloat(n) || 0;
        return Math.round((v + Number.EPSILON) * 100) / 100;
    }

    _gstMult(item) {
        return 1 + (parseFloat(item.taxPercent || 0) / 100);
    }

    // Flat list of live order-item refs (scheme groups + other products).
    _allEngineItems() {
        const out = [];
        (this.schemePro || []).forEach(g => (g.products || []).forEach(p => { if (p) out.push(p); }));
        (this.productData || []).forEach(p => { if (p) out.push(p); });
        return out;
    }

    _groupMembers(scheme) {
        const ids = new Set((scheme.groupProductIds || []).map(String));
        return this._allEngineItems().filter(p => ids.has(String(p.id)) && (parseFloat(p.value) || 0) > 0);
    }

    // Highest qualifying slab by quantity (qtyMin treated as 0, null qtyMax as +inf).
    _pickSlabByQty(slabs, qty) {
        let best = null;
        (slabs || []).forEach(sl => {
            const mn = (sl.qtyMin != null) ? parseFloat(sl.qtyMin) : 0;
            const mx = (sl.qtyMax != null) ? parseFloat(sl.qtyMax) : null;
            if (qty >= mn && (mx == null || qty <= mx)) {
                const bestMn = (best && best.qtyMin != null) ? parseFloat(best.qtyMin) : -1;
                if (!best || mn > bestMn) best = sl;
            }
        });
        return best;
    }

    // Slab whose value range contains val (valMin treated as 0, null valMax as +inf).
    _pickSlabByValue(slabs, val) {
        let best = null;
        (slabs || []).forEach(sl => {
            const mn = (sl.valMin != null) ? parseFloat(sl.valMin) : 0;
            const mx = (sl.valMax != null) ? parseFloat(sl.valMax) : null;
            if (val >= mn && (mx == null || val <= mx)) {
                const bestMn = (best && best.valMin != null) ? parseFloat(best.valMin) : -1;
                if (!best || mn > bestMn) best = sl;
            }
        });
        return best;
    }

    _flagLine(m, scheme) {
        m.appliedScheme = true;
        if (!m._appliedSchemeId) m._appliedSchemeId = scheme.id;
        m.schemeLabel = scheme.name;
    }

    // Record a step in a line's price-breakup ledger (Base -> Free Quantity -> QPS ...).
    _addPriceStep(m, label) {
        if (!Array.isArray(m._priceSteps)) m._priceSteps = [];
        m._priceSteps.push({ key: 'step-' + m._priceSteps.length, label: label, price: this._round2(m._wkUnit).toFixed(2) });
    }

    // Partition applicable schemes by type. FOC Giveaway, Free Quantity and QPS
    // all apply independently to their own groups (no cross-type exclusion).
    buildSchemeContext() {
        const byType = {
            'Free Quantity': [], 'QPS': [], 'FOC Giveaway': [],
            'Category Value': [], 'Order Value': []
        };
        (this.coverageSchemes || []).forEach(s => {
            if (byType[s.schemeType]) byType[s.schemeType].push(s);
        });
        return { byType, skipped: [] };
    }

    // ORDER 1 — Free Quantity (group based)
    _pass1FreeQuantity(byType) {
        byType['Free Quantity'].forEach(scheme => {
            const members = this._groupMembers(scheme);
            const totalQty = members.reduce((s, m) => s + (parseFloat(m.value) || 0), 0);
            if (totalQty <= 0) return;
            const slab = this._pickSlabByQty(scheme.slabsRaw, totalQty);
            if (!slab || !slab.qtyMin || parseFloat(slab.qtyMin) <= 0 || !slab.freeQty) return;
            const free = Math.floor(totalQty / parseFloat(slab.qtyMin)) * parseFloat(slab.freeQty);
            if (free <= 0) return;
            const factor = totalQty / (totalQty + free);
            members.forEach(m => {
                const before = m._wkUnit;
                m._wkUnit = m._wkUnit * factor;
                this._flagLine(m, scheme);
                this._addPriceStep(m, 'Free Quantity — ' + scheme.name);
                // one record per affected order item -> links Order_Item__c on save
                this.appliedSchemeRecords.push({
                    productId: m.id,
                    schemeId: scheme.id, slabId: slab.slabId, schemeType: 'Free Quantity',
                    freeQty: free, benefitAmount: this._round2((this._round2(before) - this._round2(m._wkUnit)) * (parseFloat(m.value) || 0)),
                    sequence: slab.seq,
                    description: 'Free Quantity: ' + free + ' EA free on ' + totalQty + ' EA'
                });
            });
        });
    }

    // ORDER 2 — QPS (group based, price after Order 1)
    _pass2QPS(byType) {
        byType['QPS'].forEach(scheme => {
            const members = this._groupMembers(scheme);
            const totalQty = members.reduce((s, m) => s + (parseFloat(m.value) || 0), 0);
            if (totalQty <= 0) return;
            const slab = this._pickSlabByQty(scheme.slabsRaw, totalQty);
            if (!slab || slab.benefitAmtPerEA == null) return;
            const off = parseFloat(slab.benefitAmtPerEA);
            members.forEach(m => {
                const before = m._wkUnit;
                m._wkUnit = Math.max(0, m._wkUnit - off);
                this._flagLine(m, scheme);
                this._addPriceStep(m, 'QPS — ' + scheme.name);
                // one record per affected order item -> links Order_Item__c on save
                this.appliedSchemeRecords.push({
                    productId: m.id,
                    schemeId: scheme.id, slabId: slab.slabId, schemeType: 'QPS',
                    benefitAmount: this._round2((this._round2(before) - this._round2(m._wkUnit)) * (parseFloat(m.value) || 0)),
                    sequence: slab.seq,
                    description: 'QPS: ₹' + off + ' off per EA'
                });
            });
        });
    }

    // ORDER 3 — FOC Giveaway (group based; merges if FOC product is also ordered)
    _pass3FOCGiveaway(byType) {
        byType['FOC Giveaway'].forEach(scheme => {
            const members = this._groupMembers(scheme);
            const totalQty = members.reduce((s, m) => s + (parseFloat(m.value) || 0), 0);
            if (totalQty <= 0) return;
            const slab = this._pickSlabByQty(scheme.slabsRaw, totalQty);
            if (!slab || !slab.qtyMin || parseFloat(slab.qtyMin) <= 0 || !slab.freeQty || !slab.focProductId) return;
            const focQty = Math.floor(totalQty / parseFloat(slab.qtyMin)) * parseFloat(slab.freeQty);
            if (focQty <= 0) return;
            const focPrice = parseFloat(slab.focUnitPrice) || 0;
            const focTax = parseFloat(slab.focTaxPercent) || 0;
            const existing = this._allEngineItems().find(p => String(p.id) === String(slab.focProductId) && (parseFloat(p.value) || 0) > 0);
            if (existing) {
                existing._focMergeQty = (existing._focMergeQty || 0) + focQty;
                existing._focMergeDiscount = (existing._focMergeDiscount || 0) + (focPrice * focQty);
                existing.appliedScheme = true;
                existing.schemeLabel = scheme.name;
                if (!existing._appliedSchemeId) existing._appliedSchemeId = scheme.id;
                if (Array.isArray(existing._priceSteps)) {
                    existing._priceSteps.push({ key: 'step-' + existing._priceSteps.length, label: 'FOC Giveaway — ' + focQty + ' EA free', price: this._round2(existing._wkUnit).toFixed(2) });
                }
            } else {
                this.focLines.push({
                    id: slab.focProductId,
                    name: slab.focProductName,
                    isFOC: true,
                    value: focQty,
                    crateQty: 0,
                    eachQty: focQty,
                    proCate: null,
                    UnitPricePriceBook: focPrice,
                    originalUnitPrice: focPrice,
                    discountedUnitPrice: focPrice.toFixed(2),
                    taxPercent: focTax,
                    netWeight: 0,
                    _lineDiscount: this._round2(focPrice * focQty),
                    _appliedSchemeId: scheme.id,
                    appliedScheme: true,
                    schemeLabel: scheme.name
                });
            }
            this.appliedSchemeRecords.push({
                productId: slab.focProductId, // links to the giveaway / merged order line
                schemeId: scheme.id, slabId: slab.slabId, schemeType: 'FOC Giveaway',
                freeQty: focQty, benefitAmount: this._round2(this._round2(focPrice) * focQty),
                focProductId: slab.focProductId, sequence: slab.seq,
                description: 'FOC Giveaway: ' + focQty + ' EA of ' + (slab.focProductName || 'product')
            });
        });
    }

    // ORDER 4 — Category Value (sub-group based, header discount)
    _pass4CategoryValue(byType) {
        byType['Category Value'].forEach(scheme => {
            const cat = scheme.productCategory;
            if (!cat) return;
            const members = this._allEngineItems().filter(p =>
                p.subGroup === cat && (parseFloat(p.value) || 0) > 0);
            // Base on the rounded per-line price (discountedUnitPrice = round2(_wkUnit))
            // so the discount matches the displayed GST-inclusive subtotal.
            const catVal = this._round2(members.reduce((s, m) =>
                s + (this._round2(m._wkUnit) * (parseFloat(m.value) || 0) * this._gstMult(m)), 0));
            if (catVal <= 0) return;
            const slab = this._pickSlabByValue(scheme.slabsRaw, catVal);
            if (!slab || slab.benefitPercent == null) return;
            const pct = parseFloat(slab.benefitPercent);
            const disc = catVal * pct / 100;
            this.categoryValueDiscount += disc;
            this.appliedSchemeRecords.push({
                schemeId: scheme.id, slabId: slab.slabId, schemeType: 'Category Value',
                discountPercent: pct, benefitAmount: this._round2(disc), sequence: slab.seq,
                description: 'Category Value: ' + pct + '% on ' + cat
            });
        });
    }

    // ORDER 5 — Order Value (whole order, header discount)
    _pass5OrderValue(byType) {
        byType['Order Value'].forEach(scheme => {
            const members = this._allEngineItems().filter(p => (parseFloat(p.value) || 0) > 0);
            // Base on the rounded per-line price so the discount equals pct% of the
            // displayed Total Amount (grandTotalAmt also uses round2(_wkUnit)).
            const orderVal = this._round2(members.reduce((s, m) =>
                s + (this._round2(m._wkUnit) * (parseFloat(m.value) || 0) * this._gstMult(m)), 0));
            if (orderVal <= 0) return;
            const slab = this._pickSlabByValue(scheme.slabsRaw, orderVal);
            if (!slab || slab.benefitPercent == null) return;
            const pct = parseFloat(slab.benefitPercent);
            const disc = orderVal * pct / 100;
            this.orderValueDiscount += disc;
            this.appliedSchemeRecords.push({
                schemeId: scheme.id, slabId: slab.slabId, schemeType: 'Order Value',
                discountPercent: pct, benefitAmount: this._round2(disc), sequence: slab.seq,
                description: 'Order Value: ' + pct + '% on order'
            });
        });
    }

    applySchemeEngine() {
        if (!this.isSecondaryAccount) return;
        try {
            this._runSchemeEngine();
        } catch (e) {
            // Never let a pricing-engine error break the screen or wipe scheme coverage.
            // eslint-disable-next-line no-console
            console.error('applySchemeEngine failed', e);
            try { this.recalculateTotals(); } catch (ignore) { /* noop */ }
        }
    }

    _runSchemeEngine() {
        const items = this._allEngineItems();

        // Reset working state to base price (idempotent across runs)
        items.forEach(p => {
            const base = parseFloat(p.UnitPricePriceBook) || 0;
            p._baseUnit = base;
            p._wkUnit = base;
            p.appliedScheme = false;
            p._appliedSchemeId = null;
            p.schemeLabel = null;
            p._focMergeQty = 0;
            p._focMergeDiscount = 0;
            p._lineDiscount = 0;
            p._priceSteps = [{ key: 'base', label: 'Base Price', price: base.toFixed(2) }];
            p.discountedUnitPrice = base.toFixed(2);
            p.discountedPrice = base * (parseFloat(p.value) || 0);
        });
        this.focLines = [];
        this.categoryValueDiscount = 0;
        this.orderValueDiscount = 0;
        this.appliedSchemeRecords = [];

        const ctx = this.buildSchemeContext();
        this._pass1FreeQuantity(ctx.byType);
        this._pass2QPS(ctx.byType);
        this._pass3FOCGiveaway(ctx.byType);
        this._pass4CategoryValue(ctx.byType);
        this._pass5OrderValue(ctx.byType);

        // Write back per-line results
        items.forEach(p => {
            const finalUnit = this._round2(p._wkUnit);
            const base2 = this._round2(p._baseUnit);
            const qty = parseFloat(p.value) || 0;
            p.discountedUnitPrice = finalUnit.toFixed(2);
            p.discountedPrice = finalUnit * qty;
            p._lineDiscount = this._round2((base2 - finalUnit) * qty + (p._focMergeDiscount || 0));
            if (finalUnit !== base2 || (p._focMergeQty || 0) > 0) p.appliedScheme = true;
        });
        this.categoryValueDiscount = this._round2(this.categoryValueDiscount);
        this.orderValueDiscount = this._round2(this.orderValueDiscount);

        // Reactivity + downstream recompute
        if (this.schemePro) this.schemePro = [...this.schemePro];
        this.recalculateTotals();
        if (this.isSummaryProduct) this.setProducts();

        // Warn once per distinct invalid-combination signature
        const sig = ctx.skipped.slice().sort().join('|');
        if (ctx.skipped.length && sig !== this._lastInvalidSig) {
            this.genericDispatchToastEvent(
                'Schemes Skipped',
                'These schemes were not applied (invalid combination): ' + ctx.skipped.join(', '),
                'warning'
            );
        }
        this._lastInvalidSig = sig;
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


    /*setProducts() {
        let plantGroups = {};
        let grandTotalAmt = 0;
        let totalTaxAmt = 0;
        let subTotalAmt = 0;
        let totalQnt = 0;
        let totalNetWeight = 0; // NEW: Total net weight across all products
        let alternateUOMGroups = {}; // NEW: Group by AlterNateUOM
    
        // ✅ SAFELY HANDLE SCHEMES & PRODUCTS
        const schemeArray = Array.isArray(this.schemePro) ? this.schemePro : [];
        const otherProArray = Array.isArray(this.productData) ? this.productData : [];
    
        // Check if the customer is a Secondary Customer
        const isSecondaryCustomer = this.isPrimaryAccount === false;
    
        // Collect all products with quantities for sorting
        let allProductsWithQty = [];
    
        // If the customer is a Secondary Customer, skip the plant grouping logic
        if (isSecondaryCustomer) {
            // Process all products as one group without separating by plant
            const allProducts = [...schemeArray, ...otherProArray];
    
            allProducts.forEach(group => {
                (group.products || [group]).forEach(product => {
                    if (product.value > 0) {
                        allProductsWithQty.push({
                            product: product,
                            groupType: 'secondary',
                            originalGroup: group
                        });
                    }
                });
            });
    
            // Sort by entry order (oldest first)
            allProductsWithQty.sort((a, b) => {
                const timeA = a.product.firstEntryTimestamp || 0;
                const timeB = b.product.firstEntryTimestamp || 0;
                return timeA - timeB;
            });
    
            // Process sorted products
            allProductsWithQty.forEach(item => {
                const product = item.product;
                const unitPrice = parseFloat(product.discountedUnitPrice || product.UnitPricePriceBook);
                const crateQty = parseInt(product.crateQty || 0);
                const eachQty = parseInt(product.eachQty || 0);
                const uomConv = parseFloat(product.uomConversion || 1);
                const quantity = product.quantity || product.value;
                const netWeight = parseFloat(product.netWeight || 0); // NEW: Get net weight
    
                const taxPercent = parseFloat(product.taxPercent || 0);
                const totalOriginalPrice = unitPrice * quantity;
                const totalDiscount = totalOriginalPrice - product.discountedPrice;
                const taxAmt = parseFloat(((unitPrice * quantity) * (taxPercent / 100)).toFixed(2));
                const netTotal = parseFloat(((unitPrice * quantity) + taxAmt).toFixed(2));
    
                // NEW: Calculate product net weight and add to total
                const productNetWeight = netWeight * quantity;
                totalNetWeight += productNetWeight;
    
                // NEW: Group by AlterNateUOM
                const alternateUOM = 'EA';
                if (!alternateUOMGroups[alternateUOM]) {
                    alternateUOMGroups[alternateUOM] = {
                        alternateUOM: alternateUOM,
                        totalCaseQty: 0,
                        totalEachQty: 0,
                        products: []
                    };
                }
                alternateUOMGroups[alternateUOM].totalCaseQty += crateQty;
                alternateUOMGroups[alternateUOM].totalEachQty += eachQty;
                alternateUOMGroups[alternateUOM].products.push(product);
    
                // Only one group for all products
                plantGroups['All Products'] = plantGroups['All Products'] || {
                    plantName: 'All Products',
                    products: [],
                    plantSubTotal: 0,
                    plantTax: 0,
                    plantTotal: 0
                };
    
                plantGroups['All Products'].products.push({
                    ...product,
                    displayQty: quantity,
                    unitPrice: unitPrice.toFixed(2),
                    taxPercent,
                    taxAmt: taxAmt.toFixed(2),
                    netValue: netTotal.toFixed(2),
                    netWeight: netWeight, // NEW: Include net weight
                    productNetWeight: productNetWeight.toFixed(2) // NEW: Individual product weight
                });
    
                // Update plant totals with fixed decimals
                plantGroups['All Products'].plantSubTotal = parseFloat((plantGroups['All Products'].plantSubTotal + (unitPrice * quantity)).toFixed(2));
                plantGroups['All Products'].plantTax = parseFloat((plantGroups['All Products'].plantTax + taxAmt).toFixed(2));
                plantGroups['All Products'].plantTotal = parseFloat((plantGroups['All Products'].plantTotal + netTotal).toFixed(2));
    
                // Update running totals with fixed decimals
                subTotalAmt = parseFloat((subTotalAmt + (unitPrice * quantity)).toFixed(2));
                totalTaxAmt = parseFloat((totalTaxAmt + taxAmt).toFixed(2));
                grandTotalAmt = parseFloat((grandTotalAmt + netTotal).toFixed(2));
                totalQnt += quantity;
            });
        } else {
            // If the customer is a Primary Customer, proceed with the original grouping logic
            // First collect all products for sorting
            [...schemeArray, ...otherProArray].forEach(group => {
                (group.products || [group]).forEach(product => {
                    if (product.value > 0) {
                        allProductsWithQty.push({
                            product: product,
                            groupType: 'primary',
                            originalGroup: group
                        });
                    }
                });
            });
    
            // Sort by entry order (oldest first)
            allProductsWithQty.sort((a, b) => {
                const timeA = a.product.firstEntryTimestamp || 0;
                const timeB = b.product.firstEntryTimestamp || 0;
                return timeA - timeB;
            });
    
            // Process sorted products
            allProductsWithQty.forEach(item => {
                const product = item.product;
                const plant = product.deliveryPlant || '';
                const crateQty = parseInt(product.crateQty || 0);
                const eachQty = parseInt(product.eachQty || 0);
                const uomConv = parseFloat(product.uomConversion || 1);
                const quantity = (crateQty * uomConv) + eachQty;
                const netWeight = parseFloat(product.netWeight || 0); // NEW: Get net weight
    
                const baseUnitPrice = parseFloat(product.UnitPricePriceBook.toFixed(2) || 0);
                const taxPercent = parseFloat(product.taxPercent || 0);
    
                const taxAmt = (baseUnitPrice * quantity) * (taxPercent / 100);
                const netTotal = (baseUnitPrice * quantity) + taxAmt;
    
                // NEW: Calculate product net weight and add to total
                const productNetWeight = netWeight * quantity;
                totalNetWeight += productNetWeight;
    
                // NEW: Group by AlterNateUOM
                const alternateUOM = product.AlterNateUOM || 'N/A';
                if (!alternateUOMGroups[alternateUOM]) {
                    alternateUOMGroups[alternateUOM] = {
                        alternateUOM: alternateUOM,
                        totalCaseQty: 0,
                        totalEachQty: 0,
                        products: []
                    };
                }
                alternateUOMGroups[alternateUOM].totalCaseQty += crateQty;
                alternateUOMGroups[alternateUOM].totalEachQty += eachQty;
                alternateUOMGroups[alternateUOM].products.push(product);
    
                if (!plantGroups[plant]) {
                    plantGroups[plant] = {
                        plantName: 'Delivery Plant : ' + plant,
                        products: [],
                        plantSubTotal: 0,
                        plantTax: 0,
                        plantTotal: 0
                    };
                }
    
                plantGroups[plant].products.push({
                    ...product,
                    displayQty: quantity,
                    unitPrice: baseUnitPrice.toFixed(2),
                    taxPercent,
                    taxAmt: taxAmt.toFixed(2),
                    netValue: netTotal.toFixed(2),
                    netWeight: netWeight, // NEW: Include net weight
                    productNetWeight: productNetWeight.toFixed(2) // NEW: Individual product weight
                });
    
                plantGroups[plant].plantSubTotal += parseFloat((baseUnitPrice * quantity).toFixed(2));
                plantGroups[plant].plantTax += taxAmt;
                plantGroups[plant].plantTotal += netTotal;
    
                subTotalAmt += baseUnitPrice * quantity;
                totalTaxAmt += taxAmt;
                grandTotalAmt += netTotal;
                totalQnt += quantity;
            });
        }
    
        this.plantGroups = Object.values(plantGroups);
        this.totalQnt = totalQnt;
        this.subTotalAmt = subTotalAmt.toFixed(2);
        this.totalTaxAmt = totalTaxAmt.toFixed(2);
        this.grandTotalAmt = grandTotalAmt.toFixed(2);
        this.totalNetWeight = totalNetWeight.toFixed(2); // NEW: Store total net weight
        this.alternateUOMGroups = Object.values(alternateUOMGroups); // NEW: Store grouped alternate UOM data
    }*/


    setProducts() {
        let plantGroups = {};
        let grandTotalAmt = 0;
        let totalTaxAmt = 0;
        let subTotalAmt = 0;
        let totalQnt = 0;
        let totalNetWeight = 0; // NEW: Total net weight across all products
        let alternateUOMGroups = {}; // NEW: Group by AlterNateUOM

        // ✅ SAFELY HANDLE SCHEMES & PRODUCTS
        const schemeArray = Array.isArray(this.schemePro) ? this.schemePro : [];
        const otherProArray = Array.isArray(this.productData) ? this.productData : [];

        // Check if the customer is a Secondary Customer
        const isSecondaryCustomer = this.isPrimaryAccount === false;

        // Collect all products with quantities for sorting
        let allProductsWithQty = [];

        // If the customer is a Secondary Customer, skip the plant grouping logic
        if (isSecondaryCustomer) {
            // Process all products as one group without separating by plant
            const allProducts = [...schemeArray, ...otherProArray];

            allProducts.forEach(group => {
                (group.products || [group]).forEach(product => {
                    if (product.value > 0) {
                        allProductsWithQty.push({
                            product: product,
                            groupType: 'secondary',
                            originalGroup: group
                        });
                    }
                });
            });

            // Sort by entry order (oldest first)
            allProductsWithQty.sort((a, b) => {
                const timeA = a.product.firstEntryTimestamp || 0;
                const timeB = b.product.firstEntryTimestamp || 0;
                return timeA - timeB;
            });

            // Process sorted products
            allProductsWithQty.forEach(item => {
                const product = item.product;
                const unitPrice = parseFloat(product.discountedUnitPrice || product.UnitPricePriceBook);
                const crateQty = parseInt(product.crateQty || 0);
                const eachQty = parseInt(product.eachQty || 0);
                const uomConv = parseFloat(product.uomConversion || 1);
                const quantity = product.quantity || product.value;
                const netWeight = parseFloat(product.netWeight || 0); // NEW: Get net weight

                const taxPercent = parseFloat(product.taxPercent || 0);
                const totalOriginalPrice = unitPrice * quantity;
                const totalDiscount = totalOriginalPrice - product.discountedPrice;
                const taxAmt = parseFloat(((unitPrice * quantity) * (taxPercent / 100)).toFixed(2));
                const netTotal = parseFloat(((unitPrice * quantity) + taxAmt).toFixed(2));

                // NEW: Calculate product net weight and add to total
                const productNetWeight = netWeight * quantity;
                totalNetWeight += productNetWeight;

                // NEW: Group by AlterNateUOM
                const alternateUOM = 'EA';
                if (!alternateUOMGroups[alternateUOM]) {
                    alternateUOMGroups[alternateUOM] = {
                        alternateUOM: alternateUOM,
                        totalCaseQty: 0,
                        totalEachQty: 0,
                        products: []
                    };
                }
                alternateUOMGroups[alternateUOM].totalCaseQty += crateQty;
                alternateUOMGroups[alternateUOM].totalEachQty += eachQty;
                alternateUOMGroups[alternateUOM].products.push(product);

                // Only one group for all products
                plantGroups['All Products'] = plantGroups['All Products'] || {
                    plantName: 'All Products',
                    products: [],
                    plantSubTotal: 0,
                    plantTax: 0,
                    plantTotal: 0,
                    plantCaseQyt: 0,
                    plantEachQyt: 0,
                    plantProductWeight: 0
                };

                plantGroups['All Products'].products.push({
                    ...product,
                    displayQty: quantity,
                    focFreeQty: parseInt(product._focMergeQty) || 0, // FOC giveaway units merged into this paid line
                    unitPrice: unitPrice.toFixed(2),
                    taxPercent,
                    taxAmt: taxAmt.toFixed(2),
                    netValue: netTotal.toFixed(2),
                    netWeight: netWeight, // NEW: Include net weight
                    productNetWeight: productNetWeight.toFixed(2),
                    caseQuantity: crateQty,
                    eachQuantity: eachQty // NEW: Individual product weight
                });

                // Update plant totals with fixed decimals
                plantGroups['All Products'].plantSubTotal = parseFloat((plantGroups['All Products'].plantSubTotal + (unitPrice * quantity)).toFixed(2));
                plantGroups['All Products'].plantTax = parseFloat((plantGroups['All Products'].plantTax + taxAmt).toFixed(2));
                plantGroups['All Products'].plantTotal = parseFloat((plantGroups['All Products'].plantTotal + netTotal).toFixed(2));
                plantGroups['All Products'].plantCaseQyt += crateQty;
                plantGroups['All Products'].plantEachQyt += eachQty;
                plantGroups['All Products'].plantProductWeight += productNetWeight;

                // Update running totals with fixed decimals
                subTotalAmt = parseFloat((subTotalAmt + (unitPrice * quantity)).toFixed(2));
                totalTaxAmt = parseFloat((totalTaxAmt + taxAmt).toFixed(2));
                grandTotalAmt = parseFloat((grandTotalAmt + netTotal).toFixed(2));
                totalQnt += quantity;
            });

            // Append FOC giveaway lines (net 0) produced by the scheme engine
            if (Array.isArray(this.focLines) && this.focLines.length > 0 && plantGroups['All Products']) {
                this.focLines.forEach(foc => {
                    const focQty = parseFloat(foc.value) || 0;
                    plantGroups['All Products'].products.push({
                        ...foc,
                        displayQty: focQty,
                        unitPrice: (parseFloat(foc.UnitPricePriceBook) || 0).toFixed(2),
                        taxPercent: parseFloat(foc.taxPercent) || 0,
                        taxAmt: '0.00',
                        netValue: '0.00',
                        netWeight: 0,
                        productNetWeight: '0.00',
                        caseQuantity: 0,
                        eachQuantity: focQty
                    });
                    plantGroups['All Products'].plantEachQyt += focQty;
                });
            }
        } else {
            // If the customer is a Primary Customer, proceed with the original grouping logic
            // First collect all products for sorting
            [...schemeArray, ...otherProArray].forEach(group => {
                (group.products || [group]).forEach(product => {
                    if (product.value > 0) {
                        allProductsWithQty.push({
                            product: product,
                            groupType: 'primary',
                            originalGroup: group
                        });
                    }
                });
            });

            // Sort by entry order (oldest first)
            allProductsWithQty.sort((a, b) => {
                const timeA = a.product.firstEntryTimestamp || 0;
                const timeB = b.product.firstEntryTimestamp || 0;
                return timeA - timeB;
            });

            // Process sorted products
            allProductsWithQty.forEach(item => {
                const product = item.product;
                const plant = product.deliveryPlant || '';
                const crateQty = parseInt(product.crateQty || 0);
                const eachQty = parseInt(product.eachQty || 0);
                const uomConv = parseFloat(product.uomConversion || 1);
                const quantity = (crateQty * uomConv) + eachQty;
                const netWeight = parseFloat(product.netWeight || 0); // NEW: Get net weight

                const baseUnitPrice = parseFloat(product.UnitPricePriceBook.toFixed(2) || 0);
                const taxPercent = parseFloat(product.taxPercent || 0);

                const taxAmt = (baseUnitPrice * quantity) * (taxPercent / 100);
                const netTotal = (baseUnitPrice * quantity) + taxAmt;

                // NEW: Calculate product net weight and add to total
                const productNetWeight = netWeight * quantity;
                totalNetWeight += productNetWeight;

                // NEW: Group by AlterNateUOM
                const alternateUOM = product.AlterNateUOM || 'N/A';
                if (!alternateUOMGroups[alternateUOM]) {
                    alternateUOMGroups[alternateUOM] = {
                        alternateUOM: alternateUOM,
                        totalCaseQty: 0,
                        totalEachQty: 0,
                        products: []
                    };
                }
                alternateUOMGroups[alternateUOM].totalCaseQty += crateQty;
                alternateUOMGroups[alternateUOM].totalEachQty += eachQty;
                alternateUOMGroups[alternateUOM].products.push(product);

                if (!plantGroups[plant]) {
                    plantGroups[plant] = {
                        plantName: 'Delivery Plant : ' + plant,
                        products: [],
                        plantSubTotal: 0,
                        plantTax: 0,
                        plantTotal: 0,
                        plantCaseQyt: 0,
                        plantEachQyt: 0,
                        plantProductWeight: 0
                    };
                }

                plantGroups[plant].products.push({
                    ...product,
                    displayQty: quantity,
                    unitPrice: baseUnitPrice.toFixed(2),
                    taxPercent,
                    taxAmt: taxAmt.toFixed(2),
                    netValue: netTotal.toFixed(2),
                    netWeight: netWeight, // NEW: Include net weight
                    productNetWeight: productNetWeight.toFixed(2),
                    caseQuantity: crateQty,
                    eachQuantity: eachQty // NEW: Individual product weight
                });

                plantGroups[plant].plantSubTotal += parseFloat((baseUnitPrice * quantity).toFixed(2));
                plantGroups[plant].plantTax += taxAmt;
                plantGroups[plant].plantTotal += netTotal;
                plantGroups[plant].plantCaseQyt += crateQty;
                plantGroups[plant].plantEachQyt += eachQty;
                plantGroups[plant].plantProductWeight += productNetWeight;

                subTotalAmt += baseUnitPrice * quantity;
                totalTaxAmt += taxAmt;
                grandTotalAmt += netTotal;
                totalQnt += quantity;
            });
        }

        this.plantGroups = Object.values(plantGroups);
        // Round each plant's totals to 2 decimals (avoids float artifacts like 3336.5600000000004 / 257.20000000000005)
        this.plantGroups.forEach(g => {
            g.plantSubTotal      = (parseFloat(g.plantSubTotal) || 0).toFixed(2);
            g.plantTax           = (parseFloat(g.plantTax) || 0).toFixed(2);
            g.plantTotal         = (parseFloat(g.plantTotal) || 0).toFixed(2);
            g.plantProductWeight = (parseFloat(g.plantProductWeight) || 0).toFixed(2);
        });
        this.totalQnt = totalQnt;
        this.subTotalAmt = subTotalAmt.toFixed(2);
        this.totalTaxAmt = totalTaxAmt.toFixed(2);
        this.grandTotalAmt = grandTotalAmt.toFixed(2);
        // Net payable after order-wide scheme discounts (category value + order value)
        const headerDisc = (parseFloat(this.categoryValueDiscount) || 0) + (parseFloat(this.orderValueDiscount) || 0);
        this.netPayable = Math.max(0, grandTotalAmt - headerDisc).toFixed(2);
        this.totalNetWeight = totalNetWeight.toFixed(2); // NEW: Store total net weight
        this.alternateUOMGroups = Object.values(alternateUOMGroups); // NEW: Store grouped alternate UOM data
    }


}