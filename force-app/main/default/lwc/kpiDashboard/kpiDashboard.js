import { LightningElement } from 'lwc';

export default class KpiDashboard extends LightningElement {
    activeTab = 'primary';
    primaryLoaded = true;    // first pane renders immediately
    secondaryLoaded = false; // rendered on first activation

    get isPrimary() { return this.activeTab === 'primary'; }
    get isSecondary() { return this.activeTab === 'secondary'; }

    get primaryTabClass() { return 'kd-tab' + (this.isPrimary ? ' kd-tab--active' : ''); }
    get secondaryTabClass() { return 'kd-tab' + (this.isSecondary ? ' kd-tab--active' : ''); }
    get primaryPaneClass() { return 'kd-pane' + (this.isPrimary ? '' : ' kd-hidden'); }
    get secondaryPaneClass() { return 'kd-pane' + (this.isSecondary ? '' : ' kd-hidden'); }

    selectPrimary() { this.activeTab = 'primary'; this.primaryLoaded = true; }
    selectSecondary() { this.activeTab = 'secondary'; this.secondaryLoaded = true; }
}
