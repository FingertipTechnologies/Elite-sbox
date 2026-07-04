/**
 * Backs the Primary KPI tab (primaryKpiDashboard LWC). Reads the already-computed
 * PBIS_Target__c calc fields (Task 4) for the logged-in user and, for managers, their
 * subordinates (role hierarchy) — no recompute. Mirrors SecondaryKpiDashboard_Controller's
 * PERSONAL / TEAM / EMPTY shape.
 */
public with sharing class PrimaryKpiDashboard_Controller {

    private static final Integer SLOTS = 10;

    // Admins start the My Team drill-down at the RSM tier; everyone else starts
    // at their own direct reportees.
    private static final String ADMIN_PROFILE = 'System Administrator';
    private static final Set<String> TOP_MANAGER_PROFILES = new Set<String>{
        'RSM', 'Sr. RSM', 'Deputy RSM'
    };
    // Sentinel option value: "show the aggregate of everyone at this level".
    private static final String ALL_OPTION = 'ALL';

    // ===== wrappers =====
    public class Dashboard {
        @AuraEnabled public String mode;                 // PERSONAL | TEAM | EMPTY
        @AuraEnabled public Boolean viewerIsManager;
        @AuraEnabled public Boolean viewerIsAdmin;
        @AuraEnabled public String periodLabel;
        @AuraEnabled public String selectedUserName;
        @AuraEnabled public Hero hero;
        @AuraEnabled public List<ParamRow> parameters;
        @AuraEnabled public List<TeamRow> team;
        @AuraEnabled public List<BreakdownRow> channels;       // team: Sales Channel wise
        @AuraEnabled public List<BreakdownRow> paramBreakdown; // team: S&D Parameter wise
        @AuraEnabled public List<Option> userPickerOptions;

        // My Team cascade drill-down: one picker per level, top → bottom.
        @AuraEnabled public List<TeamPicker> teamPickers;
        @AuraEnabled public Boolean teamShowsPersonal;     // a picked user's own record is shown
    }
    // One level of the My Team drill-down. `options` are the direct reportees to
    // choose from at this level; `selectedUserId` is the choice already made (if any).
    public class TeamPicker {
        @AuraEnabled public Integer level;
        @AuraEnabled public String label;
        @AuraEnabled public String selectedUserId;   // a userId, or the ALL sentinel
        @AuraEnabled public List<Option> options;
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
        @AuraEnabled public String slab;            // snapshot band "from - to"
        @AuraEnabled public Decimal incentivePct;   // snapshot slab incentive %
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

    // Whether the running user participates in Primary PBIS — payroll employees do.
    // The KPI Dashboard tab wrapper uses this to decide if the Primary tab shows.
    @AuraEnabled(cacheable=true)
    public static Boolean currentUserShowsPrimary() {
        List<User> us = [SELECT Payroll__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        return !us.isEmpty() && us[0].Payroll__c == 'Yes';
    }

    @AuraEnabled(cacheable=false)
    public static Dashboard getDashboard(Integer year, Integer month, String incentivePeriod,
                                         Id viewUserId, List<Id> teamPath) {
        Dashboard d = new Dashboard();
        Id me = UserInfo.getUserId();
        if (year == null) year = Date.today().year();
        if (month == null) month = Date.today().month();
        if (String.isBlank(incentivePeriod)) incentivePeriod = 'Monthly';
        Date monthStart = Date.newInstance(year, month, 1);
        d.periodLabel = monthLabel(month) + ' ' + year + ' · ' + incentivePeriod;

        // Viewer profile → decides where the My Team drill-down starts.
        User meUser = [SELECT Id, Name, Profile.Name FROM User WHERE Id = :me LIMIT 1];
        d.viewerIsAdmin = meUser.Profile != null && meUser.Profile.Name == ADMIN_PROFILE;

        // Strict subordinates = users in roles below the viewer's role.
        Set<Id> subordinateIds = subordinatesOf(me);
        d.viewerIsManager = !subordinateIds.isEmpty() || d.viewerIsAdmin;

        // Flat downline list — drives the existing "User Search" combobox.
        d.userPickerOptions = new List<Option>();
        if (!subordinateIds.isEmpty()) {
            for (User u : [SELECT Id, Name FROM User WHERE Id IN :subordinateIds ORDER BY Name]) {
                Option o = new Option();
                o.label = u.Name;
                o.userId = u.Id;
                d.userPickerOptions.add(o);
            }
        }

        // ===== My Team drill-down (cascading direct-reportee pickers) =====
        List<Id> path = (teamPath == null) ? new List<Id>() : teamPath;
        Boolean hasPath = !path.isEmpty();
        d.teamPickers = buildTeamPickers(me, d.viewerIsAdmin, path);

        // The deepest picked user is the focus. The team table shows only the
        // focus's DIRECT reportees (one level) so the drill goes down step by step:
        //   - admin, "All" → the regional managers (RSM tier),
        //   - a picked user → that user's direct reportees,
        //   - other manager, "All" → the viewer's own direct reportees.
        Id teamFocusId = hasPath ? path[path.size() - 1] : null;
        Set<Id> teamMembers;
        if (hasPath) {
            teamMembers = directReporteeIds(teamFocusId);
        } else if (d.viewerIsAdmin) {
            teamMembers = topManagerUserIds();
        } else {
            teamMembers = directReporteeIds(me);
        }

        // A specifically picked user also shows their OWN record — not just the
        // (possibly empty) team below them.
        Id personalFocusId = hasPath ? teamFocusId : ((viewUserId != null) ? viewUserId : me);

        // Targets active in the chosen month for everything we may render (one SOQL).
        Set<Id> queryIds = new Set<Id>(subordinateIds);
        queryIds.add(me);
        queryIds.addAll(teamMembers);
        if (teamFocusId != null) queryIds.add(teamFocusId);
        if (viewUserId != null) queryIds.add(viewUserId);
        Map<Id, PBIS_Target__c> targetByUser = new Map<Id, PBIS_Target__c>();
        for (PBIS_Target__c t : queryTargets(queryIds, incentivePeriod, monthStart)) {
            targetByUser.put(t.User__c, t);
        }
        if (targetByUser.isEmpty()) {
            // Nothing to show anywhere — but keep the drill pickers so a manager
            // can still navigate the hierarchy.
            d.mode = 'EMPTY';
            return d;
        }

        // Team analytics over the focus's direct reportees.
        if (!teamMembers.isEmpty()) {
            d.mode = 'TEAM';
            d.team = buildTeamRows(teamMembers, targetByUser);
            d.channels = buildChannelBreakdown(teamMembers, targetByUser);
            d.paramBreakdown = buildParamBreakdown(teamMembers, targetByUser);
        } else {
            d.mode = d.viewerIsManager ? 'TEAM' : 'PERSONAL';
        }

        // Personal detail:
        //   - team drill on a specific user → that user's own record,
        //   - My / User Search → the viewer or the searched user.
        PBIS_Target__c ft = targetByUser.get(personalFocusId);
        if (ft == null && !d.viewerIsManager) {
            d.mode = 'EMPTY';
            return d;
        }
        if (ft != null) {
            d.selectedUserName = userName(personalFocusId);
            d.hero = buildHero(ft);
            d.parameters = buildParams(ft);
        } else if (hasPath) {
            // Selected user with no target this period — still name them for the header.
            d.selectedUserName = userName(personalFocusId);
        }
        // Inside My Team, surface the selected user's own record when they have one.
        d.teamShowsPersonal = hasPath && d.hero != null;
        return d;
    }

    // ===== My Team drill-down helpers =====

    // One picker per level of the drill, top → bottom. Each reportee picker also
    // carries an "All" entry so the viewer can drop back to the level's aggregate.
    // The loop adds a picker for the direct reportees of each selection, and a
    // final "All"-defaulted picker for the deepest selection's reportees.
    private static List<TeamPicker> buildTeamPickers(Id me, Boolean isAdmin, List<Id> path) {
        List<TeamPicker> pickers = new List<TeamPicker>();
        List<Option> reps = topLevelOptions(me, isAdmin);
        Integer level = 0;
        while (reps != null && !reps.isEmpty()) {
            // Every picker offers "All" to drop back to that level's aggregate —
            // including the admin's top RSM picker (default = all regional managers).
            Boolean includeAll = true;
            TeamPicker tp = new TeamPicker();
            tp.level = level;
            tp.label = pickerLabel(level, isAdmin);
            tp.options = new List<Option>();
            if (includeAll) tp.options.add(makeAllOption());
            tp.options.addAll(reps);
            if (level < path.size()) {
                tp.selectedUserId = path[level];
            } else {
                // No specific choice at this level yet → show "All" (the aggregate).
                tp.selectedUserId = includeAll ? ALL_OPTION : null;
            }
            pickers.add(tp);
            if (level >= path.size()) break;   // this level is the aggregate — stop
            reps = directReporteeOptions(path[level]);
            level++;
        }
        return pickers;
    }

    private static Option makeAllOption() {
        Option o = new Option();
        o.userId = ALL_OPTION;
        o.label = 'All';
        return o;
    }

    // The regional managers (RSM tier) — the top level of the admin's drill.
    private static Set<Id> topManagerUserIds() {
        Set<Id> ids = new Set<Id>();
        for (User u : [
            SELECT Id FROM User
            WHERE IsActive = true AND Profile.Name IN :TOP_MANAGER_PROFILES
        ]) {
            ids.add(u.Id);
        }
        return ids;
    }

    // Direct reportees (one level down) as a user-id set — the same universe the
    // level's picker offers, so the team table and the picker stay in step.
    private static Set<Id> directReporteeIds(Id userId) {
        Set<Id> ids = new Set<Id>();
        Set<Id> childRoleIds = directChildRoleIds(userId);
        if (childRoleIds.isEmpty()) return ids;
        for (User u : [SELECT Id FROM User WHERE UserRoleId IN :childRoleIds AND IsActive = true]) {
            ids.add(u.Id);
        }
        return ids;
    }

    private static String pickerLabel(Integer level, Boolean isAdmin) {
        if (level == 0) return isAdmin ? 'Regional Sales Manager' : 'Team Member';
        return 'Reportee';
    }

    // Level-0 options: RSM tier for admins, own direct reportees for everyone else.
    private static List<Option> topLevelOptions(Id me, Boolean isAdmin) {
        if (!isAdmin) return directReporteeOptions(me);
        List<Option> opts = new List<Option>();
        for (User u : [
            SELECT Id, Name, Profile.Name
            FROM User
            WHERE IsActive = true AND Profile.Name IN :TOP_MANAGER_PROFILES
            ORDER BY Name
        ]) {
            opts.add(makeOption(u.Id, u.Name, u.Profile != null ? u.Profile.Name : null));
        }
        return opts;
    }

    // Direct reportees = active users in roles immediately below the given user's role.
    private static List<Option> directReporteeOptions(Id userId) {
        List<Option> opts = new List<Option>();
        Set<Id> childRoleIds = directChildRoleIds(userId);
        if (childRoleIds.isEmpty()) return opts;
        for (User u : [
            SELECT Id, Name, Profile.Name
            FROM User
            WHERE UserRoleId IN :childRoleIds AND IsActive = true
            ORDER BY Name
        ]) {
            opts.add(makeOption(u.Id, u.Name, u.Profile != null ? u.Profile.Name : null));
        }
        return opts;
    }

    private static Set<Id> directChildRoleIds(Id userId) {
        Set<Id> ids = new Set<Id>();
        List<User> us = [SELECT UserRoleId FROM User WHERE Id = :userId LIMIT 1];
        if (us.isEmpty() || us[0].UserRoleId == null) return ids;
        for (UserRole r : [SELECT Id FROM UserRole WHERE ParentRoleId = :us[0].UserRoleId]) {
            ids.add(r.Id);
        }
        return ids;
    }

    // Label a picker option as "Name (Profile)".
    private static Option makeOption(Id userId, String name, String profileName) {
        Option o = new Option();
        o.userId = userId;
        o.label = String.isNotBlank(profileName) ? name + ' (' + profileName + ')' : name;
        return o;
    }

    // ===== Team analytics builders =====

    private static List<TeamRow> buildTeamRows(Set<Id> userIds, Map<Id, PBIS_Target__c> targetByUser) {
        List<TeamRow> rows = new List<TeamRow>();
        if (userIds.isEmpty()) return rows;
        Map<Id, User> uMap = new Map<Id, User>([
            SELECT Id, Name, UserRole.Name FROM User WHERE Id IN :userIds
        ]);
        for (Id uid : userIds) {
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
            rows.add(tr);
        }
        return rows;
    }

    private static List<BreakdownRow> buildChannelBreakdown(Set<Id> userIds, Map<Id, PBIS_Target__c> targetByUser) {
        Map<String, Decimal[]> chAgg = new Map<String, Decimal[]>();   // [incSum, pctSum, count]
        for (Id uid : userIds) {
            PBIS_Target__c t = targetByUser.get(uid);
            if (t == null) continue;
            String ch = (String) t.get('Sales_Channel__c');
            accumulate(chAgg, String.isBlank(ch) ? '— No channel —' : ch,
                nz(t.Total_Incentive_Value__c), weightedPct(t));
        }
        return toBreakdownRows(chAgg);
    }

    private static List<BreakdownRow> buildParamBreakdown(Set<Id> userIds, Map<Id, PBIS_Target__c> targetByUser) {
        Map<String, Decimal[]> pmAgg = new Map<String, Decimal[]>();
        for (Id uid : userIds) {
            PBIS_Target__c t = targetByUser.get(uid);
            if (t == null) continue;
            for (Integer n = 1; n <= SLOTS; n++) {
                if (t.get('S_D_Parameter_' + n + '__c') == null) continue;
                SObject p = t.getSObject('S_D_Parameter_' + n + '__r');
                String pname = p != null ? (String) p.get('Name') : ('Slot ' + n);
                accumulate(pmAgg, pname,
                    nz((Decimal) t.get('S_D_Parameter_' + n + '_Incentive_Amount__c')),
                    nz((Decimal) t.get('S_D_Parameter_' + n + '_Achievement_Percent__c')));
            }
        }
        return toBreakdownRows(pmAgg);
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
            String band = (String) t.get('S_D_Parameter_' + n + '_Slab__c');
            r.slab = String.isBlank(band) ? '—' : band;
            r.incentivePct = nz((Decimal) t.get('S_D_Parameter_' + n + '_Incentive_Percentage__c'));
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
            fields.add('S_D_Parameter_' + n + '_Slab__c');
            fields.add('S_D_Parameter_' + n + '_Incentive_Percentage__c');
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