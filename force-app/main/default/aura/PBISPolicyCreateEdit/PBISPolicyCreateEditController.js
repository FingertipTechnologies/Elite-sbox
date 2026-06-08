({
    // Saved: open the record detail page.
    handleDone: function (component, event) {
        var recordId = event.getParam('recordId');
        if (recordId) {
            var navEvt = $A.get('e.force:navigateToSObject');
            navEvt.setParams({ recordId: recordId, slideDevName: 'detail' });
            navEvt.fire();
        } else {
            $A.get('e.force:navigateToList').fire();
        }
    },

    // Cancelled: back to the record (edit) or the object home (new).
    handleClose: function (component) {
        var recordId = component.get('v.recordId');
        if (recordId) {
            var navEvt = $A.get('e.force:navigateToSObject');
            navEvt.setParams({ recordId: recordId, slideDevName: 'detail' });
            navEvt.fire();
        } else {
            var homeEvt = $A.get('e.force:navigateToObjectHome');
            homeEvt.setParams({ scope: component.get('v.sObjectName') || 'PBIS_Policy__c' });
            homeEvt.fire();
        }
    }
})