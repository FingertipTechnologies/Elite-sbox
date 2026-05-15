import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getPicklists from '@salesforce/apex/FocusedPackController.getPicklists';
import getSkusForChannel from '@salesforce/apex/FocusedPackController.getSkusForChannel';
import isNameAvailable from '@salesforce/apex/FocusedPackController.isNameAvailable';
import saveFocusedPack from '@salesforce/apex/FocusedPackController.saveFocusedPack';

const SKU_COLUMNS = [
    { label: 'SKU Code',          fieldName: 'skuCode',         type: 'text', initialWidth: 140 },
    { label: 'Product Name',      fieldName: 'name',            type: 'text' },
    { label: 'SKU Name',          fieldName: 'skuName',         type: 'text' },
    { label: 'Category',          fieldName: 'category',        type: 'text', initialWidth: 140 },
    { label: 'Group',             fieldName: 'productGroup',    type: 'text', initialWidth: 140 },
    { label: 'Sub Group',         fieldName: 'productSubGroup', type: 'text', initialWidth: 140 }
];

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

    columns = SKU_COLUMNS;

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
            this.categoryOptions        = data.categories;
            this.productGroupOptions    = data.productGroups;
            this.productSubGroupOptions = data.productSubGroups;
        } catch (error) {
            this.toast('Error', this.reduceError(error), 'error');
        }
    }

    get hasChannel() {
        return !!this.header.salesChannel;
    }

    get selectedCount() {
        return this.selectedSkuIds.size;
    }

    get selectedRowIds() {
        return Array.from(this.selectedSkuIds);
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
    }

    handleSearchChange(event) {
        this.filters = { ...this.filters, searchTerm: event.target.value };
    }

    handleApplyFilters() {
        this.refreshSkus();
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
            const presentIds = new Set(this.skuRows.map(r => r.id));
            const trimmed = new Set();
            this.selectedSkuIds.forEach(id => {
                if (presentIds.has(id)) {
                    trimmed.add(id);
                }
            });
            this.selectedSkuIds = trimmed;
        } catch (error) {
            this.toast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRowSelection(event) {
        const visibleIds = new Set(this.skuRows.map(r => r.id));
        const selectedNow = new Set(event.detail.selectedRows.map(r => r.id));
        const next = new Set();
        this.selectedSkuIds.forEach(id => {
            if (!visibleIds.has(id)) {
                next.add(id);
            }
        });
        selectedNow.forEach(id => next.add(id));
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