import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import SHEETJS from '@salesforce/resourceUrl/SheetJS';
import getOutstandingReport from '@salesforce/apex/DMSPortalLwc.getOutstandingReport';

export default class OutstandingReport extends LightningElement {
    @api customerId;
    @api customerName;

    @track reportData = [];
    @track isLoading = true;
    @track showDownloadMenu = false;
    @track totalDocumentAmount = 0;
    @track totalCollectedAmount = 0;
    @track totalCreditAdjustedAmount = 0;
    @track totalOutstandingAmount = 0;

    sheetJsLoaded = false;

    connectedCallback() {
        this.fetchData();
        if (!this.sheetJsLoaded) {
            loadScript(this, SHEETJS)
                .then(() => { this.sheetJsLoaded = true; })
                .catch(err => { console.error('SheetJS load error:', err); });
        }
    }

    get hasData() {
        return this.reportData.length > 0;
    }

    get noData() {
        return !this.isLoading && this.reportData.length === 0;
    }

    get formattedTotalDocument() {
        return this.formatCurrency(this.totalDocumentAmount);
    }

    get formattedTotalCollected() {
        return this.formatCurrency(this.totalCollectedAmount);
    }

    get formattedTotalCreditAdjusted() {
        return this.formatCurrency(this.totalCreditAdjustedAmount);
    }

    get formattedTotalOutstanding() {
        return this.formatCurrency(this.totalOutstandingAmount);
    }

    fetchData() {
        this.isLoading = true;
        getOutstandingReport({ customerId: this.customerId })
            .then(result => {
                let totalDoc = 0;
                let totalCol = 0;
                let totalCredit = 0;
                let totalOut = 0;

                this.reportData = (result || []).map((item, index) => {
                    const docAmt = Number(item.documentAmount) || 0;
                    const colAmt = Number(item.collectedAmount) || 0;
                    const creditAmt = Number(item.creditAdjustedAmount) || 0;
                    const outAmt = Number(item.outstandingAmount) || 0;
                    totalDoc += docAmt;
                    totalCol += colAmt;
                    totalCredit += creditAmt;
                    totalOut += outAmt;

                    return {
                        ...item,
                        sno: index + 1,
                        key: item.documentType + '-' + item.documentNumber,
                        formattedDate: item.documentDate,
                        formattedDocAmount: this.formatCurrency(docAmt),
                        formattedCollected: this.formatCurrency(colAmt),
                        formattedCreditAdjusted: this.formatCurrency(creditAmt),
                        formattedOutstanding: this.formatCurrency(outAmt)
                    };
                });

                this.totalDocumentAmount = totalDoc;
                this.totalCollectedAmount = totalCol;
                this.totalCreditAdjustedAmount = totalCredit;
                this.totalOutstandingAmount = totalOut;
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error fetching outstanding report:', error);
                this.reportData = [];
                this.isLoading = false;
            });
    }

    formatCurrency(value) {
        return Number(value || 0).toLocaleString('en-IN', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    handleBack() {
        this.isLoading = true;
        setTimeout(() => {
            this.isLoading = false;
        }, 3000);
        this.dispatchEvent(new CustomEvent('back'));
    }

    // ==================== Download ====================

    toggleDownloadMenu() {
        this.showDownloadMenu = !this.showDownloadMenu;
    }

    get exportHeaders() {
        return [
            'S.No', 'Type', 'Primary Customer SAP Code', 'Primary Customer Name',
            'Secondary Customer Code', 'Secondary Customer Name',
            'Executive Code', 'Executive Name', 'Beat Name',
            'Document Number', 'Document Date',
            'Amount', 'Collected Amount', 'Credit Adjusted Amount', 'Outstanding Amount'
        ];
    }

    get exportRows() {
        const rows = this.reportData.map(r => [
            r.sno, r.documentType, r.primaryCustomerSapCode, r.primaryCustomerName,
            r.secondaryCustomerCode, r.secondaryCustomerName,
            r.executiveCode || '', r.executiveName || '', r.beatName || '',
            r.documentNumber, r.documentDate,
            Number(r.documentAmount) || 0, Number(r.collectedAmount) || 0,
            Number(r.creditAdjustedAmount) || 0, Number(r.outstandingAmount) || 0
        ]);
        rows.push([
            '', '', '', '', '', '', '', '', '', '', 'Total',
            this.totalDocumentAmount, this.totalCollectedAmount,
            this.totalCreditAdjustedAmount, this.totalOutstandingAmount
        ]);
        return rows;
    }

    get exportFileName() {
        return `Outstanding_Report_${(this.customerName || 'Customer').replace(/[^a-zA-Z0-9]/g, '_')}`;
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

            const wsData = [this.exportHeaders, ...this.exportRows];
            const ws = XLSX.utils.aoa_to_sheet(wsData);
            ws['!cols'] = this.exportHeaders.map(() => ({ wch: 20 }));

            const wb = XLSX.utils.book_new();
            XLSX.utils.book_append_sheet(wb, ws, 'Outstanding Report');
            XLSX.writeFile(wb, this.exportFileName + '.xlsx');
        } catch (error) {
            console.error('XLSX Export Error:', error);
        }
    }

    handleExportPdf() {
        this.showDownloadMenu = false;
        if (!this.hasData) return;

        try {
            const title = `Outstanding Report — ${this.customerName || 'Customer'}`;

            let rowsHtml = '';
            this.reportData.forEach(r => {
                rowsHtml += `<tr>
                    <td>${r.sno}</td>
                    <td>${r.documentType}</td>
                    <td>${r.primaryCustomerSapCode || ''}</td>
                    <td>${r.primaryCustomerName || ''}</td>
                    <td>${r.secondaryCustomerCode || ''}</td>
                    <td>${r.secondaryCustomerName || ''}</td>
                    <td>${r.executiveCode || ''}</td>
                    <td>${r.executiveName || ''}</td>
                    <td>${r.beatName || ''}</td>
                    <td>${r.documentNumber || ''}</td>
                    <td>${r.formattedDate || ''}</td>
                    <td class="num">${r.formattedDocAmount}</td>
                    <td class="num">${r.formattedCollected}</td>
                    <td class="num">${r.formattedCreditAdjusted}</td>
                    <td class="num bold">${r.formattedOutstanding}</td>
                </tr>`;
            });

            rowsHtml += `<tr style="background:#dceef5;font-weight:bold;">
                <td colspan="11">Total</td>
                <td class="num">${this.formattedTotalDocument}</td>
                <td class="num">${this.formattedTotalCollected}</td>
                <td class="num">${this.formattedTotalCreditAdjusted}</td>
                <td class="num bold">${this.formattedTotalOutstanding}</td>
            </tr>`;

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
                    <table>
                        <thead>
                            <tr>
                                <th>S.No</th><th>Type</th>
                                <th>Pri. SAP Code</th><th>Pri. Customer</th>
                                <th>Sec. Code</th><th>Sec. Customer</th>
                                <th>Exec. Code</th><th>Exec. Name</th><th>Beat</th>
                                <th>Doc Number</th><th>Doc Date</th>
                                <th class="num">Amount</th>
                                <th class="num">Collected</th>
                                <th class="num">Credit Adjusted</th>
                                <th class="num">Outstanding</th>
                            </tr>
                        </thead>
                        <tbody>${rowsHtml}</tbody>
                    </table>
                </div>
                <style>
                    #lwc-print-overlay { display:none; position:fixed; top:0; left:0; width:100%; height:100%; background:white; z-index:99999; padding:20px; box-sizing:border-box; overflow:auto; }
                    #lwc-print-content { font-family:Arial,sans-serif; font-size:11px; color:#333; }
                    #lwc-print-content h2 { font-size:14px; color:#02323e; margin-bottom:12px; }
                    #lwc-print-content table { width:100%; border-collapse:collapse; }
                    #lwc-print-content th { background:#02323e; color:#fff; padding:6px 8px; font-size:9px; text-align:left; }
                    #lwc-print-content td { padding:5px 8px; border-bottom:1px solid #e0e0e0; font-size:9px; }
                    #lwc-print-content .num { text-align:right; }
                    #lwc-print-content .bold { font-weight:bold; }
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