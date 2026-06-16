import { LightningElement, track } from 'lwc';
import getRunningSchemes from '@salesforce/apex/RunningSchemeController.getRunningSchemes';

const MONTH_NAMES = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'
];

export default class RunningSchemes extends LightningElement {

    @track schemes = [];
    @track isLoading = false;
    @track error = null;
    @track selectedFilter = 'current';
    expandedSchemes = new Set();

    // Custom date range
    @track customFromDate = '';
    @track customToDate = '';
    @track appliedFromDate = '';
    @track appliedToDate = '';

    // ─── Filter Classes ───────────────────────────────────────────
    get currentMonthClass() {
        return this.selectedFilter === 'current' ? 'rs-filter-btn rs-filter-active' : 'rs-filter-btn';
    }
    get lastMonthClass() {
        return this.selectedFilter === 'previous' ? 'rs-filter-btn rs-filter-active' : 'rs-filter-btn';
    }
    get customClass() {
        return this.selectedFilter === 'custom' ? 'rs-filter-btn rs-filter-active' : 'rs-filter-btn';
    }
    get isCustom() {
        return this.selectedFilter === 'custom';
    }

    // ─── Date Range Label ─────────────────────────────────────────
    get dateRangeLabel() {
        const today = new Date();
        if (this.selectedFilter === 'current') {
            const y = today.getFullYear(), m = today.getMonth();
            const last = new Date(y, m + 1, 0).getDate();
            return `${MONTH_NAMES[m]} 01 – ${MONTH_NAMES[m]} ${last}, ${y}`;
        } else if (this.selectedFilter === 'previous') {
            const m = today.getMonth() - 1;
            const realM = m < 0 ? 11 : m;
            const realY = m < 0 ? today.getFullYear() - 1 : today.getFullYear();
            const last = new Date(realY, realM + 1, 0).getDate();
            return `${MONTH_NAMES[realM]} 01 – ${MONTH_NAMES[realM]} ${last}, ${realY}`;
        } else if (this.selectedFilter === 'custom' && this.appliedFromDate && this.appliedToDate) {
            return `${this.appliedFromDate} – ${this.appliedToDate}`;
        }
        return 'Select date range and click Apply';
    }

    get totalSchemes() { return this.schemes.length; }
    get totalProducts() {
        return this.schemes.reduce((acc, s) => acc + (s.productCount || 0), 0);
    }
    get hasSchemes() { return !this.isLoading && !this.error && this.schemes.length > 0; }
    get isEmpty()    { return !this.isLoading && !this.error && this.schemes.length === 0; }

    // ─── Lifecycle ────────────────────────────────────────────────
    connectedCallback() {
        this.loadSchemes();
    }

    // ─── Handlers ─────────────────────────────────────────────────
    handleFilterChange(evt) {
        const filter = evt.currentTarget.dataset.filter;
        if (filter === this.selectedFilter) return;
        this.selectedFilter = filter;
        this.expandedSchemes.clear();
        if (filter !== 'custom') {
            this.loadSchemes();
        }
    }

    handleFromDate(evt) {
        this.customFromDate = evt.target.value;
    }

    handleToDate(evt) {
        this.customToDate = evt.target.value;
    }

    applyCustomFilter() {
        if (!this.customFromDate || !this.customToDate) {
            this.error = 'Please select both From and To dates.';
            return;
        }
        if (this.customFromDate > this.customToDate) {
            this.error = 'From date cannot be after To date.';
            return;
        }
        this.appliedFromDate = this.customFromDate;
        this.appliedToDate = this.customToDate;
        this.loadSchemes();
    }

    // ─── Data Load ────────────────────────────────────────────────
    loadSchemes() {
        this.isLoading = true;
        this.error = null;

        const params = { dateFilter: this.selectedFilter };
        if (this.selectedFilter === 'custom') {
            params.fromDate = this.appliedFromDate;
            params.toDate   = this.appliedToDate;
        }

        getRunningSchemes(params)
            .then(data => {
                this.schemes   = this.transformSchemes(data);
                this.isLoading = false;
            })
            .catch(err => {
                this.error     = err?.body?.message || 'Failed to load schemes.';
                this.isLoading = false;
            });
    }

    // ─── Transform ────────────────────────────────────────────────
    // Each CoverageScheme is rendered exactly like the order-screen Schemes tab.
    transformSchemes(raw) {
        return (raw || []).map(scheme => {
            const isExpanded = this.expandedSchemes.has(scheme.id);
            return {
                ...scheme,
                isExpanded,
                productCount: (scheme.products || []).length,
                slabRows:     scheme.slabRows || [],
                products:     scheme.products || [],
                expandIcon:   isExpanded ? 'utility:chevrondown' : 'utility:chevronright'
            };
        });
    }

    toggleScheme(evt) {
        const id = evt.currentTarget.dataset.id;
        if (this.expandedSchemes.has(id)) {
            this.expandedSchemes.delete(id);
        } else {
            this.expandedSchemes.add(id);
        }
        this.schemes = this.schemes.map(s => {
            if (s.id !== id) return s;
            const isExpanded = this.expandedSchemes.has(id);
            return {
                ...s,
                isExpanded,
                expandIcon: isExpanded ? 'utility:chevrondown' : 'utility:chevronright'
            };
        });
    }

    // ─── Download Excel (CSV) ─────────────────────────────────────
    // One row per (scheme × product); offer sentences are concatenated.
    handleDownload() {
        if (!this.schemes || this.schemes.length === 0) {
            this.error = 'No data available to download.';
            return;
        }

        try {
            const headers = [
                'Scheme Name', 'Scheme Type', 'Valid',
                'Product Group', 'Product Category', 'Offers', 'Product', 'SKU'
            ];

            const rows = [];
            this.schemes.forEach(scheme => {
                const offers = (scheme.slabRows || [])
                    .map(r => `${r.label}: ${r.value}`)
                    .join(' | ');
                const products = scheme.products || [];
                if (products.length === 0) {
                    rows.push([
                        scheme.name || '',
                        scheme.schemeType || '',
                        scheme.validLabel || '',
                        scheme.productGroupName || '',
                        scheme.productCategory || '',
                        offers,
                        '',
                        ''
                    ]);
                } else {
                    products.forEach(p => {
                        rows.push([
                            scheme.name || '',
                            scheme.schemeType || '',
                            scheme.validLabel || '',
                            scheme.productGroupName || '',
                            scheme.productCategory || '',
                            offers,
                            p.name || '',
                            p.sku || ''
                        ]);
                    });
                }
            });

            const csvContent = [headers, ...rows]
                .map(row =>
                    row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(',')
                )
                .join('\n');

            const blob = new Blob(['﻿' + csvContent], {
                type: 'application/octet-stream'
            });

            const url = URL.createObjectURL(blob);

            const link = document.createElement('a');
            link.href = url;
            link.download = `Schemes_${new Date().toISOString().slice(0,10)}.csv`;

            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);

            URL.revokeObjectURL(url);

        } catch (error) {
            console.error('CSV Export Error:', error);
            this.error = 'Error while downloading CSV';
        }
    }
}
