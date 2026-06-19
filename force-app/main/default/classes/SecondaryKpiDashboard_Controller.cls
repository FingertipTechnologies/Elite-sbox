/**
 * UI controller for the Secondary KPI Dashboard.
 *
 * The dashboard has two display modes:
 *
 *   PERSONAL — a single user's secondary targets, achievement and incentives
 *              for the period. Used for DSM / SSA viewers (always themselves)
 *              and for managers who pick a specific DSM / SSA from the filter.
 *
 *   TEAM     — analytics across every active DSM / SSA in the viewer's role-
 *              hierarchy downline: aggregate hero, per-user table, top /
 *              bottom performers, channel and criterion breakdowns. Used for
 *              managers and heads when no specific user is selected.
 *
 * There is no rolled-up team target. Each DSM / SSA owns their own
 * Secondary_Target__c records; team aggregates sum across the individual
 * targets in the selected user-set.
 *
 * Uses `without sharing` so a manager can read every subordinate's data
 * regardless of record sharing — only the rolled-up aggregates leave the
 * class.
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
        @AuraEnabled public Integer targetedUsers = 0;     // TEAM mode only
        @AuraEnabled public Integer activeTargets = 0;
        @AuraEnabled public Decimal totalTarget = 0;
        @AuraEnabled public Decimal totalAchievement = 0;
        @AuraEnabled public Decimal achievementPct = 0;
        @AuraEnabled public Decimal totalIncentive = 0;
        @AuraEnabled public Integer incentiveLines = 0;
    }

    public class UserRow {
        @AuraEnabled public Id userId;
        @AuraEnabled public String userName;
        @AuraEnabled public String role;          // Profile.Name
        @AuraEnabled public String channel;
        @AuraEnabled public String employeeCode;
        @AuraEnabled public Integer activeTargets = 0;
        @AuraEnabled public Decimal totalTarget = 0;
        @AuraEnabled public Decimal totalAchievement = 0;
        @AuraEnabled public Decimal achievementPct = 0;
        @AuraEnabled public Decimal totalIncentive = 0;
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

    public class ChannelRow {
        @AuraEnabled public String channel;
        @AuraEnabled public Decimal totalTarget = 0;
        @AuraEnabled public Decimal totalAchievement = 0;
        @AuraEnabled public Decimal achievementPct = 0;
        @AuraEnabled public Integer userCount = 0;
    }

    public class CriteriaRow {
        @AuraEnabled public Id criteriaId;
        @AuraEnabled public String criteriaName;
        @AuraEnabled public Decimal totalTarget = 0;
        @AuraEnabled public Decimal totalAchievement = 0;
        @AuraEnabled public Decimal achievementPct = 0;
        @AuraEnabled public Integer userCount = 0;
    }

    public class DashboardData {
        @AuraEnabled public String mode;                  // 'PERSONAL' | 'TEAM' | 'EMPTY'
        @AuraEnabled public Id viewerUserId;
        @AuraEnabled public Boolean viewerIsDsmSsa = false;

        // PERSONAL
        @AuraEnabled public Id selectedUserId;
        @AuraEnabled public String selectedUserName;
        @AuraEnabled public String selectedUserRole;
        @AuraEnabled public String selectedUserChannel;
        @AuraEnabled public String employeeCode;
        @AuraEnabled public List<TargetRow> targets = new List<TargetRow>();

        // TEAM
        @AuraEnabled public List<UserRow> users = new List<UserRow>();
        @AuraEnabled public List<UserRow> topPerformers = new List<UserRow>();
        @AuraEnabled public List<UserRow> bottomPerformers = new List<UserRow>();
        @AuraEnabled public List<ChannelRow> channels = new List<ChannelRow>();
        @AuraEnabled public List<CriteriaRow> criteria = new List<CriteriaRow>();

        // Common
        @AuraEnabled public Integer year;
        @AuraEnabled public Integer month;
        @AuraEnabled public String periodLabel;
        @AuraEnabled public Hero hero;
    }

    public class PickerStep {
        @AuraEnabled public Integer tierIndex;
        @AuraEnabled public String tierLabel;
        @AuraEnabled public List<UserOption> options;
        @AuraEnabled public Id selectedUserId;
    }

    public class HierarchyResponse {
        @AuraEnabled public List<PickerStep> steps = new List<PickerStep>();
        @AuraEnabled public Id effectiveUserId;
        @AuraEnabled public Boolean viewerIsDsmSsa = false;
    }

    // ===== Constants =====

    private static final Set<String> SALES_REP_PROFILES = new Set<String>{
        'DSM', 'SSA'
    };

    // Tier model — used by the cascading picker. Order matters: top to bottom.
    // Each tier is a list of equivalent profile names so seniority variants
    // (Sr. RSM / RSM / Deputy RSM, etc.) collapse into one logical level.
    // Empty tiers in a given viewer's downline are skipped automatically, so
    // an org whose hierarchy doesn't use one of the intermediate levels
    // (e.g. no TSMs) still renders correctly.
    private static final List<List<String>> TIER_PROFILES = new List<List<String>>{
        new List<String>{ 'General Manager - Sales', 'Sr. RSM', 'RSM', 'Deputy RSM' },
        new List<String>{ 'Sr. ASM', 'ASM', 'Deputy ASM' },
        new List<String>{ 'Sr. TSM', 'TSM', 'Deputy TSM' },
        new List<String>{ 'Sr. TSE', 'TSE', 'Jr. TSE' },
        new List<String>{ 'DSM', 'SSA' }
    };
    private static final List<String> TIER_LABELS = new List<String>{
        'RSM', 'ASM', 'TSM', 'TSE', 'DSM / SSA'
    };

    private static Integer tierIndexFor(String profileName) {
        if (profileName == null) return -1;
        for (Integer i = 0; i < TIER_PROFILES.size(); i++) {
            if (TIER_PROFILES[i].contains(profileName)) return i;
        }
        return -1;
    }

    // ===== Picker =====

    @AuraEnabled(cacheable=true)
    public static List<UserOption> getDsmSsaSubordinates() {
        return findDsmSsaUsers(UserInfo.getUserId());
    }

    private static List<UserOption> findDsmSsaUsers(Id viewerId) {
        List<UserOption> result = new List<UserOption>();
        User myUser = [
            SELECT Id, Name, UserRoleId, Profile.Name
            FROM User WHERE Id = :viewerId LIMIT 1
        ];

        Boolean meIsRep = myUser.Profile != null
            && SALES_REP_PROFILES.contains(myUser.Profile.Name);

        Set<Id> universe;
        if (meIsRep) {
            universe = new Set<Id>{ viewerId };
        } else {
            universe = collectDownlineUsers(myUser.UserRoleId);
            universe.add(viewerId);
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
            String suffix = String.isNotBlank(u.Employee_Code__c)
                ? ' · ' + u.Employee_Code__c : '';
            String role = String.isNotBlank(opt.profileName)
                ? ' (' + opt.profileName + ')' : '';
            opt.label = u.Name + suffix + role;
            result.add(opt);
        }
        return result;
    }

    // ===== Cascading picker =====

    /**
     * Returns the picker cascade the LWC should render, given the user's
     * progressive selections (top-to-bottom, e.g. [ASM-id, TSE-id]).
     *
     *  - DSM / SSA viewers get no steps; they are locked to themselves.
     *  - Empty tiers in the viewer's downline are skipped, so an ASM whose
     *    DSMs report directly (no TSE layer) sees one combobox, not two.
     *  - Only one tier *below* the deepest specific selection is shown,
     *    so the cascade reveals progressively.
     */
    @AuraEnabled(cacheable=false)
    public static HierarchyResponse getHierarchy(List<String> selectedPath) {
        HierarchyResponse out = new HierarchyResponse();
        Id me = UserInfo.getUserId();
        User myUser = [
            SELECT Id, UserRoleId, Profile.Name FROM User WHERE Id = :me LIMIT 1
        ];
        String myProfile = myUser.Profile != null ? myUser.Profile.Name : null;
        out.viewerIsDsmSsa = myProfile != null && SALES_REP_PROFILES.contains(myProfile);

        if (out.viewerIsDsmSsa) {
            out.effectiveUserId = me;
            return out;
        }

        Integer viewerTier = tierIndexFor(myProfile);
        Integer startTier = viewerTier + 1;      // tier *below* the viewer's
        if (startTier < 0) startTier = 0;        // admin / above-all → start at top tier

        Id scopeRootId = me;
        List<String> path = selectedPath == null ? new List<String>() : selectedPath;
        Integer pathPos = 0;

        for (Integer tier = startTier; tier < TIER_PROFILES.size(); tier++) {
            List<UserOption> options = usersInTierUnderUser(scopeRootId, TIER_PROFILES[tier]);
            if (options.isEmpty()) continue; // skip empty layers — no users to choose from

            PickerStep step = new PickerStep();
            step.tierIndex = tier;
            step.tierLabel = TIER_LABELS[tier];
            step.options = options;

            // Resolve a selection at this visible position from the supplied path.
            if (pathPos < path.size()) {
                String sel = path[pathPos];
                if (String.isNotBlank(sel)) {
                    for (UserOption o : options) {
                        if (String.valueOf(o.userId) == sel) {
                            step.selectedUserId = (Id) sel;
                            scopeRootId = (Id) sel;
                            break;
                        }
                    }
                }
            }
            out.steps.add(step);
            pathPos++;

            // Stop revealing deeper tiers if no specific selection was made here.
            if (step.selectedUserId == null) break;
        }

        out.effectiveUserId = (scopeRootId == me) ? null : scopeRootId;
        return out;
    }

    /** Active users at a given tier inside the supplied root user's downline. */
    private static List<UserOption> usersInTierUnderUser(Id rootUserId, List<String> tierProfiles) {
        List<UserOption> out = new List<UserOption>();
        if (rootUserId == null) return out;
        User root = [SELECT Id, UserRoleId FROM User WHERE Id = :rootUserId LIMIT 1];
        Set<Id> downline = collectDownlineUsers(root.UserRoleId);
        downline.add(rootUserId);
        if (downline.isEmpty()) return out;
        for (User u : [
            SELECT Id, Name, Profile.Name, Employee_Code__c
            FROM User
            WHERE Id IN :downline
              AND IsActive = true
              AND Profile.Name IN :tierProfiles
              AND Id != :rootUserId
            ORDER BY Name
        ]) {
            UserOption opt = new UserOption();
            opt.userId = u.Id;
            opt.name = u.Name;
            opt.profileName = u.Profile != null ? u.Profile.Name : '';
            opt.employeeCode = u.Employee_Code__c;
            String suffix = String.isNotBlank(u.Employee_Code__c)
                ? ' · ' + u.Employee_Code__c : '';
            String role = String.isNotBlank(opt.profileName)
                ? ' (' + opt.profileName + ')' : '';
            opt.label = u.Name + suffix + role;
            out.add(opt);
        }
        return out;
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
            SELECT Id, Name, Profile.Name, UserRoleId FROM User WHERE Id = :me LIMIT 1
        ];
        out.viewerUserId = me;
        out.viewerIsDsmSsa = myUser.Profile != null
            && SALES_REP_PROFILES.contains(myUser.Profile.Name);

        // DSM / SSA — always their own dashboard regardless of selectedUserId.
        if (out.viewerIsDsmSsa) {
            out.mode = 'PERSONAL';
            return buildPersonal(out, me, year, month);
        }

        // Validate selectedUserId is inside the viewer's downline. If not (URL
        // hack, stale state, etc.), fall back to the viewer's whole scope.
        Id scopeRootId = (selectedUserId == null) ? me : selectedUserId;
        if (scopeRootId != me) {
            Set<Id> viewerDownline = collectDownlineUsers(myUser.UserRoleId);
            viewerDownline.add(me);
            if (!viewerDownline.contains(scopeRootId)) scopeRootId = me;
        }

        // If the scope user is a DSM / SSA, render their personal view; otherwise
        // aggregate every DSM / SSA in their downline as a team view.
        Boolean scopeIsDsmSsa = false;
        if (scopeRootId != me) {
            User su = [SELECT Profile.Name FROM User WHERE Id = :scopeRootId LIMIT 1];
            scopeIsDsmSsa = su.Profile != null
                && SALES_REP_PROFILES.contains(su.Profile.Name);
        }
        if (scopeIsDsmSsa) {
            out.mode = 'PERSONAL';
            return buildPersonal(out, scopeRootId, year, month);
        }

        Set<Id> dsmSsaIds = findDsmSsaUserIdsUnder(scopeRootId);
        if (dsmSsaIds.isEmpty()) {
            out.mode = 'EMPTY';
            out.hero = new Hero();
            return out;
        }
        out.mode = 'TEAM';
        return buildTeam(out, dsmSsaIds, year, month);
    }

    private static Set<Id> findDsmSsaUserIdsUnder(Id rootUserId) {
        Set<Id> ids = new Set<Id>();
        if (rootUserId == null) return ids;
        User root = [SELECT Id, UserRoleId FROM User WHERE Id = :rootUserId LIMIT 1];
        Set<Id> downline = collectDownlineUsers(root.UserRoleId);
        downline.add(rootUserId);
        if (downline.isEmpty()) return ids;
        for (User u : [
            SELECT Id FROM User
            WHERE Id IN :downline AND IsActive = true
              AND Profile.Name IN :SALES_REP_PROFILES
        ]) ids.add(u.Id);
        return ids;
    }

    // ===== PERSONAL mode =====

    private static DashboardData buildPersonal(DashboardData out, Id userId, Integer year, Integer month) {
        User u = [
            SELECT Id, Name, Profile.Name, Employee_Code__c, Sales_Channel__c
            FROM User WHERE Id = :userId LIMIT 1
        ];
        out.selectedUserId = userId;
        out.selectedUserName = u.Name;
        out.selectedUserRole = u.Profile != null ? u.Profile.Name : null;
        out.selectedUserChannel = u.Sales_Channel__c;
        out.employeeCode = u.Employee_Code__c;

        Date monthStart = Date.newInstance(year, month, 1);
        Date monthEnd = monthStart.addMonths(1).addDays(-1);

        Hero h = new Hero();
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
        out.hero = h;

        // Per-criterion incentive snapshot so each row shows what it earned.
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
            out.targets.add(tr);
        }
        return out;
    }

    // ===== TEAM mode =====

    private static DashboardData buildTeam(DashboardData out, Set<Id> userIds, Integer year, Integer month) {
        Date monthStart = Date.newInstance(year, month, 1);
        Date monthEnd = monthStart.addMonths(1).addDays(-1);

        Hero h = new Hero();
        Map<Id, Decimal[]> perUserTgt = perUserTargetTotals(userIds, monthStart, monthEnd);
        Map<Id, Decimal> perUserIncentive = perUserIncentiveTotals(userIds, year, month);

        // Aggregate hero by summing per-user numbers (faster than a second SOQL).
        for (Decimal[] rec : perUserTgt.values()) {
            h.activeTargets += rec[0].intValue();
            h.totalTarget += rec[1];
            h.totalAchievement += rec[2];
        }
        for (Decimal v : perUserIncentive.values()) {
            h.totalIncentive += v;
            h.incentiveLines++;
        }
        h.achievementPct = pct(h.totalAchievement, h.totalTarget);
        h.targetedUsers = perUserTgt.size();
        out.hero = h;

        // Per-DSM/SSA row list — show every team member that has activity in the
        // period, sorted by achievement % descending so leaders surface first.
        Set<Id> activeIds = new Set<Id>();
        activeIds.addAll(perUserTgt.keySet());
        activeIds.addAll(perUserIncentive.keySet());

        Map<Id, User> profile = new Map<Id, User>();
        if (!activeIds.isEmpty()) {
            profile = new Map<Id, User>([
                SELECT Id, Name, Profile.Name, Sales_Channel__c, Employee_Code__c
                FROM User WHERE Id IN :activeIds
            ]);
        }

        List<UserRow> rows = new List<UserRow>();
        for (Id uid : activeIds) {
            UserRow ur = new UserRow();
            ur.userId = uid;
            User u = profile.get(uid);
            if (u != null) {
                ur.userName = u.Name;
                ur.role = u.Profile != null ? u.Profile.Name : null;
                ur.channel = u.Sales_Channel__c;
                ur.employeeCode = u.Employee_Code__c;
            }
            Decimal[] rec = perUserTgt.get(uid);
            if (rec != null) {
                ur.activeTargets = rec[0].intValue();
                ur.totalTarget = rec[1];
                ur.totalAchievement = rec[2];
            }
            ur.achievementPct = pct(ur.totalAchievement, ur.totalTarget);
            Decimal inc = perUserIncentive.get(uid);
            ur.totalIncentive = inc == null ? 0 : inc;
            rows.add(ur);
        }
        out.users = sortByPct(rows, true);
        out.topPerformers = topN(rows, 5, true);
        out.bottomPerformers = topN(rows, 5, false);

        out.channels = buildChannelRows(userIds, monthStart, monthEnd);
        out.criteria = buildCriteriaRows(userIds, monthStart, monthEnd);
        return out;
    }

    private static List<UserRow> sortByPct(List<UserRow> rows, Boolean descending) {
        List<UserRow> copy = new List<UserRow>(rows);
        for (Integer i = 1; i < copy.size(); i++) {
            UserRow cur = copy[i];
            Integer j = i - 1;
            while (j >= 0 && cmpPct(copy[j], cur, descending) > 0) {
                copy[j + 1] = copy[j];
                j--;
            }
            copy[j + 1] = cur;
        }
        return copy;
    }

    private static List<UserRow> topN(List<UserRow> rows, Integer n, Boolean descending) {
        // Only consider users with a real target — empty users shouldn't dominate either list.
        List<UserRow> filtered = new List<UserRow>();
        for (UserRow r : rows) if (r.totalTarget != null && r.totalTarget > 0) filtered.add(r);
        List<UserRow> sorted = sortByPct(filtered, descending);
        List<UserRow> outList = new List<UserRow>();
        for (Integer i = 0; i < sorted.size() && i < n; i++) outList.add(sorted[i]);
        return outList;
    }

    private static Integer cmpPct(UserRow a, UserRow b, Boolean descending) {
        Decimal pa = a.achievementPct == null ? 0 : a.achievementPct;
        Decimal pb = b.achievementPct == null ? 0 : b.achievementPct;
        if (pa == pb) return 0;
        Boolean aBigger = pa > pb;
        if (descending) return aBigger ? -1 : 1;
        return aBigger ? 1 : -1;
    }

    // ===== Channel / Criterion breakdowns (TEAM only) =====

    private static List<ChannelRow> buildChannelRows(Set<Id> userIds, Date monthStart, Date monthEnd) {
        List<ChannelRow> out = new List<ChannelRow>();
        if (userIds == null || userIds.isEmpty()) return out;
        for (AggregateResult ar : [
            SELECT Sales_Channel__c ch,
                   SUM(Target_Value__c) tgt,
                   SUM(Achievement_Value__c) ach,
                   COUNT_DISTINCT(User__c) usr
            FROM Secondary_Target__c
            WHERE Is_Active__c = true
              AND User__c IN :userIds
              AND Start_Date__c <= :monthEnd
              AND End_Date__c >= :monthStart
            GROUP BY Sales_Channel__c
        ]) {
            ChannelRow cr = new ChannelRow();
            cr.channel = (String) ar.get('ch');
            cr.totalTarget = nzd((Decimal) ar.get('tgt'));
            cr.totalAchievement = nzd((Decimal) ar.get('ach'));
            cr.userCount = nz((Integer) ar.get('usr'));
            cr.achievementPct = pct(cr.totalAchievement, cr.totalTarget);
            out.add(cr);
        }
        return out;
    }

    private static List<CriteriaRow> buildCriteriaRows(Set<Id> userIds, Date monthStart, Date monthEnd) {
        List<CriteriaRow> out = new List<CriteriaRow>();
        if (userIds == null || userIds.isEmpty()) return out;
        for (AggregateResult ar : [
            SELECT Target_Criteria__c cid,
                   Target_Criteria__r.Name cname,
                   SUM(Target_Value__c) tgt,
                   SUM(Achievement_Value__c) ach,
                   COUNT_DISTINCT(User__c) usr
            FROM Secondary_Target__c
            WHERE Is_Active__c = true
              AND User__c IN :userIds
              AND Target_Criteria__c != null
              AND Start_Date__c <= :monthEnd
              AND End_Date__c >= :monthStart
            GROUP BY Target_Criteria__c, Target_Criteria__r.Name
        ]) {
            CriteriaRow cr = new CriteriaRow();
            cr.criteriaId = (Id) ar.get('cid');
            cr.criteriaName = (String) ar.get('cname');
            cr.totalTarget = nzd((Decimal) ar.get('tgt'));
            cr.totalAchievement = nzd((Decimal) ar.get('ach'));
            cr.userCount = nz((Integer) ar.get('usr'));
            cr.achievementPct = pct(cr.totalAchievement, cr.totalTarget);
            out.add(cr);
        }
        return out;
    }

    // ===== Per-user aggregate helpers =====

    /** Returns Map<userId, [activeTargetCount, targetSum, achievementSum]>. */
    private static Map<Id, Decimal[]> perUserTargetTotals(Set<Id> userIds, Date monthStart, Date monthEnd) {
        Map<Id, Decimal[]> out = new Map<Id, Decimal[]>();
        if (userIds == null || userIds.isEmpty()) return out;
        for (AggregateResult ar : [
            SELECT User__c uid,
                   COUNT(Id) cnt,
                   SUM(Target_Value__c) tgt,
                   SUM(Achievement_Value__c) ach
            FROM Secondary_Target__c
            WHERE Is_Active__c = true
              AND User__c IN :userIds
              AND Start_Date__c <= :monthEnd
              AND End_Date__c >= :monthStart
            GROUP BY User__c
        ]) {
            Id uid = (Id) ar.get('uid');
            out.put(uid, new Decimal[]{
                nzd((Decimal) ar.get('cnt')),
                nzd((Decimal) ar.get('tgt')),
                nzd((Decimal) ar.get('ach'))
            });
        }
        return out;
    }

    private static Map<Id, Decimal> perUserIncentiveTotals(Set<Id> userIds, Integer year, Integer month) {
        Map<Id, Decimal> out = new Map<Id, Decimal>();
        if (userIds == null || userIds.isEmpty()) return out;
        for (AggregateResult ar : [
            SELECT Executive__c uid, SUM(Credit_Amount__c) amt
            FROM Incentive_Credit__c
            WHERE Source__c = 'Secondary PBIS'
              AND Year__c = :year AND Month__c = :month
              AND Executive__c IN :userIds
            GROUP BY Executive__c
        ]) {
            out.put((Id) ar.get('uid'), nzd((Decimal) ar.get('amt')));
        }
        return out;
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
            if (acc.add(child)) collectDescendantRoles(child, parentToChildren, acc);
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
