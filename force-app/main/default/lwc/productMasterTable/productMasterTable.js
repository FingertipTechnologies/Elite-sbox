import { LightningElement, track, wire } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

import PRODUCT_OBJECT from '@salesforce/schema/Product__c';
import CATEGORY_FIELD from '@salesforce/schema/Product__c.Category__c';
import PRODUCT_GROUP_FIELD from '@salesforce/schema/Product__c.Product_Group__c';
import PRODUCT_SUB_GROUP_FIELD from '@salesforce/schema/Product__c.Product_Sub_Group__c';

import getProductGalleryData from '@salesforce/apex/DMSPortalLwc.getProductGalleryData';

export default class ProductMasterTable extends LightningElement {

    @track allProducts = [];
    @track filteredProducts = [];

    @track categoryOptions = [{ label: 'All Categories', value: '' }];
    @track productGroupOptions = [{ label: 'All Product Groups', value: '' }];
    @track productSubGroupOptions = [{ label: 'All Product Sub Groups', value: '' }];

    selectedCategory = '';
    selectedProductGroup = '';
    selectedProductSubGroup = '';
    searchKey = '';
    @track viewMode = 'table';

    isLoading = false;
    productRecordTypeId;

    // Record Type
    @wire(getObjectInfo, { objectApiName: PRODUCT_OBJECT })
    objectInfoHandler({ data }) {
        if (data) {
            this.productRecordTypeId = data.defaultRecordTypeId;
        }
    }

    // Category
    @wire(getPicklistValues, { recordTypeId: '$productRecordTypeId', fieldApiName: CATEGORY_FIELD })
    categoryHandler({ data }) {
        if (data) {
            this.categoryOptions = [
                { label: 'All Categories', value: '' },
                ...data.values.map(v => ({ label: v.label, value: v.value }))
            ];
        }
    }

    // Product Group
    @wire(getPicklistValues, { recordTypeId: '$productRecordTypeId', fieldApiName: PRODUCT_GROUP_FIELD })
    groupHandler({ data }) {
        if (data) {
            this.productGroupOptions = [
                { label: 'All Product Groups', value: '' },
                ...data.values.map(v => ({ label: v.label, value: v.value }))
            ];
        }
    }

    // Sub Group
    @wire(getPicklistValues, { recordTypeId: '$productRecordTypeId', fieldApiName: PRODUCT_SUB_GROUP_FIELD })
    subGroupHandler({ data }) {
        if (data) {
            this.productSubGroupOptions = [
                { label: 'All Product Sub Groups', value: '' },
                ...data.values.map(v => ({ label: v.label, value: v.value }))
            ];
        }
    }

    connectedCallback() {
        this.loadData();
    }

    loadData() {
        this.isLoading = true;

        getProductGalleryData()
            .then(data => {
                this.allProducts = data.map((p, index) => {

                    const alternateUom = p.Alternate_UOM__c || '';
                    const uomConversion = p.Uom_Conversion__c || '';
                    const uom = p.UOM__c || '';

                    const hasConversion = !!(alternateUom && uomConversion !== '' && uom);
                    const imageUrl = p.Product_Image_Url__c || null;

                    return {
                        id: p.Id,
                        index: index + 1,
                        name: p.Name || '',
                        sku: p.SKU_Code__c || '',
                        category: p.Category__c || '',
                        productGroup: p.Product_Group__c || '',
                        productSubGroup: p.Product_Sub_Group__c || '',
                        mrp: p.MRP__c || 0,
                        uom: uom,
                        alternateUom: alternateUom,
                        uomConversion: uomConversion,
                        hasConversion: hasConversion,
                        conversionText: hasConversion
                            ? `Conversion : 1 ${alternateUom} = ${uomConversion} ${uom}`
                            : '',
                        channel: p.Channel__c || '',
                        imageUrl: imageUrl,
                        hasImage: !!imageUrl
                    };
                });

                this.filteredProducts = this.allProducts;
                this.isLoading = false;
            })
            .catch(error => {
                console.error(error);
                this.isLoading = false;
            });
    }

    // Filters
    handleCategoryChange(e) {
        this.selectedCategory = e.detail.value;
        this.filterData();
    }

    handleProductGroupChange(e) {
        this.selectedProductGroup = e.detail.value;
        this.filterData();
    }

    handleProductSubGroupChange(e) {
        this.selectedProductSubGroup = e.detail.value;
        this.filterData();
    }

    handleSearch(e) {
        this.searchKey = e.target.value.toLowerCase();
        this.filterData();
    }

    filterData() {
        let data = [...this.allProducts];

        if (this.selectedCategory) {
            data = data.filter(p => p.category === this.selectedCategory);
        }

        if (this.selectedProductGroup) {
            data = data.filter(p => p.productGroup === this.selectedProductGroup);
        }

        if (this.selectedProductSubGroup) {
            data = data.filter(p => p.productSubGroup === this.selectedProductSubGroup);
        }

        if (this.searchKey) {
            data = data.filter(p => p.name.toLowerCase().includes(this.searchKey));
        }

        this.filteredProducts = data;
    }

    get hasProducts() {
        return this.filteredProducts && this.filteredProducts.length > 0;
    }

    get isTableView() {
        return this.viewMode === 'table';
    }

    get isGridView() {
        return this.viewMode === 'grid';
    }

    get tableViewClass() {
        return this.viewMode === 'table' ? 'rs-filter-btn rs-filter-active' : 'rs-filter-btn';
    }

    get gridViewClass() {
        return this.viewMode === 'grid' ? 'rs-filter-btn rs-filter-active' : 'rs-filter-btn';
    }

    handleViewToggle(event) {
        const view = event.currentTarget.dataset.view;
        if (view === 'table' || view === 'grid') {
            this.viewMode = view;
        }
    }

   handleDownload() {
        const data = this.filteredProducts;

        if (!data || data.length === 0) {
            this.showToast('No Data Found', 'No product data to export.', 'error');
            return;
        }

        try {
            const headers = [
                'S.No', 'Product Name', 'SKU', 'Category',
                'Product Group', 'Sub Group', 'MRP', 'UOM',
                'Alternate UOM', 'UOM Conversion', 'Conversion Text'
            ];

            const rows = data.map((prod, index) => [
                index + 1,
                prod.name || '',
                prod.sku || '',
                prod.category || '',
                prod.productGroup || '',
                prod.productSubGroup || '',
                prod.mrp || '',
                prod.uom || '',
                prod.alternateUom || '',
                prod.uomConversion || '',
                prod.conversionText || '',
            ]);

            const csvContent = [headers, ...rows]
                .map(row =>
                    row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(',')
                )
                .join('\n');

            // ✅ FIXED MIME TYPE
            const blob = new Blob(['\uFEFF' + csvContent], {
                type: 'application/octet-stream'
            });

            const url = URL.createObjectURL(blob);

            const link = document.createElement('a');
            link.href = url;
            link.download = `Product_Master_${new Date().toISOString().slice(0, 10)}.csv`;

            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);

            URL.revokeObjectURL(url);

        } catch (error) {
            console.error('CSV Export Error:', error);
            this.showToast('Error', 'Error while exporting CSV', 'error');
        }
    }
}