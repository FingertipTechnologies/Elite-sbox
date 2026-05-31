({
    doInit : function(component, event, helper) {
        const recordId = component.get('v.recordId');
        const heading = recordId != undefined ? 'Edit Scheme' : 'New Scheme';
        
        component.set('v.heading',heading);
        component.set('v.isSchemeTrue',true);
    },
    onClickAction:function(component, event, helper) {
        var msg = event.getParam("message");
        if(msg == 'close'){
            let recordId = component.get('v.recordId');
            let navEvt = recordId ?
                $A.get("e.force:navigateToSObject") :
            $A.get("e.force:navigateToList");

            navEvt.setParams(recordId ? {
                "recordId": recordId,
                "slideDevName": "related"
            } : {
                "listViewId": event.getParam("id"),
                "listViewName": null,
                "scope": "Scheme__c"
            });

            navEvt.fire();
        }
        else if(msg == 'Done'){
            let recordId = event.getParam("id");
            let navEvt = $A.get("e.force:navigateToSObject");
            navEvt.setParams({
                "recordId": recordId,
                "slideDevName": "related"
            });
            navEvt.fire();
        }
    },
    onWizardComplete:function(component, event, helper) {
        const savedId = event.getParam('recordId');
        if (savedId) {
            const navEvt = $A.get("e.force:navigateToSObject");
            navEvt.setParams({
                "recordId": savedId,
                "slideDevName": "related"
            });
            navEvt.fire();
        }
    },
    onWizardCancel:function(component, event, helper) {
        const recordId = component.get('v.recordId');
        if (recordId) {
            const navEvt = $A.get("e.force:navigateToSObject");
            navEvt.setParams({
                "recordId": recordId,
                "slideDevName": "related"
            });
            navEvt.fire();
        } else {
            const navEvt = $A.get("e.force:navigateToList");
            navEvt.setParams({
                "listViewId": null,
                "listViewName": null,
                "scope": "Scheme__c"
            });
            navEvt.fire();
        }
    }
})