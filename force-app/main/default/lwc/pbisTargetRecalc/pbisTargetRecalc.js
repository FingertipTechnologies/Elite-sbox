import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import recalcOne from '@salesforce/apex/PBISActuals_Controller.recalcOne';

export default class PbisTargetRecalc extends LightningElement {
    @api recordId;

    @api async invoke() {
        try {
            await recalcOne({ recordId: this.recordId });
            getRecordNotifyChange([{ recordId: this.recordId }]);
            this.toast('Recalculated', 'Actuals & incentive updated for this PBIS Target.', 'success');
        } catch (e) {
            const msg = (e && e.body && e.body.message) || 'Recalculation failed';
            this.toast('Error', msg, 'error');
        }
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
