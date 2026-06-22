/**
 * Test coverage for TAM_TargetCriteria_Controller — the criteria CRUD
 * surface used by the tamCriteriaBuilder LWC and the CSV import flow.
 *
 * Covers all 13 @AuraEnabled methods: object/field discovery, list and
 * single-record fetch, save (with duplicate-name guard), prerequisite
 * options, linked-target counting, single + bulk delete (with cascade
 * to Target_Actual__c), single + bulk active toggle, clone, and the
 * preview pipeline.
 */
@isTest
public class TAM_TargetCriteria_ControllerTest {

    private static Target_Criteria__c makeCriteria(String name) {
        // Account-based criterion so the preview pipeline runs against a safe,
        // always-present standard object regardless of org-specific custom data.
        return new Target_Criteria__c(
            Name = name,
            Object__c = 'Account',
            Operator__c = 'COUNT',
            Date_Field__c = 'CreatedDate',
            User_Field__c = 'OwnerId',
            Active__c = true
        );
    }

    @TestSetup
    static void setup() {
        // Two criteria — one to be cloned / queried, one to round out the list view.
        Target_Criteria__c a = makeCriteria('TAM Test Revenue');
        Target_Criteria__c b = makeCriteria('TAM Test Calls');
        insert new List<Target_Criteria__c>{ a, b };

        // A linked Target_Actual__c so the cascade path is exercised on delete.
        insert new Target_Actual__c(
            Target_Criteria__c = a.Id,
            Target_Value__c = 100
        );
    }

    // ----- Object / field discovery -----

    @isTest
    static void getAllObjectsExcludesSystemNoise() {
        Test.startTest();
        List<Map<String, String>> objs = TAM_TargetCriteria_Controller.getAllObjects();
        Test.stopTest();

        System.assertNotEquals(null, objs);
        System.assert(!objs.isEmpty(), 'should return at least one queryable object');

        Boolean sawAccount = false;
        for (Map<String, String> r : objs) {
            String api = r.get('api');
            sawAccount = sawAccount || api == 'Account';
            String lower = api.toLowerCase();
            System.assert(
                !lower.endsWith('history') && !lower.endsWith('feed')
                    && !lower.endsWith('share') && !lower.contains('changeevent'),
                'system noise ' + api + ' should be filtered out'
            );
        }
        System.assert(sawAccount, 'Account should be present in the list');
    }

    @isTest
    static void getFieldCategoriesBucketsCorrectly() {
        Test.startTest();
        Map<String, List<String>> cats =
            TAM_TargetCriteria_Controller.getFieldCategories('Account');
        Test.stopTest();

        System.assert(cats.containsKey('numberFields'));
        System.assert(cats.containsKey('dateFields'));
        System.assert(cats.containsKey('userFields'));
        System.assert(cats.containsKey('allFields'));

        // Schema.fields.getMap() returns lowercased keys, so the buckets carry
        // 'createddate' / 'ownerid' rather than the camel-case API names.
        System.assert(containsIgnoreCase(cats.get('dateFields'), 'CreatedDate'),
            'CreatedDate should be classified as a date field; got ' + cats.get('dateFields'));
        System.assert(containsIgnoreCase(cats.get('userFields'), 'OwnerId'),
            'OwnerId should be classified as a User field; got ' + cats.get('userFields'));
    }

    private static Boolean containsIgnoreCase(List<String> haystack, String needle) {
        if (haystack == null || needle == null) return false;
        String n = needle.toLowerCase();
        for (String s : haystack) {
            if (s != null && s.toLowerCase() == n) return true;
        }
        return false;
    }

    // ----- List + single fetch -----

    @isTest
    static void getAllCriteriaReturnsSeededRecords() {
        Test.startTest();
        List<Target_Criteria__c> all = TAM_TargetCriteria_Controller.getAllCriteria();
        Test.stopTest();
        System.assert(all.size() >= 2, 'two seeded records expected');
    }

    @isTest
    static void getCriteriaReturnsFullFieldSet() {
        Target_Criteria__c seed = [SELECT Id FROM Target_Criteria__c WHERE Name = 'TAM Test Revenue' LIMIT 1];
        Test.startTest();
        Target_Criteria__c got = TAM_TargetCriteria_Controller.getCriteria(seed.Id);
        Test.stopTest();
        System.assertEquals(seed.Id, got.Id);
        System.assertEquals('Account', got.Object__c);
        System.assertEquals('COUNT', got.Operator__c);
    }

    // ----- Save (insert, update, duplicate guard) -----

    @isTest
    static void saveCriteriaInsertsNewRecord() {
        Target_Criteria__c fresh = makeCriteria('TAM Brand-New');
        Test.startTest();
        Target_Criteria__c saved = TAM_TargetCriteria_Controller.saveCriteria(fresh);
        Test.stopTest();
        System.assertNotEquals(null, saved.Id, 'insert should assign an Id');
        System.assertEquals('TAM Brand-New', saved.Name);
    }

    @isTest
    static void saveCriteriaUpdatesExisting() {
        Target_Criteria__c seed = [SELECT Id, Name, Active__c FROM Target_Criteria__c WHERE Name = 'TAM Test Calls' LIMIT 1];
        seed.Active__c = false;
        Test.startTest();
        Target_Criteria__c saved = TAM_TargetCriteria_Controller.saveCriteria(seed);
        Test.stopTest();
        System.assertEquals(false, saved.Active__c, 'update should persist Active=false');
    }

    @isTest
    static void saveCriteriaRejectsDuplicateName() {
        Target_Criteria__c clash = makeCriteria('TAM Test Revenue'); // matches an existing record
        Boolean threw = false;
        Test.startTest();
        try {
            TAM_TargetCriteria_Controller.saveCriteria(clash);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'duplicate-name save should throw AuraHandledException');
    }

    @isTest
    static void saveCriteriaAllowsSameNameForSameRecord() {
        // Renaming a record to its own name (i.e. saving without renaming) must not
        // collide with the duplicate guard.
        Target_Criteria__c seed = [SELECT Id, Name FROM Target_Criteria__c WHERE Name = 'TAM Test Revenue' LIMIT 1];
        Test.startTest();
        Target_Criteria__c saved = TAM_TargetCriteria_Controller.saveCriteria(seed);
        Test.stopTest();
        System.assertEquals('TAM Test Revenue', saved.Name);
    }

    // ----- Prerequisite dropdown / linked counts -----

    @isTest
    static void getCriteriaOptionsIncludesNoneSentinel() {
        Test.startTest();
        List<Map<String, String>> opts = TAM_TargetCriteria_Controller.getCriteriaOptions();
        Test.stopTest();
        System.assert(opts.size() >= 3, 'sentinel + two active records');
        System.assertEquals('', opts[0].get('value'), 'first entry should be the None sentinel');
    }

    @isTest
    static void getLinkedTargetCountReflectsCascade() {
        Target_Criteria__c seed = [SELECT Id FROM Target_Criteria__c WHERE Name = 'TAM Test Revenue' LIMIT 1];
        Test.startTest();
        Integer count = TAM_TargetCriteria_Controller.getLinkedTargetCount(seed.Id);
        Test.stopTest();
        System.assertEquals(1, count, 'one linked Target_Actual__c was seeded');
    }

    // ----- Delete (single + bulk) -----

    @isTest
    static void deleteCriteriaCascadesLinkedActuals() {
        Target_Criteria__c seed = [SELECT Id FROM Target_Criteria__c WHERE Name = 'TAM Test Revenue' LIMIT 1];
        Test.startTest();
        TAM_TargetCriteria_Controller.deleteCriteria(seed.Id);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Target_Criteria__c WHERE Id = :seed.Id]);
        System.assertEquals(0, [SELECT COUNT() FROM Target_Actual__c WHERE Target_Criteria__c = :seed.Id]);
    }

    @isTest
    static void bulkDeleteCascadesLinkedActuals() {
        Map<Id, Target_Criteria__c> all = new Map<Id, Target_Criteria__c>(
            [SELECT Id FROM Target_Criteria__c]
        );
        Test.startTest();
        TAM_TargetCriteria_Controller.bulkDelete(new List<Id>(all.keySet()));
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Target_Criteria__c]);
        System.assertEquals(0, [SELECT COUNT() FROM Target_Actual__c]);
    }

    // ----- Active toggle (single + bulk) -----

    @isTest
    static void toggleActiveFlipsTheFlag() {
        Target_Criteria__c seed = [SELECT Id, Active__c FROM Target_Criteria__c LIMIT 1];
        Test.startTest();
        TAM_TargetCriteria_Controller.toggleActive(seed.Id, false);
        Test.stopTest();
        Target_Criteria__c after = [SELECT Active__c FROM Target_Criteria__c WHERE Id = :seed.Id];
        System.assertEquals(false, after.Active__c);
    }

    @isTest
    static void bulkToggleActiveAppliesToWholeList() {
        Map<Id, Target_Criteria__c> all = new Map<Id, Target_Criteria__c>(
            [SELECT Id FROM Target_Criteria__c]
        );
        Test.startTest();
        TAM_TargetCriteria_Controller.bulkToggleActive(new List<Id>(all.keySet()), false);
        Test.stopTest();
        for (Target_Criteria__c c : [SELECT Active__c FROM Target_Criteria__c]) {
            System.assertEquals(false, c.Active__c, 'every record should be deactivated');
        }
    }

    // ----- Clone -----

    @isTest
    static void cloneCriteriaSuffixesNameAndDeactivates() {
        Target_Criteria__c seed = [SELECT Id, Name FROM Target_Criteria__c WHERE Name = 'TAM Test Revenue' LIMIT 1];
        Test.startTest();
        Target_Criteria__c cloned = TAM_TargetCriteria_Controller.cloneCriteria(seed.Id);
        Test.stopTest();
        System.assertNotEquals(seed.Id, cloned.Id, 'clone gets a new Id');
        System.assertEquals('TAM Test Revenue (Copy)', cloned.Name);
        System.assertEquals(false, cloned.Active__c, 'clones land deactivated for review');
    }

    // ----- Preview pipeline -----

    @isTest
    static void previewCriteriaRunsAndReportsStructure() {
        Target_Criteria__c seed = [SELECT Id FROM Target_Criteria__c WHERE Name = 'TAM Test Revenue' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = TAM_TargetCriteria_Controller.previewCriteria(seed.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('operator'), 'should report the operator');
        System.assert(result.containsKey('period'), 'should report the period');
        System.assert(result.containsKey('success'), 'should report success/failure');
        System.assertEquals('COUNT', (String) result.get('operator'));
    }

    @isTest
    static void previewCriteriaShortCircuitsFocusPackOperators() {
        // Focus-Pack operators can't be previewed from the criteria alone — the
        // controller should return success=true with a note instead of running the engine.
        Target_Criteria__c fp = new Target_Criteria__c(
            Name = 'TAM Test FP ECO',
            Object__c = 'Order_Item__c',
            Operator__c = 'FOCUS_PACK_ECO',
            Active__c = true
        );
        insert fp;

        Test.startTest();
        Map<String, Object> result = TAM_TargetCriteria_Controller.previewCriteria(fp.Id);
        Test.stopTest();

        System.assertEquals(true, (Boolean) result.get('success'));
        System.assertEquals(0, (Integer) result.get('rowCount'));
        System.assert(result.containsKey('note'), 'focus pack short-circuit should include a note');
    }
}
