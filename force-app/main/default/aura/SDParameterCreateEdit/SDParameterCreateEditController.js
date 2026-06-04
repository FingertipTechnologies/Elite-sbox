({
    doInit: function (component) {
        component.set('v.ready', true);
    },

    // On save the LWC fires 'done' with the saved record Id; navigate to its detail page.
    handleDone: function (component, event) {
        var recordId = event.getParam('recordId');
        if (recordId) {
            var navEvt = $A.get('e.force:navigateToSObject');
            navEvt.setParams({ recordId: recordId, slideDevName: 'detail' });
            navEvt.fire();
            window.setTimeout(function () {
                $A.get('e.force:refreshView').fire();
            }, 800);
        } else {
            $A.get('e.force:navigateToList').fire();
        }
    },

    // Cancel: go back to the record (edit) or the object home (new).
    handleClose: function (component) {
        var recordId = component.get('v.recordId');
        if (recordId) {
            var navEvt = $A.get('e.force:navigateToSObject');
            navEvt.setParams({ recordId: recordId, slideDevName: 'detail' });
            navEvt.fire();
        } else {
            var homeEvt = $A.get('e.force:navigateToObjectHome');
            homeEvt.setParams({ scope: component.get('v.sObjectName') || 'S_D_Parameter__c' });
            homeEvt.fire();
        }
    }
})
