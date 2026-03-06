import 'package:flutter/foundation.dart';
import '../models/models.dart';

class AppProvider extends ChangeNotifier {
  // ─── Current User (현재 로그인 사용자) ─────────────────────
  AppUser _currentUser = AppUser(
    id: 'u1', name: '김지수', email: 'jisu@company.com',
    avatarInitials: '김지', avatarColor: '#00BFA5',
    jobTitle: JobTitle.teamLead, department: '마케팅팀',
  );

  // ─── Data ──────────────────────────────────────────────────
  final List<AppUser> _allUsers = [];
  final List<Team> _teams = [];
  final List<KpiModel> _kpis = [];
  final List<CampaignModel> _campaigns = [];
  final List<FunnelStage> _funnelStages = [];
  final List<MonthlyData> _monthlyData = [];
  final List<MonthlyKpiRecord> _monthlyKpiRecords = [];

  // ─── 새 기능 데이터 ─────────────────────────────────────────
  final List<DmConversation> _dmConversations = [];
  final List<AppNotification> _notifications = [];
  final List<AiMessage> _aiMessages = [];
  bool _aiPanelOpen = false;
  bool _notificationPanelOpen = false;
  String? _activeDmUserId;

  // ─── 환율 설정 ─────────────────────────────────────────────
  GlobalExchangeRateConfig _globalRates = GlobalExchangeRateConfig.defaults();
  // projectId+year → AnnualExchangeRateConfig
  final Map<String, AnnualExchangeRateConfig> _annualRates = {};

  // ─── 마케팅 권역 & 고객사 ─────────────────────────────────
  final List<MarketingRegion> _regions = [];
  final List<ClientAccount> _clients = [];
  final List<ProjectRevenueEntry> _revenueEntries = [];

  // ─── 대시보드 위젯 설정 ────────────────────────────────────
  DashboardConfig _dashboardConfig = DashboardConfig.defaults();

  // ─── UI State ──────────────────────────────────────────────
  String? _selectedTeamId;
  String? _selectedProjectId;
  String? _selectedTaskId;
  String _currentSection = 'dashboard';
  String _selectedKpiTrackerId = 'kpi1';
  String _selectedPeriod = 'Q1 2025';
  // 'YYYY' 형태 연도 또는 'Q1 YYYY' 형태 쿼터
  String _selectedYear = '2025';
  String? _selectedQuarter; // null = 연간 전체

  // ─── Getters ───────────────────────────────────────────────
  AppUser get currentUser => _currentUser;
  List<AppUser> get allUsers => _allUsers;
  List<Team> get teams => _teams;
  List<KpiModel> get kpis => _kpis;
  List<KpiModel> get teamKpis => _kpis.where((k) => k.isTeamKpi).toList();
  List<KpiModel> get personalKpis => _kpis.where((k) => !k.isTeamKpi).toList();
  List<CampaignModel> get campaigns => _campaigns;
  List<FunnelStage> get funnelStages => _funnelStages;
  List<MonthlyData> get monthlyData => _monthlyData;
  List<MonthlyKpiRecord> get monthlyKpiRecords => _monthlyKpiRecords;
  List<DmConversation> get dmConversations => _dmConversations;
  List<AppNotification> get notifications => _notifications;
  List<AppNotification> get unreadNotifications => _notifications.where((n) => !n.isRead).toList();
  int get unreadNotificationCount => unreadNotifications.length;
  List<AiMessage> get aiMessages => _aiMessages;
  bool get aiPanelOpen => _aiPanelOpen;
  bool get notificationPanelOpen => _notificationPanelOpen;
  String? get activeDmUserId => _activeDmUserId;
  String? get selectedTeamId => _selectedTeamId;
  String? get selectedProjectId => _selectedProjectId;
  String? get selectedTaskId => _selectedTaskId;

  // 권역/고객 Getters
  List<MarketingRegion> get regions => _regions;
  List<ClientAccount> get clients => _clients;
  List<ClientAccount> get activeClients => _clients.where((c) => c.isActive).toList();
  List<ProjectRevenueEntry> get revenueEntries => _revenueEntries;

  // 대시보드 설정 Getter
  DashboardConfig get dashboardConfig => _dashboardConfig;

  // 전체 CostEntry 수집 (모든 프로젝트+태스크)
  List<CostWithMeta> get allCostEntries {
    final result = <CostWithMeta>[];
    for (final proj in _projectStore) {
      for (final task in proj.tasks) {
        for (final ce in task.costEntries) {
          result.add(CostWithMeta(entry: ce, projectId: proj.id, taskId: task.id, taskTitle: task.title, projectName: proj.name));
        }
      }
      for (final ce in proj.projectCosts) {
        result.add(CostWithMeta(entry: ce, projectId: proj.id, taskId: null, taskTitle: null, projectName: proj.name));
      }
    }
    return result;
  }

  // 권역별 비용 집계
  Map<String, double> get costByRegion {
    final map = <String, double>{};
    for (final cm in allCostEntries) {
      final key = cm.entry.region ?? '미분류';
      map[key] = (map[key] ?? 0) + getAmountInKrwForEntry(cm.entry, cm.projectId);
    }
    return map;
  }

  // 나라별 비용 집계
  Map<String, double> get costByCountry {
    final map = <String, double>{};
    for (final cm in allCostEntries) {
      final key = cm.entry.country ?? '미분류';
      map[key] = (map[key] ?? 0) + getAmountInKrwForEntry(cm.entry, cm.projectId);
    }
    return map;
  }

  // 고객별 비용 집계
  Map<String, double> get costByClient {
    final map = <String, double>{};
    for (final cm in allCostEntries) {
      final key = cm.entry.clientId ?? '미할당';
      map[key] = (map[key] ?? 0) + getAmountInKrwForEntry(cm.entry, cm.projectId);
    }
    return map;
  }

  // 특정 고객의 전체 투자비용
  double clientTotalCost(String clientId) => costByClient[clientId] ?? 0;

  // 특정 고객의 ROI = (매출 - 비용) / 비용 * 100
  double clientRoi(String clientId) {
    final cost = clientTotalCost(clientId);
    final client = _clients.where((c) => c.id == clientId).firstOrNull;
    if (client == null || cost == 0) return 0;
    return (client.revenue - cost) / cost * 100;
  }

  // 환율 Getters
  GlobalExchangeRateConfig get globalRates => _globalRates;
  Map<String, AnnualExchangeRateConfig> get annualRates => _annualRates;

  static String _annualKey(String projectId, String year) => '${projectId}_$year';

  AnnualExchangeRateConfig getAnnualRate(String projectId, String year) {
    final key = _annualKey(projectId, year);
    return _annualRates[key] ?? AnnualExchangeRateConfig(
      year: year, projectId: projectId,
      baseCurrency: CurrencyCode.krw,
      rates: Map.from(_globalRates.rates),
      updatedAt: DateTime.now(),
    );
  }

  double getRateToKrw(CurrencyCode currency) => _globalRates.getRateFor(currency);
  double get usdToKrw => _globalRates.getRateFor(CurrencyCode.usd);

  void updateGlobalRate(CurrencyCode currency, double rateToKrw) {
    final newRates = Map<String, double>.from(_globalRates.rates);
    newRates[currency.code] = rateToKrw;
    _globalRates = GlobalExchangeRateConfig(rates: newRates, updatedAt: DateTime.now());
    notifyListeners();
  }

  void updateAnnualRate(String projectId, String year, CurrencyCode currency, double rate) {
    final key = _annualKey(projectId, year);
    final existing = _annualRates[key];
    final newRates = Map<String, double>.from(existing?.rates ?? _globalRates.rates);
    newRates[currency.code] = rate;
    _annualRates[key] = AnnualExchangeRateConfig(
      year: year, projectId: projectId,
      baseCurrency: existing?.baseCurrency ?? CurrencyCode.krw,
      rates: newRates, updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  void setAnnualBaseCurrency(String projectId, String year, CurrencyCode base) {
    final key = _annualKey(projectId, year);
    final existing = _annualRates[key];
    _annualRates[key] = AnnualExchangeRateConfig(
      year: year, projectId: projectId,
      baseCurrency: base,
      rates: existing?.rates ?? Map.from(_globalRates.rates),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // ─── 태스크 탐색 헬퍼 ─────────────────────────────────────
  List<TaskWithProject> getTasksByKpiId(String kpiId) {
    final result = <TaskWithProject>[];
    for (final proj in _projectStore) {
      for (final task in proj.tasks) {
        if (task.kpiId == kpiId) result.add(TaskWithProject(task: task, project: proj));
      }
    }
    return result;
  }

  List<TaskWithProject> getTasksByCampaignId(String campaignId) {
    final result = <TaskWithProject>[];
    final campaign = _campaigns.firstWhere((c) => c.id == campaignId, orElse: () => _campaigns.first);
    final lower = campaign.name.toLowerCase();
    for (final proj in _projectStore) {
      for (final task in proj.tasks) {
        final matches = task.tags.any((t) => t.toLowerCase().contains(lower)) ||
            task.title.toLowerCase().contains(lower) ||
            proj.name.toLowerCase().contains(lower);
        if (matches) result.add(TaskWithProject(task: task, project: proj));
      }
    }
    return result;
  }

  List<TaskWithProject> get allTasksWithProject {
    final result = <TaskWithProject>[];
    for (final proj in _projectStore) {
      for (final task in proj.tasks) {
        result.add(TaskWithProject(task: task, project: proj));
      }
    }
    return result;
  }

  void navigateToTask(String taskId) {
    for (final proj in _projectStore) {
      for (final task in proj.tasks) {
        if (task.id == taskId) {
          _selectedProjectId = proj.id;
          _selectedTeamId = proj.teamId;
          _selectedTaskId = taskId;
          _currentSection = 'task_detail';
          notifyListeners();
          return;
        }
      }
    }
  }

  /// 프로젝트+연도 기반 경영환율 적용 (집행환율 없을 때 자동 대체)
  double getEffectiveRateForTask(String projectId, CurrencyCode currency, DateTime date) {
    final year = date.year.toString();
    final annual = _annualRates['${projectId}_$year'];
    if (annual != null) {
      return annual.getRateFor(currency);
    }
    return _globalRates.getRateFor(currency);
  }

  /// CostEntry의 실효 원화금액 (집행환율 → 프로젝트경영환율 → 글로벌환율 순 우선)
  double getAmountInKrwForEntry(CostEntry entry, String? projectId) {
    if (entry.currency == CurrencyCode.krw) return entry.amount;
    if (entry.executionRate != null) return entry.amount * entry.executionRate!;
    if (projectId != null) {
      final rate = getEffectiveRateForTask(projectId, entry.currency, entry.date);
      return entry.amount * rate;
    }
    return entry.amount * _globalRates.getRateFor(entry.currency);
  }

  /// 특정 기준통화로 환산 (KRW 기준 중간 환산)
  double convertToBaseCurrency(double krwAmount, CurrencyCode baseCurrency) {
    if (baseCurrency == CurrencyCode.krw) return krwAmount;
    final rate = _globalRates.getRateFor(baseCurrency);
    return rate > 0 ? krwAmount / rate : krwAmount;
  }
  String get currentSection => _currentSection;
  String get selectedKpiTrackerId => _selectedKpiTrackerId;
  String get selectedPeriod => _selectedPeriod;
  String get selectedYear => _selectedYear;
  String? get selectedQuarter => _selectedQuarter; // null = 연간

  // ─── 사용 가능한 연도 목록 ─────────────────────────────────
  List<String> get availableYears {
    final years = _monthlyData
        .map((d) => _parseYearFromMonthKey(d.monthKey))
        .whereType<String>()
        .toSet()
        .toList();
    years.sort();
    if (years.isEmpty) return ['2024', '2025'];
    return years;
  }

  static String? _parseYearFromMonthKey(String? key) {
    if (key == null) return null;
    final parts = key.split('-');
    if (parts.length == 2) return parts[0];
    return null;
  }

  Team? get selectedTeam =>
      _selectedTeamId != null ? _teams.firstWhere((t) => t.id == _selectedTeamId, orElse: () => _teams.first) : null;

  Project? get selectedProject {
    if (_selectedProjectId == null || selectedTeam == null) return null;
    final allProjects = selectedTeam!.projectIds;
    for (final team in _teams) {
      for (final proj in _getTeamProjects(team.id)) {
        if (proj.id == _selectedProjectId) return proj;
      }
    }
    return null;
  }

  List<Project> _projectStore = [];
  List<Project> get projectStore => _projectStore;

  List<Project> _getTeamProjects(String teamId) =>
      _projectStore.where((p) => p.teamId == teamId).toList();

  List<Project> getProjectsForTeam(String teamId) =>
      _projectStore.where((p) => p.teamId == teamId).toList();

  Project? getProjectById(String id) =>
      _projectStore.firstWhere((p) => p.id == id, orElse: () => _projectStore.first);

  AppUser? getUserById(String id) =>
      _allUsers.firstWhere((u) => u.id == id, orElse: () => _currentUser);

  // ─── Dashboard Stats ───────────────────────────────────────
  double get totalBudget => _campaigns.fold(0, (s, c) => s + c.budget);
  double get totalSpent => _campaigns.fold(0, (s, c) => s + c.spent);
  double get totalRevenue => _campaigns.fold(0, (s, c) => s + c.revenue);
  double get overallRoi => totalSpent > 0 ? ((totalRevenue - totalSpent) / totalSpent * 100) : 0;
  double get avgKpiAchievement => _kpis.isEmpty ? 0 : _kpis.fold(0.0, (s, k) => s + k.achievementRate) / _kpis.length;
  int get activeCampaigns => _campaigns.where((c) => c.status == 'active').length;
  int get totalTasks => _projectStore.fold(0, (s, p) => s + p.tasks.length);
  int get doneTasks => _projectStore.fold(0, (s, p) => s + p.tasks.where((t) => t.status == TaskStatus.done).length);

  List<MonthlyKpiRecord> getMonthlyRecordsForKpi(String kpiId) =>
      _monthlyKpiRecords.where((r) => r.kpiId == kpiId).toList()
        ..sort((a, b) => a.month.compareTo(b.month));

  // ─── 기간 필터링된 월별 데이터 ─────────────────────────────
  /// selectedYear + selectedQuarter 에 맞는 MonthlyData 리스트 반환
  List<MonthlyData> get filteredMonthlyData {
    final qMonths = _quarterMonths(_selectedYear, _selectedQuarter);
    if (qMonths == null) {
      // 연간 전체: 해당 연도 모든 달
      return _monthlyData.where((d) {
        final y = _parseYearFromMonthKey(d.monthKey);
        return y == _selectedYear;
      }).toList()
        ..sort((a, b) => (a.monthKey ?? '').compareTo(b.monthKey ?? ''));
    }
    return _monthlyData.where((d) => qMonths.contains(d.monthKey)).toList()
      ..sort((a, b) => (a.monthKey ?? '').compareTo(b.monthKey ?? ''));
  }

  /// 현재 기간의 집계 매출
  double get periodRevenue => filteredMonthlyData.fold(0, (s, d) => s + d.revenue);
  double get periodAdSpend => filteredMonthlyData.fold(0, (s, d) => s + d.adSpend);
  int get periodLeads => filteredMonthlyData.fold(0, (s, d) => s + d.leads);
  double get periodRoi => periodAdSpend > 0 ? ((periodRevenue - periodAdSpend) / periodAdSpend * 100) : 0;

  /// 쿼터에 해당하는 monthKey 목록 반환, null이면 연간
  static List<String>? _quarterMonths(String year, String? quarter) {
    if (quarter == null) return null;
    final Map<String, List<int>> qMap = {
      'Q1': [1, 2, 3],
      'Q2': [4, 5, 6],
      'Q3': [7, 8, 9],
      'Q4': [10, 11, 12],
    };
    final months = qMap[quarter];
    if (months == null) return null;
    return months.map((m) => '$year-${m.toString().padLeft(2, '0')}').toList();
  }

  // ─── Risk TOP 5 ────────────────────────────────────────────
  List<RiskItem> get top5RiskItems {
    final risks = <RiskItem>[];
    final now = DateTime.now();
    for (final proj in _projectStore) {
      for (final task in proj.tasks) {
        if (task.status == TaskStatus.done) continue;
        double score = 0;
        final reasons = <String>[];
        final daysLeft = task.dueDate?.difference(now).inDays ?? 999;
        if (task.isOverdue) { score += (40 + daysLeft.abs() * 3).clamp(40, 70).toDouble(); reasons.add('${daysLeft.abs()}일 지연'); }
        else if (daysLeft <= 1) { score += 35; reasons.add('D-Day'); }
        else if (daysLeft <= 3) { score += 25; reasons.add('3일 내 마감'); }
        else if (daysLeft <= 7) { score += 15; reasons.add('7일 내 마감'); }
        final cp = task.checklistProgress;
        if (cp < 20 && daysLeft <= 5) { score += 28; reasons.add('진행률 ${cp.toInt()}%'); }
        else if (cp < 50 && task.isOverdue) { score += 15; reasons.add('진행률 ${cp.toInt()}%'); }
        if (task.priority == TaskPriority.urgent) score += 18;
        else if (task.priority == TaskPriority.high) score += 12;
        if (score > 10) {
          final assigneeName = task.assigneeIds.isNotEmpty
              ? (getUserById(task.assigneeIds.first)?.name ?? '미배정') : '미배정';
          risks.add(RiskItem(
            id: task.id, title: task.title, type: 'task',
            assignedTo: assigneeName, riskScore: score.clamp(0, 100),
            riskLevel: score >= 70 ? 'critical' : score >= 45 ? 'high' : 'medium',
            reason: reasons.join(' · '), dueDate: task.dueDate,
            progressPercent: task.checklistProgress,
          ));
        }
      }
    }
    for (final kpi in _kpis) {
      final rate = kpi.achievementRate;
      final daysLeft = kpi.dueDate.difference(now).inDays;
      double score = 0; final reasons = <String>[];
      if (rate < 50) { score += 45; reasons.add('달성률 ${rate.toStringAsFixed(0)}%'); }
      else if (rate < 65) { score += 30; reasons.add('달성률 ${rate.toStringAsFixed(0)}%'); }
      else if (rate < 80) { score += 15; reasons.add('달성률 ${rate.toStringAsFixed(0)}%'); }
      if (daysLeft <= 7 && rate < 80) { score += 20; reasons.add('${daysLeft}일 내 마감'); }
      if (kpi.isTeamKpi) score += 8;
      if (score > 10) {
        risks.add(RiskItem(
          id: kpi.id, title: kpi.title, type: 'kpi',
          assignedTo: kpi.assignedTo != null ? (getUserById(kpi.assignedTo!)?.name ?? '팀 전체') : '팀 전체',
          riskScore: score.clamp(0, 100),
          riskLevel: score >= 60 ? 'critical' : score >= 35 ? 'high' : 'medium',
          reason: reasons.join(' · '), dueDate: kpi.dueDate,
          kpiAchievementRate: rate,
        ));
      }
    }
    risks.sort((a, b) => b.riskScore.compareTo(a.riskScore));
    return risks.take(5).toList();
  }

  // ─── Navigation ────────────────────────────────────────────
  void navigateTo(String section, {String? teamId, String? projectId, String? taskId}) {
    _currentSection = section;
    if (teamId != null) _selectedTeamId = teamId;
    if (projectId != null) _selectedProjectId = projectId;
    if (taskId != null) _selectedTaskId = taskId;
    notifyListeners();
  }

  void selectTeam(String teamId) {
    _selectedTeamId = teamId;
    _selectedProjectId = null;
    _selectedTaskId = null;
    _currentSection = 'team_detail';
    notifyListeners();
  }

  void selectProject(String projectId) {
    _selectedProjectId = projectId;
    _selectedTaskId = null;
    _currentSection = 'project_detail';
    notifyListeners();
  }

  void selectTask(String taskId) {
    _selectedTaskId = taskId;
    _currentSection = 'task_detail';
    notifyListeners();
  }

  void setPeriod(String p) { _selectedPeriod = p; notifyListeners(); }
  void selectKpiForTracker(String id) { _selectedKpiTrackerId = id; notifyListeners(); }

  /// 연도+쿼터 선택. quarter == null 이면 연간 전체 보기
  void setYearQuarter(String year, String? quarter) {
    _selectedYear = year;
    _selectedQuarter = quarter;
    // 기존 selectedPeriod 도 동기화 (KPI 페이지 등 참조용)
    _selectedPeriod = quarter != null ? '$quarter $year' : year;
    notifyListeners();
  }

  // ─── Team CRUD ─────────────────────────────────────────────
  void createTeam({required String name, required String description,
    required String colorHex, required String iconEmoji}) {
    final team = Team(
      id: 'team_${DateTime.now().millisecondsSinceEpoch}',
      name: name, description: description,
      colorHex: colorHex, iconEmoji: iconEmoji,
      members: [TeamMember(
        id: 'tm_${DateTime.now().millisecondsSinceEpoch}',
        user: _currentUser, role: MemberRole.owner,
        joinedAt: DateTime.now(),
      )],
      projectIds: [], createdAt: DateTime.now(),
    );
    _teams.add(team);
    notifyListeners();
  }

  void inviteMember(String teamId, String userId, MemberRole role) {
    final team = _teams.firstWhere((t) => t.id == teamId, orElse: () => _teams.first);
    final user = _allUsers.firstWhere((u) => u.id == userId, orElse: () => _allUsers.first);
    team.members.add(TeamMember(
      id: 'tm_${DateTime.now().millisecondsSinceEpoch}',
      user: user, role: role, joinedAt: DateTime.now(),
    ));
    notifyListeners();
  }

  void updateMemberRole(String teamId, String memberId, MemberRole newRole) {
    final team = _teams.firstWhere((t) => t.id == teamId, orElse: () => _teams.first);
    final idx = team.members.indexWhere((m) => m.id == memberId);
    if (idx >= 0) { team.members[idx] = team.members[idx].copyWith(role: newRole); notifyListeners(); }
  }

  void removeMember(String teamId, String memberId) {
    final team = _teams.firstWhere((t) => t.id == teamId, orElse: () => _teams.first);
    team.members.removeWhere((m) => m.id == memberId);
    notifyListeners();
  }

  // ─── Project CRUD ──────────────────────────────────────────
  Project createProject({
    required String teamId, required String name, required String description,
    required String category, required String colorHex, required String iconEmoji,
    DateTime? dueDate, BudgetConfig? budget,
  }) {
    final proj = Project(
      id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
      name: name, description: description, category: category,
      status: ProjectStatus.active, teamId: teamId,
      ownerId: _currentUser.id,
      memberIds: [_currentUser.id],
      tasks: [], budget: budget, projectCosts: [],
      colorHex: colorHex, iconEmoji: iconEmoji,
      createdAt: DateTime.now(), dueDate: dueDate,
    );
    _projectStore.add(proj);
    final team = _teams.firstWhere((t) => t.id == teamId, orElse: () => _teams.first);
    team.projectIds.add(proj.id);
    notifyListeners();
    return proj;
  }

  // ─── Task CRUD ─────────────────────────────────────────────
  TaskDetail createTask({
    required String projectId, required String title, required String description,
    required TaskPriority priority, List<String>? assigneeIds,
    DateTime? startDate, DateTime? dueDate, BudgetConfig? budget, String? kpiId,
  }) {
    final task = TaskDetail(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      title: title, description: description,
      status: TaskStatus.todo, priority: priority,
      createdBy: _currentUser.id,
      assigneeIds: assigneeIds ?? [_currentUser.id],
      mentionedUserIds: [], checklist: [], schedules: [],
      costEntries: [], budget: budget, tags: [],
      startDate: startDate, dueDate: dueDate, kpiId: kpiId,
      createdAt: DateTime.now(), updatedAt: DateTime.now(),
    );
    final proj = _projectStore.firstWhere((p) => p.id == projectId, orElse: () => _projectStore.first);
    proj.tasks.add(task);
    notifyListeners();
    return task;
  }

  void updateTaskStatus(String projectId, String taskId, TaskStatus status) {
    final proj = _projectStore.firstWhere((p) => p.id == projectId, orElse: () => _projectStore.first);
    final task = proj.tasks.firstWhere((t) => t.id == taskId);
    task.status = status;
    task.updatedAt = DateTime.now();
    notifyListeners();
  }

  void toggleChecklistItem(String projectId, String taskId, String itemId) {
    final proj = _projectStore.firstWhere((p) => p.id == projectId, orElse: () => _projectStore.first);
    final task = proj.tasks.firstWhere((t) => t.id == taskId);
    final item = task.checklist.firstWhere((c) => c.id == itemId);
    item.isDone = !item.isDone;
    task.updatedAt = DateTime.now();
    notifyListeners();
  }

  void addChecklistItem(String projectId, String taskId, String title) {
    final proj = _projectStore.firstWhere((p) => p.id == projectId, orElse: () => _projectStore.first);
    final task = proj.tasks.firstWhere((t) => t.id == taskId);
    task.checklist.add(ChecklistItem(
      id: 'cl_${DateTime.now().millisecondsSinceEpoch}', title: title,
    ));
    task.updatedAt = DateTime.now();
    notifyListeners();
  }

  // ─── 체크리스트 항목 고객사·예산·집행 업데이트 ───────────
  void updateChecklistItemBudget(String projectId, String taskId, String itemId, {
    String? clientId,
    String? region,
    String? country,
    double? allocatedBudget,
    double? executedAmount,
    CurrencyCode? currency,
    String? costNote,
    String? assigneeId,
    DateTime? dueDate,
    String? title,
  }) {
    for (final proj in _projectStore) {
      if (proj.id != projectId) continue;
      for (final task in proj.tasks) {
        if (task.id != taskId) continue;
        final idx = task.checklist.indexWhere((c) => c.id == itemId);
        if (idx < 0) return;
        final old = task.checklist[idx];
        task.checklist[idx] = ChecklistItem(
          id: old.id,
          title: title ?? old.title,
          isDone: old.isDone,
          assigneeId: assigneeId ?? old.assigneeId,
          dueDate: dueDate ?? old.dueDate,
          clientId: clientId ?? old.clientId,
          region: region ?? old.region,
          country: country ?? old.country,
          allocatedBudget: allocatedBudget ?? old.allocatedBudget,
          executedAmount: executedAmount ?? old.executedAmount,
          currency: currency ?? old.currency,
          costNote: costNote ?? old.costNote,
        );
        task.updatedAt = DateTime.now();
        notifyListeners();
        return;
      }
    }
  }

  // ─── 태스크 기본 고객사·지역·예산 업데이트 ──────────────
  void updateTaskClientBudget(String projectId, String taskId, {
    String? defaultClientId,
    String? defaultRegion,
    String? defaultCountry,
    double? taskAllocatedBudget,
    CurrencyCode? taskBudgetCurrency,
  }) {
    for (final proj in _projectStore) {
      if (proj.id != projectId) continue;
      for (final task in proj.tasks) {
        if (task.id != taskId) continue;
        if (defaultClientId != null) task.defaultClientId = defaultClientId;
        if (defaultRegion != null) task.defaultRegion = defaultRegion;
        if (defaultCountry != null) task.defaultCountry = defaultCountry;
        if (taskAllocatedBudget != null) task.taskAllocatedBudget = taskAllocatedBudget;
        if (taskBudgetCurrency != null) task.taskBudgetCurrency = taskBudgetCurrency;
        task.updatedAt = DateTime.now();
        notifyListeners();
        return;
      }
    }
  }

  void addScheduleItem(String projectId, String taskId, ScheduleItem item) {
    final proj = _projectStore.firstWhere((p) => p.id == projectId, orElse: () => _projectStore.first);
    final task = proj.tasks.firstWhere((t) => t.id == taskId);
    task.schedules.add(item);
    notifyListeners();
  }

  void addCostEntry(String projectId, String taskId, CostEntry entry) {
    final proj = _projectStore.firstWhere((p) => p.id == projectId, orElse: () => _projectStore.first);
    final task = proj.tasks.firstWhere((t) => t.id == taskId);
    task.costEntries.add(entry);
    notifyListeners();
  }

  void toggleCostEntry(String projectId, String taskId, String entryId) {
    final proj = _projectStore.firstWhere((p) => p.id == projectId, orElse: () => _projectStore.first);
    final task = proj.tasks.firstWhere((t) => t.id == taskId);
    final entry = task.costEntries.firstWhere((e) => e.id == entryId);
    task.costEntries[task.costEntries.indexOf(entry)] = entry.copyWith(isExecuted: !entry.isExecuted);
    notifyListeners();
  }

  void updateTaskBudget(String projectId, String taskId, BudgetConfig budget) {
    final proj = _projectStore.firstWhere((p) => p.id == projectId, orElse: () => _projectStore.first);
    final task = proj.tasks.firstWhere((t) => t.id == taskId);
    task.budget = budget;
    notifyListeners();
  }

  // ─── KPI CRUD ──────────────────────────────────────────────
  void addKpi(KpiModel kpi) { _kpis.add(kpi); notifyListeners(); }
  void updateKpi(KpiModel updated) {
    final idx = _kpis.indexWhere((k) => k.id == updated.id);
    if (idx >= 0) { _kpis[idx] = updated; notifyListeners(); }
  }
  void deleteKpi(String id) { _kpis.removeWhere((k) => k.id == id); notifyListeners(); }

  // ─── User Profile Update ───────────────────────────────────
  void updateCurrentUser({
    String? name, String? nickname, String? email,
    String? avatarColor, JobTitle? jobTitle, String? department,
  }) {
    _currentUser = _currentUser.copyWith(
      name: name, nickname: nickname, email: email,
      avatarColor: avatarColor, jobTitle: jobTitle, department: department,
    );
    // allUsers 에도 반영
    final idx = _allUsers.indexWhere((u) => u.id == _currentUser.id);
    if (idx >= 0) _allUsers[idx] = _currentUser;
    notifyListeners();
  }

  // ─── AI Panel ──────────────────────────────────────────────
  void toggleAiPanel() { _aiPanelOpen = !_aiPanelOpen; notifyListeners(); }
  void closeAiPanel() { _aiPanelOpen = false; notifyListeners(); }

  void addAiMessage(String content, {bool isUser = true}) {
    _aiMessages.add(AiMessage(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      isUser: isUser, content: content, createdAt: DateTime.now(),
    ));
    notifyListeners();
  }

  void addAiLoadingMessage() {
    _aiMessages.add(AiMessage(
      id: 'ai_loading_${DateTime.now().millisecondsSinceEpoch}',
      isUser: false, content: '...', createdAt: DateTime.now(), isLoading: true,
    ));
    notifyListeners();
  }

  void replaceLastAiMessage(String content) {
    if (_aiMessages.isNotEmpty && _aiMessages.last.isLoading) {
      _aiMessages.last.content = content;
      _aiMessages.last.isLoading = false;
    } else {
      _aiMessages.add(AiMessage(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
        isUser: false, content: content, createdAt: DateTime.now(),
      ));
    }
    notifyListeners();
  }

  // ─── Notification Panel ────────────────────────────────────
  void toggleNotificationPanel() { _notificationPanelOpen = !_notificationPanelOpen; notifyListeners(); }
  void closeNotificationPanel() { _notificationPanelOpen = false; notifyListeners(); }

  void markNotificationRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) { _notifications[idx].isRead = true; notifyListeners(); }
  }

  void markAllNotificationsRead() {
    for (final n in _notifications) { n.isRead = true; }
    notifyListeners();
  }

  void addNotification({
    required String toUserId, required String fromUserId,
    required NotificationType type, required String title, required String body,
    String? relatedId, String? relatedType,
  }) {
    _notifications.insert(0, AppNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      toUserId: toUserId, fromUserId: fromUserId,
      type: type, title: title, body: body,
      relatedId: relatedId, relatedType: relatedType,
      createdAt: DateTime.now(),
    ));
    notifyListeners();
  }

  // ─── DM System ────────────────────────────────────────────
  void openDm(String userId) {
    _activeDmUserId = userId;
    _aiPanelOpen = false;
    _notificationPanelOpen = false;
    notifyListeners();
  }
  void closeDm() { _activeDmUserId = null; notifyListeners(); }

  DmConversation getOrCreateDm(String otherUserId) {
    final myId = _currentUser.id;
    final existing = _dmConversations.firstWhere(
      (c) => (c.userId1 == myId && c.userId2 == otherUserId) ||
             (c.userId1 == otherUserId && c.userId2 == myId),
      orElse: () {
        final newConv = DmConversation(
          id: 'dm_${myId}_$otherUserId',
          userId1: myId, userId2: otherUserId,
          messages: [], lastActivity: DateTime.now(),
        );
        _dmConversations.add(newConv);
        return newConv;
      },
    );
    return existing;
  }

  void sendDm(String toUserId, String content) {
    final conv = getOrCreateDm(toUserId);
    final msg = DmMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      fromUserId: _currentUser.id, toUserId: toUserId,
      content: content, createdAt: DateTime.now(),
    );
    conv.messages.add(msg);
    conv.lastActivity = DateTime.now();

    // 상대방에게 알림 추가
    final sender = _currentUser;
    addNotification(
      toUserId: toUserId, fromUserId: sender.id,
      type: NotificationType.dm,
      title: 'DM from ${sender.displayName}',
      body: content.length > 50 ? '${content.substring(0, 50)}...' : content,
      relatedId: conv.id, relatedType: 'dm',
    );
    notifyListeners();
  }

  // ─── Task Comment ──────────────────────────────────────────
  void addTaskComment(String projectId, String taskId, String content, List<String> mentionIds) {
    final proj = _projectStore.firstWhere((p) => p.id == projectId, orElse: () => _projectStore.first);
    final task = proj.tasks.firstWhere((t) => t.id == taskId);
    final comment = TaskComment(
      id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',
      taskId: taskId, authorId: _currentUser.id,
      content: content, mentionedUserIds: mentionIds,
      createdAt: DateTime.now(), updatedAt: DateTime.now(),
    );
    task.comments.add(comment);
    task.updatedAt = DateTime.now();

    // 담당자 및 멘션된 사람에게 알림
    final notifyIds = {...task.assigneeIds, ...mentionIds}..remove(_currentUser.id);
    for (final uid in notifyIds) {
      addNotification(
        toUserId: uid, fromUserId: _currentUser.id,
        type: mentionIds.contains(uid) ? NotificationType.mention : NotificationType.comment,
        title: mentionIds.contains(uid) ? '${_currentUser.displayName}님이 멘션했습니다' : '새 코멘트',
        body: content.length > 60 ? '${content.substring(0, 60)}...' : content,
        relatedId: taskId, relatedType: 'task',
      );
    }
    notifyListeners();
  }

  // ─── Task Attachments ─────────────────────────────────────
  /// 첨부파일/링크 추가
  void addTaskAttachment(String projectId, String taskId, TaskAttachment attachment) {
    final proj = _projectStore.firstWhere((p) => p.id == projectId, orElse: () => _projectStore.first);
    final task = proj.tasks.firstWhere((t) => t.id == taskId);
    task.attachments.add(attachment);
    task.updatedAt = DateTime.now();
    // 담당자에게 알림
    final notifyIds = task.assigneeIds.where((id) => id != _currentUser.id);
    for (final uid in notifyIds) {
      addNotification(
        toUserId: uid, fromUserId: _currentUser.id,
        type: NotificationType.comment,
        title: '${_currentUser.displayName}님이 파일을 첨부했습니다',
        body: attachment.name,
        relatedId: taskId, relatedType: 'task',
      );
    }
    notifyListeners();
  }

  /// 첨부파일 삭제
  void deleteTaskAttachment(String projectId, String taskId, String attachmentId) {
    final proj = _projectStore.firstWhere((p) => p.id == projectId, orElse: () => _projectStore.first);
    final task = proj.tasks.firstWhere((t) => t.id == taskId);
    task.attachments.removeWhere((a) => a.id == attachmentId);
    task.updatedAt = DateTime.now();
    notifyListeners();
  }

  /// 첨부파일 이름/설명 수정
  void updateTaskAttachment(String projectId, String taskId, String attachmentId,
      {String? name, String? description, String? checklistItemId}) {
    final proj = _projectStore.firstWhere((p) => p.id == projectId, orElse: () => _projectStore.first);
    final task = proj.tasks.firstWhere((t) => t.id == taskId);
    final att = task.attachments.firstWhere((a) => a.id == attachmentId);
    if (name != null) att.name = name;
    if (description != null) att.description = description;
    if (checklistItemId != null) att.checklistItemId = checklistItemId;
    task.updatedAt = DateTime.now();
    notifyListeners();
  }

  // ─── Task KPI Targets ──────────────────────────────────────
  void addTaskKpiTarget(String projectId, String taskId, TaskKpiTarget target) {
    final proj = _projectStore.firstWhere((p) => p.id == projectId, orElse: () => _projectStore.first);
    final task = proj.tasks.firstWhere((t) => t.id == taskId);
    task.kpiTargets.add(target);
    task.updatedAt = DateTime.now();
    notifyListeners();
  }

  void updateTaskKpiEntry(String projectId, String taskId, String kpiTargetId, String month, double actual) {
    final proj = _projectStore.firstWhere((p) => p.id == projectId, orElse: () => _projectStore.first);
    final task = proj.tasks.firstWhere((t) => t.id == taskId);
    final kpiTarget = task.kpiTargets.firstWhere((k) => k.id == kpiTargetId);
    final entry = kpiTarget.monthlyTargets.firstWhere((e) => e.month == month, orElse: () => kpiTarget.monthlyTargets.first);
    entry.actual = actual;
    task.updatedAt = DateTime.now();
    notifyListeners();
  }

  void removeTaskKpiTarget(String projectId, String taskId, String kpiTargetId) {
    final proj = _projectStore.firstWhere((p) => p.id == projectId, orElse: () => _projectStore.first);
    final task = proj.tasks.firstWhere((t) => t.id == taskId);
    task.kpiTargets.removeWhere((k) => k.id == kpiTargetId);
    task.updatedAt = DateTime.now();
    notifyListeners();
  }

  // ─── Initialize Sample Data ────────────────────────────────
  void initSampleData() {
    _initUsers();
    _initKpis();
    _initCampaigns();
    _initFunnelStages();
    _initMonthlyData();
    _initMonthlyKpiRecords();
    _initTeamsAndProjects();
    _initSampleNotifications();
    _initRegionsAndClients();
    notifyListeners();
  }

  void _initSampleNotifications() {
    _notifications.addAll([
      AppNotification(
        id: 'notif1', toUserId: 'u1', fromUserId: 'u2',
        type: NotificationType.mention, title: '이준혁님이 멘션했습니다',
        body: '@김지수 Q2 캠페인 예산안 검토 부탁드립니다.',
        relatedId: 'task1', relatedType: 'task', createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      AppNotification(
        id: 'notif2', toUserId: 'u1', fromUserId: 'u3',
        type: NotificationType.comment, title: '새 코멘트',
        body: 'SNS 광고 소재 수정 완료했습니다. 확인 부탁드려요.',
        relatedId: 'task2', relatedType: 'task', createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: 'notif3', toUserId: 'u1', fromUserId: 'u4',
        type: NotificationType.taskAssigned, title: '태스크 배정',
        body: 'KPI 성과 분석 리포트 작성 태스크가 배정되었습니다.',
        relatedId: 'task3', relatedType: 'task', createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        isRead: true,
      ),
      AppNotification(
        id: 'notif4', toUserId: 'u1', fromUserId: 'u2',
        type: NotificationType.dm, title: 'DM from 이준혁',
        body: '내일 미팅 시간 확인 부탁드립니다.',
        relatedId: 'dm_u1_u2', relatedType: 'dm', createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ]);

    // 샘플 DM 데이터
    final conv = DmConversation(
      id: 'dm_u1_u2', userId1: 'u1', userId2: 'u2',
      messages: [
        DmMessage(id: 'dm1', fromUserId: 'u2', toUserId: 'u1', content: '안녕하세요! 내일 미팅 시간 확인 부탁드립니다.', createdAt: DateTime.now().subtract(const Duration(hours: 1))),
        DmMessage(id: 'dm2', fromUserId: 'u1', toUserId: 'u2', content: '네, 오후 2시에 뵙겠습니다.', createdAt: DateTime.now().subtract(const Duration(minutes: 45)), isRead: true),
        DmMessage(id: 'dm3', fromUserId: 'u2', toUserId: 'u1', content: '감사합니다! Q2 예산안 자료도 준비해오세요.', createdAt: DateTime.now().subtract(const Duration(minutes: 30))),
      ],
      lastActivity: DateTime.now().subtract(const Duration(minutes: 30)),
    );
    _dmConversations.add(conv);
  }

  void _initUsers() {
    _allUsers.addAll([
      AppUser(id: 'u1', name: '김지수', email: 'jisu@company.com', avatarInitials: '김지', avatarColor: '#00BFA5', jobTitle: JobTitle.teamLead, department: '마케팅팀'),
      AppUser(id: 'u2', name: '이준혁', email: 'junhyuk@company.com', avatarInitials: '이준', avatarColor: '#29B6F6', jobTitle: JobTitle.senior, department: '마케팅팀'),
      AppUser(id: 'u3', name: '박소연', email: 'soyeon@company.com', avatarInitials: '박소', avatarColor: '#AB47BC', jobTitle: JobTitle.member, department: '마케팅팀'),
      AppUser(id: 'u4', name: '최민준', email: 'minjun@company.com', avatarInitials: '최민', avatarColor: '#FF7043', jobTitle: JobTitle.partLead, department: '디지털팀'),
      AppUser(id: 'u5', name: '정유진', email: 'yujin@company.com', avatarInitials: '정유', avatarColor: '#FFB300', jobTitle: JobTitle.member, department: '디지털팀'),
      AppUser(id: 'u6', name: '한승우', email: 'seungwoo@company.com', avatarInitials: '한승', avatarColor: '#66BB6A', jobTitle: JobTitle.director, department: '경영진'),
    ]);
    final cu = _allUsers.firstWhere((u) => u.id == _currentUser.id, orElse: () => _currentUser);
    _currentUser = cu;
  }

  void _initTeamsAndProjects() {
    // ── Team 1: 마케팅 전략팀 ──────────────────────────────
    final team1 = Team(
      id: 'team1', name: '마케팅 전략팀', description: '브랜드 마케팅 및 퍼포먼스 마케팅 전략 수립',
      colorHex: '#00BFA5', iconEmoji: '🎯',
      members: [
        TeamMember(id: 'tm1', user: _allUsers[0], role: MemberRole.owner, joinedAt: DateTime(2024, 1, 1)),
        TeamMember(id: 'tm2', user: _allUsers[1], role: MemberRole.editor, joinedAt: DateTime(2024, 1, 5)),
        TeamMember(id: 'tm3', user: _allUsers[2], role: MemberRole.editor, joinedAt: DateTime(2024, 1, 5)),
        TeamMember(id: 'tm4', user: _allUsers[4], role: MemberRole.viewer, joinedAt: DateTime(2024, 2, 1)),
      ],
      projectIds: ['proj1', 'proj2'], createdAt: DateTime(2024, 1, 1),
    );

    // ── Team 2: 디지털 마케팅팀 ────────────────────────────
    final team2 = Team(
      id: 'team2', name: '디지털 마케팅팀', description: 'SEO, SEM, SNS 디지털 채널 마케팅',
      colorHex: '#29B6F6', iconEmoji: '📱',
      members: [
        TeamMember(id: 'tm5', user: _allUsers[1], role: MemberRole.owner, joinedAt: DateTime(2024, 1, 1)),
        TeamMember(id: 'tm6', user: _allUsers[3], role: MemberRole.admin, joinedAt: DateTime(2024, 1, 3)),
        TeamMember(id: 'tm7', user: _allUsers[5], role: MemberRole.editor, joinedAt: DateTime(2024, 2, 1)),
      ],
      projectIds: ['proj3'], createdAt: DateTime(2024, 1, 1),
    );

    _teams.addAll([team1, team2]);
    _selectedTeamId = 'team1';

    final now = DateTime.now();

    // ── Project 1: 봄 시즌 캠페인 ─────────────────────────
    final proj1 = Project(
      id: 'proj1', name: '봄 시즌 마케팅 캠페인', category: '캠페인',
      description: '2025 봄 시즌 브랜드 인지도 및 전환 캠페인 기획/운영',
      status: ProjectStatus.active, teamId: 'team1',
      ownerId: 'u1', memberIds: ['u1', 'u2', 'u3'],
      colorHex: '#00BFA5', iconEmoji: '🌸',
      budget: BudgetConfig(totalBudget: 15000000, currency: CurrencyCode.krw, exchangeRateToKrw: 1.0),
      projectCosts: [
        CostEntry(id: 'pc1', title: '광고 집행비 1차', amount: 4500000, currency: CurrencyCode.krw, date: DateTime(now.year, 3, 5), category: '광고비', isExecuted: true),
        CostEntry(id: 'pc2', title: '크리에이티브 외주', amount: 1200000, currency: CurrencyCode.krw, date: DateTime(now.year, 3, 10), category: '외주', isExecuted: true),
      ],
      tasks: [], createdAt: DateTime(2025, 2, 1), dueDate: DateTime(now.year, 4, 30),
    );

    // Task 1-1
    proj1.tasks.add(TaskDetail(
      id: 'task1', title: '캠페인 크리에이티브 제작', description: '봄 시즌 배너, SNS 소재, 영상 크리에이티브 제작',
      status: TaskStatus.inProgress, priority: TaskPriority.high,
      createdBy: 'u1', assigneeIds: ['u3'], mentionedUserIds: ['u1', 'u2'],
      checklist: [
        ChecklistItem(id: 'cl1', title: '기획안 작성', isDone: true),
        ChecklistItem(id: 'cl2', title: '디자인 시안 3종 제작', isDone: true),
        ChecklistItem(id: 'cl3', title: '내부 검토 및 피드백 반영', isDone: false),
        ChecklistItem(id: 'cl4', title: '최종 파일 납품', isDone: false),
      ],
      schedules: [
        ScheduleItem(id: 'sc1', title: '기획 회의', startDate: DateTime(now.year, 3, 1), endDate: DateTime(now.year, 3, 3), isDone: true, color: '#00BFA5'),
        ScheduleItem(id: 'sc2', title: '시안 제작', startDate: DateTime(now.year, 3, 4), endDate: DateTime(now.year, 3, 10), isDone: true, color: '#29B6F6'),
        ScheduleItem(id: 'sc3', title: '검토 & 수정', startDate: DateTime(now.year, 3, 11), endDate: DateTime(now.year, 3, 15), isDone: false, color: '#FFB300'),
        ScheduleItem(id: 'sc4', title: '최종 납품', startDate: DateTime(now.year, 3, 16), endDate: DateTime(now.year, 3, 18), isDone: false, color: '#AB47BC'),
      ],
      budget: BudgetConfig(totalBudget: 1200000, currency: CurrencyCode.krw, exchangeRateToKrw: 1.0),
      costEntries: [
        CostEntry(id: 'ce1', title: '외주 디자이너 계약금 50%', amount: 600000, currency: CurrencyCode.krw, date: DateTime(now.year, 3, 1), category: '외주', isExecuted: true),
        CostEntry(id: 'ce2', title: '외주 디자이너 잔금 50%', amount: 600000, currency: CurrencyCode.krw, date: DateTime(now.year, 3, 18), category: '외주', isExecuted: false),
      ],
      tags: ['디자인', '크리에이티브', '봄캠페인'],
      startDate: DateTime(now.year, 3, 1), dueDate: DateTime(now.year, now.month, now.day + 3),
      kpiId: 'kpi3', createdAt: DateTime(now.year, 2, 28), updatedAt: DateTime.now(),
    ));

    // Task 1-2
    proj1.tasks.add(TaskDetail(
      id: 'task2', title: '구글/메타 광고 키워드 최적화', description: 'ROAS 개선을 위한 키워드 분석 및 A/B 테스트 설정',
      status: TaskStatus.todo, priority: TaskPriority.urgent,
      createdBy: 'u1', assigneeIds: ['u2'], mentionedUserIds: ['u5'],
      checklist: [
        ChecklistItem(id: 'cl5', title: '현재 키워드 성과 분석', isDone: false),
        ChecklistItem(id: 'cl6', title: '경쟁사 키워드 조사', isDone: false),
        ChecklistItem(id: 'cl7', title: 'A/B 테스트 설계', isDone: false),
        ChecklistItem(id: 'cl8', title: '새 키워드 세트 업로드', isDone: false),
        ChecklistItem(id: 'cl9', title: '성과 모니터링 대시보드 설정', isDone: false),
      ],
      schedules: [
        ScheduleItem(id: 'sc5', title: '분석 기간', startDate: DateTime(now.year, now.month, now.day), endDate: DateTime(now.year, now.month, now.day + 2), isDone: false, color: '#FF7043'),
        ScheduleItem(id: 'sc6', title: 'A/B 테스트 진행', startDate: DateTime(now.year, now.month, now.day + 3), endDate: DateTime(now.year, now.month, now.day + 10), isDone: false, color: '#29B6F6'),
      ],
      budget: BudgetConfig(totalBudget: 500000, currency: CurrencyCode.usd, exchangeRateToKrw: 1340.0),
      costEntries: [
        CostEntry(id: 'ce3', title: 'SEMrush 툴 비용', amount: 200, currency: CurrencyCode.usd, date: DateTime(now.year, 3, 15), category: '툴/소프트웨어', isExecuted: false),
      ],
      tags: ['SEM', 'ROAS', '광고최적화'],
      dueDate: DateTime(now.year, now.month, now.day + 1),
      kpiId: 'kpi2', createdAt: DateTime(now.year, 3, 1), updatedAt: DateTime.now(),
    ));

    // ── Project 2: Q2 전략 ────────────────────────────────
    final proj2 = Project(
      id: 'proj2', name: 'Q2 마케팅 전략 수립', category: '전략기획',
      description: '2분기 마케팅 전략, 예산 배분, KPI 설정',
      status: ProjectStatus.active, teamId: 'team1',
      ownerId: 'u1', memberIds: ['u1', 'u2', 'u5'],
      colorHex: '#AB47BC', iconEmoji: '📊',
      budget: BudgetConfig(totalBudget: 50000, currency: CurrencyCode.usd, exchangeRateToKrw: 1340.0),
      projectCosts: [],
      tasks: [], createdAt: DateTime(2025, 3, 1), dueDate: DateTime(now.year, 3, 31),
    );
    proj2.tasks.add(TaskDetail(
      id: 'task3', title: 'Q2 마케팅 전략 문서 작성', description: '2분기 채널별 전략, 예산, KPI 목표 문서화',
      status: TaskStatus.todo, priority: TaskPriority.high,
      createdBy: 'u1', assigneeIds: ['u1'], mentionedUserIds: ['u2', 'u5'],
      checklist: [
        ChecklistItem(id: 'cl10', title: '1분기 성과 리뷰', isDone: false),
        ChecklistItem(id: 'cl11', title: '채널별 전략 초안', isDone: false),
        ChecklistItem(id: 'cl12', title: '예산 배분 계획', isDone: false),
        ChecklistItem(id: 'cl13', title: 'KPI 목표 설정', isDone: false),
      ],
      schedules: [
        ScheduleItem(id: 'sc7', title: '전략 수립', startDate: DateTime(now.year, now.month, now.day - 3), endDate: DateTime(now.year, 3, 31), isDone: false, color: '#AB47BC'),
      ],
      budget: BudgetConfig(totalBudget: 5000000, currency: CurrencyCode.krw, exchangeRateToKrw: 1.0),
      costEntries: [],
      tags: ['전략', 'Q2', '기획'],
      dueDate: DateTime(now.year, 3, 31),
      createdAt: DateTime(now.year, 3, 1), updatedAt: DateTime.now(),
    ));

    // ── Project 3: SEO/콘텐츠 ─────────────────────────────
    final proj3 = Project(
      id: 'proj3', name: 'SEO 콘텐츠 마케팅', category: 'SEO/콘텐츠',
      description: '오가닉 트래픽 증대를 위한 SEO 콘텐츠 전략 및 발행',
      status: ProjectStatus.active, teamId: 'team2',
      ownerId: 'u2', memberIds: ['u2', 'u4', 'u6'],
      colorHex: '#FF7043', iconEmoji: '✍️',
      budget: BudgetConfig(totalBudget: 3000000, currency: CurrencyCode.krw, exchangeRateToKrw: 1.0),
      projectCosts: [],
      tasks: [], createdAt: DateTime(2025, 1, 1), dueDate: DateTime(now.year, 6, 30),
    );
    proj3.tasks.add(TaskDetail(
      id: 'task4', title: 'SEO 블로그 포스트 5편 발행', description: '타겟 키워드 기반 롱폼 콘텐츠 제작 및 최적화',
      status: TaskStatus.inProgress, priority: TaskPriority.medium,
      createdBy: 'u2', assigneeIds: ['u4', 'u6'], mentionedUserIds: ['u2'],
      checklist: [
        ChecklistItem(id: 'cl14', title: '키워드 리서치', isDone: true),
        ChecklistItem(id: 'cl15', title: '콘텐츠 아웃라인 작성', isDone: true),
        ChecklistItem(id: 'cl16', title: '1편 작성 및 발행', isDone: true),
        ChecklistItem(id: 'cl17', title: '2편 작성 및 발행', isDone: false),
        ChecklistItem(id: 'cl18', title: '3~5편 작성 및 발행', isDone: false),
      ],
      schedules: [
        ScheduleItem(id: 'sc8', title: '리서치', startDate: DateTime(now.year, 2, 1), endDate: DateTime(now.year, 2, 10), isDone: true, color: '#FF7043'),
        ScheduleItem(id: 'sc9', title: '콘텐츠 제작', startDate: DateTime(now.year, 2, 11), endDate: DateTime(now.year, now.month, now.day + 7), isDone: false, color: '#66BB6A'),
      ],
      budget: BudgetConfig(totalBudget: 800000, currency: CurrencyCode.krw, exchangeRateToKrw: 1.0),
      costEntries: [
        CostEntry(id: 'ce4', title: '콘텐츠 라이터 고용', amount: 300000, currency: CurrencyCode.krw, date: DateTime(now.year, 2, 15), category: '외주', isExecuted: true),
        CostEntry(id: 'ce5', title: 'Ahrefs 구독료', amount: 99, currency: CurrencyCode.usd, date: DateTime(now.year, 3, 1), category: '툴/소프트웨어', isExecuted: true),
      ],
      tags: ['SEO', '콘텐츠', '블로그'],
      startDate: DateTime(now.year, 2, 1), dueDate: DateTime(now.year, now.month, now.day + 7),
      kpiId: 'kpi9', createdAt: DateTime(now.year, 2, 1), updatedAt: DateTime.now(),
    ));

    _projectStore.addAll([proj1, proj2, proj3]);
  }

  void _initKpis() {
    final now = DateTime.now();
    _kpis.addAll([
      KpiModel(id: 'kpi1', title: '분기 총 매출', category: '매출', target: 500000000, current: 342000000, unit: '원', period: 'Q1 2025', isTeamKpi: true, dueDate: DateTime(now.year, 3, 31), teamId: 'team1'),
      KpiModel(id: 'kpi2', title: '마케팅 ROI', category: 'ROI', target: 300, current: 285, unit: '%', period: 'Q1 2025', isTeamKpi: true, dueDate: DateTime(now.year, 3, 31), teamId: 'team1'),
      KpiModel(id: 'kpi3', title: '신규 리드 수', category: '리드', target: 2000, current: 1650, unit: '건', period: 'Q1 2025', isTeamKpi: true, dueDate: DateTime(now.year, 3, 31), teamId: 'team1'),
      KpiModel(id: 'kpi4', title: '광고비 효율 (ROAS)', category: 'ROAS', target: 4.0, current: 3.6, unit: 'x', period: 'Q1 2025', isTeamKpi: true, dueDate: DateTime(now.year, 3, 31), teamId: 'team1'),
      KpiModel(id: 'kpi5', title: '캠페인 클릭률', category: 'CTR', target: 3.5, current: 3.2, unit: '%', period: 'Q1 2025', isTeamKpi: false, assignedTo: 'u2', dueDate: DateTime(now.year, 3, 31), teamId: 'team1'),
      KpiModel(id: 'kpi6', title: '이메일 오픈율', category: '이메일', target: 25, current: 28.4, unit: '%', period: 'Q1 2025', isTeamKpi: false, assignedTo: 'u2', dueDate: DateTime(now.year, 3, 31)),
      KpiModel(id: 'kpi7', title: '콘텐츠 조회수', category: '콘텐츠', target: 100000, current: 87500, unit: '회', period: 'Q1 2025', isTeamKpi: false, assignedTo: 'u3', dueDate: DateTime(now.year, 3, 31)),
      KpiModel(id: 'kpi8', title: 'SNS 팔로워 증가', category: 'SNS', target: 5000, current: 4200, unit: '명', period: 'Q1 2025', isTeamKpi: false, assignedTo: 'u3', dueDate: DateTime(now.year, 3, 31)),
      KpiModel(id: 'kpi9', title: '오가닉 트래픽', category: 'SEO', target: 50000, current: 43200, unit: '방문', period: 'Q1 2025', isTeamKpi: false, assignedTo: 'u4', dueDate: DateTime(now.year, 3, 31), teamId: 'team2'),
      KpiModel(id: 'kpi10', title: '키워드 상위 노출', category: 'SEO', target: 20, current: 17, unit: '개', period: 'Q1 2025', isTeamKpi: false, assignedTo: 'u4', dueDate: DateTime(now.year, 3, 31), teamId: 'team2'),
      KpiModel(id: 'kpi11', title: 'CPA 목표', category: '광고', target: 15000, current: 18500, unit: '원', period: 'Q1 2025', isTeamKpi: false, assignedTo: 'u5', dueDate: DateTime(now.year, 3, 31)),
      KpiModel(id: 'kpi12', title: '전환율', category: '전환', target: 5.0, current: 4.2, unit: '%', period: 'Q1 2025', isTeamKpi: false, assignedTo: 'u5', dueDate: DateTime(now.year, 3, 31)),
    ]);
  }

  void _initCampaigns() {
    final now = DateTime.now();
    _campaigns.addAll([
      CampaignModel(id: 'c1', name: '봄 시즌 프로모션', type: '시즌 프로모션', status: 'active', budget: 15000000, spent: 9800000, revenue: 42000000, impressions: 850000, clicks: 28500, conversions: 720, startDate: DateTime(now.year, 3, 1), endDate: DateTime(now.year, 3, 31), channel: 'Google/Meta'),
      CampaignModel(id: 'c2', name: 'SNS 브랜드 인지도', type: '브랜딩', status: 'active', budget: 8000000, spent: 5200000, revenue: 18500000, impressions: 1200000, clicks: 45000, conversions: 320, startDate: DateTime(now.year, 2, 15), endDate: DateTime(now.year, 4, 15), channel: 'Instagram/TikTok'),
      CampaignModel(id: 'c3', name: '이메일 리타겟팅', type: '리타겟팅', status: 'active', budget: 3000000, spent: 2800000, revenue: 15600000, impressions: 95000, clicks: 12800, conversions: 580, startDate: DateTime(now.year, 1, 1), endDate: DateTime(now.year, 3, 31), channel: '이메일'),
      CampaignModel(id: 'c4', name: 'SEO 콘텐츠 캠페인', type: 'SEO', status: 'active', budget: 5000000, spent: 3100000, revenue: 22000000, impressions: 320000, clicks: 18500, conversions: 410, startDate: DateTime(now.year, 1, 1), endDate: DateTime(now.year, 6, 30), channel: '검색/블로그'),
      CampaignModel(id: 'c5', name: '연말 블랙프라이데이', type: '시즌 프로모션', status: 'completed', budget: 20000000, spent: 19500000, revenue: 85000000, impressions: 2100000, clicks: 89000, conversions: 2100, startDate: DateTime(now.year - 1, 11, 20), endDate: DateTime(now.year - 1, 11, 30), channel: 'All'),
    ]);
  }

  void _initFunnelStages() {
    _funnelStages.addAll([
      FunnelStage(name: 'awareness', label: '인지 (Awareness)', value: 185000, previousValue: 185000, icon: '👁️'),
      FunnelStage(name: 'interest', label: '관심 (Interest)', value: 52000, previousValue: 185000, icon: '💡'),
      FunnelStage(name: 'consideration', label: '고려 (Consideration)', value: 18500, previousValue: 52000, icon: '🤔'),
      FunnelStage(name: 'intent', label: '구매의도 (Intent)', value: 6200, previousValue: 18500, icon: '🛒'),
      FunnelStage(name: 'conversion', label: '전환 (Conversion)', value: 2030, previousValue: 6200, icon: '✅'),
      FunnelStage(name: 'retention', label: '재구매 (Retention)', value: 890, previousValue: 2030, icon: '🔄'),
    ]);
  }

  void _initMonthlyData() {
    // 2024년 월별 데이터 (12개월)
    _monthlyData.addAll([
      MonthlyData(month: '1월',  monthKey: '2024-01', revenue: 58000000,  adSpend: 14000000, leads: 1200),
      MonthlyData(month: '2월',  monthKey: '2024-02', revenue: 62000000,  adSpend: 15500000, leads: 1350),
      MonthlyData(month: '3월',  monthKey: '2024-03', revenue: 74000000,  adSpend: 18000000, leads: 1580),
      MonthlyData(month: '4월',  monthKey: '2024-04', revenue: 81000000,  adSpend: 20000000, leads: 1720),
      MonthlyData(month: '5월',  monthKey: '2024-05', revenue: 78000000,  adSpend: 19500000, leads: 1650),
      MonthlyData(month: '6월',  monthKey: '2024-06', revenue: 92000000,  adSpend: 22000000, leads: 1900),
      MonthlyData(month: '7월',  monthKey: '2024-07', revenue: 88000000,  adSpend: 21000000, leads: 1820),
      MonthlyData(month: '8월',  monthKey: '2024-08', revenue: 95000000,  adSpend: 23500000, leads: 2050),
      MonthlyData(month: '9월',  monthKey: '2024-09', revenue: 104000000, adSpend: 26000000, leads: 2200),
      MonthlyData(month: '10월', monthKey: '2024-10', revenue: 85000000,  adSpend: 22000000, leads: 1800),
      MonthlyData(month: '11월', monthKey: '2024-11', revenue: 142000000, adSpend: 35000000, leads: 3200),
      MonthlyData(month: '12월', monthKey: '2024-12', revenue: 98000000,  adSpend: 28000000, leads: 2100),
    ]);
    // 2025년 월별 데이터 (1~6월)
    _monthlyData.addAll([
      MonthlyData(month: '1월',  monthKey: '2025-01', revenue: 72000000,  adSpend: 18000000, leads: 1500),
      MonthlyData(month: '2월',  monthKey: '2025-02', revenue: 115000000, adSpend: 25000000, leads: 2400),
      MonthlyData(month: '3월',  monthKey: '2025-03', revenue: 98000000,  adSpend: 20900000, leads: 2030),
      MonthlyData(month: '4월',  monthKey: '2025-04', revenue: 0,         adSpend: 0,         leads: 0),
      MonthlyData(month: '5월',  monthKey: '2025-05', revenue: 0,         adSpend: 0,         leads: 0),
      MonthlyData(month: '6월',  monthKey: '2025-06', revenue: 0,         adSpend: 0,         leads: 0),
      MonthlyData(month: '7월',  monthKey: '2025-07', revenue: 0,         adSpend: 0,         leads: 0),
      MonthlyData(month: '8월',  monthKey: '2025-08', revenue: 0,         adSpend: 0,         leads: 0),
      MonthlyData(month: '9월',  monthKey: '2025-09', revenue: 0,         adSpend: 0,         leads: 0),
      MonthlyData(month: '10월', monthKey: '2025-10', revenue: 0,         adSpend: 0,         leads: 0),
      MonthlyData(month: '11월', monthKey: '2025-11', revenue: 0,         adSpend: 0,         leads: 0),
      MonthlyData(month: '12월', monthKey: '2025-12', revenue: 0,         adSpend: 0,         leads: 0),
    ]);
  }

  void _initMonthlyKpiRecords() {
    // 2024년 전체 + 2025년 1~3월
    final months2024 = ['2024-01','2024-02','2024-03','2024-04','2024-05','2024-06',
                        '2024-07','2024-08','2024-09','2024-10','2024-11','2024-12'];
    final labels2024 = ['1월','2월','3월','4월','5월','6월','7월','8월','9월','10월','11월','12월'];
    final months2025 = ['2025-01','2025-02','2025-03'];
    final labels2025 = ['1월','2월','3월'];

    void addRecords(String kpiId, List<String> ms, List<String> ls, List<List<double>> data, String unit) {
      for (int i = 0; i < ms.length; i++) {
        _monthlyKpiRecords.add(MonthlyKpiRecord(
          kpiId: kpiId, month: ms[i], monthLabel: ls[i],
          target: data[i][0], actual: data[i][1], unit: unit,
        ));
      }
    }

    // kpi1: 분기 총 매출 (원)
    addRecords('kpi1', months2024, labels2024, [
      [70000000,58000000],[75000000,62000000],[80000000,74000000],
      [88000000,81000000],[90000000,78000000],[95000000,92000000],
      [92000000,88000000],[98000000,95000000],[105000000,104000000],
      [95000000,85000000],[110000000,142000000],[130000000,98000000],
    ], '원');
    addRecords('kpi1', months2025, labels2025, [
      [145000000,72000000],[155000000,115000000],[166000000,98000000],
    ], '원');

    // kpi2: 마케팅 ROI (%)
    addRecords('kpi2', months2024, labels2024, [
      [200,210],[210,215],[220,218],[225,230],[230,225],[235,240],
      [240,235],[245,250],[250,260],[240,228],[255,262],[265,275],
    ], '%');
    addRecords('kpi2', months2025, labels2025, [
      [270,241],[280,295],[300,285],
    ], '%');

    // kpi3: 신규 리드 수 (건)
    addRecords('kpi3', months2024, labels2024, [
      [200,180],[220,210],[240,230],[260,250],[270,240],[290,275],
      [280,265],[295,280],[310,305],[280,245],[310,342],[340,298],
    ], '건');
    addRecords('kpi3', months2025, labels2025, [
      [360,285],[380,412],[400,330],
    ], '건');

    // kpi5: 캠페인 클릭률 (%)
    addRecords('kpi5', months2024, labels2024, [
      [2.5,2.3],[2.6,2.5],[2.7,2.6],[2.8,2.7],[2.9,2.8],[3.0,2.9],
      [3.0,2.8],[3.1,3.0],[3.2,3.1],[3.0,2.8],[3.1,3.0],[3.2,3.1],
    ], '%');
    addRecords('kpi5', months2025, labels2025, [
      [3.3,2.9],[3.4,3.3],[3.5,3.2],
    ], '%');

    // kpi9: 오가닉 트래픽 (방문)
    addRecords('kpi9', months2024, labels2024, [
      [5000,4200],[5200,4800],[5500,5200],[5800,5600],[6000,5800],[6500,6200],
      [6800,6500],[7000,6800],[7200,7000],[7000,6200],[7500,7800],[8000,7400],
    ], '방문');
    addRecords('kpi9', months2025, labels2025, [
      [8500,7100],[9000,9200],[10000,8300],
    ], '방문');

    // kpi12: 전환율 (%)
    addRecords('kpi12', months2024, labels2024, [
      [3.5,3.2],[3.6,3.4],[3.7,3.5],[3.8,3.6],[3.9,3.7],[4.0,3.8],
      [3.9,3.7],[4.0,3.8],[4.1,3.9],[4.0,3.6],[4.2,4.0],[4.4,4.1],
    ], '%');
    addRecords('kpi12', months2025, labels2025, [
      [4.6,3.8],[4.8,4.5],[5.0,4.2],
    ], '%');
  }

  // ─── 권역 & 고객사 초기 데이터 ────────────────────────────
  void _initRegionsAndClients() {
    _regions.addAll([
      MarketingRegion(id: 'r1', name: '국내', countries: ['KR'], colorHex: '#00BFA5', icon: '🇰🇷'),
      MarketingRegion(id: 'r2', name: '동남아', countries: ['VN','TH','ID','MY','PH','SG'], colorHex: '#29B6F6', icon: '🌏'),
      MarketingRegion(id: 'r3', name: '중동', countries: ['AE','SA','QA','KW'], colorHex: '#FFB300', icon: '🌍'),
      MarketingRegion(id: 'r4', name: '북미', countries: ['US','CA'], colorHex: '#AB47BC', icon: '🌎'),
      MarketingRegion(id: 'r5', name: '유럽', countries: ['DE','FR','GB','NL'], colorHex: '#FF7043', icon: '🇪🇺'),
      MarketingRegion(id: 'r6', name: '중화권', countries: ['CN','TW','HK'], colorHex: '#EF5350', icon: '🇨🇳'),
    ]);

    _clients.addAll([
      ClientAccount(id: 'c1', name: '베트남 파트너스', country: 'VN', region: '동남아',
          industry: '유통', contactName: 'Nguyen Van A', revenue: 180000000, createdAt: DateTime(2024, 1)),
      ClientAccount(id: 'c2', name: '두바이 트레이딩', country: 'AE', region: '중동',
          industry: '무역', contactName: 'Ahmed Al-Rashid', revenue: 320000000, createdAt: DateTime(2024, 3)),
      ClientAccount(id: 'c3', name: '서울 리테일', country: 'KR', region: '국내',
          industry: '소매업', contactName: '김상현', revenue: 450000000, createdAt: DateTime(2023, 11)),
      ClientAccount(id: 'c4', name: 'US Startup Inc.', country: 'US', region: '북미',
          industry: 'IT/SaaS', contactName: 'John Smith', revenue: 220000000, createdAt: DateTime(2024, 6)),
      ClientAccount(id: 'c5', name: '방콕 미디어', country: 'TH', region: '동남아',
          industry: '미디어', contactName: 'Somchai P.', revenue: 95000000, createdAt: DateTime(2024, 2)),
    ]);

    // ── 샘플 매출/오더 데이터 ─────────────────────────────────
    _revenueEntries.addAll([
      ProjectRevenueEntry(id: 'r1', clientId: 'c1', country: 'KR', region: '국내',
          orderAmount: 580000000, revenue: 520000000, adSpend: 85000000, currency: 'KRW', date: DateTime(2025, 1)),
      ProjectRevenueEntry(id: 'r2', clientId: 'c2', country: 'SA', region: '중동',
          orderAmount: 320000000, revenue: 290000000, adSpend: 42000000, currency: 'KRW', date: DateTime(2025, 1)),
      ProjectRevenueEntry(id: 'r3', clientId: 'c3', country: 'SG', region: '동남아',
          orderAmount: 180000000, revenue: 165000000, adSpend: 28000000, currency: 'KRW', date: DateTime(2025, 2)),
      ProjectRevenueEntry(id: 'r4', clientId: 'c4', country: 'US', region: '북미',
          orderAmount: 420000000, revenue: 380000000, adSpend: 55000000, currency: 'KRW', date: DateTime(2025, 2)),
      ProjectRevenueEntry(id: 'r5', clientId: 'c5', country: 'TH', region: '동남아',
          orderAmount: 150000000, revenue: 130000000, adSpend: 22000000, currency: 'KRW', date: DateTime(2025, 3)),
      ProjectRevenueEntry(id: 'r6', clientId: 'c1', country: 'KR', region: '국내',
          orderAmount: 640000000, revenue: 590000000, adSpend: 92000000, currency: 'KRW', date: DateTime(2025, 4)),
      ProjectRevenueEntry(id: 'r7', clientId: 'c2', country: 'AE', region: '중동',
          orderAmount: 270000000, revenue: 250000000, adSpend: 38000000, currency: 'KRW', date: DateTime(2025, 4)),
    ]);
  }

  // ─── 권역 CRUD ────────────────────────────────────────────
  void addRegion(MarketingRegion r) { _regions.add(r); notifyListeners(); }
  void updateRegion(MarketingRegion r) {
    final i = _regions.indexWhere((x) => x.id == r.id);
    if (i >= 0) { _regions[i] = r; notifyListeners(); }
  }
  void deleteRegion(String id) { _regions.removeWhere((r) => r.id == id); notifyListeners(); }


  // ─── 고객사 CRUD ──────────────────────────────────────────
  void addClient(ClientAccount c) { _clients.add(c); notifyListeners(); }
  void updateClient(ClientAccount c) {
    final i = _clients.indexWhere((x) => x.id == c.id);
    if (i >= 0) { _clients[i] = c; notifyListeners(); }
  }
  void deleteClient(String id) { _clients.removeWhere((c) => c.id == id); notifyListeners(); }

  // ─── 매출/오더 항목 CRUD ──────────────────────────────────
  void addRevenueEntry(ProjectRevenueEntry e) { _revenueEntries.add(e); notifyListeners(); }
  void updateRevenueEntry(ProjectRevenueEntry e) {
    final i = _revenueEntries.indexWhere((x) => x.id == e.id);
    if (i >= 0) { _revenueEntries[i] = e; notifyListeners(); }
  }
  void deleteRevenueEntry(String id) { _revenueEntries.removeWhere((e) => e.id == id); notifyListeners(); }

  // ─── 대시보드 위젯 설정 ────────────────────────────────────
  void updateDashboardWidget(DashboardWidgetType type, {
    bool? isVisible, int? order, String? customTitle, bool? isExpanded,
  }) {
    final idx = _dashboardConfig.widgets.indexWhere((w) => w.type == type);
    if (idx >= 0) {
      _dashboardConfig.widgets[idx] = _dashboardConfig.widgets[idx].copyWith(
        isVisible: isVisible, order: order,
        customTitle: customTitle, isExpanded: isExpanded,
      );
      notifyListeners();
    }
  }

  void reorderDashboardWidgets(List<DashboardWidgetType> orderedTypes) {
    for (int i = 0; i < orderedTypes.length; i++) {
      final idx = _dashboardConfig.widgets.indexWhere((w) => w.type == orderedTypes[i]);
      if (idx >= 0) _dashboardConfig.widgets[idx].order = i;
    }
    notifyListeners();
  }

  void resetDashboardConfig() {
    _dashboardConfig = DashboardConfig.defaults();
    notifyListeners();
  }

  // ─── 대시보드 지표 조합 설정 ──────────────────────────────
  void updateDashboardMetrics({
    List<String>? summaryMetrics,
    String? campaignTypeFilter,
    bool? showRoiWidgets,
  }) {
    if (summaryMetrics != null) _dashboardConfig.selectedSummaryMetrics = summaryMetrics;
    if (campaignTypeFilter != null) _dashboardConfig.campaignTypeFilter = campaignTypeFilter;
    if (showRoiWidgets != null) _dashboardConfig.showRoiWidgets = showRoiWidgets;
    notifyListeners();
  }

  // ─── 프로젝트 전체 편집 ────────────────────────────────────
  void updateProject(String projectId, {
    String? name, String? description, String? category,
    ProjectStatus? status, String? colorHex, String? iconEmoji,
    DateTime? dueDate, List<String>? memberIds,
  }) {
    for (final proj in _projectStore) {
      if (proj.id == projectId) {
        if (name != null) proj.name = name;
        if (description != null) proj.description = description;
        if (category != null) proj.category = category;
        if (status != null) proj.status = status;
        if (colorHex != null) proj.colorHex = colorHex;
        if (iconEmoji != null) proj.iconEmoji = iconEmoji;
        if (dueDate != null) proj.dueDate = dueDate;
        if (memberIds != null) {
          proj.memberIds.clear();
          proj.memberIds.addAll(memberIds);
        }
        notifyListeners();
        return;
      }
    }
  }

  // ─── 태스크 전체 편집 ─────────────────────────────────────
  void updateTask(String projectId, String taskId, {
    String? title, String? description, TaskStatus? status, TaskPriority? priority,
    DateTime? dueDate, DateTime? startDate, List<String>? assigneeIds,
    List<String>? tags, String? kpiId, StrategyPillar? pillar,
  }) {
    for (final proj in _projectStore) {
      if (proj.id != projectId) continue;
      for (int i = 0; i < proj.tasks.length; i++) {
        if (proj.tasks[i].id != taskId) continue;
        final t = proj.tasks[i];
        if (title != null) t.title = title;
        if (description != null) t.description = description;
        if (status != null) t.status = status;
        if (priority != null) t.priority = priority;
        if (dueDate != null) t.dueDate = dueDate;
        if (startDate != null) t.startDate = startDate;
        if (assigneeIds != null) {
          t.assigneeIds.clear();
          t.assigneeIds.addAll(assigneeIds);
        }
        if (tags != null) {
          t.tags.clear();
          t.tags.addAll(tags);
        }
        if (kpiId != null) t.kpiId = kpiId;
        if (pillar != null) t.pillar = pillar;
        t.updatedAt = DateTime.now();
        notifyListeners();
        return;
      }
    }
  }

  // ─── KPI 전체 편집 ────────────────────────────────────────
  void updateKpiFull(String kpiId, {
    String? title, String? category, double? target, double? current,
    String? unit, String? period, String? assignedTo,
    StrategyPillar? pillar, String? pillarDescription,
  }) {
    final idx = _kpis.indexWhere((k) => k.id == kpiId);
    if (idx < 0) return;
    final k = _kpis[idx];
    if (title != null) k.title = title;
    if (category != null) k.category = category;
    if (target != null) k.target = target;
    if (current != null) k.current = current;
    if (unit != null) k.unit = unit;
    if (period != null) k.period = period;
    if (assignedTo != null) k.assignedTo = assignedTo;
    if (pillar != null) k.pillar = pillar;
    if (pillarDescription != null) k.pillarDescription = pillarDescription;
    notifyListeners();
  }

  // ─── 캠페인 편집 ──────────────────────────────────────────
  void updateCampaignField(String campaignId, {
    String? name, String? type, String? status, String? channel,
    double? budget, double? revenue,
  }) {
    final idx = _campaigns.indexWhere((c) => c.id == campaignId);
    if (idx < 0) return;
    final old = _campaigns[idx];
    _campaigns[idx] = CampaignModel(
      id: old.id,
      name: name ?? old.name,
      type: type ?? old.type,
      status: status ?? old.status,
      channel: channel ?? old.channel,
      budget: budget ?? old.budget,
      spent: old.spent,
      revenue: revenue ?? old.revenue,
      impressions: old.impressions,
      clicks: old.clicks,
      conversions: old.conversions,
      startDate: old.startDate,
      endDate: old.endDate,
    );
    notifyListeners();
  }

  // ─── CSV 벌크 태스크 업로드 ───────────────────────────────
  /// CSV 행 데이터를 파싱해서 태스크 목록으로 변환 후 지정 프로젝트에 추가
  /// CSV 컬럼 순서: title, description, status, priority, dueDate(yyyy-MM-dd), assigneeIds(;구분), tags(;구분)
  List<String> bulkAddTasksFromCsv(String projectId, List<Map<String, String>> rows) {
    final proj = _projectStore.where((p) => p.id == projectId).firstOrNull;
    if (proj == null) return ['프로젝트를 찾을 수 없습니다'];

    final errors = <String>[];
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final title = row['title']?.trim() ?? '';
      if (title.isEmpty) { errors.add('행 ${i+1}: 제목이 비어있습니다'); continue; }

      final statusStr = row['status']?.trim().toLowerCase() ?? 'todo';
      final status = _parseStatus(statusStr);
      final priorityStr = row['priority']?.trim().toLowerCase() ?? 'medium';
      final priority = _parsePriority(priorityStr);
      DateTime? dueDate;
      try {
        final ds = row['dueDate']?.trim() ?? '';
        if (ds.isNotEmpty) dueDate = DateTime.parse(ds);
      } catch (_) { errors.add('행 ${i+1}: 날짜 형식 오류 (yyyy-MM-dd 필요)'); }

      final assigneeIds = (row['assigneeIds'] ?? '').split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final tags = (row['tags'] ?? '').split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      // ── 확장 필드 파싱 ──────────────────────────────────
      final externalId = row['externalId']?.trim();
      final yearStr    = row['year']?.trim() ?? '';
      final targetStr  = row['target']?.trim() ?? '';
      final unit       = row['unit']?.trim();
      final theme      = row['theme']?.trim();
      final ownerName  = row['owner']?.trim();

      int? year;
      if (yearStr.isNotEmpty) year = int.tryParse(yearStr);

      double? target;
      if (targetStr.isNotEmpty) target = double.tryParse(targetStr);

      // pillar 파싱 (문자열 → StrategyPillar enum)
      StrategyPillar? pillar;
      final pillarStr = (row['pillar'] ?? '').toLowerCase().replaceAll(' ', '');
      if (pillarStr.contains('brand') || pillarStr.contains('awareness')) {
        pillar = StrategyPillar.awareness;
      } else if (pillarStr.contains('demand') || pillarStr.contains('conversion')) {
        pillar = StrategyPillar.conversion;
      } else if (pillarStr.contains('growth')) {
        pillar = StrategyPillar.growth;
      } else if (pillarStr.contains('retention') || pillarStr.contains('loyalty')) {
        pillar = StrategyPillar.loyalty;
      } else if (pillarStr.contains('partner')) {
        pillar = StrategyPillar.partnership;
      } else if (pillarStr.contains('innov')) {
        pillar = StrategyPillar.innovation;
      } else if (pillarStr.contains('effici')) {
        pillar = StrategyPillar.efficiency;
      }

      // description 자동 생성 (비어있을 때)
      final description = row['description']?.trim().isNotEmpty == true
          ? row['description']!.trim()
          : [
              if (externalId != null && externalId.isNotEmpty) '[$externalId]',
              if (theme != null && theme.isNotEmpty) theme,
              if (year != null) '$year년',
              if (target != null && unit != null) '목표: ${target.toStringAsFixed(target.truncateToDouble() == target ? 0 : 1)} $unit',
            ].join(' ').trim();

      final task = TaskDetail(
        id: 'task_csv_${DateTime.now().millisecondsSinceEpoch}_$i',
        title: title,
        description: description,
        status: status,
        priority: priority,
        createdBy: _currentUser.id,
        assigneeIds: assigneeIds.isEmpty ? [_currentUser.id] : assigneeIds,
        mentionedUserIds: [],
        checklist: [],
        schedules: [],
        costEntries: [],
        tags: tags,
        dueDate: dueDate,
        pillar: pillar,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        // 확장 필드
        externalId: externalId?.isEmpty == true ? null : externalId,
        year:       year,
        target:     target,
        unit:       unit?.isEmpty == true ? null : unit,
        theme:      theme?.isEmpty == true ? null : theme,
        ownerName:  ownerName?.isEmpty == true ? null : ownerName,
      );
      proj.tasks.add(task);
    }
    notifyListeners();
    return errors;
  }

  TaskStatus _parseStatus(String s) {
    switch (s) {
      case 'inprogress': case '진행': return TaskStatus.inProgress;
      case 'inreview': case '검토': return TaskStatus.inReview;
      case 'done': case '완료': return TaskStatus.done;
      default: return TaskStatus.todo;
    }
  }

  TaskPriority _parsePriority(String s) {
    switch (s) {
      case 'low': case '낮음': return TaskPriority.low;
      case 'high': case '높음': return TaskPriority.high;
      case 'urgent': case '긴급': return TaskPriority.urgent;
      default: return TaskPriority.medium;
    }
  }
}

/// 태스크 + 프로젝트 정보 묶음 (헬퍼)
class TaskWithProject {
  final TaskDetail task;
  final Project project;
  const TaskWithProject({required this.task, required this.project});
}

/// 비용 + 출처 메타 묶음 (지역/고객 분석용)
class CostWithMeta {
  final CostEntry entry;
  final String projectId;
  final String? taskId;
  final String? taskTitle;
  final String projectName;
  const CostWithMeta({
    required this.entry, required this.projectId,
    this.taskId, this.taskTitle, required this.projectName,
  });
}
