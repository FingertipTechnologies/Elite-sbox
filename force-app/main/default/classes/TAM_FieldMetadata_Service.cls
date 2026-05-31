public with sharing class TAM_FieldMetadata_Service {

    @AuraEnabled(cacheable=true)
    public static List<FieldInfo> getFields(String objectName) {

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(objectName)) return new List<FieldInfo>();

        Schema.DescribeSObjectResult objDesc = gd.get(objectName).getDescribe();
        Map<String, Schema.SObjectField> fields = objDesc.fields.getMap();

        List<FieldInfo> results = new List<FieldInfo>();

        for (String name : fields.keySet()) {
            Schema.DescribeFieldResult fd = fields.get(name).getDescribe();

            FieldInfo info = new FieldInfo();
            info.apiName = fd.getName();
            info.label = fd.getLabel();
            info.type = getFieldType(fd);

            // Picklist
            if (fd.getType() == Schema.DisplayType.Picklist ||
                fd.getType() == Schema.DisplayType.MultiPicklist)
            {
                info.picklistValues = new List<String>();
                for (Schema.PicklistEntry p : fd.getPicklistValues()) {
                    info.picklistValues.add(p.getValue());
                }
            }

            // ONLY TRUE USER LOOKUPS
            if (fd.getType() == Schema.DisplayType.Reference) {
                List<Schema.SObjectType> refTo = fd.getReferenceTo();
                for (Schema.SObjectType r : refTo) {
                    if (r != null && r.getDescribe().getName().equalsIgnoreCase('User')) {
                        info.isUserField = true;
                    }
                }
            }

            results.add(info);
        }

        // Add parent-relationship fields (e.g. Order__r.Account__c) so admins can
        // pick fields that live on the parent record without typing dot paths.
        Set<String> commonFieldsLower = new Set<String>{
            'name', 'email', 'phone', 'title', 'department', 'city', 'state', 'country'
        };
        for (String name : fields.keySet()) {
            Schema.DescribeFieldResult fd = fields.get(name).getDescribe();
            if (fd.getType() != Schema.DisplayType.Reference) continue;

            List<Schema.SObjectType> refs = fd.getReferenceTo();
            if (refs.isEmpty()) continue;

            Schema.DescribeSObjectResult parentDesc = refs[0].getDescribe();
            String relationName = fd.getRelationshipName();
            if (String.isBlank(relationName)) continue;

            Map<String, Schema.SObjectField> parentFields = parentDesc.fields.getMap();
            for (String pname : parentFields.keySet()) {
                Schema.DescribeFieldResult pfd = parentFields.get(pname).getDescribe();
                Schema.DisplayType pt = pfd.getType();
                Boolean include = commonFieldsLower.contains(pname.toLowerCase())
                    || pt == Schema.DisplayType.Reference
                    || pt == Schema.DisplayType.Picklist
                    || pt == Schema.DisplayType.MultiPicklist
                    || pt == Schema.DisplayType.Date
                    || pt == Schema.DisplayType.DateTime;
                if (!include) continue;

                FieldInfo info = new FieldInfo();
                info.apiName = relationName + '.' + pfd.getName();
                info.label = parentDesc.getLabel() + ' > ' + pfd.getLabel();
                info.type = getFieldType(pfd);
                info.isUserField = false;

                if (pt == Schema.DisplayType.Picklist || pt == Schema.DisplayType.MultiPicklist) {
                    info.picklistValues = new List<String>();
                    for (Schema.PicklistEntry p : pfd.getPicklistValues()) {
                        info.picklistValues.add(p.getValue());
                    }
                }
                if (pt == Schema.DisplayType.Reference) {
                    for (Schema.SObjectType r : pfd.getReferenceTo()) {
                        if (r != null && r.getDescribe().getName().equalsIgnoreCase('User')) {
                            info.isUserField = true;
                        }
                    }
                }
                results.add(info);
            }
        }

        results.sort();
        return results;
    }

    private static String getFieldType(Schema.DescribeFieldResult fd) {
        Schema.DisplayType t = fd.getType();

        if (t == Schema.DisplayType.String || t == Schema.DisplayType.TextArea) return 'String';
        if (t == Schema.DisplayType.Integer || t == Schema.DisplayType.Long ||
            t == Schema.DisplayType.Double || t == Schema.DisplayType.Percent) return 'Number';
        if (t == Schema.DisplayType.Currency) return 'Currency';
        if (t == Schema.DisplayType.Date) return 'Date';
        if (t == Schema.DisplayType.DateTime) return 'DateTime';
        if (t == Schema.DisplayType.Boolean) return 'Boolean';
        if (t == Schema.DisplayType.Picklist) return 'Picklist';
        if (t == Schema.DisplayType.MultiPicklist) return 'MultiPicklist';
        if (t == Schema.DisplayType.Reference) return 'Reference';

        return 'String'; // fallback
    }

    public class FieldInfo implements Comparable {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean isUserField;
        @AuraEnabled public List<String> picklistValues;

        public Integer compareTo(Object o) {
            FieldInfo other = (FieldInfo)o;
            return String.valueOf(label).toLowerCase().compareTo(
                   String.valueOf(other.label).toLowerCase());
        }
    }
}