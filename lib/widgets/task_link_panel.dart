import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

/// 대시보드/캠페인/KPI/퍼널 등 어디서든 태스크 목록을 클릭 가능하게 보여주는 공통 패널
class TaskLinkPanel extends StatelessWidget {
  final String title;
  final List<TaskWithProject> tasks;
  final AppProvider provider;
  final Color accentColor;
  final bool compact; // true = 작은 사이즈 (사이드 패널용)

  const TaskLinkPanel({
    super.key,
    required this.title,
    required this.tasks,
    required this.provider,
    this.accentColor = AppTheme.mintPrimary,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E3040)),
        ),
        child: Row(children: [
          Icon(Icons.task_alt_outlined, color: AppTheme.textMuted, size: 16),
          const SizedBox(width: 8),
          Text('연결된 태스크 없음', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ]),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 10 : 12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              Icon(Icons.link, color: accentColor, size: 14),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: accentColor, fontSize: compact ? 11 : 12, fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${tasks.length}개',
                  style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
          // 태스크 목록
          ...tasks.asMap().entries.map((e) {
            final tp = e.value;
            final isLast = e.key == tasks.length - 1;
            return _TaskLinkRow(
              tp: tp,
              provider: provider,
              isLast: isLast,
              compact: compact,
            );
          }),
        ],
      ),
    );
  }
}

class _TaskLinkRow extends StatelessWidget {
  final TaskWithProject tp;
  final AppProvider provider;
  final bool isLast;
  final bool compact;

  const _TaskLinkRow({
    required this.tp,
    required this.provider,
    this.isLast = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final task = tp.task;
    final project = tp.project;

    final statusColor = _statusColor(task.status);
    final statusLabel = _statusLabel(task.status);
    final priorityColor = _priorityColor(task.priority);
    final progress = task.checklistProgress;
    final daysLeft = task.dueDate?.difference(DateTime.now()).inDays;
    final isOverdue = task.isOverdue;
    final fmt = DateFormat('MM/dd');

    return InkWell(
      onTap: () => provider.navigateToTask(task.id),
      borderRadius: BorderRadius.vertical(
        bottom: isLast ? const Radius.circular(12) : Radius.zero,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 8 : 12,
        ),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFF1E3040))),
        ),
        child: Row(children: [
          // 우선순위 도트
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          // 내용
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (!compact) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(
                      project.name,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                    ),
                    if (task.dueDate != null) ...[
                      const Text(' · ', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                      Text(
                        fmt.format(task.dueDate!),
                        style: TextStyle(
                          color: isOverdue ? AppTheme.error : AppTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ]),
                  if (task.checklist.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            backgroundColor: AppTheme.bgCardLight,
                            valueColor: AlwaysStoppedAnimation(statusColor),
                            minHeight: 3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${progress.toInt()}%',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
                      ),
                    ]),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 상태 배지 + D-day
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w600),
              ),
            ),
            if (daysLeft != null && !compact) ...[
              const SizedBox(height: 2),
              Text(
                isOverdue
                    ? 'D+${daysLeft.abs()}'
                    : daysLeft == 0
                        ? 'D-Day'
                        : 'D-$daysLeft',
                style: TextStyle(
                  color: isOverdue ? AppTheme.error : AppTheme.textMuted,
                  fontSize: 9,
                ),
              ),
            ],
          ]),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 14),
        ]),
      ),
    );
  }

  Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.todo: return AppTheme.textMuted;
      case TaskStatus.inProgress: return AppTheme.info;
      case TaskStatus.inReview: return AppTheme.warning;
      case TaskStatus.done: return AppTheme.success;
    }
  }

  String _statusLabel(TaskStatus s) {
    switch (s) {
      case TaskStatus.todo: return '대기';
      case TaskStatus.inProgress: return '진행';
      case TaskStatus.inReview: return '검토';
      case TaskStatus.done: return '완료';
    }
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.low: return AppTheme.textMuted;
      case TaskPriority.medium: return AppTheme.info;
      case TaskPriority.high: return AppTheme.warning;
      case TaskPriority.urgent: return AppTheme.error;
    }
  }
}
