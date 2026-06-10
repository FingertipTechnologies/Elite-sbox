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
import importTargets from '@salesforce/apex/SecondaryTarget_Controller.importTargets';

const CSV_HEADERS = [
    'Target Name', 'User Employee Code', 'Criteria Name', 'Focus Pack Name', 'Sales Channel',
    'Year', 'Start Date (YYYY-MM-DD)', 'End Date (YYYY-MM-DD)', 'Target Value', 'Is Active'
];
const CSV_SAMPLES = [
    ['', 'EMP001', 'Sec Revenue', '', 'TN', '2026', '2026-05-01', '2026-05-31', '100000', 'TRUE'],
    ['', 'EMP001', 'Focus Pack ECO', 'Brownie', 'TN', '2026', '2026-05-01', '2026-05-31', '3', 'TRUE'],
    ['STGT-0033', 'EMP001', 'Sec Revenue', '', 'TN', '2026', '2026-05-01', '2026-05-31', '120000', 'TRUE']
];

const COLUMNS = [
    { label: 'Target', fieldName: 'Name', type: 'text', initialWidth: 110 },
    { label: 'User', fieldName: 'userName', type: 'text' },
    { label: 'Criteria', fieldName: 'criteriaName', type: 'text' },
    { label: 'Focus Pack', fieldName: 'packName', type: 'text' },
    { label: 'Channel', fieldName: 'Sales_Channel__c', type: 'text', initialWidth: 100 },
    { label: 'Start', fieldName: 'Start_Date__c', type: 'date-local', initialWidth: 110,
      typeAttributes: { year: 'numeric', month: 'short', day: '2-digit' } },
    { label: 'End', fieldName: 'End_Date__c', type: 'date-local', initialWidth: 110,
      typeAttributes: { year: 'numeric', month: 'short', day: '2-digit' } },
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

    // user-filter (typeahead) state
    @track filterUserId = null;
    @track filterUserLabel = '';
    @track filterUserResults = [];
    @track showFilterUserResults = false;

    // operator lookup keyed by criteria Id (for focus-pack detection)
    operatorById = {};

    // modal / form state
    @track showForm = false;
    @track form = { ...EMPTY_FORM };
    @track userResults = [];
    @track showUserResults = false;

    // import-results modal state
    @track showImportResults = false;
    @track importCreated = 0;
    @track importUpdated = 0;
    @track importErrors = [];

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
        getTargets({
            channel: '',
            criteriaId: this.selectedCriteria,
            activeOnly: this.activeOnly,
            userId: this.filterUserId
        })
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

    // user-filter typeahead
    handleFilterUserSearch(e) {
        const term = e.target.value;
        this.filterUserLabel = term;
        // editing clears the previously-selected user until they pick again
        if (this.filterUserId) {
            this.filterUserId = null;
            this.loadTargets();
        }
        if (!term || term.length < 2) {
            this.filterUserResults = [];
            this.showFilterUserResults = false;
            return;
        }
        searchUsers({ term })
            .then(d => {
                this.filterUserResults = (d || []).map(o => ({ label: o.label, value: o.value }));
                this.showFilterUserResults = this.filterUserResults.length > 0;
            })
            .catch(() => { this.filterUserResults = []; this.showFilterUserResults = false; });
    }

    handleFilterUserSelect(e) {
        const id = e.currentTarget.dataset.value;
        const label = e.currentTarget.dataset.label;
        this.filterUserId = id;
        this.filterUserLabel = label;
        this.showFilterUserResults = false;
        this.loadTargets();
    }

    handleFilterUserClear() {
        this.filterUserId = null;
        this.filterUserLabel = '';
        this.filterUserResults = [];
        this.showFilterUserResults = false;
        this.loadTargets();
    }

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

    get hasImportErrors() { return this.importErrors && this.importErrors.length > 0; }
    get importErrorCount() { return this.importErrors ? this.importErrors.length : 0; }
    get importToastVariant() { return this.hasImportErrors ? 'warning' : 'success'; }

    // ===== CSV Template =====
    handleDownloadTemplate() {
        const lines = [CSV_HEADERS, ...CSV_SAMPLES]
            .map(r => r.map(v => '"' + String(v).replace(/"/g, '""') + '"').join(','))
            .join('\n');
        // %EF%BB%BF is the URL-encoded UTF-8 BOM so Excel opens it cleanly.
        const dataUri = 'data:text/csv;charset=utf-8,%EF%BB%BF' + encodeURIComponent(lines);
        const link = this.template.querySelector('.csv-download-link');
        if (!link) return;
        link.setAttribute('href', dataUri);
        link.setAttribute('download', 'secondary_targets_template.csv');
        link.click();
    }

    // ===== CSV Import =====
    openFilePicker() {
        const input = this.template.querySelector('.csv-file-input');
        if (input) {
            input.value = null; // reset so picking the same file again still fires change
            input.click();
        }
    }

    handleImportFile(e) {
        const file = e.target.files && e.target.files[0];
        if (!file) return;
        const reader = new FileReader();
        reader.onload = (ev) => {
            const text = ev.target.result;
            const rows = this.parseCsv(text);
            if (!rows.length) {
                this.toast('Validation', 'CSV has no data rows.', 'error');
                return;
            }
            this.runImport(rows);
        };
        reader.onerror = () => this.toast('Error', 'Could not read the file.', 'error');
        reader.readAsText(file);
    }

    parseCsv(text) {
        const lines = text.split(/\r?\n/).filter(l => l.length > 0);
        if (lines.length < 2) return [];
        const headers = this.splitCsvLine(lines[0]).map(h => h.trim());
        const out = [];
        for (let i = 1; i < lines.length; i++) {
            const cells = this.splitCsvLine(lines[i]);
            if (cells.every(c => !c || !c.trim())) continue;
            const row = {};
            headers.forEach((h, j) => { row[h] = (cells[j] !== undefined ? String(cells[j]).trim() : ''); });
            out.push({
                targetName: row['Target Name'] || null,
                employeeCode: row['User Employee Code'] || '',
                criteriaName: row['Criteria Name'] || '',
                focusPackName: row['Focus Pack Name'] || null,
                salesChannel: row['Sales Channel'] || null,
                targetYear: row['Year'] ? Number(row['Year']) : null,
                startDate: row['Start Date (YYYY-MM-DD)'] || '',
                endDate: row['End Date (YYYY-MM-DD)'] || '',
                targetValue: row['Target Value'] ? Number(row['Target Value']) : null,
                isActive: (row['Is Active'] || '').toUpperCase() === 'TRUE'
            });
        }
        return out;
    }

    splitCsvLine(line) {
        const out = [];
        let cur = '';
        let inQ = false;
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === '"') {
                if (inQ && line[i + 1] === '"') { cur += '"'; i++; }
                else inQ = !inQ;
            } else if (c === ',' && !inQ) {
                out.push(cur);
                cur = '';
            } else {
                cur += c;
            }
        }
        out.push(cur);
        return out;
    }

    runImport(rows) {
        this.isLoading = true;
        importTargets({ rows })
            .then(res => {
                this.importCreated = res.createdCount || 0;
                this.importUpdated = res.updatedCount || 0;
                this.importErrors = (res.errors || []).map((m, i) => ({ id: i + 1, message: m }));
                this.showImportResults = true;
                this.loadTargets();
            })
            .catch(e => this.toast('Error', this.msg(e), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    handleCloseImportResults() { this.showImportResults = false; }

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
