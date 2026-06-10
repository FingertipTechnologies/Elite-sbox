/**
 * UI controller for the Secondary KPI Dashboard.
 *
 * Phase 2 model — single-user dashboard, switched via a picker:
 *   - DSM / SSA users see only their own dashboard. The picker is hidden.
 *   - Managers and heads pick one DSM / SSA from their role-hierarchy
 *     downline; the dashboard refreshes for that user only.
 *
 * Each secondary target belongs to one user — there is no rolled-up team
 * target — so the dashboard is always a per-user view of that person's
 * active targets, achievements, and PBIS incentives for the selected
 * month.
 *
 * Uses `without sharing` so a manager can read their subordinates'
 * Secondary_Target__c / Incentive_Credit__c data regardless of record
 * sharing — only the rolled-up per-user aggregates leave the class.
 */
public without sharing class SecondaryKpiDashboard_Controller {

    // ===== Wrappers =====

    public class UserOption {
        @AuraEnabled public Id userId;
        @AuraEnabled public String name;
        @AuraEnabled public String profileName;
        @AuraEnabled public String employeeCode;
        @AuraEnabled public String label;
    }

    public class Hero {
        @AuraEnabled public Integer activeTargets = 0;
        @AuraEnabled public Decimal totalTarget = 0;
        @AuraEnabled public Decimal totalAchievement = 0;
        @AuraEnabled public Decimal achievementPct = 0;
        @AuraEnabled public Decimal totalIncentive = 0;
        @AuraEnabled public Integer incentiveLines = 0;
    }

    public class TargetRow {
        @AuraEnabled public Id targetId;
        @AuraEnabled public String targetName;
        @AuraEnabled public String criterionName;
        @AuraEnabled public String focusPackName;
        @AuraEnabled public String channel;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public Decimal targetValue = 0;
        @AuraEnabled public Decimal achievementValue = 0;
        @AuraEnabled public Decimal achievementPct = 0;
        @AuraEnabled public Decimal pendingTarget = 0;
        @AuraEnabled public Decimal workingDays = 0;
        @AuraEnabled public Decimal incentive = 0;
    }

    public class DashboardData {
        @AuraEnabled public Id viewerUserId;
        @AuraEnabled public Boolean viewerIsDsmSsa = false;
        @AuraEnabled public Id selectedUserId;
        @AuraEnabled public String selectedUserName;
        @AuraEnabled public String selectedUserRole;
        @AuraEnabled public String selectedUserChannel;
        @AuraEnabled public String employeeCode;
        @AuraEnabled public Integer year;
        @AuraEnabled public Integer month;
        @AuraEnabled public String periodLabel;
        @AuraEnabled public Hero hero;
        @AuraEnabled public List<TargetRow> targets = new List<TargetRow>();
        @AuraEnabled public Boolean noSubordinates = false;
    }

    // ===== Constants =====

    // Field-sales profile names — only users in these profiles carry secondary
    // targets, so the picker and the "DSM/SSA dashboard" gate use this set.
    private static final Set<String> SALES_REP_PROFILES = new Set<String>{
        'DSM', 'SSA'
    };

    // ===== Picker =====

    /**
     * DSM / SSA users available to the current viewer.
     *  - If the viewer is a DSM / SSA, returns just themselves.
     *  - Otherwise returns every active DSM / SSA in the viewer's role-hierarchy
     *    downline.
     */
    @AuraEnabled(cacheable=true)
    public static List<UserOption> getDsmSsaSubordinates() {
        List<UserOption> result = new List<UserOption>();
        Id me = UserInfo.getUserId();
        User myUser = [
            SELECT Id, Name, UserRoleId, Profile.Name
            FROM User WHERE Id = :me LIMIT 1
        ];

        Boolean meIsRep = myUser.Profile != null
            && SALES_REP_PROFILES.contains(myUser.Profile.Name);

        Set<Id> universe;
        if (meIsRep) {
            universe = new Set<Id>{ me };
        } else {
            universe = collectDownlineUsers(myUser.UserRoleId);
            universe.add(me); // harmless; will be filtered out by the profile check.
        }
        if (universe.isEmpty()) return result;

        for (User u : [
            SELECT Id, Name, Profile.Name, Employee_Code__c
            FROM User
            WHERE Id IN :universe
              AND IsActive = true
              AND Profile.Name IN :SALES_REP_PROFILES
            ORDER BY Name
        ]) {
            UserOption opt = new UserOption();
            opt.userId = u.Id;
            opt.name = u.Name;
            opt.profileName = u.Profile != null ? u.Profile.Name : '';
            opt.employeeCode = u.Employee_Code__c;
            // "Name · EMP001 (DSM)"
            String suffix = String.isNotBlank(u.Employee_Code__c)
                ? ' · ' + u.Employee_Code__c : '';
            String role = String.isNotBlank(opt.profileName)
                ? ' (' + opt.profileName + ')' : '';
            opt.label = u.Name + suffix + role;
            result.add(opt);
        }
        return result;
    }

    // ===== Dashboard =====

    @AuraEnabled(cacheable=false)
    public static DashboardData getDashboard(Integer year, Integer month, Id selectedUserId) {
        DashboardData out = new DashboardData();

        if (year == null || month == null || month < 1 || month > 12) {
            Date today = Date.today();
            year = today.year();
            month = today.month();
        }
        out.year = year;
        out.month = month;
        out.periodLabel = monthName(month) + ' ' + String.valueOf(year);

        Id me = UserInfo.getUserId();
        User myUser = [
            SELECT Id, Name, Profile.Name, UserRoleId
            FROM User WHERE Id = :me LIMIT 1
        ];
        out.viewerUserId = me;
        out.viewerIsDsmSsa = myUser.Profile != null
            && SALES_REP_PROFILES.contains(myUser.Profile.Name);

        // Resolve who we're showing data for.
        if (out.viewerIsDsmSsa) {
            // DSM/SSAs can only see themselves — ignore any passed selectedUserId.
            selectedUserId = me;
        } else if (selectedUserId == null) {
            // Manager / head with no explicit pick — default to the first DSM/SSA
            // we find in their downline.
            List<UserOption> subs = getDsmSsaSubordinates();
            if (subs.isEmpty()) {
                out.noSubordinates = true;
                out.hero = new Hero();
                return out;
            }
            selectedUserId = subs[0].userId;
        }
        out.selectedUserId = selectedUserId;

        User u = [
            SELECT Id, Name, Profile.Name, Employee_Code__c, Sales_Channel__c
            FROM User WHERE Id = :selectedUserId LIMIT 1
        ];
        out.selectedUserName = u.Name;
        out.selectedUserRole = u.Profile != null ? u.Profile.Name : null;
        out.selectedUserChannel = u.Sales_Channel__c;
        out.employeeCode = u.Employee_Code__c;

        Date monthStart = Date.newInstance(year, month, 1);
        Date monthEnd = monthStart.addMonths(1).addDays(-1);

        out.hero = buildHero(selectedUserId, monthStart, monthEnd, year, month);
        out.targets = buildTargetRows(selectedUserId, monthStart, monthEnd, year, month);
        return out;
    }

    // ===== Hero =====

    private static Hero buildHero(Id userId, Date monthStart, Date monthEnd, Integer year, Integer month) {
        Hero h = new Hero();
        if (userId == null) return h;

        for (AggregateResult ar : [
            SELECT COUNT(Id) cnt,
                   SUM(Target_Value__c) tgt,
                   SUM(Achievement_Value__c) ach
            FROM Secondary_Target__c
            WHERE Is_Active__c = true
              AND User__c = :userId
              AND Start_Date__c <= :monthEnd
              AND End_Date__c >= :monthStart
        ]) {
            h.activeTargets = nz((Integer) ar.get('cnt'));
            h.totalTarget = nzd((Decimal) ar.get('tgt'));
            h.totalAchievement = nzd((Decimal) ar.get('ach'));
        }
        h.achievementPct = pct(h.totalAchievement, h.totalTarget);

        for (AggregateResult ar : [
            SELECT SUM(Credit_Amount__c) amt, COUNT(Id) cnt
            FROM Incentive_Credit__c
            WHERE Source__c = 'Secondary PBIS'
              AND Year__c = :year AND Month__c = :month
              AND Executive__c = :userId
        ]) {
            h.totalIncentive = nzd((Decimal) ar.get('amt'));
            h.incentiveLines = nz((Integer) ar.get('cnt'));
        }
        return h;
    }

    // ===== Per-target rows =====

    private static List<TargetRow> buildTargetRows(Id userId, Date monthStart, Date monthEnd, Integer year, Integer month) {
        List<TargetRow> rows = new List<TargetRow>();
        if (userId == null) return rows;

        // Map each (criterion, focus pack) to its PBIS payout for this user/month
        // so each target row can show the incentive it earned.
        Map<String, Decimal> incentiveByKey = new Map<String, Decimal>();
        for (AggregateResult ar : [
            SELECT Target_Criteria__c cid, Focused_Pack__c pid, SUM(Credit_Amount__c) amt
            FROM Incentive_Credit__c
            WHERE Source__c = 'Secondary PBIS'
              AND Year__c = :year AND Month__c = :month
              AND Executive__c = :userId
            GROUP BY Target_Criteria__c, Focused_Pack__c
        ]) {
            String key = String.valueOf(ar.get('cid')) + '|' + String.valueOf(ar.get('pid'));
            incentiveByKey.put(key, nzd((Decimal) ar.get('amt')));
        }

        for (Secondary_Target__c t : [
            SELECT Id, Name, Sales_Channel__c, Start_Date__c, End_Date__c,
                   Target_Criteria__c, Target_Criteria__r.Name,
                   Focused_Pack__c, Focused_Pack__r.Name,
                   Target_Value__c, Achievement_Value__c, Achievement_Percent__c,
                   Pending_Target__c, Working_Days__c
            FROM Secondary_Target__c
            WHERE Is_Active__c = true
              AND User__c = :userId
              AND Start_Date__c <= :monthEnd
              AND End_Date__c >= :monthStart
            ORDER BY Target_Criteria__r.Name
        ]) {
            TargetRow tr = new TargetRow();
            tr.targetId = t.Id;
            tr.targetName = t.Name;
            tr.criterionName = t.Target_Criteria__r != null ? t.Target_Criteria__r.Name : null;
            tr.focusPackName = t.Focused_Pack__r != null ? t.Focused_Pack__r.Name : null;
            tr.channel = t.Sales_Channel__c;
            tr.startDate = t.Start_Date__c;
            tr.endDate = t.End_Date__c;
            tr.targetValue = nzd(t.Target_Value__c);
            tr.achievementValue = nzd(t.Achievement_Value__c);
            tr.achievementPct = nzd(t.Achievement_Percent__c);
            tr.pendingTarget = nzd(t.Pending_Target__c);
            tr.workingDays = nzd(t.Working_Days__c);
            String key = String.valueOf(t.Target_Criteria__c) + '|' + String.valueOf(t.Focused_Pack__c);
            tr.incentive = incentiveByKey.containsKey(key) ? incentiveByKey.get(key) : 0;
            rows.add(tr);
        }
        return rows;
    }

    // ===== Role-hierarchy helpers =====

    private static Set<Id> collectDownlineUsers(Id rootRoleId) {
        Set<Id> userIds = new Set<Id>();
        if (rootRoleId == null) return userIds;
        Map<Id, Set<Id>> parentToChildren = buildParentChildMap();
        Set<Id> roleIds = new Set<Id>();
        collectDescendantRoles(rootRoleId, parentToChildren, roleIds);
        roleIds.add(rootRoleId);
        return usersInRoles(roleIds);
    }

    private static Map<Id, Set<Id>> buildParentChildMap() {
        Map<Id, Set<Id>> parentToChildren = new Map<Id, Set<Id>>();
        for (UserRole r : [SELECT Id, ParentRoleId FROM UserRole]) {
            if (r.ParentRoleId == null) continue;
            if (!parentToChildren.containsKey(r.ParentRoleId)) {
                parentToChildren.put(r.ParentRoleId, new Set<Id>());
            }
            parentToChildren.get(r.ParentRoleId).add(r.Id);
        }
        return parentToChildren;
    }

    private static void collectDescendantRoles(Id parentRoleId, Map<Id, Set<Id>> parentToChildren, Set<Id> acc) {
        if (!parentToChildren.containsKey(parentRoleId)) return;
        for (Id child : parentToChildren.get(parentRoleId)) {
            if (acc.add(child)) {
                collectDescendantRoles(child, parentToChildren, acc);
            }
        }
    }

    private static Set<Id> usersInRoles(Set<Id> roleIds) {
        Set<Id> result = new Set<Id>();
        if (roleIds == null || roleIds.isEmpty()) return result;
        for (User u : [SELECT Id FROM User WHERE UserRoleId IN :roleIds AND IsActive = true]) {
            result.add(u.Id);
        }
        return result;
    }

    // ===== Small utilities =====

    private static Decimal pct(Decimal num, Decimal den) {
        if (den == null || den == 0) return 0;
        return (num == null ? 0 : num) / den * 100;
    }
    private static Integer nz(Integer v) { return v == null ? 0 : v; }
    private static Decimal nzd(Decimal v) { return v == null ? 0 : v; }

    private static String monthName(Integer m) {
        List<String> names = new List<String>{
            'January','February','March','April','May','June',
            'July','August','September','October','November','December'
        };
        return (m == null || m < 1 || m > 12) ? '' : names[m - 1];
    }
}
