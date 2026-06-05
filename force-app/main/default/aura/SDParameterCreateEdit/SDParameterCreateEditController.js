({
    // Build the LWC and show it inside a real overlay modal (floats over the app,
    // dark backdrop, escapes the action-override page container).
    doInit: function (component) {
        var recordId = component.get('v.recordId');
        $A.createComponent(
            'c:sdParameterBuilder',
            {
                recordId: recordId,
                ondone: component.getReference('c.handleDone'),
                onclose: component.getReference('c.handleClose')
            },
            function (content, status) {
                if (status === 'SUCCESS') {
                    component.find('overlayLib').showCustomModal({
                        body: content,
                        showCloseButton: false,
                        cssClass: 'sdp-overlay-modal slds-modal_medium'
                    }).then(function (overlay) {
                        component.set('v.overlay', overlay);
                    });
                }
            }
        );
    },

    // Saved: close the modal and open the record detail.
    handleDone: function (component, event) {
        var recordId = event.getParam('recordId');
        var overlay = component.get('v.overlay');
        if (overlay) overlay.close();
        if (recordId) {
            var navEvt = $A.get('e.force:navigateToSObject');
            navEvt.setParams({ recordId: recordId, slideDevName: 'detail' });
            navEvt.fire();
        } else {
            $A.get('e.force:navigateToList').fire();
        }
    },

    // Cancelled / closed: close the modal and go back to the record or object home.
    handleClose: function (component) {
        var overlay = component.get('v.overlay');
        if (overlay) overlay.close();
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