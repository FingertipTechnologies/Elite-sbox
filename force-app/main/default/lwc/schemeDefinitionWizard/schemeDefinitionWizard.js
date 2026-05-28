import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPicklists from '@salesforce/apex/SchemeDefinitionController.getPicklists';
import loadScheme from '@salesforce/apex/SchemeDefinitionController.loadScheme';
import searchProductGroups from '@salesforce/apex/SchemeDefinitionController.searchProductGroups';
import saveSchemeWithSlabs from '@salesforce/apex/SchemeDefinitionController.saveSchemeWithSlabs';

const TYPE_FREE_QTY     = 'Free Quantity';
const TYPE_QPS          = 'QPS';
const TYPE_FOC_GIVEAWAY = 'FOC_Giveaway';
const TYPE_ORDER_VALUE  = 'Order_Value';
const TYPE_CATEGORY     = 'Category_Value';

const GROUP_TYPES    = new Set([TYPE_FREE_QTY, TYPE_QPS, TYPE_FOC_GIVEAWAY]);
const CATEGORY_TYPES = new Set([TYPE_CATEGORY]);

let _uidSeq = 0;
const nextUid = () => `slab-${++_uidSeq}`;

const FALLBACK_SCHEME_TYPES = [
    { label: 'Free Quantity', value: TYPE_FREE_QTY },
    { label: 'QPS', value: TYPE_QPS },
    { label: 'FOC Giveaway', value: TYPE_FOC_GIVEAWAY },
    { label: 'Order Value', value: TYPE_ORDER_VALUE },
    { label: 'Category Value', value: TYPE_CATEGORY }
];

export default class SchemeDefinitionWizard extends LightningElement {
    @api recordId;

    @track currentStep = 1;
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
    @track freeQtyMode = 'cycle';
    @track productGroupResults = [];

    @track isLoadingPicklists = false;
    @track isHydrating = false;
    @track isSaving = false;
    @track isSearchingGroups = false;

    salesChannelOptions = [];
    schemeTypeOptionsRaw = [];
    productCategoryOptions = [];

    _searchDebounce;
    _searchTerm = '';

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
            this.salesChannelOptions     = data.salesChannels || [];
            this.schemeTypeOptionsRaw    = data.schemeTypes || [];
            this.productCategoryOptions  = data.productCategories || [];
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
                focProductId: s.focProductId
            }));
            if (this.master.schemeType === TYPE_FREE_QTY) {
                const allMaxNull = incoming.length === 1 && incoming[0].qtyMax == null;
                this.freeQtyMode = allMaxNull ? 'cycle' : 'band';
            }
        } catch (error) {
            this.toast('Error', this.reduceError(error), 'error');
        } finally {
            this.isHydrating = false;
        }
    }

    get isEditMode() { return !!this.recordId; }
    get pageTitle()  { return this.isEditMode ? 'Edit Scheme' : 'New Scheme'; }

    get showStep1() { return this.currentStep === 1; }
    get showStep2() { return this.currentStep === 2; }
    get showStep3() { return this.currentStep === 3; }

    get step1Class() { return this.stepChipClass(1); }
    get step2Class() { return this.stepChipClass(2); }
    get step3Class() { return this.stepChipClass(3); }

    stepChipClass(n) {
        if (n === this.currentStep) return 'step-chip step-chip--active';
        if (n < this.currentStep)   return 'step-chip step-chip--done';
        return 'step-chip';
    }

    get schemeTypeOptions() {
        const list = this.schemeTypeOptionsRaw && this.schemeTypeOptionsRaw.length
            ? this.schemeTypeOptionsRaw
            : FALLBACK_SCHEME_TYPES;
        return list;
    }

    get step2Mode() {
        const t = this.master.schemeType;
        if (GROUP_TYPES.has(t))    return 'group';
        if (CATEGORY_TYPES.has(t)) return 'category';
        return 'none';
    }

    get showGroupPicker()    { return this.step2Mode === 'group'; }
    get showCategoryPicker() { return this.step2Mode === 'category'; }
    get showNoLinkageHint()  { return this.step2Mode === 'none'; }

    get expectedGroupPurpose() {
        return this.master.schemeType === TYPE_FOC_GIVEAWAY ? 'FOCQualifier' : 'PriceDivision';
    }

    get isFreeQty()     { return this.master.schemeType === TYPE_FREE_QTY; }
    get isQps()         { return this.master.schemeType === TYPE_QPS; }
    get isFoc()         { return this.master.schemeType === TYPE_FOC_GIVEAWAY; }
    get isOrderValue()  { return this.master.schemeType === TYPE_ORDER_VALUE; }
    get isCategoryValue() { return this.master.schemeType === TYPE_CATEGORY; }

    get isFreeQtyCycle() { return this.isFreeQty && this.freeQtyMode === 'cycle'; }
    get isFreeQtyBand()  { return this.isFreeQty && this.freeQtyMode === 'band'; }

    get freeQtyModeOptions() {
        return [
            { label: 'Cycle (X + Y repeats)', value: 'cycle' },
            { label: 'Bands (one-shot ranges)', value: 'band' }
        ];
    }

    get canAddSlabRow() {
        if (this.isFreeQtyCycle) return false;
        if (this.isFoc)          return false;
        return true;
    }

    get canRemoveSlabRow() {
        return this.canAddSlabRow && this.slabs.length > 1;
    }

    get displaySlabs() {
        return this.slabs.map((s, i) => ({
            ...s,
            sNo: i + 1,
            showRemove: this.canRemoveSlabRow
        }));
    }

    get currentStepIsValid() {
        if (this.currentStep === 1) return this.isStep1Valid;
        if (this.currentStep === 2) return this.isStep2Valid;
        if (this.currentStep === 3) return this.isStep3Valid;
        return false;
    }

    get isStep1Valid() {
        const m = this.master;
        if (!m.name || !m.schemeType || !m.salesChannel || !m.startDate || !m.endDate) return false;
        return m.endDate >= m.startDate;
    }

    get isStep2Valid() {
        if (this.step2Mode === 'group')    return !!this.linkage.productGroupId;
        if (this.step2Mode === 'category') return !!this.linkage.productCategory;
        return true;
    }

    get isStep3Valid() {
        if (!this.slabs.length) return false;
        for (const s of this.slabs) {
            if (this.isFreeQty) {
                if (s.qtyMin == null || s.qtyMin === '' || s.freeQty == null || s.freeQty === '') return false;
                if (this.isFreeQtyBand && (s.qtyMax === '' || s.qtyMax == null)) {
                    if (this.slabs.indexOf(s) !== this.slabs.length - 1) return false;
                }
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

    get isNextDisabled() {
        return this.currentStep >= 3 || !this.currentStepIsValid || this.isSaving;
    }

    get isBackDisabled() {
        return this.currentStep <= 1 || this.isSaving;
    }

    get isSaveDisabled() {
        return this.isSaving || !this.isStep1Valid || !this.isStep2Valid || !this.isStep3Valid;
    }

    get showNextButton() { return this.currentStep < 3; }
    get showSaveButton() { return this.currentStep === 3; }

    get inlineMessage() {
        if (this.currentStep === 1 && !this.isStep1Valid) {
            if (this.master.endDate && this.master.startDate && this.master.endDate < this.master.startDate) {
                return { cls: 'chip chip--red',  text: 'End Date must be on/after Start Date.' };
            }
            return { cls: 'chip chip--info', text: 'Fill all required master fields to continue.' };
        }
        if (this.currentStep === 2 && !this.isStep2Valid) {
            return { cls: 'chip chip--info', text: this.step2Mode === 'group'
                ? 'Select a Scheme Product Group to continue.'
                : 'Select a Product Category to continue.' };
        }
        if (this.currentStep === 3 && !this.isStep3Valid) {
            return { cls: 'chip chip--info', text: 'Fill every slab row to enable Save.' };
        }
        return { cls: 'chip chip--green', text: 'Ready.' };
    }

    handleMasterChange(event) {
        const field = event.target.dataset.field;
        const value = event.detail ? event.detail.value : event.target.value;
        this.master = { ...this.master, [field]: value };

        if (field === 'schemeType') {
            this.linkage = { productGroupId: '', productGroupName: '', productCategory: '' };
            this.productGroupResults = [];
            this.freeQtyMode = 'cycle';
            this.slabs = this.seedSlabsForType(value, this.freeQtyMode);
        } else if (field === 'salesChannel') {
            this.linkage = { ...this.linkage, productGroupId: '', productGroupName: '' };
            this.productGroupResults = [];
        }
    }

    handleFreeQtyModeChange(event) {
        const next = event.detail.value;
        if (next === this.freeQtyMode) return;
        this.freeQtyMode = next;
        this.slabs = this.seedSlabsForType(this.master.schemeType, next);
    }

    seedSlabsForType(type, mode) {
        if (!type) return [];
        if (type === TYPE_FREE_QTY) {
            if (mode === 'cycle') {
                return [this.makeSlab({ qtyMin: null, qtyMax: null, freeQty: null })];
            }
            return [this.makeSlab({ qtyMin: null, qtyMax: null, freeQty: null })];
        }
        if (type === TYPE_QPS) {
            return [this.makeSlab({ qtyMin: null, benefitPerEa: null })];
        }
        if (type === TYPE_FOC_GIVEAWAY) {
            return [this.makeSlab({ qtyMin: null, freeQty: null, focProductId: '' })];
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
        if (!this.canAddSlabRow) return;
        this.slabs = [...this.slabs, this.makeSlab({})];
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

    handleFocProductChange(event) {
        const uid = event.target.dataset.uid;
        const value = event.detail ? event.detail.recordId : null;
        this.slabs = this.slabs.map(s => s._uid === uid ? { ...s, focProductId: value || '' } : s);
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

    handleNext() {
        if (!this.currentStepIsValid) return;
        if (this.currentStep === 1 && this.step2Mode === 'group' && !this.productGroupResults.length) {
            this.runProductGroupSearch();
        }
        this.currentStep = Math.min(3, this.currentStep + 1);
    }

    handleBack() {
        this.currentStep = Math.max(1, this.currentStep - 1);
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
