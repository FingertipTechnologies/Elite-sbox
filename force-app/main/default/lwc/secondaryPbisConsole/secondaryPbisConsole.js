import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import runMonthAsync from '@salesforce/apex/SecondaryPBIS_Controller.runMonthAsync';
import getOverlappingTargets from '@salesforce/apex/SecondaryPBIS_Controller.getOverlappingTargets';
import getAllMonthlyRows from '@salesforce/apex/SecondaryPBIS_Controller.getAllMonthlyRows';
import getUserMonthlyTotals from '@salesforce/apex/SecondaryPBIS_Controller.getUserMonthlyTotals';
import getUserMonthlyRows from '@salesforce/apex/SecondaryPBIS_Controller.getUserMonthlyRows';

const MONTHS = [
    { label: 'January', value: 1 }, { label: 'February', value: 2 },
    { label: 'March', value: 3 }, { label: 'April', value: 4 },
    { label: 'May', value: 5 }, { label: 'June', value: 6 },
    { label: 'July', value: 7 }, { label: 'August', value: 8 },
    { label: 'September', value: 9 }, { label: 'October', value: 10 },
    { label: 'November', value: 11 }, { label: 'December', value: 12 }
];

const TOTAL_COLUMNS = [
    { label: 'User', fieldName: 'executiveName', type: 'text' },
    { label: 'Channel', fieldName: 'salesChannel', type: 'text', initialWidth: 120 },
    { label: 'Lines', fieldName: 'lineCount', type: 'number', initialWidth: 90,
      cellAttributes: { alignment: 'right' } },
    { label: 'Monthly Total', fieldName: 'total', type: 'currency',
      cellAttributes: { alignment: 'right' } },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [{ label: 'View breakdown', name: 'breakdown' }]
        }
    }
];

const LINE_COLUMNS = [
    { label: 'Target', fieldName: 'targetName', type: 'text', initialWidth: 110 },
    { label: 'Criterion', fieldName: 'criteriaName', type: 'text' },
    { label: 'Focus Pack', fieldName: 'packName', type: 'text' },
    { label: 'Compare', fieldName: 'Compare_On__c', type: 'text', initialWidth: 90 },
    { label: 'Achievement Value', fieldName: 'Achievement_Value__c', type: 'number',
      cellAttributes: { alignment: 'right' } },
    { label: 'Achievement %', fieldName: 'achPct', type: 'percent',
      cellAttributes: { alignment: 'right' }, typeAttributes: { step: '0.01' } },
    { label: 'Slab From', fieldName: 'slabFrom', type: 'number',
      cellAttributes: { alignment: 'right' } },
    { label: 'Slab To', fieldName: 'slabTo', type: 'number',
      cellAttributes: { alignment: 'right' } },
    { label: 'Amount', fieldName: 'Credit_Amount__c', type: 'currency',
      cellAttributes: { alignment: 'right' } }
];

export default class SecondaryPbisConsole extends LightningElement {
    monthOptions = MONTHS;
    totalColumns = TOTAL_COLUMNS;
    lineColumns = LINE_COLUMNS;

    @track year;
    @track month;
    @track totals = [];
    @track lines = [];
    @track selectedUserName = '';
    @track isLoading = false;
    @track showLines = false;
    @track skippedDuplicates = [];

    connectedCallback() {
        const now = new Date();
        // Default to the current month.
        this.year = now.getFullYear();
        this.month = now.getMonth() + 1;
        this.loadTotals();
    }

    get hasTotals() { return this.totals && this.totals.length > 0; }
    get hasLines() { return this.lines && this.lines.length > 0; }
    get hasSkippedDuplicates() { return this.skippedDuplicates && this.skippedDuplicates.length > 0; }
    get skippedCount() { return this.skippedDuplicates ? this.skippedDuplicates.length : 0; }
    get periodLabel() {
        const opt = MONTHS.find(o => o.value === Number(this.month));
        return (opt ? opt.label : '') + ' ' + (this.year || '');
    }
    get grandTotal() {
        return (this.totals || []).reduce((a, r) => a + (r.total || 0), 0);
    }

    handleYear(e) {
        this.year = e.target.value ? Number(e.target.value) : null;
        this.loadTotals();
    }
    handleMonth(e) {
        this.month = Number(e.detail.value);
        this.loadTotals();
    }

    handleRun() {
        if (!this.year || !this.month) {
            this.toast('Validation', 'Pick Year and Month first.', 'error');
            return;
        }
        this.isLoading = true;
        this.skippedDuplicates = [];   // clear stale info from a previous sync run
        runMonthAsync({ year: this.year, month: this.month })
            .then(() => {
                this.toast(
                    'Started',
                    `PBIS computation started for ${this.periodLabel}. Refreshing shortly…`,
                    'success'
                );
                this.showLines = false;
                // Auto-refresh after a short delay so the queueable has time to commit.
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => this.loadTotals(), 5000);
            })
            .catch(e => this.toast('Error', this.msg(e), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    handleRefresh() { this.loadTotals(); }

    handleExport() {
        if (!this.year || !this.month) {
            this.toast('Validation', 'Pick Year and Month first.', 'error');
            return;
        }
        this.isLoading = true;
        getAllMonthlyRows({ year: this.year, month: this.month })
            .then(rows => {
                if (!rows || !rows.length) {
                    this.toast('Nothing to export', `No PBIS rows for ${this.periodLabel}.`, 'warning');
                    return;
                }
                const headers = [
                    'Executive', 'Channel', 'Year', 'Month', 'Secondary Target',
                    'Criterion', 'Operator', 'Focus Pack', 'Compare On',
                    'Achievement Value', 'Achievement %',
                    'Slab From', 'Slab To', 'Incentive Amount', 'Computed At'
                ];
                const fmt = v => (v === null || v === undefined ? '' : String(v));
                const csvRows = rows.map(r => [
                    (r.Executive__r && r.Executive__r.Name) || r.User_Name__c || '',
                    fmt(r.Sales_Channel__c),
                    fmt(r.Year__c),
                    fmt(r.Month__c),
                    (r.Secondary_Target__r && r.Secondary_Target__r.Name) || '',
                    (r.Target_Criteria__r && r.Target_Criteria__r.Name) || '',
                    (r.Target_Criteria__r && r.Target_Criteria__r.Operator__c) || '',
                    (r.Focused_Pack__r && r.Focused_Pack__r.Name) || '',
                    fmt(r.Compare_On__c),
                    fmt(r.Achievement_Value__c),
                    fmt(r.Achievement_Percent__c),
                    fmt(r.Matched_Slab__r && r.Matched_Slab__r.Achievement_From__c),
                    fmt(r.Matched_Slab__r && r.Matched_Slab__r.Achievement_To__c),
                    fmt(r.Credit_Amount__c),
                    fmt(r.Computed_At__c)
                ]);
                const csv = [headers, ...csvRows]
                    .map(row => row.map(v => '"' + String(v == null ? '' : v).replace(/"/g, '""') + '"').join(','))
                    .join('\n');
                const dataUri = 'data:text/csv;charset=utf-8,%EF%BB%BF' + encodeURIComponent(csv);
                const link = this.template.querySelector('.pbis-download-link');
                if (!link) return;
                const yearStr = String(this.year);
                const monthStr = String(this.month).padStart(2, '0');
                link.setAttribute('href', dataUri);
                link.setAttribute('download', `secondary_pbis_${yearStr}_${monthStr}.csv`);
                link.click();
                this.toast('Exported', `${rows.length} row${rows.length === 1 ? '' : 's'} downloaded.`, 'success');
            })
            .catch(e => this.toast('Error', this.msg(e), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    loadTotals() {
        if (!this.year || !this.month) return;
        this.isLoading = true;
        Promise.all([
            getUserMonthlyTotals({ year: this.year, month: this.month }),
            getOverlappingTargets({ year: this.year, month: this.month })
        ])
            .then(([totals, dupes]) => {
                this.totals = totals || [];
                this.skippedDuplicates = (dupes || []).map((s, i) => ({ id: i + 1, ...s }));
                this.showLines = false;
            })
            .catch(e => this.toast('Error', this.msg(e), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    handleTotalsAction(e) {
        if (e.detail.action.name !== 'breakdown') return;
        const row = e.detail.row;
        this.selectedUserName = row.executiveName;
        this.isLoading = true;
        getUserMonthlyRows({ executiveId: row.executiveId, year: this.year, month: this.month })
            .then(d => {
                this.lines = (d || []).map(r => ({
                    ...r,
                    criteriaName: (r.Target_Criteria__r && r.Target_Criteria__r.Name) || '',
                    operator: (r.Target_Criteria__r && r.Target_Criteria__r.Operator__c) || '',
                    targetName: (r.Secondary_Target__r && r.Secondary_Target__r.Name) || '',
                    packName: (r.Focused_Pack__r && r.Focused_Pack__r.Name) || '',
                    achPct: r.Achievement_Percent__c != null ? r.Achievement_Percent__c / 100 : null,
                    slabFrom: (r.Matched_Slab__r && r.Matched_Slab__r.Achievement_From__c) ?? null,
                    slabTo: (r.Matched_Slab__r && r.Matched_Slab__r.Achievement_To__c) ?? null
                }));
                this.showLines = true;
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