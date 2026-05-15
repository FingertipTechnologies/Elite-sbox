({
    doInit: function (component) {
        component.set("v.openPopup", true);
    },
    onSaved: function (component, event) {
        var recordId = event.getParam('recordId');
        var navEvt = $A.get("e.force:navigateToSObject");
        if (navEvt && recordId) {
            navEvt.setParams({ "recordId": recordId, "slideDevName": "detail" });
            navEvt.fire();
        }
    },
    onCancel: function () {
        var urlEvent = $A.get("e.force:navigateToURL");
        urlEvent.setParams({ "url": "/lightning/o/Focused_Pack__c/list" });
        urlEvent.fire();
    }
})