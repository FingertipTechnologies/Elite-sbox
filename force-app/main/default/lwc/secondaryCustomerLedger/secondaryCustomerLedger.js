import { LightningElement, track } from 'lwc';
import searchCustomers from '@salesforce/apex/DMSPortalLwc.searchCustomers';
import getSecondaryLedger from '@salesforce/apex/DMSPortalLwc.getSecondaryLedger';
import getOpeningBalance from '@salesforce/apex/DMSPortalLwc.getOpeningBalance';
import { loadScript } from 'lightning/platformResourceLoader';
import SHEETJS from '@salesforce/resourceUrl/SheetJS';

export default class SecondaryCustomerLedger extends LightningElement {
    @track customerOptions = [];
    @track selectedCustomer = '';
    @track fromDate = '';
    @track toDate = '';
    @track srchVal = '';
    @track status = 'All';
    @track statusOptions = [
        { label: 'All', value: 'All' },
        { label: 'Active', value: 'Active' },
        { label: 'Inactive', value: 'Inactive' }
    ];
    @track allLedgerData = [];
    @track isDataExisted = false;
    @track isLoading = false;
    @track errorMessage = '';
    @track filteredCustomers = [];
    showCustomerSuggestions = false;
    selectedCustomerId = '';
    customerSearch = '';
    customerName = '';
    showDownloadMenu = false;

    connectedCallback() {
        console.log('SecondaryCustomerLedger connectedCallback called');
        this.initializeDates();
        loadScript(this, SHEETJS)
        .then(() => console.log('SheetJS loaded'))
        .catch(err => console.error('SheetJS load error', err));

    }
    

    toggleDownloadMenu() {
        this.showDownloadMenu = !this.showDownloadMenu;
    }

    initializeDates() {
        const today = new Date();
        const firstDate = new Date(today.getFullYear(), today.getMonth(), 1);
        const lastDate = new Date(today.getFullYear(), today.getMonth() + 1, 0);
        const formatDate = (date) => date.toLocaleDateString('en-CA');
        this.fromDate = formatDate(firstDate);
        this.toDate = formatDate(lastDate);
        this.status = 'All';
    }

    handleCustomerSearch(event) {
        this.customerSearch = event.target.value;
        const searchVal = this.customerSearch?.trim();

        // Reset if empty or too short (handles built-in X clear button)
        if (!searchVal || searchVal.length < 2) {
            this.filteredCustomers = [];
            this.showCustomerSuggestions = false;
            this.selectedCustomerId = '';
            this.customerName = '';
            this.allLedgerData = [];
            this.isDataExisted = false;
            this.errorMessage = '';
            return;
        }

        searchCustomers({ searchKey: searchVal })
            .then(result => {
                this.filteredCustomers = result.map(acc => ({
                    label: acc.Name,
                    value: acc.Id,
                    landmark: acc.Land_Mark__c,
                    street: acc.Street__c
                }));
                this.showCustomerSuggestions = this.filteredCustomers.length > 0;
            })
            .catch(error => {
                console.error('Customer search error', error);
                this.filteredCustomers = [];
                this.showCustomerSuggestions = false;
            });
    }

    handleCustomerFocus() {
        if (this.filteredCustomers.length > 0) {
            this.showCustomerSuggestions = true;
        }
    }

    selectCustomer(event) {
        this.selectedCustomerId = event.currentTarget.dataset.id;
        const selected = this.filteredCustomers.find(c => c.value === this.selectedCustomerId);
        this.customerSearch = selected ? selected.label : '';
        this.customerName = selected ? selected.label : '';
        this.showCustomerSuggestions = false;
    }

    handleCustomerChange(event) {
        this.selectedCustomer = event.detail.value;
    }

    handleFromDateChange(event) {
        this.fromDate = event.detail.value;
    }

    handleToDateChange(event) {
        this.toDate = event.detail.value;
    }

    handleStatusChange(event) {
        this.status = event.detail.value;
    }

    handleSearchChange(event) {
        this.srchVal = event.detail.value;
    }

   handleGenerateLedger() {
        if (!this.selectedCustomerId) {
            this.showToast('Validation Error', 'Please select a Customer', 'error');
            return;
        }
        if (!this.fromDate || !this.toDate) {
            this.showToast('Validation Error', 'Please select both From Date and To Date', 'error');
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';
        this.allLedgerData = [];
        this.isDataExisted = false;

        // Step 1: Fetch opening balance
        getOpeningBalance({
            customerId: this.selectedCustomerId,
            asOfDate: this.fromDate
        })
        .then(openingBalResult => {
            const openingBalance = Number(openingBalResult?.balance) || 0;
            console.log('Opening Balance:', openingBalance);

            // Step 2: Fetch ledger transactions
            return getSecondaryLedger({
                customerId: this.selectedCustomerId,
                fromDate: this.fromDate,
                toDate: this.toDate,
                status: this.status
            }).then(ledgerResult => ({ openingBalance, ledgerResult }));
        })
        .then(({ openingBalance, ledgerResult }) => {
            const ledgerData = ledgerResult?.ledgerData || [];
            console.log('Ledger entries fetched:', ledgerData.length);

            this.showCustomerSuggestions = false;

            // Step 3: Opening Balance Row
            const openingRow = {
                uniqueKey: 'opening-balance',
                rowIndex: '1',
                transactionDate: this.fromDate,
                description: 'Opening Balance',
                transactionNo: 'Opening Balance',
                referenceNo: '-',
                debitAmount: openingBalance > 0 ? this.formatAmount(openingBalance) : '',
                creditAmount: openingBalance < 0 ? this.formatAmount(Math.abs(openingBalance)) : '',
                balance: this.formatAmount(openingBalance),
                isOpeningBalance: true,
                rowClass: 'opening-balance-row'
            };

            // Step 4: Process ledger entries
            let runningBalance = Number(openingBalance) || 0;

            const processedData = ledgerData.map((entry, index) => {

                const isDebit = entry.transactionType === 'Secondary Invoice' ||
                                entry.transactionType === 'Invoice' ||
                                entry.transactionType === 'Debit Note';

                const isCredit = entry.transactionType === 'Receipt' ||
                                entry.transactionType === 'Credit Note';

                const amount = Number(entry.amount) || 0;

                const debitAmt  = isDebit  ? amount : 0;
                const creditAmt = isCredit ? amount : 0;

                // Correct running balance
                runningBalance = Number(runningBalance) + debitAmt - creditAmt;

                return {
                    ...entry,
                    uniqueKey: (entry.transactionNo || 'txn') + '-' + index,
                    rowIndex: index + 2,
                    debitAmount:  debitAmt  > 0 ? this.formatAmount(debitAmt)  : '',
                    creditAmount: creditAmt > 0 ? this.formatAmount(creditAmt) : '',
                    balance: this.formatAmount(runningBalance),
                    isOpeningBalance: false,
                    rowClass: ''
                };
            });

            // Step 5: Combine data
            this.allLedgerData = [openingRow, ...processedData];
            this.isDataExisted = processedData.length > 0;

            if (!this.isDataExisted) {
                this.errorMessage = 'No ledger data found for the selected criteria';
            }

            this.isLoading = false;
        })
        .catch(error => {
            console.error('Error fetching ledger data:', error);
            this.errorMessage = 'Failed to fetch ledger data: ' + 
                (error.body?.message || error.message || 'Unknown error');
            this.isLoading = false;
        });
    }


    // Safe formatter (prevents NaN)
    formatAmount(value) {
        const num = Number(value);

        if (isNaN(num)) {
            return '0.00';
        }

        return num.toLocaleString('en-IN', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    handleExportCsv() {
        console.log('Export CSV clicked'); // Add this to confirm click is firing
        console.log('Ledger data length:', this.allLedgerData.length);

        if (!this.allLedgerData || this.allLedgerData.length === 0) {
            this.showToast('Export Error', 'No ledger data to export', 'error');
            return;
        }

        try {
            const headers = ['S.No.', 'Transaction Date', 'Doc Type', 'Doc No', 'Debit (INR)', 'Credit (INR)', 'Balance (INR)'];

            const rows = this.allLedgerData.map(record => [
                record.rowIndex || '',
                record.transactionDate || '',
                record.description || '',
                record.referenceNo || '',
                record.debitAmount || '',
                record.creditAmount || '',
                record.balance || ''
            ]);

            const csvContent = [headers, ...rows]
                .map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(','))
                .join('\n');

            const blob = new Blob(['\ufeff' + csvContent], { type: 'text/plain' });
            const url = URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.download = `Ledger_${this.customerName || 'Customer'}_${this.fromDate}_to_${this.toDate}.csv`;
            link.style.display = 'none';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            URL.revokeObjectURL(url);
        } catch (error) {
            console.error('CSV Export Error:', error);
            this.showToast('Export Error', 'Failed to export CSV', 'error');
        }
    }
    handlePrint() {
        if (this.allLedgerData.length === 0) {
            this.showToast('Print Error', 'No ledger data to print', 'error');
            return;
        }
        window.print();
    }
    // ─────────────────────────────────────────────────────────────────
    // XLSX EXPORT — Works in LWS + Chrome
    // Uses text/plain blob (only allowed MIME) + .xls extension
    // Excel/Sheets opens TSV with .xls extension natively
    // ─────────────────────────────────────────────────────────────────
    handleExportXlsx() {
        this.showDownloadMenu = false;
        if (!this.allLedgerData || this.allLedgerData.length === 0) {
            this.showToast('Export Error', 'No ledger data to export', 'error');
            return;
        }

        try {
            const XLSX = window.XLSX;
            if (!XLSX) {
                this.showToast('Export Error', 'Excel library not loaded yet, please retry', 'error');
                return;
            }

            const headers = ['S.No.', 'Transaction Date', 'Doc Type', 'Doc No', 'Debit (INR)', 'Credit (INR)', 'Balance (INR)'];

            const rows = this.allLedgerData.map(record => [
                record.rowIndex        || '',
                record.transactionDate || '',
                record.description     || '',
                record.referenceNo     || '',
                record.debitAmount     || '',
                record.creditAmount    || '',
                record.balance         || ''
            ]);

            const wsData = [headers, ...rows];
            const ws     = XLSX.utils.aoa_to_sheet(wsData);

            // Column widths
            ws['!cols'] = [
                { wch: 6 }, { wch: 16 }, { wch: 22 },
                { wch: 18 }, { wch: 14 }, { wch: 14 }, { wch: 14 }
            ];

            const wb = XLSX.utils.book_new();
            XLSX.utils.book_append_sheet(wb, ws, 'Ledger');
            XLSX.writeFile(wb, `Ledger_${this.customerName || 'Customer'}_${this.fromDate}_to_${this.toDate}.xlsx`);

        } catch (error) {
            console.error('XLSX Export Error:', error);
            this.showToast('Export Error', 'Failed to export: ' + error.message, 'error');
        }
    }


    // ─────────────────────────────────────────────────────────────────
    // PDF EXPORT — Works in LWS + Chrome
    // Strategy: inject a full-page print overlay into the CURRENT document,
    // call window.print(), then remove the overlay.
    // This avoids window.open (blocked) and data: URI nav (blocked by Chrome).
    // ─────────────────────────────────────────────────────────────────
    handleExportPdf() {
        this.showDownloadMenu = false;
        if (!this.allLedgerData || this.allLedgerData.length === 0) {
            this.showToast('Export Error', 'No ledger data to export', 'error');
            return;
        }

        try {
            const title = `Ledger — ${this.customerName || 'Customer'} | ${this.fromDate} to ${this.toDate}`;

            // Build table rows HTML
            let rowsHtml = '';
            this.allLedgerData.forEach(record => {
                const bg = record.isOpeningBalance ? 'background:#dceef5;font-weight:bold;' : '';
                rowsHtml += `<tr style="${bg}">
                    <td>${record.rowIndex        || ''}</td>
                    <td>${record.transactionDate || ''}</td>
                    <td>${record.description     || ''}</td>
                    <td>${record.referenceNo     || ''}</td>
                    <td class="num">${record.debitAmount  || ''}</td>
                    <td class="num">${record.creditAmount || ''}</td>
                    <td class="num bold">${record.balance || ''}</td>
                </tr>`;
            });

            // Create a div that covers the page ONLY during print
            const printDiv = document.createElement('div');
            printDiv.id = 'lwc-print-overlay';
            printDiv.innerHTML = `
                <style id="lwc-print-style">
                    @media print {
                        @page { margin: 0; padding: 10mm; }
                        body * { visibility: hidden !important; }
                        #lwc-print-overlay, #lwc-print-overlay * { visibility: visible !important; }
                        #lwc-print-overlay { position: absolute !important; top: 0; left: 0; width: 100%; display: block !important; }
                    }
                </style>
                <div id="lwc-print-content">
                    <h2>${title}</h2>
                    <table>
                        <thead>
                            <tr>
                                <th>S.No.</th>
                                <th>Transaction Date</th>
                                <th>Doc Type</th>
                                <th>Doc No</th>
                                <th class="num">Debit (&#8377;)</th>
                                <th class="num">Credit (&#8377;)</th>
                                <th class="num">Balance (&#8377;)</th>
                            </tr>
                        </thead>
                        <tbody>${rowsHtml}</tbody>
                    </table>
                </div>
                <style>
                    #lwc-print-overlay {
                        display: none; /* hidden on screen, shown on print via @media above */
                        position: fixed;
                        top: 0; left: 0;
                        width: 100%; height: 100%;
                        background: white;
                        z-index: 99999;
                        padding: 20px;
                        box-sizing: border-box;
                    }
                    #lwc-print-content {
                        font-family: Arial, sans-serif;
                        font-size: 12px;
                        color: #333;
                    }
                    #lwc-print-content h2 {
                        font-size: 14px;
                        color: #02323e;
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
                        font-size: 11px;
                        text-align: left;
                    }
                    #lwc-print-content td {
                        padding: 6px 9px;
                        border-bottom: 1px solid #e0e0e0;
                        font-size: 11px;
                    }
                    #lwc-print-content .num  { text-align: right; }
                    #lwc-print-content .bold { font-weight: bold; }
                </style>`;

            document.body.appendChild(printDiv);

            // Brief timeout lets DOM paint before print dialog
            setTimeout(() => {
                window.print();
                // Remove overlay after print dialog closes (afterprint fires on close)
                const cleanup = () => {
                    const overlay = document.getElementById('lwc-print-overlay');
                    if (overlay) overlay.parentNode.removeChild(overlay);
                    window.removeEventListener('afterprint', cleanup);
                };
                window.addEventListener('afterprint', cleanup);
                // Fallback cleanup if afterprint doesn't fire (some browsers)
                setTimeout(cleanup, 5000);
            }, 100);

        } catch (error) {
            console.error('PDF Export Error:', error);
            this.showToast('Export Error', 'Failed to export PDF: ' + error.message, 'error');
        }
    }

 
    // Getter: controls table visibility
    get hasLedgerData() {
        return this.allLedgerData && this.allLedgerData.length > 0;
    }

    // Custom Toast helper
    showToast(title, message, variant) {
        const toast = this.template.querySelector('c-custom-toast');
        if (toast) {
            toast.showToast(variant, message);
        } else {
            console.error('Custom Toast component not found!');
        }
    }
}