import { LightningElement } from 'lwc';

export default class KpiDashboard extends LightningElement {
    activeTab = 'primary';
    primaryLoaded = true;   // first tab renders immediately
    secondaryLoaded = false; // rendered on first activation

    handleTabActive(event) {
        const tab = event.target.value;
        this.activeTab = tab;
        if (tab === 'primary') this.primaryLoaded = true;
        if (tab === 'secondary') this.secondaryLoaded = true;
    }
}
