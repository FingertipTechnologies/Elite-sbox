import { LightningElement, api, track } from 'lwc';

/**
 * Lightweight type-ahead single-select over a static option list
 * ([{label, value}]). Used for the Object / Field / User Field pickers on the
 * S&D Parameter setup screen where the lists are long. Emits `change` with
 * { detail: { value } }.
 */
export default class SearchableCombobox extends LightningElement {
    @api label;
    @api placeholder = 'Search…';
    @api options = [];
    @api required = false;
    @api disabled = false;

    _value;
    @api
    get value() {
        return this._value;
    }
    set value(v) {
        this._value = v;
    }

    @track searchTerm = '';
    @track isOpen = false;
    _typing = false;

    get selectedLabel() {
        const o = (this.options || []).find((x) => x.value === this._value);
        return o ? o.label : '';
    }
    get displayText() {
        return this._typing ? this.searchTerm : this.selectedLabel;
    }
    get filtered() {
        if (!this._typing || !this.searchTerm) return this.options || [];
        const t = this.searchTerm.toLowerCase();
        return (this.options || []).filter((o) => (o.label || '').toLowerCase().includes(t));
    }
    get hasResults() {
        return this.filtered.length > 0;
    }
    get comboClass() {
        return (
            'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click' +
            (this.isOpen ? ' slds-is-open' : '')
        );
    }

    handleFocus() {
        if (this.disabled) return;
        this.isOpen = true;
        this._typing = false;
        this.searchTerm = '';
    }
    handleInput(event) {
        this._typing = true;
        this.searchTerm = event.target.value;
        this.isOpen = true;
    }
    handleBlur() {
        // delay so a mousedown on an option registers first
        window.setTimeout(() => {
            this.isOpen = false;
            this._typing = false;
        }, 200);
    }
    handleSelect(event) {
        const v = event.currentTarget.dataset.value;
        this._value = v;
        this._typing = false;
        this.isOpen = false;
        this.searchTerm = '';
        this.dispatchEvent(new CustomEvent('change', { detail: { value: v } }));
    }
    handleClear() {
        this._value = '';
        this.searchTerm = '';
        this._typing = false;
        this.dispatchEvent(new CustomEvent('change', { detail: { value: '' } }));
    }
}