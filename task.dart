// lib/models/task.dart

import 'package:uuid/uuid.dart';

enum TaskPriority { low, medium, high }
enum TaskStatus { pending, inProgress, completed }

class Task {
  final String id;
  final String title;
  final String description;
  final List<String> assigneeIds; // 담당자 ID 목록
  final DateTime dueDate;
  final TaskPriority priority;
  final TaskStatus status;
  final int progress; // 0-100
  final String createdBy;
  final String teamId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    String? id,
    required this.title,
    required this.description,
    required this.assigneeIds,
    required this.dueDate,
    required this.priority,
    required this.status,
    required this.progress,
    required this.createdBy,
    required this.teamId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Firestore JSON to Model
  factory Task.fromFirestore(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      assigneeIds: List<String>.from(json['assigneeIds'] as List? ?? []),
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : DateTime.now(),
      priority: _parsePriority(json['priority'] as String? ?? 'medium'),
      status: _parseStatus(json['status'] as String? ?? 'pending'),
      progress: json['progress'] as int? ?? 0,
      createdBy: json['createdBy'] as String? ?? '',
      teamId: json['teamId'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  /// Model to Firestore JSON
  Map<String, dynamic> toFirestore() => {
    'id': id,
    'title': title,
    'description': description,
    'assigneeIds': assigneeIds,
    'dueDate': dueDate.toIso8601String(),
    'priority': priority.name.toLowerCase(),
    'status': status.name.toLowerCase(),
    'progress': progress,
    'createdBy': createdBy,
    'teamId': teamId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// 데이터 복사 및 수정
  Task copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? assigneeIds,
    DateTime? dueDate,
    TaskPriority? priority,
    TaskStatus? status,
    int? progress,
    String? createdBy,
    String? teamId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      assigneeIds: assigneeIds ?? this.assigneeIds,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdBy: createdBy ?? this.createdBy,
      teamId: teamId ?? this.teamId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// 상태 텍스트 (한글)
  String getStatusText() {
    switch (status) {
      case TaskStatus.pending:
        return '대기';
      case TaskStatus.inProgress:
        return '진행 중';
      case TaskStatus.completed:
        return '완료';
    }
  }

  /// 우선순위 텍스트 (한글)
  String getPriorityText() {
    switch (priority) {
      case TaskPriority.low:
        return '낮음';
      case TaskPriority.medium:
        return '중간';
      case TaskPriority.high:
        return '높음';
    }
  }

  /// 마감일까지 남은 일수
  int getDaysUntilDue() {
    final now = DateTime.now();
    return dueDate.difference(now).inDays;
  }

  /// 마감 임박 여부 (3일 이내)
  bool isUrgent() {
    return getDaysUntilDue() <= 3 && status != TaskStatus.completed;
  }

  /// 마감 지난 여부
  bool isOverdue() {
    return DateTime.now().isAfter(dueDate) && status != TaskStatus.completed;
  }

  @override
  String toString() =>
      'Task(id: $id, title: $title, assignees: ${assigneeIds.length}, '
      'status: ${status.name}, progress: $progress%)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title;

  @override
  int get hashCode => id.hashCode ^ title.hashCode;

  // Private static 파싱 함수
  static TaskPriority _parsePriority(String value) {
    try {
      return TaskPriority.values.byName(value.toLowerCase());
    } catch (_) {
      return TaskPriority.medium;
    }
  }

  static TaskStatus _parseStatus(String value) {
    try {
      return TaskStatus.values.byName(value.toLowerCase());
    } catch (_) {
      return TaskStatus.pending;
    }
  }
}
