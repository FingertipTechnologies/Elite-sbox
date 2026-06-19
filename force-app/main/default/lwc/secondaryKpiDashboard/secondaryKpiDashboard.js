import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FORM_FACTOR from '@salesforce/client/formFactor';
import getDashboard from '@salesforce/apex/SecondaryKpiDashboard_Controller.getDashboard';
import getHierarchy from '@salesforce/apex/SecondaryKpiDashboard_Controller.getHierarchy';

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

const USER_COLUMNS = [
    { label: 'Name', fieldName: 'userName', type: 'text', wrapText: true },
    { label: 'Role', fieldName: 'role', type: 'text', initialWidth: 100 },
    { label: 'Channel', fieldName: 'channel', type: 'text', initialWidth: 110 },
    { label: 'Targets', fieldName: 'activeTargets', type: 'number',
      cellAttributes: { alignment: 'right' }, initialWidth: 90 },
    { label: 'Target', fieldName: 'totalTarget', type: 'currency',
      typeAttributes: CCY, cellAttributes: { alignment: 'right' } },
    { label: 'Achievement', fieldName: 'totalAchievement', type: 'currency',
      typeAttributes: CCY, cellAttributes: { alignment: 'right' } },
    { label: 'Ach %', fieldName: 'achievementPct', type: 'number',
      typeAttributes: { maximumFractionDigits: '1' },
      cellAttributes: { alignment: 'right', class: { fieldName: 'pctClass' } },
      initialWidth: 100 },
    { label: 'Incentive', fieldName: 'totalIncentive', type: 'currency',
      typeAttributes: CCY, cellAttributes: { alignment: 'right' } },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [{ label: 'View this user', name: 'drill' }]
        }
    }
];

const PERFORMER_COLUMNS = [
    { label: 'User', fieldName: 'userName', type: 'text', wrapText: true },
    { label: 'Role', fieldName: 'role', type: 'text', initialWidth: 100 },
    { label: 'Achievement', fieldName: 'totalAchievement', type: 'currency',
      typeAttributes: CCY, cellAttributes: { alignment: 'right' } },
    { label: 'Ach %', fieldName: 'achievementPct', type: 'number',
      typeAttributes: { maximumFractionDigits: '1' },
      cellAttributes: { alignment: 'right', class: { fieldName: 'pctClass' } },
      initialWidth: 100 }
];

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
    { label: 'Incentive', fieldName: 'incentive', type: 'currency',
      typeAttributes: CCY, cellAttributes: { alignment: 'right' } }
];

const ALL_VALUE = ''; // empty-string sentinel for the "All <tier>" option

export default class SecondaryKpiDashboard extends LightningElement {
    monthOptions = MONTHS;
    userColumns = USER_COLUMNS;
    performerColumns = PERFORMER_COLUMNS;
    targetColumns = TARGET_COLUMNS;

    // FORM_FACTOR is 'Small' inside the Salesforce mobile app.
    isMobile = FORM_FACTOR === 'Small';

    @track year;
    @track month;
    // Selected user id at each visible picker tier, top→bottom. An entry of ''
    // means "All at this tier" — drilling stops there. The effective user is
    // simply the last non-empty entry (or null if none).
    @track selectedPath = [];
    @track pickerSteps = [];
    @track data;
    @track isLoading = false;

    connectedCallback() {
        const now = new Date();
        this.year = now.getFullYear();
        this.month = now.getMonth() + 1;
        this.reloadAll();
    }

    // ===== Mode flags =====

    get hasData() { return !!this.data; }
    get isPersonal() { return !!this.data && this.data.mode === 'PERSONAL'; }
    get isTeam() { return !!this.data && this.data.mode === 'TEAM'; }
    get isEmpty() { return !!this.data && this.data.mode === 'EMPTY'; }
    get viewerIsManager() { return !!this.data && this.data.viewerIsDsmSsa === false; }

    get showPickers() {
        return this.viewerIsManager && this.pickerSteps.length > 0;
    }

    // Effective user-id derived from the deepest specific selection in the path.
    get effectiveUserId() {
        for (let i = this.selectedPath.length - 1; i >= 0; i--) {
            if (this.selectedPath[i]) return this.selectedPath[i];
        }
        return null;
    }

    // Picker rendering data — one combobox per visible tier, each prepended
    // with an "All <tier>" option valued '' so the user can stop drilling.
    get decoratedSteps() {
        return this.pickerSteps.map(s => ({
            tierIndex: s.tierIndex,
            label: `Select ${s.tierLabel}`,
            value: s.selectedUserId || ALL_VALUE,
            options: [
                { label: `All ${s.tierLabel}`, value: ALL_VALUE },
                ...((s.options || []).map(o => ({ label: o.label, value: o.userId })))
            ]
        }));
    }

    // ===== Hero =====

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

    get heroHeading() {
        if (!this.data) return '';
        if (this.isPersonal) return this.data.selectedUserName || '';
        if (this.isTeam) return 'My DSM / SSA Team';
        return '';
    }
    get heroSubHeading() {
        if (!this.data) return '';
        if (this.isPersonal) {
            const parts = [];
            if (this.data.selectedUserRole) parts.push(this.data.selectedUserRole);
            if (this.data.employeeCode) parts.push(this.data.employeeCode);
            if (this.data.selectedUserChannel) parts.push(this.data.selectedUserChannel);
            parts.push(this.data.periodLabel);
            return parts.join(' · ');
        }
        if (this.isTeam && this.hero) {
            return `${this.hero.targetedUsers} active DSM / SSA · ${this.data.periodLabel}`;
        }
        return '';
    }

    // ===== TEAM lists (decorated) =====

    get users() {
        const rows = (this.data && this.data.users) || [];
        return rows.map(r => this.decoratePerformer(r));
    }
    get hasUsers() { return this.users.length > 0; }

    get topPerformers() {
        const rows = (this.data && this.data.topPerformers) || [];
        return rows.map(r => this.decoratePerformer(r));
    }
    get bottomPerformers() {
        const rows = (this.data && this.data.bottomPerformers) || [];
        return rows.map(r => this.decoratePerformer(r));
    }
    get hasTopPerformers() { return this.topPerformers.length > 0; }
    get hasBottomPerformers() { return this.bottomPerformers.length > 0; }

    get channelRows() {
        const rows = (this.data && this.data.channels) || [];
        return rows.map(r => this.decorateBar(r, r.channel || '— No channel —'));
    }
    get hasChannels() { return this.channelRows.length > 0; }

    get criteriaRows() {
        const rows = (this.data && this.data.criteria) || [];
        return rows.map(r => this.decorateBar(r, r.criteriaName));
    }
    get hasCriteria() { return this.criteriaRows.length > 0; }

    // ===== PERSONAL targets =====

    get targets() {
        const rows = (this.data && this.data.targets) || [];
        return rows.map(r => this.decorateTarget(r));
    }
    get hasTargets() { return this.targets.length > 0; }

    // ===== Decorators =====

    decoratePerformer(r) {
        const pct = num(r.achievementPct);
        return {
            ...r,
            pctClass: this.pctClassForCell(pct),
            pctText: pct.toFixed(1) + '%',
            targetText: INR.format(num(r.totalTarget)),
            achText: INR.format(num(r.totalAchievement)),
            incentiveText: INR.format(num(r.totalIncentive)),
            barStyle: `width:${Math.min(pct, 100)}%;`,
            barClass: 'progress-fill ' + this.pctBucket(pct),
            badgeClass: 'kpi-badge ' + this.pctBucket(pct)
        };
    }

    decorateBar(r, label) {
        const pct = num(r.achievementPct);
        return {
            ...r,
            label,
            barStyle: `width:${Math.min(pct, 100)}%;`,
            pctText: pct.toFixed(1) + '%',
            targetText: INR.format(num(r.totalTarget)),
            achText: INR.format(num(r.totalAchievement)),
            barClass: 'progress-fill ' + this.pctBucket(pct)
        };
    }

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
        this.loadDashboardOnly();
    }
    handleMonth(e) {
        this.month = Number(e.detail.value);
        this.loadDashboardOnly();
    }
    handleRefresh() { this.reloadAll(); }

    // Picker change at any tier. Truncate the path at this position, set the
    // new value, drop everything deeper, then reload hierarchy + dashboard.
    handleStepChange(e) {
        const tier = Number(e.currentTarget.dataset.tier);
        const value = e.detail.value || '';
        const stepIdx = this.pickerSteps.findIndex(s => s.tierIndex === tier);
        if (stepIdx < 0) return;
        const newPath = this.selectedPath.slice(0, stepIdx);
        newPath.push(value);
        this.selectedPath = this.trimTrailing(newPath);
        this.reloadAll();
    }

    // Click on a user row in the My DSM/SSA Team table → that user becomes
    // the deepest selection. Since this list is always DSM/SSAs, we append a
    // selection at the DSM/SSA tier (which may be deeper than the current
    // path) and let the server return the resolved cascade.
    handleUserAction(e) {
        if (e.detail.action.name !== 'drill') return;
        this.drillToUser(e.detail.row.userId);
    }
    handleUserCardClick(e) {
        const uid = e.currentTarget.dataset.id;
        if (uid) this.drillToUser(uid);
    }
    drillToUser(userId) {
        // Drop trailing entries then push the new leaf; server figures out
        // where in the cascade it sits.
        this.selectedPath = this.trimTrailing(this.selectedPath);
        this.selectedPath.push(userId);
        this.reloadAll();
    }
    handleBackToTeam() {
        // Pop the deepest specific selection so the dashboard climbs back up
        // one level. If only one selection is present, that resets to "all".
        const next = this.selectedPath.slice(0, -1);
        this.selectedPath = this.trimTrailing(next);
        this.reloadAll();
    }

    trimTrailing(path) {
        // Trailing '' entries add no information — strip them so the canonical
        // path matches between client and server.
        const p = [...path];
        while (p.length && p[p.length - 1] === '') p.pop();
        return p;
    }

    // ===== Apex =====

    reloadAll() {
        if (!this.year || !this.month) return;
        this.isLoading = true;
        getHierarchy({ selectedPath: this.selectedPath })
            .then(h => {
                this.pickerSteps = (h && h.steps) || [];
                // If the viewer is a DSM/SSA the server pins them to themselves —
                // drop any client-side path.
                if (h && h.viewerIsDsmSsa) this.selectedPath = [];
                return getDashboard({
                    year: this.year, month: this.month,
                    selectedUserId: this.effectiveUserId
                });
            })
            .then(d => { this.data = d; })
            .catch(err => this.toast('Error', this.msg(err), 'error'))
            .finally(() => { this.isLoading = false; });
    }

    loadDashboardOnly() {
        if (!this.year || !this.month) return;
        this.isLoading = true;
        getDashboard({
            year: this.year, month: this.month,
            selectedUserId: this.effectiveUserId
        })
            .then(d => { this.data = d; })
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
