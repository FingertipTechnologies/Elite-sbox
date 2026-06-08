import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import runMonth from '@salesforce/apex/SecondaryPBIS_Controller.runMonth';
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
    { label: 'Criterion', fieldName: 'criteriaName', type: 'text' },
    { label: 'Type', fieldName: 'operator', type: 'text', initialWidth: 160 },
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

    connectedCallback() {
        const now = new Date();
        // Default to the current month.
        this.year = now.getFullYear();
        this.month = now.getMonth() + 1;
        this.loadTotals();
    }

    get hasTotals() { return this.totals && this.totals.length > 0; }
    get hasLines() { return this.lines && this.lines.length > 0; }
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
        runMonth({ year: this.year, month: this.month })
            .then(count => {
                this.toast('Done', `Wrote ${count} incentive row${count === 1 ? '' : 's'} for ${this.periodLabel}.`, 'success');
                this.loadTotals();
                this.showLines = false;
            })
            .catch(e => this.toast('Error', this.msg(e), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    handleRefresh() { this.loadTotals(); }

    loadTotals() {
        if (!this.year || !this.month) return;
        this.isLoading = true;
        getUserMonthlyTotals({ year: this.year, month: this.month })
            .then(d => { this.totals = d || []; this.showLines = false; })
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