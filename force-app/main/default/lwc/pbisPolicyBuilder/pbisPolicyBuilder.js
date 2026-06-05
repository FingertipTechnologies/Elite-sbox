import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

import getPolicy from '@salesforce/apex/PBISPolicy_Controller.getPolicy';
import savePolicy from '@salesforce/apex/PBISPolicy_Controller.savePolicy';

import POLICY_OBJECT from '@salesforce/schema/PBIS_Policy__c';
import CHANNELS_FIELD from '@salesforce/schema/PBIS_Policy__c.Sales_Channels__c';
import SLAB_OBJECT from '@salesforce/schema/PBIS_Incentive_Slab__c';
import PROFILE_FIELD from '@salesforce/schema/PBIS_Incentive_Slab__c.Profile__c';

const BASIS_OPTIONS = [
    { label: 'Value', value: 'Value' },
    { label: 'Volume', value: 'Volume' }
];

export default class PbisPolicyBuilder extends LightningElement {
    @api recordId;

    @track policy = {
        Name: '',
        Sales_Channels__c: [],
        Basis__c: 'Value',
        Is_Active__c: true,
        Description__c: ''
    };

    @track slabs = [];

    basisOptions = BASIS_OPTIONS;
    channelOptions = [];
    profileOptions = [];
    isLoading = false;

    _rowSeq = 1;
    _policyRtId;
    _slabRtId;

    // ===== lifecycle =====
    connectedCallback() {
        if (this.recordId) {
            this.isLoading = true;
            this.loadExisting().finally(() => (this.isLoading = false));
        } else {
            this.addSlab();
        }
    }

    // ===== picklists via UI API =====
    @wire(getObjectInfo, { objectApiName: POLICY_OBJECT })
    policyInfo({ data }) {
        if (data) this._policyRtId = data.defaultRecordTypeId;
    }
    @wire(getPicklistValues, { recordTypeId: '$_policyRtId', fieldApiName: CHANNELS_FIELD })
    channelPicklist({ data }) {
        if (data) this.channelOptions = data.values.map((v) => ({ label: v.label, value: v.value }));
    }
    @wire(getObjectInfo, { objectApiName: SLAB_OBJECT })
    slabInfo({ data }) {
        if (data) this._slabRtId = data.defaultRecordTypeId;
    }
    @wire(getPicklistValues, { recordTypeId: '$_slabRtId', fieldApiName: PROFILE_FIELD })
    profilePicklist({ data }) {
        if (data) this.profileOptions = data.values.map((v) => ({ label: v.label, value: v.value }));
    }

    // ===== load =====
    loadExisting() {
        return getPolicy({ policyId: this.recordId })
            .then((bundle) => {
                const p = bundle.policy;
                this.policy = {
                    Name: p.Name || '',
                    Sales_Channels__c: p.Sales_Channels__c ? p.Sales_Channels__c.split(';') : [],
                    Basis__c: p.Basis__c || 'Value',
                    Is_Active__c: p.Is_Active__c === undefined ? true : p.Is_Active__c,
                    Description__c: p.Description__c || ''
                };
                this.slabs = (bundle.slabs || []).map((s) => ({
                    key: `r${this._rowSeq++}`,
                    Id: s.Id,
                    Profile__c: s.Profile__c,
                    Slab_Number__c: s.Slab_Number__c,
                    Achievement_From__c: s.Achievement_From__c,
                    Achievement_To__c: s.Achievement_To__c,
                    Monthly_Incentive_Percent__c: s.Monthly_Incentive_Percent__c,
                    Quarterly_Incentive_Percent__c: s.Quarterly_Incentive_Percent__c,
                    Is_Active__c: s.Is_Active__c
                }));
                if (this.slabs.length === 0) this.addSlab();
            })
            .catch((e) => this.toast('Error', this.errMessage(e), 'error'));
    }

    get headerTitle() {
        return this.recordId ? 'Edit PBIS Policy' : 'New PBIS Policy';
    }

    // ===== header handlers =====
    handlePolicyField(event) {
        const field = event.target.dataset.field;
        this.policy = { ...this.policy, [field]: event.target.value };
    }
    handleBasis(event) {
        this.policy = { ...this.policy, Basis__c: event.detail.value };
    }
    handleChannels(event) {
        this.policy = { ...this.policy, Sales_Channels__c: event.detail.value };
    }
    handleActive(event) {
        this.policy = { ...this.policy, Is_Active__c: event.target.checked };
    }

    // ===== slab handlers =====
    addSlab() {
        this.slabs = [
            ...this.slabs,
            {
                key: `r${this._rowSeq++}`,
                Id: null,
                Profile__c: '',
                Slab_Number__c: this.slabs.length + 1,
                Achievement_From__c: null,
                Achievement_To__c: null,
                Monthly_Incentive_Percent__c: null,
                Quarterly_Incentive_Percent__c: null,
                Is_Active__c: true
            }
        ];
    }
    removeSlab(event) {
        const key = event.currentTarget.dataset.key;
        this.slabs = this.slabs.filter((s) => s.key !== key);
    }
    handleSlabValue(event) {
        const key = event.currentTarget.dataset.key;
        const field = event.currentTarget.dataset.field;
        const value = event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value;
        this.slabs = this.slabs.map((s) => (s.key === key ? { ...s, [field]: value } : s));
    }
    handleSlabActive(event) {
        const key = event.currentTarget.dataset.key;
        const checked = event.target.checked;
        this.slabs = this.slabs.map((s) => (s.key === key ? { ...s, Is_Active__c: checked } : s));
    }

    // ===== save / cancel =====
    handleSave() {
        if (!this.validate()) return;

        const policyRecord = {
            Name: this.policy.Name,
            Sales_Channels__c: (this.policy.Sales_Channels__c || []).join(';'),
            Basis__c: this.policy.Basis__c,
            Is_Active__c: this.policy.Is_Active__c,
            Description__c: this.policy.Description__c
        };
        if (this.recordId) policyRecord.Id = this.recordId;

        const slabRecords = this.slabs.map((s) => {
            const rec = {
                Profile__c: s.Profile__c || null,
                Slab_Number__c: s.Slab_Number__c || null,
                Achievement_From__c: s.Achievement_From__c || null,
                Achievement_To__c: s.Achievement_To__c || null,
                Monthly_Incentive_Percent__c: s.Monthly_Incentive_Percent__c || null,
                Quarterly_Incentive_Percent__c: s.Quarterly_Incentive_Percent__c || null,
                Is_Active__c: s.Is_Active__c
            };
            if (s.Id) rec.Id = s.Id;
            return rec;
        });

        this.isLoading = true;
        savePolicy({ policy: policyRecord, slabs: slabRecords })
            .then((bundle) => {
                this.toast('Success', 'PBIS Policy saved', 'success');
                this.dispatchEvent(new CustomEvent('done', { detail: { recordId: bundle.policy.Id } }));
            })
            .catch((e) => this.toast('Error', this.errMessage(e), 'error'))
            .finally(() => (this.isLoading = false));
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    validate() {
        if (!this.policy.Name) {
            this.toast('Required', 'Enter a policy name', 'warning');
            return false;
        }
        if (!this.policy.Sales_Channels__c || this.policy.Sales_Channels__c.length === 0) {
            this.toast('Required', 'Select at least one sales channel', 'warning');
            return false;
        }
        for (const s of this.slabs) {
            if (!s.Profile__c) {
                this.toast('Required', 'Each slab needs a Profile', 'warning');
                return false;
            }
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
