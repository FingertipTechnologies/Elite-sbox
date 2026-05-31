import { LightningElement, track } from 'lwc';
import searchCustomers from '@salesforce/apex/DMSPortalLwc.searchCustomers';
import saveSecondaryReceiptWithDetails from '@salesforce/apex/DMSPortalLwc.saveSecondaryReceiptWithDetails';
import allSecondaryReceiptData from '@salesforce/apex/DMSPortalLwc.allSecondaryReceiptData';
import getPendingSecondaryInvoicesByCustomer from '@salesforce/apex/DMSPortalLwc.getPendingSecondaryInvoicesByCustomer';
import getPendingDebitNotesByCustomer from '@salesforce/apex/DMSPortalLwc.getPendingDebitNotesByCustomer';
import getSecondaryReceiptItemsByReceiptId from '@salesforce/apex/DMSPortalLwc.getSecondaryReceiptItemsByReceiptId';

export default class NewSecondaryReceipt extends LightningElement {
    @track showReceiptItemsPage = false;
    @track selectedReceiptId = null;
    @track selectedReceiptNo = null;
    @track pendingInvoices = [];
    @track pendingDebitNotes = [];
    @track payingNowMap = {};
    @track amountMessage = '';
    @track showNewSecondaryReceiptForm = false;
    @track customerSearch = '';
    @track selectedReceipt = null;
    @track receiptItems = [];
    @track hasReceiptItems = false;
    isPageLoaded = false;
    isReceiptPageLoaded = false;
    showinvoices = false;

    get isAutoFillDisabled() {
        const enteredAmount = parseFloat(this.totalAmount) || 0;
        const totalPending = this.totalPendingAll;
        return enteredAmount > totalPending && totalPending > 0;
    }

    get totalPendingAll() {
        const invPending = this.pendingInvoices.reduce((sum, inv) => sum + (inv.pendingAmount || 0), 0);
        const dnPending = this.pendingDebitNotes.reduce((sum, dn) => sum + (dn.pendingAmount || 0), 0);
        return invPending + dnPending;
    }


    get invoicePayingTotal() {
        return this.pendingInvoices.reduce((sum, inv) => sum + (inv.payingNow || 0), 0);
    }

    get debitNotePayingTotal() {
        return this.pendingDebitNotes.reduce((sum, dn) => sum + (dn.payingNow || 0), 0);
    }


    get netAmount() {
        return this.invoicePayingTotal + this.debitNotePayingTotal;
    }

    get hasPendingDebitNotes() {
        return this.pendingDebitNotes && this.pendingDebitNotes.length > 0;
    }



    closeReceiptDetail() {
        this.selectedReceipt = null;
    }


    handleReceiptClick(event) {
        const receiptId = event.currentTarget.dataset.id;
        const found = this.receipts.find(r => r.id === receiptId);
        if (found) {
            this.selectedReceiptId = found.id;
            this.selectedReceiptNo = found.receiptNo;
            this.showReceiptItemsPage = true;
            this.fetchReceiptItems(found.id);
        }
    }

    fetchReceiptItems(receiptId) {
        this.isSubPartLoad = true;
        getSecondaryReceiptItemsByReceiptId({ receiptId: receiptId })
            .then(result => {
                this.receiptItems = result.map((item, index) => ({
                    rowIndex  : index + 1,
                    name      : item.name,
                    docNo     : item.docNo,
                    createdDate: item.createdDate,
                    amount    : item.amount,
                    itemType  : item.itemType
                }));
                this.isSubPartLoad = false;
                this.hasReceiptItems = this.receiptItems.length > 0;
            })
            .catch(error => {
                console.error('Error fetching receipt items:', error);
                this.receiptItems = [];
                this.hasReceiptItems = false;
                this.isSubPartLoad = false;
            });
    }

    handleBackToReceipts() {
        this.showReceiptItemsPage = false;
        this.selectedReceiptId = null;
        this.selectedReceiptNo = null;
        this.receiptItems = [];
        this.hasReceiptItems = false;
    }

    downloadReceiptsAsCSV() {
        if (!this.originalReceipts || this.originalReceipts.length === 0) {
            if (this.showToast) {
                this.showToast('No Data Found', 'No secondary receipts found for the selected filters.', 'error');
            } else {
                alert('No secondary receipts found for the selected filters.');
            }
            return;
        }
        const header = ['S.No.', 'Receipt No', 'Customer Name', 'Payment Date', 'Payment Mode', 'Reference No', 'Remark','Amount'];
        const rows = this.originalReceipts.map(rec => [
            rec.rowIndex,
            rec.receiptNo || '',
            rec.customerName || '',
            rec.paymentDate || '',
            rec.paymentMode || '',
            rec.referenceNumber || '',
            rec.remarks || '',
            rec.amount || ''
        ]);
        let csvContent = 'data:text/csv;charset=utf-8,' + header.join(',') + '\n';
        rows.forEach(row => {
            csvContent += row.join(',') + '\n';
        });
        const encodedUri = encodeURI(csvContent);
        const link = document.createElement('a');
        link.setAttribute('href', encodedUri);
        link.setAttribute('download', 'secondary_receipts.csv');
        link.click();
    }

    handleListCustomerSearch(event) {
        this.searchSecondaryCustomerName = event.detail.value || event.target.value;
        this.applyListFilters();
    }

    selectListCustomer(event) {
        const selectedName = event.currentTarget.dataset.name;
        this.searchSecondaryCustomerName = selectedName;
        this.showListCustomerSuggestions = false;
        this.applyListFilters();
    }

    applyListFilters() {
        let filtered = [...this.originalReceipts];
        if (this.searchReceiptNo) {
            const key = this.searchReceiptNo.toLowerCase();
            filtered = filtered.filter(n => n.receiptNo && n.receiptNo.toLowerCase().includes(key));
        }
        if (this.searchSecondaryCustomerName) {
            const key = this.searchSecondaryCustomerName.toLowerCase();
            filtered = filtered.filter(n => n.customerName && n.customerName.toLowerCase().includes(key));
        }
        this.receipts = filtered.length > 0 ? filtered : null;
    }

    handleNewSecondaryReceipt() {
        this.showNewSecondaryReceiptForm = true;
    }

    handleCancel() {
        this.showNewSecondaryReceiptForm = false;
        this.customerSearch = '';
        this.selectedCustomerId = '';
        this.filteredCustomers = [];
        this.showCustomerSuggestions = false;
        this.paymentDate = new Date().toLocaleDateString('en-CA');
        this.paymentMode = '';
        this.referenceNumber = '';
        this.totalAmount = null;
        this.remarks = '';
        this.loadReceipts();
    }
    @track customerOptions = [];
    @track selectedCustomerId = '';
    @track filteredCustomers = [];
    @track showCustomerSuggestions = false;
    @track customerName = '';

    // New fields for Secondary Receipt
    @track paymentDate = '';
    @track paymentMode = '';
    @track paymentModeOptions = [
        { label: 'Cash', value: 'Cash' },
        { label: 'Cheque', value: 'Cheque' },
        { label: 'NEFT', value: 'NEFT' },
        { label: 'RTGS', value: 'RTGS' },
        { label: 'IMPS', value: 'IMPS' },
        { label: 'UPI', value: 'UPI' },
        { label: 'Other', value: 'Other' }
    ];
    @track referenceNumber = '';
    @track totalAmount = null;
    @track remarks = '';

    // List view properties
    @track receipts = [];
    @track originalReceipts = [];
    @track fromDate = '';
    @track toDate = '';
    @track searchReceiptNo = '';
    @track searchSecondaryCustomerName = '';
    @track filteredListCustomers = [];
    @track showListCustomerSuggestions = false;

    isPageLoaded = false;
    isSubPartLoad = false;

    connectedCallback() {
        const today = new Date();
        this.paymentDate = today.toLocaleDateString('en-CA');
        this.initReceiptList();
    }

    initReceiptList() {
        const today = new Date();
        const firstDate = new Date(today.getFullYear(), today.getMonth(), 1);
        const lastDate = new Date(today.getFullYear(), today.getMonth() + 1, 0);
        const formatDate = (d) => d.toLocaleDateString('en-CA');
        this.fromDate = formatDate(firstDate);
        this.toDate = formatDate(lastDate);
        this.loadReceipts();
    }

    loadReceipts() {
        this.isSubPartLoad = true;
        allSecondaryReceiptData({ frmDate: this.fromDate, toDate: this.toDate, status: '' })
            .then(result => {
                const data = result.totalSecondaryReceiptData || [];
                if (result.reasonOptions) {
                    this.reasonOptions = result.reasonOptions
                        .filter(opt => opt.value !== 'All')
                        .map(opt => ({ label: opt.label, value: opt.value }));
                }
                this.originalReceipts = data.map((rec, index) => ({
                    id: rec.receiptId,
                    rowIndex: index + 1,
                    receiptNo: rec.receiptNo, // This should be the auto number field (Secondary Receipt Name)
                    customerName: rec.customerName,
                    paymentDate: rec.paymentDate,
                    paymentMode: rec.paymentMode,
                    referenceNumber: rec.referenceNumber,
                    remarks: rec.remarks,
                    totalAmount:rec.totalAmount
                }));
                this.receipts = [...this.originalReceipts];
                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error('Error loading receipts:', error);
                this.isSubPartLoad = false;
            });
    }

    handleFromDateChange(event) {
        this.fromDate = event.target.value;
        this.searchReceiptNo = '';
        this.searchSecondaryCustomerName = '';
        this.loadReceipts();
    }

    handleToDateChange(event) {
        this.toDate = event.target.value;
        this.searchReceiptNo = '';
        this.searchSecondaryCustomerName = '';
        this.loadReceipts();
    }

    handleSearchReceiptNo(event) {
        this.searchReceiptNo = event.target.value;
        this.applyListFilters();
    }

    handleListCustomerFocus() {
        this.showListCustomerSuggestions = false;
    }
    // Handlers for new fields
    handlePaymentDateChange(event) {
        this.paymentDate = event.target.value;
    }
    handlePaymentModeChange(event) {
        this.paymentMode = event.detail.value;
    }
    handleReferenceNumberChange(event) {
        this.referenceNumber = event.target.value;
    }
    handleTotalAmountChange(event) {
        this.totalAmount = event.target.value;
        // Validation: entered amount should not exceed total pending amount (invoices + debit notes)
        const enteredAmount = parseFloat(this.totalAmount) || 0;
        const totalPending = this.totalPendingAll;
        if (enteredAmount > totalPending && totalPending > 0) {
            this.amountMessage = 'Entered amount exceeds pending amount. Please check and enter a valid amount.';
        } else {
            this.handleAutoFillOldestFirst();
            this.amountMessage = '';
        }
    }
    handleRemarksChange(event) {
        this.remarks = event.target.value;
    }


    handleCustomerFocus() {
        this.showCustomerSuggestions = false;
    }

    handleCustomerSearch(event) {
        this.customerSearch = event.target.value;
        const searchVal = this.customerSearch?.trim();

        // Reset if empty or cleared
        if (!searchVal || searchVal.length < 2) {
            this.filteredCustomers = [];
            this.showCustomerSuggestions = false;
            this.selectedCustomerId = '';
            this.showinvoices = false;
            return;
        }

        // Call Apex search
        searchCustomers({ searchKey: searchVal })
            .then(result => {
                this.filteredCustomers = result.map(acc => ({
                    label: acc.Name,
                    value: acc.Id,
                    landmark: acc.Land_Mark__c,
                    street: acc.Street__c
                }));
                this.customerOptions = this.filteredCustomers;
                this.showCustomerSuggestions = this.filteredCustomers.length > 0;
            })
            .catch(error => {
                console.error('Customer search error', error);
                this.filteredCustomers = [];
                this.showCustomerSuggestions = false;
            });
    }

    selectCustomer(event) {
        this.selectedCustomerId = event.currentTarget.dataset.id;
        const selected = this.filteredCustomers.find(c => c.value === this.selectedCustomerId);
        this.customerSearch = selected ? selected.label : '';
        this.customerName = selected ? selected.label : '';
        this.showCustomerSuggestions = false;
        this.showinvoices = true;


        // Clear stale data immediately before new fetch
        this.pendingInvoices = [];
        this.pendingDebitNotes = [];
        this.availableAdvances = [];
        this.payingNowMap = {};

        // Fetch pending invoices, debit notes, and advances for this customer
        if (this.selectedCustomerId) {
            this.isPageLoaded = true;
            const custId = this.selectedCustomerId;

            // Fetch all three in parallel
            Promise.all([
                getPendingSecondaryInvoicesByCustomer({ customerId: custId }),
                getPendingDebitNotesByCustomer({ customerId: custId })
            ])
            .then(([invoiceResult, debitNoteResult]) => {
               // Map invoices
            this.pendingInvoices = invoiceResult.map((inv, index) => ({
                rowIndex: index + 1,
                InvId: inv.InvId,
                name: inv.name,
                InvDate: inv.InvDate,
                invoiceAmount: inv.Amount != null ? inv.Amount : 0,
                alreadyPaid: inv.paidAmount != null ? inv.paidAmount : 0,
                pendingAmount: inv.pendingAmount != null ? inv.pendingAmount : 0,
                payingNow: 0,
                balance: inv.pendingAmount != null ? Math.round((inv.pendingAmount + Number.EPSILON) * 100) / 100 : 0
            }));
            this.payingNowMap = {};

            // Map debit notes
            this.pendingDebitNotes = debitNoteResult.map((dn, index) => ({
                rowIndex: index + 1,
                debitNoteId: dn.debitNoteId,
                name: dn.name,
                noteDate: dn.noteDate,
                amount: dn.amount != null ? dn.amount : 0,
                paidAmount: dn.paidAmount != null ? dn.paidAmount : 0,
                pendingAmount: dn.pendingAmount != null ? dn.pendingAmount : 0,
                reason: dn.reason,
                payingNow: 0,
                balance: dn.pendingAmount != null ? Math.round((dn.pendingAmount + Number.EPSILON) * 100) / 100 : 0
            }));


                this.isPageLoaded = false;
            })
            .catch(error => {
                console.error('Error fetching customer data:', error);
                this.pendingInvoices = [];
                this.pendingDebitNotes = [];
                this.availableAdvances = [];
                this.payingNowMap = {};
                this.isPageLoaded = false;
            });
        } else {
            this.pendingInvoices = [];
            this.pendingDebitNotes = [];
            this.availableAdvances = [];
            this.payingNowMap = {};
        }
    }

    handlePayingNowChange(event) {
        const index = event.target.dataset.index;
        const value = parseFloat(event.target.value) || 0;
        this.payingNowMap[index] = value;
        this.pendingInvoices = this.pendingInvoices.map((inv, i) => {
            if (i == index) {
                const payingNow = value;
                let balance = (inv.pendingAmount || 0) - payingNow;
                balance = Math.round((balance + Number.EPSILON) * 100) / 100;
                return { ...inv, payingNow, balance };
            }
            return inv;
        });
    }

    handleDebitNotePayingNowChange(event) {
        const index = event.target.dataset.index;
        const value = parseFloat(event.target.value) || 0;
        this.pendingDebitNotes = this.pendingDebitNotes.map((dn, i) => {
            if (i == index) {
                const payingNow = value;
                let balance = (dn.pendingAmount || 0) - payingNow;
                balance = Math.round((balance + Number.EPSILON) * 100) / 100;
                return { ...dn, payingNow, balance };
            }
            return dn;
        });
    }

    handleAdvanceApplyingNowChange(event) {
        const index = event.target.dataset.index;
        const value = parseFloat(event.target.value) || 0;
        this.availableAdvances = this.availableAdvances.map((adv, i) => {
            if (i == index) {
                const applyingNow = value;
                let remaining = (adv.availableAmount || 0) - applyingNow;
                remaining = Math.round((remaining + Number.EPSILON) * 100) / 100;
                return { ...adv, applyingNow, remaining };
            }
            return adv;
        });
    }

    handleAutoFillOldestFirst() {
        let amountLeft = parseFloat(this.totalAmount) || 0;
        const parseDate = (d) => {
            if (!d) return new Date(0);
            if (d.includes('/')) {
                const [day, month, year] = d.split('/').map(Number);
                return new Date(year, month - 1, day);
            } else if (d.includes('-')) {
                const [year, month, day] = d.split('-').map(Number);
                return new Date(year, month - 1, day);
            }
            return new Date(d);
        };

        // Sort and allocate to invoices (oldest first)
        let sortedInv = [...this.pendingInvoices].sort((a, b) => parseDate(a.InvDate) - parseDate(b.InvDate));
        let invAllocation = [];
        for (let inv of sortedInv) {
            let pay = 0;
            if (amountLeft > 0) {
                pay = Math.min(inv.pendingAmount, amountLeft);
                amountLeft -= pay;
            }
            let balance = inv.pendingAmount - pay;
            balance = Math.round((balance + Number.EPSILON) * 100) / 100;
            invAllocation.push({ ...inv, payingNow: pay, balance });
        }
        this.pendingInvoices = this.pendingInvoices.map(inv => {
            const found = invAllocation.find(a => a.InvId === inv.InvId);
            return found ? found : inv;
        });
        this.payingNowMap = {};
        this.pendingInvoices.forEach((inv, idx) => {
            this.payingNowMap[idx] = inv.payingNow;
        });

        // Allocate remaining to debit notes (oldest first)
        let sortedDn = [...this.pendingDebitNotes].sort((a, b) => parseDate(a.noteDate) - parseDate(b.noteDate));
        let dnAllocation = [];
        for (let dn of sortedDn) {
            let pay = 0;
            if (amountLeft > 0) {
                pay = Math.min(dn.pendingAmount, amountLeft);
                amountLeft -= pay;
            }
            let balance = dn.pendingAmount - pay;
            balance = Math.round((balance + Number.EPSILON) * 100) / 100;
            dnAllocation.push({ ...dn, payingNow: pay, balance });
        }
        this.pendingDebitNotes = this.pendingDebitNotes.map(dn => {
            const found = dnAllocation.find(a => a.debitNoteId === dn.debitNoteId);
            return found ? found : dn;
        });
    }

    handleCancel() {
        this.reset();
    }
    reset() {
        this.showNewSecondaryReceiptForm = false;
        this.customerSearch = '';
        this.selectedCustomerId = '';
        this.showinvoices = false;
        this.filteredCustomers = [];
        this.showCustomerSuggestions = false;
        this.customerName = '';
        this.paymentDate = new Date().toLocaleDateString('en-CA');
        this.paymentMode = '';
        this.referenceNumber = '';
        this.totalAmount = null;
        this.remarks = '';
        this.pendingDebitNotes = [];
        this.availableAdvances = [];
        this.loadReceipts();
    }

    handleSave() {
        // Validate required fields
        if (!this.selectedCustomerId || !this.paymentDate || !this.paymentMode) {
            this.showToast('Validation Error', 'Please select all required fields.', 'error');
            return;
        }

        // Invoices
        for (let item of this.pendingInvoices) {
            if (item.payingNow > 0 && item.payingNow > item.pendingAmount) {
                this.showToast(
                    'Validation Error',
                    `Row ${item.rowIndex} - Invoice "${item.name}": Paying amount ${item.payingNow} cannot exceed pending amount ${item.pendingAmount}.`,
                    'error'
                );
                return;
            }
        }

        // Debit Notes
        for (let dn of this.pendingDebitNotes) {
            if (dn.payingNow > 0 && dn.payingNow > dn.pendingAmount) {
                this.showToast(
                    'Validation Error',
                    `Row ${dn.rowIndex} - Debit Note "${dn.name}": Paying amount ${dn.payingNow} cannot exceed pending amount ${dn.pendingAmount}.`,
                    'error'
                );
                return;
            }
        }
   

        const receiptData = {
            sobjectType: 'Secondary_Receipt__c',
            Customer__c: this.selectedCustomerId,
            Payment_Date__c: this.paymentDate,
            Payment_Mode__c: this.paymentMode,
            Reference_Number__c: this.referenceNumber,
            Total_Amount__c: this.netAmount,
            Remarks__c: this.remarks
        };

        // Build invoice receipt items
        const receiptItems = [];
        for (let item of this.pendingInvoices) {
            if (item.payingNow > 0) {
                receiptItems.push({
                    sobjectType: 'Secondary_Receipt_Item__c',
                    Secondary_Invoice__c: item.InvId,
                    Amount__c: item.payingNow
                });
            }
        }

        // Build debit note receipt items
        const debitItems = [];
        for (let dn of this.pendingDebitNotes) {
            if (dn.payingNow > 0) {
                debitItems.push({
                    sobjectType: 'Secondary_Receipt_Debit_Item__c',
                    Secondary_Debit_Note__c: dn.debitNoteId,
                    Amount__c: dn.payingNow
                });
            }
        }

        // Build advance receipt items


        this.isPageLoaded = true;
        saveSecondaryReceiptWithDetails({
            receiptData: receiptData,
            receiptItems: receiptItems,
            debitItems: debitItems
        })
            .then(() => {
                this.isPageLoaded = false;
                this.showNewSecondaryReceiptForm = false;
                this.showToast('Success', 'Receipt created successfully', 'Success');
                this.reset();
            })
            .catch(error => {
                this.isPageLoaded = false;
                console.error('Error saving receipt:', error);
                this.showToast('Error', 'Error saving receipt. Please try again.', 'error');
            });
    }

    // Custom Toast method (to use c-custom-toast)
    showToast(title, message, variant) {
        const toast = this.template.querySelector('c-custom-toast');
        console.log('Custom Toast component:', toast);
        if (toast) {
            toast.showToast(variant, message);
        } else {
            console.error('Custom Toast component not found!');
        }
    }
}