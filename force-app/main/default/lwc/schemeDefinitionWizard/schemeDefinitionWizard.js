import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPicklists from '@salesforce/apex/SchemeDefinitionController.getPicklists';
import loadScheme from '@salesforce/apex/SchemeDefinitionController.loadScheme';
import searchProductGroups from '@salesforce/apex/SchemeDefinitionController.searchProductGroups';
import saveSchemeWithSlabs from '@salesforce/apex/SchemeDefinitionController.saveSchemeWithSlabs';
import getSkusForChannel from '@salesforce/apex/SchemeProductGroupController.getSkusForChannel';

const TYPE_FREE_QTY     = 'Free Quantity';
const TYPE_QPS          = 'QPS';
const TYPE_FOC_GIVEAWAY = 'FOC Giveaway';
const TYPE_ORDER_VALUE  = 'Order Value';
const TYPE_CATEGORY     = 'Category Value';

const GROUP_TYPES    = new Set([TYPE_FREE_QTY, TYPE_QPS, TYPE_FOC_GIVEAWAY]);
const CATEGORY_TYPES = new Set([TYPE_CATEGORY]);

const PLUM_TOKEN = 'plum';

let _uidSeq = 0;
const nextUid = () => `slab-${++_uidSeq}`;
const normalize = v => (v == null ? '' : String(v).toLowerCase().replace(/[\s_-]/g, ''));

const FALLBACK_SCHEME_TYPES = [
    { label: 'Free Quantity', value: TYPE_FREE_QTY },
    { label: 'QPS', value: TYPE_QPS },
    { label: 'FOC Giveaway', value: TYPE_FOC_GIVEAWAY },
    { label: 'Order Value', value: TYPE_ORDER_VALUE },
    { label: 'Category Value', value: TYPE_CATEGORY }
];

export default class SchemeDefinitionWizard extends LightningElement {
    @api recordId;

    @track master = {
        name: '',
        schemeType: '',
        salesChannel: '',
        startDate: '',
        endDate: '',
        description: ''
    };
    @track linkage = {
        productGroupId: '',
        productGroupName: '',
        productCategory: ''
    };
    @track slabs = [];
    @track productGroupResults = [];
    @track focUi = { activeUid: '', term: '', results: [] };

    @track isLoadingPicklists = false;
    @track isHydrating = false;
    @track isSaving = false;
    @track isSearchingGroups = false;
    @track isLoadingFocSkus = false;

    salesChannelOptions = [];
    schemeTypeOptionsRaw = [];
    productCategoryOptions = [];

    _searchDebounce;
    _searchTerm = '';
    _focCacheByChannel = {};

    connectedCallback() {
        this.loadPicklists();
        if (this.recordId) {
            this.hydrate();
        }
    }

    async loadPicklists() {
        this.isLoadingPicklists = true;
        try {
            const data = await getPicklists();
            this.salesChannelOptions    = data.salesChannels || [];
            this.schemeTypeOptionsRaw   = data.schemeTypes || [];
            this.productCategoryOptions = data.productCategories || [];
        } catch (error) {
            this.toast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoadingPicklists = false;
        }
    }

    async hydrate() {
        this.isHydrating = true;
        try {
            const data = await loadScheme({ schemeId: this.recordId });
            if (!data) return;
            const m = data.master || {};
            this.master = {
                name: m.name || '',
                schemeType: m.schemeType || '',
                salesChannel: m.salesChannel || '',
                startDate: m.startDate || '',
                endDate: m.endDate || '',
                description: m.description || ''
            };
            this.linkage = {
                productGroupId: m.productGroupId || '',
                productGroupName: data.productGroupName || '',
                productCategory: m.productCategory || ''
            };
            const incoming = data.slabs || [];
            this.slabs = incoming.map(s => ({
                _uid: nextUid(),
                qtyMin: s.qtyMin,
                qtyMax: s.qtyMax,
                valueMin: s.valueMin,
                valueMax: s.valueMax,
                freeQty: s.freeQty,
                benefitPerEa: s.benefitPerEa,
                benefitPercent: s.benefitPercent,
                focProductId: s.focProductId,
                focProductName: s.focProductName || ''
            }));
            if (this.master.salesChannel && this.master.schemeType === TYPE_FOC_GIVEAWAY) {
                this.loadFocProducts(this.master.salesChannel);
            }
        } catch (error) {
            this.toast('Error', this.reduceError(error), 'error');
        } finally {
            this.isHydrating = false;
        }
    }

    get isEditMode() { return !!this.recordId; }
    get pageTitle()  { return this.isEditMode ? 'Edit Scheme' : 'New Scheme'; }

    get schemeTypeOptions() {
        const list = this.schemeTypeOptionsRaw && this.schemeTypeOptionsRaw.length
            ? this.schemeTypeOptionsRaw
            : FALLBACK_SCHEME_TYPES;
        return list;
    }

    get hasMasterMinimums() {
        return !!(this.master.schemeType && this.master.salesChannel);
    }

    get step2Mode() {
        const t = this.master.schemeType;
        if (GROUP_TYPES.has(t))    return 'group';
        if (CATEGORY_TYPES.has(t)) return 'category';
        return 'none';
    }

    get showGroupPicker()    { return this.hasMasterMinimums && this.step2Mode === 'group'; }
    get showCategoryPicker() { return this.hasMasterMinimums && this.step2Mode === 'category'; }
    get showNoLinkageHint()  { return this.hasMasterMinimums && this.step2Mode === 'none'; }
    get showLinkagePlaceholder() { return !this.hasMasterMinimums; }
    get showSlabsPlaceholder()   { return !this.hasMasterMinimums; }
    get showSlabsTable()         { return this.hasMasterMinimums; }

    get expectedGroupPurpose() {
        return this.master.schemeType === TYPE_FOC_GIVEAWAY ? 'FOC Qualifier' : 'Price Division';
    }

    get isFreeQty()       { return this.master.schemeType === TYPE_FREE_QTY; }
    get isQps()           { return this.master.schemeType === TYPE_QPS; }
    get isFoc()           { return this.master.schemeType === TYPE_FOC_GIVEAWAY; }
    get isOrderValue()    { return this.master.schemeType === TYPE_ORDER_VALUE; }
    get isCategoryValue() { return this.master.schemeType === TYPE_CATEGORY; }

    get displaySlabs() {
        const activeUid = this.focUi.activeUid;
        const focResults = this.focUi.results || [];
        return this.slabs.map((s, i) => ({
            ...s,
            sNo: i + 1,
            showRemove: this.slabs.length > 1,
            hasFocPick: !!s.focProductId,
            showFocSearch: !s.focProductId,
            isFocActive: activeUid === s._uid,
            focResults: activeUid === s._uid ? focResults : [],
            showFocResults: activeUid === s._uid && focResults.length > 0
        }));
    }

    get isMasterValid() {
        const m = this.master;
        if (!m.name || !m.schemeType || !m.salesChannel || !m.startDate || !m.endDate) return false;
        return m.endDate >= m.startDate;
    }

    get isLinkageValid() {
        if (this.step2Mode === 'group')    return !!this.linkage.productGroupId;
        if (this.step2Mode === 'category') return !!this.linkage.productCategory;
        return true;
    }

    get areSlabsValid() {
        if (!this.slabs.length) return false;
        for (const s of this.slabs) {
            if (this.isFreeQty) {
                if (s.qtyMin == null || s.qtyMin === '' || s.freeQty == null || s.freeQty === '') return false;
            } else if (this.isQps) {
                if (s.qtyMin == null || s.qtyMin === '' || s.benefitPerEa == null || s.benefitPerEa === '') return false;
            } else if (this.isFoc) {
                if (s.qtyMin == null || s.qtyMin === '' || s.freeQty == null || s.freeQty === '') return false;
                if (!s.focProductId) return false;
            } else if (this.isOrderValue || this.isCategoryValue) {
                if (s.valueMin == null || s.valueMin === '' || s.benefitPercent == null || s.benefitPercent === '') return false;
            }
        }
        return true;
    }

    get isSaveDisabled() {
        return this.isSaving || !this.hasMasterMinimums || !this.isMasterValid || !this.isLinkageValid || !this.areSlabsValid;
    }

    get inlineMessage() {
        if (!this.isMasterValid) {
            if (this.master.endDate && this.master.startDate && this.master.endDate < this.master.startDate) {
                return { cls: 'chip chip--red',  text: 'End Date must be on/after Start Date.' };
            }
            return { cls: 'chip chip--info', text: 'Fill all required master fields.' };
        }
        if (!this.isLinkageValid) {
            return { cls: 'chip chip--info', text: this.step2Mode === 'group'
                ? 'Select a Scheme Product Group to continue.'
                : 'Select a Product Category to continue.' };
        }
        if (!this.areSlabsValid) {
            return { cls: 'chip chip--info', text: 'Fill every slab row to enable Save.' };
        }
        return { cls: 'chip chip--green', text: 'Ready to save.' };
    }

    handleMasterChange(event) {
        const field = event.target.dataset.field;
        const value = event.detail ? event.detail.value : event.target.value;
        const prevType = this.master.schemeType;
        const prevChannel = this.master.salesChannel;
        this.master = { ...this.master, [field]: value };

        if (field === 'schemeType') {
            const newLinkage = {
                productGroupId: '',
                productGroupName: '',
                productCategory: this.defaultCategoryFor(value)
            };
            this.linkage = newLinkage;
            this.productGroupResults = [];
            this.slabs = this.seedSlabsForType(value);
            this.focUi = { activeUid: '', term: '', results: [] };
            if (value === TYPE_FOC_GIVEAWAY && this.master.salesChannel) {
                this.loadFocProducts(this.master.salesChannel);
            }
        } else if (field === 'salesChannel') {
            this.linkage = { ...this.linkage, productGroupId: '', productGroupName: '' };
            this.productGroupResults = [];
            this.clearFocFromSlabs();
            this.focUi = { activeUid: '', term: '', results: [] };
            if (value && this.master.schemeType === TYPE_FOC_GIVEAWAY) {
                this.loadFocProducts(value);
            }
        }
    }

    defaultCategoryFor(schemeType) {
        if (schemeType !== TYPE_CATEGORY) return '';
        const match = (this.productCategoryOptions || []).find(o => normalize(o.value) === PLUM_TOKEN);
        return match ? match.value : '';
    }

    clearFocFromSlabs() {
        if (!this.slabs.length) return;
        this.slabs = this.slabs.map(s => ({ ...s, focProductId: '', focProductName: '' }));
    }

    async loadFocProducts(channel) {
        if (!channel || this._focCacheByChannel[channel]) {
            return;
        }
        this.isLoadingFocSkus = true;
        try {
            const rows = await getSkusForChannel({ salesChannel: channel });
            this._focCacheByChannel[channel] = (rows || []).map(r => ({
                id: r.id,
                name: r.name,
                skuCode: r.skuCode || '',
                displayLabel: r.skuCode ? `${r.name} (${r.skuCode})` : r.name
            }));
        } catch (error) {
            this.toast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoadingFocSkus = false;
        }
    }

    filterFocProducts(term) {
        const channel = this.master.salesChannel;
        if (!channel || !this._focCacheByChannel[channel]) return [];
        const t = (term || '').trim().toLowerCase();
        const pool = this._focCacheByChannel[channel];
        const filtered = !t
            ? pool
            : pool.filter(p =>
                (p.name && p.name.toLowerCase().includes(t)) ||
                (p.skuCode && p.skuCode.toLowerCase().includes(t))
            );
        return filtered.slice(0, 50);
    }

    seedSlabsForType(type) {
        if (!type) return [];
        if (type === TYPE_FREE_QTY) {
            return [this.makeSlab({ qtyMin: null, qtyMax: null, freeQty: null })];
        }
        if (type === TYPE_QPS) {
            return [this.makeSlab({ qtyMin: null, qtyMax: null, benefitPerEa: null })];
        }
        if (type === TYPE_FOC_GIVEAWAY) {
            return [this.makeSlab({ qtyMin: null, qtyMax: null, freeQty: null, focProductId: '' })];
        }
        if (type === TYPE_ORDER_VALUE || type === TYPE_CATEGORY) {
            return [this.makeSlab({ valueMin: null, valueMax: null, benefitPercent: null })];
        }
        return [];
    }

    makeSlab(extra) {
        return {
            _uid: nextUid(),
            qtyMin: null, qtyMax: null,
            valueMin: null, valueMax: null,
            freeQty: null, benefitPerEa: null, benefitPercent: null,
            focProductId: '',
            ...extra
        };
    }

    handleAddSlab() {
        this.slabs = [...this.slabs, this.makeSlab({})];
        if (this.isFoc && this.master.salesChannel) {
            this.loadFocProducts(this.master.salesChannel);
        }
    }

    handleRemoveSlab(event) {
        const uid = event.target.dataset.uid;
        if (this.slabs.length <= 1) return;
        this.slabs = this.slabs.filter(s => s._uid !== uid);
    }

    handleSlabFieldChange(event) {
        const uid = event.target.dataset.uid;
        const field = event.target.dataset.field;
        const raw = event.detail ? event.detail.value : event.target.value;
        const numeric = ['qtyMin','qtyMax','valueMin','valueMax','freeQty','benefitPerEa','benefitPercent'];
        const value = numeric.includes(field)
            ? (raw === '' || raw == null ? null : Number(raw))
            : raw;
        this.slabs = this.slabs.map(s => s._uid === uid ? { ...s, [field]: value } : s);
    }

    handleFocSearchFocus(event) {
        const uid = event.target.dataset.uid;
        this.focUi = {
            activeUid: uid,
            term: '',
            results: this.filterFocProducts('')
        };
    }

    handleFocSearchInput(event) {
        const uid = event.target.dataset.uid;
        const term = event.target.value || '';
        this.focUi = {
            activeUid: uid,
            term,
            results: this.filterFocProducts(term)
        };
    }

    handleFocProductPick(event) {
        const uid = event.currentTarget.dataset.uid;
        const id = event.currentTarget.dataset.id;
        const channel = this.master.salesChannel;
        const pool = (channel && this._focCacheByChannel[channel]) || [];
        const pick = pool.find(p => p.id === id);
        if (!pick) return;
        this.slabs = this.slabs.map(s => s._uid === uid
            ? { ...s, focProductId: pick.id, focProductName: pick.displayLabel }
            : s);
        this.focUi = { activeUid: '', term: '', results: [] };
    }

    handleClearFocProduct(event) {
        const uid = event.target.dataset.uid;
        this.slabs = this.slabs.map(s => s._uid === uid
            ? { ...s, focProductId: '', focProductName: '' }
            : s);
        this.focUi = { activeUid: '', term: '', results: [] };
    }

    handleProductGroupSearchInput(event) {
        const value = event.target.value || '';
        this._searchTerm = value;
        window.clearTimeout(this._searchDebounce);
        this._searchDebounce = window.setTimeout(() => this.runProductGroupSearch(), 250);
    }

    async runProductGroupSearch() {
        if (!this.master.salesChannel || !this.master.schemeType) {
            this.productGroupResults = [];
            return;
        }
        this.isSearchingGroups = true;
        try {
            const rows = await searchProductGroups({
                salesChannel: this.master.salesChannel,
                groupPurpose: this.expectedGroupPurpose,
                searchTerm: this._searchTerm,
                excludeId: null
            });
            this.productGroupResults = rows || [];
        } catch (error) {
            this.toast('Error', this.reduceError(error), 'error');
        } finally {
            this.isSearchingGroups = false;
        }
    }

    handleProductGroupPick(event) {
        const id = event.currentTarget.dataset.id;
        const row = (this.productGroupResults || []).find(r => r.id === id);
        if (!row) return;
        this.linkage = {
            ...this.linkage,
            productGroupId: row.id,
            productGroupName: row.name
        };
        this.productGroupResults = [];
        this._searchTerm = '';
    }

    handleClearGroup() {
        this.linkage = { ...this.linkage, productGroupId: '', productGroupName: '' };
    }

    handleCategoryChange(event) {
        this.linkage = { ...this.linkage, productCategory: event.detail.value };
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    async handleSave() {
        if (this.isSaveDisabled) return;
        this.isSaving = true;
        try {
            const payloadMaster = {
                name:            this.master.name,
                schemeType:      this.master.schemeType,
                salesChannel:    this.master.salesChannel,
                startDate:       this.master.startDate,
                endDate:         this.master.endDate,
                description:     this.master.description,
                productGroupId:  this.linkage.productGroupId || null,
                productCategory: this.linkage.productCategory || null
            };
            const payloadSlabs = this.slabs.map((s, i) => ({
                sequence: i + 1,
                slabType: this.master.schemeType,
                qtyMin:         s.qtyMin         === '' ? null : s.qtyMin,
                qtyMax:         s.qtyMax         === '' ? null : s.qtyMax,
                valueMin:       s.valueMin       === '' ? null : s.valueMin,
                valueMax:       s.valueMax       === '' ? null : s.valueMax,
                freeQty:        s.freeQty        === '' ? null : s.freeQty,
                benefitPerEa:   s.benefitPerEa   === '' ? null : s.benefitPerEa,
                benefitPercent: s.benefitPercent === '' ? null : s.benefitPercent,
                focProductId:   s.focProductId   || null
            }));
            const savedId = await saveSchemeWithSlabs({
                master: payloadMaster,
                slabs: payloadSlabs,
                existingId: this.recordId || null
            });
            this.toast('Success', this.isEditMode ? 'Scheme updated.' : 'Scheme created.', 'success');
            this.dispatchEvent(new CustomEvent('complete', { detail: { recordId: savedId } }));
        } catch (error) {
            this.toast('Error', this.reduceError(error), 'error');
        } finally {
            this.isSaving = false;
        }
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
