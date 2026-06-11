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
import explainAchievement from '@salesforce/apex/SecondaryTarget_Controller.explainAchievement';

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
                { label: 'View calculation', name: 'explain' },
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

    // achievement-breakdown modal state
    @track showExplain = false;
    @track explain = null;

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
        // Date sanity — server re-checks, but fail fast for nicer UX.
        const startD = new Date(f.Start_Date__c);
        const endD = new Date(f.End_Date__c);
        if (endD < startD) {
            this.toast('Validation', 'End Date cannot be before Start Date.', 'error'); return;
        }
        if (!f.Id) {
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            if (endD < today) {
                this.toast('Validation', 'End Date cannot be in the past. The target must extend to today or later.', 'error'); return;
            }
        }
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
        } else if (action === 'explain') {
            this.openExplain(row.Id);
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

    // ===== Export current view to CSV =====
    handleExport() {
        if (!this.rows || !this.rows.length) {
            this.toast('Nothing to export', 'The list is empty.', 'warning');
            return;
        }
        const headers = [
            'Target Name', 'User', 'Criteria', 'Focus Pack', 'Channel',
            'Start Date', 'End Date', 'Year',
            'Target Value', 'Achievement Value', 'Achievement %', 'Pending', 'Working Days',
            'Active', 'Last Updated'
        ];
        const fmtBool = b => (b === true ? 'TRUE' : 'FALSE');
        const fmtDate = d => (d ? String(d) : '');
        const fmtNum = n => (n === null || n === undefined ? '' : String(n));
        const csvRows = this.rows.map(r => [
            r.Name,
            r.userName,
            r.criteriaName,
            r.packName,
            r.Sales_Channel__c,
            fmtDate(r.Start_Date__c),
            fmtDate(r.End_Date__c),
            fmtNum(r.Year__c),
            fmtNum(r.Target_Value__c),
            fmtNum(r.Achievement_Value__c),
            fmtNum(r.Achievement_Percent__c),
            fmtNum(r.Pending_Target__c),
            fmtNum(r.Working_Days__c),
            fmtBool(r.Is_Active__c),
            fmtDate(r.Last_Updated__c)
        ]);
        const csv = [headers, ...csvRows]
            .map(row => row.map(v => '"' + String(v == null ? '' : v).replace(/"/g, '""') + '"').join(','))
            .join('\n');
        const dataUri = 'data:text/csv;charset=utf-8,%EF%BB%BF' + encodeURIComponent(csv);
        const link = this.template.querySelector('.csv-download-link');
        if (!link) return;
        const today = new Date().toISOString().slice(0, 10);
        link.setAttribute('href', dataUri);
        link.setAttribute('download', `secondary_targets_${today}.csv`);
        link.click();
        this.toast('Exported', `${this.rows.length} row${this.rows.length === 1 ? '' : 's'} downloaded.`, 'success');
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
            // Diagnostic — open the browser console (F12) to inspect what the parser
            // built before posting to Apex. Helps diagnose header mismatches.
            // eslint-disable-next-line no-console
            console.log('[Secondary Target Import] parsed rows:', JSON.stringify(rows, null, 2));
            if (!rows.length) {
                this.toast('Validation', 'CSV has no data rows.', 'error');
                return;
            }
            this.runImport(rows);
        };
        reader.onerror = () => this.toast('Error', 'Could not read the file.', 'error');
        reader.readAsText(file);
    }

    // Normalize a header cell so "Target Name", " Target  Name ", "TARGET NAME"
    // all hash to the same key.
    normHeader(s) { return (s || '').toLowerCase().replace(/\s+/g, ' ').trim(); }

    parseCsv(text) {
        // Strip UTF-8 BOM that Excel adds to the first cell of column A.
        if (text && text.charCodeAt(0) === 0xFEFF) text = text.substring(1);
        const lines = text.split(/\r?\n/).filter(l => l.length > 0);
        if (lines.length < 2) return [];
        // Auto-detect the delimiter from the header line — Excel locales
        // may export CSVs with ';' or '\t' instead of ','.
        const headerLine = lines[0];
        const counts = {
            ',': (headerLine.match(/,/g) || []).length,
            ';': (headerLine.match(/;/g) || []).length,
            '\t': (headerLine.match(/\t/g) || []).length
        };
        let sep = ',';
        let best = counts[','];
        if (counts[';'] > best) { sep = ';'; best = counts[';']; }
        if (counts['\t'] > best) { sep = '\t'; best = counts['\t']; }

        const rawHeaders = this.splitCsvLine(headerLine, sep);
        const headers = rawHeaders.map(h => this.normHeader(h));
        const out = [];
        for (let i = 1; i < lines.length; i++) {
            const cells = this.splitCsvLine(lines[i], sep);
            if (cells.every(c => !c || !c.trim())) continue;
            const row = {};
            headers.forEach((h, j) => { row[h] = (cells[j] !== undefined ? String(cells[j]).trim() : ''); });
            const get = (label) => row[this.normHeader(label)] || '';
            out.push({
                targetName: get('Target Name') || null,
                employeeCode: get('User Employee Code'),
                criteriaName: get('Criteria Name'),
                focusPackName: get('Focus Pack Name') || null,
                salesChannel: get('Sales Channel') || null,
                targetYear: get('Year') ? Number(get('Year')) : null,
                startDate: get('Start Date (YYYY-MM-DD)') || get('Start Date'),
                endDate: get('End Date (YYYY-MM-DD)') || get('End Date'),
                targetValue: get('Target Value') ? Number(get('Target Value')) : null,
                isActive: get('Is Active').toUpperCase() === 'TRUE'
            });
        }
        return out;
    }

    splitCsvLine(line, sep) {
        const out = [];
        let cur = '';
        let inQ = false;
        const delim = sep || ',';
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === '"') {
                if (inQ && line[i + 1] === '"') { cur += '"'; i++; }
                else inQ = !inQ;
            } else if (c === delim && !inQ) {
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
        importTargets({ rowsJson: JSON.stringify(rows) })
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

    // ===== Achievement Breakdown =====
    get hasExplain() { return this.explain != null; }
    get explainFilters() {
        return (this.explain && this.explain.filterClauses && this.explain.filterClauses.length)
            ? this.explain.filterClauses.map((c, i) => ({ id: i + 1, text: c }))
            : null;
    }
    get explainSteps() {
        return (this.explain && this.explain.steps && this.explain.steps.length)
            ? this.explain.steps.map((s, i) => ({ id: i + 1, ...s }))
            : null;
    }
    get explainPackSkus() {
        return (this.explain && this.explain.packSkus && this.explain.packSkus.length)
            ? this.explain.packSkus.map((n, i) => ({ id: i + 1, name: n }))
            : null;
    }
    get explainPerDay() {
        return (this.explain && this.explain.perDay && this.explain.perDay.length)
            ? this.explain.perDay.map((r, i) => ({ id: i + 1, ...r }))
            : null;
    }
    get explainIsTlsd() {
        return this.explain && this.explain.operator === 'DAILY_LINES_PER_ORDER';
    }
    get explainIsDailyUnique() {
        return this.explain && this.explain.operator === 'DAILY_UNIQUE_AVG';
    }

    openExplain(id) {
        this.isLoading = true;
        explainAchievement({ targetId: id })
            .then(x => { this.explain = x; this.showExplain = true; })
            .catch(e => this.toast('Error', this.msg(e), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    handleCloseExplain() { this.showExplain = false; this.explain = null; }

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