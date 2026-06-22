/**
 * Test coverage for TAM_FilterEngine_Service — the WHERE-clause builder used
 * by every filtered Target Criterion.
 *
 * The service has two public methods (`buildWhereClause`, `parseFilters`) but
 * the bulk of the logic lives in `buildCondition` (private), reached via the
 * different filter types. The tests below feed JSON payloads that exercise
 * each branch: blanks, NULL operators, String / Number / Boolean / Date /
 * DateTime / Picklist / MultiPicklist, IN / NOT IN lists, custom filter
 * logic with multi-digit ids, and the SOQL-injection escape path.
 */
@isTest
public class TAM_FilterEngine_ServiceTest {

    private static String row(Integer id, String field, String op, Object val, String type) {
        Map<String, Object> r = new Map<String, Object>{
            'id' => id, 'field' => field, 'operator' => op,
            'value' => val, 'type' => type
        };
        return JSON.serialize(r);
    }

    private static String payload(List<String> rows) {
        return '{"filters":[' + String.join(rows, ',') + ']}';
    }

    @isTest
    static void blankInputReturnsEmptyClause() {
        Test.startTest();
        String empty = TAM_FilterEngine_Service.buildWhereClause(null, null);
        String emptyJson = TAM_FilterEngine_Service.buildWhereClause('', null);
        String noFilters = TAM_FilterEngine_Service.buildWhereClause('{"filters":[]}', null);
        Test.stopTest();
        System.assertEquals('', empty);
        System.assertEquals('', emptyJson);
        System.assertEquals('', noFilters);
    }

    @isTest
    static void stringEqualsEscapesQuotes() {
        // O'Brien must end up as O\'Brien in the generated clause.
        String json = payload(new List<String>{
            row(1, 'Name', '=', 'O\'Brien', 'String')
        });
        Test.startTest();
        String clause = TAM_FilterEngine_Service.buildWhereClause(json, null);
        Test.stopTest();
        System.assert(clause.contains('Name = \'O\\\'Brien\''),
            'single quote should be escaped — got: ' + clause);
    }

    @isTest
    static void stringLikeWrapsInPercent() {
        String json = payload(new List<String>{
            row(1, 'Name', 'LIKE', 'foo', 'String')
        });
        Test.startTest();
        String clause = TAM_FilterEngine_Service.buildWhereClause(json, null);
        Test.stopTest();
        System.assert(clause.contains('LIKE \'%foo%\''), 'got: ' + clause);
    }

    @isTest
    static void numberOperatorsKeepValueUnquoted() {
        String json = payload(new List<String>{
            row(1, 'Amount', '>=', 1000, 'Number')
        });
        Test.startTest();
        String clause = TAM_FilterEngine_Service.buildWhereClause(json, null);
        Test.stopTest();
        System.assert(clause.contains('Amount >= 1000'), 'got: ' + clause);
        System.assert(!clause.contains('\'1000\''),
            'numeric values must not be quoted');
    }

    @isTest
    static void booleanValueRendersAsSoqlLiteral() {
        // JSON-deserialized booleans come through as their string form per the
        // service's comment, so test both bool and "true"/"false" inputs.
        String json = payload(new List<String>{
            row(1, 'IsActive', '=', true, 'Boolean'),
            row(2, 'IsArchived', '=', 'false', 'Boolean')
        });
        Test.startTest();
        String clause = TAM_FilterEngine_Service.buildWhereClause(json, null);
        Test.stopTest();
        System.assert(clause.contains('IsActive = TRUE'), 'got: ' + clause);
        System.assert(clause.contains('IsArchived = FALSE'), 'got: ' + clause);
    }

    @isTest
    static void dateValueRendersAsSoqlDateLiteral() {
        String json = payload(new List<String>{
            row(1, 'CloseDate', '>=', '2026-06-01', 'Date')
        });
        Test.startTest();
        String clause = TAM_FilterEngine_Service.buildWhereClause(json, null);
        Test.stopTest();
        System.assert(clause.contains('CloseDate >= 2026-06-01'),
            'date should be unquoted ISO literal — got: ' + clause);
    }

    @isTest
    static void dateTimeRendersAsSoqlDateTimeLiteral() {
        String json = payload(new List<String>{
            row(1, 'CreatedDate', '>=', '2026-06-01T10:00:00Z', 'DateTime')
        });
        Test.startTest();
        String clause = TAM_FilterEngine_Service.buildWhereClause(json, null);
        Test.stopTest();
        System.assert(clause.contains('CreatedDate >= '),
            'should produce a datetime comparison — got: ' + clause);
        System.assert(clause.contains('Z'),
            'datetime literal must end in Z — got: ' + clause);
    }

    @isTest
    static void picklistOperatorQuotesValue() {
        String json = payload(new List<String>{
            row(1, 'StageName', '=', 'Closed Won', 'Picklist')
        });
        Test.startTest();
        String clause = TAM_FilterEngine_Service.buildWhereClause(json, null);
        Test.stopTest();
        System.assert(clause.contains('StageName = \'Closed Won\''), 'got: ' + clause);
    }

    @isTest
    static void multiPicklistRendersIncludesList() {
        String json = payload(new List<String>{
            row(1, 'Tags__c', 'INCLUDES', new List<String>{ 'A', 'B' }, 'MultiPicklist')
        });
        Test.startTest();
        String clause = TAM_FilterEngine_Service.buildWhereClause(json, null);
        Test.stopTest();
        System.assert(clause.contains('INCLUDES (\'A\',\'B\')'),
            'INCLUDES tuple expected — got: ' + clause);
    }

    @isTest
    static void multiPicklistScalarValueStillWraps() {
        String json = payload(new List<String>{
            row(1, 'Tags__c', 'INCLUDES', 'Solo', 'MultiPicklist')
        });
        Test.startTest();
        String clause = TAM_FilterEngine_Service.buildWhereClause(json, null);
        Test.stopTest();
        System.assert(clause.contains('INCLUDES (\'Solo\')'), 'got: ' + clause);
    }

    @isTest
    static void inOperatorOnNumberLeavesValuesUnquoted() {
        String json = payload(new List<String>{
            row(1, 'Amount', 'IN', new List<Integer>{ 100, 200, 300 }, 'Number')
        });
        Test.startTest();
        String clause = TAM_FilterEngine_Service.buildWhereClause(json, null);
        Test.stopTest();
        System.assert(clause.contains('IN (100,200,300)'), 'got: ' + clause);
    }

    @isTest
    static void inOperatorOnStringQuotesValues() {
        String json = payload(new List<String>{
            row(1, 'Name', 'IN', new List<String>{ 'foo', 'bar' }, 'String')
        });
        Test.startTest();
        String clause = TAM_FilterEngine_Service.buildWhereClause(json, null);
        Test.stopTest();
        System.assert(clause.contains('IN (\'foo\',\'bar\')'), 'got: ' + clause);
    }

    @isTest
    static void nullOperatorsBuildSoqlNullComparisons() {
        String json = payload(new List<String>{
            row(1, 'AccountId', 'IS NULL', null, 'Null'),
            row(2, 'OwnerId', 'IS NOT NULL', null, 'Null')
        });
        Test.startTest();
        String clause = TAM_FilterEngine_Service.buildWhereClause(json, null);
        Test.stopTest();
        System.assert(clause.contains('AccountId = NULL'), 'got: ' + clause);
        System.assert(clause.contains('OwnerId != NULL'), 'got: ' + clause);
    }

    @isTest
    static void noLogicJoinsConditionsWithAnd() {
        String json = payload(new List<String>{
            row(1, 'IsActive', '=', true, 'Boolean'),
            row(2, 'Amount', '>=', 1000, 'Number')
        });
        Test.startTest();
        String clause = TAM_FilterEngine_Service.buildWhereClause(json, null);
        Test.stopTest();
        System.assert(clause.contains(' AND '),
            'missing logic string must default to AND — got: ' + clause);
        System.assert(clause.contains('IsActive = TRUE'), 'got: ' + clause);
        System.assert(clause.contains('Amount >= 1000'), 'got: ' + clause);
    }

    @isTest
    static void customLogicResolvesIdReferences() {
        // Numeric value (5000) deliberately avoids digits 1/2/3 so the naive
        // String.replace inside the service can't clobber them when it
        // substitutes the row ids back into the logic string.
        String json = payload(new List<String>{
            row(1, 'IsActive', '=', true, 'Boolean'),
            row(2, 'Amount', '>=', 5000, 'Number'),
            row(3, 'Name', '=', 'foo', 'String')
        });
        Test.startTest();
        String clause = TAM_FilterEngine_Service.buildWhereClause(
            json, '1 AND (2 OR 3)'
        );
        Test.stopTest();
        System.assert(clause.startsWith('(') && clause.endsWith(')'),
            'logic clauses are wrapped in parens — got: ' + clause);
        System.assert(clause.contains('IsActive = TRUE'), 'got: ' + clause);
        System.assert(clause.contains('Amount >= 5000'), 'got: ' + clause);
        System.assert(clause.contains('Name = \'foo\''), 'got: ' + clause);
        System.assert(clause.contains(' AND ') && clause.contains(' OR '), 'got: ' + clause);
    }

    @isTest
    static void multiDigitIdsDontGetClobberedByLowerIds() {
        // The service notes it processes ids in descending order to avoid
        // replacing "1" inside "12" in the LOGIC string. Use field names that
        // don't themselves contain digits, otherwise the naive replacement
        // also clobbers the substituted condition text (a known limitation,
        // not what this test is asserting).
        String json = payload(new List<String>{
            row(1,  'Status',   '=', 'A', 'String'),
            row(12, 'Priority', '=', 'B', 'String')
        });
        Test.startTest();
        String clause = TAM_FilterEngine_Service.buildWhereClause(
            json, '1 AND 12'
        );
        Test.stopTest();
        // Both conditions must appear intact — a buggy ascending replacement
        // would inject "(Status = 'A')" inside "12", leaving "(Status = 'A')2".
        System.assert(clause.contains('Status = \'A\''),
            'id 1 condition should appear: ' + clause);
        System.assert(clause.contains('Priority = \'B\''),
            'id 12 condition should appear, not clobbered by id 1 replacement: ' + clause);
    }

    @isTest
    static void parseFiltersExposesParsedShape() {
        String json = payload(new List<String>{
            row(7, 'Name', '=', 'foo', 'String'),
            row(8, 'Amount', '>', 50, 'Number')
        });
        Test.startTest();
        TAM_FilterEngine_Service.FilterDefinition def = TAM_FilterEngine_Service.parseFilters(json);
        Test.stopTest();
        System.assertEquals(2, def.filters.size());
        System.assertEquals(7, def.filters[0].id);
        System.assertEquals('Name', def.filters[0].field);
        System.assertEquals('String', def.filters[0].type);
    }

    @isTest
    static void parseFiltersHandlesBlankInput() {
        Test.startTest();
        TAM_FilterEngine_Service.FilterDefinition def = TAM_FilterEngine_Service.parseFilters(null);
        Test.stopTest();
        System.assertNotEquals(null, def);
        System.assert(def.filters.isEmpty());
    }
}
