import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getPicklists from '@salesforce/apex/FocusedPackController.getPicklists';
import getSkusForChannel from '@salesforce/apex/FocusedPackController.getSkusForChannel';
import isNameAvailable from '@salesforce/apex/FocusedPackController.isNameAvailable';
import saveFocusedPack from '@salesforce/apex/FocusedPackController.saveFocusedPack';

export default class FocusedPackForm extends NavigationMixin(LightningElement) {
    @track header = {
        name: '',
        salesChannel: '',
        minimumQuantity: null
    };

    @track filters = {
        category: '',
        productGroup: '',
        productSubGroup: '',
        searchTerm: ''
    };

    @track skuRows = [];
    @track selectedSkuIds = new Set();

    salesChannelOptions = [];
    categoryOptions = [];
    productGroupOptions = [];
    productSubGroupOptions = [];

    isLoading = false;
    isSaving = false;
    nameError = '';

    connectedCallback() {
        this.loadPicklists();
    }

    async loadPicklists() {
        try {
            const data = await getPicklists();
            this.salesChannelOptions    = data.salesChannels;
            this.categoryOptions        = this.withAllOption(data.categories);
            this.productGroupOptions    = this.withAllOption(data.productGroups);
            this.productSubGroupOptions = this.withAllOption(data.productSubGroups);
        } catch (error) {
            this.toast('Error', this.reduceError(error), 'error');
        }
    }

    withAllOption(options) {
        return [{ label: 'All', value: '' }, ...(options || [])];
    }

    get hasChannel() {
        return !!this.header.salesChannel;
    }

    get selectedCount() {
        return this.selectedSkuIds.size;
    }

    get rowsForDisplay() {
        return this.skuRows.map((r, i) => ({
            ...r,
            sNo: i + 1,
            isSelected: this.selectedSkuIds.has(r.id)
        }));
    }

    get isAllSelected() {
        return this.skuRows.length > 0
            && this.skuRows.every(r => this.selectedSkuIds.has(r.id));
    }

    get isEmpty() {
        return !this.isLoading && this.skuRows.length === 0;
    }

    get isSubmitDisabled() {
        return this.isSaving
            || !this.header.name
            || !this.header.salesChannel
            || this.selectedSkuIds.size === 0
            || !!this.nameError;
    }

    handleHeaderChange(event) {
        const field = event.target.dataset.field;
        let value = event.detail.value;
        if (field === 'minimumQuantity' && value !== '' && value != null) {
            value = Number(value);
        }
        this.header = { ...this.header, [field]: value };

        if (field === 'salesChannel') {
            this.skuRows = [];
            this.selectedSkuIds = new Set();
            if (value) {
                this.refreshSkus();
            }
        }
    }

    async handleNameBlur() {
        this.nameError = '';
        const name = this.header.name && this.header.name.trim();
        if (!name) {
            return;
        }
        try {
            const available = await isNameAvailable({ name });
            if (!available) {
                this.nameError = 'A Focused Pack with this name already exists.';
            }
        } catch (error) {
            this.nameError = this.reduceError(error);
        }
    }

    handleFilterChange(event) {
        const field = event.target.dataset.field;
        this.filters = { ...this.filters, [field]: event.detail.value };
        this.refreshSkus();
    }

    handleSearchChange(event) {
        const value = event.target.value;
        this.filters = { ...this.filters, searchTerm: value };
        window.clearTimeout(this._searchDebounce);
        this._searchDebounce = window.setTimeout(() => this.refreshSkus(), 300);
    }

    handleClearFilters() {
        this.filters = { category: '', productGroup: '', productSubGroup: '', searchTerm: '' };
        this.refreshSkus();
    }

    async refreshSkus() {
        if (!this.header.salesChannel) {
            this.skuRows = [];
            return;
        }
        this.isLoading = true;
        try {
            const rows = await getSkusForChannel({
                salesChannel: this.header.salesChannel,
                category: this.filters.category,
                productGroup: this.filters.productGroup,
                productSubGroup: this.filters.productSubGroup,
                searchTerm: this.filters.searchTerm
            });
            this.skuRows = rows || [];
        } catch (error) {
            this.toast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRowCheckbox(event) {
        const id = event.target.dataset.id;
        const next = new Set(this.selectedSkuIds);
        if (event.target.checked) {
            next.add(id);
        } else {
            next.delete(id);
        }
        this.selectedSkuIds = next;
    }

    handleSelectAll(event) {
        const next = new Set(this.selectedSkuIds);
        if (event.target.checked) {
            this.skuRows.forEach(r => next.add(r.id));
        } else {
            this.skuRows.forEach(r => next.delete(r.id));
        }
        this.selectedSkuIds = next;
    }

    handleSelectAllVisible() {
        const next = new Set(this.selectedSkuIds);
        this.skuRows.forEach(r => next.add(r.id));
        this.selectedSkuIds = next;
    }

    handleClearSelection() {
        this.selectedSkuIds = new Set();
    }

    async handleSubmit() {
        if (this.isSubmitDisabled) {
            return;
        }
        this.isSaving = true;
        try {
            const recordId = await saveFocusedPack({
                name: this.header.name,
                salesChannel: this.header.salesChannel,
                minimumQuantity: this.header.minimumQuantity,
                skuIds: Array.from(this.selectedSkuIds)
            });
            this.toast('Success', 'Focused Pack created.', 'success');
            this.dispatchEvent(new CustomEvent('saved', { detail: { recordId } }));
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId,
                    objectApiName: 'Focused_Pack__c',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.toast('Error', this.reduceError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Focused_Pack__c',
                actionName: 'list'
            },
            state: { filterName: 'Recent' }
        });
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (!error) return 'Unknown error';
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        if (error.body && Array.isArray(error.body.pageErrors)) {
            return error.body.pageErrors.map(e => e.message).join(', ');
        }
        return error.message || JSON.stringify(error);
    }
}