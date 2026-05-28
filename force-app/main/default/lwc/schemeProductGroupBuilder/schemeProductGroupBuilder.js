import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getPicklists from '@salesforce/apex/SchemeProductGroupController.getPicklists';
import getSkusForChannel from '@salesforce/apex/SchemeProductGroupController.getSkusForChannel';
import loadGroup from '@salesforce/apex/SchemeProductGroupController.loadGroup';
import getConflictingProductIds from '@salesforce/apex/SchemeProductGroupController.getConflictingProductIds';
import saveGroup from '@salesforce/apex/SchemeProductGroupController.saveGroup';

const normalizePurpose = v => (v || '').toString().toLowerCase().replace(/[\s_-]/g, '');
const isPriceDivisionValue = v => normalizePurpose(v) === 'pricedivision';
const isFocQualifierValue = v => normalizePurpose(v) === 'focqualifier';

export default class SchemeProductGroupBuilder extends NavigationMixin(LightningElement) {
    @api recordId;

    @track header = {
        groupLabel: '',
        salesChannel: '',
        groupPurpose: '',
        description: '',
        isActive: true
    };

    @track filters = {
        category: '',
        productGroup: '',
        productSubGroup: '',
        varient: '',
        grammage: '',
        mrpFilter: '',
        searchTerm: ''
    };

    @track skuRows = [];
    @track selectedSkuIds = new Set();
    @track conflictMap = {};
    @track viewMode = 'all';

    salesChannelOptions = [];
    groupPurposeOptions = [];
    categoryOptions = [];
    productGroupOptions = [];
    productSubGroupOptions = [];
    varientOptions = [];

    isLoading = false;
    isSaving = false;
    isHydrating = false;

    productCacheByChannel = {};
    _searchDebounce;
    _conflictDebounce;

    connectedCallback() {
        this.loadPicklists();
        if (this.recordId) {
            this.hydrateFromExisting();
        }
    }

    async loadPicklists() {
        try {
            const data = await getPicklists();
            this.salesChannelOptions    = data.salesChannels || [];
            this.groupPurposeOptions    = data.groupPurposes || [];
            this.categoryOptions        = this.withAllOption(data.categories);
            this.productGroupOptions    = this.withAllOption(data.productGroups);
            this.productSubGroupOptions = this.withAllOption(data.productSubGroups);
            this.varientOptions         = this.withAllOption(data.varients);
        } catch (error) {
            this.toast('Error', this.reduceError(error), 'error');
        }
    }

    async hydrateFromExisting() {
        this.isHydrating = true;
        try {
            const data = await loadGroup({ groupId: this.recordId });
            if (!data) {
                return;
            }
            this.header = {
                groupLabel:   data.header.groupLabel   || '',
                salesChannel: data.header.salesChannel || '',
                groupPurpose: data.header.groupPurpose || '',
                description:  data.header.description  || '',
                isActive:     data.header.isActive !== false
            };
            this.selectedSkuIds = new Set(data.productIds || []);
            if (this.header.salesChannel) {
                await this.refreshSkus();
            }
            this.refreshConflicts();
        } catch (error) {
            this.toast('Error', this.reduceError(error), 'error');
        } finally {
            this.isHydrating = false;
        }
    }

    withAllOption(options) {
        return [{ label: 'All', value: '' }, ...(options || [])];
    }

    get isEditMode() {
        return !!this.recordId;
    }

    get pageTitle() {
        return this.isEditMode ? 'Edit Scheme Product Group' : 'New Scheme Product Group';
    }

    get isPriceDivision() {
        return isPriceDivisionValue(this.header.groupPurpose);
    }

    get isFocQualifier() {
        return isFocQualifierValue(this.header.groupPurpose);
    }

    get hasChannel() {
        return !!this.header.salesChannel;
    }

    get hasPurpose() {
        return !!this.header.groupPurpose;
    }

    get selectedCount() {
        return this.selectedSkuIds.size;
    }

    get grammageOptions() {
        const seen = new Set();
        const opts = [{ label: 'All', value: '' }];
        this.skuRows.forEach(r => {
            if (r.netWeight != null && !seen.has(String(r.netWeight))) {
                seen.add(String(r.netWeight));
                opts.push({ label: String(r.netWeight), value: String(r.netWeight) });
            }
        });
        return opts;
    }

    get mrpOptions() {
        const seen = new Set();
        const opts = [{ label: 'All', value: '' }];
        this.skuRows.forEach(r => {
            if (r.mrp != null && !seen.has(String(r.mrp))) {
                seen.add(String(r.mrp));
                opts.push({ label: String(r.mrp), value: String(r.mrp) });
            }
        });
        return opts;
    }

    get rowsForDisplay() {
        const f = this.filters;
        const term = (f.searchTerm || '').trim().toLowerCase();
        const selectedOnly = this.viewMode === 'selected';
        const filtered = this.skuRows.filter(r => {
            if (selectedOnly && !this.selectedSkuIds.has(r.id)) return false;
            if (f.category && r.category !== f.category) return false;
            if (f.productGroup && r.productGroup !== f.productGroup) return false;
            if (f.productSubGroup && r.productSubGroup !== f.productSubGroup) return false;
            if (f.varient && r.varient !== f.varient) return false;
            if (f.grammage && String(r.netWeight) !== f.grammage) return false;
            if (f.mrpFilter && String(r.mrp) !== f.mrpFilter) return false;
            if (term) {
                const inName = r.name && r.name.toLowerCase().includes(term);
                const inCode = r.skuCode && r.skuCode.toLowerCase().includes(term);
                if (!inName && !inCode) return false;
            }
            return true;
        });
        return filtered.map((r, i) => {
            const conflict = this.conflictMap[r.id];
            return {
                ...r,
                sNo: i + 1,
                isSelected: this.selectedSkuIds.has(r.id),
                hasConflict: !!conflict,
                conflictGroup: conflict || '',
                rowClass: conflict && this.selectedSkuIds.has(r.id)
                    ? 'table-row row-conflict'
                    : 'table-row'
            };
        });
    }

    get visibleIds() {
        return this.rowsForDisplay.map(r => r.id);
    }

    get isAllVisibleSelected() {
        const visible = this.visibleIds;
        return visible.length > 0 && visible.every(id => this.selectedSkuIds.has(id));
    }

    get isEmpty() {
        return !this.isLoading && this.rowsForDisplay.length === 0;
    }

    get validationState() {
        const selectedRows = this.skuRows.filter(r => this.selectedSkuIds.has(r.id));
        const conflictIds = Object.keys(this.conflictMap);
        const hasConflictInSelection = conflictIds.some(id => this.selectedSkuIds.has(id));

        if (!this.hasPurpose) {
            return { color: 'info', message: 'Pick a Group Purpose to begin.' };
        }
        if (selectedRows.length === 0) {
            return { color: 'info', message: 'Select one or more SKUs.' };
        }
        if (hasConflictInSelection) {
            return {
                color: 'red',
                message: 'One or more selected SKUs already belong to another active group for this channel.'
            };
        }
        if (this.isPriceDivision) {
            const mrps = new Set(selectedRows.map(r => r.mrp));
            const weights = new Set(selectedRows.map(r => r.netWeight));
            if (mrps.size > 1) {
                return { color: 'red', message: 'Mixed MRP — group not allowed.' };
            }
            if (weights.size > 1) {
                return { color: 'red', message: 'Mixed Net Weight — group not allowed.' };
            }
            const mrp = [...mrps][0];
            const wt  = [...weights][0];
            return {
                color: 'green',
                message: `All members aligned — MRP ${mrp}, Net Weight ${wt}.`
            };
        }
        return { color: 'info', message: 'Mixed MRP / Weight allowed for FOC.' };
    }

    get chipClass() {
        return `chip chip--${this.validationState.color}`;
    }

    get chipMessage() {
        return this.validationState.message;
    }

    get isSubmitDisabled() {
        if (this.isSaving) return true;
        if (!this.header.groupLabel) return true;
        if (!this.header.salesChannel) return true;
        if (!this.header.groupPurpose) return true;
        if (this.selectedSkuIds.size === 0) return true;
        return this.validationState.color === 'red';
    }

    handleHeaderChange(event) {
        const field = event.target.dataset.field;
        const value = event.detail.value;
        this.header = { ...this.header, [field]: value };

        if (field === 'salesChannel') {
            this.selectedSkuIds = new Set();
            this.conflictMap = {};
            this.skuRows = [];
            if (value) {
                this.refreshSkus();
            }
        }
    }

    handleActiveToggle(event) {
        this.header = { ...this.header, isActive: event.target.checked };
    }

    handleFilterChange(event) {
        const field = event.target.dataset.field;
        this.filters = { ...this.filters, [field]: event.detail.value };
    }

    handleSearchChange(event) {
        const value = event.target.value;
        window.clearTimeout(this._searchDebounce);
        this._searchDebounce = window.setTimeout(() => {
            this.filters = { ...this.filters, searchTerm: value };
        }, 250);
    }

    get allViewClass() {
        return this.viewMode === 'all' ? 'view-btn view-btn--active' : 'view-btn';
    }

    get selectedViewClass() {
        return this.viewMode === 'selected' ? 'view-btn view-btn--active' : 'view-btn';
    }

    handleViewToggle(event) {
        const next = event.target.dataset.view;
        if (next && next !== this.viewMode) {
            this.viewMode = next;
        }
    }

    handleClearFilters() {
        this.filters = {
            category: '', productGroup: '', productSubGroup: '',
            varient: '', grammage: '', mrpFilter: '', searchTerm: ''
        };
    }

    async refreshSkus() {
        const channel = this.header.salesChannel;
        if (!channel) {
            this.skuRows = [];
            return;
        }
        if (this.productCacheByChannel[channel]) {
            this.skuRows = this.productCacheByChannel[channel];
            return;
        }
        this.isLoading = true;
        try {
            const rows = await getSkusForChannel({ salesChannel: channel });
            this.skuRows = rows || [];
            this.productCacheByChannel[channel] = this.skuRows;
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
        this.scheduleConflictRefresh();
    }

    handleSelectAll(event) {
        const next = new Set(this.selectedSkuIds);
        const visible = this.visibleIds;
        if (event.target.checked) {
            visible.forEach(id => next.add(id));
        } else {
            visible.forEach(id => next.delete(id));
        }
        this.selectedSkuIds = next;
        this.scheduleConflictRefresh();
    }

    handleSelectAllVisible() {
        const next = new Set(this.selectedSkuIds);
        this.visibleIds.forEach(id => next.add(id));
        this.selectedSkuIds = next;
        this.scheduleConflictRefresh();
    }

    handleClearSelection() {
        this.selectedSkuIds = new Set();
        this.conflictMap = {};
    }

    scheduleConflictRefresh() {
        window.clearTimeout(this._conflictDebounce);
        this._conflictDebounce = window.setTimeout(() => this.refreshConflicts(), 250);
    }

    async refreshConflicts() {
        const channel = this.header.salesChannel;
        const ids = Array.from(this.selectedSkuIds);
        if (!channel || ids.length === 0) {
            this.conflictMap = {};
            return;
        }
        try {
            const conflicts = await getConflictingProductIds({
                salesChannel: channel,
                productIds: ids,
                excludeGroupId: this.recordId || null
            });
            const map = {};
            (conflicts || []).forEach(c => { map[c.productId] = c.groupName; });
            this.conflictMap = map;
        } catch (error) {
            this.toast('Error', this.reduceError(error), 'error');
        }
    }

    async handleSubmit() {
        if (this.isSubmitDisabled) return;
        this.isSaving = true;
        try {
            const recordId = await saveGroup({
                header: {
                    groupLabel:   this.header.groupLabel,
                    salesChannel: this.header.salesChannel,
                    groupPurpose: this.header.groupPurpose,
                    description:  this.header.description,
                    isActive:     this.header.isActive
                },
                productIds: Array.from(this.selectedSkuIds),
                existingId: this.recordId || null
            });
            this.toast(
                'Success',
                this.isEditMode ? 'Scheme Product Group updated.' : 'Scheme Product Group created.',
                'success'
            );
            this.dispatchEvent(new CustomEvent('saved', { detail: { recordId } }));
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId,
                    objectApiName: 'Scheme_Product_Group__c',
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
                objectApiName: 'Scheme_Product_Group__c',
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