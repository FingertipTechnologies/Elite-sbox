import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTargets from '@salesforce/apex/SecondaryTarget_Controller.getTargets';
import getCriteriaOptions from '@salesforce/apex/SecondaryTarget_Controller.getCriteriaOptions';
import deleteTarget from '@salesforce/apex/SecondaryTarget_Controller.deleteTarget';
import recalculateAll from '@salesforce/apex/SecondaryTarget_Controller.recalculateAll';
import recalculateTarget from '@salesforce/apex/SecondaryTarget_Controller.recalculateTarget';

const COLUMNS = [
    { label: 'Target', fieldName: 'Name', type: 'text', initialWidth: 110 },
    { label: 'User', fieldName: 'userName', type: 'text' },
    { label: 'Criteria', fieldName: 'criteriaName', type: 'text' },
    { label: 'Type', fieldName: 'operator', type: 'text', initialWidth: 150 },
    { label: 'Channel', fieldName: 'Sales_Channel__c', type: 'text', initialWidth: 110 },
    { label: 'Target', fieldName: 'Target_Value__c', type: 'number', initialWidth: 100,
      cellAttributes: { alignment: 'right' } },
    { label: 'Achieved', fieldName: 'Achievement_Value__c', type: 'number', initialWidth: 100,
      cellAttributes: { alignment: 'right' } },
    { label: '% Ach.', fieldName: 'pctFraction', type: 'percent', initialWidth: 100,
      cellAttributes: { alignment: 'right' }, typeAttributes: { step: '0.01' } },
    { label: 'Pending', fieldName: 'Pending_Target__c', type: 'number', initialWidth: 100,
      cellAttributes: { alignment: 'right' } },
    { label: 'Active', fieldName: 'Is_Active__c', type: 'boolean', initialWidth: 70 },
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

export default class SecondaryTargetManager extends LightningElement {
    columns = COLUMNS;

    @track rows = [];
    @track criteriaOptions = [{ label: 'All Criteria', value: '' }];
    @track selectedCriteria = '';
    @track activeOnly = false;
    @track isLoading = false;

    // modal state
    @track showForm = false;
    @track editRecordId = null;

    objectApiName = 'Secondary_Target__c';

    connectedCallback() {
        this.loadCriteriaOptions();
        this.loadTargets();
    }

    get formTitle() {
        return this.editRecordId ? 'Edit Secondary Target' : 'New Secondary Target';
    }

    get hasRows() {
        return this.rows && this.rows.length > 0;
    }

    get totalCount() { return this.rows.length; }
    get activeCount() { return this.rows.filter(r => r.Is_Active__c).length; }
    get avgAchievement() {
        const withTargets = this.rows.filter(r => r.Target_Value__c);
        if (!withTargets.length) return 0;
        const sum = withTargets.reduce((a, r) => a + (r.Achievement_Percent__c || 0), 0);
        return Math.round((sum / withTargets.length) * 100) / 100;
    }

    loadCriteriaOptions() {
        getCriteriaOptions()
            .then(data => {
                const opts = (data || []).map(o => ({ label: o.label, value: o.value }));
                this.criteriaOptions = [{ label: 'All Criteria', value: '' }, ...opts];
            })
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
                    // datatable percent type expects a fraction; keep the real % for tiles
                    pctFraction: r.Achievement_Percent__c != null ? r.Achievement_Percent__c / 100 : null
                }));
            })
            .catch(e => this.toast('Error', this.msg(e), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    handleCriteriaFilter(e) {
        this.selectedCriteria = e.detail.value;
        this.loadTargets();
    }

    handleActiveToggle(e) {
        this.activeOnly = e.target.checked;
        this.loadTargets();
    }

    handleRefresh() {
        this.loadTargets();
    }

    handleNew() {
        this.editRecordId = null;
        this.showForm = true;
    }

    handleCloseForm() {
        this.showForm = false;
        this.editRecordId = null;
    }

    handleFormSuccess() {
        this.showForm = false;
        this.editRecordId = null;
        this.toast('Success', 'Secondary Target saved', 'success');
        this.loadTargets();
    }

    handleFormError(e) {
        this.toast('Error', this.msg(e) || 'Could not save target', 'error');
    }

    handleRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action === 'edit') {
            this.editRecordId = row.Id;
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
            .then(() => {
                this.toast('Success', 'Target recalculated', 'success');
                this.loadTargets();
            })
            .catch(e => this.toast('Error', this.msg(e), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    removeOne(id) {
        this.isLoading = true;
        deleteTarget({ targetId: id })
            .then(() => {
                this.toast('Success', 'Target deleted', 'success');
                this.loadTargets();
            })
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
