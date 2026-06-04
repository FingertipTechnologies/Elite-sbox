/*
 * Seed the 15 S&D Parameters from the "S & D Parameters list" (Primary PBIS, Task 1).
 * Idempotent on Name + Sales Channel: existing rows are updated, not duplicated.
 * Run:  sf apex run -f scripts/apex/seed_sd_parameters.apex -o <org>
 *
 * Resilient by design:
 *  - Sales Channel is only set when the value exists in the Chanel global value set
 *    (so the seed never fails on a channel that hasn't been added yet).
 *  - Focused Pack is linked by Name when a matching Focused_Pack__c exists, else left null.
 */

// --- valid Sales Channel values (restricted Chanel GVS) ---
Set<String> validChannels = new Set<String>();
for (Schema.PicklistEntry e : S_D_Parameter__c.Sales_Channel__c.getDescribe().getPicklistValues()) {
    if (e.isActive()) validChannels.add(e.getValue());
}

// --- existing Focused Packs by (lower) name for linking ---
Map<String, Id> packByName = new Map<String, Id>();
for (Focused_Pack__c fp : [SELECT Id, Name FROM Focused_Pack__c]) {
    if (fp.Name != null) packByName.put(fp.Name.toLowerCase(), fp.Id);
}

// --- catalog: channel, name, operator, focusPackName(optional) ---
List<List<String>> catalog = new List<List<String>>{
    new List<String>{ 'Bulk Depot',    'Total Volume Achievement',  'SUM',                null },
    new List<String>{ 'Bulk Depot',    'Focus Pack 1',              'FOCUS_PACK_VOLUME',  'Apple Brand' },
    new List<String>{ 'Bulk Depot',    'Focus Pack 2',              'FOCUS_PACK_VOLUME',  'Yamuna Brand' },
    new List<String>{ 'Bulk Depot',    'New Primary Customer addition', 'COUNT',          null },
    new List<String>{ 'District Bulk', 'Total Volume Achievement',  'SUM',                null },
    new List<String>{ 'District Bulk', 'Focus Pack 1',              'FOCUS_PACK_VOLUME',  'Apple Brand' },
    new List<String>{ 'District Bulk', 'Focus Pack 2',              'FOCUS_PACK_VOLUME',  'Yamuna Brand' },
    new List<String>{ 'CPD',           'Total Revenue Achievement', 'SUM',                null },
    new List<String>{ 'CPD',           'Focus Pack 1',              'FOCUS_PACK_REVENUE', 'Chakki atta' },
    new List<String>{ 'CPD',           'Focus Pack 2',              'FOCUS_PACK_REVENUE', 'Puttupodi' },
    new List<String>{ 'CPD',           'New Outlet Addition',       'COUNT',              null },
    new List<String>{ 'Bread',         'Total Revenue Achievement', 'SUM',                null },
    new List<String>{ 'Bread',         'Focus Pack 1',              'FOCUS_PACK_REVENUE', 'Bun roll' },
    new List<String>{ 'Bread',         'Focus Pack 2',              'FOCUS_PACK_REVENUE', 'Cup cake and Bar cake' },
    new List<String>{ 'Bread',         'New Outlet Addition',       'COUNT',              null }
};

// --- index existing records by name|channel for idempotency ---
Map<String, S_D_Parameter__c> existing = new Map<String, S_D_Parameter__c>();
for (S_D_Parameter__c p : [
    SELECT Id, Name, Sales_Channel__c, Operator__c, Focused_Pack__c
    FROM S_D_Parameter__c
]) {
    existing.put((p.Name + '|' + p.Sales_Channel__c).toLowerCase(), p);
}

List<S_D_Parameter__c> toUpsert = new List<S_D_Parameter__c>();
for (List<String> row : catalog) {
    String channel  = row[0];
    String pname    = row[1];
    String op       = row[2];
    String packName = row[3];

    String channelValue = validChannels.contains(channel) ? channel : null;
    String key = (pname + '|' + channelValue).toLowerCase();

    S_D_Parameter__c rec = existing.containsKey(key) ? existing.get(key) : new S_D_Parameter__c();
    rec.Name = pname;
    rec.Sales_Channel__c = channelValue;
    rec.Operator__c = op;
    rec.Is_Active__c = true;

    if (op == 'FOCUS_PACK_VOLUME' || op == 'FOCUS_PACK_REVENUE') {
        rec.Focused_Pack__c = (packName != null && packByName.containsKey(packName.toLowerCase()))
            ? packByName.get(packName.toLowerCase()) : null;
    } else {
        // Aggregate parameters: source object + user field; Field__c set by admin in setup.
        rec.User_Field__c = 'OwnerId';
    }
    toUpsert.add(rec);
}

upsert toUpsert;
System.debug('Seeded S&D Parameters: ' + toUpsert.size());
System.debug('Channels applied (present in Chanel GVS): ' + validChannels);
