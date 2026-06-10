/**
 * UI controller for the Secondary KPI Dashboard.
 *
 * Aggregates Secondary_Target__c achievements and Secondary PBIS Incentive_Credit__c
 * payouts up the Salesforce role hierarchy, so a manager / head sees their entire
 * downline's KPIs with a one-click drill-down into each direct subordinate team.
 *
 * Uses `without sharing` because a manager needs to see every subordinate's totals
 * even if the underlying records aren't shared to them directly. Only aggregate /
 * roll-up numbers leave the class — no detail SOQL bypasses sharing.
 */
public without sharing class SecondaryKpiDashboard_Controller {

    // ===== Wrappers =====

    public class Hero {
        @AuraEnabled public Integer totalUsers = 0;
        @AuraEnabled public Integer activeTargets = 0;
        @AuraEnabled public Decimal totalTarget = 0;
        @AuraEnabled public Decimal totalAchievement = 0;
        @AuraEnabled public Decimal achievementPct = 0;
        @AuraEnabled public Decimal totalIncentive = 0;
        @AuraEnabled public Integer incentiveLines = 0;
    }

    public class TeamRow {
        @AuraEnabled public Id leadUserId;
        @AuraEnabled public String leadUserName;
        @AuraEnabled public String leadRole;            // Profile.Name
        @AuraEnabled public String leadRoleLabel;       // UserRole.Name
        @AuraEnabled public Integer teamSize = 0;
        @AuraEnabled public Integer activeTargets = 0;
        @AuraEnabled public Decimal totalTarget = 0;
        @AuraEnabled public Decimal totalAchievement = 0;
        @AuraEnabled public Decimal achievementPct = 0;
        @AuraEnabled public Decimal totalIncentive = 0;
        @AuraEnabled public Boolean hasSubordinates = false;
    }

    public class UserRow {
        @AuraEnabled public Id userId;
        @AuraEnabled public String userName;
        @AuraEnabled public String role;
        @AuraEnabled public String channel;
        @AuraEnabled public Integer activeTargets = 0;
        @AuraEnabled public Decimal totalTarget = 0;
        @AuraEnabled public Decimal totalAchievement = 0;
        @AuraEnabled public Decimal achievementPct = 0;
        @AuraEnabled public Decimal totalIncentive = 0;
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

    public class Crumb {
        @AuraEnabled public Id userId;
        @AuraEnabled public String userName;
        @AuraEnabled public String role;
    }

    public class DashboardData {
        @AuraEnabled public Id rootUserId;
        @AuraEnabled public String rootUserName;
        @AuraEnabled public String rootRole;       // Profile.Name
        @AuraEnabled public String rootRoleLabel;  // UserRole.Name
        @AuraEnabled public Integer year;
        @AuraEnabled public Integer month;
        @AuraEnabled public String periodLabel;
        @AuraEnabled public Hero hero;
        @AuraEnabled public List<TeamRow> teams = new List<TeamRow>();
        @AuraEnabled public List<UserRow> topPerformers = new List<UserRow>();
        @AuraEnabled public List<UserRow> bottomPerformers = new List<UserRow>();
        @AuraEnabled public List<ChannelRow> channels = new List<ChannelRow>();
        @AuraEnabled public List<CriteriaRow> criteria = new List<CriteriaRow>();
    }

    // ===== Entry =====

    @AuraEnabled(cacheable=false)
    public static DashboardData getDashboard(Integer year, Integer month, Id rootUserId) {
        DashboardData out = new DashboardData();

        if (year == null || month == null || month < 1 || month > 12) {
            Date today = Date.today();
            year = today.year();
            month = today.month();
        }
        out.year = year;
        out.month = month;
        out.periodLabel = monthName(month) + ' ' + String.valueOf(year);

        // Default root = current user.
        if (rootUserId == null) rootUserId = UserInfo.getUserId();

        User root = [SELECT Id, Name, UserRoleId, UserRole.Name, Profile.Name
                     FROM User WHERE Id = :rootUserId LIMIT 1];
        out.rootUserId = root.Id;
        out.rootUserName = root.Name;
        out.rootRole = root.Profile != null ? root.Profile.Name : null;
        out.rootRoleLabel = root.UserRole != null ? root.UserRole.Name : null;

        Date monthStart = Date.newInstance(year, month, 1);
        Date monthEnd = monthStart.addMonths(1).addDays(-1);

        // Universe = root user + every descendingendant user under the role hierarchy.
        Set<Id> universeUserIds = collectDownlineUsers(root.UserRoleId);
        universeUserIds.add(root.Id);

        // Hero — totals across the entire universe.
        out.hero = buildHero(universeUserIds, monthStart, monthEnd, year, month);

        // Teams — one row per immediate-subordinate user (direct child role users).
        out.teams = buildTeams(root.UserRoleId, monthStart, monthEnd, year, month);

        // Per-user rollup across the whole universe — feeds top/bottom + per-user drill.
        List<UserRow> perUser = buildPerUserRows(universeUserIds, monthStart, monthEnd, year, month);
        out.topPerformers = topN(perUser, 5, true);
        out.bottomPerformers = topN(perUser, 5, false);

        out.channels = buildChannelRows(universeUserIds, monthStart, monthEnd);
        out.criteria = buildCriteriaRows(universeUserIds, monthStart, monthEnd);

        return out;
    }

    /**
     * Resolves the chain root → ... → user, so the LWC can render breadcrumbs without
     * walking the role tree on the client.
     */
    @AuraEnabled(cacheable=true)
    public static List<Crumb> getBreadcrumbs(Id userId) {
        List<Crumb> crumbs = new List<Crumb>();
        if (userId == null) return crumbs;

        User u = [SELECT Id, Name, UserRoleId, Profile.Name FROM User WHERE Id = :userId LIMIT 1];
        Id roleId = u.UserRoleId;
        if (roleId == null) {
            Crumb c = new Crumb();
            c.userId = u.Id; c.userName = u.Name;
            c.role = u.Profile != null ? u.Profile.Name : null;
            crumbs.add(c);
            return crumbs;
        }

        // Walk up the role hierarchy collecting one user per role (the first active one).
        Map<Id, UserRole> allRoles = new Map<Id, UserRole>(
            [SELECT Id, Name, ParentRoleId FROM UserRole]
        );
        List<Id> chainRoleIds = new List<Id>();
        Id cur = roleId;
        while (cur != null && allRoles.containsKey(cur)) {
            chainRoleIds.add(0, cur); // prepend → root first
            cur = allRoles.get(cur).ParentRoleId;
        }
        if (chainRoleIds.isEmpty()) chainRoleIds.add(roleId);

        Map<Id, User> oneUserPerRole = new Map<Id, User>();
        for (User x : [
            SELECT Id, Name, UserRoleId, Profile.Name
            FROM User
            WHERE UserRoleId IN :chainRoleIds AND IsActive = true
            ORDER BY Name
        ]) {
            if (!oneUserPerRole.containsKey(x.UserRoleId)) {
                oneUserPerRole.put(x.UserRoleId, x);
            }
        }

        for (Id rid : chainRoleIds) {
            User rep = oneUserPerRole.get(rid);
            if (rep == null) continue;
            // Only emit the ancestor chain up to (but not past) the requested user's own row.
            Crumb c = new Crumb();
            c.userId = rep.Id; c.userName = rep.Name;
            c.role = rep.Profile != null ? rep.Profile.Name : null;
            crumbs.add(c);
            if (rep.Id == u.Id) break;
        }
        // Ensure the requested user is the last crumb even if their role had no active user
        // representative selected above.
        if (crumbs.isEmpty() || crumbs[crumbs.size() - 1].userId != u.Id) {
            Crumb c = new Crumb();
            c.userId = u.Id; c.userName = u.Name;
            c.role = u.Profile != null ? u.Profile.Name : null;
            crumbs.add(c);
        }
        return crumbs;
    }

    // ===== Hero =====

    private static Hero buildHero(Set<Id> userIds, Date monthStart, Date monthEnd, Integer year, Integer month) {
        Hero h = new Hero();
        if (userIds == null || userIds.isEmpty()) return h;

        h.totalUsers = userIds.size();

        for (AggregateResult ar : [
            SELECT COUNT(Id) cnt,
                   SUM(Target_Value__c) tgt,
                   SUM(Achievement_Value__c) ach
            FROM Secondary_Target__c
            WHERE Is_Active__c = true
              AND User__c IN :userIds
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
              AND Executive__c IN :userIds
        ]) {
            h.totalIncentive = nzd((Decimal) ar.get('amt'));
            h.incentiveLines = nz((Integer) ar.get('cnt'));
        }
        return h;
    }

    // ===== Teams (direct subordinate users; each row drills to that user as the new root) =====

    private static List<TeamRow> buildTeams(Id rootRoleId, Date monthStart, Date monthEnd, Integer year, Integer month) {
        List<TeamRow> rows = new List<TeamRow>();
        if (rootRoleId == null) return rows;

        // Pre-build parent → children map once.
        Map<Id, Set<Id>> parentToChildren = buildParentChildMap();

        Set<Id> directChildRoles = parentToChildren.containsKey(rootRoleId)
            ? parentToChildren.get(rootRoleId) : new Set<Id>();
        if (directChildRoles.isEmpty()) return rows;

        // Active users assigned to those direct child roles.
        List<User> directUsers = [
            SELECT Id, Name, UserRoleId, UserRole.Name, Profile.Name
            FROM User
            WHERE UserRoleId IN :directChildRoles AND IsActive = true
            ORDER BY UserRole.Name, Name
        ];
        if (directUsers.isEmpty()) return rows;

        // For each direct user, compute their downline universe (their role's subtree).
        Map<Id, Set<Id>> userToUniverse = new Map<Id, Set<Id>>();
        Set<Id> allTeamUserIds = new Set<Id>();
        for (User du : directUsers) {
            Set<Id> downlineRoles = new Set<Id>();
            collectDescendantRoles(du.UserRoleId, parentToChildren, downlineRoles);
            Set<Id> teamUserIds = usersInRoles(downlineRoles);
            teamUserIds.add(du.Id);
            userToUniverse.put(du.Id, teamUserIds);
            allTeamUserIds.addAll(teamUserIds);
        }

        // Per-user target totals across the whole batch in one shot.
        Map<Id, Decimal[]> perUserTgt = perUserTargetTotals(allTeamUserIds, monthStart, monthEnd);
        Map<Id, Decimal> perUserIncentive = perUserIncentiveTotals(allTeamUserIds, year, month);

        for (User du : directUsers) {
            Set<Id> universe = userToUniverse.get(du.Id);
            TeamRow tr = new TeamRow();
            tr.leadUserId = du.Id;
            tr.leadUserName = du.Name;
            tr.leadRole = du.Profile != null ? du.Profile.Name : null;
            tr.leadRoleLabel = du.UserRole != null ? du.UserRole.Name : null;
            tr.teamSize = universe.size();
            tr.hasSubordinates = parentToChildren.containsKey(du.UserRoleId)
                                 && !parentToChildren.get(du.UserRoleId).isEmpty();
            Decimal tgt = 0, ach = 0, inc = 0;
            Integer atc = 0;
            for (Id uid : universe) {
                Decimal[] rec = perUserTgt.get(uid);
                if (rec != null) {
                    atc += rec[0].intValue();
                    tgt += rec[1];
                    ach += rec[2];
                }
                Decimal incAmt = perUserIncentive.get(uid);
                if (incAmt != null) inc += incAmt;
            }
            tr.activeTargets = atc;
            tr.totalTarget = tgt;
            tr.totalAchievement = ach;
            tr.achievementPct = pct(ach, tgt);
            tr.totalIncentive = inc;
            rows.add(tr);
        }
        return rows;
    }

    // ===== Per-user rollup (for top/bottom performer lists) =====

    private static List<UserRow> buildPerUserRows(Set<Id> userIds, Date monthStart, Date monthEnd, Integer year, Integer month) {
        List<UserRow> result = new List<UserRow>();
        if (userIds == null || userIds.isEmpty()) return result;

        Map<Id, Decimal[]> perUserTgt = perUserTargetTotals(userIds, monthStart, monthEnd);
        Map<Id, Decimal> perUserIncentive = perUserIncentiveTotals(userIds, year, month);

        // Only render users who actually have at least one active target or one incentive line.
        Set<Id> relevant = new Set<Id>();
        relevant.addAll(perUserTgt.keySet());
        relevant.addAll(perUserIncentive.keySet());
        if (relevant.isEmpty()) return result;

        Map<Id, User> profile = new Map<Id, User>([
            SELECT Id, Name, Profile.Name, Sales_Channel__c
            FROM User WHERE Id IN :relevant
        ]);

        for (Id uid : relevant) {
            UserRow ur = new UserRow();
            ur.userId = uid;
            User u = profile.get(uid);
            if (u != null) {
                ur.userName = u.Name;
                ur.role = u.Profile != null ? u.Profile.Name : null;
                ur.channel = u.Sales_Channel__c;
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
            result.add(ur);
        }
        return result;
    }

    /** Pick top or bottom N users by achievement %, requiring a non-zero target so empty users don't dominate. */
    private static List<UserRow> topN(List<UserRow> rows, Integer n, Boolean descending) {
        List<UserRow> filtered = new List<UserRow>();
        for (UserRow r : rows) if (r.totalTarget != null && r.totalTarget > 0) filtered.add(r);
        // Simple insertion sort — N ≤ tens of users on a typical screen, no need for fancier.
        for (Integer i = 1; i < filtered.size(); i++) {
            UserRow cur = filtered[i];
            Integer j = i - 1;
            while (j >= 0 && cmpPct(filtered[j], cur, descending) > 0) {
                filtered[j + 1] = filtered[j];
                j--;
            }
            filtered[j + 1] = cur;
        }
        List<UserRow> out = new List<UserRow>();
        for (Integer i = 0; i < filtered.size() && i < n; i++) out.add(filtered[i]);
        return out;
    }

    private static Integer cmpPct(UserRow a, UserRow b, Boolean descending) {
        Decimal pa = a.achievementPct == null ? 0 : a.achievementPct;
        Decimal pb = b.achievementPct == null ? 0 : b.achievementPct;
        if (pa == pb) return 0;
        Boolean aBigger = pa > pb;
        // Desc=true → bigger first → "a > b" means a should come earlier → return negative.
        if (descending) return aBigger ? -1 : 1;
        return aBigger ? 1 : -1;
    }

    // ===== Channel / Criteria breakdowns =====

    private static List<ChannelRow> buildChannelRows(Set<Id> userIds, Date monthStart, Date monthEnd) {
        List<ChannelRow> result = new List<ChannelRow>();
        if (userIds == null || userIds.isEmpty()) return result;

        // Aggregate target / achievement per channel, plus distinct users per channel.
        Map<String, ChannelRow> byChannel = new Map<String, ChannelRow>();
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
            byChannel.put(cr.channel == null ? '' : cr.channel, cr);
        }
        result.addAll(byChannel.values());
        return result;
    }

    private static List<CriteriaRow> buildCriteriaRows(Set<Id> userIds, Date monthStart, Date monthEnd) {
        List<CriteriaRow> result = new List<CriteriaRow>();
        if (userIds == null || userIds.isEmpty()) return result;

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
            result.add(cr);
        }
        return result;
    }

    // ===== Shared aggregate helpers =====

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
            Decimal[] rec = new Decimal[]{
                nzd((Decimal) ar.get('cnt')),
                nzd((Decimal) ar.get('tgt')),
                nzd((Decimal) ar.get('ach'))
            };
            out.put(uid, rec);
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

    // ===== Role hierarchy helpers =====

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

    /** Collect every active user under the given role's entire subtree (excluding the role itself). */
    private static Set<Id> collectDownlineUsers(Id rootRoleId) {
        Set<Id> userIds = new Set<Id>();
        if (rootRoleId == null) return userIds;
        Map<Id, Set<Id>> parentToChildren = buildParentChildMap();
        Set<Id> roleIds = new Set<Id>();
        collectDescendantRoles(rootRoleId, parentToChildren, roleIds);
        roleIds.add(rootRoleId);
        return usersInRoles(roleIds);
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
