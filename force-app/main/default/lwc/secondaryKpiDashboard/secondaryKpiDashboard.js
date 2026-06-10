import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FORM_FACTOR from '@salesforce/client/formFactor';
import getDashboard from '@salesforce/apex/SecondaryKpiDashboard_Controller.getDashboard';
import getBreadcrumbs from '@salesforce/apex/SecondaryKpiDashboard_Controller.getBreadcrumbs';

const MONTHS = [
    { label: 'January', value: 1 }, { label: 'February', value: 2 },
    { label: 'March', value: 3 }, { label: 'April', value: 4 },
    { label: 'May', value: 5 }, { label: 'June', value: 6 },
    { label: 'July', value: 7 }, { label: 'August', value: 8 },
    { label: 'September', value: 9 }, { label: 'October', value: 10 },
    { label: 'November', value: 11 }, { label: 'December', value: 12 }
];

const CCY = { currencyCode: 'INR', minimumFractionDigits: 0, maximumFractionDigits: 0 };

const TEAM_COLUMNS = [
    { label: 'Lead', fieldName: 'leadUserName', type: 'text', wrapText: true },
    { label: 'Role', fieldName: 'leadRole', type: 'text', initialWidth: 140 },
    { label: 'Team Size', fieldName: 'teamSize', type: 'number',
      cellAttributes: { alignment: 'right' }, initialWidth: 110 },
    { label: 'Active Targets', fieldName: 'activeTargets', type: 'number',
      cellAttributes: { alignment: 'right' }, initialWidth: 130 },
    { label: 'Target', fieldName: 'totalTarget', type: 'currency',
      typeAttributes: CCY, cellAttributes: { alignment: 'right' } },
    { label: 'Achievement', fieldName: 'totalAchievement', type: 'currency',
      typeAttributes: CCY, cellAttributes: { alignment: 'right' } },
    { label: 'Ach %', fieldName: 'achievementPct', type: 'number',
      typeAttributes: { maximumFractionDigits: '1' },
      cellAttributes: { alignment: 'right', class: { fieldName: 'pctClass' } },
      initialWidth: 110 },
    { label: 'Incentive', fieldName: 'totalIncentive', type: 'currency',
      typeAttributes: CCY, cellAttributes: { alignment: 'right' } },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [{ label: 'Drill into team', name: 'drill' }]
        }
    }
];

const PERFORMER_COLUMNS = [
    { label: 'User', fieldName: 'userName', type: 'text', wrapText: true },
    { label: 'Role', fieldName: 'role', type: 'text', initialWidth: 130 },
    { label: 'Target', fieldName: 'totalTarget', type: 'currency',
      typeAttributes: CCY, cellAttributes: { alignment: 'right' } },
    { label: 'Achievement', fieldName: 'totalAchievement', type: 'currency',
      typeAttributes: CCY, cellAttributes: { alignment: 'right' } },
    { label: 'Ach %', fieldName: 'achievementPct', type: 'number',
      typeAttributes: { maximumFractionDigits: '1' },
      cellAttributes: { alignment: 'right', class: { fieldName: 'pctClass' } },
      initialWidth: 100 },
    { label: 'Incentive', fieldName: 'totalIncentive', type: 'currency',
      typeAttributes: CCY, cellAttributes: { alignment: 'right' } }
];

const INR = new Intl.NumberFormat('en-IN', {
    style: 'currency', currency: 'INR', maximumFractionDigits: 0
});

export default class SecondaryKpiDashboard extends LightningElement {
    monthOptions = MONTHS;
    teamColumns = TEAM_COLUMNS;
    performerColumns = PERFORMER_COLUMNS;

    // FORM_FACTOR is 'Small' inside the Salesforce mobile app, 'Large' on desktop.
    // DSM/SSAs work on phones, so swap the dense datatables for card lists when small.
    isMobile = FORM_FACTOR === 'Small';

    @track year;
    @track month;
    @track rootUserId;
    @track data;
    @track isLoading = false;
    @track breadcrumbs = [];

    connectedCallback() {
        const now = new Date();
        this.year = now.getFullYear();
        this.month = now.getMonth() + 1;
        this.load();
    }

    // ===== Getters for the template =====

    get periodLabel() {
        const m = MONTHS.find(o => o.value === Number(this.month));
        return (m ? m.label : '') + ' ' + (this.year || '');
    }
    get hasData() { return !!this.data; }
    get hero() { return this.data && this.data.hero ? this.data.hero : null; }
    get hasHero() { return !!this.hero; }

    get heroAchievementPct() {
        if (!this.hero) return '0%';
        return (this.hero.achievementPct || 0).toFixed(1) + '%';
    }
    get heroTotalTarget() { return this.hero ? INR.format(this.hero.totalTarget || 0) : '—'; }
    get heroTotalAchievement() { return this.hero ? INR.format(this.hero.totalAchievement || 0) : '—'; }
    get heroTotalIncentive() { return this.hero ? INR.format(this.hero.totalIncentive || 0) : '—'; }

    get heroPctClass() {
        if (!this.hero) return 'kpi-pct';
        return 'kpi-pct ' + this.pctBucket(this.hero.achievementPct);
    }
    get heroProgressStyle() {
        const v = this.hero ? Math.min(this.hero.achievementPct || 0, 100) : 0;
        return `width:${v}%;`;
    }

    get teams() {
        const rows = (this.data && this.data.teams) || [];
        return rows.map(r => this.decorateTeam(r));
    }
    get hasTeams() { return this.teams.length > 0; }

    get topPerformers() {
        const rows = (this.data && this.data.topPerformers) || [];
        return rows.map(r => this.decoratePerformer(r));
    }
    get bottomPerformers() {
        const rows = (this.data && this.data.bottomPerformers) || [];
        return rows.map(r => this.decoratePerformer(r));
    }

    decorateTeam(r) {
        const pct = r.achievementPct || 0;
        return {
            ...r,
            pctClass: this.pctClassForCell(pct),
            pctText: pct.toFixed(1) + '%',
            targetText: INR.format(r.totalTarget || 0),
            achText: INR.format(r.totalAchievement || 0),
            incentiveText: INR.format(r.totalIncentive || 0),
            barStyle: `width:${Math.min(pct, 100)}%;`,
            barClass: 'progress-fill ' + this.pctBucket(pct),
            badgeClass: 'kpi-badge ' + this.pctBucket(pct)
        };
    }
    decoratePerformer(r) {
        const pct = r.achievementPct || 0;
        return {
            ...r,
            pctClass: this.pctClassForCell(pct),
            pctText: pct.toFixed(1) + '%',
            targetText: INR.format(r.totalTarget || 0),
            achText: INR.format(r.totalAchievement || 0),
            incentiveText: INR.format(r.totalIncentive || 0),
            barStyle: `width:${Math.min(pct, 100)}%;`,
            barClass: 'progress-fill ' + this.pctBucket(pct),
            badgeClass: 'kpi-badge ' + this.pctBucket(pct)
        };
    }
    get hasTopPerformers() { return this.topPerformers.length > 0; }
    get hasBottomPerformers() { return this.bottomPerformers.length > 0; }

    get channelRows() {
        const rows = (this.data && this.data.channels) || [];
        return rows.map(r => ({
            ...r,
            barStyle: `width:${Math.min(r.achievementPct || 0, 100)}%;`,
            pctText: (r.achievementPct || 0).toFixed(1) + '%',
            targetText: INR.format(r.totalTarget || 0),
            achText: INR.format(r.totalAchievement || 0),
            barClass: 'progress-fill ' + this.pctBucket(r.achievementPct),
            channelLabel: r.channel || '— No channel —'
        }));
    }
    get hasChannels() { return this.channelRows.length > 0; }

    get criteriaRows() {
        const rows = (this.data && this.data.criteria) || [];
        return rows.map(r => ({
            ...r,
            barStyle: `width:${Math.min(r.achievementPct || 0, 100)}%;`,
            pctText: (r.achievementPct || 0).toFixed(1) + '%',
            targetText: INR.format(r.totalTarget || 0),
            achText: INR.format(r.totalAchievement || 0),
            barClass: 'progress-fill ' + this.pctBucket(r.achievementPct)
        }));
    }
    get hasCriteria() { return this.criteriaRows.length > 0; }

    get rootHeading() {
        if (!this.data) return 'KPI Dashboard';
        const role = this.data.rootRole ? ` · ${this.data.rootRole}` : '';
        return `${this.data.rootUserName}${role}`;
    }

    get crumbView() {
        // mark the last crumb as current (not clickable)
        const cs = this.breadcrumbs || [];
        return cs.map((c, i) => ({
            ...c,
            isCurrent: i === cs.length - 1,
            isClickable: i !== cs.length - 1
        }));
    }
    get hasBreadcrumbs() { return (this.breadcrumbs || []).length > 1; }

    // ===== Helpers =====

    pctBucket(p) {
        const v = p || 0;
        if (v >= 100) return 'pct-green';
        if (v >= 80) return 'pct-amber';
        return 'pct-red';
    }
    pctClassForCell(p) {
        // SLDS utility classes only — datatable cells live in shadow DOM
        // beyond the reach of this component's CSS file.
        const v = p || 0;
        if (v >= 100) return 'slds-text-color_success';
        if (v >= 80) return '';
        return 'slds-text-color_error';
    }

    // ===== Handlers =====

    handleYear(e) {
        this.year = e.target.value ? Number(e.target.value) : null;
        this.load();
    }
    handleMonth(e) {
        this.month = Number(e.detail.value);
        this.load();
    }
    handleHome() {
        this.rootUserId = null;
        this.breadcrumbs = [];
        this.load();
    }
    handleRefresh() { this.load(); }

    handleTeamAction(e) {
        if (e.detail.action.name !== 'drill') return;
        const row = e.detail.row;
        this.drillTo(row.leadUserId);
    }

    handleTeamCardClick(e) {
        // Used on mobile cards; only drill when the user actually has subordinates,
        // otherwise the click is a no-op (consistent with the desktop row action).
        const uid = e.currentTarget.dataset.id;
        const has = e.currentTarget.dataset.has === 'true';
        if (uid && has) this.drillTo(uid);
    }

    handleCrumbClick(e) {
        const uid = e.currentTarget.dataset.id;
        this.drillTo(uid);
    }

    drillTo(userId) {
        this.rootUserId = userId;
        this.load();
    }

    load() {
        if (!this.year || !this.month) return;
        this.isLoading = true;
        getDashboard({ year: this.year, month: this.month, rootUserId: this.rootUserId })
            .then(d => {
                this.data = d;
                this.rootUserId = d ? d.rootUserId : null;
                return getBreadcrumbs({ userId: this.rootUserId });
            })
            .then(crumbs => {
                this.breadcrumbs = crumbs || [];
            })
            .catch(err => this.toast('Error', this.msg(err), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    msg(e) {
        return (e && e.body && e.body.message) ? e.body.message : (e && e.message) ? e.message : 'Unexpected error';
    }
    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
