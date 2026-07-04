import { LightningElement, wire } from 'lwc';
import currentUserShowsPrimary from '@salesforce/apex/PrimaryKpiDashboard_Controller.currentUserShowsPrimary';

export default class KpiDashboard extends LightningElement {
    activeTab = 'primary';
    primaryLoaded = true;    // first pane renders immediately
    secondaryLoaded = false; // rendered on first activation
    showPrimary = true;      // payroll users see Primary; resolved by the wire below

    // Only payroll employees participate in Primary PBIS. For everyone else, hide
    // the Primary tab and land straight on Secondary.
    @wire(currentUserShowsPrimary)
    wiredShowPrimary({ data }) {
        if (data === false) {
            this.showPrimary = false;
            this.primaryLoaded = false;
            this.activeTab = 'secondary';
            this.secondaryLoaded = true;
        } else if (data === true) {
            this.showPrimary = true;
        }
        // On error, keep the optimistic default (show Primary).
    }

    get isPrimary() { return this.activeTab === 'primary'; }
    get isSecondary() { return this.activeTab === 'secondary'; }

    get primaryTabClass() { return 'kd-tab' + (this.isPrimary ? ' kd-tab--active' : ''); }
    get secondaryTabClass() { return 'kd-tab' + (this.isSecondary ? ' kd-tab--active' : ''); }
    get primaryPaneClass() { return 'kd-pane' + (this.isPrimary ? '' : ' kd-hidden'); }
    get secondaryPaneClass() { return 'kd-pane' + (this.isSecondary ? '' : ' kd-hidden'); }

    selectPrimary() { this.activeTab = 'primary'; this.primaryLoaded = true; }
    selectSecondary() { this.activeTab = 'secondary'; this.secondaryLoaded = true; }
}
