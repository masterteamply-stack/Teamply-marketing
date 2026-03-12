/// lib/models/marketing_task.dart
/// 마케팅 대시보드 태스크 모델

enum TaskPriority { low, medium, high }
enum TaskStatus { pending, inProgress, completed }

class MarketingTask {
  final String id;
  final String title;           // 태스크 제목
  final String description;     // 상세 설명
  final List<String> assigneeIds;  // 담당자 ID 목록
  final DateTime dueDate;       // 마감일
  final TaskPriority priority;  // 우선순위
  final TaskStatus status;      // 상태
  final int progress;           // 진행률 (0-100)
  final DateTime createdAt;     // 생성 날짜
  final DateTime updatedAt;     // 마지막 수정 날짜

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
  });

  /// JSON으로 직렬화 (Firestore 저장용)
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'assigneeIds': assigneeIds,
    'dueDate': dueDate.toIso8601String(),
    'priority': priority.toString().split('.').last,
    'status': status.toString().split('.').last,
    'progress': progress,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// JSON에서 역직렬화
  factory MarketingTask.fromJson(Map<String, dynamic> json) {
    final priorityStr = json['priority'] as String?;
    final statusStr = json['status'] as String?;

    return MarketingTask(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      assigneeIds: List<String>.from(json['assigneeIds'] as List? ?? []),
      dueDate: DateTime.parse(json['dueDate'] as String),
      priority: _parsePriority(priorityStr),
      status: _parseStatus(statusStr),
      progress: json['progress'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// 데이터 업데이트용 copyWith 메서드
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
  }) => MarketingTask(
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
  );

  /// 우선순위 문자열 파싱
  static TaskPriority _parsePriority(String? str) {
    switch (str?.toLowerCase()) {
      case 'low':
        return TaskPriority.low;
      case 'high':
        return TaskPriority.high;
      case 'medium':
      default:
        return TaskPriority.medium;
    }
  }

  /// 상태 문자열 파싱
  static TaskStatus _parseStatus(String? str) {
    switch (str?.toLowerCase()) {
      case 'inprogress':
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      case 'pending':
      default:
        return TaskStatus.pending;
    }
  }

  /// 우선순위를 한글로 변환
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

  /// 상태를 한글로 변환
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

  /// 마감일까지 남은 일수 (음수면 지난 것)
  int get daysUntilDue {
    final today = DateTime.now();
    return dueDate.difference(today).inDays;
  }

  /// 마감이 지났는지 확인
  bool get isOverdue {
    return status != TaskStatus.completed && daysUntilDue < 0;
  }

  /// 곧 마감되는지 확인 (3일 이내)
  bool get isUpcoming {
    return status != TaskStatus.completed && 
           daysUntilDue >= 0 && 
           daysUntilDue <= 3;
  }

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
