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

// Default slab bands seeded for every new profile card.
const DEFAULT_SLABS = [
    { Slab_Number__c: 1, Achievement_From__c: 90, Achievement_To__c: 94.99 },
    { Slab_Number__c: 2, Achievement_From__c: 95, Achievement_To__c: 99.99 },
    { Slab_Number__c: 3, Achievement_From__c: 100, Achievement_To__c: 109.99 },
    { Slab_Number__c: 4, Achievement_From__c: 110, Achievement_To__c: null }
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

    @track profiles = []; // [{ key, Profile__c, slabs: [{...}] }]

    basisOptions = BASIS_OPTIONS;
    channelOptions = [];
    profileOptions = [];
    isLoading = false;

    _seq = 1;
    _policyRtId;
    _slabRtId;

    // ===== lifecycle =====
    connectedCallback() {
        if (this.recordId) {
            this.isLoading = true;
            this.loadExisting().finally(() => (this.isLoading = false));
        } else {
            this.addProfile();
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

    get headerTitle() {
        return this.recordId ? 'Edit PBIS Policy' : 'New PBIS Policy';
    }

    // ===== load existing =====
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
                // Group slabs into profile cards.
                const byProfile = {};
                (bundle.slabs || []).forEach((s) => {
                    const key = s.Profile__c || '';
                    if (!byProfile[key]) byProfile[key] = [];
                    byProfile[key].push({
                        key: `s${this._seq++}`,
                        Id: s.Id,
                        Slab_Number__c: s.Slab_Number__c,
                        Achievement_From__c: s.Achievement_From__c,
                        Achievement_To__c: s.Achievement_To__c,
                        Monthly_Incentive_Percent__c: s.Monthly_Incentive_Percent__c,
                        Quarterly_Incentive_Percent__c: s.Quarterly_Incentive_Percent__c,
                        Is_Active__c: s.Is_Active__c
                    });
                });
                this.profiles = Object.keys(byProfile).map((prof) => ({
                    key: `p${this._seq++}`,
                    Profile__c: prof,
                    slabs: byProfile[prof].sort((a, b) => (a.Slab_Number__c || 0) - (b.Slab_Number__c || 0))
                }));
                if (this.profiles.length === 0) this.addProfile();
            })
            .catch((e) => this.toast('Error', this.errMessage(e), 'error'));
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
    handleDescription(event) {
        this.policy = { ...this.policy, Description__c: event.target.value };
    }

    // ===== profile card handlers =====
    freshSlabs() {
        return DEFAULT_SLABS.map((d) => ({
            key: `s${this._seq++}`,
            Id: null,
            Slab_Number__c: d.Slab_Number__c,
            Achievement_From__c: d.Achievement_From__c,
            Achievement_To__c: d.Achievement_To__c,
            Monthly_Incentive_Percent__c: null,
            Quarterly_Incentive_Percent__c: null,
            Is_Active__c: true
        }));
    }
    addProfile() {
        this.profiles = [
            ...this.profiles,
            { key: `p${this._seq++}`, Profile__c: '', slabs: this.freshSlabs() }
        ];
    }
    cloneProfile(event) {
        const key = event.currentTarget.dataset.key;
        const src = this.profiles.find((p) => p.key === key);
        if (!src) return;
        const copy = {
            key: `p${this._seq++}`,
            Profile__c: '', // pick a new profile for the clone
            slabs: src.slabs.map((s) => ({
                ...s,
                key: `s${this._seq++}`,
                Id: null // new records
            }))
        };
        const idx = this.profiles.findIndex((p) => p.key === key);
        const next = [...this.profiles];
        next.splice(idx + 1, 0, copy);
        this.profiles = next;
    }
    removeProfile(event) {
        const key = event.currentTarget.dataset.key;
        this.profiles = this.profiles.filter((p) => p.key !== key);
    }
    handleProfileChange(event) {
        const key = event.currentTarget.dataset.key;
        const value = event.detail.value;
        this.profiles = this.profiles.map((p) => (p.key === key ? { ...p, Profile__c: value } : p));
    }
    handleSlabValue(event) {
        const pKey = event.currentTarget.dataset.profile;
        const sKey = event.currentTarget.dataset.key;
        const field = event.currentTarget.dataset.field;
        const value = event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value;
        this.profiles = this.profiles.map((p) => {
            if (p.key !== pKey) return p;
            return { ...p, slabs: p.slabs.map((s) => (s.key === sKey ? { ...s, [field]: value } : s)) };
        });
    }
    addSlab(event) {
        const pKey = event.currentTarget.dataset.key;
        this.profiles = this.profiles.map((p) => {
            if (p.key !== pKey) return p;
            const nextNum = p.slabs.length + 1;
            return {
                ...p,
                slabs: [
                    ...p.slabs,
                    {
                        key: `s${this._seq++}`, Id: null, Slab_Number__c: nextNum,
                        Achievement_From__c: null, Achievement_To__c: null,
                        Monthly_Incentive_Percent__c: null, Quarterly_Incentive_Percent__c: null,
                        Is_Active__c: true
                    }
                ]
            };
        });
    }
    removeSlab(event) {
        const pKey = event.currentTarget.dataset.profile;
        const sKey = event.currentTarget.dataset.key;
        this.profiles = this.profiles.map((p) =>
            p.key !== pKey ? p : { ...p, slabs: p.slabs.filter((s) => s.key !== sKey) }
        );
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

        const slabRecords = [];
        this.profiles.forEach((p) => {
            p.slabs.forEach((s) => {
                const rec = {
                    Profile__c: p.Profile__c || null,
                    Slab_Number__c: s.Slab_Number__c || null,
                    Achievement_From__c: s.Achievement_From__c || null,
                    Achievement_To__c: s.Achievement_To__c || null,
                    Monthly_Incentive_Percent__c: s.Monthly_Incentive_Percent__c || null,
                    Quarterly_Incentive_Percent__c: s.Quarterly_Incentive_Percent__c || null,
                    Is_Active__c: s.Is_Active__c
                };
                if (s.Id) rec.Id = s.Id;
                slabRecords.push(rec);
            });
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
        if (this.profiles.length === 0) {
            this.toast('Required', 'Add at least one profile', 'warning');
            return false;
        }
        const seen = new Set();
        for (const p of this.profiles) {
            if (!p.Profile__c) {
                this.toast('Required', 'Each profile card needs a Profile selected', 'warning');
                return false;
            }
            if (seen.has(p.Profile__c)) {
                this.toast('Duplicate', `Profile "${p.Profile__c}" is used more than once`, 'warning');
                return false;
            }
            seen.add(p.Profile__c);
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