({
    doInit: function (component) {
        component.set("v.openPopup", true);
    },
    // Each navigation to this override (e.g. clicking New again after a save) updates the
    // page reference. Tear the form down and rebuild it so it always starts empty — a reused
    // override instance otherwise keeps the previously entered/saved values.
    onNavigate: function (component) {
        // Only rebuild when the form is already open (a genuine re-navigation such as a
        // second New); the first open is handled by doInit.
        if (component.get("v.openPopup")) {
            component.set("v.openPopup", false);
            window.setTimeout(
                $A.getCallback(function () {
                    component.set("v.openPopup", true);
                }),
                0
            );
        }
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