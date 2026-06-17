import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPicklists from '@salesforce/apex/SchemeDefinitionController.getPicklists';
import loadScheme from '@salesforce/apex/SchemeDefinitionController.loadScheme';
import searchProductGroups from '@salesforce/apex/SchemeDefinitionController.searchProductGroups';
import saveSchemeWithApplicability from '@salesforce/apex/SchemeDefinitionController.saveSchemeWithApplicability';
import getApplicabilityOptions from '@salesforce/apex/SchemeDefinitionController.getApplicabilityOptions';
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
        description: '',
        isActive: true
    };
    @track savedStartDate = '';
    @track linkage = {
        productGroupId: '',
        productGroupName: '',
        productCategory: ''
    };
    @track slabs = [];
    @track productGroupResults = [];
    @track focUi = { activeUid: '', term: '', results: [] };

    @track currentStep = 1;
    @track applicability = {
        regions:          { applyToAll: false, values: [] },
        areas:            { applyToAll: false, values: [] },
        territories:      { applyToAll: false, values: [] },
        outletCategories: { applyToAll: false, values: [] }
    };
    @track applicabilityOptions = {
        regions: [], areas: [], territories: [], outletCategories: []
    };
    @track savedTerritoryDisplay = {};
    @track isLoadingApplicability = false;

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
                description: m.description || '',
                isActive: m.isActive !== false
            };
            this.savedStartDate = m.startDate || '';
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

            const a = data.applicability;
            if (a) {
                this.applicability = {
                    regions:          this.cloneLevel(a.regions),
                    areas:            this.cloneLevel(a.areas),
                    territories:      this.cloneLevel(a.territories),
                    outletCategories: this.cloneLevel(a.outletCategories)
                };
            }
            this.savedTerritoryDisplay = {};
            for (const t of (data.savedTerritoryOptions || [])) {
                this.savedTerritoryDisplay[t.id] = t.name;
            }
        } catch (error) {
            this.toast('Error', this.reduceError(error), 'error');
        } finally {
            this.isHydrating = false;
        }
    }

    cloneLevel(src) {
        return {
            applyToAll: !!(src && src.applyToAll),
            values: (src && Array.isArray(src.values)) ? [...src.values] : []
        };
    }

    get isEditMode() { return !!this.recordId; }
    get pageTitle()  { return this.isEditMode ? 'Edit Scheme' : 'New Scheme'; }

    get todayIso() {
        const d = new Date();
        const tzOffset = d.getTimezoneOffset() * 60000;
        return new Date(d.getTime() - tzOffset).toISOString().slice(0, 10);
    }

    get isStartDateReadOnly() {
        return this.isEditMode && !!this.savedStartDate && this.savedStartDate < this.todayIso;
    }

    get startDateMin() {
        return this.isStartDateReadOnly ? null : this.todayIso;
    }

    get endDateMin() {
        return this.master.startDate && this.master.startDate > this.todayIso
            ? this.master.startDate
            : this.todayIso;
    }

    get schemeTypeOptions() {
        const list = this.schemeTypeOptionsRaw && this.schemeTypeOptionsRaw.length
            ? this.schemeTypeOptionsRaw
            : FALLBACK_SCHEME_TYPES;
        // 'Outlet Category Scheme' is a system marker recorded on OSA/ISA by the pricing engine,
        // not a scheme users define — never offer it as a selectable scheme type here.
        return list.filter(o => o.value !== 'Outlet Category Scheme');
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
        if (m.endDate < m.startDate) return false;
        const today = this.todayIso;
        const startChanged = !this.savedStartDate || m.startDate !== this.savedStartDate;
        if (startChanged && m.startDate < today) return false;
        if (m.endDate < today) return false;
        return true;
    }

    get isLinkageValid() {
        if (this.step2Mode === 'group')    return !!this.linkage.productGroupId;
        if (this.step2Mode === 'category') return !!this.linkage.productCategory;
        return true;
    }

    get slabsError() {
        if (!this.slabs.length) return 'Add at least one slab row.';

        const isQtyType   = this.isFreeQty || this.isQps || this.isFoc;
        const isValueType = this.isOrderValue || this.isCategoryValue;
        if (!(isQtyType || isValueType)) return null;

        const minField    = isQtyType ? 'qtyMin' : 'valueMin';
        const maxField    = isQtyType ? 'qtyMax' : 'valueMax';
        const minLabel    = isQtyType ? 'Min Qty' : 'Min Value';
        const maxLabel    = isQtyType ? 'Max Qty' : 'Max Value';
        const benefitField = (this.isFreeQty || this.isFoc) ? 'freeQty'
                           : this.isQps ? 'benefitPerEa' : 'benefitPercent';
        const benefitLabel = (this.isFreeQty || this.isFoc) ? 'Free Qty'
                           : this.isQps ? 'Benefit / EA' : 'Discount %';
        const filled = v => v != null && v !== '';
        const num    = v => Number(v);

        for (let i = 0; i < this.slabs.length; i++) {
            const s = this.slabs[i];
            const n = i + 1;

            if (this.isFoc && !s.focProductId) return `Slab ${n}: pick the FOC product.`;
            if (!filled(s[minField])) return `Slab ${n}: fill ${minLabel}.`;
            if (!filled(s[benefitField])) return `Slab ${n}: fill ${benefitLabel}.`;

            if (num(s[minField]) <= 0)     return `Slab ${n}: ${minLabel} must be greater than 0.`;
            if (num(s[benefitField]) <= 0) return `Slab ${n}: ${benefitLabel} must be greater than 0.`;
            if ((this.isOrderValue || this.isCategoryValue) && num(s[benefitField]) > 100) {
                return `Slab ${n}: Discount % cannot exceed 100.`;
            }
            if (filled(s[maxField])) {
                if (num(s[maxField]) <= 0) return `Slab ${n}: ${maxLabel} must be greater than 0.`;
                if (num(s[maxField]) < num(s[minField])) {
                    return `Slab ${n}: ${maxLabel} (${s[maxField]}) must be greater than or equal to ${minLabel} (${s[minField]}).`;
                }
            }
        }

        let openTopRow = -1;
        for (let i = 0; i < this.slabs.length; i++) {
            if (!filled(this.slabs[i][maxField])) {
                if (openTopRow !== -1) {
                    return `Slab ${openTopRow + 1} and Slab ${i + 1} both leave ${maxLabel} blank — only one open-top slab is allowed.`;
                }
                openTopRow = i;
            }
        }

        for (let i = 1; i < this.slabs.length; i++) {
            const prev = num(this.slabs[i - 1][minField]);
            const cur  = num(this.slabs[i][minField]);
            if (cur <= prev) {
                return `Slab ${i + 1}'s ${minLabel} (${cur}) must be greater than Slab ${i}'s ${minLabel} (${prev}). Enter slabs in ascending order.`;
            }
        }

        for (let i = 0; i < this.slabs.length - 1; i++) {
            const curMax = this.slabs[i][maxField];
            const nxtMin = this.slabs[i + 1][minField];
            if (!filled(curMax)) {
                return `Slab ${i + 1} has no ${maxLabel} but Slab ${i + 2} comes after it. Only the last slab can be open-top.`;
            }
            if (filled(nxtMin) && num(curMax) >= num(nxtMin)) {
                return `Slab ${i + 1} and Slab ${i + 2} ranges overlap.`;
            }
        }

        for (let i = 1; i < this.slabs.length; i++) {
            const prev = num(this.slabs[i - 1][benefitField]);
            const cur  = num(this.slabs[i][benefitField]);
            if (cur <= prev) {
                return `Slab ${i + 1}'s ${benefitLabel} (${cur}) must be greater than Slab ${i}'s ${benefitLabel} (${prev}). Higher slabs should give a better deal.`;
            }
        }

        return null;
    }

    get areSlabsValid() {
        return this.slabsError === null;
    }

    get slabsValidationMessage() {
        return this.slabsError || 'Fill every slab row to continue.';
    }

    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get stepLabel() { return this.isStep1 ? 'Step 1 of 2 — Definition' : 'Step 2 of 2 — Applicability'; }

    get step1Class() {
        return 'stepper__item' + (this.isStep1 ? ' stepper__item--active' : ' stepper__item--done stepper__item--clickable');
    }
    get step2Class() {
        return 'stepper__item' + (this.isStep2 ? ' stepper__item--active' : '');
    }

    handleStepperStep1() {
        if (this.isStep2 && !this.isSaving) this.currentStep = 1;
    }

    get isStep1Complete() {
        return this.hasMasterMinimums && this.isMasterValid && this.isLinkageValid && this.areSlabsValid;
    }
    get isNextDisabled() { return this.isSaving || !this.isStep1Complete; }
    get isSaveDisabled() {
        return this.isSaving || !this.isStep1Complete || !this.isApplicabilityValid;
    }

    get regionsApplyToAll()          { return this.applicability.regions.applyToAll; }
    get areasApplyToAll()            { return this.applicability.areas.applyToAll; }
    get territoriesApplyToAll()      { return this.applicability.territories.applyToAll; }
    get outletCategoriesApplyToAll() { return this.applicability.outletCategories.applyToAll; }

    get regionsPickerDisabled()          { return this.regionsApplyToAll; }
    get areasPickerDisabled()            { return this.areasApplyToAll; }
    get territoriesPickerDisabled()      { return this.territoriesApplyToAll; }
    get outletCategoriesPickerDisabled() { return this.outletCategoriesApplyToAll; }

    get regionOptions() {
        return (this.applicabilityOptions.regions || []).map(v => ({ label: v, value: v }));
    }
    get areaOptions() {
        return (this.applicabilityOptions.areas || []).map(v => ({ label: v, value: v }));
    }
    get territoryOptions() {
        return (this.applicabilityOptions.territories || []).map(t => ({
            label: t.name + (t.region || t.area ? ` — ${[t.region, t.area].filter(Boolean).join(' / ')}` : ''),
            value: t.id
        }));
    }
    get outletCategoryOptions() {
        return (this.applicabilityOptions.outletCategories || []).map(v => ({ label: v, value: v }));
    }

    get regionsValues()          { return this.applicability.regions.values; }
    get areasValues()            { return this.applicability.areas.values; }
    get territoriesValues()      { return this.applicability.territories.values; }
    get outletCategoriesValues() { return this.applicability.outletCategories.values; }

    get isApplicabilityValid() {
        return this.isLevelValid(this.applicability.regions)
            && this.isLevelValid(this.applicability.areas)
            && this.isLevelValid(this.applicability.territories)
            && this.isLevelValid(this.applicability.outletCategories);
    }

    isLevelValid(level) {
        if (!level) return false;
        return level.applyToAll || (Array.isArray(level.values) && level.values.length > 0);
    }

    get applicabilityMessage() {
        if (!this.isLevelValid(this.applicability.regions))          return { cls: 'chip chip--info', text: 'Pick at least one Region, or toggle Apply to all Regions.' };
        if (!this.isLevelValid(this.applicability.areas))            return { cls: 'chip chip--info', text: 'Pick at least one Area, or toggle Apply to all Areas.' };
        if (!this.isLevelValid(this.applicability.territories))      return { cls: 'chip chip--info', text: 'Pick at least one Territory, or toggle Apply to all Territories.' };
        if (!this.isLevelValid(this.applicability.outletCategories)) return { cls: 'chip chip--info', text: 'Pick at least one Outlet Category, or toggle Apply to all Outlet Categories.' };
        return { cls: 'chip chip--green', text: 'Ready to save.' };
    }

    get inlineMessage() {
        const m = this.master;
        if (!m.name || !m.schemeType || !m.salesChannel || !m.startDate || !m.endDate) {
            return { cls: 'chip chip--info', text: 'Fill all required master fields.' };
        }
        if (m.endDate < m.startDate) {
            return { cls: 'chip chip--red', text: 'End Date must be on/after Start Date.' };
        }
        const today = this.todayIso;
        const startChanged = !this.savedStartDate || m.startDate !== this.savedStartDate;
        if (startChanged && m.startDate < today) {
            return { cls: 'chip chip--red', text: 'Start Date cannot be in the past.' };
        }
        if (m.endDate < today) {
            return { cls: 'chip chip--red', text: 'End Date cannot be in the past.' };
        }
        if (!this.isLinkageValid) {
            return { cls: 'chip chip--info', text: this.step2Mode === 'group'
                ? 'Select a Scheme Product Group to continue.'
                : 'Select a Product Category to continue.' };
        }
        if (!this.areSlabsValid) {
            return { cls: 'chip chip--red', text: this.slabsValidationMessage };
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

    handleActiveToggle(event) {
        const checked = event.target && typeof event.target.checked === 'boolean'
            ? event.target.checked
            : !!(event.detail && event.detail.checked);
        this.master = { ...this.master, isActive: checked };
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

    async handleNext() {
        if (this.isNextDisabled) return;
        this.currentStep = 2;
        await this.refreshApplicabilityOptions();
    }

    handleBack() {
        this.currentStep = 1;
    }

    async refreshApplicabilityOptions() {
        const channel = this.master.salesChannel;
        if (!channel) return;
        this.isLoadingApplicability = true;
        try {
            const a = this.applicability;
            const regions = a.regions.applyToAll ? [] : (a.regions.values || []);
            const areas   = a.areas.applyToAll   ? [] : (a.areas.values   || []);
            const opts = await getApplicabilityOptions({
                salesChannel: channel,
                regions,
                areas
            });
            this.applicabilityOptions = {
                regions: opts.regions || [],
                areas: opts.areas || [],
                territories: opts.territories || [],
                outletCategories: opts.outletCategories || []
            };
            this.pruneStaleSelections();
        } catch (error) {
            this.toast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoadingApplicability = false;
        }
    }

    pruneStaleSelections() {
        const regSet  = new Set(this.applicabilityOptions.regions || []);
        const areaSet = new Set(this.applicabilityOptions.areas || []);
        const terrSet = new Set((this.applicabilityOptions.territories || []).map(t => t.id));
        const ocSet   = new Set(this.applicabilityOptions.outletCategories || []);
        const a = this.applicability;
        this.applicability = {
            regions:          { applyToAll: a.regions.applyToAll,          values: (a.regions.values          || []).filter(v => regSet.has(v))  },
            areas:            { applyToAll: a.areas.applyToAll,            values: (a.areas.values            || []).filter(v => areaSet.has(v)) },
            territories:      { applyToAll: a.territories.applyToAll,      values: (a.territories.values      || []).filter(v => terrSet.has(v)) },
            outletCategories: { applyToAll: a.outletCategories.applyToAll, values: (a.outletCategories.values || []).filter(v => ocSet.has(v))   }
        };
    }

    handleRegionsApplyToAll(event)          { this.toggleApplyToAll('regions', event); }
    handleAreasApplyToAll(event)            { this.toggleApplyToAll('areas', event); }
    handleTerritoriesApplyToAll(event)      { this.toggleApplyToAll('territories', event); }
    handleOutletCategoriesApplyToAll(event) { this.toggleApplyToAll('outletCategories', event); }

    toggleApplyToAll(levelKey, event) {
        const checked = event.target && typeof event.target.checked === 'boolean'
            ? event.target.checked
            : !!(event.detail && event.detail.checked);
        const next = { ...this.applicability };
        next[levelKey] = { applyToAll: checked, values: checked ? [] : next[levelKey].values };
        this.applicability = next;
        if (levelKey === 'regions' || levelKey === 'areas') {
            this.refreshApplicabilityOptions();
        }
    }

    handleRegionsChange(event)          { this.setLevelValues('regions', event, true); }
    handleAreasChange(event)            { this.setLevelValues('areas', event, true); }
    handleTerritoriesChange(event)      { this.setLevelValues('territories', event, false); }
    handleOutletCategoriesChange(event) { this.setLevelValues('outletCategories', event, false); }

    setLevelValues(levelKey, event, refreshChildren) {
        const values = (event.detail && event.detail.value) || [];
        const next = { ...this.applicability };
        next[levelKey] = { applyToAll: false, values: [...values] };
        this.applicability = next;
        if (refreshChildren) {
            this.refreshApplicabilityOptions();
        }
    }

    resetWizard() {
        this.master = {
            name: '',
            schemeType: '',
            salesChannel: '',
            startDate: '',
            endDate: '',
            description: '',
            isActive: true
        };
        this.savedStartDate = '';
        this.linkage = { productGroupId: '', productGroupName: '', productCategory: '' };
        this.slabs = [];
        this.productGroupResults = [];
        this.focUi = { activeUid: '', term: '', results: [] };
        this.applicability = {
            regions:          { applyToAll: false, values: [] },
            areas:            { applyToAll: false, values: [] },
            territories:      { applyToAll: false, values: [] },
            outletCategories: { applyToAll: false, values: [] }
        };
        this.applicabilityOptions = { regions: [], areas: [], territories: [], outletCategories: [] };
        this.savedTerritoryDisplay = {};
        this.currentStep = 1;
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
                productCategory: this.linkage.productCategory || null,
                isActive:        this.master.isActive !== false
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
            const payloadApplicability = {
                regions:          { applyToAll: !!this.applicability.regions.applyToAll,          values: this.applicability.regions.values || [] },
                areas:            { applyToAll: !!this.applicability.areas.applyToAll,            values: this.applicability.areas.values || [] },
                territories:      { applyToAll: !!this.applicability.territories.applyToAll,      values: this.applicability.territories.values || [] },
                outletCategories: { applyToAll: !!this.applicability.outletCategories.applyToAll, values: this.applicability.outletCategories.values || [] }
            };
            const savedId = await saveSchemeWithApplicability({
                master: payloadMaster,
                slabs: payloadSlabs,
                applicability: payloadApplicability,
                existingId: this.recordId || null
            });
            const wasEdit = this.isEditMode;
            this.toast('Success', wasEdit ? 'Scheme updated.' : 'Scheme created.', 'success');
            this.dispatchEvent(new CustomEvent('complete', { detail: { recordId: savedId } }));
            if (!wasEdit) {
                this.resetWizard();
            }
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