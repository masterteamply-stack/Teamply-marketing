/// lib/models/marketing_task.dart
/// 마케팅 대시보드 태스크 모델

enum TaskPriority { low, medium, high }
enum TaskStatus { pending, inProgress, completed }

class MarketingTask {
  final String id;
  final String title;
  final String description;
  final List<String> assigneeIds;
  final DateTime dueDate;
  final TaskPriority priority;
  final TaskStatus status;
  final int progress; // 0–100
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? teamId; // 팀 연결

  MarketingTask({
    required this.id,
    required this.title,
    required this.description,
    required this.assigneeIds,
    required this.dueDate,
    required this.priority,
    required this.status,
    this.progress = 0,
    required this.createdAt,
    required this.updatedAt,
    this.teamId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'assigneeIds': assigneeIds,
    'dueDate': dueDate.toIso8601String(),
    'priority': priority.name,
    'status': status.name,
    'progress': progress,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'teamId': teamId,
  };

  factory MarketingTask.fromJson(Map<String, dynamic> json) => MarketingTask(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    assigneeIds: List<String>.from(json['assigneeIds'] as List? ?? []),
    dueDate: DateTime.parse(json['dueDate'] as String),
    priority: _parsePriority(json['priority'] as String?),
    status: _parseStatus(json['status'] as String?),
    progress: json['progress'] as int? ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    teamId: json['teamId'] as String?,
  );

  MarketingTask copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? assigneeIds,
    DateTime? dueDate,
    TaskPriority? priority,
    TaskStatus? status,
    int? progress,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? teamId,
  }) =>
      MarketingTask(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        assigneeIds: assigneeIds ?? this.assigneeIds,
        dueDate: dueDate ?? this.dueDate,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        teamId: teamId ?? this.teamId,
      );

  static TaskPriority _parsePriority(String? str) {
    switch (str?.toLowerCase()) {
      case 'low':
        return TaskPriority.low;
      case 'high':
        return TaskPriority.high;
      default:
        return TaskPriority.medium;
    }
  }

  static TaskStatus _parseStatus(String? str) {
    switch (str?.toLowerCase()) {
      case 'inprogress':
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      default:
        return TaskStatus.pending;
    }
  }

  String get priorityLabel {
    switch (priority) {
      case TaskPriority.high:
        return '높음';
      case TaskPriority.medium:
        return '중간';
      case TaskPriority.low:
        return '낮음';
    }
  }

  String get statusLabel {
    switch (status) {
      case TaskStatus.pending:
        return '대기';
      case TaskStatus.inProgress:
        return '진행 중';
      case TaskStatus.completed:
        return '완료';
    }
  }

  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;

  bool get isOverdue =>
      status != TaskStatus.completed && daysUntilDue < 0;

  bool get isUpcoming =>
      status != TaskStatus.completed &&
      daysUntilDue >= 0 &&
      daysUntilDue <= 3;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarketingTask &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MarketingTask(id: $id, title: $title, status: $statusLabel, progress: $progress%)';
}
