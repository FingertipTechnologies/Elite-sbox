import { LightningElement, track, api } from 'lwc';
import getSecondaryOrders from '@salesforce/apex/DMSPortalLwc.getSecondaryOrders';
import getOrderItems from '@salesforce/apex/DMSPortalLwc.getOrderItems';
import saveSecondaryInvoice from '@salesforce/apex/DMSPortalLwc.saveSecondaryInvoice';


export default class DmsPortal extends LightningElement {
    @api selectedOrderIds;
    @api selectedOrderId;
    @api selectedCustomerName;
    @api selectedCustomerId;
    @track orderList = [];
    @track selectedOrders = [];
    @track invoiceItems = [];
    remarks = '';
    delivaryRemakrs ='';
    gstNumber = '';
    irnNumber = '';
    customerName = '';
    beatName = '';
    isSubPartLoad = false;
    invoiceDate = new Date().toISOString().split('T')[0];

    // Replaced this.showInvoiceScreen with this.isGenerateInvoice
    isSubPartLoad = false;

    connectedCallback() {
        console.log('ordrId --'+this.selectedOrderId);
        this.getorderItems()
    }

    getorderItems() {
        this.isSubPartLoad = true;

        getOrderItems({ orderId: this.selectedOrderId })
            .then(data => {

                // Directly process items (no aggregation needed)
                const invitems = data.map(item => ({
                    ...item,
                    Quantity: Number(item.Quantity),
                    TaxAmount: Number(item.TaxAmount).toFixed(2),
                    TotalAmount: Number(item.TotalAmount).toFixed(2),
                    availableQuantity: Number(item.availableQuantity)
                }));

                this.invoiceItems = this.addRowIndex(invitems);

                this.customerName = this.invoiceItems[0]?.CustomerName || '';
                this.beatName = data.length > 0 ? (data[0].BeatName || '') : '';
                this.gstNumber = data.length > 0 ? (data[0].gstNumber || '') : '';
                this.isGenerateInvoice = true;
                this.isSubPartLoad = false;
            })
            .catch(error => {
                console.error('Error fetching order items:', error);
                this.showToast('Error', 'Failed to load order items', 'error');
                this.isSubPartLoad = false;
            });
    }

    handleQuantityChange(event) {
        const itemId = event.target.dataset.id;
        const newQty = Number(event.target.value);

        this.invoiceItems = this.invoiceItems.map(item => {
            if (item.OrderItemId === itemId) {

                //  Validation: Qty should not exceed Available Qty
                if (newQty > item.availableQuantity) {
                    this.showToast(
                        'Validation Error',
                        "Invoice Qty can't be more than Available Qty.",
                        'error'
                    );
                }

                //  Valid quantity → update values
                item.Quantity = newQty;
                item.TaxAmount = (
                    item.UnitPrice * newQty * item.TaxPercent / 100
                ).toFixed(2);
                item.TotalAmount = (
                    item.UnitPrice * newQty * (1 + item.TaxPercent / 100)
                ).toFixed(2);
            }
            return item;
        });
    }

    handleSave() {
        try {
            console.log('handleSave called');

            // Validate invoice items
            if (!this.invoiceItems || this.invoiceItems.length === 0) {
                this.showToast('Validation Error', 'No items to save.', 'error');
                return;
            }

            const payload = [];
            let totalQuantity = 0;
            let totalTax = 0;
            let grandTotal = 0;
            for (let item of this.invoiceItems) {

                // Quantity validation
                if (!item.Quantity || item.Quantity <= 0) {
                    this.showToast(
                        'Validation Error',
                        `Row ${item.rowIndex}: Please add a valid Quantity.`,
                        'error'
                    );
                    return;
                }

                // Available Quantity validation
                if (
                    item.availableQuantity !== undefined &&
                    item.Quantity > item.availableQuantity
                ) {
                    this.showToast(
                        'Validation Error',
                        `Row ${item.rowIndex} (${item.ProductName}): Invoice Qty can't be more than Available Qty (${item.availableQuantity}).`,
                        'error'
                    );
                    return;
                }
                totalQuantity += Number(item.Quantity) || 0;
                totalTax += Number(item.TaxAmount) || 0;
                grandTotal += Number(item.TotalAmount) || 0;

                payload.push({
                    sobjectType: 'Secondary_Invoice_Item__c',
                    Product__c: item.ProductId,
                    Product_Name__c: item.ProductName,
                    Store__c: item.customerName,
                    Quantity__c: item.Quantity,
                    Unit_Price__c: item.UnitPrice,
                    Tax_Amount__c: item.TaxAmount,
                    Tax_Percent__c : item.TaxPercent,
                    Order_Item__c: item.OrderItemId,
                    Total_Amount__c: item.TotalAmount,
                    Order_Item__c : item.OrderItemId,
                    Before_Category_Slab_Unit_Price__c: item.BeforeCategorySlabUnitPrice,
                    After_Category_Slab_Unit_Price__c: item.AfterCategorySlabUnitPrice,
                    Before_Scheme_Unit_Price__c: item.BeforeSchemeUnitPrice,
                    After_Scheme_Unit_Price__c: item.AfterSchemeUnitPrice,
                    Scheme_Item__c: item.schemeItem || null
                });
            }

            const secondaryInvoicePayload = {
                sobjectType: 'Secondary_Invoice__c',
                Store__c: this.selectedCustomerId,
                Invoice_Date__c: this.invoiceDate,
                Customer_Name__c: this.selectedCustomerName,
                Status__c: 'Raised',
                Remarks__c: this.remarks,
                Delivery_remarks__c: this.delivaryRemakrs,
                GST_Number__c: this.gstNumber,
                IRN_Number__c: this.irnNumber,
                Order__c :  this.selectedOrderId,
                Total_Tax__c: totalTax,
                Grand_Total__c: grandTotal,
                Total_Quantity__c: totalQuantity,
                Beat_Name__c: this.beatName
            };

            if (!secondaryInvoicePayload.Store__c || !secondaryInvoicePayload.Invoice_Date__c) {
                this.showToast(
                    'Validation Error',
                    'Missing required fields: Store or Invoice Date.',
                    'error'
                );
                return;
            }
            this.isSubPartLoad = true;
            saveSecondaryInvoice({
                invoices: [secondaryInvoicePayload],
                items: payload
            })
                .then(() => {
                     this.isSubPartLoad = false;
                    this.showToast(
                        'Success',
                        'Secondary Invoice saved successfully.',
                        'success'
                    );
                    
                    setTimeout(() => {
                        this.dispatchEvent(new CustomEvent('returncreated'));
                        this.resetForm();
                    }, 1000);
                })
                .catch(error => {
                    console.error(error);
                    this.showToast(
                        'Error',
                        error.body?.message || error.message,
                        'error'
                    );
                });

        } catch (error) {
            console.error(error);
            this.showToast(
                'Error',
                'Failed to save. Please try again.',
                'error'
            );
        }
    }
    onUpdateRemakrs(event) {
        var remarks = event.target.value;
        this.remarks = remarks;
    }

    onUpdateDelivaryRemakrs(event) {
        var delivaryRemakrs = event.target.value;
        this.delivaryRemakrs = delivaryRemakrs;
    }

    onUpdateGstNumber(event) {
        this.gstNumber = event.target.value;
    }

    onUpdateIrnNumber(event) {
        this.irnNumber = event.target.value;
    }

    handleCancel() {
        // this.resetToOrderList();
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    addRowIndex(data) {
        return data.map((row, index) => {
            return {
                ...row,
                rowIndex: index + 1
            };
        });
    }

    resetToOrderList() {
        this.selectedOrders = [];
        this.selectedCustomerId = null;
        this.customerName = '';
        this.invoiceItems = [];
        this.isGenerateInvoice = false; // Reset to hide the invoice screen
    }
    showToast(title, message, variant) {
        const toast = this.template.querySelector('c-custom-toast'); // Query the toast component
        console.log('Custom Toast component:', toast);  // Log the reference

        if (toast) {
            toast.showToast(variant, message); // Show the toast with the correct variant
        } else {
            console.error('Custom Toast component not found!');
        }
    }
}