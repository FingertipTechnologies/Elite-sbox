import { LightningElement, api, track } from 'lwc';
import searchRecords from '@salesforce/apex/LookupController.searchRecords';

export default class CLookup extends LightningElement {
    @api label = 'Search';
    @api placeholder = 'Type to search...';
    @api objectApiName; // e.g. 'Product__c', 'User', 'Account'
    @api filterField;   // Optional: e.g. 'Channel__c'
    @api filterValue;   // Optional: 'GT' etc.
    @api field;
    @api index;
    @api iconName = 'standard:default'; // Use 'standard:user', 'standard:account', etc.

    // Optional preselected display text (e.g. restore a saved value on edit)
    _preselectedLabel;
    @api
    get preselectedLabel() { return this._preselectedLabel; }
    set preselectedLabel(value) {
        this._preselectedLabel = value;
        if (value) this.searchKey = value;
    }

    @track searchKey = '';
    @track results = [];
    @track showDropdown = false;

    handleSearchChange(event) {
        this.searchKey = event.target.value;
        if (this.searchKey.length > 1) {
            searchRecords({
                objectApiName: this.objectApiName,
                searchKey: this.searchKey,
                filterField: this.filterField,
                filterValue: this.filterValue
            }).then(data => {
                this.results = data;
                this.showDropdown = true;
            }).catch(error => {
                console.error(error);
            });
        } else {
            this.showDropdown = false;
            this.results = [];
        }
    }

    handleSelect(event) {
    const selectedId = event.currentTarget.dataset.id;
    const selectedName = event.currentTarget.dataset.name;

    this.searchKey = selectedName;
    this.showDropdown = false;

    this.dispatchEvent(new CustomEvent('lookupselect', {
        detail: {
            index: this.index,
            field: this.field,
            value: selectedId,
            label: selectedName
        }
    }));
}



    
}