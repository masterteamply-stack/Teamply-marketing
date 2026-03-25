// ════════════════════════════════════════════════════════════
//  MarketingDashboardProvider
//  담당자(TeamMember) + 태스크(MarketingTask) 상태 관리
//  백엔드: Supabase (isAvailable) → SharedPreferences 로컬 캐시 fallback
//
//  Supabase 테이블 (SQL Editor에서 실행):
//  ────────────────────────────────────────────────────────
//  create table marketing_members (
//    id          text primary key,
//    uid         text not null,          -- auth.uid()
//    team_id     text,
//    data        jsonb not null,
//    updated_at  timestamptz default now()
//  );
//  alter table marketing_members enable row level security;
//  create policy "owner" on marketing_members using (uid = auth.uid()::text);
//
//  create table marketing_tasks (
//    id          text primary key,
//    uid         text not null,
//    team_id     text,
//    data        jsonb not null,
//    updated_at  timestamptz default now()
//  );
//  alter table marketing_tasks enable row level security;
//  create policy "owner" on marketing_tasks using (uid = auth.uid()::text);
// ════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/team_member.dart';
import '../models/marketing_task.dart';

class MarketingDashboardProvider extends ChangeNotifier {
  // ── 상태 ─────────────────────────────────────────────────
  List<TeamMember> _members = [];
  List<MarketingTask> _tasks = [];
  String? _uid;
  String? _currentTeamId;
  bool _isLoading = false;
  String? _errorMessage;

  // ── SharedPreferences 키 ─────────────────────────────────
  static const _kMembers = 'mkt_members_v1';
  static const _kTasks = 'mkt_tasks_v1';

  // ── Getters ───────────────────────────────────────────────
  List<TeamMember> get teamMembers => List.unmodifiable(_members);
  List<MarketingTask> get tasks => List.unmodifiable(_tasks);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<MarketingTask> get inProgressTasks =>
      _tasks.where((t) => t.status == TaskStatus.inProgress).toList();

  List<MarketingTask> get upcomingTasks {
    final now = DateTime.now();
    return _tasks
        .where((t) =>
            t.status != TaskStatus.completed &&
            t.dueDate.isAfter(now) &&
            t.dueDate.isBefore(now.add(const Duration(days: 3))))
        .toList();
  }

  List<MarketingTask> get overdueTasks {
    final now = DateTime.now();
    return _tasks
        .where((t) =>
            t.status != TaskStatus.completed && t.dueDate.isBefore(now))
        .toList();
  }

  Map<String, int> get taskCountByMember {
    final result = <String, int>{};
    for (final m in _members) {
      result[m.id] = 0;
    }
    for (final t in _tasks) {
      for (final id in t.assigneeIds) {
        result[id] = (result[id] ?? 0) + 1;
      }
    }
    return result;
  }

  Map<String, double> get progressByMember {
    final result = <String, double>{};
    for (final m in _members) {
      final mt = _tasks.where((t) => t.assigneeIds.contains(m.id)).toList();
      result[m.id] = mt.isEmpty
          ? 0.0
          : mt.fold<double>(0, (s, t) => s + t.progress) / mt.length;
    }
    return result;
  }

  TeamMember? getTeamMemberById(String id) {
    try {
      return _members.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Supabase 클라이언트 ───────────────────────────────────
  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get _isSupabaseAvailable => _db != null;

  // ════════════════════════════════════════════════════════
  //  초기화 – 로그인 후 호출
  // ════════════════════════════════════════════════════════
  Future<void> loadTeamData(String teamId, {String? uid}) async {
    _currentTeamId = teamId;
    _uid = uid;
    _setLoading(true);

    // ① 로컬 캐시 먼저 복원
    await _loadFromLocal();

    // ② Supabase에서 최신 데이터 동기화
    if (_isSupabaseAvailable && _uid != null) {
      await _loadFromSupabase();
      await _saveToLocal(); // 캐시 갱신
    }

    _setLoading(false);
  }

  // ── 로컬 캐시 저장/복원 ────────────────────────────────────
  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kMembers,
        jsonEncode(_members.map((m) => m.toJson()).toList()),
      );
      await prefs.setString(
        _kTasks,
        jsonEncode(_tasks.map((t) => t.toJson()).toList()),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[MktProvider] _saveToLocal error: $e');
    }
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mJson = prefs.getString(_kMembers);
      final tJson = prefs.getString(_kTasks);
      if (mJson != null) {
        final list = jsonDecode(mJson) as List;
        _members = list
            .map((e) => TeamMember.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (tJson != null) {
        final list = jsonDecode(tJson) as List;
        _tasks = list
            .map((e) => MarketingTask.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[MktProvider] _loadFromLocal error: $e');
    }
  }

  // ── Supabase 로드 ─────────────────────────────────────────
  // marketing_members/marketing_tasks 테이블 우선,
  // 없으면 user_data 테이블에서 fallback 로드
  Future<void> _loadFromSupabase() async {
    final db = _db;
    if (db == null || _uid == null) return;
    try {
      // ── 멤버 로드 ────────────────────────────────────────
      List<TeamMember> loadedMembers = [];
      bool usedDedicatedMemberTable = false;
      try {
        final mRows = await db
            .from('marketing_members')
            .select('data')
            .eq('uid', _uid!);
        loadedMembers = (mRows as List)
            .map((r) {
              try {
                return TeamMember.fromJson(
                    Map<String, dynamic>.from(r['data'] as Map));
              } catch (_) {
                return null;
              }
            })
            .whereType<TeamMember>()
            .toList();
        usedDedicatedMemberTable = true;
      } catch (e) {
        // marketing_members 테이블 없음 → user_data fallback
        if (kDebugMode) {
          debugPrint('[MktProvider] marketing_members 테이블 없음, user_data fallback: $e');
        }
        try {
          final fallbackRows = await db
              .from('user_data')
              .select('data')
              .eq('uid', _uid!)
              .eq('table_name', 'marketing_members');
          loadedMembers = (fallbackRows as List)
              .map((r) {
                try {
                  return TeamMember.fromJson(
                      Map<String, dynamic>.from(r['data'] as Map));
                } catch (_) {
                  return null;
                }
              })
              .whereType<TeamMember>()
              .toList();
        } catch (fallbackErr) {
          if (kDebugMode) {
            debugPrint('[MktProvider] user_data fallback 멤버 로드 오류: $fallbackErr');
          }
        }
      }
      if (loadedMembers.isNotEmpty) _members = loadedMembers;

      // ── 태스크 로드 ──────────────────────────────────────
      List<MarketingTask> loadedTasks = [];
      try {
        final tRows = await db
            .from('marketing_tasks')
            .select('data')
            .eq('uid', _uid!);
        loadedTasks = (tRows as List)
            .map((r) {
              try {
                return MarketingTask.fromJson(
                    Map<String, dynamic>.from(r['data'] as Map));
              } catch (_) {
                return null;
              }
            })
            .whereType<MarketingTask>()
            .toList();
      } catch (e) {
        // marketing_tasks 테이블 없음 → user_data fallback
        if (kDebugMode) {
          debugPrint('[MktProvider] marketing_tasks 테이블 없음, user_data fallback: $e');
        }
        try {
          final fallbackRows = await db
              .from('user_data')
              .select('data')
              .eq('uid', _uid!)
              .eq('table_name', 'marketing_tasks');
          loadedTasks = (fallbackRows as List)
              .map((r) {
                try {
                  return MarketingTask.fromJson(
                      Map<String, dynamic>.from(r['data'] as Map));
                } catch (_) {
                  return null;
                }
              })
              .whereType<MarketingTask>()
              .toList();
        } catch (fallbackErr) {
          if (kDebugMode) {
            debugPrint('[MktProvider] user_data fallback 태스크 로드 오류: $fallbackErr');
          }
        }
      }
      if (loadedTasks.isNotEmpty) _tasks = loadedTasks;

      if (kDebugMode) {
        debugPrint(
          '[MktProvider] Loaded ${_members.length} members'
          ' (${usedDedicatedMemberTable ? "marketing_members" : "user_data fallback"}),'
          ' ${_tasks.length} tasks from Supabase',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[MktProvider] _loadFromSupabase error: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  //  TeamMember CRUD
  // ════════════════════════════════════════════════════════
  Future<bool> addTeamMember({
    required String name,
    required String role,
    required String department,
    String? avatarUrl,
  }) async {
    _clearError();
    if (_members.any((m) => m.name == name)) {
      _setError('이미 존재하는 담당자입니다.');
      return false;
    }
    final member = TeamMember(
      id: const Uuid().v4(),
      name: name,
      role: role,
      department: department,
      avatarUrl: avatarUrl,
      createdAt: DateTime.now(),
    );
    _members.add(member);
    notifyListeners();

    // Supabase 저장
    await _upsertMember(member);
    await _saveToLocal();
    return true;
  }

  Future<bool> updateTeamMember({
    required String memberId,
    String? name,
    String? role,
    String? department,
    String? avatarUrl,
  }) async {
    _clearError();
    final idx = _members.indexWhere((m) => m.id == memberId);
    if (idx < 0) {
      _setError('담당자를 찾을 수 없습니다.');
      return false;
    }
    final updated = _members[idx]
        .copyWith(name: name, role: role, department: department, avatarUrl: avatarUrl);
    _members[idx] = updated;
    notifyListeners();

    await _upsertMember(updated);
    await _saveToLocal();
    return true;
  }

  Future<bool> removeTeamMember(String memberId) async {
    _clearError();
    _members.removeWhere((m) => m.id == memberId);
    // 태스크에서도 제거
    for (var i = 0; i < _tasks.length; i++) {
      if (_tasks[i].assigneeIds.contains(memberId)) {
        final newIds = List<String>.from(_tasks[i].assigneeIds)
          ..remove(memberId);
        _tasks[i] = _tasks[i].copyWith(
            assigneeIds: newIds, updatedAt: DateTime.now());
      }
    }
    notifyListeners();

    await _deleteMember(memberId);
    await _saveToLocal();
    return true;
  }

  // ════════════════════════════════════════════════════════
  //  MarketingTask CRUD
  // ════════════════════════════════════════════════════════
  Future<bool> addTask({
    required String title,
    required String description,
    required List<String> assigneeIds,
    required DateTime dueDate,
    required TaskPriority priority,
  }) async {
    _clearError();
    final task = MarketingTask(
      id: const Uuid().v4(),
      title: title,
      description: description,
      assigneeIds: assigneeIds,
      dueDate: dueDate,
      priority: priority,
      status: TaskStatus.pending,
      progress: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      teamId: _currentTeamId,
    );
    _tasks.add(task);
    notifyListeners();

    await _upsertTask(task);
    await _saveToLocal();
    return true;
  }

  Future<bool> updateTask({
    required String taskId,
    String? title,
    String? description,
    List<String>? assigneeIds,
    DateTime? dueDate,
    TaskPriority? priority,
    TaskStatus? status,
    int? progress,
  }) async {
    _clearError();
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx < 0) {
      _setError('태스크를 찾을 수 없습니다.');
      return false;
    }
    final updated = _tasks[idx].copyWith(
      title: title,
      description: description,
      assigneeIds: assigneeIds,
      dueDate: dueDate,
      priority: priority,
      status: status,
      progress: progress,
      updatedAt: DateTime.now(),
    );
    _tasks[idx] = updated;
    notifyListeners();

    await _upsertTask(updated);
    await _saveToLocal();
    return true;
  }

  Future<bool> removeTask(String taskId) async {
    _clearError();
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();

    await _deleteTask(taskId);
    await _saveToLocal();
    return true;
  }

  Future<bool> updateTaskStatus(String taskId, TaskStatus status) =>
      updateTask(taskId: taskId, status: status);

  Future<bool> updateTaskProgress(String taskId, int progress) {
    if (progress < 0 || progress > 100) {
      _setError('진행률은 0~100 사이여야 합니다.');
      return Future.value(false);
    }
    return updateTask(taskId: taskId, progress: progress);
  }

  Future<bool> addAssigneeToTask(String taskId, String memberId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx < 0) return false;
    if (_tasks[idx].assigneeIds.contains(memberId)) {
      _setError('이미 지정된 담당자입니다.');
      return false;
    }
    return updateTask(
      taskId: taskId,
      assigneeIds: [..._tasks[idx].assigneeIds, memberId],
    );
  }

  Future<bool> removeAssigneeFromTask(String taskId, String memberId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx < 0) return false;
    final newIds = List<String>.from(_tasks[idx].assigneeIds)..remove(memberId);
    return updateTask(taskId: taskId, assigneeIds: newIds);
  }

  // ════════════════════════════════════════════════════════
  //  Supabase 헬퍼 – 멤버
  // ════════════════════════════════════════════════════════
  Future<void> _upsertMember(TeamMember member) async {
    final db = _db;
    if (db == null || _uid == null) return;
    // marketing_members 테이블 시도, 없으면 user_data fallback
    try {
      await db.from('marketing_members').upsert({
        'id': member.id,
        'uid': _uid,
        'team_id': _currentTeamId,
        'data': member.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');
      if (kDebugMode) debugPrint('[MktProvider] member upserted (dedicated): ${member.id}');
    } catch (e) {
      // 전용 테이블 없음 → user_data fallback
      if (kDebugMode) debugPrint('[MktProvider] marketing_members upsert failed, fallback: $e');
      try {
        await db.from('user_data').upsert({
          'uid': _uid,
          'table_name': 'marketing_members',
          'record_id': member.id,
          'data': member.toJson(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'uid,table_name,record_id');
        if (kDebugMode) debugPrint('[MktProvider] member upserted (user_data fallback): ${member.id}');
      } catch (e2) {
        if (kDebugMode) debugPrint('[MktProvider] _upsertMember fallback error: $e2');
      }
    }
  }

  Future<void> _deleteMember(String memberId) async {
    final db = _db;
    if (db == null || _uid == null) return;
    try {
      await db
          .from('marketing_members')
          .delete()
          .eq('id', memberId)
          .eq('uid', _uid!);
    } catch (e) {
      // fallback: user_data에서 삭제
      try {
        await db
            .from('user_data')
            .delete()
            .eq('uid', _uid!)
            .eq('table_name', 'marketing_members')
            .eq('record_id', memberId);
      } catch (e2) {
        if (kDebugMode) debugPrint('[MktProvider] _deleteMember error: $e2');
      }
    }
  }

  // ════════════════════════════════════════════════════════
  //  Supabase 헬퍼 – 태스크
  // ════════════════════════════════════════════════════════
  Future<void> _upsertTask(MarketingTask task) async {
    final db = _db;
    if (db == null || _uid == null) return;
    try {
      await db.from('marketing_tasks').upsert({
        'id': task.id,
        'uid': _uid,
        'team_id': _currentTeamId,
        'data': task.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');
      if (kDebugMode) debugPrint('[MktProvider] task upserted (dedicated): ${task.id}');
    } catch (e) {
      // 전용 테이블 없음 → user_data fallback
      if (kDebugMode) debugPrint('[MktProvider] marketing_tasks upsert failed, fallback: $e');
      try {
        await db.from('user_data').upsert({
          'uid': _uid,
          'table_name': 'marketing_tasks',
          'record_id': task.id,
          'data': task.toJson(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'uid,table_name,record_id');
        if (kDebugMode) debugPrint('[MktProvider] task upserted (user_data fallback): ${task.id}');
      } catch (e2) {
        if (kDebugMode) debugPrint('[MktProvider] _upsertTask fallback error: $e2');
      }
    }
  }

  Future<void> _deleteTask(String taskId) async {
    final db = _db;
    if (db == null || _uid == null) return;
    try {
      await db
          .from('marketing_tasks')
          .delete()
          .eq('id', taskId)
          .eq('uid', _uid!);
    } catch (e) {
      // fallback: user_data에서 삭제
      try {
        await db
            .from('user_data')
            .delete()
            .eq('uid', _uid!)
            .eq('table_name', 'marketing_tasks')
            .eq('record_id', taskId);
      } catch (e2) {
        if (kDebugMode) debugPrint('[MktProvider] _deleteTask error: $e2');
      }
    }
  }

  // ════════════════════════════════════════════════════════
  //  KPI 저장 (Supabase kpis 테이블 직접 insert)
  //  user_data 테이블의 table_name='kpis' 방식과 동일
  // ════════════════════════════════════════════════════════
  /// saveKpi: kpi Map을 user_data 테이블에 직접 upsert
  Future<void> saveKpi(Map<String, dynamic> kpi) async {
    final db = _db;
    if (db == null || _uid == null) return;
    try {
      await db.from('user_data').upsert({
        'uid': _uid,
        'table_name': 'kpis',
        'record_id': kpi['id'] as String,
        'data': kpi,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'uid,table_name,record_id');
      if (kDebugMode) debugPrint('[MktProvider] KPI saved: ${kpi['id']}');
    } catch (e) {
      if (kDebugMode) debugPrint('[MktProvider] saveKpi error: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  //  정리
  // ════════════════════════════════════════════════════════
  void clearAll() {
    _members.clear();
    _tasks.clear();
    _uid = null;
    _currentTeamId = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── 내부 헬퍼 ─────────────────────────────────────────────
  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
