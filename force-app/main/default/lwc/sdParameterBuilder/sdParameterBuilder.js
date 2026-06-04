import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

import getAllObjects from '@salesforce/apex/TAM_TargetCriteria_Controller.getAllObjects';
import getFields from '@salesforce/apex/TAM_FieldMetadata_Service.getFields';
import getFocusedPacks from '@salesforce/apex/SDParameter_Controller.getFocusedPacks';
import getParameter from '@salesforce/apex/SDParameter_Controller.getParameter';
import saveParameter from '@salesforce/apex/SDParameter_Controller.save';

import SD_OBJECT from '@salesforce/schema/S_D_Parameter__c';
import CHANNEL_FIELD from '@salesforce/schema/S_D_Parameter__c.Sales_Channel__c';

const OPERATOR_OPTIONS = [
    { label: 'SUM', value: 'SUM' },
    { label: 'COUNT', value: 'COUNT' },
    { label: 'FOCUS PACK VOLUME', value: 'FOCUS_PACK_VOLUME' },
    { label: 'FOCUS PACK REVENUE', value: 'FOCUS_PACK_REVENUE' }
];

export default class SdParameterBuilder extends LightningElement {
    @api recordId;

    @track param = {
        Name: '',
        Object__c: '',
        Operator__c: 'SUM',
        Field__c: '',
        User_Field__c: '',
        Focused_Pack__c: '',
        Sales_Channel__c: '',
        Filter_Logic__c: '',
        Is_Active__c: true
    };

    @track filters = [];
    @track fieldsMetadata = [];

    operatorOptions = OPERATOR_OPTIONS;
    objectOptions = [];
    focusedPackOptions = [];
    channelOptions = [];
    isLoading = false;

    _defaultRecordTypeId;

    // ===== lifecycle =====
    connectedCallback() {
        this.isLoading = true;
        Promise.all([this.loadObjects(), this.loadFocusedPacks()])
            .then(() => (this.recordId ? this.loadExisting() : null))
            .catch((e) => this.toast('Error', this.errMessage(e), 'error'))
            .finally(() => (this.isLoading = false));
    }

    // ===== channel picklist (Chanel GVS) via UI API =====
    @wire(getObjectInfo, { objectApiName: SD_OBJECT })
    objectInfo({ data }) {
        if (data) this._defaultRecordTypeId = data.defaultRecordTypeId;
    }

    @wire(getPicklistValues, { recordTypeId: '$_defaultRecordTypeId', fieldApiName: CHANNEL_FIELD })
    channelPicklist({ data }) {
        if (data) {
            this.channelOptions = data.values.map((v) => ({ label: v.label, value: v.value }));
        }
    }

    // ===== data loaders =====
    loadObjects() {
        return getAllObjects().then((rows) => {
            this.objectOptions = (rows || []).map((r) => ({
                label: `${r.label} (${r.api})`,
                value: r.api
            }));
        });
    }

    loadFocusedPacks() {
        return getFocusedPacks().then((rows) => {
            this.focusedPackOptions = rows || [];
        });
    }

    loadFields(objectName) {
        if (!objectName) {
            this.fieldsMetadata = [];
            return Promise.resolve();
        }
        return getFields({ objectName }).then((rows) => {
            this.fieldsMetadata = rows || [];
        });
    }

    loadExisting() {
        return getParameter({ parameterId: this.recordId }).then((rec) => {
            this.param = {
                Name: rec.Name || '',
                Object__c: rec.Object__c || '',
                Operator__c: rec.Operator__c || 'SUM',
                Field__c: rec.Field__c || '',
                User_Field__c: rec.User_Field__c || '',
                Focused_Pack__c: rec.Focused_Pack__c || '',
                Sales_Channel__c: rec.Sales_Channel__c || '',
                Filter_Logic__c: rec.Filter_Logic__c || '',
                Is_Active__c: rec.Is_Active__c === undefined ? true : rec.Is_Active__c
            };
            if (rec.Filters__c) {
                try {
                    const parsed = JSON.parse(rec.Filters__c);
                    this.filters = parsed.filters || [];
                } catch (e) {
                    this.filters = [];
                }
            }
            return this.loadFields(rec.Object__c);
        });
    }

    // ===== operator-aware visibility =====
    get isAggregateOperator() {
        return this.param.Operator__c === 'SUM' || this.param.Operator__c === 'COUNT';
    }
    get isFocusPackOperator() {
        return (
            this.param.Operator__c === 'FOCUS_PACK_VOLUME' ||
            this.param.Operator__c === 'FOCUS_PACK_REVENUE'
        );
    }
    get isSum() {
        return this.param.Operator__c === 'SUM';
    }

    get fieldOptions() {
        return this.fieldsMetadata.map((f) => ({ label: `${f.label} (${f.apiName})`, value: f.apiName }));
    }
    get userFieldOptions() {
        return this.fieldsMetadata
            .filter((f) => f.isUserField)
            .map((f) => ({ label: `${f.label} (${f.apiName})`, value: f.apiName }));
    }
    get headerTitle() {
        return this.recordId ? 'Edit S&D Parameter' : 'New S&D Parameter';
    }

    // ===== handlers =====
    handleField(event) {
        const field = event.target.dataset.field;
        this.param = { ...this.param, [field]: event.target.value };
    }
    handleActive(event) {
        this.param = { ...this.param, Is_Active__c: event.target.checked };
    }
    handleOperatorChange(event) {
        const value = event.detail.value;
        const next = { ...this.param, Operator__c: value };
        // Clear inputs that no longer apply to the chosen operator.
        if (value === 'FOCUS_PACK_VOLUME' || value === 'FOCUS_PACK_REVENUE') {
            next.Field__c = '';
        } else {
            next.Focused_Pack__c = '';
        }
        this.param = next;
    }
    handleObjectChange(event) {
        const value = event.detail.value;
        this.param = { ...this.param, Object__c: value, Field__c: '', User_Field__c: '' };
        this.filters = [];
        this.isLoading = true;
        this.loadFields(value).finally(() => (this.isLoading = false));
    }
    handleComboChange(event) {
        const field = event.target.dataset.field;
        this.param = { ...this.param, [field]: event.detail.value };
    }
    handleFilterChange(event) {
        this.filters = event.detail.filters || event.detail || [];
    }

    // ===== save / cancel =====
    handleSave() {
        if (!this.validate()) return;

        const record = { ...this.param };
        if (this.recordId) record.Id = this.recordId;
        record.Filters__c = this.filters && this.filters.length ? JSON.stringify({ filters: this.filters }) : null;
        if (!record.Focused_Pack__c) record.Focused_Pack__c = null;
        if (!record.Sales_Channel__c) record.Sales_Channel__c = null;

        this.isLoading = true;
        saveParameter({ parameter: record })
            .then((saved) => {
                this.toast('Success', 'S&D Parameter saved', 'success');
                this.dispatchEvent(new CustomEvent('done', { detail: { recordId: saved.Id } }));
            })
            .catch((e) => this.toast('Error', this.errMessage(e), 'error'))
            .finally(() => (this.isLoading = false));
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    validate() {
        if (!this.param.Name) {
            this.toast('Required', 'Enter a parameter name', 'warning');
            return false;
        }
        if (!this.param.Operator__c) {
            this.toast('Required', 'Choose an operator', 'warning');
            return false;
        }
        if (this.isAggregateOperator && !this.param.Object__c) {
            this.toast('Required', 'Choose a source object', 'warning');
            return false;
        }
        if (this.isSum && !this.param.Field__c) {
            this.toast('Required', 'Choose a field to SUM', 'warning');
            return false;
        }
        if (this.isFocusPackOperator && !this.param.Focused_Pack__c) {
            this.toast('Required', 'Choose a Focused Pack', 'warning');
            return false;
        }
        return true;
    }

    // ===== helpers =====
    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    errMessage(e) {
        return (e && e.body && e.body.message) || (e && e.message) || 'Unexpected error';
    }
}
