import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import "../services/supabase_service.dart";

// ─── 로컬 지속성 키 ─────────────────────────────────────────
const _kLocalTeams     = 'local_teams_v2';
const _kLocalProjects  = 'local_projects_v2';
const _kLocalKpis      = 'local_kpis_v2';
const _kLocalCampaigns = 'local_campaigns_v2';
const _kDefaultTeamId  = 'default_team_id';
const _kUid            = 'last_uid';

class AppProvider extends ChangeNotifier {
  // ─── Firebase UID (로그인 후 설정) ────────────────────────
  String? _uid;
  bool _firebaseLoaded = false;
  bool _dataReady = false;      // 대시보드 표시 준비 완료 여부
  final SupabaseService _svc = SupabaseService();

  // 실시간 스트림 구독 취소
  StreamSubscription<List<Team>>? _teamsSub;
  StreamSubscription<List<Project>>? _projectsSub;
  final Map<String, StreamSubscription<List<Project>>> _sharedProjectSubs = {};

  /// 대시보드 진입 가능 여부 (데이터 로딩 완료)
  bool get isDataReady => _dataReady;

  /// Firebase Auth 유저 정보를 AppProvider의 currentUser에 동기화
  void syncAuthUser({
    required String uid,
    required String name,
    required String email,
    String? avatarUrl,
  }) {
    // 이미 샘플 데이터에 있는 유저 또는 새 유저 생성
    final initials = name.length >= 2 ? name.substring(0, 2) : name;
    _currentUser = AppUser(
      id: uid,
      name: name,
      email: email,
      avatarInitials: initials,
      avatarColor: '#00BFA5',
      jobTitle: JobTitle.teamLead,
      department: '마케팅팀',
    );
    // allUsers 에도 반영
    final idx = _allUsers.indexWhere((u) => u.id == uid);
    if (idx >= 0) {
      _allUsers[idx] = _currentUser;
    } else {
      _allUsers.add(_currentUser);
    }
    if (kDebugMode) debugPrint('[AppProvider] syncAuthUser: $name ($uid)');
    notifyListeners();
  }

  /// 로그인 후 uid를 설정하고 Firebase에서 데이터 로드
  Future<void> setUidAndLoad(String uid) async {
    _uid = uid;
    _dataReady = false;
    notifyListeners();
    // 이전 데이터 초기화 (다른 계정 로그인 대비)
    _teams.clear(); _projectStore.clear(); _kpis.clear();
    _campaigns.clear(); _funnelStages.clear(); _monthlyData.clear();
    _monthlyKpiRecords.clear(); _regions.clear(); _clients.clear();
    _selectedTeamId = null; _selectedProjectId = null; _selectedTaskId = null;

    // ① 로컬 캐시를 먼저 복원 (즉각 표시)
    await _loadFromLocal(uid);

    // ② Firebase에서 최신 데이터 동기화
    await _loadFromFirebase(uid);

    // ③ Firebase 동기화 후 로컬 캐시 갱신
    await _saveToLocal(uid);

    // ④ 기본 팀 자동 선택
    _autoSelectDefaultTeam();

    // ⑤ 기본 섹션 설정: 팀이 있으면 dashboard, 없으면 teams
    if (_teams.isNotEmpty) {
      _currentSection = 'dashboard';
    } else {
      _currentSection = 'teams';
    }

    _startRealTimeSync(uid);
    _dataReady = true;
    notifyListeners();
  }

  // ─── 로컬 캐시 저장 ─────────────────────────────────────────
  Future<void> _saveToLocal(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUid, uid);
      // 팀 저장
      await prefs.setString(_kLocalTeams,
          jsonEncode(_teams.map((t) => t.toJson()).toList()));
      // 프로젝트 저장
      await prefs.setString(_kLocalProjects,
          jsonEncode(_projectStore.map((p) => p.toJson()).toList()));
      // KPI 저장
      await prefs.setString(_kLocalKpis,
          jsonEncode(_kpis.map((k) => k.toJson()).toList()));
      // 캠페인 저장
      await prefs.setString(_kLocalCampaigns,
          jsonEncode(_campaigns.map((c) => c.toJson()).toList()));
      if (kDebugMode) debugPrint('[AppProvider] Local cache saved');
    } catch (e) {
      if (kDebugMode) debugPrint('[AppProvider] saveToLocal error: $e');
    }
  }

  // ─── 로컬 캐시 로드 ─────────────────────────────────────────
  Future<void> _loadFromLocal(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUid = prefs.getString(_kUid);
      if (savedUid != uid) return; // 다른 계정이면 캐시 무시

      // 팀
      final teamsJson = prefs.getString(_kLocalTeams);
      if (teamsJson != null) {
        final list = jsonDecode(teamsJson) as List;
        _teams.addAll(list.map((j) => Team.fromJson(j as Map<String, dynamic>)));
        if (kDebugMode) debugPrint('[AppProvider] Local teams loaded: ${_teams.length}');
      }
      // 프로젝트
      final projsJson = prefs.getString(_kLocalProjects);
      if (projsJson != null) {
        final list = jsonDecode(projsJson) as List;
        _projectStore.addAll(list.map((j) => Project.fromJson(j as Map<String, dynamic>)));
      }
      // KPI
      final kpisJson = prefs.getString(_kLocalKpis);
      if (kpisJson != null) {
        final list = jsonDecode(kpisJson) as List;
        _kpis.addAll(list.map((j) => KpiModel.fromJson(j as Map<String, dynamic>)));
      }
      // 캠페인
      final campaignsJson = prefs.getString(_kLocalCampaigns);
      if (campaignsJson != null) {
        final list = jsonDecode(campaignsJson) as List;
        _campaigns.addAll(list.map((j) => CampaignModel.fromJson(j as Map<String, dynamic>)));
      }
      // 기본 팀 복원
      final defaultTeamId = prefs.getString(_kDefaultTeamId);
      if (defaultTeamId != null && _teams.any((t) => t.id == defaultTeamId)) {
        _selectedTeamId = defaultTeamId;
      }
      if (_teams.isNotEmpty && _selectedTeamId == null) {
        _selectedTeamId = _teams.first.id;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AppProvider] loadFromLocal error: $e');
    }
  }

  // ─── 기본 팀 자동 선택 ─────────────────────────────────────
  void _autoSelectDefaultTeam() {
    if (_teams.isEmpty) return;
    // defaultTeamId가 저장되어 있으면 그 팀으로
    // 없으면 첫 번째 팀으로
    if (_selectedTeamId == null || !_teams.any((t) => t.id == _selectedTeamId)) {
      _selectedTeamId = _teams.first.id;
    }
    if (kDebugMode) debugPrint('[AppProvider] Default team: $_selectedTeamId');
  }

  /// 기본 팀을 설정하고 로컬 저장
  Future<void> setDefaultTeam(String teamId) async {
    _selectedTeamId = teamId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDefaultTeamId, teamId);
    } catch (_) {}
    notifyListeners();
  }

  void _startRealTimeSync(String uid) {
    _teamsSub?.cancel();
    _projectsSub?.cancel();

    // 팀 실시간 동기화
    _teamsSub = _svc.watchTeams(uid).listen((teams) {
      if (teams.isNotEmpty) {
        _teams.clear();
        _teams.addAll(teams);
        notifyListeners();
        // 팀이 업데이트되면 공유 프로젝트 구독도 갱신
        _subscribeSharedProjects();
      }
    }, onError: (e) {
      if (kDebugMode) debugPrint('watchTeams error: $e');
    });

    // 개인 프로젝트 실시간 동기화
    _projectsSub = _svc.watchProjects(uid).listen((projects) {
      if (projects.isNotEmpty) {
        _projectStore.clear();
        _projectStore.addAll(projects);
        notifyListeners();
      }
    }, onError: (e) {
      if (kDebugMode) debugPrint('watchProjects error: $e');
    });

    // 공유 프로젝트 초기 구독
    _subscribeSharedProjects();
  }

  /// 각 팀의 공유 프로젝트 실시간 구독 (팀원 전원 동기화)
  void _subscribeSharedProjects() {
    // 기존 구독 중 더 이상 없는 팀은 취소
    final currentTeamIds = _teams.map((t) => t.id).toSet();
    _sharedProjectSubs.keys.toList().forEach((tid) {
      if (!currentTeamIds.contains(tid)) {
        _sharedProjectSubs[tid]?.cancel();
        _sharedProjectSubs.remove(tid);
      }
    });

    // 새 팀에 대한 구독 추가
    for (final team in _teams) {
      if (_sharedProjectSubs.containsKey(team.id)) continue;
      _sharedProjectSubs[team.id] = _svc.watchSharedProjects(team.id).listen((sharedProjs) {
        // 공유 프로젝트를 로컬 store에 merge (중복 제거)
        for (final sp in sharedProjs) {
          final idx = _projectStore.indexWhere((p) => p.id == sp.id);
          if (idx >= 0) {
            _projectStore[idx] = sp; // 업데이트
          } else {
            _projectStore.add(sp); // 새로 추가
          }
        }
        notifyListeners();
      }, onError: (e) {
        if (kDebugMode) debugPrint('watchSharedProjects ${team.id} error: $e');
      });
    }
  }

  void clearUid() {
    _teamsSub?.cancel();
    _projectsSub?.cancel();
    for (final sub in _sharedProjectSubs.values) { sub.cancel(); }
    _sharedProjectSubs.clear();
    _teamsSub = null;
    _projectsSub = null;
    _uid = null;
    _firebaseLoaded = false;
    _dataReady = false;
    notifyListeners();
  }

  Future<void> _loadFromFirebase(String uid) async {
    // Firebase 사용 불가 시 로컬 샘플 데이터 유지
    if (!_svc.isAvailable) {
      if (kDebugMode) debugPrint('[AppProvider] Firebase offline → using local sample data');
      _firebaseLoaded = false;
      return;   // setUidAndLoad 에서 _dataReady = true 처리
    }

    try {
      final isNew = await _svc.isNewUser(uid).timeout(const Duration(seconds: 10));
      if (isNew) {
        // 첫 가입: 빈 상태로 시작 (샘플 데이터 없음) - currentUser 메타만 저장
        await _svc.saveUserMeta(uid, _currentUser.email, _currentUser.name);
        if (kDebugMode) debugPrint('[AppProvider] New user → starting with empty data');
        // 팀/KPI/캠페인은 사용자가 직접 생성
        if (_teams.isEmpty) _selectedTeamId = null;
      } else {
        // 기존 유저: Firebase에서 데이터 로드
        final bundle = await _svc.loadAllUserData(uid).timeout(const Duration(seconds: 10));
        if (!bundle.isEmpty) {
          _teams.clear();       _teams.addAll(bundle.teams);
          _projectStore.clear(); _projectStore.addAll(bundle.projects);
          _kpis.clear();        _kpis.addAll(bundle.kpis);
          _campaigns.clear();   _campaigns.addAll(bundle.campaigns);
          _regions.clear();     _regions.addAll(bundle.regions);
          _clients.clear();     _clients.addAll(bundle.clients);
          if (bundle.members.isNotEmpty) {
            _allUsers.clear(); _allUsers.addAll(bundle.members);
          }
          // Firebase 로드 후 currentUser를 uid 기준으로 갱신
          final fbUser = _allUsers.firstWhere(
            (u) => u.id == uid,
            orElse: () => _currentUser,
          );
          _currentUser = fbUser;
          if (kDebugMode) debugPrint('[AppProvider] Loaded existing user data from Firebase');
        }
        // 유저 프리퍼런스 로드 (디폴트 페이지 등)
        final prefs = await _svc.loadUserPrefs(uid);
        if (prefs != null) {
          _defaultSection = prefs['defaultSection'] as String? ?? 'dashboard';
          _currentSection = _defaultSection;
        }
      }
      _firebaseLoaded = true;
    } catch (e) {
      // Firebase 실패해도 로컬 샘플 데이터로 계속 동작
      if (kDebugMode) debugPrint('[AppProvider] Firebase load error → using local data: $e');
      _firebaseLoaded = false;
    }
  }

  Future<void> _saveAllToFirebase(String uid) async {
    final bundle = UserDataBundle(
      teams: _teams, projects: _projectStore, kpis: _kpis,
      campaigns: _campaigns, regions: _regions, clients: _clients,
      members: _allUsers,
    );
    await _svc.saveAllUserData(uid, bundle);
  }

  @override
  void dispose() {
    _teamsSub?.cancel();
    _projectsSub?.cancel();
    super.dispose();
  }

  bool get isFirebaseLoaded => _firebaseLoaded;
  bool get isSupabaseAvailable => _svc.isAvailable;

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
  final List<StrategyFramework> _strategyFrameworks = [];

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
  String _defaultSection  = 'dashboard'; // 로그인 후 기본 페이지
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
  /// 현재 선택된 팀의 KPI만 반환 (팀 간 공유 없음)
  List<KpiModel> get teamKpis {
    if (_selectedTeamId == null) return [];
    return _kpis.where((k) => k.isTeamKpi && k.teamId == _selectedTeamId).toList();
  }
  /// 특정 팀의 모든 KPI (팀 KPI + 해당 팀에 할당된 개인 KPI)
  List<KpiModel> getKpisForTeam(String teamId) =>
      _kpis.where((k) => k.teamId == teamId).toList();
  /// 현재 선택된 팀의 모든 KPI
  List<KpiModel> get currentTeamKpis {
    if (_selectedTeamId == null) return [];
    return _kpis.where((k) => k.teamId == _selectedTeamId).toList();
  }
  List<KpiModel> get personalKpis => _kpis.where((k) => !k.isTeamKpi && (k.assignedTo == _currentUser.id)).toList();
  List<CampaignModel> get campaigns => _campaigns;

  /// 현재 선택된 팀의 캠페인만 반환
  List<CampaignModel> get teamCampaigns {
    if (_selectedTeamId == null) return _campaigns;
    return _campaigns.where((c) => c.teamId == _selectedTeamId || c.teamId == null).toList();
  }

  // ═══════════════════════════════════════════════════════════
  //  팀별 통합 집계 (대시보드/KPI/캠페인 연동의 핵심)
  // ═══════════════════════════════════════════════════════════

  /// 현재 팀의 모든 태스크 (프로젝트를 통해)
  List<TaskDetail> get currentTeamTasks {
    if (_selectedTeamId == null) {
      return _projectStore.expand((p) => p.tasks).toList();
    }
    return _projectStore
        .where((p) => p.teamId == _selectedTeamId)
        .expand((p) => p.tasks)
        .toList();
  }

  /// 현재 팀의 프로젝트
  List<Project> get currentTeamProjects {
    if (_selectedTeamId == null) return _projectStore;
    return _projectStore.where((p) => p.teamId == _selectedTeamId).toList();
  }

  /// 태스크에서 파생된 KPI 달성률 자동 집계
  /// - task.kpiId 가 있으면 해당 KPI의 current를 태스크 완료율로 자동 업데이트
  void syncTaskKpiProgress() {
    bool changed = false;
    for (final kpi in _kpis) {
      // 이 KPI에 연결된 모든 태스크 수집
      final relatedTasks = <TaskDetail>[];
      for (final proj in _projectStore) {
        for (final task in proj.tasks) {
          if (task.kpiId == kpi.id) relatedTasks.add(task);
        }
      }
      if (relatedTasks.isEmpty) continue;

      // 태스크 완료율로 KPI current 자동 업데이트
      final done = relatedTasks.where((t) => t.status == TaskStatus.done).length;
      final progress = done / relatedTasks.length * kpi.target;
      if ((progress - kpi.current).abs() > 0.01) {
        kpi.current = progress;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// 팀별 태스크 상태 집계 (대시보드 카드용)
  Map<TaskStatus, int> get currentTeamTaskStatusCount {
    final map = <TaskStatus, int>{for (final s in TaskStatus.values) s: 0};
    for (final task in currentTeamTasks) {
      map[task.status] = (map[task.status] ?? 0) + 1;
    }
    return map;
  }

  /// 팀별 태스크 완료율
  double get currentTeamTaskCompletionRate {
    final tasks = currentTeamTasks;
    if (tasks.isEmpty) return 0;
    return tasks.where((t) => t.status == TaskStatus.done).length / tasks.length * 100;
  }

  /// 팀별 예산 합계 (태스크+프로젝트)
  double get currentTeamTotalBudgetKrw {
    return currentTeamProjects.fold(
        0.0, (s, p) => s + p.totalBudgetKrw);
  }

  /// 팀별 집행 비용 합계
  double get currentTeamExecutedCostKrw {
    return currentTeamProjects.fold(
        0.0, (s, p) => s + p.executedCostKrw);
  }

  /// 팀별 예산 소진율
  double get currentTeamBudgetUsageRate {
    final budget = currentTeamTotalBudgetKrw;
    if (budget <= 0) return 0;
    return (currentTeamExecutedCostKrw / budget * 100).clamp(0, 200);
  }

  /// KPI에 연결된 태스크 목록 (팀 기준 필터)
  List<TaskWithProject> getLinkedTasksForKpi(String kpiId) {
    final result = <TaskWithProject>[];
    final projects = _selectedTeamId != null
        ? _projectStore.where((p) => p.teamId == _selectedTeamId)
        : _projectStore as Iterable<Project>;
    for (final proj in projects) {
      for (final task in proj.tasks) {
        if (task.kpiId == kpiId) {
          result.add(TaskWithProject(task: task, project: proj));
        }
      }
    }
    return result;
  }

  /// 캠페인에 연결된 태스크 목록 (팀 기준 필터)
  List<TaskWithProject> getLinkedTasksForCampaign(String campaignId) {
    final result = <TaskWithProject>[];
    final projects = _selectedTeamId != null
        ? _projectStore.where((p) => p.teamId == _selectedTeamId)
        : _projectStore as Iterable<Project>;
    for (final proj in projects) {
      // campaignId 직접 연결 또는 task.campaignId 연결
      final projMatches = proj.campaignId == campaignId;
      for (final task in proj.tasks) {
        if (projMatches || task.campaignId == campaignId) {
          result.add(TaskWithProject(task: task, project: proj));
        }
      }
    }
    return result;
  }

  /// 팀별 캠페인 KPI 집계 (캠페인 → KPI 연결)
  List<KpiModel> getKpisForCampaign(String campaignId) {
    return currentTeamKpis.where((k) => k.campaignId == campaignId).toList();
  }

  /// 태스크 진행상황을 대시보드 summary 카드용으로 집계
  /// 반환: {todo, inProgress, inReview, done, overdue}
  Map<String, int> get teamTaskSummary {
    final tasks = currentTeamTasks;
    final now = DateTime.now();
    return {
      'total': tasks.length,
      'todo': tasks.where((t) => t.status == TaskStatus.todo).length,
      'inProgress': tasks.where((t) => t.status == TaskStatus.inProgress).length,
      'inReview': tasks.where((t) => t.status == TaskStatus.inReview).length,
      'done': tasks.where((t) => t.status == TaskStatus.done).length,
      'overdue': tasks.where((t) =>
          t.dueDate != null &&
          t.dueDate!.isBefore(now) &&
          t.status != TaskStatus.done).length,
    };
  }

  /// 담당자별 태스크 수 집계 (팀 대시보드용)
  Map<String, int> get taskCountByMember {
    final map = <String, int>{};
    for (final task in currentTeamTasks) {
      for (final uid in task.assigneeIds) {
        map[uid] = (map[uid] ?? 0) + 1;
      }
      if (task.assigneeIds.isEmpty) {
        map['unassigned'] = (map['unassigned'] ?? 0) + 1;
      }
    }
    return map;
  }

  /// 팀별 KPI 달성률 (태스크 자동 집계 포함)
  double get currentTeamKpiAchievement {
    final kpis = currentTeamKpis;
    if (kpis.isEmpty) return 0;
    return kpis.fold(0.0, (s, k) => s + k.achievementRate) / kpis.length;
  }

  /// 팀 변경 (네비게이션 팀 스위처에서 사용)
  /// - 현재 섹션(대시보드, KPI, 캠페인 등)을 유지하되 팀 데이터만 갱신
  /// - 팀 상세/프로젝트/태스크 상세에서는 대시보드로 이동
  void switchTeam(String teamId) {
    if (_selectedTeamId == teamId) return;
    _selectedTeamId = teamId;
    _selectedProjectId = null;
    _selectedTaskId = null;
    // 팀 종속 하위 페이지에서 전환 시 적절한 섹션으로 이동
    if (_currentSection == 'team_detail' ||
        _currentSection == 'project_detail' ||
        _currentSection == 'task_detail') {
      _currentSection = 'dashboard';
    }
    // syncTaskKpiProgress 호출로 KPI 달성률 자동 갱신
    syncTaskKpiProgress();
    notifyListeners();
  }

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

  // 전략 프레임워크 Getters
  List<StrategyFramework> get strategyFrameworks => _strategyFrameworks;
  List<StrategyFramework> get teamStrategyFrameworks {
    if (_selectedTeamId == null) return _strategyFrameworks;
    return _strategyFrameworks.where((f) => f.teamId == _selectedTeamId).toList();
  }

  StrategyFramework? getFrameworkForTeam(String teamId) =>
      _strategyFrameworks.firstWhere((f) => f.teamId == teamId, orElse: () {
        final fw = StrategyFramework.brandToDemand(teamId);
        _strategyFrameworks.add(fw);
        _saveToLocal(_uid ?? '');
        return fw;
      });

  void addStrategyFramework(StrategyFramework fw) {
    _strategyFrameworks.removeWhere((f) => f.id == fw.id);
    _strategyFrameworks.add(fw);
    if (_uid != null) _saveToLocal(_uid!);
    notifyListeners();
  }

  void updateStrategyFramework(StrategyFramework fw) {
    final idx = _strategyFrameworks.indexWhere((f) => f.id == fw.id);
    if (idx >= 0) _strategyFrameworks[idx] = fw;
    else _strategyFrameworks.add(fw);
    if (_uid != null) _saveToLocal(_uid!);
    notifyListeners();
  }

  void updateCampaign(CampaignModel c) {
    final idx = _campaigns.indexWhere((x) => x.id == c.id);
    if (idx >= 0) {
      _campaigns[idx] = c;
      if (_uid != null) {
        _svc.saveCampaign(_uid!, c);  
        _saveToLocal(_uid!);
      }
      notifyListeners();
    }
  }

  // 권역/고객 Getters
  List<MarketingRegion> get regions => _regions;
  List<ClientAccount> get clients => _clients;
  List<ClientAccount> get activeClients => _clients.where((c) => c.isActive).toList();

  /// 현재 팀의 고객사만
  List<ClientAccount> get teamClients {
    if (_selectedTeamId == null) return _clients;
    return _clients.where((c) => c.teamId == null || c.teamId == _selectedTeamId).toList();
  }

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
    // 1순위: Project.campaignId 직접 매칭
    for (final proj in _projectStore) {
      if (proj.campaignId == campaignId) {
        for (final task in proj.tasks) {
          result.add(TaskWithProject(task: task, project: proj));
        }
      }
    }
    // 2순위: task.tags / 이름 매칭 (campaignId 직접 연결이 없는 경우 보조)
    if (result.isEmpty) {
      final campaign = _campaigns.firstWhere((c) => c.id == campaignId,
          orElse: () => _campaigns.isNotEmpty ? _campaigns.first : CampaignModel(
            id: campaignId, name: '', type: '', status: '', channel: '',
            budget: 0, spent: 0, revenue: 0, impressions: 0, clicks: 0,
            conversions: 0, startDate: DateTime.now(), endDate: DateTime.now(),
          ));
      final lower = campaign.name.toLowerCase();
      if (lower.isNotEmpty) {
        for (final proj in _projectStore) {
          for (final task in proj.tasks) {
            final matches = task.tags.any((t) => t.toLowerCase().contains(lower)) ||
                task.title.toLowerCase().contains(lower) ||
                proj.name.toLowerCase().contains(lower);
            if (matches) result.add(TaskWithProject(task: task, project: proj));
          }
        }
      }
    }
    return result;
  }

  /// 특정 캠페인에 연결된 프로젝트 목록
  List<Project> getProjectsByCampaignId(String campaignId) =>
      _projectStore.where((p) => p.campaignId == campaignId).toList();

  /// 팀의 프로젝트 중 캠페인 미연결 목록
  List<Project> getUnlinkedProjectsForTeam(String teamId) =>
      _projectStore.where((p) => p.teamId == teamId && p.campaignId == null).toList();

  /// 프로젝트에 캠페인 연결/해제
  void updateProjectCampaign(String projectId, String? campaignId) {
    final proj = _projectStore.firstWhere((p) => p.id == projectId, orElse: () => _projectStore.first);
    proj.campaignId = campaignId;
    if (_uid != null) {
      _svc.saveProject(_uid!, proj);
      _saveToLocal(_uid!);
    }
    notifyListeners();
  }

  /// 전체 태스크 (팀 필터 없음)
  List<TaskWithProject> get allTasksWithProject {
    final result = <TaskWithProject>[];
    for (final proj in _projectStore) {
      for (final task in proj.tasks) {
        result.add(TaskWithProject(task: task, project: proj));
      }
    }
    return result;
  }

  /// 현재 선택된 팀의 태스크만 (대시보드 등 팀별 뷰에서 사용)
  List<TaskWithProject> get currentTeamTasksWithProject {
    final projects = currentTeamProjects;
    final result = <TaskWithProject>[];
    for (final proj in projects) {
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
  String get defaultSection  => _defaultSection;
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

  // ─── Dashboard Stats (팀별 필터링 적용) ────────────────────
  /// 현재 팀 캠페인 기반 예산 합계
  double get totalBudget => teamCampaigns.fold(0, (s, c) => s + c.budget);
  double get totalSpent => teamCampaigns.fold(0, (s, c) => s + c.spent);
  double get totalRevenue => teamCampaigns.fold(0, (s, c) => s + c.revenue);
  double get overallRoi => totalSpent > 0 ? ((totalRevenue - totalSpent) / totalSpent * 100) : 0;
  /// 현재 선택 팀 KPI 달성률 평균
  double get avgKpiAchievement {
    final list = _selectedTeamId != null ? currentTeamKpis : _kpis;
    if (list.isEmpty) return 0;
    return list.fold(0.0, (s, k) => s + k.achievementRate) / list.length;
  }
  int get activeCampaigns => teamCampaigns.where((c) => c.status == 'active').length;
  /// 현재 선택 팀 Task 수
  int get totalTasks => currentTeamTasks.length;
  int get doneTasks =>
      currentTeamTasks.where((t) => t.status == TaskStatus.done).length;

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

  // ─── 팀별 기간 필터링 (캠페인 + 프로젝트/태스크 기반) ────────
  /// 현재 팀의 기간 매출 (캠페인 기반, 기간 필터 적용)
  /// MonthlyData에 teamId 필드가 없으므로 팀별 캠페인에서 집계
  double get periodRevenue {
    // 1. 현재 팀 캠페인이 있으면 캠페인 매출 합산
    final campaigns = teamCampaigns;
    if (campaigns.isNotEmpty) {
      // 기간 필터: 캠페인 startDate~endDate 범위가 선택 기간과 겹치는 것만
      final filtered = _filterCampaignsByPeriod(campaigns);
      if (filtered.isNotEmpty) return filtered.fold(0, (s, c) => s + c.revenue);
      // 기간 필터 결과가 없으면 전체 팀 캠페인 합산
      return campaigns.fold(0, (s, c) => s + c.revenue);
    }
    // 2. 캠페인 없으면 MonthlyData에서 집계 (fallback)
    return filteredMonthlyData.fold(0, (s, d) => s + d.revenue);
  }

  /// 현재 팀의 기간 광고비 (캠페인 기반)
  double get periodAdSpend {
    final campaigns = teamCampaigns;
    if (campaigns.isNotEmpty) {
      final filtered = _filterCampaignsByPeriod(campaigns);
      if (filtered.isNotEmpty) return filtered.fold(0, (s, c) => s + c.spent);
      return campaigns.fold(0, (s, c) => s + c.spent);
    }
    return filteredMonthlyData.fold(0, (s, d) => s + d.adSpend);
  }

  /// 현재 팀의 기간 리드 수 (태스크 체크리스트 기반 또는 MonthlyData fallback)
  int get periodLeads {
    // 리드는 MonthlyData에만 있으므로 그대로 유지하되 팀 전환 시 전체 반환
    return filteredMonthlyData.fold(0, (s, d) => s + d.leads);
  }

  double get periodRoi => periodAdSpend > 0 ? ((periodRevenue - periodAdSpend) / periodAdSpend * 100) : 0;

  /// 기간에 맞는 캠페인 필터링 (startDate~endDate가 선택 기간과 겹침)
  List<CampaignModel> _filterCampaignsByPeriod(List<CampaignModel> campaigns) {
    final qMonths = _quarterMonths(_selectedYear, _selectedQuarter);
    if (qMonths == null) {
      // 연간 전체: 해당 연도와 겹치는 캠페인
      final yearStart = DateTime(int.tryParse(_selectedYear) ?? 2025, 1, 1);
      final yearEnd = DateTime((int.tryParse(_selectedYear) ?? 2025) + 1, 1, 1);
      return campaigns.where((c) =>
          c.startDate.isBefore(yearEnd) && c.endDate.isAfter(yearStart)).toList();
    }
    // 분기 필터: 해당 분기 월들과 겹치는 캠페인
    if (qMonths.isEmpty) return campaigns;
    final firstMonth = qMonths.first; // e.g. '2025-01'
    final lastMonth = qMonths.last;   // e.g. '2025-03'
    final parts1 = firstMonth.split('-');
    final parts2 = lastMonth.split('-');
    if (parts1.length < 2 || parts2.length < 2) return campaigns;
    final periodStart = DateTime(
        int.tryParse(parts1[0]) ?? 2025, int.tryParse(parts1[1]) ?? 1, 1);
    final endM = int.tryParse(parts2[1]) ?? 3;
    final endY = int.tryParse(parts2[0]) ?? 2025;
    final periodEnd = DateTime(endM == 12 ? endY + 1 : endY,
        endM == 12 ? 1 : endM + 1, 1);
    return campaigns.where((c) =>
        c.startDate.isBefore(periodEnd) && c.endDate.isAfter(periodStart)).toList();
  }

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

  // ─── Risk TOP 5 (현재 팀 기준) ────────────────────────────
  List<RiskItem> get top5RiskItems {
    final risks = <RiskItem>[];
    final now = DateTime.now();
    // 현재 선택된 팀의 프로젝트만 스캔
    final teamProjects = currentTeamProjects.isNotEmpty
        ? currentTeamProjects
        : _projectStore;
    for (final proj in teamProjects) {
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
    // KPI도 현재 팀 기준으로 필터
    final teamKpiList = currentTeamKpis.isNotEmpty ? currentTeamKpis : _kpis;
    for (final kpi in teamKpiList) {
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

  /// 디폴트(시작) 페이지 설정 — Firestore에도 저장
  Future<void> setDefaultSection(String section) async {
    _defaultSection  = section;
    _currentSection  = section;
    notifyListeners();
    if (_uid != null && _svc.isAvailable) {
      await _svc.saveUserPrefs(_uid!, {'defaultSection': section});
    }
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

  void selectCampaign(String campaignId) {
    _selectedProjectId = campaignId; // 캠페인 ID를 selectedProjectId에 임시 저장
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
    if (_uid != null) {
      _svc.saveTeam(_uid!, team);
      _saveToLocal(_uid!); // 로컬 캐시 갱신
    }
    notifyListeners();
  }

  /// 팀 설정 업데이트 (예산, 환율, 고객 파라미터 포함)
  void updateTeamSettings(String teamId, {
    double? annualBudget,
    String? budgetCurrency,
    double? exchangeRateUsd,
    double? exchangeRateEur,
    List<String>? clientIds,
    String? targetMarket,
    String? name,
    String? description,
  }) {
    final idx = _teams.indexWhere((t) => t.id == teamId);
    if (idx < 0) return;
    final t = _teams[idx];
    if (annualBudget != null) t.annualBudget = annualBudget;
    if (budgetCurrency != null) t.budgetCurrency = budgetCurrency;
    if (exchangeRateUsd != null) t.exchangeRateUsd = exchangeRateUsd;
    if (exchangeRateEur != null) t.exchangeRateEur = exchangeRateEur;
    if (clientIds != null) t.clientIds
      ..clear()
      ..addAll(clientIds);
    if (targetMarket != null) t.targetMarket = targetMarket;
    if (name != null) t.name = name;
    if (description != null) t.description = description;
    if (_uid != null) {
      _svc.saveTeam(_uid!, t);
      _saveToLocal(_uid!);
    }
    notifyListeners();
  }

  void inviteMember(String teamId, String userId, MemberRole role) {
    final idx = _teams.indexWhere((t) => t.id == teamId);
    if (idx < 0) return;

    // 이미 팀 멤버인지 확인
    if (_teams[idx].getMember(userId) != null) {
      if (kDebugMode) debugPrint('[inviteMember] User $userId is already a member of $teamId');
      return;
    }

    // allUsers에서 찾되, 없으면 null 반환 (잘못된 currentUser fallback 제거)
    final user = _allUsers.firstWhere(
      (u) => u.id == userId,
      orElse: () => _currentUser,
    );

    _teams[idx].members.add(TeamMember(
      id: 'tm_${DateTime.now().millisecondsSinceEpoch}',
      user: user,
      role: role,
      joinedAt: DateTime.now(),
    ));
    if (_uid != null) {
      _svc.saveTeam(_uid!, _teams[idx]);
      _saveToLocal(_uid!);
    }
    notifyListeners();
  }

  /// 이메일로 새 멤버를 팀에 추가 (allUsers에도 등록)
  void inviteMemberByEmail({
    required String teamId,
    required String email,
    required String name,
    required MemberRole role,
  }) {
    final teamIdx = _teams.indexWhere((t) => t.id == teamId);
    if (teamIdx < 0) return;

    // 이미 팀 내에 해당 이메일이 있는지 확인
    final alreadyInTeam = _teams[teamIdx].members.any(
      (m) => m.user.email.toLowerCase() == email.toLowerCase(),
    );
    if (alreadyInTeam) {
      if (kDebugMode) debugPrint('[inviteMemberByEmail] $email is already in team $teamId');
      return;
    }

    // allUsers에 없으면 새 유저 생성
    AppUser newUser;
    final existingIdx = _allUsers.indexWhere(
      (u) => u.email.toLowerCase() == email.toLowerCase(),
    );
    if (existingIdx < 0) {
      // 이니셜 생성 (한글 2자 or 영문 첫 2글자)
      String initials;
      if (name.length >= 2) {
        initials = name.substring(0, 2);
      } else {
        initials = name;
      }
      newUser = AppUser(
        id: 'u_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        email: email,
        avatarInitials: initials,
        avatarColor: _randomColor(),
        jobTitle: JobTitle.member,
        department: '',
      );
      _allUsers.add(newUser);
      // ✅ Firebase에 멤버 저장 (신규 유저만)
      if (_uid != null) _svc.saveMember(_uid!, newUser);
    } else {
      newUser = _allUsers[existingIdx];
    }
    inviteMember(teamId, newUser.id, role);
  }

  static String _randomColor() {
    const colors = ['#29B6F6','#AB47BC','#FF7043','#FFB300','#66BB6A','#EF5350','#26C6DA'];
    return colors[DateTime.now().millisecondsSinceEpoch % colors.length];
  }

  void updateMemberRole(String teamId, String memberId, MemberRole newRole) {
    final teamIdx = _teams.indexWhere((t) => t.id == teamId);
    if (teamIdx < 0) return;
    final team = _teams[teamIdx];
    final idx = team.members.indexWhere((m) => m.id == memberId);
    if (idx >= 0) {
      team.members[idx] = team.members[idx].copyWith(role: newRole);
      if (_uid != null) {
        _svc.saveTeam(_uid!, team);
        _saveToLocal(_uid!);
      }
      notifyListeners();
    }
  }

  void removeMember(String teamId, String memberId) {
    final teamIdx = _teams.indexWhere((t) => t.id == teamId);
    if (teamIdx < 0) return;
    final team = _teams[teamIdx];
    team.members.removeWhere((m) => m.id == memberId);
    if (_uid != null) {
      _svc.saveTeam(_uid!, team);
      _saveToLocal(_uid!);
    }
    notifyListeners();
  }

  /// 팀 삭제 (팀에 속한 프로젝트도 함께 삭제)
  Future<void> deleteTeam(String teamId) async {
    final team = _teams.firstWhere((t) => t.id == teamId, orElse: () => _teams.first);
    // 팀 소속 프로젝트 삭제
    final projIds = List<String>.from(team.projectIds);
    for (final pid in projIds) {
      _projectStore.removeWhere((p) => p.id == pid);
      if (_uid != null) await _svc.deleteProject(_uid!, pid);
    }
    // 팀 삭제
    _teams.removeWhere((t) => t.id == teamId);
    if (_uid != null) await _svc.deleteTeam(_uid!, teamId);
    // 선택된 팀/프로젝트 초기화
    if (_selectedTeamId == teamId) {
      _selectedTeamId = _teams.isNotEmpty ? _teams.first.id : null;
      _selectedProjectId = null;
    }
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
    if (_uid != null) {
      _svc.saveProject(_uid!, proj);        // 개인 store 저장
      _svc.saveTeam(_uid!, team);
      _svc.saveSharedProject(teamId, proj); // 팀 공유 저장 (팀원 동기화)
    }
    notifyListeners();
    return proj;
  }

  /// 프로젝트 업데이트 — Firestore에도 즉시 저장
  Future<void> updateProject(Project updated) async {
    final idx = _projectStore.indexWhere((p) => p.id == updated.id);
    if (idx < 0) return;
    _projectStore[idx] = updated;
    if (_uid != null) {
      await _svc.saveProject(_uid!, updated);          // 개인 store
      await _svc.saveSharedProject(updated.teamId, updated); // 팀 공유
    }
    notifyListeners();
  }

  /// 단일 프로젝트 삭제
  Future<void> deleteProject(String projectId) async {
    // 팀의 projectIds에서도 제거
    for (final team in _teams) {
      team.projectIds.remove(projectId);
      if (_uid != null) await _svc.saveTeam(_uid!, team);
    }
    _projectStore.removeWhere((p) => p.id == projectId);
    if (_uid != null) await _svc.deleteProject(_uid!, projectId);
    if (_selectedProjectId == projectId) _selectedProjectId = null;
    notifyListeners();
  }

  /// 선택된 팀의 프로젝트 일괄 삭제
  Future<void> deleteProjectsBulk(List<String> projectIds) async {
    for (final pid in projectIds) {
      await deleteProject(pid);
    }
  }

  /// 전체 데이터 리셋 (Firebase에서도 삭제 후 샘플 데이터로 재초기화)
  Future<void> resetAllData() async {
    if (_uid != null) {
      // Firebase에서 모든 데이터 삭제
      final futures = <Future>[];
      for (final t in List<Team>.from(_teams)) {
        futures.add(_svc.deleteTeam(_uid!, t.id));
      }
      for (final p in List<Project>.from(_projectStore)) {
        futures.add(_svc.deleteProject(_uid!, p.id));
      }
      for (final k in List<KpiModel>.from(_kpis)) {
        futures.add(_svc.deleteKpi(_uid!, k.id));
      }
      for (final c in List<CampaignModel>.from(_campaigns)) {
        futures.add(_svc.deleteCampaign(_uid!, c.id));
      }
      for (final r in List<MarketingRegion>.from(_regions)) {
        futures.add(_svc.deleteRegion(_uid!, r.id));
      }
      for (final c in List<ClientAccount>.from(_clients)) {
        futures.add(_svc.deleteClient(_uid!, c.id));
      }
      await Future.wait(futures);
    }
    // 메모리 초기화
    _teams.clear(); _projectStore.clear(); _kpis.clear();
    _campaigns.clear(); _funnelStages.clear(); _monthlyData.clear();
    _monthlyKpiRecords.clear(); _regions.clear(); _clients.clear();
    _allUsers.clear(); _revenueEntries.clear();
    _selectedTeamId = null; _selectedProjectId = null; _selectedTaskId = null;
    // 샘플 데이터 재생성
    initSampleData();
    // Firebase에 샘플 데이터 저장
    if (_uid != null) await _saveAllToFirebase(_uid!);
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
    if (_uid != null) _svc.saveProject(_uid!, proj);
    notifyListeners();
    return task;
  }

  void updateTaskStatus(String projectId, String taskId, TaskStatus status) {
    final proj = _projectStore.firstWhere((p) => p.id == projectId, orElse: () => _projectStore.first);
    final task = proj.tasks.firstWhere((t) => t.id == taskId);
    final prevStatus = task.status;
    task.status = status;
    task.updatedAt = DateTime.now();
    if (_uid != null) _svc.saveProject(_uid!, proj);

    // ── 태스크 완료 시 담당자 개인 KPI 자동 업데이트 ──────────
    if (status == TaskStatus.done && prevStatus != TaskStatus.done) {
      _autoUpdatePersonalKpiOnTaskDone(proj, task);
    }
    // 완료 → 되돌림 시 KPI 역산
    if (prevStatus == TaskStatus.done && status != TaskStatus.done) {
      _autoRevertPersonalKpiOnTaskUndone(proj, task);
    }

    notifyListeners();
  }

  /// 태스크 완료 시 담당자의 개인 KPI current 값 증가
  void _autoUpdatePersonalKpiOnTaskDone(Project proj, TaskDetail task) {
    for (final uid in task.assigneeIds) {
      // 해당 담당자의 개인 KPI 중 이 프로젝트/캠페인과 연결된 것
      final personalKpis = _kpis.where((k) =>
        !k.isTeamKpi &&
        k.assignedTo == uid &&
        (k.projectId == proj.id || (proj.campaignId != null && k.campaignId == proj.campaignId))
      ).toList();

      for (final kpi in personalKpis) {
        final idx = _kpis.indexWhere((k) => k.id == kpi.id);
        if (idx < 0) continue;
        // KPI 단위에 따라 증가 방식 결정
        final increment = _calcKpiIncrement(kpi, task);
        final newCurrent = (kpi.current + increment).clamp(0.0, kpi.target * 2);
        _kpis[idx] = kpi.copyWith(current: newCurrent);
        if (_uid != null) _svc.saveKpi(_uid!, _kpis[idx]);
      }
    }
  }

  /// 태스크 완료 취소 시 KPI 역산
  void _autoRevertPersonalKpiOnTaskUndone(Project proj, TaskDetail task) {
    for (final uid in task.assigneeIds) {
      final personalKpis = _kpis.where((k) =>
        !k.isTeamKpi &&
        k.assignedTo == uid &&
        (k.projectId == proj.id || (proj.campaignId != null && k.campaignId == proj.campaignId))
      ).toList();

      for (final kpi in personalKpis) {
        final idx = _kpis.indexWhere((k) => k.id == kpi.id);
        if (idx < 0) continue;
        final increment = _calcKpiIncrement(kpi, task);
        final newCurrent = (kpi.current - increment).clamp(0.0, kpi.target * 2);
        _kpis[idx] = kpi.copyWith(current: newCurrent);
        if (_uid != null) _svc.saveKpi(_uid!, _kpis[idx]);
      }
    }
  }

  /// KPI 증가량 계산 (단위별 처리)
  double _calcKpiIncrement(KpiModel kpi, TaskDetail task) {
    final unit = kpi.unit.toLowerCase();
    // 건수 단위: 태스크 1개 = 1 증가
    if (unit.contains('건') || unit.contains('개') || unit.contains('회') ||
        unit.contains('task') || unit.contains('count')) {
      return 1.0;
    }
    // 진행률 단위: 체크리스트 완료율 반영
    if (unit.contains('%') || unit.contains('율') || unit.contains('률')) {
      return task.checklistProgress;
    }
    // 예산/금액 단위: 태스크의 집행 비용 반영
    if (unit.contains('원') || unit.contains('usd') || unit.contains('krw') ||
        unit.contains('금액') || unit.contains('매출')) {
      return task.checklistTotalExecuted;
    }
    // 기본: 1 증가
    return 1.0;
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
  void addKpi(KpiModel kpi) {
    // KPI에 teamId가 없으면 현재 선택된 팀으로 자동 설정
    final kpiWithTeam = (kpi.teamId == null && _selectedTeamId != null)
        ? kpi.copyWith(teamId: _selectedTeamId)
        : kpi;
    _kpis.add(kpiWithTeam);
    if (_uid != null) {
      _svc.saveKpi(_uid!, kpiWithTeam);
      _saveToLocal(_uid!);
    }
    notifyListeners();
  }
  void updateKpi(KpiModel updated) {
    final idx = _kpis.indexWhere((k) => k.id == updated.id);
    if (idx >= 0) {
      _kpis[idx] = updated;
      if (_uid != null) {
        _svc.saveKpi(_uid!, updated);
        _saveToLocal(_uid!);
      }
      notifyListeners();
    }
  }
  void deleteKpi(String id) {
    _kpis.removeWhere((k) => k.id == id);
    if (_uid != null) {
      _svc.deleteKpi(_uid!, id);
      _saveToLocal(_uid!);
    }
    notifyListeners();
  }

  /// KPI를 프로젝트에 연결 (KpiModel.projectId 업데이트)
  void linkKpiToProject(String kpiId, String projectId) {
    final idx = _kpis.indexWhere((k) => k.id == kpiId);
    if (idx < 0) return;
    final old = _kpis[idx];
    _kpis[idx] = old.copyWith(projectId: projectId);
    if (_uid != null) _svc.saveKpi(_uid!, _kpis[idx]);
    notifyListeners();
  }

  /// KPI와 프로젝트 연결 해제
  void unlinkKpiFromProject(String kpiId, String projectId) {
    final idx = _kpis.indexWhere((k) => k.id == kpiId);
    if (idx < 0) return;
    final old = _kpis[idx];
    if (old.projectId != projectId) return;
    _kpis[idx] = old.copyWith(projectId: null);
    if (_uid != null) _svc.saveKpi(_uid!, _kpis[idx]);
    notifyListeners();
  }

  // ─── Task Delete ───────────────────────────────────────────
  /// 태스크 단일 삭제
  void deleteTask(String projectId, String taskId) {
    final proj = _projectStore.firstWhere(
      (p) => p.id == projectId,
      orElse: () => _projectStore.isEmpty ? throw StateError('no projects') : _projectStore.first,
    );
    proj.tasks.removeWhere((t) => t.id == taskId);
    if (_selectedTaskId == taskId) _selectedTaskId = null;
    if (_uid != null) _svc.saveProject(_uid!, proj);
    notifyListeners();
  }

  /// KPI 일괄 CSV 업로드
  /// columns: name, current, target, unit, category, date
  List<String> bulkAddKpisFromCsv(List<Map<String, String>> rows) {
    final errors = <String>[];
    int added = 0;

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final name = (row['name'] ?? row['title'] ?? '').trim();
      if (name.isEmpty) {
        errors.add('행 ${i+2}: 이름(name)이 비어 있습니다');
        continue;
      }

      // target이 없거나 0이어도 허용 (나중에 수정 가능)
      final target = double.tryParse(row['target']?.replaceAll(',', '') ?? '') ?? 0;
      final current = double.tryParse(row['current']?.replaceAll(',', '') ?? '') ?? 0;
      final unit = (row['unit'] ?? '건').trim();

      // 카테고리: 원본 값 그대로 허용 (고정 목록 제한 제거)
      final category = (row['category'] ?? '기타').trim().isEmpty ? '기타' : (row['category'] ?? '기타').trim();

      // 날짜 파싱
      DateTime dueDate = DateTime(DateTime.now().year, 12, 31);
      final dateStr = (row['date'] ?? row['duedate'] ?? row['due_date'] ?? '').trim();
      if (dateStr.isNotEmpty) {
        final parsed = DateTime.tryParse(dateStr);
        if (parsed != null) dueDate = parsed;
      }

      // 연도별/분기별 목표 파싱 (CSV에 y2025, y2026 컬럼이 있으면)
      final Map<String, double> yearlyTargets = {};
      final Map<String, double> quarterlyTargets = {};
      for (final key in row.keys) {
        // y2025, y2026 형태
        if (RegExp(r'^y\d{4}$').hasMatch(key)) {
          final yr = key.substring(1);
          final val = double.tryParse(row[key]?.replaceAll(',', '') ?? '');
          if (val != null) yearlyTargets[yr] = val;
        }
        // q1_2025, 2025q1, 2025_q1 형태
        final qMatch = RegExp(r'(?:q(\d)_?(\d{4})|(\d{4})_?q(\d))', caseSensitive: false).firstMatch(key);
        if (qMatch != null) {
          final q = qMatch.group(1) ?? qMatch.group(4) ?? '';
          final yr = qMatch.group(2) ?? qMatch.group(3) ?? '';
          if (q.isNotEmpty && yr.isNotEmpty) {
            final qKey = '$yr-Q$q';
            final val = double.tryParse(row[key]?.replaceAll(',', '') ?? '');
            if (val != null) quarterlyTargets[qKey] = val;
          }
        }
      }

      final kpi = KpiModel(
        id: 'kpi_csv_${DateTime.now().millisecondsSinceEpoch}_$i',
        title: name,
        category: category,
        target: target,
        current: current,
        unit: unit,
        period: _selectedPeriod,
        isTeamKpi: true,
        dueDate: dueDate,
        teamId: _selectedTeamId,
        yearlyTargets: yearlyTargets,
        quarterlyTargets: quarterlyTargets,
      );
      _kpis.add(kpi);
      if (_uid != null) _svc.saveKpi(_uid!, kpi);
      added++;
    }

    if (_uid != null && added > 0) _saveToLocal(_uid!);
    if (added > 0) notifyListeners();
    return errors;
  }

  /// KPI 일괄 삭제
  void deleteKpisBulk(List<String> ids) {
    _kpis.removeWhere((k) => ids.contains(k.id));
    if (_uid != null) {
      for (final id in ids) _svc.deleteKpi(_uid!, id);
      _saveToLocal(_uid!);
    }
    notifyListeners();
  }

  /// 태스크 일괄 삭제
  void deleteTasksBulk(String projectId, List<String> taskIds) {
    final proj = _projectStore.firstWhere(
      (p) => p.id == projectId,
      orElse: () => _projectStore.isEmpty ? throw StateError('no projects') : _projectStore.first,
    );
    proj.tasks.removeWhere((t) => taskIds.contains(t.id));
    if (taskIds.contains(_selectedTaskId)) _selectedTaskId = null;
    if (_uid != null) _svc.saveProject(_uid!, proj);
    notifyListeners();
  }

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
      KpiModel(id: 'kpi6', title: '이메일 오픈율', category: '이메일', target: 25, current: 28.4, unit: '%', period: 'Q1 2025', isTeamKpi: false, assignedTo: 'u2', dueDate: DateTime(now.year, 3, 31), teamId: 'team1'),
      KpiModel(id: 'kpi7', title: '콘텐츠 조회수', category: '콘텐츠', target: 100000, current: 87500, unit: '회', period: 'Q1 2025', isTeamKpi: false, assignedTo: 'u3', dueDate: DateTime(now.year, 3, 31), teamId: 'team1'),
      KpiModel(id: 'kpi8', title: 'SNS 팔로워 증가', category: 'SNS', target: 5000, current: 4200, unit: '명', period: 'Q1 2025', isTeamKpi: false, assignedTo: 'u3', dueDate: DateTime(now.year, 3, 31), teamId: 'team1'),
      KpiModel(id: 'kpi9', title: '오가닉 트래픽', category: 'SEO', target: 50000, current: 43200, unit: '방문', period: 'Q1 2025', isTeamKpi: false, assignedTo: 'u4', dueDate: DateTime(now.year, 3, 31), teamId: 'team2'),
      KpiModel(id: 'kpi10', title: '키워드 상위 노출', category: 'SEO', target: 20, current: 17, unit: '개', period: 'Q1 2025', isTeamKpi: false, assignedTo: 'u4', dueDate: DateTime(now.year, 3, 31), teamId: 'team2'),
      KpiModel(id: 'kpi11', title: 'CPA 목표', category: '광고', target: 15000, current: 18500, unit: '원', period: 'Q1 2025', isTeamKpi: false, assignedTo: 'u5', dueDate: DateTime(now.year, 3, 31), teamId: 'team2'),
      KpiModel(id: 'kpi12', title: '전환율', category: '전환', target: 5.0, current: 4.2, unit: '%', period: 'Q1 2025', isTeamKpi: false, assignedTo: 'u5', dueDate: DateTime(now.year, 3, 31), teamId: 'team2'),
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
  void addRegion(MarketingRegion r) {
    _regions.add(r);
    if (_uid != null) _svc.saveRegion(_uid!, r);
    notifyListeners();
  }
  void updateRegion(MarketingRegion r) {
    final i = _regions.indexWhere((x) => x.id == r.id);
    if (i >= 0) {
      _regions[i] = r;
      if (_uid != null) _svc.saveRegion(_uid!, r);
      notifyListeners();
    }
  }
  void deleteRegion(String id) {
    _regions.removeWhere((r) => r.id == id);
    if (_uid != null) _svc.deleteRegion(_uid!, id);
    notifyListeners();
  }

  // ─── 고객사 CRUD ──────────────────────────────────────────

  /// CSV 벌크 업로드: 중복 제거 후 일괄 등록, KPI/캠페인 자동 연결
  /// 반환값: {'added': int, 'skipped': int}
  Map<String, int> bulkAddClients(List<ClientAccount> incoming) {
    int added = 0;
    int skipped = 0;

    // 기존 ID/바이어코드 셋
    final existingIds = _clients.map((c) => c.id).toSet();
    final existingBuyerCodes = _clients
        .where((c) => c.buyerCode != null)
        .map((c) => c.buyerCode!)
        .toSet();

    for (final client in incoming) {
      // 중복 확인
      if (existingIds.contains(client.id) ||
          (client.buyerCode != null && existingBuyerCodes.contains(client.buyerCode))) {
        skipped++;
        continue;
      }

      // teamId 기본값 설정 (선택된 팀)
      final enriched = client.teamId != null
          ? client
          : ClientAccount(
              id: client.id,
              name: client.name,
              buyerCode: client.buyerCode,
              country: client.country,
              countryName: client.countryName,
              region: client.region,
              regionEn: client.regionEn,
              industry: client.industry,
              contactName: client.contactName,
              contactEmail: client.contactEmail,
              contactPhone: client.contactPhone,
              note: client.note,
              isActive: client.isActive,
              teamId: _selectedTeamId,
              salesOrg: client.salesOrg,
              salesOrgName: client.salesOrgName,
              distributionChannel: client.distributionChannel,
              currency: client.currency,
              salesZone: client.salesZone,
              incoterms: client.incoterms,
              incotermsDesc: client.incotermsDesc,
              soldToParty: client.soldToParty,
              soldToPartyName: client.soldToPartyName,
              billToParty: client.billToParty,
              billToPartyName: client.billToPartyName,
              shipToParty: client.shipToParty,
              shipToPartyName: client.shipToPartyName,
              settlementType: client.settlementType,
              settlementTypeDesc: client.settlementTypeDesc,
              pbOrderType: client.pbOrderType,
              revenue: client.revenue,
              adSpend: client.adSpend,
              createdAt: client.createdAt,
            );

      _clients.add(enriched);
      existingIds.add(enriched.id);
      if (enriched.buyerCode != null) existingBuyerCodes.add(enriched.buyerCode!);

      if (_uid != null) _svc.saveClient(_uid!, enriched);
      added++;
    }

    // 업로드 후 자동 연결: 같은 국가/권역의 활성 캠페인에 고객사 태그 자동 매핑
    _autoLinkClientsToTasks(incoming.where((c) => existingIds.contains(c.id)).toList());

    if (_uid != null) _saveToLocal(_uid!);
    notifyListeners();
    return {'added': added, 'skipped': skipped};
  }

  /// 업로드된 고객사를 동일 국가/권역 태스크에 자동 연결
  void _autoLinkClientsToTasks(List<ClientAccount> newClients) {
    if (newClients.isEmpty) return;
    bool changed = false;
    for (final proj in _projectStore) {
      for (final task in proj.tasks) {
        for (final client in newClients) {
          // 태스크의 defaultCountry나 defaultRegion이 고객사와 매치되면 연결
          final countryMatch = client.country != null &&
              task.defaultCountry?.toUpperCase() == client.country?.toUpperCase();
          final regionMatch = client.region != null &&
              task.defaultRegion?.contains(client.region ?? '') == true;
          if ((countryMatch || regionMatch) &&
              !task.targetClientIds.contains(client.id)) {
            task.targetClientIds.add(client.id);
            changed = true;
          }
        }
      }
    }
    if (changed && _uid != null) {
      for (final proj in _projectStore) {
        _svc.saveProject(_uid!, proj);
      }
    }
  }

  void addClient(ClientAccount c) {
    _clients.add(c);
    if (_uid != null) _svc.saveClient(_uid!, c);
    notifyListeners();
  }
  void updateClient(ClientAccount c) {
    final i = _clients.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      _clients[i] = c;
      if (_uid != null) _svc.saveClient(_uid!, c);
      notifyListeners();
    }
  }
  void deleteClient(String id) {
    _clients.removeWhere((c) => c.id == id);
    if (_uid != null) _svc.deleteClient(_uid!, id);
    notifyListeners();
  }

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

  // ─── 프로젝트 전체 편집 + Firestore 즉시 저장 ──────────────
  void updateProjectFields(String projectId, {
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
        // Firestore 즉시 저장
        if (_uid != null) {
          _svc.saveProject(_uid!, proj);
          _svc.saveSharedProject(proj.teamId, proj);
        }
        notifyListeners();
        return;
      }
    }
  }

  // ─── 태스크 전체 편집 ─────────────────────────────────────
  void updateTask(String projectId, TaskDetail taskOrId, {
    String? title, String? description, TaskStatus? status, TaskPriority? priority,
    DateTime? dueDate, DateTime? startDate, List<String>? assigneeIds,
    List<String>? tags, String? kpiId, StrategyPillar? pillar,
  }) {
    final taskId = taskOrId.id;
    for (final proj in _projectStore) {
      if (proj.id != projectId) continue;
      for (int i = 0; i < proj.tasks.length; i++) {
        if (proj.tasks[i].id != taskId) continue;
        // taskOrId 자체를 직접 넣어 (이미 수정된 TaskDetail 객체)
        proj.tasks[i] = taskOrId;
        final t = proj.tasks[i];
        // 추가 named 파라미터로 overwrite
        if (title != null) t.title = title;
        if (description != null) t.description = description;
        if (status != null) t.status = status;
        if (priority != null) t.priority = priority;
        if (dueDate != null) t.dueDate = dueDate;
        if (startDate != null) t.startDate = startDate;
        if (assigneeIds != null) { t.assigneeIds.clear(); t.assigneeIds.addAll(assigneeIds); }
        if (tags != null) { t.tags.clear(); t.tags.addAll(tags); }
        if (kpiId != null) t.kpiId = kpiId;
        if (pillar != null) t.pillar = pillar;
        t.updatedAt = DateTime.now();
        // ✅ Firebase에 프로젝트 저장
        if (_uid != null) {
          _svc.saveProject(_uid!, proj);
          _saveToLocal(_uid!);
        }
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
