import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSlabs from '@salesforce/apex/SecondaryPBIS_Controller.getSlabs';
import saveSlab from '@salesforce/apex/SecondaryPBIS_Controller.saveSlab';
import saveSlabs from '@salesforce/apex/SecondaryPBIS_Controller.saveSlabs';
import deleteSlab from '@salesforce/apex/SecondaryPBIS_Controller.deleteSlab';
import getCriteriaOptions from '@salesforce/apex/SecondaryPBIS_Controller.getCriteriaOptions';
import getChannelOptions from '@salesforce/apex/SecondaryPBIS_Controller.getChannelOptions';
import getFocusedPackOptions from '@salesforce/apex/SecondaryPBIS_Controller.getFocusedPackOptions';

const COMPARE_OPTIONS = [
    { label: 'Percent (Achievement %)', value: 'Percent' },
    { label: 'Value (Achievement Value)', value: 'Value' }
];

const COLUMNS = [
    { label: 'Slab', fieldName: 'Name', type: 'text', initialWidth: 110 },
    { label: 'Criterion', fieldName: 'criteriaName', type: 'text' },
    { label: 'Operator', fieldName: 'operator', type: 'text', initialWidth: 170 },
    { label: 'Channel', fieldName: 'Sales_Channel__c', type: 'text', initialWidth: 100 },
    { label: 'Focus Pack', fieldName: 'packName', type: 'text' },
    { label: 'Compare', fieldName: 'Compare_On__c', type: 'text', initialWidth: 90 },
    { label: 'From', fieldName: 'Achievement_From__c', type: 'number', initialWidth: 90,
      cellAttributes: { alignment: 'right' } },
    { label: 'To', fieldName: 'Achievement_To__c', type: 'number', initialWidth: 90,
      cellAttributes: { alignment: 'right' } },
    { label: 'Amount', fieldName: 'Incentive_Amount__c', type: 'currency', initialWidth: 110,
      cellAttributes: { alignment: 'right' } },
    { label: 'Active', fieldName: 'Active__c', type: 'boolean', initialWidth: 70 },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Edit', name: 'edit' },
                { label: 'Delete', name: 'delete' }
            ]
        }
    }
];

const EMPTY_FORM = {
    Id: null, Target_Criteria__c: '', Sales_Channel__c: '', Focused_Pack__c: '',
    Compare_On__c: 'Percent', Achievement_From__c: null, Achievement_To__c: null,
    Incentive_Amount__c: null, Active__c: true
};

export default class SecondaryPbisSlabs extends LightningElement {
    columns = COLUMNS;
    compareOptions = COMPARE_OPTIONS;

    @track rows = [];
    @track criteriaOptions = [{ label: 'All Criteria', value: '' }];
    @track channelOptions = [];
    @track channelFilterOptions = [{ label: 'All Channels', value: '' }];
    @track _packsRaw = [];
    @track selectedChannel = '';
    @track selectedCriteria = '';
    @track activeOnly = true;
    @track isLoading = false;

    // criteria operator lookup for the form (controls Focus Pack visibility)
    operatorById = {};

    @track showForm = false;
    @track form = { ...EMPTY_FORM };

    // bulk-add modal state
    @track showBulk = false;
    @track bulkRows = [];
    bulkRowSeq = 0;

    connectedCallback() {
        this.loadCriteria();
        this.loadChannels();
        this.loadPacks();
        this.loadRows();
    }

    get formTitle() { return this.form.Id ? 'Edit Incentive Slab' : 'New Incentive Slab'; }
    get hasRows() { return this.rows && this.rows.length > 0; }
    get formCriteriaOptions() { return this.criteriaOptions.filter(o => o.value); }
    get selectedOperator() { return this.operatorById[this.form.Target_Criteria__c] || ''; }
    get isFocusPackCriteria() { return this.selectedOperator.indexOf('FOCUS_PACK') === 0; }

    get hasBulkRows() { return this.bulkRows && this.bulkRows.length > 0; }
    // "blank = all" option prepended for the per-row pickers
    get rowChannelOptions() {
        return [{ label: '— All Channels —', value: '' }, ...this.channelOptions];
    }
    // Each bulk row gets its own filtered pack list keyed off its own
    // Sales_Channel__c selection so the per-row combobox stays in sync.
    get decoratedBulkRows() {
        return this.bulkRows.map(r => ({
            ...r,
            packOptionsForRow: [
                { label: '— All Packs —', value: '' },
                ...this.packsForChannel(r.Sales_Channel__c)
            ]
        }));
    }

    loadCriteria() {
        getCriteriaOptions()
            .then(d => {
                const opts = [];
                const map = {};
                (d || []).forEach(o => {
                    opts.push({ label: o.label, value: o.value });
                    map[o.value] = o.operator;
                });
                this.operatorById = map;
                this.criteriaOptions = [{ label: 'All Criteria', value: '' }, ...opts];
            })
            .catch(() => {});
    }

    loadChannels() {
        getChannelOptions()
            .then(d => {
                const opts = (d || []).map(o => ({ label: o.label, value: o.value }));
                this.channelOptions = opts;
                this.channelFilterOptions = [{ label: 'All Channels', value: '' }, ...opts];
            })
            .catch(() => {});
    }

    loadPacks() {
        getFocusedPackOptions()
            .then(d => {
                this._packsRaw = (d || []).map(o => ({
                    label: o.label, value: o.value, channel: o.channel || ''
                }));
            })
            .catch(() => {});
    }

    // Packs filtered by a given Sales Channel. Packs with no channel apply to
    // all channels. Empty channel = no filter (show all).
    packsForChannel(ch) {
        const raw = this._packsRaw || [];
        if (!ch) return raw.map(o => ({ label: o.label, value: o.value }));
        return raw
            .filter(o => !o.channel || o.channel === ch)
            .map(o => ({ label: o.label, value: o.value }));
    }

    // Single-form combobox — filtered by form.Sales_Channel__c.
    get packOptions() {
        return this.packsForChannel(this.form && this.form.Sales_Channel__c);
    }

    loadRows() {
        this.isLoading = true;
        getSlabs({ channel: this.selectedChannel, criteriaId: this.selectedCriteria, activeOnly: this.activeOnly })
            .then(d => {
                this.rows = (d || []).map(r => ({
                    ...r,
                    criteriaName: (r.Target_Criteria__r && r.Target_Criteria__r.Name) || '',
                    operator: (r.Target_Criteria__r && r.Target_Criteria__r.Operator__c) || '',
                    packName: (r.Focused_Pack__r && r.Focused_Pack__r.Name) || ''
                }));
            })
            .catch(e => this.toast('Error', this.msg(e), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    handleChannelFilter(e) { this.selectedChannel = e.detail.value; this.loadRows(); }
    handleCriteriaFilter(e) { this.selectedCriteria = e.detail.value; this.loadRows(); }
    handleActiveToggle(e) { this.activeOnly = e.target.checked; this.loadRows(); }
    handleRefresh() { this.loadRows(); }

    handleNew() {
        this.form = { ...EMPTY_FORM };
        this.showForm = true;
    }

    handleCloseForm() { this.showForm = false; }

    // ===== Bulk Add =====
    handleBulkOpen() {
        this.bulkRows = [this.makeBulkRow()];
        this.showBulk = true;
    }

    handleBulkClose() { this.showBulk = false; }

    makeBulkRow(seed) {
        this.bulkRowSeq += 1;
        const base = {
            id: this.bulkRowSeq,
            Target_Criteria__c: '', Sales_Channel__c: '', Focused_Pack__c: '',
            Compare_On__c: 'Percent',
            Achievement_From__c: null, Achievement_To__c: null,
            Incentive_Amount__c: null, Active__c: true,
            packDisabled: true
        };
        if (!seed) return base;
        return { ...base, ...seed, id: this.bulkRowSeq };
    }

    handleBulkRowField(e) {
        const rowId = Number(e.target.dataset.id);
        const field = e.target.dataset.field;
        const val = e.target.type === 'checkbox' ? e.target.checked : e.target.value;
        this.bulkRows = this.bulkRows.map(r => {
            if (r.id !== rowId) return r;
            const next = { ...r, [field]: val };
            // Channel change → drop a focus pack that no longer matches the
            // new channel, so the row doesn't carry a stale value.
            if (field === 'Sales_Channel__c' && next.Focused_Pack__c) {
                const pack = (this._packsRaw || []).find(o => o.value === next.Focused_Pack__c);
                if (pack && pack.channel && val && pack.channel !== val) {
                    next.Focused_Pack__c = '';
                }
            }
            return next;
        });
    }

    handleBulkRowCriteriaChange(e) {
        const rowId = Number(e.target.dataset.id);
        const val = e.detail.value;
        const isFP = (this.operatorById[val] || '').indexOf('FOCUS_PACK') === 0;
        this.bulkRows = this.bulkRows.map(r => {
            if (r.id !== rowId) return r;
            return {
                ...r,
                Target_Criteria__c: val,
                Focused_Pack__c: isFP ? r.Focused_Pack__c : '',
                packDisabled: !isFP
            };
        });
    }

    handleBulkAddRow() {
        this.bulkRows = [...this.bulkRows, this.makeBulkRow()];
    }

    handleBulkCloneRow(e) {
        const rowId = Number(e.currentTarget.dataset.id);
        const idx = this.bulkRows.findIndex(r => r.id === rowId);
        if (idx < 0) return;
        const src = this.bulkRows[idx];
        const copy = this.makeBulkRow({
            Target_Criteria__c: src.Target_Criteria__c,
            Sales_Channel__c: src.Sales_Channel__c,
            Focused_Pack__c: src.Focused_Pack__c,
            Compare_On__c: src.Compare_On__c,
            Achievement_From__c: src.Achievement_From__c,
            Achievement_To__c: src.Achievement_To__c,
            Incentive_Amount__c: src.Incentive_Amount__c,
            Active__c: src.Active__c,
            packDisabled: src.packDisabled
        });
        const next = [...this.bulkRows];
        next.splice(idx + 1, 0, copy);
        this.bulkRows = next;
    }

    handleBulkRemoveRow(e) {
        const rowId = Number(e.currentTarget.dataset.id);
        this.bulkRows = this.bulkRows.filter(r => r.id !== rowId);
    }

    handleBulkSave() {
        if (!this.bulkRows.length) { this.toast('Validation', 'Add at least one row.', 'error'); return; }

        const recs = [];
        for (let i = 0; i < this.bulkRows.length; i++) {
            const r = this.bulkRows[i];
            const rowLabel = `Row ${i + 1}`;
            if (!r.Target_Criteria__c) { this.toast('Validation', `${rowLabel}: pick a Target Criteria.`, 'error'); return; }
            if (!r.Compare_On__c) { this.toast('Validation', `${rowLabel}: pick Compare On.`, 'error'); return; }
            if (r.Achievement_From__c === null || r.Achievement_From__c === '') {
                this.toast('Validation', `${rowLabel}: set Achievement From.`, 'error'); return;
            }
            if (r.Incentive_Amount__c === null || r.Incentive_Amount__c === '') {
                this.toast('Validation', `${rowLabel}: set Incentive Amount.`, 'error'); return;
            }
            const isFP = (this.operatorById[r.Target_Criteria__c] || '').indexOf('FOCUS_PACK') === 0;
            recs.push({
                sobjectType: 'Incentive_Slab__c',
                Target_Criteria__c: r.Target_Criteria__c,
                Sales_Channel__c: r.Sales_Channel__c || null,
                Focused_Pack__c: isFP ? (r.Focused_Pack__c || null) : null,
                Compare_On__c: r.Compare_On__c,
                Achievement_From__c: r.Achievement_From__c,
                Achievement_To__c: (r.Achievement_To__c === '' ? null : r.Achievement_To__c),
                Incentive_Amount__c: r.Incentive_Amount__c,
                Active__c: r.Active__c === true
            });
        }

        this.isLoading = true;
        saveSlabs({ slabs: recs })
            .then(count => {
                this.showBulk = false;
                this.toast('Success', `Saved ${count} slab${count === 1 ? '' : 's'}.`, 'success');
                this.loadRows();
            })
            .catch(e => this.toast('Error', this.msg(e), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    handleField(e) {
        const field = e.target.dataset.field;
        const val = e.target.type === 'checkbox' ? e.target.checked : e.target.value;
        const next = { ...this.form, [field]: val };
        // Channel change → drop a focus pack that doesn't belong to the new
        // channel so the combobox doesn't carry a stale, hidden value.
        if (field === 'Sales_Channel__c' && next.Focused_Pack__c) {
            const pack = (this._packsRaw || []).find(o => o.value === next.Focused_Pack__c);
            if (pack && pack.channel && val && pack.channel !== val) {
                next.Focused_Pack__c = '';
            }
        }
        this.form = next;
    }

    handleCriteriaChange(e) {
        const val = e.detail.value;
        const next = { ...this.form, Target_Criteria__c: val };
        if ((this.operatorById[val] || '').indexOf('FOCUS_PACK') !== 0) {
            next.Focused_Pack__c = '';
        }
        this.form = next;
    }

    handleSave() {
        const f = this.form;
        if (!f.Target_Criteria__c) { this.toast('Validation', 'Select a Target Criteria.', 'error'); return; }
        if (!f.Compare_On__c) { this.toast('Validation', 'Pick Compare On.', 'error'); return; }
        if (f.Achievement_From__c === null || f.Achievement_From__c === '') {
            this.toast('Validation', 'Set an Achievement From.', 'error'); return;
        }
        if (f.Incentive_Amount__c === null || f.Incentive_Amount__c === '') {
            this.toast('Validation', 'Set an Incentive Amount.', 'error'); return;
        }

        const rec = {
            sobjectType: 'Incentive_Slab__c',
            Id: f.Id || null,
            Target_Criteria__c: f.Target_Criteria__c,
            Sales_Channel__c: f.Sales_Channel__c || null,
            Focused_Pack__c: this.isFocusPackCriteria ? (f.Focused_Pack__c || null) : null,
            Compare_On__c: f.Compare_On__c,
            Achievement_From__c: f.Achievement_From__c,
            Achievement_To__c: (f.Achievement_To__c === '' ? null : f.Achievement_To__c),
            Incentive_Amount__c: f.Incentive_Amount__c,
            Active__c: f.Active__c === true
        };

        this.isLoading = true;
        saveSlab({ slab: rec })
            .then(() => {
                this.showForm = false;
                this.toast('Success', 'Slab saved', 'success');
                this.loadRows();
            })
            .catch(e => this.toast('Error', this.msg(e), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    handleRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action === 'edit') {
            this.form = {
                Id: row.Id,
                Target_Criteria__c: row.Target_Criteria__c,
                Sales_Channel__c: row.Sales_Channel__c || '',
                Focused_Pack__c: row.Focused_Pack__c || '',
                Compare_On__c: row.Compare_On__c || 'Percent',
                Achievement_From__c: row.Achievement_From__c,
                Achievement_To__c: row.Achievement_To__c,
                Incentive_Amount__c: row.Incentive_Amount__c,
                Active__c: row.Active__c
            };
            this.showForm = true;
        } else if (action === 'delete') {
            this.isLoading = true;
            deleteSlab({ slabId: row.Id })
                .then(() => { this.toast('Success', 'Slab deleted', 'success'); this.loadRows(); })
                .catch(e => this.toast('Error', this.msg(e), 'error'))
                .finally(() => { this.isLoading = false; });
        }
    }

    msg(e) {
        return (e && e.body && e.body.message) ? e.body.message : (e && e.message) ? e.message : 'Unexpected error';
    }
    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
