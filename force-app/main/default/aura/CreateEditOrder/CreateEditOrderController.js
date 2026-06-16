({
    doInit : function(component, event, helper) {
        const recordId = component.get('v.recordId');
        const heading = recordId != undefined ? 'Edit Order' : 'New Order';
        component.set('v.heading',heading);
        component.set('v.isOrderTrue',true);
    },
    onClickAction:function(component, event, helper) {
        var msg = event.getParam("message");
        if(msg == 'close' || msg == 'Done'){
            // Navigate to the Order Today list view via force:navigateToList (loads the
            // list fresh). A null Id falls back to the default list rather than hanging.
            // Do NOT fire force:refreshView — racing the navigation leaves the list view
            // stuck loading until a manual browser refresh.
            var navList = $A.get("e.force:navigateToList");
            navList.setParams({
                listViewId: event.getParam("id") || null,
                listViewName: null,
                scope: "Order__c"
            });
            navList.fire();
        }
    },
    onPageReferenceChange: function(component, event, helper) {
        var detail = {};
        detail["isPullToRefreshEnabled"] = false;
        detail["isPullToShowMoreEnabled"] = false;
        var updateScrollSettingsEvent = new CustomEvent("updateScrollSettings", {
            detail: detail,
            bubbles: true,
            composed: true
        });
        dispatchEvent(updateScrollSettingsEvent);
        // Force refresh the page
       // $A.get('e.force:refreshView').fire();
    }
})