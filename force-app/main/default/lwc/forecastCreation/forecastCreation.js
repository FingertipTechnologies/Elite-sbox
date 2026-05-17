import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import FORM_FACTOR from '@salesforce/client/formFactor';
import PRODUCT_FORECAST_OBJECT from '@salesforce/schema/Product_Forecast__c';
import SUB_GROUP_FIELD from '@salesforce/schema/Product_Forecast__c.Product_Sub_Group__c';
import MONTH_FIELD from '@salesforce/schema/Product_Forecast__c.Forecast_Month__c';
import YEAR_FIELD from '@salesforce/schema/Product_Forecast__c.Forecast_Year__c';
import UOM_FIELD from '@salesforce/schema/Product_Forecast__c.Forecast_UOM__c';

import searchProducts from '@salesforce/apex/ForecastSubmissionController.searchProducts';
import saveAndSubmit from '@salesforce/apex/ForecastSubmissionController.saveAndSubmit';

export default class ForecastCreation extends LightningElement {
    isLoading = false;
    isDesktop = false;
    isPhone = false;
    containerClass = 'slds-modal__container';
    fieldClass = 'slds-size_1-of-2 slds-p-bottom_small';

    distributorId;
    subGroup;
    productId;
    productName = '';
    month;
    year;
    uom = 'KG';
    quantity;

    @track subGroupOptions = [];
    @track monthOptions = [];
    @track yearOptions = [];
    @track uomOptions = [];
    @track searchedProducts = [];
    isShowProductValues = false;

    defaultRecordTypeId;
    searchDebounce;

    

    displayInfo = {
        primaryField: "Name",
        additionalFields: ["SAP_Customer_Code__c"]
    };
    matchingInfo = {
        primaryField: { fieldPath: "Name", mode: "contains" },
        additionalFields: [
            { fieldPath: "SAP_Customer_Code__c", mode: "contains" }
        ]
    };
    accountFilter = {
        criteria: [
            {
                fieldPath: "Customer_Type__c",
                operator: "eq",
                value: "Primary Customer"
            }
        ]
    };

    connectedCallback() {
        this.isDesktop = FORM_FACTOR === 'Large';
        this.isPhone = FORM_FACTOR === 'Small';
        if (FORM_FACTOR === 'Medium') this.isDesktop = true;
        this.fieldClass = this.isDesktop
            ? 'slds-size_1-of-2 slds-p-bottom_small'
            : 'slds-size_1-of-1 slds-p-bottom_small';
    }

    @wire(getObjectInfo, { objectApiName: PRODUCT_FORECAST_OBJECT })
    objectInfoHandler({ data }) {
        if (data) {
            this.defaultRecordTypeId = data.defaultRecordTypeId;
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$defaultRecordTypeId', fieldApiName: SUB_GROUP_FIELD })
    subGroupHandler({ data }) {
        if (data) this.subGroupOptions = this.toOptions(data.values);
    }

    @wire(getPicklistValues, { recordTypeId: '$defaultRecordTypeId', fieldApiName: MONTH_FIELD })
    monthHandler({ data }) {
        if (data) this.monthOptions = this.toOptions(data.values);
    }

    @wire(getPicklistValues, { recordTypeId: '$defaultRecordTypeId', fieldApiName: YEAR_FIELD })
    yearHandler({ data }) {
        if (data) this.yearOptions = this.toOptions(data.values);
    }

    @wire(getPicklistValues, { recordTypeId: '$defaultRecordTypeId', fieldApiName: UOM_FIELD })
    uomHandler({ data }) {
        if (data) this.uomOptions = this.toOptions(data.values);
    }

    toOptions(values) {
        return values.map(v => ({ label: v.label, value: v.value }));
    }

    get isProductDisabled() {
        return !this.distributorId || !this.subGroup;
    }

    handleDistributorChange(e) {
        this.distributorId = e.detail.recordId;
        this.clearProduct();
    }

    handleSubGroupChange(e) {
        this.subGroup = e.detail.value;
        this.clearProduct();
    }

    handleProductSearch(e) {
        const term = e.target.value || '';
        this.productName = term;
        this.productId = null;

        if (!this.distributorId || !this.subGroup) {
            this.isShowProductValues = false;
            this.searchedProducts = [];
            return;
        }

        if (this.searchDebounce) {
            clearTimeout(this.searchDebounce);
        }
        this.searchDebounce = setTimeout(() => {
            searchProducts({
                distributorId: this.distributorId,
                subGroup: this.subGroup,
                searchKey: term
            })
                .then(rows => {
                    this.searchedProducts = rows || [];
                    this.isShowProductValues = this.searchedProducts.length > 0;
                })
                .catch(err => {
                    this.isShowProductValues = false;
                    this.searchedProducts = [];
                    this.toast('Error', this.errMsg(err), 'error');
                });
        }, 250);
    }

    selectProduct(e) {
        this.productId = e.currentTarget.dataset.id;
        this.productName = e.currentTarget.dataset.name;
        this.isShowProductValues = false;
    }

    clearProduct() {
        this.productId = null;
        this.productName = '';
        this.searchedProducts = [];
        this.isShowProductValues = false;
    }

    handleMonthChange(e)    { this.month = e.detail.value; }
    handleYearChange(e)     { this.year = e.detail.value; }
    handleUomChange(e)      { this.uom = e.detail.value; }
    handleQuantityChange(e) { this.quantity = e.detail.value; }

    validate() {
        if (!this.distributorId) return 'Distributor is required.';
        if (!this.subGroup)      return 'Product Sub Group is required.';
        if (!this.month)         return 'Forecast Month is required.';
        if (!this.year)          return 'Forecast Year is required.';
        if (!this.uom)           return 'UOM is required.';
        if (!this.quantity || Number(this.quantity) <= 0) return 'Quantity must be greater than 0.';
        return null;
    }

    handleSaveAndSubmit() {
        const err = this.validate();
        if (err) {
            this.toast('Validation', err, 'warning');
            return;
        }

        const record = {
            sobjectType: 'Product_Forecast__c',
            Distributor__c: this.distributorId,
            Product_Sub_Group__c: this.subGroup,
            Product__c: this.productId || null,
            Forecast_Month__c: this.month,
            Forecast_Year__c: this.year,
            Forecast_UOM__c: this.uom,
            Forecast__c: Number(this.quantity)
        };

        this.isLoading = true;

        saveAndSubmit({ record })
            .then(res => {
                if (res && res.success) {
                    const recordId = res.recordId;
                    this.toast('Success', res.message || 'Submitted for approval.', 'success');
                    this.dispatchToAura('Done', recordId);
                    this.resetForm();
                } else {
                    const rawMsg = (res && res.message) || 'Submission failed.';
                    this.toast('Error', this.extractValidationMessage(rawMsg), 'error');
                }
            })
            .catch(err => this.toast('Error', this.extractValidationMessage(this.getRawMessage(err)), 'error'))
            .finally(() => {
                this.isLoading = false;
            });
    }

    getRawMessage(err) {
        try {
            const body = err?.body;

            const pageErrors = body?.output?.errors;
            if (pageErrors && pageErrors.length > 0) {
                return pageErrors[0].message;
            }

            const fieldErrors = body?.output?.fieldErrors;
            if (fieldErrors) {
                for (const field in fieldErrors) {
                    const list = fieldErrors[field];
                    if (list && list.length > 0) return list[0].message;
                }
            }

            if (body?.message) return body.message;
            if (typeof err === 'string') return err;
            return err?.message || 'An unexpected error occurred.';
        } catch (e) {
            return 'An unexpected error occurred.';
        }
    }

    extractValidationMessage(rawMessage) {
        if (!rawMessage) return 'An unexpected error occurred.';

        // Extract everything after "FIELD_CUSTOM_VALIDATION_EXCEPTION, "
        const match = rawMessage.match(/FIELD_CUSTOM_VALIDATION_EXCEPTION,\s*(.+)/s);
        if (match) {
            return match[1].replace(/:\s*\[\]$/, '').trim();
        }

        return rawMessage;
    }

    resetForm() {
        this.distributorId = null;
        this.subGroup = null;
        this.clearProduct();
        this.month = null;
        this.year = null;
        this.uom = 'KG';
        this.quantity = null;
    }

    errMsg(err) {
        return (err && err.body && err.body.message) || (err && err.message) || JSON.stringify(err);
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    cancel() {
        this.dispatchToAura('Cancel',null);
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
}