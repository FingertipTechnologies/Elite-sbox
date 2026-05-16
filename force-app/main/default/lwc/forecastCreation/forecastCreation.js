import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import PRODUCT_FORECAST_OBJECT from '@salesforce/schema/Product_Forecast__c';
import SUB_GROUP_FIELD from '@salesforce/schema/Product_Forecast__c.Product_Sub_Group__c';
import MONTH_FIELD from '@salesforce/schema/Product_Forecast__c.Forecast_Month__c';
import YEAR_FIELD from '@salesforce/schema/Product_Forecast__c.Forecast_Year__c';
import UOM_FIELD from '@salesforce/schema/Product_Forecast__c.Forecast_UOM__c';

import getProductsBySubGroup from '@salesforce/apex/ForecastSubmissionController.getProductsBySubGroup';
import saveAndSubmit from '@salesforce/apex/ForecastSubmissionController.saveAndSubmit';

export default class ForecastCreation extends LightningElement {
    isLoading = false;

    distributorId;
    subGroup;
    productId;
    month;
    year;
    uom = 'KG';
    quantity;

    @track subGroupOptions = [];
    @track monthOptions = [];
    @track yearOptions = [];
    @track uomOptions = [];
    @track productOptions = [];

    defaultRecordTypeId;

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
        return !this.subGroup;
    }

    handleDistributorChange(e) { this.distributorId = e.detail.recordId; }
    handleSubGroupChange(e) {
        this.subGroup = e.detail.value;
        this.productId = null;
        this.loadProducts();
    }
    handleProductChange(e) { this.productId = e.detail.value; }
    handleMonthChange(e)   { this.month = e.detail.value; }
    handleYearChange(e)    { this.year = e.detail.value; }
    handleUomChange(e)     { this.uom = e.detail.value; }
    handleQuantityChange(e){ this.quantity = e.detail.value; }

    loadProducts() {
        if (!this.subGroup) {
            this.productOptions = [];
            return;
        }
        this.isLoading = true;
        getProductsBySubGroup({ subGroup: this.subGroup })
            .then(rows => {
                this.productOptions = (rows || []).map(p => ({
                    label: p.Sku_Name__c ? `${p.Name} (${p.Sku_Name__c})` : p.Name,
                    value: p.Id
                }));
            })
            .catch(err => this.toast('Error', this.errMsg(err), 'error'))
            .finally(() => { this.isLoading = false; });
    }

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
        if (err) { this.toast('Validation', err, 'warning'); return; }

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
                    this.toast('Success', res.message || 'Submitted for approval.', 'success');
                    this.resetForm();
                } else {
                    this.toast('Error', (res && res.message) || 'Submission failed.', 'error');
                }
            })
            .catch(err => this.toast('Error', this.errMsg(err), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    resetForm() {
        this.distributorId = null;
        this.subGroup = null;
        this.productId = null;
        this.month = null;
        this.year = null;
        this.uom = 'KG';
        this.quantity = null;
        this.productOptions = [];
    }

    errMsg(err) {
        return (err && err.body && err.body.message) || (err && err.message) || JSON.stringify(err);
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
