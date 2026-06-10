import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FORM_FACTOR from '@salesforce/client/formFactor';
import getDashboard from '@salesforce/apex/SecondaryKpiDashboard_Controller.getDashboard';
import getDsmSsaSubordinates from '@salesforce/apex/SecondaryKpiDashboard_Controller.getDsmSsaSubordinates';

const MONTHS = [
    { label: 'January', value: 1 }, { label: 'February', value: 2 },
    { label: 'March', value: 3 }, { label: 'April', value: 4 },
    { label: 'May', value: 5 }, { label: 'June', value: 6 },
    { label: 'July', value: 7 }, { label: 'August', value: 8 },
    { label: 'September', value: 9 }, { label: 'October', value: 10 },
    { label: 'November', value: 11 }, { label: 'December', value: 12 }
];

const INR = new Intl.NumberFormat('en-IN', {
    style: 'currency', currency: 'INR', maximumFractionDigits: 0
});

// Apex Decimal sometimes deserializes as a JS string in this org's API version,
// so coerce every numeric field through this helper before formatting it.
function num(v) {
    if (v === null || v === undefined || v === '') return 0;
    const n = typeof v === 'number' ? v : Number(v);
    return isNaN(n) ? 0 : n;
}

const CCY = { currencyCode: 'INR', minimumFractionDigits: 0, maximumFractionDigits: 0 };

const TARGET_COLUMNS = [
    { label: 'Target', fieldName: 'targetName', type: 'text', initialWidth: 110 },
    { label: 'Criterion', fieldName: 'criterionName', type: 'text', wrapText: true },
    { label: 'Focus Pack', fieldName: 'focusPackName', type: 'text', wrapText: true },
    { label: 'Channel', fieldName: 'channel', type: 'text', initialWidth: 110 },
    { label: 'Target', fieldName: 'targetValue', type: 'currency',
      typeAttributes: CCY, cellAttributes: { alignment: 'right' } },
    { label: 'Achievement', fieldName: 'achievementValue', type: 'currency',
      typeAttributes: CCY, cellAttributes: { alignment: 'right' } },
    { label: 'Ach %', fieldName: 'achievementPct', type: 'number',
      typeAttributes: { maximumFractionDigits: '1' },
      cellAttributes: { alignment: 'right', class: { fieldName: 'pctClass' } },
      initialWidth: 100 },
    { label: 'Pending', fieldName: 'pendingTarget', type: 'currency',
      typeAttributes: CCY, cellAttributes: { alignment: 'right' } },
    { label: 'Working Days', fieldName: 'workingDays', type: 'number',
      cellAttributes: { alignment: 'right' }, initialWidth: 130 },
    { label: 'Incentive', fieldName: 'incentive', type: 'currency',
      typeAttributes: CCY, cellAttributes: { alignment: 'right' } }
];

export default class SecondaryKpiDashboard extends LightningElement {
    monthOptions = MONTHS;
    targetColumns = TARGET_COLUMNS;

    // FORM_FACTOR is 'Small' inside the Salesforce mobile app, 'Large' on desktop.
    // DSM/SSAs work on phones, so swap the dense datatable for card list when small.
    isMobile = FORM_FACTOR === 'Small';

    @track year;
    @track month;
    @track selectedUserId;
    @track userOptions = [];
    @track data;
    @track isLoading = false;

    connectedCallback() {
        const now = new Date();
        this.year = now.getFullYear();
        this.month = now.getMonth() + 1;
        this.loadOptionsAndDashboard();
    }

    // ===== Getters =====

    get hasData() { return !!this.data; }
    get viewerIsManager() {
        return !!this.data && this.data.viewerIsDsmSsa === false;
    }
    // Show the user picker only for managers who actually have DSM/SSAs to pick from.
    get showPicker() {
        return this.viewerIsManager && this.userOptions.length > 1;
    }
    get noSubordinates() {
        return !!this.data && this.data.noSubordinates === true;
    }

    get hero() { return this.data ? this.data.hero : null; }
    get hasHero() { return !!this.hero; }

    get heroAchievementPct() {
        if (!this.hero) return '0%';
        return num(this.hero.achievementPct).toFixed(1) + '%';
    }
    get heroTotalTarget() { return this.hero ? INR.format(num(this.hero.totalTarget)) : '—'; }
    get heroTotalAchievement() { return this.hero ? INR.format(num(this.hero.totalAchievement)) : '—'; }
    get heroTotalIncentive() { return this.hero ? INR.format(num(this.hero.totalIncentive)) : '—'; }

    get heroPctClass() {
        if (!this.hero) return 'kpi-pct';
        return 'kpi-pct ' + this.pctBucket(this.hero.achievementPct);
    }
    get heroProgressStyle() {
        const v = this.hero ? Math.min(num(this.hero.achievementPct), 100) : 0;
        return `width:${v}%;`;
    }

    get headerLine() {
        if (!this.data || !this.data.selectedUserName) return '';
        const parts = [this.data.selectedUserName];
        if (this.data.selectedUserRole) parts.push(this.data.selectedUserRole);
        if (this.data.employeeCode) parts.push(this.data.employeeCode);
        return parts.join(' · ');
    }

    get targets() {
        const rows = (this.data && this.data.targets) || [];
        return rows.map(r => this.decorateTarget(r));
    }
    get hasTargets() { return this.targets.length > 0; }

    decorateTarget(r) {
        const pct = num(r.achievementPct);
        return {
            ...r,
            pctClass: this.pctClassForCell(pct),
            pctText: pct.toFixed(1) + '%',
            targetText: INR.format(num(r.targetValue)),
            achText: INR.format(num(r.achievementValue)),
            pendingText: INR.format(num(r.pendingTarget)),
            incentiveText: INR.format(num(r.incentive)),
            barStyle: `width:${Math.min(pct, 100)}%;`,
            barClass: 'progress-fill ' + this.pctBucket(pct),
            badgeClass: 'kpi-badge ' + this.pctBucket(pct)
        };
    }

    pctBucket(p) {
        const v = num(p);
        if (v >= 100) return 'pct-green';
        if (v >= 80) return 'pct-amber';
        return 'pct-red';
    }
    pctClassForCell(p) {
        // SLDS utility classes only — datatable cells live in shadow DOM
        // beyond the reach of this component's CSS file.
        const v = num(p);
        if (v >= 100) return 'slds-text-color_success';
        if (v >= 80) return '';
        return 'slds-text-color_error';
    }

    // ===== Handlers =====

    handleYear(e) {
        this.year = e.target.value ? Number(e.target.value) : null;
        this.loadDashboard();
    }
    handleMonth(e) {
        this.month = Number(e.detail.value);
        this.loadDashboard();
    }
    handleUserChange(e) {
        this.selectedUserId = e.detail.value;
        this.loadDashboard();
    }
    handleRefresh() {
        this.loadDashboard();
    }

    // ===== Apex calls =====

    loadOptionsAndDashboard() {
        this.isLoading = true;
        getDsmSsaSubordinates()
            .then(opts => {
                this.userOptions = (opts || []).map(o => ({
                    label: o.label, value: o.userId
                }));
                // Honor explicit selection if it's still valid, otherwise let the
                // server pick the default (first subordinate, or self for DSM/SSAs).
                return getDashboard({
                    year: this.year, month: this.month, selectedUserId: this.selectedUserId
                });
            })
            .then(d => this.applyDashboard(d))
            .catch(err => this.toast('Error', this.msg(err), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    loadDashboard() {
        if (!this.year || !this.month) return;
        this.isLoading = true;
        getDashboard({
            year: this.year, month: this.month, selectedUserId: this.selectedUserId
        })
            .then(d => this.applyDashboard(d))
            .catch(err => this.toast('Error', this.msg(err), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    applyDashboard(d) {
        this.data = d;
        // Reflect the server-chosen default back to the picker.
        if (d && d.selectedUserId) this.selectedUserId = d.selectedUserId;
    }

    msg(e) {
        return (e && e.body && e.body.message) ? e.body.message : (e && e.message) ? e.message : 'Unexpected error';
    }
    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
