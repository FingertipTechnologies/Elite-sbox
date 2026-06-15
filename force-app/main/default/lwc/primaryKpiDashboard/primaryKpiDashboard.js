import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FORM_FACTOR from '@salesforce/client/formFactor';
import getDashboard from '@salesforce/apex/PrimaryKpiDashboard_Controller.getDashboard';

const MONTHS = [
    { label: 'January', value: 1 }, { label: 'February', value: 2 }, { label: 'March', value: 3 },
    { label: 'April', value: 4 }, { label: 'May', value: 5 }, { label: 'June', value: 6 },
    { label: 'July', value: 7 }, { label: 'August', value: 8 }, { label: 'September', value: 9 },
    { label: 'October', value: 10 }, { label: 'November', value: 11 }, { label: 'December', value: 12 }
];

const INR = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 });
const CCY = { currencyCode: 'INR', minimumFractionDigits: 0, maximumFractionDigits: 0 };

function num(v) {
    if (v === null || v === undefined || v === '') return 0;
    const n = typeof v === 'number' ? v : Number(v);
    return isNaN(n) ? 0 : n;
}

const PARAM_COLUMNS = [
    { label: 'Parameter', fieldName: 'parameter', type: 'text', wrapText: true },
    { label: 'Weight %', fieldName: 'weightage', type: 'number', cellAttributes: { alignment: 'right' }, initialWidth: 90 },
    { label: 'Target', fieldName: 'target', type: 'number', cellAttributes: { alignment: 'right' } },
    { label: 'Achievement', fieldName: 'achievement', type: 'number', cellAttributes: { alignment: 'right' } },
    { label: 'Ach %', fieldName: 'achievementPct', type: 'number', typeAttributes: { maximumFractionDigits: '1' },
      cellAttributes: { alignment: 'right', class: { fieldName: 'pctClass' } }, initialWidth: 100 },
    { label: 'Slab', fieldName: 'slab', type: 'text', initialWidth: 110 },
    { label: 'Incentive', fieldName: 'incentive', type: 'currency', typeAttributes: CCY, cellAttributes: { alignment: 'right' } }
];

const TEAM_COLUMNS = [
    { label: 'Name', fieldName: 'userName', type: 'text', wrapText: true },
    { label: 'Role', fieldName: 'role', type: 'text', initialWidth: 120 },
    { label: 'Ach %', fieldName: 'achievementPct', type: 'number', typeAttributes: { maximumFractionDigits: '1' },
      cellAttributes: { alignment: 'right', class: { fieldName: 'pctClass' } }, initialWidth: 100 },
    { label: 'Incentive', fieldName: 'totalIncentive', type: 'currency', typeAttributes: CCY, cellAttributes: { alignment: 'right' } },
    { label: 'Eligible', fieldName: 'eligibleText', type: 'text', initialWidth: 90 },
    { type: 'action', typeAttributes: { rowActions: [{ label: 'View this user', name: 'drill' }] } }
];

export default class PrimaryKpiDashboard extends LightningElement {
    monthOptions = MONTHS;
    periodOptions = [{ label: 'Monthly', value: 'Monthly' }, { label: 'Quarterly', value: 'Quarterly' }];
    paramColumns = PARAM_COLUMNS;
    teamColumns = TEAM_COLUMNS;
    isMobile = FORM_FACTOR === 'Small';

    viewModeOptions = [
        { label: 'My', value: 'my' },
        { label: 'My Team', value: 'team' },
        { label: 'User Search', value: 'search' }
    ];

    @track year;
    @track month;
    @track incentivePeriod = 'Monthly';
    @track viewMode = 'my';      // my | team | search
    @track viewUserId = '';
    @track data;
    @track isLoading = false;

    connectedCallback() {
        const now = new Date();
        this.year = now.getFullYear();
        this.month = now.getMonth() + 1;
        this.load();
    }

    // ===== mode flags =====
    get hasData() { return !!this.data; }
    get isEmpty() { return !!this.data && this.data.mode === 'EMPTY'; }
    get viewerIsManager() { return !!this.data && this.data.viewerIsManager; }
    get showViewControl() { return this.viewerIsManager; }
    get isMyView() { return this.viewMode === 'my'; }
    get isTeamView() { return this.viewMode === 'team'; }
    get isSearchView() { return this.viewMode === 'search'; }
    get showPersonalBlock() { return this.hasHero && (this.isMyView || (this.isSearchView && !!this.viewUserId)); }
    get showTeamBlock() { return this.isTeamView; }
    get isDrilled() { return this.isSearchView && !!this.viewUserId; }
    get searchUserOptions() {
        return ((this.data && this.data.userPickerOptions) || []).map(o => ({ label: o.label, value: o.userId }));
    }
    get noPersonalForMy() {
        return this.isMyView && this.hasData && !this.isEmpty && !this.hasHero;
    }
    // User Search: a user is picked but has no target this period.
    get noTargetForSelected() {
        return this.isSearchView && !!this.viewUserId && this.hasData && !this.hasHero;
    }
    // Heading above the personal block: "My Primary PBIS" for My view, the user's name in Search.
    get personalHeading() {
        return this.isMyView ? 'My Primary PBIS' : ((this.data && this.data.selectedUserName) || 'Primary PBIS');
    }

    // ===== team totals (cards like My view) =====
    get teamTotalIncentiveText() {
        let s = 0;
        ((this.data && this.data.team) || []).forEach(r => { s += num(r.totalIncentive); });
        return INR.format(s);
    }
    get teamAchievementPctValue() {
        const rows = (this.data && this.data.team) || [];
        if (!rows.length) return 0;
        let s = 0;
        rows.forEach(r => { s += num(r.achievementPct); });
        return s / rows.length;
    }
    get teamAchievementPctText() { return this.teamAchievementPctValue.toFixed(1) + '%'; }
    get teamPctClass() { return 'kpi-pct ' + this.bucket(this.teamAchievementPctValue); }
    get teamProgressStyle() { return `width:${Math.min(this.teamAchievementPctValue, 100)}%;`; }

    // Team breakdowns (Sales Channel wise / S&D Parameter wise)
    get channelRows() { return this.decorateBreakdown(this.data && this.data.channels); }
    get hasChannels() { return this.channelRows.length > 0; }
    get paramBreakdownRows() { return this.decorateBreakdown(this.data && this.data.paramBreakdown); }
    get hasParamBreakdown() { return this.paramBreakdownRows.length > 0; }
    decorateBreakdown(list) {
        return (list || []).map(r => {
            const pct = num(r.achievementPct);
            return {
                ...r,
                pctText: pct.toFixed(1) + '%',
                barClass: 'progress-fill ' + this.bucket(pct),
                barStyle: `width:${Math.min(pct, 100)}%;`,
                incentiveText: INR.format(num(r.incentive))
            };
        });
    }
    get pickerOptions() {
        const opts = (this.data && this.data.userPickerOptions) || [];
        return [{ label: '— Me —', value: '' }, ...opts.map(o => ({ label: o.label, value: o.userId }))];
    }

    // ===== hero =====
    get hero() { return this.data ? this.data.hero : null; }
    get hasHero() { return !!this.hero; }
    get heroTotalIncentive() { return this.hero ? INR.format(num(this.hero.totalIncentive)) : '—'; }
    get heroMaxIncentive() { return this.hero ? INR.format(num(this.hero.maxIncentive)) : '—'; }
    get heroPctText() { return this.hero ? num(this.hero.achievementPct).toFixed(1) + '%' : '0%'; }
    get heroEligibleText() { return this.hero ? (this.hero.isEligible ? 'Eligible' : 'Not eligible') : '—'; }
    get heroEligibleClass() { return 'kpi-badge ' + (this.hero && this.hero.isEligible ? 'pct-green' : 'pct-red'); }
    get heroPctClass() {
        const v = this.hero ? num(this.hero.achievementPct) : 0;
        return 'kpi-pct ' + (v >= 100 ? 'pct-green' : v >= 80 ? 'pct-amber' : 'pct-red');
    }
    get heroProgressStyle() {
        const v = this.hero ? Math.min(num(this.hero.achievementPct), 100) : 0;
        return `width:${v}%;`;
    }
    get heroProgressClass() {
        const v = this.hero ? num(this.hero.achievementPct) : 0;
        return 'progress-fill ' + (v >= 100 ? 'pct-green' : v >= 80 ? 'pct-amber' : 'pct-red');
    }
    get heroSubHeading() {
        if (!this.data) return '';
        const p = [];
        if (this.data.selectedUserName) p.push(this.data.selectedUserName);
        if (this.hero && this.hero.profileName) p.push(this.hero.profileName);
        if (this.hero && this.hero.policyName) p.push(this.hero.policyName);
        if (this.data.periodLabel) p.push(this.data.periodLabel);
        return p.join(' · ');
    }

    // ===== tables =====
    get parameters() {
        return ((this.data && this.data.parameters) || []).map(r => {
            const pct = num(r.achievementPct);
            return {
                ...r,
                target: num(r.target),
                achievement: num(r.achievement),
                achievementPct: pct,
                weightage: num(r.weightage),
                incentive: num(r.incentive),
                pctClass: this.pctCell(pct),
                pctText: pct.toFixed(1) + '%',
                badgeClass: 'kpi-badge ' + this.bucket(pct),
                barClass: 'progress-fill ' + this.bucket(pct),
                barStyle: `width:${Math.min(pct, 100)}%;`,
                targetText: this.fmtNum(r.target),
                achText: this.fmtNum(r.achievement),
                incentiveText: INR.format(num(r.incentive))
            };
        });
    }
    get hasParameters() { return this.parameters.length > 0; }
    get teamRows() {
        return ((this.data && this.data.team) || []).map(r => {
            const pct = num(r.achievementPct);
            return {
                ...r,
                achievementPct: pct,
                totalIncentive: num(r.totalIncentive),
                eligibleText: r.isEligible ? 'Yes' : 'No',
                pctClass: this.pctCell(pct),
                pctText: pct.toFixed(1) + '%',
                badgeClass: 'kpi-badge ' + this.bucket(pct),
                barClass: 'progress-fill ' + this.bucket(pct),
                barStyle: `width:${Math.min(pct, 100)}%;`,
                incentiveText: INR.format(num(r.totalIncentive))
            };
        });
    }
    get hasTeam() { return this.teamRows.length > 0; }

    pctCell(p) {
        const v = num(p);
        if (v >= 100) return 'slds-text-color_success';
        if (v >= 80) return '';
        return 'slds-text-color_error';
    }
    bucket(p) {
        const v = num(p);
        return v >= 100 ? 'pct-green' : v >= 80 ? 'pct-amber' : 'pct-red';
    }
    fmtNum(v) {
        return new Intl.NumberFormat('en-IN').format(num(v));
    }

    // ===== handlers =====
    handleYear(e) { this.year = e.target.value ? Number(e.target.value) : null; this.load(); }
    handleMonth(e) { this.month = Number(e.detail.value); this.load(); }
    handlePeriod(e) { this.incentivePeriod = e.detail.value; this.load(); }
    handleViewMode(e) { this.viewMode = e.detail.value; this.viewUserId = ''; this.load(); }
    handleUserSearch(e) { this.viewUserId = e.detail.value; this.load(); }
    handleRefresh() { this.load(); }
    handleRowAction(e) {
        if (e.detail.action.name === 'drill') {
            this.viewMode = 'search';
            this.viewUserId = e.detail.row.userId;
            this.load();
        }
    }
    handleTeamCardClick(e) {
        const uid = e.currentTarget.dataset.id;
        if (uid) { this.viewMode = 'search'; this.viewUserId = uid; this.load(); }
    }
    handleBack() { this.viewMode = 'team'; this.viewUserId = ''; this.load(); }

    // ===== apex =====
    load() {
        if (!this.year || !this.month) return;
        this.isLoading = true;
        getDashboard({
            year: this.year,
            month: this.month,
            incentivePeriod: this.incentivePeriod,
            viewUserId: this.viewUserId || null
        })
            .then(d => { this.data = d; })
            .catch(err => this.toast('Error', this.msg(err), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    msg(e) {
        return (e && e.body && e.body.message) || (e && e.message) || 'Unexpected error';
    }
}
