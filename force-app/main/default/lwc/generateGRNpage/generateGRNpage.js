import { LightningElement, api, track } from 'lwc';
import createGRN from '@salesforce/apex/DMSPortalLwc.createGRN';
import saveGRNFile from '@salesforce/apex/DMSPortalLwc.saveGRNFile';
import getInvoicesByIds from '@salesforce/apex/DMSPortalLwc.getInvoicesByIds';
import GOOGLE_ICONS from '@salesforce/resourceUrl/googleIcons';

export default class GenerateGRNpage extends LightningElement {
    @api invoiceIds; // expects a single-item list
    @track invoiceItems = [];
    isPageLoaded = false;
    loading = false;
    @track grnComments = '';
    @track selectedFileName = '';
    fileBase64 = '';

    googleIcons = {
        order: GOOGLE_ICONS + "/googleIcons/order.png",
        sort: GOOGLE_ICONS + "/googleIcons/sort.png",
        progress: GOOGLE_ICONS + "/googleIcons/progress.png",
        play: GOOGLE_ICONS + "/googleIcons/play.png",
        forward: GOOGLE_ICONS + "/googleIcons/forward.png"
    };

    connectedCallback() {
        this.fetchInvoices();
    }

    fetchInvoices() {
        this.isPageLoaded = true;

        getInvoicesByIds({ invoiceIds: this.invoiceIds })
            .then(result => {
                this.invoiceItems = result.map(inv => ({
                    id: inv.Id,
                    name: inv.Name,
                    invoiceNo: inv.Invoice_No__c,
                    store: inv.Store__r?.Name,
                    lineItems: inv.Invoice_line_items__r?.map((item, index) => ({
                        rowIndex: index + 1, 
                        id: item.Id,
                        name: item.Name,
                        productId: item.SKU__c,
                        productName: item.SKU__r?.Name,
                        quantity: item.Qyt_in_Each__c,
                        receivedSaleableQty: item.Qyt_in_Each__c,
                        receivedNonSaleableQty: 0,
                        receivedQty: item.Qyt_in_Each__c
                    })) || []
                }));
                this.isPageLoaded = false;
            })
            .catch(error => {
                this.showToast(
                    'Error',
                    error.body?.message || 'Unknown error',
                    'error'
                );
                this.isPageLoaded = false;
            });
    }


    handleReceivedSaleableQtyChange(event) {
        const invoiceId = event.target.dataset.invoice;
        const index = event.target.dataset.index;
        const value = parseFloat(event.detail.value);

        const invoice = this.invoiceItems.find(i => i.id === invoiceId);
        if (invoice) {
            invoice.lineItems[index].receivedSaleableQty = value;
            this.updateReceivedQty(invoiceId, index);
        }
    }

    handleReceivedNonSaleableQtyChange(event) {
        const invoiceId = event.target.dataset.invoice;
        const index = event.target.dataset.index;
        const value = parseFloat(event.detail.value);

        const invoice = this.invoiceItems.find(i => i.id === invoiceId);
        if (invoice) {
            invoice.lineItems[index].receivedNonSaleableQty = value;
            this.updateReceivedQty(invoiceId, index);
        }
    }


    updateReceivedQty(invoiceId, index) {

        const invoice = this.invoiceItems.find(i => i.id === invoiceId);
        if (!invoice) return;

        const line = invoice.lineItems[index];

        const saleable = parseFloat(line.receivedSaleableQty) || 0;
        const nonSaleable = parseFloat(line.receivedNonSaleableQty) || 0;

        const totalReceived = saleable + nonSaleable;
        // ===== ASSIGN ONLY IF VALID =====
        line.receivedQty = totalReceived;
        // ===== VALIDATION =====
        if (totalReceived != parseFloat(line.quantity || 0)) {

            this.showToast(
                'Error',
                'Total received quantity is not matching with invoiced quantity',
                'error'
            ); 
         
            return;
        }
    }




    handleCommentsChange(event) {
        this.grnComments = event.detail.value;
    }

    handleFileUpload(event) {
        const file = event.target.files[0];
        if (!file) return;

        this.selectedFileName = file.name;
        const reader = new FileReader();
        reader.onload = () => {
            this.fileBase64 = reader.result.split(',')[1];
        };
        reader.readAsDataURL(file);
    }

    handleRemoveFile() {
        this.selectedFileName = '';
        this.fileBase64 = '';
        const input = this.template.querySelector('input[type="file"]');
        if (input) input.value = null;
    }

    handleSave() {
        if (!this.invoiceItems || this.invoiceItems.length === 0) {
            this.showToast('Error', 'No invoice data found', 'error');
            return;
        }

        const invoice = this.invoiceItems[0];
        const invoiceId = invoice.id;

        console.log('Sending invoiceId:', invoiceId);

        const payload = [];

        for (let item of invoice.lineItems) {
            // Check for invalid receivedQty
            if (
                item.receivedQty === undefined ||
                item.receivedQty === null ||
                item.receivedQty <= 0
            ) {
                this.showToast(
                    'Error',
                    `Received Saleable Or Non-Saleable Quantity missing for item at row ${item.rowIndex}.`,
                    'error'
                );
                return; // Stop further execution
            }

            if (Number(item.receivedQty || 0) !== Number(item.quantity || 0)) {
                this.showToast(
                    'Error',
                    `Total received quantity is not matching with invoiced quantity for item at row ${item.rowIndex}.`,
                    'error'
                );
                return; // Stop further execution
            }


            // Add valid items to the payload
            payload.push({
                sobjectType: 'Goods_Received_Note_Item__c',
                Invoice_Item__c: item.id,
                Product__c: item.productId,
                SKU_Name__c: item.productName,
                Invoiced_Quantity__c: item.quantity,
                Received_Nonsaleable_Quantity__c: item.receivedNonSaleableQty,
                Received_Saleable_Quantity__c: item.receivedSaleableQty,
                Received_Quantity__c : item.receivedQty
            });
        }


        console.log('Payload:', JSON.stringify(payload));

        if (payload.length === 0) {
            this.showToast('Error', 'No valid items to save.', 'error');
            return;
        }

        this.isPageLoaded = true;

        createGRN({ invoiceId: invoiceId, items: payload, comments: this.grnComments || '' })

            .then(grnId => {
                if (this.fileBase64 && this.selectedFileName) {
                    return saveGRNFile({
                        grnId: grnId,
                        fileName: this.selectedFileName,
                        base64Data: this.fileBase64
                    })
                        .then(() => grnId)
                        .catch(error => {
                            this.showToast(
                                'Warning',
                                'GRN created but file upload failed: ' + (error.body?.message || 'Unknown error'),
                                'warning'
                            );
                            return grnId;
                        });
                }
                return grnId;
            })
            .then(grnId => {
                this.showToast('Success', 'GRN created successfully', 'success');
                setTimeout(() => {
                    this.dispatchEvent(new CustomEvent('grncreated', {
                        detail: {
                            message: 'GRN creation completed',
                            invoiceId: invoiceId
                        }
                    }));
                    this.isPageLoaded = false;
                }, 1000);
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Unknown error', 'error');
                this.isPageLoaded = false;
            });
    }




    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    // Custom Toast method (to use c-custom-toast)
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