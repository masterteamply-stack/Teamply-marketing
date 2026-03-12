import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/team_member.dart';
import '../models/marketing_task.dart';

// ─────────────────────────────────────────────────────────────
//  MarketingDashboardProvider
//  담당자 관리 및 태스크 관리의 중앙 상태 관리
// ─────────────────────────────────────────────────────────────
class MarketingDashboardProvider extends ChangeNotifier {
  // 상태
  List<TeamMember> _teamMembers = [];
  List<MarketingTask> _tasks = [];
  String? _currentTeamId;
  bool _isLoading = false;
  String? _errorMessage;

  // ─────────────────────────────────────────────────────────────
  //  Getters
  // ─────────────────────────────────────────────────────────────
  List<TeamMember> get teamMembers => _teamMembers;
  List<MarketingTask> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 담당자별 할당된 태스크 수
  Map<String, int> get taskCountByMember {
    final result = <String, int>{};
    for (var member in _teamMembers) {
      result[member.id] = 0;
    }
    for (var task in _tasks) {
      for (var assigneeId in task.assigneeIds) {
        result[assigneeId] = (result[assigneeId] ?? 0) + 1;
      }
    }
    return result;
  }

  /// 담당자별 평균 진행률
  Map<String, double> get progressByMember {
    final result = <String, double>{};
    
    for (var member in _teamMembers) {
      final memberTasks = _tasks
          .where((t) => t.assigneeIds.contains(member.id))
          .toList();
      
      if (memberTasks.isEmpty) {
        result[member.id] = 0.0;
      } else {
        final avgProgress = memberTasks
            .fold<double>(0, (sum, task) => sum + task.progress) 
            / memberTasks.length;
        result[member.id] = avgProgress;
      }
    }
    
    return result;
  }

  /// 진행 중인 태스크 (상태가 inProgress)
  List<MarketingTask> get inProgressTasks =>
      _tasks.where((t) => t.status == TaskStatus.inProgress).toList();

  /// 곧 마감되는 태스크 (3일 이내)
  List<MarketingTask> get upcomingTasks {
    final now = DateTime.now();
    final threeDaysLater = now.add(const Duration(days: 3));
    return _tasks
        .where((t) => 
            t.status != TaskStatus.completed &&
            t.dueDate.isAfter(now) &&
            t.dueDate.isBefore(threeDaysLater)
        )
        .toList();
  }

  /// 마감 지난 태스크 (상태가 진행 중 또는 대기)
  List<MarketingTask> get overdueTasks {
    final now = DateTime.now();
    return _tasks
        .where((t) =>
            (t.status == TaskStatus.inProgress || t.status == TaskStatus.pending) &&
            t.dueDate.isBefore(now)
        )
        .toList();
  }

  // ─────────────────────────────────────────────────────────────
  //  담당자 관리 (CRUD)
  // ─────────────────────────────────────────────────────────────

  /// 담당자 추가
  /// 
  /// 성공 시 true 반환, 실패 시 false 반환
  Future<bool> addTeamMember({
    required String name,
    required String role,
    required String department,
    String? avatarUrl,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // 중복 확인
      if (_teamMembers.any((m) => m.name == name)) {
        _errorMessage = '이미 존재하는 담당자입니다.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final newMember = TeamMember(
        id: const Uuid().v4(),
        name: name,
        role: role,
        department: department,
        avatarUrl: avatarUrl,
        createdAt: DateTime.now(),
        isActive: true,
      );

      _teamMembers.add(newMember);
      _isLoading = false;
      notifyListeners();

      // TODO: Firestore에 저장
      // await _firestore
      //     .collection('teams')
      //     .doc(_currentTeamId)
      //     .collection('members')
      //     .doc(newMember.id)
      //     .set(newMember.toJson());

      return true;
    } catch (e) {
      _errorMessage = '담당자 추가 실패: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 담당자 정보 수정
  Future<bool> updateTeamMember({
    required String memberId,
    String? name,
    String? role,
    String? department,
    String? avatarUrl,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final index = _teamMembers.indexWhere((m) => m.id == memberId);
      if (index < 0) {
        _errorMessage = '담당자를 찾을 수 없습니다.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final updated = _teamMembers[index].copyWith(
        name: name,
        role: role,
        department: department,
        avatarUrl: avatarUrl,
      );

      _teamMembers[index] = updated;
      _isLoading = false;
      notifyListeners();

      // TODO: Firestore에 저장
      return true;
    } catch (e) {
      _errorMessage = '담당자 수정 실패: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 담당자 삭제
  /// 
  /// 이 담당자가 지정된 모든 태스크에서도 자동 제거
  Future<bool> removeTeamMember(String memberId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // 담당자 삭제
      _teamMembers.removeWhere((m) => m.id == memberId);

      // 해당 담당자가 지정된 모든 태스크에서 제거
      for (var i = 0; i < _tasks.length; i++) {
        if (_tasks[i].assigneeIds.contains(memberId)) {
          _tasks[i] = _tasks[i].copyWith(
            assigneeIds: _tasks[i].assigneeIds
              ..removeWhere((id) => id == memberId),
          );
        }
      }

      _isLoading = false;
      notifyListeners();

      // TODO: Firestore에서 삭제
      return true;
    } catch (e) {
      _errorMessage = '담당자 삭제 실패: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// ID로 담당자 정보 조회
  TeamMember? getTeamMemberById(String id) {
    try {
      return _teamMembers.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  태스크 관리 (CRUD)
  // ─────────────────────────────────────────────────────────────

  /// 태스크 생성
  Future<bool> addTask({
    required String title,
    required String description,
    required List<String> assigneeIds,
    required DateTime dueDate,
    required TaskPriority priority,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final newTask = MarketingTask(
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
      );

      _tasks.add(newTask);
      _isLoading = false;
      notifyListeners();

      // TODO: Firestore에 저장
      return true;
    } catch (e) {
      _errorMessage = '태스크 생성 실패: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 태스크 정보 수정
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
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index < 0) {
        _errorMessage = '태스크를 찾을 수 없습니다.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _tasks[index] = _tasks[index].copyWith(
        title: title,
        description: description,
        assigneeIds: assigneeIds,
        dueDate: dueDate,
        priority: priority,
        status: status,
        progress: progress,
        updatedAt: DateTime.now(),
      );

      _isLoading = false;
      notifyListeners();

      // TODO: Firestore에 저장
      return true;
    } catch (e) {
      _errorMessage = '태스크 수정 실패: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 태스크 삭제
  Future<bool> removeTask(String taskId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _tasks.removeWhere((t) => t.id == taskId);
      _isLoading = false;
      notifyListeners();

      // TODO: Firestore에서 삭제
      return true;
    } catch (e) {
      _errorMessage = '태스크 삭제 실패: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 태스크 상태 변경
  Future<bool> updateTaskStatus(String taskId, TaskStatus newStatus) async {
    return updateTask(taskId: taskId, status: newStatus);
  }

  /// 태스크 진행률 업데이트
  Future<bool> updateTaskProgress(String taskId, int progress) async {
    if (progress < 0 || progress > 100) {
      _errorMessage = '진행률은 0-100 사이의 값이어야 합니다.';
      notifyListeners();
      return false;
    }
    return updateTask(taskId: taskId, progress: progress);
  }

  /// 태스크에 담당자 추가
  Future<bool> addAssigneeToTask(String taskId, String memberId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index < 0) {
        _errorMessage = '태스크를 찾을 수 없습니다.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (_tasks[index].assigneeIds.contains(memberId)) {
        _errorMessage = '이미 지정된 담당자입니다.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _tasks[index] = _tasks[index].copyWith(
        assigneeIds: [..._tasks[index].assigneeIds, memberId],
        updatedAt: DateTime.now(),
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '담당자 추가 실패: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 태스크에서 담당자 제거
  Future<bool> removeAssigneeFromTask(String taskId, String memberId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index < 0) {
        _errorMessage = '태스크를 찾을 수 없습니다.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _tasks[index] = _tasks[index].copyWith(
        assigneeIds: _tasks[index].assigneeIds
          ..removeWhere((id) => id == memberId),
        updatedAt: DateTime.now(),
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '담당자 제거 실패: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  데이터 로드 및 초기화
  // ─────────────────────────────────────────────────────────────

  /// 팀 데이터 로드 (Firebase Firestore에서)
  Future<bool> loadTeamData(String teamId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      _currentTeamId = teamId;
      notifyListeners();

      // TODO: Firestore에서 데이터 로드
      // 예시 코드:
      // final membersSnap = await _firestore
      //     .collection('teams')
      //     .doc(teamId)
      //     .collection('members')
      //     .get();
      // _teamMembers = membersSnap.docs
      //     .map((doc) => TeamMember.fromJson(doc.data()))
      //     .toList();
      //
      // final tasksSnap = await _firestore
      //     .collection('teams')
      //     .doc(teamId)
      //     .collection('tasks')
      //     .get();
      // _tasks = tasksSnap.docs
      //     .map((doc) => MarketingTask.fromJson(doc.data()))
      //     .toList();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '데이터 로드 실패: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 모든 데이터 초기화 (로그아웃 시)
  void clearAll() {
    _teamMembers.clear();
    _tasks.clear();
    _currentTeamId = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
