({
    doInit: function (component) {
        var recordId = component.get('v.recordId');
        $A.createComponent(
            'c:pbisPolicyBuilder',
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
                        cssClass: 'pbp-overlay-modal slds-modal_large'
                    }).then(function (overlay) {
                        component.set('v.overlay', overlay);
                    });
                }
            }
        );
    },

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
            homeEvt.setParams({ scope: component.get('v.sObjectName') || 'PBIS_Policy__c' });
            homeEvt.fire();
        }
    }
})
