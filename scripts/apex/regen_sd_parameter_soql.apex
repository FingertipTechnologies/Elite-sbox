/*
 * One-time regen of S_D_Parameter__c.SOQL_Query__c after the buildSoql change that
 * aliases the user field as `uid` (needed by the grouped PBISActuals_Service).
 * Run once after deploy:  sf apex run -f scripts/apex/regen_sd_parameter_soql.apex -o <org>
 */
List<S_D_Parameter__c> ps = [
    SELECT Id, Operator__c, Object__c, User_Field__c, Date_Field__c, Field__c,
           SKU_Field__c, Focused_Pack__c, Filters__c, Filter_Logic__c
    FROM S_D_Parameter__c
];
for (S_D_Parameter__c p : ps) {
    p.SOQL_Query__c = SDParameter_Controller.buildSoql(p);
}
update ps;
System.debug('Regenerated SOQL_Query__c for ' + ps.size() + ' S&D Parameters');
