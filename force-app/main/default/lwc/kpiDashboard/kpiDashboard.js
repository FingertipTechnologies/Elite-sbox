import { LightningElement, wire } from 'lwc';
import currentUserShowsPrimary from '@salesforce/apex/PrimaryKpiDashboard_Controller.currentUserShowsPrimary';

export default class KpiDashboard extends LightningElement {
    resolved = false;        // wire has returned — render the dashboard
    showPrimary = false;     // only payroll users see the Primary KPI tab
    activeTab = 'secondary'; // default until the wire resolves (fail-safe to Secondary)
    primaryLoaded = false;
    secondaryLoaded = false;

    @wire(currentUserShowsPrimary)
    wiredShowPrimary({ data, error }) {
        if (data !== undefined) {
            this.showPrimary = data === true;
            if (this.showPrimary) {
                this.activeTab = 'primary';
                this.primaryLoaded = true;
            } else {
                this.activeTab = 'secondary';
                this.secondaryLoaded = true;
            }
            this.resolved = true;
        } else if (error) {
            // Fail safe: show only the Secondary KPI dashboard.
            this.showPrimary = false;
            this.activeTab = 'secondary';
            this.secondaryLoaded = true;
            this.resolved = true;
        }
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
