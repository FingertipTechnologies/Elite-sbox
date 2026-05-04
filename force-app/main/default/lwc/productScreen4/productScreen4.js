import { LightningElement, api, track, wire } from 'lwc';
import getApexData from '@salesforce/apex/beatPlannerlwc.getSchemeWiseOrderData';
import getAccountData from '@salesforce/apex/beatPlannerlwc.getAccountData';
import getAccountsByArea from '@salesforce/apex/beatPlannerlwc.getAccountsByArea';
import saveOrderItemData from '@salesforce/apex/beatPlannerlwc.upsertOrder';
import saveStockItem from '@salesforce/apex/beatPlannerlwc.upsertStock';
import getAreaOptions from '@salesforce/apex/beatPlannerlwc.getAreaOptions';
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
    @track isShowOwner = false;
    @track productData = [];
    @track getSelectedProduct = [];
    @track deliveryTo = '';
    @track expectedDeliveryDate = '';
    @track OrderOwnerId = '';
    @track poNum = '';
    @track poDate = '';
    @track minumumOrderValue = '';
    @track isSchemeView = false;
    @track areaFilter = '';  // Default to no filter
    @track accounts = [];    // Accounts data from Apex
    @track areaOptions = []; // Dropdown options for Area
    @track isLoading = false;
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

        // CASE 1: Create Mode + accountId (from related list New override)
        if (!this.orderRecordId && this.isOrderTrue && this.acccountId) {
            //alert('1');
            this.isFieldsDisabled = false;
            this.forceHeight = true;

            /*getAccountData({areaFilter: this.areaFilter })
                .then(result => {
                    this.accountDataOriginal = result.Account;
                    this.listView = result.listViewRecords.Id;
    
                    const foundAcc = result.Account.find(acc => acc.Id === this.acccountId);
                    if (foundAcc) {
                        this.accNam = foundAcc.Name;
                        this.isPrimaryAccount = foundAcc.Customer_Type__c === 'Primary Customer';
                        this.isSecondaryAccount = acc.Customer_Type__c === 'Secondary Customer';
                        this.getData();
                    }
                })
                .catch(error => {
                    console.error('Account fetch error:', error);
                });*/

            return; // prevent going below
        }

        // CASE 2: Create Mode + No accountId
        if (!this.orderRecordId && this.isOrderTrue) {
            this.isFieldsDisabled = true;
            this.forceHeight = true;
            this.showAreaSearch = true;
            this.getAccountData();
            return;
        }

        // CASE 3: Edit Mode
        if (this.orderRecordId && this.isOrderTrue) {
            this.isFieldsDisabled = false;
            this.showAreaSearch = false;
            this.getAccountData(); // for fetching account name
            this.getData();
            return;
        }

        // CASE 4: Non-order flow
        if (!this.isOrderTrue) {
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
        getAccountsByArea({ area: this.areaFilter, searchTerm: this.accNam })
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
                this.accountDataOriginal = result.Account;
                this.listView = result.listViewRecords.Id;
            })
            .catch(error => {
                console.error(error);
                this.isPageLoaded = false;
            });
    }
    getData() {
        getApexData({
            visitId: this.recordId,
            AccountId: this.acccountId,
            orderRecordId: this.orderRecordId
        })
            .then(result => {
                this.resultData = result;
                this.originalResultData = result;
                this.acccountId = result.orderAccountId;
                this.productData = result.allOtherProducts.length !== 0 ? result.allOtherProducts : null;
                this.originalSelectedProduct = result.allOtherProducts.length !== 0 ? result.allOtherProducts : null;

                this.schemePro = result.strategyProductMapList.length !== 0 ? result.strategyProductMapList : null;
                this.originalSchemePro = result.strategyProductMapList.length !== 0 ? result.strategyProductMapList : null;
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

                    if (this.schemePro) {
                        this.schemePro.forEach((schemeGroup) => {
                            schemeGroup.products.forEach((product) => {
                                if (existingQty[product.id]) {
                                    product.value = existingQty[product.id].Quantity__c;
                                    product.crateQty = existingQty[product.id].Case_Qyt__c;
                                    product.eachQty = existingQty[product.id].Each_Qyt__c;
                                }
                            });
                        });
                    }

                    if (this.productData) {
                        this.productData.forEach((product) => {
                            if (existingQty[product.id]) {
                                product.value = existingQty[product.id];
                                product.crateQty = existingQty[product.id].Case_Qyt__c;
                                product.eachQty = existingQty[product.id].Each_Qyt__c;
                            }
                        });
                    }

                    if (this.allProDtas) {
                        this.allProDtas.forEach((product) => {
                            if (existingQty[product.id]) {
                                product.value = existingQty[product.id];
                            }
                        });
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
            })
            .catch(error => {
                console.error(error);
                this.isPageLoaded = false;
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
        this.autoSelectBestScheme(productId);
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
                this.allProDtas[i].hoverDta = this.schemePro[index1].hoverDta;
                this.allProDtas[i].offer = this.schemePro[index1].offer;
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
        this.autoSelectBestScheme(productId);
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
                this.allProDtas[i].hoverDta = this.schemePro[index1].hoverDta;
                this.allProDtas[i].offer = this.schemePro[index1].offer;
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
            this.autoSelectBestScheme(productId);
            var dta = this.productData[index1];
            for (var i = 0; i < this.allProDtas.length; i++) {
                if (dta.id == this.allProDtas[i].id) {
                    this.allProDtas[i].value = value;
                    this.allProDtas[i].hoverDta = this.schemePro[index1].hoverDta;
                    this.allProDtas[i].offer = this.schemePro[index1].offer;
                    break;
                }
            }
        } else {
            this.schemePro[index1].value = 0;
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
            products: plantGroup.products.map(item => ({
                Product__c: item.id,
                Product_Category__c: item.proCate,
                Quantity__c: item.value,
                Case_Qyt__c: item.crateQty,
                Each_Qyt__c: item.eachQty,
                Unit_price__c: item.discountedUnitPrice || item.UnitPricePriceBook,
                Before_Category_Slab_Unit_Price__c: item.originalUnitPrice || item.UnitPricePriceBook,
                After_Category_Slab_Unit_Price__c: item.UnitPricePriceBook,
                Before_Scheme_Unit_Price__c: item.UnitPricePriceBook,
                After_Scheme_Unit_Price__c: item.discountedUnitPrice || item.UnitPricePriceBook,
                Tax__c: item.taxPercent || 0,
                Tax_Amount__c: parseFloat(item.taxAmt),
                Total_Amount__c: parseFloat(item.netValue),
                SKU_Weight__c : parseFloat(item.netWeight)
            })),
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
            this.schemePro = this.originalSchemePro ? [...this.originalSchemePro] : [];
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

        this.schemePro = filteredSchemePro;
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

        this.schemePro = [...this.schemePro];
        //this.syncQuantityToSchemeOffer(product.id, totalQty);
        //this.autoSelectBestScheme(product.id);
        this.recalculateTotals();
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

        //alert(product.total);
        //alert(JSON.stringify(product));
        // Ensure reactivity
        this.schemePro = [...this.schemePro];
        if (this.isSecondaryAccount) {
            this.syncQuantityToSchemeOffer(product.id, totalQty, product.total);
            this.autoSelectBestScheme(product.id);
        }
        this.recalculateTotals();

    }

    syncQuantityToSchemeOffer(productId, newQty, totalValue) {
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

    autoSelectBestScheme(productId) {
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
                    }

                }
            }

            // Force reactivity by updating schemePro
            this.schemePro = [...this.schemePro];

            // Debugging: Check the updated product in schemePro
            //alert(JSON.stringify(this.schemePro)); // You can remove this after debugging
        }
        else {
            for (let schemeGroup of this.schemePro) {
                for (let lineItem of schemeGroup.products) {
                    if (lineItem.id === productId) {

                        lineItem.discountedPrice = 0;
                        lineItem.discountedUnitPrice = product.UnitPricePriceBook;
                        lineItem.quantity = product.quantity;
                        lineItem.appliedScheme = false;
                        lineItem.actualQuantity = product.quantity;// Set the discounted price for the matching product in schemePro
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
                const price = parseFloat(item.UnitPricePriceBook); // Use discounted price if available

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
        this.totalQnt = totalQnt;
        this.subTotalAmt = subTotalAmt.toFixed(2);
        this.totalTaxAmt = totalTaxAmt.toFixed(2);
        this.grandTotalAmt = grandTotalAmt.toFixed(2);
        this.totalNetWeight = totalNetWeight.toFixed(2); // NEW: Store total net weight
        this.alternateUOMGroups = Object.values(alternateUOMGroups); // NEW: Store grouped alternate UOM data
    }


}