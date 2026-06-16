import { LightningElement, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import SHEETJS from '@salesforce/resourceUrl/SheetJS';
import getCategorySlabClaimCategorySummary from '@salesforce/apex/DMSPortalLwc.getCategorySlabClaimCategorySummary';
import getCategorySlabClaimCategoryCustomerDetail from '@salesforce/apex/DMSPortalLwc.getCategorySlabClaimCategoryCustomerDetail';
import getSchemeClaimCustomerSummary from '@salesforce/apex/DMSPortalLwc.getSchemeClaimCustomerSummary';
import getCombinedClaimCategoryCustomerSummary from '@salesforce/apex/DMSPortalLwc.getCombinedClaimCategoryCustomerSummary';
import getTotalClaimCategoryCustomerSummary from '@salesforce/apex/DMSPortalLwc.getTotalClaimCategoryCustomerSummary';
import getSchemeIssueReport from '@salesforce/apex/DMSPortalLwc.getSchemeIssueReport';

export default class ClaimReports extends LightningElement {
    @track selectedReport = null;
    @track fromDate = '';
    @track toDate = '';
    @track isLoading = false;
    @track groupedData = [];
    @track hasData = false;
    @track totalClaimAmount = '0.00';
    @track isSummaryView = false;
    @track showDownloadMenu = false;

    rawData = [];
    sheetJsLoaded = false;

    reportOptions = [
        {
            id: 'categorySummary',
            label: 'Category Slab Claim — Category-Wise Summary',
            description: 'View category slab claim amounts grouped by customer category'
        },
        {
            id: 'categoryCustomerDetail',
            label: 'Category Slab Claim — Category + Customer Detail',
            description: 'View category slab claim amounts grouped by category and customer'
        },
        {
            id: 'schemeCustomerSummary',
            label: 'Scheme Claim — Customer-Wise Summary',
            description: 'View scheme claim amounts grouped by customer'
        },
        {
            id: 'combinedClaim',
            label: 'Combined Claim — Category Slab + Scheme Summary',
            description: 'View items with both category slab and scheme claims, grouped by category and customer'
        },
        {
            id: 'totalClaim',
            label: 'Total Claim Amount — Customer Category and Customer Wise',
            description: 'View all claim amounts (category slab or scheme), grouped by category and customer'
        },
        {
            id: 'schemeIssues',
            label: 'Scheme Issues — Reduced/Disqualified',
            description: 'Invoice lines where a scheme on the order no longer qualifies at the invoiced quantity'
        }
    ];

    connectedCallback() {
        if (!this.sheetJsLoaded) {
            loadScript(this, SHEETJS)
                .then(() => { this.sheetJsLoaded = true; })
                .catch(err => { console.error('SheetJS load error:', err); });
        }
    }

    get isReportSelection() {
        return this.selectedReport === null;
    }

    get isCategorySummary() {
        return this.selectedReport === 'categorySummary';
    }

    get isCategoryCustomerDetail() {
        return this.selectedReport === 'categoryCustomerDetail';
    }

    get isSchemeCustomerSummary() {
        return this.selectedReport === 'schemeCustomerSummary';
    }

    get isCombinedClaim() {
        return this.selectedReport === 'combinedClaim';
    }

    get isTotalClaim() {
        return this.selectedReport === 'totalClaim';
    }

    get isCombinedOrTotalClaim() {
        return this.selectedReport === 'combinedClaim' || this.selectedReport === 'totalClaim';
    }

    get isSchemeIssues() {
        return this.selectedReport === 'schemeIssues';
    }

    get reportTitle() {
        const opt = this.reportOptions.find(r => r.id === this.selectedReport);
        return opt ? opt.label : '';
    }

    get showReport() {
        return this.selectedReport !== null;
    }

    get showNoData() {
        return !this.isLoading && !this.hasData && this.selectedReport !== null;
    }

    get toggleButtonLabel() {
        return this.isSummaryView ? 'Show Details' : 'Show Summary';
    }

    get displayData() {
        if (!this.isSummaryView) {
            return this.groupedData;
        }
        return this.groupedData.filter(row => row.isGroupHeader || row.isSubGroupHeader || row.isSubtotal || row.isGrandTotal);
    }

    initializeDates() {
        const today = new Date();
        const firstDate = new Date(today.getFullYear(), today.getMonth(), 1);
        const lastDate = new Date(today.getFullYear(), today.getMonth() + 1, 0);
        const formatDate = (date) => date.toLocaleDateString('en-CA');
        this.fromDate = formatDate(firstDate);
        this.toDate = formatDate(lastDate);
    }

    handleReportSelect(event) {
        const reportId = event.currentTarget.dataset.id;
        this.selectedReport = reportId;
        this.isSummaryView = false;
        this.initializeDates();
        this.fetchReportData();
    }

    handleBack() {
        this.selectedReport = null;
        this.groupedData = [];
        this.rawData = [];
        this.hasData = false;
        this.totalClaimAmount = '0.00';
        this.isSummaryView = false;
        this.showDownloadMenu = false;
    }

    handleDateChange(event) {
        const field = event.target.dataset.field;
        if (field === 'fromDate') {
            this.fromDate = event.target.value;
        } else if (field === 'toDate') {
            this.toDate = event.target.value;
        }
        this.fetchReportData();
    }

    handleToggleView() {
        this.isSummaryView = !this.isSummaryView;
    }

    fetchReportData() {
        if (!this.fromDate || !this.toDate) return;

        this.isLoading = true;
        let apexMethod;

        if (this.selectedReport === 'categorySummary') {
            apexMethod = getCategorySlabClaimCategorySummary;
        } else if (this.selectedReport === 'categoryCustomerDetail') {
            apexMethod = getCategorySlabClaimCategoryCustomerDetail;
        } else if (this.selectedReport === 'schemeCustomerSummary') {
            apexMethod = getSchemeClaimCustomerSummary;
        } else if (this.selectedReport === 'combinedClaim') {
            apexMethod = getCombinedClaimCategoryCustomerSummary;
        } else if (this.selectedReport === 'totalClaim') {
            apexMethod = getTotalClaimCategoryCustomerSummary;
        } else if (this.selectedReport === 'schemeIssues') {
            apexMethod = getSchemeIssueReport;
        }

        apexMethod({ fromDate: this.fromDate, toDate: this.toDate })
            .then(result => {
                this.rawData = result || [];
                this.processData(result);
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error fetching claim report data:', error);
                this.groupedData = [];
                this.rawData = [];
                this.hasData = false;
                this.isLoading = false;
            });
    }

    processData(data) {
        if (!data || data.length === 0) {
            this.groupedData = [];
            this.hasData = false;
            this.totalClaimAmount = '0.00';
            return;
        }

        let totalClaim = 0;
        if (this.selectedReport === 'combinedClaim' || this.selectedReport === 'totalClaim') {
            data.forEach(item => { totalClaim += (item.totalClaimAmount || 0); });
        } else {
            data.forEach(item => { totalClaim += (item.claimAmount || 0); });
        }
        this.totalClaimAmount = this.fmt(totalClaim);

        if (this.selectedReport === 'categorySummary') {
            this.groupedData = this.groupByCategory(data);
        } else if (this.selectedReport === 'categoryCustomerDetail') {
            this.groupedData = this.groupByCategoryAndCustomer(data);
        } else if (this.selectedReport === 'schemeCustomerSummary') {
            this.groupedData = this.groupByCustomer(data);
        } else if (this.selectedReport === 'combinedClaim' || this.selectedReport === 'totalClaim') {
            this.groupedData = this.groupByCategoryAndCustomerCombined(data);
        } else if (this.selectedReport === 'schemeIssues') {
            this.groupedData = this.groupBySchemeIssues(data);
        }

        this.hasData = this.groupedData.length > 0;
    }

    groupByCategory(data) {
        const rows = [];
        let currentCategory = null;
        let subtotalQty = 0;
        let subtotalClaim = 0;
        let subtotalAmount = 0;
        let grandTotalQty = 0;
        let grandTotalClaim = 0;
        let grandTotalAmount = 0;
        let sno = 0;

        data.forEach((item, index) => {
            const cat = item.category || 'Uncategorized';

            if (currentCategory !== null && currentCategory !== cat) {
                rows.push({
                    key: 'sub-' + currentCategory,
                    rowType: 'subtotal',
                    label: currentCategory + ' Subtotal',
                    quantity: subtotalQty,
                    claimAmount: subtotalClaim,
                    totalAmount: subtotalAmount
                });
                subtotalQty = 0;
                subtotalClaim = 0;
                subtotalAmount = 0;
            }

            if (currentCategory !== cat) {
                rows.push({
                    key: 'grp-' + cat,
                    rowType: 'groupHeader',
                    label: cat
                });
                currentCategory = cat;
            }

            sno++;
            const qty = item.quantity || 0;
            const claim = item.claimAmount || 0;
            const total = item.totalAmount || 0;

            rows.push({
                key: 'row-' + index,
                rowType: 'data',
                sno: sno,
                productName: item.productName,
                beforePrice: this.fmt(item.beforePrice),
                afterPrice: this.fmt(item.afterPrice),
                quantity: qty,
                claimAmount: this.fmt(claim),
                totalAmount: this.fmt(total)
            });

            subtotalQty += qty;
            subtotalClaim += claim;
            subtotalAmount += total;
            grandTotalQty += qty;
            grandTotalClaim += claim;
            grandTotalAmount += total;
        });

        if (currentCategory !== null) {
            rows.push({
                key: 'sub-' + currentCategory + '-last',
                rowType: 'subtotal',
                label: currentCategory + ' Subtotal',
                quantity: subtotalQty,
                claimAmount: subtotalClaim,
                totalAmount: subtotalAmount
            });
        }

        rows.push({
            key: 'grand-total',
            rowType: 'grandtotal',
            label: 'Grand Total',
            quantity: grandTotalQty,
            claimAmount: grandTotalClaim,
            totalAmount: grandTotalAmount
        });

        return this.formatTotalRows(rows);
    }

    groupByCategoryAndCustomer(data) {
        const rows = [];
        let currentCategory = null;
        let currentCustomer = null;
        let subtotalQty = 0;
        let subtotalClaim = 0;
        let subtotalAmount = 0;
        let grandTotalQty = 0;
        let grandTotalClaim = 0;
        let grandTotalAmount = 0;
        let sno = 0;

        data.forEach((item, index) => {
            const cat = item.category || 'Uncategorized';
            const cust = item.customerName || 'Unknown';
            const groupKey = cat + '||' + cust;
            const prevGroupKey = currentCategory && currentCustomer ? currentCategory + '||' + currentCustomer : null;

            if (prevGroupKey !== null && prevGroupKey !== groupKey) {
                rows.push({
                    key: 'sub-' + prevGroupKey,
                    rowType: 'subtotal',
                    label: currentCategory + ' / ' + currentCustomer + ' Subtotal',
                    quantity: subtotalQty,
                    claimAmount: subtotalClaim,
                    totalAmount: subtotalAmount
                });
                subtotalQty = 0;
                subtotalClaim = 0;
                subtotalAmount = 0;
            }

            if (currentCategory !== cat) {
                rows.push({
                    key: 'catgrp-' + cat,
                    rowType: 'groupHeader',
                    label: cat
                });
            }

            if (currentCategory !== cat || currentCustomer !== cust) {
                rows.push({
                    key: 'custgrp-' + groupKey,
                    rowType: 'subGroupHeader',
                    label: cust
                });
                currentCategory = cat;
                currentCustomer = cust;
            }

            sno++;
            const qty = item.quantity || 0;
            const claim = item.claimAmount || 0;
            const total = item.totalAmount || 0;

            rows.push({
                key: 'row-' + index,
                rowType: 'data',
                sno: sno,
                productName: item.productName,
                customerName: cust,
                beforePrice: this.fmt(item.beforePrice),
                afterPrice: this.fmt(item.afterPrice),
                quantity: qty,
                claimAmount: this.fmt(claim),
                totalAmount: this.fmt(total)
            });

            subtotalQty += qty;
            subtotalClaim += claim;
            subtotalAmount += total;
            grandTotalQty += qty;
            grandTotalClaim += claim;
            grandTotalAmount += total;
        });

        if (currentCategory !== null && currentCustomer !== null) {
            rows.push({
                key: 'sub-last',
                rowType: 'subtotal',
                label: currentCategory + ' / ' + currentCustomer + ' Subtotal',
                quantity: subtotalQty,
                claimAmount: subtotalClaim,
                totalAmount: subtotalAmount
            });
        }

        rows.push({
            key: 'grand-total',
            rowType: 'grandtotal',
            label: 'Grand Total',
            quantity: grandTotalQty,
            claimAmount: grandTotalClaim,
            totalAmount: grandTotalAmount
        });

        return this.formatTotalRows(rows);
    }

    groupByCustomer(data) {
        const rows = [];
        let currentCustomer = null;
        let subtotalQty = 0;
        let subtotalClaim = 0;
        let subtotalAmount = 0;
        let grandTotalQty = 0;
        let grandTotalClaim = 0;
        let grandTotalAmount = 0;
        let sno = 0;

        data.forEach((item, index) => {
            const cust = item.customerName || 'Unknown';

            if (currentCustomer !== null && currentCustomer !== cust) {
                rows.push({
                    key: 'sub-' + currentCustomer,
                    rowType: 'subtotal',
                    label: currentCustomer + ' Subtotal',
                    quantity: subtotalQty,
                    claimAmount: subtotalClaim,
                    totalAmount: subtotalAmount
                });
                subtotalQty = 0;
                subtotalClaim = 0;
                subtotalAmount = 0;
            }

            if (currentCustomer !== cust) {
                rows.push({
                    key: 'grp-' + cust,
                    rowType: 'groupHeader',
                    label: cust
                });
                currentCustomer = cust;
            }

            sno++;
            const qty = item.quantity || 0;
            const claim = item.claimAmount || 0;
            const total = item.totalAmount || 0;

            rows.push({
                key: 'row-' + index,
                rowType: 'data',
                sno: sno,
                productName: item.productName,
                beforePrice: this.fmt(item.beforePrice),
                afterPrice: this.fmt(item.afterPrice),
                quantity: qty,
                claimAmount: this.fmt(claim),
                totalAmount: this.fmt(total)
            });

            subtotalQty += qty;
            subtotalClaim += claim;
            subtotalAmount += total;
            grandTotalQty += qty;
            grandTotalClaim += claim;
            grandTotalAmount += total;
        });

        if (currentCustomer !== null) {
            rows.push({
                key: 'sub-' + currentCustomer + '-last',
                rowType: 'subtotal',
                label: currentCustomer + ' Subtotal',
                quantity: subtotalQty,
                claimAmount: subtotalClaim,
                totalAmount: subtotalAmount
            });
        }

        rows.push({
            key: 'grand-total',
            rowType: 'grandtotal',
            label: 'Grand Total',
            quantity: grandTotalQty,
            claimAmount: grandTotalClaim,
            totalAmount: grandTotalAmount
        });

        return this.formatTotalRows(rows);
    }

    groupByCategoryAndCustomerCombined(data) {
        const rows = [];
        let currentCategory = null;
        let currentCustomer = null;
        let subtotalQty = 0;
        let subtotalCatClaim = 0;
        let subtotalSchemeClaim = 0;
        let subtotalTotalClaim = 0;
        let grandTotalQty = 0;
        let grandTotalCatClaim = 0;
        let grandTotalSchemeClaim = 0;
        let grandTotalTotalClaim = 0;
        let sno = 0;

        data.forEach((item, index) => {
            const cat = item.category || 'Uncategorized';
            const cust = item.customerName || 'Unknown';
            const groupKey = cat + '||' + cust;
            const prevGroupKey = currentCategory && currentCustomer ? currentCategory + '||' + currentCustomer : null;

            if (prevGroupKey !== null && prevGroupKey !== groupKey) {
                rows.push({
                    key: 'sub-' + prevGroupKey,
                    rowType: 'subtotal',
                    label: currentCategory + ' / ' + currentCustomer + ' Subtotal',
                    quantity: subtotalQty,
                    categorySlabClaimAmount: subtotalCatClaim,
                    schemeClaimAmount: subtotalSchemeClaim,
                    totalClaimAmt: subtotalTotalClaim
                });
                subtotalQty = 0;
                subtotalCatClaim = 0;
                subtotalSchemeClaim = 0;
                subtotalTotalClaim = 0;
            }

            if (currentCategory !== cat) {
                rows.push({
                    key: 'catgrp-' + cat,
                    rowType: 'groupHeader',
                    label: cat
                });
            }

            if (currentCategory !== cat || currentCustomer !== cust) {
                rows.push({
                    key: 'custgrp-' + groupKey,
                    rowType: 'subGroupHeader',
                    label: cust
                });
                currentCategory = cat;
                currentCustomer = cust;
            }

            sno++;
            const qty = item.quantity || 0;
            const catClaim = item.categorySlabClaimAmount || 0;
            const schemeClaim = item.schemeClaimAmount || 0;
            const totalClaim = item.totalClaimAmount || 0;

            rows.push({
                key: 'row-' + index,
                rowType: 'data',
                sno: sno,
                productName: item.productName,
                beforeCategorySlabPrice: this.fmt(item.beforeCategorySlabPrice),
                afterCategorySlabPrice: this.fmt(item.afterCategorySlabPrice),
                categorySlabClaimAmount: this.fmt(catClaim),
                beforeSchemePrice: this.fmt(item.beforeSchemePrice),
                afterSchemePrice: this.fmt(item.afterSchemePrice),
                schemeClaimAmount: this.fmt(schemeClaim),
                totalClaimAmt: this.fmt(totalClaim),
                quantity: qty
            });

            subtotalQty += qty;
            subtotalCatClaim += catClaim;
            subtotalSchemeClaim += schemeClaim;
            subtotalTotalClaim += totalClaim;
            grandTotalQty += qty;
            grandTotalCatClaim += catClaim;
            grandTotalSchemeClaim += schemeClaim;
            grandTotalTotalClaim += totalClaim;
        });

        if (currentCategory !== null && currentCustomer !== null) {
            rows.push({
                key: 'sub-last',
                rowType: 'subtotal',
                label: currentCategory + ' / ' + currentCustomer + ' Subtotal',
                quantity: subtotalQty,
                categorySlabClaimAmount: subtotalCatClaim,
                schemeClaimAmount: subtotalSchemeClaim,
                totalClaimAmt: subtotalTotalClaim
            });
        }

        rows.push({
            key: 'grand-total',
            rowType: 'grandtotal',
            label: 'Grand Total',
            quantity: grandTotalQty,
            categorySlabClaimAmount: grandTotalCatClaim,
            schemeClaimAmount: grandTotalSchemeClaim,
            totalClaimAmt: grandTotalTotalClaim
        });

        return this.formatCombinedTotalRows(rows);
    }

    groupBySchemeIssues(data) {
        const rows = [];
        let currentCustomer = null;
        let sno = 0;
        data.forEach((item, index) => {
            const cust = item.customerName || 'Unknown';
            if (currentCustomer !== cust) {
                rows.push({ key: 'grp-' + cust, rowType: 'groupHeader', label: cust });
                currentCustomer = cust;
            }
            sno++;
            rows.push({
                key: 'row-' + index,
                rowType: 'data',
                sno: sno,
                productName: item.productName,
                invoiceName: item.invoiceName,
                quantity: item.quantity || 0,
                reason: item.reason
            });
        });
        return this.formatTotalRows(rows);
    }

    formatTotalRows(rows) {
        return rows.map(row => {
            if (row.rowType === 'subtotal' || row.rowType === 'grandtotal') {
                return {
                    ...row,
                    quantity: row.quantity,
                    claimAmount: this.fmt(row.claimAmount),
                    totalAmount: this.fmt(row.totalAmount),
                    isSubtotal: row.rowType === 'subtotal',
                    isGrandTotal: row.rowType === 'grandtotal',
                    isGroupHeader: false,
                    isSubGroupHeader: false,
                    isData: false
                };
            }
            return {
                ...row,
                isSubtotal: false,
                isGrandTotal: false,
                isGroupHeader: row.rowType === 'groupHeader',
                isSubGroupHeader: row.rowType === 'subGroupHeader',
                isData: row.rowType === 'data'
            };
        });
    }

    formatCombinedTotalRows(rows) {
        return rows.map(row => {
            if (row.rowType === 'subtotal' || row.rowType === 'grandtotal') {
                return {
                    ...row,
                    quantity: row.quantity,
                    categorySlabClaimAmount: this.fmt(row.categorySlabClaimAmount),
                    schemeClaimAmount: this.fmt(row.schemeClaimAmount),
                    totalClaimAmt: this.fmt(row.totalClaimAmt),
                    isSubtotal: row.rowType === 'subtotal',
                    isGrandTotal: row.rowType === 'grandtotal',
                    isGroupHeader: false,
                    isSubGroupHeader: false,
                    isData: false
                };
            }
            return {
                ...row,
                isSubtotal: false,
                isGrandTotal: false,
                isGroupHeader: row.rowType === 'groupHeader',
                isSubGroupHeader: row.rowType === 'subGroupHeader',
                isData: row.rowType === 'data'
            };
        });
    }

    fmt(value) {
        if (value === null || value === undefined) return '0.00';
        return Number(value).toLocaleString('en-IN', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    // ==================== Download ====================

    toggleDownloadMenu() {
        this.showDownloadMenu = !this.showDownloadMenu;
    }

    get exportHeaders() {
        if (this.isSchemeIssues) {
            return ['S.No', 'Product Name', 'Invoice', 'Qty', 'Reason'];
        }
        if (this.isCombinedOrTotalClaim) {
            return ['S.No', 'Product Name', 'Before Cat. Slab Price', 'After Cat. Slab Price', 'Cat. Slab Claim Amt', 'Before Scheme Price', 'After Scheme Price', 'Scheme Claim Amt', 'Qty', 'Total Claim Amt'];
        }
        if (this.isSchemeCustomerSummary) {
            return ['S.No', 'Product Name', 'Before Scheme Price', 'After Scheme Price', 'Qty', 'Scheme Claim Amt', 'Total Amount'];
        }
        return ['S.No', 'Product Name', 'Before Cat. Slab Price', 'After Cat. Slab Price', 'Qty', 'Cat. Slab Claim Amt', 'Total Amount'];
    }

    get exportRows() {
        const rows = [];
        const data = this.displayData;
        data.forEach(row => {
            if (row.isGroupHeader) {
                rows.push([row.label]);
            } else if (row.isSubGroupHeader) {
                rows.push(['  ' + row.label]);
            } else if (row.isData) {
                if (this.isSchemeIssues) {
                    rows.push([row.sno, row.productName, row.invoiceName, row.quantity, row.reason]);
                } else if (this.isCombinedOrTotalClaim) {
                    rows.push([row.sno, row.productName, row.beforeCategorySlabPrice, row.afterCategorySlabPrice, row.categorySlabClaimAmount, row.beforeSchemePrice, row.afterSchemePrice, row.schemeClaimAmount, row.quantity, row.totalClaimAmt]);
                } else {
                    rows.push([row.sno, row.productName, row.beforePrice, row.afterPrice, row.quantity, row.claimAmount, row.totalAmount]);
                }
            } else if (row.isSubtotal) {
                if (this.isCombinedOrTotalClaim) {
                    rows.push([row.label, '', '', '', row.categorySlabClaimAmount, '', '', row.schemeClaimAmount, row.quantity, row.totalClaimAmt]);
                } else {
                    rows.push([row.label, '', '', '', row.quantity, row.claimAmount, row.totalAmount]);
                }
            } else if (row.isGrandTotal) {
                if (this.isCombinedOrTotalClaim) {
                    rows.push([row.label, '', '', '', row.categorySlabClaimAmount, '', '', row.schemeClaimAmount, row.quantity, row.totalClaimAmt]);
                } else {
                    rows.push([row.label, '', '', '', row.quantity, row.claimAmount, row.totalAmount]);
                }
            }
        });
        return rows;
    }

    get exportFileName() {
        const opt = this.reportOptions.find(r => r.id === this.selectedReport);
        const name = opt ? opt.label.replace(/[^a-zA-Z0-9]/g, '_') : 'Claim_Report';
        return `${name}_${this.fromDate}_${this.toDate}`;
    }

    handleExportCsv() {
        this.showDownloadMenu = false;
        if (!this.hasData) return;

        try {
            const headers = this.exportHeaders;
            const rows = this.exportRows;
            const csvContent = [headers, ...rows]
                .map(row => row.map(cell => `"${String(cell != null ? cell : '').replace(/"/g, '""')}"`).join(','))
                .join('\n');

            const blob = new Blob(['\ufeff' + csvContent], { type: 'text/plain' });
            const url = URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.download = this.exportFileName + '.csv';
            link.style.display = 'none';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            URL.revokeObjectURL(url);
        } catch (error) {
            console.error('CSV Export Error:', error);
        }
    }

    handleExportXlsx() {
        this.showDownloadMenu = false;
        if (!this.hasData) return;

        try {
            const XLSX = window.XLSX;
            if (!XLSX) {
                console.error('Excel library not loaded yet, please retry');
                return;
            }

            const headers = this.exportHeaders;
            const rows = this.exportRows;
            const wsData = [headers, ...rows];
            const ws = XLSX.utils.aoa_to_sheet(wsData);

            ws['!cols'] = headers.map(() => ({ wch: 20 }));

            const wb = XLSX.utils.book_new();
            XLSX.utils.book_append_sheet(wb, ws, 'Claim Report');
            XLSX.writeFile(wb, this.exportFileName + '.xlsx');
        } catch (error) {
            console.error('XLSX Export Error:', error);
        }
    }

    handleExportPdf() {
        this.showDownloadMenu = false;
        if (!this.hasData) return;

        try {
            const title = this.reportTitle;
            const headers = this.exportHeaders;
            const rows = this.exportRows;

            let headerHtml = headers.map(h => `<th>${h}</th>`).join('');
            let rowsHtml = '';
            rows.forEach(row => {
                const isGroupRow = row.length === 1;
                if (isGroupRow) {
                    rowsHtml += `<tr style="background:#e8f4f8;font-weight:bold;"><td colspan="${headers.length}">${row[0]}</td></tr>`;
                } else {
                    const isTotal = String(row[0]).includes('Subtotal') || String(row[0]).includes('Grand Total');
                    const style = String(row[0]).includes('Grand Total') ? 'background:#02323e;color:#fff;font-weight:bold;' :
                                  String(row[0]).includes('Subtotal') ? 'background:#dceef5;font-weight:bold;' : '';
                    rowsHtml += `<tr style="${style}">${row.map(cell => `<td>${cell != null ? cell : ''}</td>`).join('')}</tr>`;
                }
            });

            const printDiv = document.createElement('div');
            printDiv.id = 'lwc-print-overlay';
            printDiv.innerHTML = `
                <style id="lwc-print-style">
                    @media print {
                        body > *:not(#lwc-print-overlay) { display: none !important; }
                        #lwc-print-overlay { display: block !important; }
                    }
                </style>
                <div id="lwc-print-content">
                    <h2>${title}</h2>
                    <p>Period: ${this.fromDate} to ${this.toDate} | Total Claim Amount: ${this.totalClaimAmount}</p>
                    <table>
                        <thead><tr>${headerHtml}</tr></thead>
                        <tbody>${rowsHtml}</tbody>
                    </table>
                </div>
                <style>
                    #lwc-print-overlay {
                        display: none;
                        position: fixed;
                        top: 0; left: 0;
                        width: 100%; height: 100%;
                        background: white;
                        z-index: 99999;
                        padding: 20px;
                        box-sizing: border-box;
                        overflow: auto;
                    }
                    #lwc-print-content {
                        font-family: Arial, sans-serif;
                        font-size: 12px;
                        color: #333;
                    }
                    #lwc-print-content h2 {
                        font-size: 14px;
                        color: #02323e;
                        margin-bottom: 4px;
                    }
                    #lwc-print-content p {
                        font-size: 11px;
                        color: #666;
                        margin-bottom: 12px;
                    }
                    #lwc-print-content table {
                        width: 100%;
                        border-collapse: collapse;
                    }
                    #lwc-print-content th {
                        background: #02323e;
                        color: #fff;
                        padding: 7px 9px;
                        font-size: 10px;
                        text-align: left;
                    }
                    #lwc-print-content td {
                        padding: 6px 9px;
                        border-bottom: 1px solid #e0e0e0;
                        font-size: 10px;
                    }
                </style>`;

            document.body.appendChild(printDiv);

            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                window.print();
                const cleanup = () => {
                    const overlay = document.getElementById('lwc-print-overlay');
                    if (overlay) overlay.parentNode.removeChild(overlay);
                    window.removeEventListener('afterprint', cleanup);
                };
                window.addEventListener('afterprint', cleanup);
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(cleanup, 5000);
            }, 100);
        } catch (error) {
            console.error('PDF Export Error:', error);
        }
    }
}