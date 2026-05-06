import { LightningElement, track } from 'lwc';
import searchCustomers from '@salesforce/apex/DMSPortalLwc.searchCustomers';
import saveCreditNote from '@salesforce/apex/DMSPortalLwc.saveCreditNote';
import allCreditNoteData from '@salesforce/apex/DMSPortalLwc.allCreditNoteData';

export default class NewCreditNote extends LightningElement {
    @track showNewCreditNoteForm = false;
    @track showUpload = false;
    @track customerSearch = '';
    @track customerOptions = [];
    @track selectedCustomerId = '';
    @track filteredCustomers = [];
    @track showCustomerSuggestions = false;

    @track noteDate = '';
    @track reason = '';
    @track amount = null;
    @track description = '';
    showCreditNotes = false;

    // List view properties
    @track creditNotes = [];
    @track originalCreditNotes = [];
    @track fromDate = '';
    @track toDate = '';
    @track searchCreditNoteNo = '';
    @track searchSecondaryCustomerName = '';
    @track filteredListCustomers = [];
    @track showListCustomerSuggestions = false;

    isPageLoaded = false;
    isSubPartLoad = false;

    @track reasonOptions = [];

    connectedCallback() {
        const today = new Date();
        this.noteDate = today.toLocaleDateString('en-CA');
        this.initCreditNoteList();
    }

    initCreditNoteList() {
        const today = new Date();
        const firstDate = new Date(today.getFullYear(), today.getMonth(), 1);
        const lastDate = new Date(today.getFullYear(), today.getMonth() + 1, 0);
        const formatDate = (d) => d.toLocaleDateString('en-CA');
        this.fromDate = formatDate(firstDate);
        this.toDate = formatDate(lastDate);
        this.loadCreditNotes();
    }

    loadCreditNotes() {
        this.isSubPartLoad = true;
        allCreditNoteData({ frmDate: this.fromDate, toDate: this.toDate, status: '' })
            .then(result => {
                const data = result.totalCreditNoteData || [];
                if (result.reasonOptions) {
                    this.reasonOptions = result.reasonOptions
                        .filter(opt => opt.value !== 'All')
                        .map(opt => ({ label: opt.label, value: opt.value }));
                }
                this.originalCreditNotes = data.map((note, index) => ({
                    id: note.creditNoteId,
                    rowIndex: index + 1,
                    creditNoteNo: note.creditNoteNo,
                    customerName: note.customerName,
                    reason: note.reason,
                    date: note.creditDate,
                    amount: note.creditAmount
                }));
                this.creditNotes = [...this.originalCreditNotes];
                this.showCreditNotes = this.creditNotes.length >0 ? true : false ;
                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error('Error loading credit notes:', error);
                this.isSubPartLoad = false;
            });
    }

    handleFromDateChange(event) {
        this.fromDate = event.target.value;
        this.searchCreditNoteNo = '';
        this.searchSecondaryCustomerName = '';
        this.loadCreditNotes();
    }

    handleToDateChange(event) {
        this.toDate = event.target.value;
        this.searchCreditNoteNo = '';
        this.searchSecondaryCustomerName = '';
        this.loadCreditNotes();
    }

    handleSearchCreditNoteNo(event) {
        this.searchCreditNoteNo = event.target.value;
        this.applyListFilters();
    }

    handleListCustomerFocus() {
        this.showListCustomerSuggestions = false;
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
        let filtered = [...this.originalCreditNotes];
        if (this.searchCreditNoteNo) {
            const key = this.searchCreditNoteNo.toLowerCase();
            filtered = filtered.filter(n => n.creditNoteNo && n.creditNoteNo.toLowerCase().includes(key));
        }
        if (this.searchSecondaryCustomerName) {
            const key = this.searchSecondaryCustomerName.toLowerCase();
            filtered = filtered.filter(n => n.customerName && n.customerName.toLowerCase().includes(key));
        }
        this.creditNotes = filtered.length > 0 ? filtered : null;
        this.showCreditNotes = filtered.length >0 ? true : false ;
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
        const selectedId = event.currentTarget.dataset.id;
        const selected = this.customerOptions.find(acc => acc.value === selectedId);
        this.customerSearch = selected.label;
        this.selectedCustomerId = selected.value;
        this.showCustomerSuggestions = false;
    }

    handleReasonChange(event) {
        this.reason = event.detail.value;
    }

    handleAmountChange(event) {
        this.amount = parseFloat(event.detail.value) || 0;
    }

    handleDescriptionChange(event) {
        this.description = event.detail.value;
    
    }


    handleNoteDateChange(event) {
    this.noteDate = event.detail.value;
}

    handleSave() {
        if (!this.selectedCustomerId) {
            this.showToast('Validation Error', 'Please select a Secondary Customer.', 'error');
            return;
        }
        if (!this.reason) {
            this.showToast('Validation Error', 'Please select a Reason.', 'error');
            return;
        }
        if (!this.amount || this.amount <= 0) {
            this.showToast('Validation Error', 'Please enter a valid Amount.', 'error');
            return;
        }

        this.isPageLoaded = true;

        const creditNoteData = {
            customerId: this.selectedCustomerId,
            noteDate: this.noteDate,
            reason: this.reason,
            amount: this.amount,
            description: this.description || ''
        };

        saveCreditNote({ creditNoteJson: JSON.stringify(creditNoteData) })
            .then(() => {
                this.showToast('Success', 'Credit Note created successfully.', 'success');
                this.isPageLoaded = false;
                this.showNewCreditNoteForm = false;
                this.customerSearch = '';
                this.selectedCustomerId = '';
                this.reason = '';
                this.amount = null;
                this.description = '';
                this.loadCreditNotes();
            })
            .catch(error => {
                console.error('Save error', error);
                const msg = error.body?.message || 'An error occurred while saving.';
                this.showToast('Error', msg, 'error');
                this.isPageLoaded = false;
            });
    }

    handleNewCreditNote() {
        this.showNewCreditNoteForm = true;
    }

    handleShowUpload() {
        this.showUpload = true;
    }

    handleUploadClose() {
        this.showUpload = false;
        this.loadCreditNotes();
    }

    handleUploadComplete() {
        this.loadCreditNotes();
    }

    handleCancel() {
        this.showNewCreditNoteForm = false;
        this.customerSearch = '';
        this.selectedCustomerId = '';
        this.filteredCustomers = [];
        this.showCustomerSuggestions = false;
        this.reason = '';
        this.amount = null;
        this.description = '';
        const today = new Date();
        this.noteDate = today.toLocaleDateString('en-CA');
        this.loadCreditNotes();
    }

    showToast(title, message, variant) {
        const toast = this.template.querySelector('c-custom-toast');
        if (toast) {
            toast.showToast(variant, message);
        }
    }

    downloadCreditNotesAsCSV() {
        if (!this.originalCreditNotes || this.originalCreditNotes.length === 0) {
            this.showToast('No Data Found', 'No credit notes found for the selected filters.', 'error');
            return;
        }

        const header = ['S.No.', 'Credit Note No', 'Customer Name', 'Reason', 'Date', 'Amount'];

        const rows = this.originalCreditNotes.map(note => [
            note.rowIndex,
            note.creditNoteNo || '',
            note.customerName || '',
            note.reason || '',
            note.date || '',
            note.amount || 0
        ]);

        let csvContent = 'data:text/csv;charset=utf-8,' + header.join(',') + '\n';
        rows.forEach(row => {
            csvContent += row.join(',') + '\n';
        });

        const encodedUri = encodeURI(csvContent);
        const link = document.createElement('a');
        link.setAttribute('href', encodedUri);
        link.setAttribute('download', 'secondary_credit_notes.csv');
        link.click();
    }
}