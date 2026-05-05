import { LightningElement, track } from 'lwc';
import searchCustomers from '@salesforce/apex/DMSPortalLwc.searchCustomers';
import saveDebitNote from '@salesforce/apex/DMSPortalLwc.saveDebitNote';
import allDebitNoteData from '@salesforce/apex/DMSPortalLwc.allDebitNoteData';

export default class NewDebitNote extends LightningElement {
    @track showNewDebitNoteForm = false;
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

    // List view properties
    @track debitNotes = [];
    @track originalDebitNotes = [];
    @track fromDate = '';
    @track toDate = '';
    @track searchDebitNoteNo = '';
    @track searchSecondaryCustomerName = '';
    @track filteredListCustomers = [];
    @track showListCustomerSuggestions = false;
    showDebitNotes = false;

    isPageLoaded = false;
    isSubPartLoad = false;

    @track reasonOptions = [];

    connectedCallback() {
        const today = new Date();
        this.noteDate = today.toLocaleDateString('en-CA');
        this.initDebitNoteList();
    }

    initDebitNoteList() {
        const today = new Date();
        const firstDate = new Date(today.getFullYear(), today.getMonth(), 1);
        const lastDate = new Date(today.getFullYear(), today.getMonth() + 1, 0);
        const formatDate = (d) => d.toLocaleDateString('en-CA');
        this.fromDate = formatDate(firstDate);
        this.toDate = formatDate(lastDate);
        this.loadDebitNotes();
    }

    loadDebitNotes() {
        this.isSubPartLoad = true;
        allDebitNoteData({ frmDate: this.fromDate, toDate: this.toDate, status: '' })
            .then(result => {
                const data = result.totalDebitNoteData || [];
                if (result.reasonOptions) {
                    this.reasonOptions = result.reasonOptions
                        .filter(opt => opt.value !== 'All')
                        .map(opt => ({ label: opt.label, value: opt.value }));
                }
                this.originalDebitNotes = data.map((note, index) => ({
                    id: note.debitNoteId,
                    rowIndex: index + 1,
                    debitNoteNo: note.debitNoteNo ? note.debitNoteNo.replace(/\)$/,'') : '',
                    customerName: note.customerName,
                    reason: note.reason,
                    date: note.noteDate,
                    amount: note.amount,
                    description: note.description || ''
                }));
                this.debitNotes = [...this.originalDebitNotes];
                this.showDebitNotes = this.debitNotes.length >0 ? true : false ;
                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error('Error loading debit notes:', error);
                this.isSubPartLoad = false;
            });
    }

    handleFromDateChange(event) {
        this.fromDate = event.target.value;
        this.searchDebitNoteNo = '';
        this.searchSecondaryCustomerName = '';
        this.loadDebitNotes();
    }

    handleToDateChange(event) {
        this.toDate = event.target.value;
        this.searchDebitNoteNo = '';
        this.searchSecondaryCustomerName = '';
        this.loadDebitNotes();
    }

    handleSearchDebitNoteNo(event) {
        this.searchDebitNoteNo = event.target.value;
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
        let filtered = [...this.originalDebitNotes];
        if (this.searchDebitNoteNo) {
            const key = this.searchDebitNoteNo.toLowerCase();
            filtered = filtered.filter(n => n.debitNoteNo && n.debitNoteNo.toLowerCase().includes(key));
        }
        if (this.searchSecondaryCustomerName) {
            const key = this.searchSecondaryCustomerName.toLowerCase();
            filtered = filtered.filter(n => n.customerName && n.customerName.toLowerCase().includes(key));
        }
        this.debitNotes = filtered.length > 0 ? filtered : null;
        this.showDebitNotes = filtered.length > 0  ? true : false ;
    }

    handleCustomerFocus() {
        this.showCustomerSuggestions = false;
    }

    handleCustomerSearch(event) {
        this.customerSearch = event.target.value;
        const searchVal = this.customerSearch?.trim();

        if (!searchVal || searchVal.length < 2) {
            this.filteredCustomers = [];
            this.showCustomerSuggestions = false;
            this.selectedCustomerId = '';
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

        const debitNoteData = {
            customerId: this.selectedCustomerId,
            noteDate: this.noteDate,
            reason: this.reason,
            amount: this.amount,
            description: this.description || ''
        };

        saveDebitNote({ debitNoteJson: JSON.stringify(debitNoteData) })
            .then(() => {
                this.showToast('Success', 'Debit Note created successfully.', 'success');
                this.isPageLoaded = false;
                this.showNewDebitNoteForm = false;
                this.customerSearch = '';
                this.selectedCustomerId = '';
                this.reason = '';
                this.amount = null;
                this.description = '';
                this.loadDebitNotes();
            })
            .catch(error => {
                console.error('Save error', error);
                const msg = error.body?.message || 'An error occurred while saving.';
                this.showToast('Error', msg, 'error');
                this.isPageLoaded = false;
            });
    }

    handleNewDebitNote() {
        this.showNewDebitNoteForm = true;
    }

    handleShowUpload() {
        this.showUpload = true;
    }

    handleUploadClose() {
        this.showUpload = false;
        this.loadDebitNotes();
    }

    handleUploadComplete() {
        this.loadDebitNotes();
    }

    handleCancel() {
        this.showNewDebitNoteForm = false;
        this.customerSearch = '';
        this.selectedCustomerId = '';
        this.filteredCustomers = [];
        this.showCustomerSuggestions = false;
        this.reason = '';
        this.amount = null;
        this.description = '';
        const today = new Date();
        this.noteDate = today.toLocaleDateString('en-CA');
        this.loadDebitNotes();
    }

    showToast(title, message, variant) {
        const toast = this.template.querySelector('c-custom-toast');
        if (toast) {
            toast.showToast(variant, message);
        }
    }

    downloadDebitNotesAsCSV() {
        if (!this.originalDebitNotes || this.originalDebitNotes.length === 0) {
            this.showToast('No Data Found', 'No debit notes found for the selected filters.', 'error');
            return;
        }

        const header = ['S.No.', 'Debit Note No', 'Customer Name', 'Reason', 'Date', 'Amount', 'Description'];

        const rows = this.originalDebitNotes.map(note => [
            note.rowIndex,
            note.debitNoteNo || '',
            note.customerName || '',
            note.reason || '',
            note.date || '',
            note.amount || 0,
            `"${(note.description || '').replace(/"/g, '""')}"`
        ]);

        let csvContent = 'data:text/csv;charset=utf-8,' + header.join(',') + '\n';
        rows.forEach(row => {
            csvContent += row.join(',') + '\n';
        });

        const encodedUri = encodeURI(csvContent);
        const link = document.createElement('a');
        link.setAttribute('href', encodedUri);
        link.setAttribute('download', 'secondary_debit_notes.csv');
        link.click();
    }
}