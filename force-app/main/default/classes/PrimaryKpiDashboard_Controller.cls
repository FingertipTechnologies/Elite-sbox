/**
 * Backs the Primary KPI tab (primaryKpiDashboard LWC). Reads the already-computed
 * PBIS_Target__c calc fields (Task 4) for the logged-in user and, for managers, their
 * subordinates (role hierarchy) — no recompute. Mirrors SecondaryKpiDashboard_Controller's
 * PERSONAL / TEAM / EMPTY shape.
 */
public with sharing class PrimaryKpiDashboard_Controller {

    private static final Integer SLOTS = 10;

    // ===== wrappers =====
    public class Dashboard {
        @AuraEnabled public String mode;                 // PERSONAL | TEAM | EMPTY
        @AuraEnabled public Boolean viewerIsManager;
        @AuraEnabled public String periodLabel;
        @AuraEnabled public String selectedUserName;
        @AuraEnabled public Hero hero;
        @AuraEnabled public List<ParamRow> parameters;
        @AuraEnabled public List<TeamRow> team;
        @AuraEnabled public List<BreakdownRow> channels;       // team: Sales Channel wise
        @AuraEnabled public List<BreakdownRow> paramBreakdown; // team: S&D Parameter wise
        @AuraEnabled public List<Option> userPickerOptions;
    }
    public class BreakdownRow {
        @AuraEnabled public String label;
        @AuraEnabled public Decimal achievementPct;
        @AuraEnabled public Decimal incentive;
    }
    public class Hero {
        @AuraEnabled public Decimal totalIncentive;
        @AuraEnabled public Decimal maxIncentive;
        @AuraEnabled public Decimal achievementPct;
        @AuraEnabled public Boolean isEligible;
        @AuraEnabled public String policyName;
        @AuraEnabled public String profileName;
    }
    public class ParamRow {
        @AuraEnabled public String id;
        @AuraEnabled public String parameter;
        @AuraEnabled public Decimal target;
        @AuraEnabled public Decimal achievement;
        @AuraEnabled public Decimal achievementPct;
        @AuraEnabled public Decimal weightage;
        @AuraEnabled public String slab;
        @AuraEnabled public Decimal incentive;
    }
    public class TeamRow {
        @AuraEnabled public Id userId;
        @AuraEnabled public String userName;
        @AuraEnabled public String role;
        @AuraEnabled public Decimal totalIncentive;
        @AuraEnabled public Decimal maxIncentive;
        @AuraEnabled public Decimal achievementPct;
        @AuraEnabled public Boolean isEligible;
    }
    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String userId;
    }

    @AuraEnabled(cacheable=false)
    public static Dashboard getDashboard(Integer year, Integer month, String incentivePeriod, Id viewUserId) {
        Dashboard d = new Dashboard();
        Id me = UserInfo.getUserId();
        if (year == null) year = Date.today().year();
        if (month == null) month = Date.today().month();
        if (String.isBlank(incentivePeriod)) incentivePeriod = 'Monthly';
        Date monthStart = Date.newInstance(year, month, 1);
        d.periodLabel = monthLabel(month) + ' ' + year + ' · ' + incentivePeriod;

        // Strict subordinates = users in roles below the viewer's role.
        Set<Id> subordinateIds = subordinatesOf(me);
        d.viewerIsManager = !subordinateIds.isEmpty();

        d.userPickerOptions = new List<Option>();
        if (d.viewerIsManager) {
            for (User u : [SELECT Id, Name FROM User WHERE Id IN :subordinateIds ORDER BY Name]) {
                Option o = new Option();
                o.label = u.Name;
                o.userId = u.Id;
                d.userPickerOptions.add(o);
            }
        }

        // Targets active in the chosen month for the viewer + subordinates (one SOQL).
        Set<Id> queryIds = new Set<Id>(subordinateIds);
        queryIds.add(me);
        Map<Id, PBIS_Target__c> targetByUser = new Map<Id, PBIS_Target__c>();
        for (PBIS_Target__c t : queryTargets(queryIds, incentivePeriod, monthStart)) {
            targetByUser.put(t.User__c, t);
        }
        if (targetByUser.isEmpty()) {
            d.mode = 'EMPTY';
            return d;
        }

        // Team table for managers.
        if (d.viewerIsManager) {
            d.mode = 'TEAM';
            d.team = new List<TeamRow>();
            Map<Id, User> uMap = new Map<Id, User>([
                SELECT Id, Name, UserRole.Name FROM User WHERE Id IN :subordinateIds
            ]);
            for (Id uid : subordinateIds) {
                PBIS_Target__c t = targetByUser.get(uid);
                if (t == null) continue; // subordinate has no target this period
                TeamRow tr = new TeamRow();
                tr.userId = uid;
                tr.userName = uMap.containsKey(uid) ? uMap.get(uid).Name : '';
                tr.role = (uMap.containsKey(uid) && uMap.get(uid).UserRole != null) ? uMap.get(uid).UserRole.Name : '';
                tr.totalIncentive = nz(t.Total_Incentive_Value__c);
                tr.maxIncentive = nz(t.Max_Incentive_Value__c);
                tr.achievementPct = weightedPct(t);
                tr.isEligible = t.Is_Eligible__c == true;
                d.team.add(tr);
            }
            // Team breakdowns: Sales Channel wise and S&D Parameter wise.
            Map<String, Decimal[]> chAgg = new Map<String, Decimal[]>();   // [incSum, pctSum, count]
            Map<String, Decimal[]> pmAgg = new Map<String, Decimal[]>();
            for (Id uid : subordinateIds) {
                PBIS_Target__c t = targetByUser.get(uid);
                if (t == null) continue;
                String ch = (String) t.get('Sales_Channel__c');
                accumulate(chAgg, String.isBlank(ch) ? '— No channel —' : ch,
                    nz(t.Total_Incentive_Value__c), weightedPct(t));
                for (Integer n = 1; n <= SLOTS; n++) {
                    if (t.get('S_D_Parameter_' + n + '__c') == null) continue;
                    SObject p = t.getSObject('S_D_Parameter_' + n + '__r');
                    String pname = p != null ? (String) p.get('Name') : ('Slot ' + n);
                    accumulate(pmAgg, pname,
                        nz((Decimal) t.get('S_D_Parameter_' + n + '_Incentive_Amount__c')),
                        nz((Decimal) t.get('S_D_Parameter_' + n + '_Achievement_Percent__c')));
                }
            }
            d.channels = toBreakdownRows(chAgg);
            d.paramBreakdown = toBreakdownRows(pmAgg);
        } else {
            d.mode = 'PERSONAL';
        }

        // Personal detail for the focused user (drilled/picked subordinate, else the viewer).
        Id focusUser = (viewUserId != null) ? viewUserId : me;
        PBIS_Target__c ft = targetByUser.get(focusUser);
        if (ft == null && !d.viewerIsManager) {
            d.mode = 'EMPTY';
            return d;
        }
        if (ft != null) {
            d.selectedUserName = userName(focusUser);
            d.hero = buildHero(ft);
            d.parameters = buildParams(ft);
        }
        return d;
    }

    // ===== helpers =====
    private static Set<Id> subordinatesOf(Id userId) {
        Id roleId = [SELECT UserRoleId FROM User WHERE Id = :userId].UserRoleId;
        Set<Id> ids = new Set<Id>();
        if (roleId == null) return ids;
        Set<Id> childRoles = RoleHeirarchyUtility.getAllChildRoleIds(new Set<Id>{ roleId });
        if (childRoles.isEmpty()) return ids;
        for (User u : [SELECT Id FROM User WHERE UserRoleId IN :childRoles AND IsActive = true]) {
            ids.add(u.Id);
        }
        return ids;
    }

    // Accumulate [incentiveSum, achievementPctSum, count] under a label.
    private static void accumulate(Map<String, Decimal[]> m, String key, Decimal incentive, Decimal pct) {
        Decimal[] a = m.get(key);
        if (a == null) { a = new Decimal[]{ 0, 0, 0 }; m.put(key, a); }
        a[0] += nz(incentive);
        a[1] += nz(pct);
        a[2] += 1;
    }

    private static List<BreakdownRow> toBreakdownRows(Map<String, Decimal[]> m) {
        List<BreakdownRow> rows = new List<BreakdownRow>();
        for (String k : m.keySet()) {
            Decimal[] a = m.get(k);
            BreakdownRow r = new BreakdownRow();
            r.label = k;
            r.incentive = a[0];
            r.achievementPct = a[2] > 0 ? (a[1] / a[2]).setScale(1) : 0;
            rows.add(r);
        }
        return rows;
    }

    private static Hero buildHero(PBIS_Target__c t) {
        Hero h = new Hero();
        h.totalIncentive = nz(t.Total_Incentive_Value__c);
        h.maxIncentive = nz(t.Max_Incentive_Value__c);
        h.isEligible = t.Is_Eligible__c == true;
        h.policyName = (String) t.get('PBIS_Policy_Name__c');
        h.profileName = (String) t.get('Profile__c');
        h.achievementPct = weightedPct(t);
        return h;
    }

    // Weighted average of each filled slot's achievement % by its weightage.
    private static Decimal weightedPct(PBIS_Target__c t) {
        Decimal wSum = 0;
        Decimal wPctSum = 0;
        for (Integer n = 1; n <= SLOTS; n++) {
            if (t.get('S_D_Parameter_' + n + '__c') == null) continue;
            Decimal w = nz((Decimal) t.get('S_D_Parameter_' + n + '_Weightage__c'));
            Decimal p = nz((Decimal) t.get('S_D_Parameter_' + n + '_Achievement_Percent__c'));
            wSum += w;
            wPctSum += w * p;
        }
        return wSum > 0 ? (wPctSum / wSum).setScale(1) : 0;
    }

    private static List<ParamRow> buildParams(PBIS_Target__c t) {
        List<ParamRow> rows = new List<ParamRow>();
        for (Integer n = 1; n <= SLOTS; n++) {
            if (t.get('S_D_Parameter_' + n + '__c') == null) continue;
            ParamRow r = new ParamRow();
            r.id = String.valueOf(n);
            SObject param = t.getSObject('S_D_Parameter_' + n + '__r');
            r.parameter = param != null ? (String) param.get('Name') : ('Slot ' + n);
            r.target = nz((Decimal) t.get('S_D_Parameter_' + n + '_Target__c'));
            r.achievement = nz((Decimal) t.get('S_D_Parameter_' + n + '_Achievement__c'));
            r.achievementPct = nz((Decimal) t.get('S_D_Parameter_' + n + '_Achievement_Percent__c'));
            r.weightage = nz((Decimal) t.get('S_D_Parameter_' + n + '_Weightage__c'));
            SObject slab = t.getSObject('S_D_Parameter_' + n + '_Qualified_Slab__r');
            r.slab = slab != null ? (String) slab.get('Name') : '—';
            r.incentive = nz((Decimal) t.get('S_D_Parameter_' + n + '_Incentive_Amount__c'));
            rows.add(r);
        }
        return rows;
    }

    private static List<PBIS_Target__c> queryTargets(Set<Id> userIds, String incentivePeriod, Date monthStart) {
        List<String> fields = new List<String>{
            'Id', 'User__c', 'Total_Incentive_Value__c', 'Max_Incentive_Value__c', 'Is_Eligible__c',
            'Total_Weightage__c', 'Incentive_Period__c', 'Start_Date__c', 'End_Date__c',
            'Profile__c', 'PBIS_Policy_Name__c', 'Sales_Channel__c'
        };
        for (Integer n = 1; n <= SLOTS; n++) {
            fields.add('S_D_Parameter_' + n + '__c');
            fields.add('S_D_Parameter_' + n + '__r.Name');
            fields.add('S_D_Parameter_' + n + '_Target__c');
            fields.add('S_D_Parameter_' + n + '_Weightage__c');
            fields.add('S_D_Parameter_' + n + '_Achievement__c');
            fields.add('S_D_Parameter_' + n + '_Achievement_Percent__c');
            fields.add('S_D_Parameter_' + n + '_Incentive_Amount__c');
            fields.add('S_D_Parameter_' + n + '_Qualified_Slab__r.Name');
        }
        String soql = 'SELECT ' + String.join(fields, ', ') +
            ' FROM PBIS_Target__c' +
            ' WHERE User__c IN :userIds AND Incentive_Period__c = :incentivePeriod' +
            ' AND Start_Date__c <= :monthStart AND End_Date__c >= :monthStart';
        return (List<PBIS_Target__c>) Database.query(soql);
    }

    private static String userName(Id userId) {
        if (userId == null) return '';
        List<User> us = [SELECT Name FROM User WHERE Id = :userId LIMIT 1];
        return us.isEmpty() ? '' : us[0].Name;
    }

    private static Decimal nz(Decimal v) {
        return v == null ? 0 : v;
    }

    private static String monthLabel(Integer m) {
        List<String> names = new List<String>{
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        };
        return (m != null && m >= 1 && m <= 12) ? names[m - 1] : '';
    }
}
