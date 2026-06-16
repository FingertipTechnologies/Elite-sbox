public without sharing class RunningSchemeController {

    // Returns the schemes "running" for the logged-in partner/community user's account,
    // selected by Sales Channel + the chosen month/date range + geo applicability
    // (region/area/territory/outlet) resolved from the account's Product_Mapping rows.
    // Reuses the order-screen Schemes-tab model (beatPlannerlwc.CoverageScheme + slab sentences).
    @AuraEnabled
    public static List<beatPlannerlwc.CoverageScheme> getRunningSchemes(String dateFilter, String fromDate, String toDate) {
        List<beatPlannerlwc.CoverageScheme> out = new List<beatPlannerlwc.CoverageScheme>();

        // ---- Date range (Current / Previous / Custom; default = current month) ----
        Date startRange;
        Date endRange;
        Date today = Date.today();
        Integer currentYear  = today.year();
        Integer currentMonth = today.month();
        if (dateFilter == 'current') {
            startRange = Date.newInstance(currentYear, currentMonth, 1);
            endRange   = startRange.addMonths(1).addDays(-1);
        } else if (dateFilter == 'previous') {
            Date firstOfCurrent = Date.newInstance(currentYear, currentMonth, 1);
            startRange = firstOfCurrent.addMonths(-1);
            endRange   = firstOfCurrent.addDays(-1);
        } else if (dateFilter == 'custom' && fromDate != null && toDate != null) {
            startRange = Date.valueOf(fromDate);
            endRange   = Date.valueOf(toDate);
        } else {
            startRange = Date.newInstance(currentYear, currentMonth, 1);
            endRange   = startRange.addMonths(1).addDays(-1);
        }

        // ---- Resolve the partner/community user's account ----
        Id accountId;
        List<User> partnerUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        if (!partnerUser.isEmpty() && partnerUser[0].ContactId != null) {
            List<Contact> cons = [SELECT AccountId FROM Contact WHERE Id = :partnerUser[0].ContactId LIMIT 1];
            if (!cons.isEmpty()) accountId = cons[0].AccountId;
        }
        if (accountId == null) return out;

        List<Account> accList = [
            SELECT Id, Sales_Channel__c, Secondary_Customer_Category__c
            FROM Account WHERE Id = :accountId LIMIT 1
        ];
        if (accList.isEmpty()) return out;
        Account acc = accList[0];

        // Channels (picklist values like 'CPD' — keep original case, just trim)
        Set<String> channelSet = new Set<String>();
        if (String.isNotBlank(acc.Sales_Channel__c)) {
            for (String ch : acc.Sales_Channel__c.split(',')) {
                if (String.isNotBlank(ch)) channelSet.add(ch.trim());
            }
        }
        if (channelSet.isEmpty()) return out;

        // ---- Geo from the account's own Product_Mapping rows ----
        Set<String> regions = new Set<String>();
        Set<String> areas = new Set<String>();
        Set<String> territoryIds = new Set<String>();
        List<Product_Mapping__c> mappings = [
            SELECT Area__c, Area_Area_Name__c, Region_Name__c
            FROM Product_Mapping__c WHERE Primary_Customer__c = :accountId
        ];
        if (mappings.isEmpty()) return out;   // no mapping -> no schemes
        for (Product_Mapping__c pm : mappings) {
            if (String.isNotBlank(pm.Region_Name__c))    regions.add(pm.Region_Name__c);
            if (String.isNotBlank(pm.Area_Area_Name__c)) areas.add(pm.Area_Area_Name__c);
            if (pm.Area__c != null)                      territoryIds.add(String.valueOf(pm.Area__c));
        }

        // ---- Candidate active schemes overlapping the range for these channels ----
        List<Scheme__c> candidates = [
            SELECT Id, Name, Scheme_Type__c, Sales_Channel__c,
            Scheme_Start_Date__c, Scheme_End_Date__c,
            Scheme_Product_Group__c, Scheme_Product_Group__r.Name,
            Scheme_Product_Category__c,
            Apply_to_All_Regions__c, Apply_to_All_Areas__c,
            Apply_to_All_Territories__c, Apply_to_All_Outlet_Categories__c
            FROM Scheme__c
            WHERE IsActive__c = true
            AND Scheme_Start_Date__c <= :endRange
            AND Scheme_End_Date__c   >= :startRange
            AND Sales_Channel__c IN :channelSet
        ];
        if (candidates.isEmpty()) return out;

        Set<Id> schemeIds = new Set<Id>();
        for (Scheme__c s : candidates) schemeIds.add(s.Id);

        // ---- Applicability rows ----
        Map<Id, Map<String, Set<String>>> appByScheme = new Map<Id, Map<String, Set<String>>>();
        for (Scheme_Applicability__c r : [
            SELECT Scheme__c, Level__c, Value_Text__c, Value_Lookup__c
            FROM Scheme_Applicability__c WHERE Scheme__c IN :schemeIds
        ]) {
            if (!appByScheme.containsKey(r.Scheme__c)) appByScheme.put(r.Scheme__c, new Map<String, Set<String>>());
            Map<String, Set<String>> lvls = appByScheme.get(r.Scheme__c);
            if (!lvls.containsKey(r.Level__c)) lvls.put(r.Level__c, new Set<String>());
            String v = (r.Value_Lookup__c != null) ? String.valueOf(r.Value_Lookup__c) : r.Value_Text__c;
            if (v != null) lvls.get(r.Level__c).add(v);
        }

        // ---- Match by region / area / territory / outlet category ----
        List<Scheme__c> matched = new List<Scheme__c>();
        Set<Id> matchedGroupIds = new Set<Id>();
        for (Scheme__c s : candidates) {
            if (s.Scheme_Product_Group__c == null && String.isBlank(s.Scheme_Product_Category__c) && s.Scheme_Type__c != 'Order Value') continue;
            Map<String, Set<String>> lvls = appByScheme.containsKey(s.Id) ? appByScheme.get(s.Id) : new Map<String, Set<String>>();
            Boolean regionOk    = s.Apply_to_All_Regions__c == true     || (lvls.containsKey('Region')    && beatPlannerlwc.anyMatch(lvls.get('Region'),    regions));
            Boolean areaOk      = s.Apply_to_All_Areas__c == true       || (lvls.containsKey('Area')      && beatPlannerlwc.anyMatch(lvls.get('Area'),      areas));
            Boolean territoryOk = s.Apply_to_All_Territories__c == true || (lvls.containsKey('Territory') && beatPlannerlwc.anyMatch(lvls.get('Territory'), territoryIds));
            Boolean outletOk    = s.Apply_to_All_Outlet_Categories__c == true
                || acc.Secondary_Customer_Category__c == null
                || (lvls.containsKey('Outlet Category') && lvls.get('Outlet Category').contains(acc.Secondary_Customer_Category__c));
            if (regionOk && areaOk && territoryOk && outletOk) {
                matched.add(s);
                if (s.Scheme_Product_Group__c != null) matchedGroupIds.add(s.Scheme_Product_Group__c);
            }
        }
        if (matched.isEmpty()) return out;

        // ---- Group products ----
        Map<Id, List<beatPlannerlwc.CoverageProductRef>> productsByGroup = new Map<Id, List<beatPlannerlwc.CoverageProductRef>>();
        for (Scheme_Product_Group_Item__c it : [
            SELECT Scheme_Product_Group__c, Product__c, Product__r.Name, Product__r.SKU_Code__c
            FROM Scheme_Product_Group_Item__c WHERE Scheme_Product_Group__c IN :matchedGroupIds
            ORDER BY Product__r.Name
        ]) {
            if (it.Product__c == null) continue;
            if (!productsByGroup.containsKey(it.Scheme_Product_Group__c)) productsByGroup.put(it.Scheme_Product_Group__c, new List<beatPlannerlwc.CoverageProductRef>());
            beatPlannerlwc.CoverageProductRef p = new beatPlannerlwc.CoverageProductRef();
            p.id   = it.Product__c;
            p.name = it.Product__r.Name;
            p.sku  = it.Product__r.SKU_Code__c;
            productsByGroup.get(it.Scheme_Product_Group__c).add(p);
        }

        // ---- Slabs ----
        Set<Id> matchedSchemeIds = new Set<Id>();
        for (Scheme__c m : matched) matchedSchemeIds.add(m.Id);
        Map<Id, List<Scheme_Slab__c>> slabsByScheme = new Map<Id, List<Scheme_Slab__c>>();
        for (Scheme_Slab__c sl : [
            SELECT Id, Scheme__c, Slab_Sequence__c, Slab_Type__c,
            Qualifying_Qty_Min__c, Qualifying_Qty_Max__c,
            Qualifying_Value_Min__c, Qualifying_Value_Max__c,
            Free_Qty__c, Benefit_Amount_Per_EA__c, Benefit_Percent__c,
            FOC_Product__c, FOC_Product__r.Name
            FROM Scheme_Slab__c WHERE Scheme__c IN :matchedSchemeIds
            ORDER BY Slab_Sequence__c ASC NULLS LAST, CreatedDate ASC
        ]) {
            if (!slabsByScheme.containsKey(sl.Scheme__c)) slabsByScheme.put(sl.Scheme__c, new List<Scheme_Slab__c>());
            slabsByScheme.get(sl.Scheme__c).add(sl);
        }

        // ---- Build CoverageScheme cards (same shape/sentences as the order Schemes tab) ----
        for (Scheme__c s : matched) {
            beatPlannerlwc.CoverageScheme cs = new beatPlannerlwc.CoverageScheme();
            cs.id               = s.Id;
            cs.name             = s.Name;
            cs.schemeType       = s.Scheme_Type__c;
            cs.salesChannel     = s.Sales_Channel__c;
            cs.startDate        = s.Scheme_Start_Date__c;
            cs.endDate          = s.Scheme_End_Date__c;
            cs.validLabel       = beatPlannerlwc.formatDdMmYyyy(s.Scheme_Start_Date__c) + ' to ' + beatPlannerlwc.formatDdMmYyyy(s.Scheme_End_Date__c);
            cs.productGroupId   = s.Scheme_Product_Group__c;
            cs.productGroupName = s.Scheme_Product_Group__r == null ? null : s.Scheme_Product_Group__r.Name;
            cs.productCategory  = s.Scheme_Product_Category__c;
            cs.products         = productsByGroup.containsKey(s.Scheme_Product_Group__c)
                ? productsByGroup.get(s.Scheme_Product_Group__c)
                : new List<beatPlannerlwc.CoverageProductRef>();
            cs.slabRows         = beatPlannerlwc.buildSlabRows(s.Scheme_Type__c, slabsByScheme.get(s.Id));
            out.add(cs);
        }
        return out;
    }
}
