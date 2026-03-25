import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../widgets/csv_task_upload_dialog.dart';
import '../../widgets/edit_dialog.dart';

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({super.key});

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _filterMember = 'all';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final project = provider.selectedProject;
    if (project == null) return const Center(child: Text('프로젝트를 선택해주세요', style: TextStyle(color: AppTheme.textMuted)));

    final projColor = Color(int.parse('0xFF${project.colorHex.substring(1)}'));
    final doneTasks = project.tasks.where((t) => t.status == TaskStatus.done).length;
    final fmt = NumberFormat('#,###');

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Column(
        children: [
          // Project Header
          Container(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
            color: AppTheme.bgCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  // Breadcrumb
                  TextButton(
                    onPressed: () => provider.selectTeam(project.teamId),
                    child: const Text('← 팀으로 돌아가기', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: projColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: Text(project.iconEmoji, style: const TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(project.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: projColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text(project.category, style: TextStyle(color: projColor, fontSize: 11)),
                      ),
                    ]),
                    Text(project.description, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(children: [
                      _InfoChip(icon: Icons.task_alt_outlined, label: '태스크 ${project.tasks.length}개 ($doneTasks 완료)'),
                      const SizedBox(width: 8),
                      _InfoChip(icon: Icons.people_outline, label: '멤버 ${project.memberIds.length}명'),
                      const SizedBox(width: 8),
                      if (project.budget != null)
                        _InfoChip(icon: Icons.account_balance_wallet_outlined,
                            label: '예산 ${project.budget!.currency.symbol}${fmt.format(project.budget!.totalBudget)}'),
                      const SizedBox(width: 8),
                      _InfoChip(icon: Icons.trending_up, label: '진행률 ${project.completionRate.toStringAsFixed(0)}%'),
                      const SizedBox(width: 8),
                      // 캠페인 연결 배지
                      _CampaignLinkBadge(project: project, provider: provider),
                    ]),
                  ])),
                  // Actions
                  // 프로젝트 편집 버튼
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: AppTheme.textMuted, size: 18),
                    tooltip: '프로젝트 편집',
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => ProjectEditDialog(project: project, provider: provider),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // CSV 벌크 업로드 버튼
                  OutlinedButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => CsvTaskUploadDialog(
                        projectId: project.id,
                        provider: provider,
                      ),
                    ),
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('CSV 업로드'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentBlue,
                      side: const BorderSide(color: AppTheme.accentBlue),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddTaskDialog(context, provider, project),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('태스크 추가'),
                    style: ElevatedButton.styleFrom(backgroundColor: projColor, foregroundColor: Colors.white),
                  ),
                ]),
                const SizedBox(height: 16),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: project.completionRate / 100,
                    backgroundColor: AppTheme.bgCardLight,
                    valueColor: AlwaysStoppedAnimation<Color>(projColor),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 12),
                TabBar(
                  controller: _tab,
                  labelColor: projColor,
                  unselectedLabelColor: AppTheme.textMuted,
                  indicatorColor: projColor,
                  tabs: const [
                    Tab(text: '태스크 보드'),
                    Tab(text: '멤버별 태스크'),
                    Tab(text: '예산 & 비용'),
                    Tab(text: '전략 연결'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _TaskBoardTab(provider: provider, project: project),
                _MemberTasksTab(provider: provider, project: project),
                _BudgetTab(provider: provider, project: project),
                _StrategyLinkTab(provider: provider, project: project),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, AppProvider provider, Project project) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    TaskPriority priority = TaskPriority.medium;
    List<String> selectedAssignees = [];
    DateTime? dueDate;

    // Get team members
    final team = provider.teams.firstWhere((t) => t.id == project.teamId, orElse: () => provider.teams.first);
    final members = team.members.map((m) => m.user).toList();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('태스크 추가', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(labelText: '태스크 이름 *', hintText: '예: SNS 배너 디자인'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: '설명'),
                  ),
                  const SizedBox(height: 12),
                  const Text('우선순위', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: TaskPriority.values.map((p) {
                      final c = _priorityColor(p);
                      return ChoiceChip(
                        label: Text(_priorityLabel(p), style: TextStyle(color: priority == p ? Colors.white : c, fontSize: 12)),
                        selected: priority == p,
                        selectedColor: c,
                        backgroundColor: c.withValues(alpha: 0.15),
                        onSelected: (_) => setState(() => priority = p),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('담당자', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: members.map((u) {
                      final isSelected = selectedAssignees.contains(u.id);
                      final col = u.avatarColor != null ? Color(int.parse('0xFF${u.avatarColor!.substring(1)}')) : AppTheme.mintPrimary;
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (isSelected) selectedAssignees.remove(u.id);
                          else selectedAssignees.add(u.id);
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? col.withValues(alpha: 0.25) : AppTheme.bgCardLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? col : Colors.transparent),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            CircleAvatar(radius: 10, backgroundColor: col.withValues(alpha: 0.3), child: Text(u.avatarInitials, style: TextStyle(color: col, fontSize: 8))),
                            const SizedBox(width: 6),
                            Text(u.name, style: TextStyle(color: isSelected ? col : AppTheme.textSecondary, fontSize: 12)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Text('마감일', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2026),
                          builder: (_, child) => Theme(data: ThemeData.dark(), child: child!),
                        );
                        if (picked != null) setState(() => dueDate = picked);
                      },
                      icon: const Icon(Icons.calendar_today, size: 14),
                      label: Text(dueDate != null ? DateFormat('yyyy.MM.dd').format(dueDate!) : '날짜 선택',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty) {
                  provider.createTask(
                    projectId: project.id,
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    priority: priority,
                    assigneeIds: selectedAssignees.isEmpty ? [provider.currentUser.id] : selectedAssignees,
                    dueDate: dueDate,
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('태스크 추가'),
            ),
          ],
        ),
      ),
    );
  }

  static Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.urgent: return AppTheme.error;
      case TaskPriority.high: return AppTheme.warning;
      case TaskPriority.medium: return AppTheme.info;
      case TaskPriority.low: return AppTheme.textMuted;
    }
  }

  static String _priorityLabel(TaskPriority p) {
    switch (p) {
      case TaskPriority.urgent: return '긴급';
      case TaskPriority.high: return '높음';
      case TaskPriority.medium: return '보통';
      case TaskPriority.low: return '낮음';
    }
  }
}

// ── Task Board Tab ──────────────────────────────────────
class _TaskBoardTab extends StatefulWidget {
  final AppProvider provider;
  final Project project;
  const _TaskBoardTab({required this.provider, required this.project});

  @override
  State<_TaskBoardTab> createState() => _TaskBoardTabState();
}

class _TaskBoardTabState extends State<_TaskBoardTab> {
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;

  void _toggleSelection(String taskId) {
    setState(() {
      if (_selectedIds.contains(taskId)) {
        _selectedIds.remove(taskId);
      } else {
        _selectedIds.add(taskId);
      }
      _selectionMode = _selectedIds.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() { _selectedIds.clear(); _selectionMode = false; });
  }

  Future<void> _deleteBulk() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('태스크 일괄 삭제', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
        content: Text('선택한 ${_selectedIds.length}개 태스크를 삭제하시겠습니까?',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('취소', style: TextStyle(color: AppTheme.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('${_selectedIds.length}개 삭제', style: const TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (confirmed == true) {
      widget.provider.deleteTasksBulk(widget.project.id, _selectedIds.toList());
      _clearSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = [TaskStatus.todo, TaskStatus.inProgress, TaskStatus.inReview, TaskStatus.done];
    final labels = ['할 일', '진행 중', '검토 중', '완료'];
    final colors = [AppTheme.textMuted, AppTheme.info, AppTheme.warning, AppTheme.success];

    return Column(
      children: [
        // ── 일괄 선택 모드 액션바 ──────────────────────────
        if (_selectionMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: AppTheme.bgCard,
            child: Row(children: [
              Text('${_selectedIds.length}개 선택됨',
                  style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 15, color: AppTheme.error),
                label: const Text('삭제', style: TextStyle(color: AppTheme.error, fontSize: 12)),
                onPressed: _deleteBulk,
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _clearSelection,
                child: const Text('취소', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ),
            ]),
          ),
        // ── 안내 텍스트 ────────────────────────────────────
        if (!_selectionMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppTheme.textMuted, size: 12),
              const SizedBox(width: 4),
              const Text('카드 길게 누르기: 선택 모드',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ]),
          ),
        // ── 칸반 보드 ──────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: statuses.asMap().entries.map((e) {
                final tasks = widget.project.tasks.where((t) => t.status == e.value).toList();
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: colors[e.key].withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Row(children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[e.key], shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(labels[e.key], style: TextStyle(color: colors[e.key], fontSize: 12, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Text('${tasks.length}', style: TextStyle(color: colors[e.key], fontSize: 12)),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.separated(
                            itemCount: tasks.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) => _TaskCard(
                              task: tasks[i],
                              provider: widget.provider,
                              project: widget.project,
                              isSelected: _selectedIds.contains(tasks[i].id),
                              onLongPress: () => _toggleSelection(tasks[i].id),
                              onToggleSelect: _selectionMode ? () => _toggleSelection(tasks[i].id) : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskDetail task;
  final AppProvider provider;
  final Project project;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleSelect;
  const _TaskCard({
    required this.task,
    required this.provider,
    required this.project,
    this.isSelected = false,
    this.onLongPress,
    this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final prColor = task.priority == TaskPriority.urgent ? AppTheme.error
        : task.priority == TaskPriority.high ? AppTheme.warning
        : task.priority == TaskPriority.medium ? AppTheme.info : AppTheme.textMuted;
    final prLabel = task.priority == TaskPriority.urgent ? '긴급'
        : task.priority == TaskPriority.high ? '높음'
        : task.priority == TaskPriority.medium ? '보통' : '낮음';
    final checkDone = task.checklist.where((c) => c.isDone).length;
    final checkTotal = task.checklist.length;
    final daysLeft = task.dueDate != null ? task.dueDate!.difference(DateTime.now()).inDays : null;

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onToggleSelect ?? () => provider.selectTask(task.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.mintPrimary.withValues(alpha: 0.12) : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.mintPrimary.withValues(alpha: 0.6)
                : task.isOverdue ? AppTheme.error.withValues(alpha: 0.4)
                : const Color(0xFF1E3040),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // 선택 모드 체크박스
              if (onToggleSelect != null) ...[
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: isSelected ? AppTheme.mintPrimary : AppTheme.textMuted,
                  size: 16,
                ),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: prColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: Text(prLabel, style: TextStyle(color: prColor, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              if (task.isOverdue) const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 14),
            ]),
            const SizedBox(height: 6),
            Text(task.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 2),
            // ── 외부 ID / 테마 배지 (CSV 가져오기) ────────
            if (task.externalId != null || task.theme != null) ...[
              const SizedBox(height: 4),
              Wrap(spacing: 4, runSpacing: 2, children: [
                if (task.externalId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(task.externalId!,
                        style: const TextStyle(color: AppTheme.accentBlue, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                if (task.theme != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.accentPurple.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(task.theme!,
                        style: const TextStyle(color: AppTheme.accentPurple, fontSize: 9),
                        overflow: TextOverflow.ellipsis),
                  ),
                if (task.target != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '목표 ${task.target!.toStringAsFixed(task.target!.truncateToDouble() == task.target! ? 0 : 1)}'
                      '${task.unit != null ? ' ${task.unit}' : ''}',
                      style: const TextStyle(color: AppTheme.accentGreen, fontSize: 9),
                    ),
                  ),
              ]),
            ],
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(task.description, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            if (checkTotal > 0) ...[
              Row(children: [
                const Icon(Icons.checklist, color: AppTheme.textMuted, size: 12),
                const SizedBox(width: 4),
                Text('$checkDone/$checkTotal', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                const SizedBox(width: 8),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: checkTotal > 0 ? checkDone / checkTotal : 0,
                    backgroundColor: AppTheme.bgCardLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.mintPrimary),
                    minHeight: 3,
                  ),
                )),
              ]),
              const SizedBox(height: 6),
            ],
            Row(children: [
              // Assignee avatars
              ...task.assigneeIds.take(3).map((uid) {
                final u = provider.getUserById(uid);
                if (u == null) return const SizedBox();
                final col = u.avatarColor != null ? Color(int.parse('0xFF${u.avatarColor!.substring(1)}')) : AppTheme.mintPrimary;
                return Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: CircleAvatar(radius: 10, backgroundColor: col.withValues(alpha: 0.3), child: Text(u.avatarInitials, style: TextStyle(color: col, fontSize: 8))),
                );
              }),
              const Spacer(),
              // 인라인 편집 버튼
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => TaskEditDialog(task: task, project: project, provider: provider),
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.mintPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.edit_rounded, color: AppTheme.mintPrimary, size: 12),
                ),
              ),
              const SizedBox(width: 4),
              // 삭제 버튼
              GestureDetector(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppTheme.bgCard,
                      title: const Text('태스크 삭제', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
                      content: Text('"${task.title}" 태스크를 삭제하시겠습니까?',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false),
                            child: const Text('취소', style: TextStyle(color: AppTheme.textMuted))),
                        TextButton(onPressed: () => Navigator.pop(context, true),
                            child: const Text('삭제', style: TextStyle(color: AppTheme.error))),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    provider.deleteTask(project.id, task.id);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 12),
                ),
              ),
              const SizedBox(width: 6),
              if (daysLeft != null)
                Text(
                  daysLeft < 0 ? 'D+${daysLeft.abs()}' : daysLeft == 0 ? 'D-Day' : 'D-$daysLeft',
                  style: TextStyle(color: daysLeft < 0 ? AppTheme.error : daysLeft <= 3 ? AppTheme.warning : AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w500),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Member Tasks Tab ────────────────────────────────────
class _MemberTasksTab extends StatelessWidget {
  final AppProvider provider;
  final Project project;
  const _MemberTasksTab({required this.provider, required this.project});

  @override
  Widget build(BuildContext context) {
    final memberIds = project.memberIds.toSet();
    final allMembers = provider.allUsers.where((u) => memberIds.contains(u.id)).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: allMembers.map((u) {
          final myTasks = project.tasks.where((t) => t.assigneeIds.contains(u.id)).toList();
          final col = u.avatarColor != null ? Color(int.parse('0xFF${u.avatarColor!.substring(1)}')) : AppTheme.mintPrimary;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Member header
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(children: [
                      CircleAvatar(radius: 16, backgroundColor: col.withValues(alpha: 0.3), child: Text(u.avatarInitials, style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(u.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('태스크 ${myTasks.length}개', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      ]),
                    ]),
                  ),
                  // Tasks
                  Expanded(
                    child: myTasks.isEmpty
                        ? const Center(child: Text('태스크 없음', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)))
                        : ListView.separated(
                            padding: const EdgeInsets.all(10),
                            itemCount: myTasks.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) => _TaskCard(task: myTasks[i], provider: provider, project: project),
                          ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Budget Tab ──────────────────────────────────────────
class _BudgetTab extends StatelessWidget {
  final AppProvider provider;
  final Project project;
  const _BudgetTab({required this.provider, required this.project});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final budget = project.budget;
    final executed = project.executedCostKrw;
    final total = project.totalBudgetKrw;
    final usage = project.budgetUsageRate;
    final usageColor = usage >= 90 ? AppTheme.error : usage >= 70 ? AppTheme.warning : AppTheme.success;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Budget summary cards
          Row(children: [
            _BudgetCard(
              title: '총 예산',
              value: budget != null ? '${budget.currency.symbol}${fmt.format(budget.totalBudget)}' : '미설정',
              subtitle: '₩${fmt.format(total)}',
              color: AppTheme.mintPrimary,
              icon: Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(width: 16),
            _BudgetCard(
              title: '집행 금액',
              value: '₩${fmt.format(executed)}',
              subtitle: '${usage.toStringAsFixed(1)}% 사용',
              color: usageColor,
              icon: Icons.payment_outlined,
            ),
            const SizedBox(width: 16),
            _BudgetCard(
              title: '잔여 예산',
              value: '₩${fmt.format(total - executed)}',
              subtitle: total > 0 ? '${(100 - usage).clamp(0, 100).toStringAsFixed(1)}% 남음' : '-',
              color: AppTheme.info,
              icon: Icons.savings_outlined,
            ),
          ]),
          const SizedBox(height: 20),
          // Budget usage bar
          if (budget != null) ...[
            const Text('예산 사용률', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (usage / 100).clamp(0, 1),
                backgroundColor: AppTheme.bgCardLight,
                valueColor: AlwaysStoppedAnimation<Color>(usageColor),
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Text('₩${fmt.format(executed)} 집행', style: TextStyle(color: usageColor, fontSize: 12)),
              const Spacer(),
              Text('₩${fmt.format(total)} 총 예산', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ]),
            const SizedBox(height: 20),
          ],
          // Project cost entries
          const Text('프로젝트 비용 내역', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...project.projectCosts.map((cost) => _CostRow(cost: cost)),
          // Task budgets
          if (project.tasks.any((t) => t.budget != null)) ...[
            const SizedBox(height: 20),
            const Text('태스크별 예산', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...project.tasks.where((t) => t.budget != null).map((t) {
              final c = Color(int.parse('0xFF${project.colorHex.substring(1)}'));
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text('예산 ${t.budget!.currency.symbol}${fmt.format(t.budget!.totalBudget)}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    const SizedBox(width: 16),
                    Text('집행 ₩${fmt.format(t.executedAmountKrw)}', style: TextStyle(color: c, fontSize: 12)),
                    const SizedBox(width: 16),
                    Text('${t.costExecutionRate.toStringAsFixed(0)}%', style: TextStyle(color: t.costExecutionRate >= 90 ? AppTheme.error : AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (t.costExecutionRate / 100).clamp(0, 1),
                      backgroundColor: AppTheme.bgCardLight,
                      valueColor: AlwaysStoppedAnimation<Color>(t.costExecutionRate >= 90 ? AppTheme.error : c),
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => provider.selectTask(t.id),
                    child: const Text('상세 보기 →', style: TextStyle(color: AppTheme.mintPrimary, fontSize: 12)),
                  ),
                ]),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final String title, value, subtitle;
  final Color color;
  final IconData icon;
  const _BudgetCard({required this.title, required this.value, required this.subtitle, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            Text(subtitle, style: TextStyle(color: color, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  final CostEntry cost;
  const _CostRow({required this.cost});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: cost.isExecuted ? AppTheme.success : AppTheme.textMuted, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(cost.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
        Text(DateFormat('MM.dd').format(cost.date), style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        const SizedBox(width: 16),
        Text('${cost.currency.symbol}${NumberFormat('#,###').format(cost.amount)}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: cost.isExecuted ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.textMuted.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(cost.isExecuted ? '집행완료' : '예정', style: TextStyle(color: cost.isExecuted ? AppTheme.success : AppTheme.textMuted, fontSize: 10)),
        ),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: AppTheme.textMuted, size: 13),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ]),
    );
  }
}

// ─── 캠페인 연결 배지 (프로젝트 헤더용) ────────────────────────
class _CampaignLinkBadge extends StatelessWidget {
  final Project project;
  final AppProvider provider;
  const _CampaignLinkBadge({required this.project, required this.provider});

  @override
  Widget build(BuildContext context) {
    final linkedCampaign = project.campaignId != null
        ? provider.campaigns.where((c) => c.id == project.campaignId).firstOrNull
        : null;

    if (linkedCampaign != null) {
      // 연결된 캠페인 표시 + 클릭 시 캠페인 이동 또는 해제 메뉴
      return GestureDetector(
        onTap: () => _showCampaignMenu(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF29B6F6).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF29B6F6).withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.campaign, color: Color(0xFF29B6F6), size: 12),
            const SizedBox(width: 4),
            Text(linkedCampaign.name,
                style: const TextStyle(color: Color(0xFF29B6F6), fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, color: Color(0xFF29B6F6), size: 12),
          ]),
        ),
      );
    }

    // 미연결 상태 – 연결 버튼
    return GestureDetector(
      onTap: () => _showLinkCampaignDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.bgCardLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1E3040)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_link, color: AppTheme.textMuted, size: 12),
          SizedBox(width: 4),
          Text('캠페인 연결', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ]),
      ),
    );
  }

  void _showCampaignMenu(BuildContext context) {
    final linkedCampaign = provider.campaigns.where((c) => c.id == project.campaignId).firstOrNull;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('캠페인 연결 관리', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (linkedCampaign != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF29B6F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF29B6F6).withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.campaign, color: Color(0xFF29B6F6), size: 16),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(linkedCampaign.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('${linkedCampaign.type} · ${linkedCampaign.channel} · ${linkedCampaign.status}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                ])),
              ]),
            ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  provider.navigateTo('campaign');
                },
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('캠페인으로 이동'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF29B6F6),
                  side: const BorderSide(color: Color(0xFF29B6F6)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  provider.updateProjectCampaign(project.id, null);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.link_off, size: 14),
                label: const Text('연결 해제'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: const BorderSide(color: AppTheme.error),
                ),
              ),
            ),
          ]),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기', style: TextStyle(color: AppTheme.textMuted)),
          ),
        ],
      ),
    );
  }

  void _showLinkCampaignDialog(BuildContext context) {
    final teamCampaigns = provider.teamCampaigns;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          const Icon(Icons.add_link, color: AppTheme.mintPrimary, size: 20),
          const SizedBox(width: 8),
          const Text('캠페인 연결', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        content: SizedBox(
          width: 400,
          child: teamCampaigns.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('캠페인이 없습니다.', style: TextStyle(color: AppTheme.textMuted)),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView(children: teamCampaigns.map((c) {
                    final statusColor = c.status == 'active' ? AppTheme.success
                        : c.status == 'completed' ? AppTheme.info : AppTheme.warning;
                    return InkWell(
                      onTap: () {
                        provider.updateProjectCampaign(project.id, c.id);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCardLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1E3040)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.campaign_outlined, color: Color(0xFF29B6F6), size: 16),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                            Text('${c.type} · ${c.channel}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              c.status == 'active' ? '진행 중' : c.status == 'completed' ? '완료' : '예정',
                              style: TextStyle(color: statusColor, fontSize: 9),
                            ),
                          ),
                        ]),
                      ),
                    );
                  }).toList()),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: AppTheme.textMuted)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 전략 연결 탭 - 캠페인/KPI/퍼널/고객사 유기적 연결
// ══════════════════════════════════════════════════════════
class _StrategyLinkTab extends StatefulWidget {
  final AppProvider provider;
  final Project project;

  const _StrategyLinkTab({required this.provider, required this.project});

  @override
  State<_StrategyLinkTab> createState() => _StrategyLinkTabState();
}

class _StrategyLinkTabState extends State<_StrategyLinkTab> {
  bool _showCampaignPicker = false;
  bool _showKpiPicker = false;

  AppProvider get p => widget.provider;
  Project get proj => widget.project;

  @override
  Widget build(BuildContext context) {
    final campaign = proj.campaignId != null
        ? p.campaigns.where((c) => c.id == proj.campaignId).firstOrNull
        : null;
    final linkedKpis = p.kpis.where((k) => k.projectId == proj.id).toList();
    final allTasks = proj.tasks;
    final tasksByAssignee = <String, List<TaskDetail>>{};
    for (final t in allTasks) {
      for (final uid in t.assigneeIds) {
        tasksByAssignee.putIfAbsent(uid, () => []).add(t);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ─── 1. 캠페인 연결 ─────────────────────────────
        _SectionCard(
          icon: Icons.campaign_outlined,
          color: AppTheme.mintPrimary,
          title: '캠페인 연결',
          subtitle: '이 프로젝트 태스크보드를 캠페인의 분석 대상으로 인식시킵니다',
          child: campaign != null
              ? _CampaignLink(
                  campaign: campaign,
                  onUnlink: () {
                    p.updateProjectCampaign(proj.id, null);
                  },
                  onNavigate: () {
                    p.selectCampaign(campaign.id);
                    // 캠페인 탭으로 이동
                    final shell = context.findAncestorStateOfType<State>();
                    if (shell != null) {
                      // 내비게이션 인덱스를 캠페인으로 변경 (index 2)
                      try {
                        (shell as dynamic).setIndex(2);
                      } catch (_) {}
                    }
                  },
                )
              : _CampaignPickerBtn(
                  show: _showCampaignPicker,
                  campaigns: p.campaigns,
                  onToggle: () => setState(() => _showCampaignPicker = !_showCampaignPicker),
                  onSelect: (c) {
                    p.updateProjectCampaign(proj.id, c.id);
                    setState(() => _showCampaignPicker = false);
                  },
                ),
        ),
        const SizedBox(height: 14),

        // ─── 2. KPI 연결 ────────────────────────────────
        _SectionCard(
          icon: Icons.track_changes_outlined,
          color: AppTheme.info,
          title: 'KPI 연결 (${linkedKpis.length}개)',
          subtitle: '이 프로젝트와 연결된 KPI를 추적합니다',
          action: TextButton.icon(
            onPressed: () => setState(() => _showKpiPicker = !_showKpiPicker),
            icon: Icon(_showKpiPicker ? Icons.close : Icons.add, size: 14),
            label: Text(_showKpiPicker ? '닫기' : 'KPI 연결', style: const TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: AppTheme.info),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (linkedKpis.isEmpty && !_showKpiPicker)
              const Text('연결된 KPI가 없습니다. KPI를 연결하면 진행률이 자동 반영됩니다.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12))
            else
              ...linkedKpis.map((k) => _KpiLinkRow(kpi: k, project: proj, provider: p)),

            if (_showKpiPicker) ...[
              const SizedBox(height: 10),
              const Divider(color: Color(0xFF1E3040), height: 1),
              const SizedBox(height: 10),
              const Text('연결할 KPI 선택', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...p.teamKpis.where((k) => k.projectId != proj.id).map((k) =>
                _KpiPickerRow(
                  kpi: k,
                  onLink: () {
                    p.linkKpiToProject(k.id, proj.id);
                    setState(() {});
                  },
                ),
              ),
              if (p.teamKpis.where((k) => k.projectId != proj.id).isEmpty)
                const Text('연결 가능한 KPI가 없습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ],
          ]),
        ),
        const SizedBox(height: 14),

        // ─── 3. 개인별 KPI 자동 분류 현황 ────────────────
        if (tasksByAssignee.isNotEmpty) _SectionCard(
          icon: Icons.person_search_outlined,
          color: AppTheme.warning,
          title: '담당자별 태스크 → KPI 자동 분류',
          subtitle: '태스크 완료 시 담당자의 개인 KPI에 자동 반영됩니다',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ...tasksByAssignee.entries.map((e) {
              final user = p.getUserById(e.key);
              final tasks = e.value;
              final done = tasks.where((t) => t.status == TaskStatus.done).length;
              final personalKpis = p.kpis.where((k) =>
                !k.isTeamKpi && k.assignedTo == e.key
              ).toList();
              return _AssigneeKpiRow(
                userName: user?.name ?? user?.email ?? e.key,
                userColor: _strColor(e.key),
                totalTasks: tasks.length,
                doneTasks: done,
                personalKpiCount: personalKpis.length,
                personalKpis: personalKpis,
              );
            }),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.15)),
              ),
              child: Row(children: [
                const Icon(Icons.lightbulb_outline, color: AppTheme.warning, size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'KPI 관리 탭에서 "개인별 KPI" 탭을 열면 각 담당자의 KPI를 확인할 수 있습니다',
                  style: const TextStyle(color: AppTheme.warning, fontSize: 11),
                )),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // ─── 4. 마케팅 퍼널 연결 현황 ─────────────────────
        _SectionCard(
          icon: Icons.filter_alt_outlined,
          color: AppTheme.accentPurple,
          title: '마케팅 퍼널 연결',
          subtitle: '이 프로젝트와 연결된 퍼널 단계를 확인합니다',
          child: _FunnelLinkStatus(provider: p, project: proj),
        ),
        const SizedBox(height: 14),

        // ─── 5. 연결된 고객사 ─────────────────────────────
        _SectionCard(
          icon: Icons.business_outlined,
          color: AppTheme.success,
          title: '연결 고객사',
          subtitle: '이 프로젝트 태스크에 지정된 고객사 목록입니다',
          child: _LinkedClientsStatus(provider: p, project: proj),
        ),
      ]),
    );
  }

  Color _strColor(String s) {
    final colors = [AppTheme.mintPrimary, AppTheme.info, AppTheme.warning, AppTheme.success, AppTheme.error, AppTheme.accentPurple];
    return colors[s.hashCode.abs() % colors.length];
  }
}

// ── 섹션 카드 ────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const _SectionCard({
    required this.icon, required this.color, required this.title,
    required this.subtitle, required this.child, this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 헤더
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.15))),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
              Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            ])),
            if (action != null) action!,
          ]),
        ),
        // 바디
        Padding(
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      ]),
    );
  }
}

// ── 캠페인 연결 위젯 ──────────────────────────────────────
class _CampaignLink extends StatelessWidget {
  final CampaignModel campaign;
  final VoidCallback onUnlink;
  final VoidCallback onNavigate;

  const _CampaignLink({required this.campaign, required this.onUnlink, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final statusColor = campaign.status == 'active' ? AppTheme.success
        : campaign.status == 'completed' ? AppTheme.info : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.campaign, color: AppTheme.mintPrimary, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(campaign.name,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          Text('${campaign.type} · ${campaign.channel}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                campaign.status == 'active' ? '진행 중' : campaign.status == 'completed' ? '완료' : '예정',
                style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 6),
            Text('ROI: ${campaign.roi.toStringAsFixed(0)}%',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ]),
        ])),
        Column(children: [
          GestureDetector(
            onTap: onNavigate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.mintPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.open_in_new, color: AppTheme.mintPrimary, size: 12),
                SizedBox(width: 4),
                Text('분석 보기', style: TextStyle(color: AppTheme.mintPrimary, fontSize: 11)),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onUnlink,
            child: const Text('연결 해제', style: TextStyle(color: AppTheme.error, fontSize: 10)),
          ),
        ]),
      ]),
    );
  }
}

class _CampaignPickerBtn extends StatelessWidget {
  final bool show;
  final List<CampaignModel> campaigns;
  final VoidCallback onToggle;
  final Function(CampaignModel) onSelect;

  const _CampaignPickerBtn({
    required this.show, required this.campaigns,
    required this.onToggle, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.bgCardLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_link, color: AppTheme.mintPrimary, size: 14),
            const SizedBox(width: 6),
            Text(show ? '취소' : '캠페인 연결하기',
                style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
      if (show) ...[
        const SizedBox(height: 8),
        if (campaigns.isEmpty)
          const Text('생성된 캠페인이 없습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))
        else
          ...campaigns.map((c) {
            final statusColor = c.status == 'active' ? AppTheme.success
                : c.status == 'completed' ? AppTheme.info : AppTheme.warning;
            return GestureDetector(
              onTap: () => onSelect(c),
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.bgCardLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF1E3040)),
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('${c.type} · ${c.channel}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      c.status == 'active' ? '진행 중' : c.status == 'completed' ? '완료' : '예정',
                      style: TextStyle(color: statusColor, fontSize: 9),
                    ),
                  ),
                ]),
              ),
            );
          }),
      ],
    ]);
  }
}

// ── KPI 연결 행 ──────────────────────────────────────────
class _KpiLinkRow extends StatelessWidget {
  final KpiModel kpi;
  final Project project;
  final AppProvider provider;

  const _KpiLinkRow({required this.kpi, required this.project, required this.provider});

  @override
  Widget build(BuildContext context) {
    final pct = kpi.target > 0 ? (kpi.current / kpi.target).clamp(0.0, 1.0) : 0.0;
    final pctColor = pct >= 1.0 ? AppTheme.success : pct >= 0.7 ? AppTheme.info : AppTheme.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(kpi.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppTheme.bgCard,
              valueColor: AlwaysStoppedAnimation(pctColor),
              minHeight: 5,
            )),
            const SizedBox(width: 8),
            Text('${(pct * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: pctColor, fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
          Text('${kpi.current.toStringAsFixed(0)} / ${kpi.target.toStringAsFixed(0)} ${kpi.unit}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ])),
        GestureDetector(
          onTap: () => provider.unlinkKpiFromProject(kpi.id, project.id),
          child: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.link_off, color: AppTheme.textMuted, size: 16),
          ),
        ),
      ]),
    );
  }
}

class _KpiPickerRow extends StatelessWidget {
  final KpiModel kpi;
  final VoidCallback onLink;

  const _KpiPickerRow({required this.kpi, required this.onLink});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onLink,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.bgCardLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF1E3040)),
        ),
        child: Row(children: [
          const Icon(Icons.add_circle_outline, color: AppTheme.info, size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text(kpi.title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
          Text('${kpi.current.toStringAsFixed(0)}/${kpi.target.toStringAsFixed(0)} ${kpi.unit}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ]),
      ),
    );
  }
}

// ── 담당자별 KPI 행 ──────────────────────────────────────
class _AssigneeKpiRow extends StatelessWidget {
  final String userName;
  final Color userColor;
  final int totalTasks;
  final int doneTasks;
  final int personalKpiCount;
  final List<KpiModel> personalKpis;

  const _AssigneeKpiRow({
    required this.userName, required this.userColor, required this.totalTasks,
    required this.doneTasks, required this.personalKpiCount, required this.personalKpis,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalTasks > 0 ? doneTasks / totalTasks : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: userColor.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: userColor.withValues(alpha: 0.2),
            child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                style: TextStyle(color: userColor, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Text(userName, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('태스크 $doneTasks/$totalTasks',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('개인KPI $personalKpiCount개',
                style: const TextStyle(color: AppTheme.warning, fontSize: 9, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: AppTheme.bgCard,
          valueColor: AlwaysStoppedAnimation(userColor),
          minHeight: 4,
        ),
        if (personalKpis.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 4, runSpacing: 4, children: personalKpis.take(3).map((k) =>
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(k.title,
                  style: const TextStyle(color: AppTheme.info, fontSize: 9)),
            ),
          ).toList()),
        ],
      ]),
    );
  }
}

// ── 퍼널 연결 현황 ────────────────────────────────────────
class _FunnelLinkStatus extends StatelessWidget {
  final AppProvider provider;
  final Project project;

  const _FunnelLinkStatus({required this.provider, required this.project});

  @override
  Widget build(BuildContext context) {
    // 이 프로젝트의 캠페인과 연결된 퍼널 단계 확인
    final campaignId = project.campaignId;
    if (campaignId == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('캠페인을 연결하면 마케팅 퍼널 현황을 여기서 확인할 수 있습니다.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.accentPurple.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.accentPurple.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            Icon(Icons.arrow_upward, color: AppTheme.accentPurple.withValues(alpha: 0.6), size: 14),
            const SizedBox(width: 8),
            const Text('위 "캠페인 연결" 섹션에서 캠페인을 먼저 연결하세요',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ]),
        ),
      ]);
    }

    // 연결된 KPI 중 퍼널 스테이지가 있는 것 표시
    final funnelLinkedKpis = provider.kpis
        .where((k) => k.campaignId == campaignId && k.funnelStageKey != null)
        .toList();
    final stages = provider.funnelStages;

    if (funnelLinkedKpis.isEmpty && stages.isEmpty) {
      return const Text('이 캠페인에 연결된 퍼널 데이터가 없습니다',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('마케팅 퍼널 전환 현황',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      ...stages.take(4).map((stage) {
        final pct = stage.previousValue > 0
            ? stage.value / stage.previousValue
            : 1.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.accentPurple.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: [
            Text(stage.icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(child: Text(stage.label,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
            Text('${(pct * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: pct >= 0.5 ? AppTheme.success : AppTheme.warning,
                  fontSize: 11, fontWeight: FontWeight.w700,
                )),
          ]),
        );
      }),
    ]);
  }
}

// ── 연결 고객사 현황 ──────────────────────────────────────
class _LinkedClientsStatus extends StatelessWidget {
  final AppProvider provider;
  final Project project;

  const _LinkedClientsStatus({required this.provider, required this.project});

  @override
  Widget build(BuildContext context) {
    // 이 프로젝트 태스크에서 고객사 ID 수집
    final clientIds = <String>{};
    for (final task in project.tasks) {
      clientIds.addAll(task.targetClientIds);
    }

    if (clientIds.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('태스크에 고객사를 지정하면 여기서 확인할 수 있습니다.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        const SizedBox(height: 6),
        const Text('태스크 편집 → "대상 고객사" 필드에서 설정하세요',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ]);
    }

    final clients = provider.clients.where((c) => clientIds.contains(c.id)).toList();
    return Wrap(spacing: 6, runSpacing: 6, children: clients.map((c) {
      final regionColor = _regionColor(c.regionEn ?? c.region ?? '');
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: regionColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: regionColor.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.business, color: regionColor, size: 12),
          const SizedBox(width: 4),
          Text(c.name, style: TextStyle(color: regionColor, fontSize: 11, fontWeight: FontWeight.w600)),
          if (c.country != null) ...[
            const SizedBox(width: 4),
            Text(c.country!, style: TextStyle(color: regionColor.withValues(alpha: 0.7), fontSize: 9)),
          ],
        ]),
      );
    }).toList());
  }

  Color _regionColor(String region) {
    final lower = region.toLowerCase();
    if (lower.contains('asia') || lower.contains('아시아')) return const Color(0xFF4CAF50);
    if (lower.contains('middle') || lower.contains('중동')) return const Color(0xFFFF9800);
    if (lower.contains('europe') || lower.contains('유럽')) return const Color(0xFF2196F3);
    if (lower.contains('america') || lower.contains('미주')) return const Color(0xFF9C27B0);
    if (lower.contains('국내') || lower.contains('korea')) return AppTheme.mintPrimary;
    return AppTheme.textSecondary;
  }
}
