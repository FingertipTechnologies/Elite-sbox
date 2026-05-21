import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTargets from '@salesforce/apex/SecondaryTarget_Controller.getTargets';
import getCriteriaOptions from '@salesforce/apex/SecondaryTarget_Controller.getCriteriaOptions';
import getFocusedPackOptions from '@salesforce/apex/SecondaryTarget_Controller.getFocusedPackOptions';
import getChannelOptions from '@salesforce/apex/SecondaryTarget_Controller.getChannelOptions';
import searchUsers from '@salesforce/apex/SecondaryTarget_Controller.searchUsers';
import saveTarget from '@salesforce/apex/SecondaryTarget_Controller.saveTarget';
import deleteTarget from '@salesforce/apex/SecondaryTarget_Controller.deleteTarget';
import recalculateAll from '@salesforce/apex/SecondaryTarget_Controller.recalculateAll';
import recalculateTarget from '@salesforce/apex/SecondaryTarget_Controller.recalculateTarget';

const COLUMNS = [
    { label: 'Target', fieldName: 'Name', type: 'text', initialWidth: 110 },
    { label: 'User', fieldName: 'userName', type: 'text' },
    { label: 'Criteria', fieldName: 'criteriaName', type: 'text' },
    { label: 'Type', fieldName: 'operator', type: 'text', initialWidth: 160 },
    { label: 'Focus Pack', fieldName: 'packName', type: 'text' },
    { label: 'Channel', fieldName: 'Sales_Channel__c', type: 'text', initialWidth: 100 },
    { label: 'Target', fieldName: 'Target_Value__c', type: 'number', initialWidth: 95,
      cellAttributes: { alignment: 'right' } },
    { label: 'Achieved', fieldName: 'Achievement_Value__c', type: 'number', initialWidth: 95,
      cellAttributes: { alignment: 'right' } },
    { label: '% Ach.', fieldName: 'pctFraction', type: 'percent', initialWidth: 90,
      cellAttributes: { alignment: 'right' }, typeAttributes: { step: '0.01' } },
    { label: 'Pending', fieldName: 'Pending_Target__c', type: 'number', initialWidth: 95,
      cellAttributes: { alignment: 'right' } },
    { label: 'Active', fieldName: 'Is_Active__c', type: 'boolean', initialWidth: 65 },
    { label: 'Last Updated', fieldName: 'Last_Updated__c', type: 'date',
      typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Edit', name: 'edit' },
                { label: 'Recalculate', name: 'recalc' },
                { label: 'Delete', name: 'delete' }
            ]
        }
    }
];

const EMPTY_FORM = {
    Id: null, User__c: null, userLabel: '', Target_Criteria__c: '',
    Focused_Pack__c: '', Sales_Channel__c: '', Year__c: null,
    Start_Date__c: null, End_Date__c: null, Target_Value__c: null, Is_Active__c: true
};

export default class SecondaryTargetManager extends LightningElement {
    columns = COLUMNS;

    @track rows = [];
    @track criteriaOptions = [{ label: 'All Criteria', value: '' }];
    @track focusPackOptions = [];
    @track channelOptions = [];
    @track selectedCriteria = '';
    @track activeOnly = false;
    @track isLoading = false;

    // operator lookup keyed by criteria Id (for focus-pack detection)
    operatorById = {};

    // modal / form state
    @track showForm = false;
    @track form = { ...EMPTY_FORM };
    @track userResults = [];
    @track showUserResults = false;

    connectedCallback() {
        this.loadCriteriaOptions();
        this.loadPickOptions();
        this.loadTargets();
    }

    // ===== getters =====
    get formTitle() { return this.form.Id ? 'Edit Secondary Target' : 'New Secondary Target'; }
    get hasRows() { return this.rows && this.rows.length > 0; }
    get totalCount() { return this.rows.length; }
    get activeCount() { return this.rows.filter(r => r.Is_Active__c).length; }
    get avgAchievement() {
        const withTargets = this.rows.filter(r => r.Target_Value__c);
        if (!withTargets.length) return 0;
        const sum = withTargets.reduce((a, r) => a + (r.Achievement_Percent__c || 0), 0);
        return Math.round((sum / withTargets.length) * 100) / 100;
    }

    get selectedOperator() { return this.operatorById[this.form.Target_Criteria__c] || ''; }
    get isFocusPackCriteria() { return this.selectedOperator.indexOf('FOCUS_PACK') === 0; }
    // criteria options without the "All" entry, for the form picker
    get formCriteriaOptions() { return this.criteriaOptions.filter(o => o.value); }

    // ===== loaders =====
    loadCriteriaOptions() {
        getCriteriaOptions()
            .then(data => {
                const opts = [];
                const map = {};
                (data || []).forEach(o => {
                    opts.push({ label: o.label, value: o.value });
                    map[o.value] = o.operator;
                });
                this.operatorById = map;
                this.criteriaOptions = [{ label: 'All Criteria', value: '' }, ...opts];
            })
            .catch(() => { /* non-fatal */ });
    }

    loadPickOptions() {
        getFocusedPackOptions()
            .then(d => { this.focusPackOptions = (d || []).map(o => ({ label: o.label, value: o.value })); })
            .catch(() => { /* non-fatal */ });
        getChannelOptions()
            .then(d => { this.channelOptions = (d || []).map(o => ({ label: o.label, value: o.value })); })
            .catch(() => { /* non-fatal */ });
    }

    loadTargets() {
        this.isLoading = true;
        getTargets({ channel: '', criteriaId: this.selectedCriteria, activeOnly: this.activeOnly })
            .then(data => {
                this.rows = (data || []).map(r => ({
                    ...r,
                    userName: (r.User__r && r.User__r.Name) || r.User_Name__c || '',
                    criteriaName: (r.Target_Criteria__r && r.Target_Criteria__r.Name) || '',
                    operator: (r.Target_Criteria__r && r.Target_Criteria__r.Operator__c) || '',
                    packName: (r.Focused_Pack__r && r.Focused_Pack__r.Name) || '',
                    pctFraction: r.Achievement_Percent__c != null ? r.Achievement_Percent__c / 100 : null
                }));
            })
            .catch(e => this.toast('Error', this.msg(e), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    // ===== filters =====
    handleCriteriaFilter(e) { this.selectedCriteria = e.detail.value; this.loadTargets(); }
    handleActiveToggle(e) { this.activeOnly = e.target.checked; this.loadTargets(); }
    handleRefresh() { this.loadTargets(); }

    // ===== form =====
    handleNew() {
        this.form = { ...EMPTY_FORM };
        this.userResults = [];
        this.showUserResults = false;
        this.showForm = true;
    }

    handleCloseForm() { this.showForm = false; }

    handleFormField(e) {
        const field = e.target.dataset.field;
        const val = e.target.type === 'checkbox' ? e.target.checked : e.target.value;
        this.form = { ...this.form, [field]: val };
    }

    handleCriteriaChange(e) {
        const val = e.detail.value;
        const next = { ...this.form, Target_Criteria__c: val };
        // clear the pack if the chosen criteria is not a focus-pack type
        if ((this.operatorById[val] || '').indexOf('FOCUS_PACK') !== 0) {
            next.Focused_Pack__c = '';
        }
        this.form = next;
    }

    // user typeahead
    handleUserSearch(e) {
        const term = e.target.value;
        this.form = { ...this.form, userLabel: term, User__c: null };
        if (!term || term.length < 2) { this.userResults = []; this.showUserResults = false; return; }
        searchUsers({ term })
            .then(d => {
                this.userResults = (d || []).map(o => ({ label: o.label, value: o.value }));
                this.showUserResults = this.userResults.length > 0;
            })
            .catch(() => { this.userResults = []; this.showUserResults = false; });
    }

    handleSelectUser(e) {
        const id = e.currentTarget.dataset.value;
        const label = e.currentTarget.dataset.label;
        this.form = { ...this.form, User__c: id, userLabel: label };
        this.showUserResults = false;
    }

    handleSaveForm() {
        const f = this.form;
        if (!f.User__c) { this.toast('Validation', 'Select a User.', 'error'); return; }
        if (!f.Target_Criteria__c) { this.toast('Validation', 'Select a Target Criteria.', 'error'); return; }
        if (!f.Start_Date__c || !f.End_Date__c) { this.toast('Validation', 'Start and End dates are required.', 'error'); return; }
        if (this.isFocusPackCriteria && !f.Focused_Pack__c) {
            this.toast('Validation', 'This criteria is a Focus-Pack type — select a Focus Pack.', 'error');
            return;
        }

        const rec = {
            sobjectType: 'Secondary_Target__c',
            Id: f.Id || null,
            User__c: f.User__c,
            Target_Criteria__c: f.Target_Criteria__c,
            Focused_Pack__c: this.isFocusPackCriteria ? f.Focused_Pack__c : null,
            Sales_Channel__c: f.Sales_Channel__c || null,
            Year__c: f.Year__c || null,
            Start_Date__c: f.Start_Date__c,
            End_Date__c: f.End_Date__c,
            Target_Value__c: f.Target_Value__c || null,
            Is_Active__c: f.Is_Active__c === true
        };

        this.isLoading = true;
        saveTarget({ target: rec })
            .then(() => {
                this.showForm = false;
                this.toast('Success', 'Secondary Target saved', 'success');
                this.loadTargets();
            })
            .catch(e => this.toast('Error', this.msg(e), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    // ===== row actions =====
    handleRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action === 'edit') {
            this.form = {
                Id: row.Id,
                User__c: row.User__c,
                userLabel: row.userName,
                Target_Criteria__c: row.Target_Criteria__c,
                Focused_Pack__c: row.Focused_Pack__c || '',
                Sales_Channel__c: row.Sales_Channel__c || '',
                Year__c: row.Year__c,
                Start_Date__c: row.Start_Date__c,
                End_Date__c: row.End_Date__c,
                Target_Value__c: row.Target_Value__c,
                Is_Active__c: row.Is_Active__c
            };
            this.userResults = [];
            this.showUserResults = false;
            this.showForm = true;
        } else if (action === 'recalc') {
            this.recalcOne(row.Id);
        } else if (action === 'delete') {
            this.removeOne(row.Id);
        }
    }

    recalcOne(id) {
        this.isLoading = true;
        recalculateTarget({ targetId: id })
            .then(() => { this.toast('Success', 'Target recalculated', 'success'); this.loadTargets(); })
            .catch(e => this.toast('Error', this.msg(e), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    removeOne(id) {
        this.isLoading = true;
        deleteTarget({ targetId: id })
            .then(() => { this.toast('Success', 'Target deleted', 'success'); this.loadTargets(); })
            .catch(e => this.toast('Error', this.msg(e), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    handleRecalcAll() {
        this.isLoading = true;
        recalculateAll()
            .then(() => {
                this.toast('Started',
                    'Achievement recalculation started for all active targets. Refresh in a moment to see updated values.',
                    'success');
            })
            .catch(e => this.toast('Error', this.msg(e), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    msg(e) {
        return (e && e.body && e.body.message) ? e.body.message : (e && e.message) ? e.message : 'Unexpected error';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}