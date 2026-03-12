// lib/providers/team_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team_member.dart';
import '../models/task.dart';
import '../config/hive_config.dart';

class TeamProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  
  // ─────────────────────────────────────────────────────
  //  상태 변수
  // ─────────────────────────────────────────────────────
  List<TeamMember> _teamMembers = [];
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _error;
  String? _teamId;
  
  // Real-time listeners
  StreamSubscription? _membersSubscription;
  StreamSubscription? _tasksSubscription;

  // ─────────────────────────────────────────────────────
  //  Getters
  // ─────────────────────────────────────────────────────
  List<TeamMember> get teamMembers => List.unmodifiable(_teamMembers);
  List<Task> get tasks => List.unmodifiable(_tasks);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get teamId => _teamId;
  
  // 통계 Getters
  int get totalMembers => _teamMembers.length;
  int get activeTasks =>
      _tasks.where((t) => t.status != TaskStatus.completed).length;
  int get completedTasks =>
      _tasks.where((t) => t.status == TaskStatus.completed).length;
  double get overallProgress {
    if (_tasks.isEmpty) return 0;
    return _tasks.fold<int>(0, (sum, task) => sum + task.progress) /
        (_tasks.length * 100);
  }

  TeamProvider(this._firestore);

  // ─────────────────────────────────────────────────────
  //  팀 초기화 및 정리
  // ─────────────────────────────────────────────────────
  
  /// 팀 초기화 (최초 로드)
  Future<void> initializeTeam(String teamId) async {
    if (_teamId == teamId && _teamMembers.isNotEmpty) {
      return; // 이미 초기화됨
    }

    _teamId = teamId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. 로컬 캐시에서 로드
      final cachedMembers = HiveConfig.getTeamMembers();
      if (cachedMembers.isNotEmpty) {
        _teamMembers = List.from(cachedMembers);
        notifyListeners();
      }

      // 2. Firebase에서 최신 데이터 로드
      await _loadTeamMembers();
      await _loadTasks();
      
      // 3. Real-time listeners 설정
      _setupRealtimeListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('[TeamProvider] Initialization error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Real-time 리스너 설정
  void _setupRealtimeListeners() {
    if (_teamId == null) return;

    // 담당자 실시간 감시
    _membersSubscription = _firestore
        .collection('teams')
        .doc(_teamId)
        .collection('members')
        .snapshots()
        .listen(
          (snapshot) {
            _teamMembers = snapshot.docs
                .map((doc) => TeamMember.fromFirestore(doc.data()))
                .toList();
            notifyListeners();
          },
          onError: (e) {
            debugPrint('[TeamProvider] Members listener error: $e');
            _error = e.toString();
            notifyListeners();
          },
        );

    // 태스크 실시간 감시
    _tasksSubscription = _firestore
        .collection('teams')
        .doc(_teamId)
        .collection('tasks')
        .snapshots()
        .listen(
          (snapshot) {
            _tasks = snapshot.docs
                .map((doc) => Task.fromFirestore(doc.data()))
                .toList();
            // 마감일 순으로 정렬
            _tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
            notifyListeners();
          },
          onError: (e) {
            debugPrint('[TeamProvider] Tasks listener error: $e');
            _error = e.toString();
            notifyListeners();
          },
        );
  }

  /// 정리 (dispose 시 호출)
  void cleanup() {
    _membersSubscription?.cancel();
    _tasksSubscription?.cancel();
    _teamMembers.clear();
    _tasks.clear();
    _teamId = null;
  }

  @override
  void dispose() {
    cleanup();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────
  //  담당자 관리 (CRUD)
  // ─────────────────────────────────────────────────────

  /// 담당자 추가
  Future<String> addTeamMember({
    required String name,
    required String role,
    required String department,
  }) async {
    if (_teamId == null) throw Exception('Team not initialized');

    try {
      _error = null;
      
      final newMember = TeamMember(
        name: name,
        role: role,
        department: department,
        teamId: _teamId!,
      );

      // Firebase에 저장
      await _firestore
          .collection('teams')
          .doc(_teamId)
          .collection('members')
          .doc(newMember.id)
          .set(newMember.toFirestore());

      // 로컬 캐시 업데이트
      await HiveConfig.addTeamMember(newMember);

      // 로컬 상태는 real-time listener가 업데이트함
      debugPrint('[TeamProvider] Added member: ${newMember.name}');
      
      return newMember.id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 담당자 수정
  Future<void> updateTeamMember({
    required String memberId,
    required String name,
    required String role,
    required String department,
  }) async {
    if (_teamId == null) throw Exception('Team not initialized');

    try {
      _error = null;
      
      final index = _teamMembers.indexWhere((m) => m.id == memberId);
      if (index == -1) throw Exception('Member not found');

      final updated = _teamMembers[index].copyWith(
        name: name,
        role: role,
        department: department,
      );

      // Firebase 업데이트
      await _firestore
          .collection('teams')
          .doc(_teamId)
          .collection('members')
          .doc(memberId)
          .update(updated.toFirestore());

      // 로컬 캐시 업데이트
      await HiveConfig.addTeamMember(updated);

      // 로컬 상태는 real-time listener가 업데이트함
      debugPrint('[TeamProvider] Updated member: ${updated.name}');
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 담당자 삭제
  Future<void> deleteTeamMember(String memberId) async {
    if (_teamId == null) throw Exception('Team not initialized');

    try {
      _error = null;

      // Firebase에서 삭제
      await _firestore
          .collection('teams')
          .doc(_teamId)
          .collection('members')
          .doc(memberId)
          .delete();

      // 해당 담당자가 지정된 모든 태스크에서 제거
      final tasksToUpdate = _tasks
          .where((task) => task.assigneeIds.contains(memberId))
          .toList();

      for (var task in tasksToUpdate) {
        final updatedAssignees = task.assigneeIds
            .where((id) => id != memberId)
            .toList();
        
        await _firestore
            .collection('teams')
            .doc(_teamId)
            .collection('tasks')
            .doc(task.id)
            .update({'assigneeIds': updatedAssignees});
      }

      // 로컬에서 삭제
      await HiveConfig.deleteTeamMember(memberId);

      // 로컬 상태는 real-time listener가 업데이트함
      debugPrint('[TeamProvider] Deleted member: $memberId');
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────
  //  태스크 관리 (CRUD)
  // ─────────────────────────────────────────────────────

  /// 태스크 생성
  Future<String> addTask({
    required String title,
    required String description,
    required DateTime dueDate,
    required TaskPriority priority,
    required List<String> assigneeIds,
    required String createdBy,
  }) async {
    if (_teamId == null) throw Exception('Team not initialized');

    try {
      _error = null;
      
      final newTask = Task(
        title: title,
        description: description,
        assigneeIds: assigneeIds,
        dueDate: dueDate,
        priority: priority,
        status: TaskStatus.pending,
        progress: 0,
        createdBy: createdBy,
        teamId: _teamId!,
      );

      // Firebase에 저장
      await _firestore
          .collection('teams')
          .doc(_teamId)
          .collection('tasks')
          .doc(newTask.id)
          .set(newTask.toFirestore());

      // 로컬 상태는 real-time listener가 업데이트함
      debugPrint('[TeamProvider] Added task: ${newTask.title}');
      
      return newTask.id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 태스크 수정
  Future<void> updateTask(Task task) async {
    if (_teamId == null) throw Exception('Team not initialized');

    try {
      _error = null;

      await _firestore
          .collection('teams')
          .doc(_teamId)
          .collection('tasks')
          .doc(task.id)
          .update(task.toFirestore());

      // 로컬 상태는 real-time listener가 업데이트함
      debugPrint('[TeamProvider] Updated task: ${task.title}');
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 태스크 상태 변경
  Future<void> updateTaskStatus(
    String taskId,
    TaskStatus newStatus,
  ) async {
    final task = _tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw Exception('Task not found'),
    );
    
    final updated = task.copyWith(status: newStatus);
    await updateTask(updated);
  }

  /// 태스크 진행률 업데이트
  Future<void> updateTaskProgress(String taskId, int progress) async {
    final task = _tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw Exception('Task not found'),
    );
    
    final updated = task.copyWith(progress: progress.clamp(0, 100));
    await updateTask(updated);
  }

  /// 태스크 담당자 수정
  Future<void> updateTaskAssignees(
    String taskId,
    List<String> assigneeIds,
  ) async {
    final task = _tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw Exception('Task not found'),
    );
    
    final updated = task.copyWith(assigneeIds: assigneeIds);
    await updateTask(updated);
  }

  /// 태스크 삭제
  Future<void> deleteTask(String taskId) async {
    if (_teamId == null) throw Exception('Team not initialized');

    try {
      _error = null;

      await _firestore
          .collection('teams')
          .doc(_teamId)
          .collection('tasks')
          .doc(taskId)
          .delete();

      // 로컬 상태는 real-time listener가 업데이트함
      debugPrint('[TeamProvider] Deleted task: $taskId');
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────
  //  데이터 로드 (초기화용)
  // ─────────────────────────────────────────────────────

  Future<void> _loadTeamMembers() async {
    if (_teamId == null) return;

    try {
      final snapshot = await _firestore
          .collection('teams')
          .doc(_teamId)
          .collection('members')
          .get();

      _teamMembers = snapshot.docs
          .map((doc) => TeamMember.fromFirestore(doc.data()))
          .toList();

      // 로컬 캐시 업데이트
      await HiveConfig.saveTeamMembers(_teamMembers);
      
      debugPrint('[TeamProvider] Loaded ${_teamMembers.length} members');
    } catch (e) {
      debugPrint('[TeamProvider] Error loading members: $e');
      _error = e.toString();
    }
  }

  Future<void> _loadTasks() async {
    if (_teamId == null) return;

    try {
      final snapshot = await _firestore
          .collection('teams')
          .doc(_teamId)
          .collection('tasks')
          .orderBy('dueDate')
          .get();

      _tasks = snapshot.docs
          .map((doc) => Task.fromFirestore(doc.data()))
          .toList();

      debugPrint('[TeamProvider] Loaded ${_tasks.length} tasks');
    } catch (e) {
      debugPrint('[TeamProvider] Error loading tasks: $e');
      _error = e.toString();
    }
  }

  // ─────────────────────────────────────────────────────
  //  쿼리 유틸리티 메서드
  // ─────────────────────────────────────────────────────

  /// 담당자의 할당된 태스크 수
  int getMemberTaskCount(String memberId) {
    return _tasks
        .where((task) => task.assigneeIds.contains(memberId))
        .length;
  }

  /// 담당자의 진행 중인 태스크
  List<Task> getMemberActiveTasks(String memberId) {
    return _tasks
        .where((task) =>
            task.assigneeIds.contains(memberId) &&
            task.status != TaskStatus.completed)
        .toList();
  }

  /// 담당자의 미완료 태스크 진행률 평균
  double getMemberAverageProgress(String memberId) {
    final tasks = getMemberActiveTasks(memberId);
    if (tasks.isEmpty) return 0;
    return tasks.fold<int>(0, (sum, task) => sum + task.progress) /
        tasks.length;
  }

  /// 마감 임박 태스크 (3일 이내, 완료되지 않음)
  List<Task> getUrgentTasks() {
    final now = DateTime.now();
    final threeDaysLater = now.add(const Duration(days: 3));
    return _tasks
        .where((task) =>
            task.dueDate.isBefore(threeDaysLater) &&
            task.status != TaskStatus.completed)
        .toList();
  }

  /// 마감 지난 태스크
  List<Task> getOverdueTasks() {
    return _tasks
        .where((task) =>
            DateTime.now().isAfter(task.dueDate) &&
            task.status != TaskStatus.completed)
        .toList();
  }

  /// 우선순위별 태스크 필터링
  List<Task> getTasksByPriority(TaskPriority priority) {
    return _tasks.where((task) => task.priority == priority).toList();
  }

  /// 상태별 태스크 필터링
  List<Task> getTasksByStatus(TaskStatus status) {
    return _tasks.where((task) => task.status == status).toList();
  }

  /// 담당자 검색
  TeamMember? findMemberById(String memberId) {
    try {
      return _teamMembers.firstWhere((m) => m.id == memberId);
    } catch (_) {
      return null;
    }
  }

  /// 담당자 이름으로 검색
  List<TeamMember> searchMembers(String query) {
    if (query.isEmpty) return _teamMembers;
    return _teamMembers
        .where((m) =>
            m.name.toLowerCase().contains(query.toLowerCase()) ||
            m.role.toLowerCase().contains(query.toLowerCase()) ||
            m.department.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// 담당자별 워크로드 맵
  Map<String, int> getWorkloadMap() {
    final workload = <String, int>{};
    for (var member in _teamMembers) {
      workload[member.id] = getMemberTaskCount(member.id);
    }
    return workload;
  }

  /// 팀 전체 통계
  Map<String, dynamic> getTeamStats() {
    return {
      'totalMembers': totalMembers,
      'totalTasks': _tasks.length,
      'activeTasks': activeTasks,
      'completedTasks': completedTasks,
      'overallProgress': overallProgress,
      'urgentCount': getUrgentTasks().length,
      'overdueCount': getOverdueTasks().length,
    };
  }
}

// Real-time subscription 재사용을 위한 import
import 'dart:async';
