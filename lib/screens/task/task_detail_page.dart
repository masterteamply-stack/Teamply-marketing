import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../utils/web_utils.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../widgets/edit_dialog.dart';
import 'task_attachment_tab.dart';

class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({super.key});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  TaskDetail? _findTask(AppProvider provider) {
    final taskId = provider.selectedTaskId;
    if (taskId == null) return null;
    for (final proj in provider.projectStore) {
      for (final t in proj.tasks) {
        if (t.id == taskId) return t;
      }
    }
    return null;
  }

  Project? _findProject(AppProvider provider, String taskId) {
    for (final proj in provider.projectStore) {
      for (final t in proj.tasks) {
        if (t.id == taskId) return proj;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final task = _findTask(provider);
    if (task == null) return const Center(child: Text('태스크를 선택해주세요', style: TextStyle(color: AppTheme.textMuted)));

    final project = _findProject(provider, task.id);
    final prColor = _priorityColor(task.priority);
    final prLabel = _priorityLabel(task.priority);
    final statusColor = _statusColor(task.status);
    final statusLabel = _statusLabel(task.status);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
            color: AppTheme.bgCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (project != null)
                    TextButton(
                      onPressed: () => provider.selectProject(project.id),
                      child: Text('← ${project.name}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ),
                  const Spacer(),
                  // 태스크 인라인 편집 버튼
                  if (project != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_rounded, size: 13),
                      label: const Text('편집', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.mintPrimary,
                        side: BorderSide(color: AppTheme.mintPrimary.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                      ),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => TaskEditDialog(task: task, project: project, provider: provider),
                      ),
                    ),
                ]),
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(task.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(task.description, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                      const SizedBox(height: 10),
                      Row(children: [
                        _PillBadge(label: prLabel, color: prColor),
                        const SizedBox(width: 8),
                        _PillBadge(label: statusLabel, color: statusColor),
                        const SizedBox(width: 8),
                        if (task.dueDate != null)
                          _PillBadge(
                            label: task.isOverdue
                                ? 'D+${task.dueDate!.difference(DateTime.now()).inDays.abs()}일 지연'
                                : 'D-${task.dueDate!.difference(DateTime.now()).inDays}',
                            color: task.isOverdue ? AppTheme.error : AppTheme.textMuted,
                          ),
                        const SizedBox(width: 8),
                        // Tags
                        ...task.tags.map((t) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _PillBadge(label: '#$t', color: AppTheme.textMuted),
                        )),
                      ]),
                    ]),
                  ),
                  const SizedBox(width: 20),
                  // Right side: Quick info
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    _QuickInfoRow(icon: Icons.checklist, label: '체크리스트', value: '${task.checklist.where((c) => c.isDone).length}/${task.checklist.length}'),
                    const SizedBox(height: 4),
                    _QuickInfoRow(icon: Icons.calendar_today_outlined, label: '마감일',
                      value: task.dueDate != null ? DateFormat('yyyy.MM.dd').format(task.dueDate!) : '없음'),
                    const SizedBox(height: 4),
                    _QuickInfoRow(icon: Icons.account_balance_wallet_outlined, label: '예산',
                      value: task.budget != null ? '${task.budget!.currency.symbol}${NumberFormat('#,###').format(task.budget!.totalBudget)}' : '미설정'),
                    const SizedBox(height: 8),
                    // Status change dropdown
                    _StatusDropdown(task: task, provider: provider, project: project),
                  ]),
                ]),
                const SizedBox(height: 14),
                TabBar(
                  controller: _tab,
                  isScrollable: true,
                  labelColor: AppTheme.mintPrimary,
                  unselectedLabelColor: AppTheme.textMuted,
                  indicatorColor: AppTheme.mintPrimary,
                  tabs: [
                    const Tab(text: '체크리스트'),
                    const Tab(text: '일정 & 멘션'),
                    const Tab(text: '비용 관리'),
                    const Tab(text: 'KPI 트래커'),
                    const Tab(text: '코멘트'),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('첨부파일'),
                          if (task.attachments.isNotEmpty) ...[  
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.mintPrimary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('${task.attachments.length}',
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tab(text: '상세 정보'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _ChecklistTab(task: task, provider: provider, project: project),
                _ScheduleMentionTab(task: task, provider: provider, project: project),
                _CostTab(task: task, provider: provider, project: project),
                _KpiTrackerTab(task: task, provider: provider, project: project),
                _CommentTab(task: task, provider: provider, project: project),
                TaskAttachmentTab(task: task, provider: provider, project: project),
                _InfoTab(task: task, provider: provider, project: project),
              ],
            ),
          ),
        ],
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

  static Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.todo: return AppTheme.textMuted;
      case TaskStatus.inProgress: return AppTheme.info;
      case TaskStatus.inReview: return AppTheme.warning;
      case TaskStatus.done: return AppTheme.success;
    }
  }

  static String _statusLabel(TaskStatus s) {
    switch (s) {
      case TaskStatus.todo: return '할 일';
      case TaskStatus.inProgress: return '진행 중';
      case TaskStatus.inReview: return '검토 중';
      case TaskStatus.done: return '완료';
    }
  }
}

class _StatusDropdown extends StatelessWidget {
  final TaskDetail task;
  final AppProvider provider;
  final Project? project;
  const _StatusDropdown({required this.task, required this.provider, required this.project});

  @override
  Widget build(BuildContext context) {
    if (project == null) return const SizedBox();
    const statuses = [TaskStatus.todo, TaskStatus.inProgress, TaskStatus.inReview, TaskStatus.done];
    final labels = ['할 일', '진행 중', '검토 중', '완료'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TaskStatus>(
          value: task.status,
          dropdownColor: AppTheme.bgCard,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
          items: statuses.asMap().entries.map((e) => DropdownMenuItem(value: e.value, child: Text(labels[e.key]))).toList(),
          onChanged: (s) {
            if (s != null) provider.updateTaskStatus(project!.id, task.id, s);
          },
        ),
      ),
    );
  }
}

// ── Checklist Tab ──────────────────────────────────────
class _ChecklistTab extends StatefulWidget {
  final TaskDetail task;
  final AppProvider provider;
  final Project? project;
  const _ChecklistTab({required this.task, required this.provider, required this.project});

  @override
  State<_ChecklistTab> createState() => _ChecklistTabState();
}

class _ChecklistTabState extends State<_ChecklistTab> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final provider = widget.provider;
    final project = widget.project;
    final done = task.checklist.where((c) => c.isDone).length;
    final total = task.checklist.length;
    final pct = total > 0 ? done / total * 100 : 0.0;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checklist
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('체크리스트', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  Text('$done/$total 완료', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                ]),
                const SizedBox(height: 8),
                if (total > 0)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      backgroundColor: AppTheme.bgCardLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.mintPrimary),
                      minHeight: 8,
                    ),
                  ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: task.checklist.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1E3040)),
                    itemBuilder: (_, i) {
                      final item = task.checklist[i];
                      return ChecklistItemTile(
                        item: item,
                        attachments: task.attachments,
                        provider: provider,
                        projectId: project?.id,
                        taskId: task.id,
                        onToggle: () {
                          if (project != null) provider.toggleChecklistItem(project.id, task.id, item.id);
                        },
                      );
                    },
                  ),
                ),
                // Add checklist item
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: '체크리스트 항목 추가...',
                        prefixIcon: const Icon(Icons.add_circle_outline, size: 18, color: AppTheme.textMuted),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: AppTheme.bgCardLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty && project != null) {
                          provider.addChecklistItem(project.id, task.id, v.trim());
                          _ctrl.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (_ctrl.text.trim().isNotEmpty && project != null) {
                        provider.addChecklistItem(project.id, task.id, _ctrl.text.trim());
                        _ctrl.clear();
                      }
                    },
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                    child: const Text('추가'),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Right panel: Stats + Attachment Quick View
          SizedBox(
            width: 240,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 진행 현황
              const Text('진행 현황', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _ProgressDonut(percent: pct),
              const SizedBox(height: 12),
              _StatRow(label: '전체 항목', value: '$total개', color: AppTheme.textSecondary),
              _StatRow(label: '완료', value: '$done개', color: AppTheme.success),
              _StatRow(label: '미완료', value: '${total - done}개', color: AppTheme.warning),
              const SizedBox(height: 20),
              // ── 예산 요약 ──
              _ChecklistBudgetSummary(task: task),
              const SizedBox(height: 20),
              // 첨부파일 빠른 보기 패널
              _ChecklistAttachmentPanel(task: task, provider: provider, project: project),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── 체크리스트 항목 타일 (고객사·지역·예산 통합) ───────────
class ChecklistItemTile extends StatefulWidget {
  final ChecklistItem item;
  final VoidCallback onToggle;
  final List<TaskAttachment>? attachments;
  final AppProvider? provider;
  final String? projectId;
  final String? taskId;
  const ChecklistItemTile({
    required this.item,
    required this.onToggle,
    this.attachments,
    this.provider,
    this.projectId,
    this.taskId,
    super.key,
  });

  @override
  State<ChecklistItemTile> createState() => _ChecklistItemTileState();
}

class _ChecklistItemTileState extends State<ChecklistItemTile> {
  bool _expanded = false;

  void _save({
    String? clientId,
    String? region,
    String? country,
    double? allocatedBudget,
    double? executedAmount,
    String? costNote,
    String? title,
  }) {
    if (widget.provider == null || widget.projectId == null || widget.taskId == null) return;
    widget.provider!.updateChecklistItemBudget(
      widget.projectId!,
      widget.taskId!,
      widget.item.id,
      clientId: clientId,
      region: region,
      country: country,
      allocatedBudget: allocatedBudget,
      executedAmount: executedAmount,
      costNote: costNote,
      title: title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final linkedAttachments = widget.attachments?.where((a) => a.checklistItemId == item.id).toList() ?? [];
    final hasExtra = item.clientId != null || item.region != null ||
        (item.allocatedBudget ?? 0) > 0 || (item.executedAmount ?? 0) > 0;
    final fmt = NumberFormat('#,###');
    final budgetUsage = item.budgetUsageRate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─ 메인 행 ─
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                // 체크박스
                GestureDetector(
                  onTap: widget.onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22, height: 22,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: item.isDone ? AppTheme.mintPrimary : Colors.transparent,
                      border: Border.all(color: item.isDone ? AppTheme.mintPrimary : AppTheme.textMuted, width: 2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: item.isDone ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                  ),
                ),
                // 제목
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: item.isDone ? AppTheme.textMuted : AppTheme.textPrimary,
                      decoration: item.isDone ? TextDecoration.lineThrough : null,
                      fontSize: 13,
                    ),
                  ),
                ),
                // 배지들
                if (item.clientId != null)
                  _badge(Icons.business_rounded, item.clientId!, AppTheme.accentBlue),
                if (item.region != null)
                  _badge(Icons.location_on_rounded, item.region!, AppTheme.warning),
                if ((item.allocatedBudget ?? 0) > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _budgetColor(budgetUsage).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _budgetColor(budgetUsage).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${budgetUsage.toStringAsFixed(0)}%',
                      style: TextStyle(color: _budgetColor(budgetUsage), fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                if (linkedAttachments.isNotEmpty)
                  _badge(Icons.attach_file_rounded, '${linkedAttachments.length}', AppTheme.accentBlue),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppTheme.textMuted, size: 14,
                ),
              ],
            ),
          ),
        ),
        // ─ 첨부파일 미니 목록 ─
        if (!_expanded && linkedAttachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 16, bottom: 4),
            child: Wrap(
              spacing: 4, runSpacing: 4,
              children: linkedAttachments.map((a) => _AttachmentMiniChip(attachment: a)).toList(),
            ),
          ),
        // ─ 확장 편집 패널 ─
        if (_expanded)
          _ChecklistItemEditPanel(
            item: item,
            provider: widget.provider,
            projectId: widget.projectId,
            taskId: widget.taskId,
            attachments: linkedAttachments,
            onClose: () => setState(() => _expanded = false),
            onSave: _save,
          ),
      ],
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 9),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Color _budgetColor(double pct) {
    if (pct >= 100) return AppTheme.error;
    if (pct >= 80) return AppTheme.warning;
    return AppTheme.success;
  }
}

// ── 체크리스트 항목 인라인 편집 패널 ─────────────────────
class _ChecklistItemEditPanel extends StatefulWidget {
  final ChecklistItem item;
  final AppProvider? provider;
  final String? projectId;
  final String? taskId;
  final List<TaskAttachment> attachments;
  final VoidCallback onClose;
  final Function({String? clientId, String? region, String? country,
      double? allocatedBudget, double? executedAmount, String? costNote, String? title}) onSave;

  const _ChecklistItemEditPanel({
    required this.item,
    required this.provider,
    required this.projectId,
    required this.taskId,
    required this.attachments,
    required this.onClose,
    required this.onSave,
  });

  @override
  State<_ChecklistItemEditPanel> createState() => _ChecklistItemEditPanelState();
}

class _ChecklistItemEditPanelState extends State<_ChecklistItemEditPanel> {
  late TextEditingController _titleCtrl;
  late TextEditingController _allocCtrl;
  late TextEditingController _execCtrl;
  late TextEditingController _noteCtrl;

  String? _selectedClientId;
  String? _selectedRegion;
  String? _selectedCountry;

  static const _regions = ['국내', '동남아', '중동', '북미', '유럽', '중국', '일본', '기타'];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _titleCtrl = TextEditingController(text: item.title);
    _allocCtrl = TextEditingController(
        text: (item.allocatedBudget ?? 0) > 0 ? item.allocatedBudget!.toStringAsFixed(0) : '');
    _execCtrl = TextEditingController(
        text: (item.executedAmount ?? 0) > 0 ? item.executedAmount!.toStringAsFixed(0) : '');
    _noteCtrl = TextEditingController(text: item.costNote ?? '');
    _selectedClientId = item.clientId;
    _selectedRegion = item.region;
    _selectedCountry = item.country;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _allocCtrl.dispose();
    _execCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSave(
      title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : null,
      clientId: _selectedClientId,
      region: _selectedRegion,
      country: _selectedCountry,
      allocatedBudget: double.tryParse(_allocCtrl.text.replaceAll(',', '')),
      executedAmount: double.tryParse(_execCtrl.text.replaceAll(',', '')),
      costNote: _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
    );
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final clients = widget.provider?.activeClients ?? [];
    final fmt = NumberFormat('#,###');
    final alloc = double.tryParse(_allocCtrl.text.replaceAll(',', '')) ?? 0;
    final exec = double.tryParse(_execCtrl.text.replaceAll(',', '')) ?? 0;
    final usagePct = alloc > 0 ? (exec / alloc * 100).clamp(0.0, 200.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(left: 32, right: 4, bottom: 8, top: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2030),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.mintPrimary.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(children: [
              const Icon(Icons.edit_note_rounded, color: AppTheme.mintPrimary, size: 14),
              const SizedBox(width: 6),
              const Text('항목 설정', style: TextStyle(color: AppTheme.mintPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              InkWell(onTap: widget.onClose, child: const Icon(Icons.close, color: AppTheme.textMuted, size: 14)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 제목 편집 ──
                _label('업무 항목명'),
                const SizedBox(height: 4),
                TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: _inputDeco(hint: '업무 항목 이름'),
                ),
                const SizedBox(height: 12),

                // ── 고객사 / 권역 / 국가 ──
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // 고객사 선택
                  Expanded(
                    flex: 2,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        _label('고객사'),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            Navigator.pushNamed(context, '/settings/clients');
                          },
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.add_circle_outline, color: AppTheme.mintPrimary, size: 11),
                            SizedBox(width: 2),
                            Text('추가', style: TextStyle(color: AppTheme.mintPrimary, fontSize: 10, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: clients.any((c) => c.id == _selectedClientId) ? _selectedClientId : null,
                            hint: const Text('고객사 선택', style: TextStyle(color: AppTheme.textDisabled, fontSize: 12)),
                            isExpanded: true,
                            dropdownColor: AppTheme.bgCard,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                            items: [
                              const DropdownMenuItem<String>(value: null, child: Text('(없음)', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                              ...clients.map((c) => DropdownMenuItem<String>(
                                value: c.id,
                                child: Row(children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(color: AppTheme.accentBlue, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                                  if (c.region != null)
                                    Text(' (${c.region})', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                                ]),
                              )),
                            ],
                            onChanged: (v) {
                              setState(() {
                                _selectedClientId = v;
                                // 고객사 선택 시 권역/국가 자동 채움
                                if (v != null) {
                                  final c = clients.firstWhere((x) => x.id == v);
                                  if (c.region != null) _selectedRegion = c.region;
                                  if (c.country != null) _selectedCountry = c.country;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  // 권역 선택
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('권역'),
                      const SizedBox(height: 4),
                      Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.bgCardLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _regions.contains(_selectedRegion) ? _selectedRegion : null,
                            hint: const Text('권역', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1A3045),
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                            items: [
                              const DropdownMenuItem<String>(value: null, child: Text('(없음)', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                              ..._regions.map((r) => DropdownMenuItem<String>(value: r, child: Text(r))),
                            ],
                            onChanged: (v) => setState(() => _selectedRegion = v),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  // 국가
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('국가'),
                      const SizedBox(height: 4),
                      TextField(
                        controller: TextEditingController(text: _selectedCountry),
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                        decoration: _inputDeco(hint: 'KR, SG…'),
                        onChanged: (v) => _selectedCountry = v.trim().isEmpty ? null : v.trim().toUpperCase(),
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),

                // ── 예산 / 집행 ──
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // 할당 예산
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('할당 예산 (₩)'),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _allocCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: _inputDeco(hint: '0', prefix: '₩ '),
                        onChanged: (_) => setState(() {}),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  // 집행 금액
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('집행 금액 (₩)'),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _execCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: _inputDeco(hint: '0', prefix: '₩ '),
                        onChanged: (_) => setState(() {}),
                      ),
                    ]),
                  ),
                ]),
                // ── 예산 사용률 바 ──
                if (alloc > 0) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (usagePct / 100).clamp(0.0, 1.0),
                          backgroundColor: AppTheme.bgCardLight,
                          valueColor: AlwaysStoppedAnimation<Color>(_budgetColor(usagePct)),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${usagePct.toStringAsFixed(1)}%',
                      style: TextStyle(color: _budgetColor(usagePct), fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '잔여 ₩${fmt.format((alloc - exec).clamp(0, double.infinity))}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                    ),
                  ]),
                ],
                const SizedBox(height: 10),

                // ── 메모 ──
                _label('비용 메모'),
                const SizedBox(height: 4),
                TextField(
                  controller: _noteCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                  decoration: _inputDeco(hint: '비용 관련 메모 (선택)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                // ── 첨부파일 목록 ──
                if (widget.attachments.isNotEmpty) ...[
                  _label('연결된 첨부파일'),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4, runSpacing: 4,
                    children: widget.attachments.map((a) => _AttachmentMiniChip(attachment: a)).toList(),
                  ),
                  const SizedBox(height: 10),
                ],

                // ── 저장/취소 버튼 ──
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onClose,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textMuted,
                        side: BorderSide(color: AppTheme.textMuted.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('취소', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.save_rounded, size: 14),
                      label: const Text('저장', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.mintPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w500));

  InputDecoration _inputDeco({String? hint, String? prefix}) => InputDecoration(
    hintText: hint,
    prefixText: prefix,
    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
    prefixStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    filled: true,
    fillColor: AppTheme.bgCardLight,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.mintPrimary, width: 1.5)),
  );

  Color _budgetColor(double pct) {
    if (pct >= 100) return AppTheme.error;
    if (pct >= 80) return AppTheme.warning;
    return AppTheme.success;
  }
}

// ── 체크리스트 예산 요약 패널 (우측) ─────────────────────
class _ChecklistBudgetSummary extends StatelessWidget {
  final TaskDetail task;
  const _ChecklistBudgetSummary({required this.task});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final totalAlloc = task.checklistTotalAllocated;
    final totalExec  = task.checklistTotalExecuted;
    final usagePct   = task.checklistBudgetUsageRate;
    final hasData = task.checklist.any((c) => (c.allocatedBudget ?? 0) > 0 || (c.executedAmount ?? 0) > 0);

    // 고객사별 집계
    final Map<String, double> clientExec = {};
    for (final c in task.checklist) {
      if (c.clientId != null && (c.executedAmount ?? 0) > 0) {
        clientExec[c.clientId!] = (clientExec[c.clientId!] ?? 0) + (c.executedAmount ?? 0);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.mintPrimary, size: 13),
          const SizedBox(width: 6),
          const Text('예산 요약', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        if (!hasData)
          const Text('할당 예산 없음', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))
        else ...[
          // 전체 사용률 바
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (usagePct / 100).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFF1E3040),
              valueColor: AlwaysStoppedAnimation<Color>(_budgetColor(usagePct)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('집행률 ${usagePct.toStringAsFixed(1)}%',
                style: TextStyle(color: _budgetColor(usagePct), fontSize: 10, fontWeight: FontWeight.w700)),
            Text('₩${fmt.format(totalAlloc)}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
          ]),
          const SizedBox(height: 6),
          _SummaryRow('할당', '₩${fmt.format(totalAlloc)}', AppTheme.textSecondary),
          _SummaryRow('집행', '₩${fmt.format(totalExec)}', AppTheme.accentBlue),
          _SummaryRow('잔여', '₩${fmt.format((totalAlloc - totalExec).clamp(0, double.infinity))}',
              totalAlloc - totalExec < 0 ? AppTheme.error : AppTheme.success),
          if (clientExec.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 6),
            const Text('고객사별 집행', style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ...clientExec.entries.map((e) => _SummaryRow(e.key, '₩${fmt.format(e.value)}', AppTheme.warning)),
          ],
        ],
      ]),
    );
  }

  Widget _SummaryRow(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      Text(value, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    ]),
  );

  Color _budgetColor(double pct) {
    if (pct >= 100) return AppTheme.error;
    if (pct >= 80) return AppTheme.warning;
    return AppTheme.success;
  }
}

class _ProgressDonut extends StatelessWidget {
  final double percent;
  const _ProgressDonut({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 100, height: 100,
        child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(
            value: percent / 100,
            strokeWidth: 10,
            backgroundColor: AppTheme.bgCardLight,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.mintPrimary),
          ),
          Text('${percent.toStringAsFixed(0)}%', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ── 첨부파일 미니 칩 (체크리스트 항목 아래 표시) ──────────
class _AttachmentMiniChip extends StatelessWidget {
  final TaskAttachment attachment;
  const _AttachmentMiniChip({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final fileType = attachment.fileType;
    final color = Color(int.parse('0xFF${fileType.colorHex.substring(1)}'));
    return GestureDetector(
      onTap: () {
        if (attachment.url.isNotEmpty) {
          // URL 복사
          Clipboard.setData(ClipboardData(text: attachment.url));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('링크 복사: ${attachment.name}'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(fileType.icon, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 3),
          Text(attachment.name,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// ── 체크리스트 탭 오른쪽 - 첨부파일 빠른 패널 ────────────
class _ChecklistAttachmentPanel extends StatefulWidget {
  final TaskDetail task;
  final AppProvider provider;
  final Project? project;
  const _ChecklistAttachmentPanel({required this.task, required this.provider, required this.project});

  @override
  State<_ChecklistAttachmentPanel> createState() => _ChecklistAttachmentPanelState();
}

class _ChecklistAttachmentPanelState extends State<_ChecklistAttachmentPanel> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final attachments = widget.task.attachments;
    final count = attachments.length;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 헤더
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              const Icon(Icons.attach_file_rounded, color: AppTheme.mintPrimary, size: 14),
              const SizedBox(width: 6),
              const Text('첨부파일',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.mintPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$count',
                      style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              const Spacer(),
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppTheme.textMuted, size: 14),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1, color: AppTheme.border),
          // 첨부파일 목록 (최대 5개)
          if (attachments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                const Icon(Icons.attach_file_rounded, color: AppTheme.textMuted, size: 20),
                const SizedBox(height: 4),
                const Text('첨부파일 없음',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                const SizedBox(height: 8),
                _addButtons(context),
              ]),
            )
          else ...[
            ...attachments.take(5).map((a) => _attachmentRow(context, a)),
            if (attachments.length > 5)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text('+${attachments.length - 5}개 더 있음',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              ),
            const Divider(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.all(8),
              child: _addButtons(context),
            ),
          ],
        ],
      ]),
    );
  }

  Widget _attachmentRow(BuildContext context, TaskAttachment a) {
    final color = Color(int.parse('0xFF${a.fileType.colorHex.substring(1)}'));
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: a.url));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('링크 복사: ${a.name}'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          Text(a.fileType.icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.name,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
            Text('${a.sourceType.emoji} ${a.sourceType.label}',
                style: TextStyle(color: color, fontSize: 9)),
          ])),
          Icon(Icons.copy_outlined, color: AppTheme.textMuted, size: 12),
        ]),
      ),
    );
  }

  Widget _addButtons(BuildContext context) {
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          icon: const Icon(Icons.add_link_rounded, size: 11),
          label: const Text('링크', style: TextStyle(fontSize: 10)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.accentBlue,
            side: BorderSide(color: AppTheme.accentBlue.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            minimumSize: const Size(0, 28),
          ),
          onPressed: () => _showAttachDialog(context, initialTab: 0),
        ),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.upload_file_rounded, size: 11),
          label: const Text('파일', style: TextStyle(fontSize: 10)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.mintPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            minimumSize: const Size(0, 28),
          ),
          onPressed: () => _showAttachDialog(context, initialTab: 1),
        ),
      ),
    ]);
  }

  void _showAttachDialog(BuildContext context, {int initialTab = 0}) {
    showDialog(
      context: context,
      builder: (_) => _AttachmentQuickDialog(
        task: widget.task,
        provider: widget.provider,
        project: widget.project,
        initialTab: initialTab,
      ),
    ).then((_) => setState(() {}));
  }
}

// ── 첨부파일 빠른 추가 다이얼로그 (체크리스트 탭용) ────────
class _AttachmentQuickDialog extends StatefulWidget {
  final TaskDetail task;
  final AppProvider provider;
  final Project? project;
  final int initialTab;
  const _AttachmentQuickDialog({
    required this.task, required this.provider, required this.project, required this.initialTab,
  });
  @override
  State<_AttachmentQuickDialog> createState() => _AttachmentQuickDialogState();
}

class _AttachmentQuickDialogState extends State<_AttachmentQuickDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _nameCtrl = TextEditingController();
  final _urlCtrl  = TextEditingController();
  AttachmentSourceType _srcType = AttachmentSourceType.link;
  String? _selectedChecklistId;
  String? _error;
  String? _pickedFileName;
  int?    _pickedFileSize;

  static const _srcPresets = [
    (AttachmentSourceType.link,        '🔗 URL'),
    (AttachmentSourceType.googleDrive, '📂 Google Drive'),
    (AttachmentSourceType.oneDrive,    '☁️ OneDrive'),
    (AttachmentSourceType.email,       '📧 이메일'),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose(); _nameCtrl.dispose(); _urlCtrl.dispose(); super.dispose();
  }

  void _onUrlChanged(String url) {
    if (_nameCtrl.text.isEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final seg = uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull;
        if (seg != null) _nameCtrl.text = Uri.decodeComponent(seg);
      }
    }
    final lower = url.toLowerCase();
    if (lower.contains('drive.google.com') || lower.contains('docs.google.com'))
      setState(() => _srcType = AttachmentSourceType.googleDrive);
    else if (lower.contains('onedrive.live.com') || lower.contains('sharepoint.com') || lower.contains('1drv.ms'))
      setState(() => _srcType = AttachmentSourceType.oneDrive);
    else if (lower.contains('mailto:') || (lower.contains('@') && lower.contains('.')))
      setState(() => _srcType = AttachmentSourceType.email);
  }

  void _save() {
    final url  = _urlCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (url.isEmpty)  { setState(() => _error = 'URL을 입력해주세요'); return; }
    if (name.isEmpty) { setState(() => _error = '이름을 입력해주세요'); return; }
    if (widget.project == null) { setState(() => _error = '프로젝트 정보 없음'); return; }

    final ft = TaskAttachment.inferFileType(url, _srcType);
    widget.provider.addTaskAttachment(widget.project!.id, widget.task.id, TaskAttachment(
      id: 'att_${DateTime.now().millisecondsSinceEpoch}',
      name: name, url: url, fileType: ft, sourceType: _srcType,
      checklistItemId: _selectedChecklistId,
      uploadedBy: widget.provider.currentUser.id,
      createdAt: DateTime.now(),
      fileSizeBytes: _pickedFileSize,
    ));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ "$name" 첨부 완료'),
      backgroundColor: AppTheme.accentGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 560),
        child: Column(children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 6),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.mintPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.attach_file_rounded, color: AppTheme.mintPrimary, size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('첨부파일 추가',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700))),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 16),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          TabBar(
            controller: _tab,
            labelColor: AppTheme.mintPrimary,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.mintPrimary,
            tabs: const [
              Tab(icon: Icon(Icons.link, size: 14), text: '링크/URL'),
              Tab(icon: Icon(Icons.upload_file, size: 14), text: '파일 첨부'),
            ],
          ),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 서비스 빠른 선택 (탭 0)
              if (_tab.index == 0) ...[
                const Text('출처 선택', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: _srcPresets.map((p) {
                  final active = _srcType == p.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _srcType = p.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: active ? AppTheme.mintPrimary.withValues(alpha: 0.15) : AppTheme.bgCardLight,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: active ? AppTheme.mintPrimary : AppTheme.border,
                          width: active ? 1.5 : 1,
                        ),
                      ),
                      child: Text(p.$2, style: TextStyle(
                        fontSize: 11,
                        color: active ? AppTheme.mintPrimary : AppTheme.textSecondary,
                      )),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 12),
                _buildField('URL / 링크 *', _urlCtrl, hint: 'https://...', onChanged: _onUrlChanged),
              ],
              // 파일 선택 (탭 1)
              if (_tab.index == 1) ...[
                _buildFileDropZone(),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: AppTheme.info, size: 12),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      'OneDrive·Google Drive 공유 링크 사용을 권장합니다.',
                      style: TextStyle(color: AppTheme.info.withValues(alpha: 0.8), fontSize: 10),
                    )),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              _buildField('표시 이름 *', _nameCtrl, hint: '파일/링크 이름'),
              // 체크리스트 연결
              if (widget.task.checklist.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('체크리스트 항목 연결 (선택)',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedChecklistId,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true, fillColor: AppTheme.bgCardLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(7),
                        borderSide: const BorderSide(color: AppTheme.border)),
                    hintText: '연결할 항목 선택 (선택사항)',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                  dropdownColor: AppTheme.bgCard,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                  items: [
                    const DropdownMenuItem(value: null,
                        child: Text('연결 안함', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                    ...widget.task.checklist.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Row(children: [
                        Icon(c.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                            size: 12, color: c.isDone ? AppTheme.mintPrimary : AppTheme.textMuted),
                        const SizedBox(width: 5),
                        Expanded(child: Text(c.title, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11))),
                      ]),
                    )),
                  ],
                  onChanged: (v) => setState(() => _selectedChecklistId = v),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 13),
                    const SizedBox(width: 5),
                    Text(_error!, style: const TextStyle(color: AppTheme.accentRed, fontSize: 11)),
                  ]),
                ),
              ],
            ]),
          )),
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(children: [
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                icon: const Icon(Icons.save_rounded, size: 13),
                label: const Text('첨부 추가', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mintPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                onPressed: _save,
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl,
      {String? hint, void Function(String)? onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 5),
      TextField(
        controller: ctrl, onChanged: onChanged,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          filled: true, fillColor: AppTheme.bgCardLight,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: AppTheme.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: AppTheme.border)),
        ),
      ),
    ]);
  }

  Widget _buildFileDropZone() {
    return GestureDetector(
      onTap: _pickFile,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: double.infinity, height: 90,
          decoration: BoxDecoration(
            color: AppTheme.bgDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _pickedFileName != null ? AppTheme.accentGreen : AppTheme.border,
              width: 1.5,
            ),
          ),
          child: _pickedFileName != null
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 22),
                  const SizedBox(height: 4),
                  Text(_pickedFileName!, style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                  if (_pickedFileSize != null)
                    Text(_fmtSize(_pickedFileSize!), style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                  TextButton(
                    onPressed: () => setState(() { _pickedFileName = null; _pickedFileSize = null; _urlCtrl.clear(); }),
                    child: const Text('다른 파일 선택', style: TextStyle(fontSize: 10)),
                  ),
                ])
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.upload_rounded, color: AppTheme.mintPrimary, size: 22),
                  const SizedBox(height: 4),
                  const Text('클릭하여 파일 선택', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const Text('PDF, PPT, Word, 이미지, 소스코드 등', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                ]),
        ),
      ),
    );
  }

  void _pickFile() {
    if (!kIsWeb) return;
    pickAnyFile(
      onFilePicked: (fileName, fileSize, objectUrl) {
        if (!mounted) return;
        setState(() {
          _pickedFileName = fileName;
          _pickedFileSize = fileSize;
          _urlCtrl.text = objectUrl;
          _srcType = AttachmentSourceType.file;
          if (_nameCtrl.text.isEmpty) _nameCtrl.text = fileName;
        });
      },
    );
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }
}


class _StatRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        const Spacer(),
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Schedule & Mention Tab ─────────────────────────────
class _ScheduleMentionTab extends StatefulWidget {
  final TaskDetail task;
  final AppProvider provider;
  final Project? project;
  const _ScheduleMentionTab({required this.task, required this.provider, required this.project});

  @override
  State<_ScheduleMentionTab> createState() => _ScheduleMentionTabState();
}

class _ScheduleMentionTabState extends State<_ScheduleMentionTab> {
  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final provider = widget.provider;
    final project = widget.project;
    final dfmt = DateFormat('yyyy.MM.dd');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Schedule
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('일정 관리', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showAddScheduleDialog(context, provider, project, task),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('일정 추가', style: TextStyle(fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 12),
                Expanded(
                  child: task.schedules.isEmpty
                      ? const Center(child: Text('등록된 일정이 없습니다', style: TextStyle(color: AppTheme.textMuted)))
                      : ListView.separated(
                          itemCount: task.schedules.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final s = task.schedules[i];
                            final col = s.color != null ? Color(int.parse('0xFF${s.color!.substring(1)}')) : AppTheme.mintPrimary;
                            final duration = s.endDate.difference(s.startDate).inDays + 1;
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.bgCard,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: col.withValues(alpha: 0.3)),
                              ),
                              child: Row(children: [
                                Container(width: 4, height: 50, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(2))),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Text(s.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                                    const Spacer(),
                                    _Toggle(value: s.isDone, label: s.isDone ? '완료' : '진행 중', color: col),
                                  ]),
                                  const SizedBox(height: 4),
                                  Text('${dfmt.format(s.startDate)} ~ ${dfmt.format(s.endDate)} ($duration일)', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                ])),
                              ]),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Mentions / Assignees
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('담당자 & 멘션', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showMentionDialog(context, provider, task),
                    icon: const Icon(Icons.alternate_email, size: 14),
                    label: const Text('멘션 추가', style: TextStyle(fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 12),
                const Text('담당자', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                ...task.assigneeIds.map((uid) {
                  final u = provider.getUserById(uid);
                  if (u == null) return const SizedBox();
                  final col = u.avatarColor != null ? Color(int.parse('0xFF${u.avatarColor!.substring(1)}')) : AppTheme.mintPrimary;
                  return _MemberRow(user: u, color: col, badge: '담당자', badgeColor: '담당자');
                }),
                const SizedBox(height: 12),
                const Text('멘션된 사용자', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                if (task.mentionedUserIds.isEmpty)
                  const Text('멘션 없음', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))
                else
                  ...task.mentionedUserIds.map((uid) {
                    final u = provider.getUserById(uid);
                    if (u == null) return const SizedBox();
                    final col = u.avatarColor != null ? Color(int.parse('0xFF${u.avatarColor!.substring(1)}')) : AppTheme.mintPrimary;
                    return _MemberRow(user: u, color: col, badge: '@멘션', badgeColor: '멘션');
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddScheduleDialog(BuildContext context, AppProvider provider, Project? project, TaskDetail task) {
    if (project == null) return;
    final titleCtrl = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 3));
    String color = '#00BFA5';
    final colors = ['#00BFA5', '#29B6F6', '#AB47BC', '#FF7043', '#FFB300', '#66BB6A'];
    final dfmt = DateFormat('yyyy.MM.dd');

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('일정 추가', style: TextStyle(color: AppTheme.textPrimary)),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleCtrl, style: const TextStyle(color: AppTheme.textPrimary), decoration: const InputDecoration(labelText: '일정명 *')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: startDate, firstDate: DateTime(2024), lastDate: DateTime(2027), builder: (_, c) => Theme(data: ThemeData.dark(), child: c!));
                    if (d != null) setState(() => startDate = d);
                  },
                  child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(8)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('시작일', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                        Text(dfmt.format(startDate), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                      ])),
                )),
                const SizedBox(width: 8),
                Expanded(child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: endDate, firstDate: startDate, lastDate: DateTime(2027), builder: (_, c) => Theme(data: ThemeData.dark(), child: c!));
                    if (d != null) setState(() => endDate = d);
                  },
                  child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(8)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('종료일', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                        Text(dfmt.format(endDate), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                      ])),
                )),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: colors.map((c) {
                final col = Color(int.parse('0xFF${c.substring(1)}'));
                return GestureDetector(onTap: () => setState(() => color = c),
                  child: Container(width: 28, height: 28, decoration: BoxDecoration(color: col, shape: BoxShape.circle, border: Border.all(color: color == c ? Colors.white : Colors.transparent, width: 2.5))));
              }).toList()),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty) {
                  provider.addScheduleItem(project.id, task.id, ScheduleItem(
                    id: 'sc_${DateTime.now().millisecondsSinceEpoch}',
                    title: titleCtrl.text.trim(),
                    startDate: startDate, endDate: endDate,
                    color: color,
                  ));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMentionDialog(BuildContext context, AppProvider provider, TaskDetail task) {
    final available = provider.allUsers.where((u) => !task.mentionedUserIds.contains(u.id) && !task.assigneeIds.contains(u.id)).toList();
    AppUser? selected;
    // Find project for this task
    Project? taskProject;
    for (final p in provider.projectStore) {
      for (final t in p.tasks) {
        if (t.id == task.id) { taskProject = p; break; }
      }
    }
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('@멘션 추가', style: TextStyle(color: AppTheme.textPrimary)),
          content: SizedBox(
            width: 350,
            child: Column(mainAxisSize: MainAxisSize.min,
              children: available.map((u) {
                final col = u.avatarColor != null ? Color(int.parse('0xFF${u.avatarColor!.substring(1)}')) : AppTheme.mintPrimary;
                return RadioListTile<AppUser>(
                  value: u, groupValue: selected,
                  onChanged: (v) => setState(() => selected = v),
                  activeColor: AppTheme.mintPrimary,
                  title: Row(children: [
                    CircleAvatar(radius: 14, backgroundColor: col.withValues(alpha: 0.3), child: Text(u.avatarInitials, style: TextStyle(color: col, fontSize: 10))),
                    const SizedBox(width: 10),
                    Text(u.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                  ]),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                if (selected != null) {
                  task.mentionedUserIds.add(selected!.id);
                  if (taskProject != null) {
                    provider.updateTaskStatus(taskProject!.id, task.id, task.status);
                  }
                  Navigator.pop(ctx);
                }
              },
              child: const Text('멘션 추가'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool value;
  final String label;
  final Color color;
  const _Toggle({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: value ? color.withValues(alpha: 0.2) : AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value ? color : AppTheme.textMuted.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: value ? color : AppTheme.textMuted, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: value ? color : AppTheme.textMuted, fontSize: 10)),
      ]),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final AppUser user;
  final Color color;
  final String badge, badgeColor;
  const _MemberRow({required this.user, required this.color, required this.badge, required this.badgeColor});

  Color get _badgeColor {
    if (badgeColor == 'AppTheme.mintPrimary' || badge == '담당자') return AppTheme.mintPrimary;
    return AppTheme.info;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        CircleAvatar(radius: 14, backgroundColor: color.withValues(alpha: 0.3), child: Text(user.avatarInitials, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
          Text(user.email, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: _badgeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
          child: Text(badge, style: TextStyle(color: _badgeColor, fontSize: 10)),
        ),
      ]),
    );
  }
}

// ── Cost Tab ───────────────────────────────────────────
class _CostTab extends StatefulWidget {
  final TaskDetail task;
  final AppProvider provider;
  final Project? project;
  const _CostTab({required this.task, required this.provider, required this.project});

  @override
  State<_CostTab> createState() => _CostTabState();
}

class _CostTabState extends State<_CostTab> {
  // 집계 기준 통화 (KRW 또는 USD 등)
  CurrencyCode _baseCurrency = CurrencyCode.krw;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final provider = widget.provider;
    final project = widget.project;
    final fmt = NumberFormat('#,###');
    final budget = task.budget;
    final executed = task.executedAmountKrw;
    final total = task.totalBudgetKrw;
    final executionRate = task.costExecutionRate;

    // 다통화 집계
    final multiCurrSummary = _buildMultiCurrSummary(task.costEntries, provider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 좌측: 예산 현황 + 비용 내역 ───
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Row(children: [
                  const Text('비용 관리', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showSetBudgetDialog(context, provider, project, task),
                    icon: const Icon(Icons.account_balance_wallet_outlined, size: 14),
                    label: const Text('예산 설정', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: () => _showAddCostDialog(context, provider, project, task),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('비용 추가', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  ),
                ]),
                const SizedBox(height: 12),

                // 예산 현황 카드
                if (budget != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Text('예산 현황', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${budget.currency.symbol} ${budget.currency.code}',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        _CostStat(label: '총 예산', value: '${budget.currency.symbol}${fmt.format(budget.totalBudget)}', subValue: '₩${fmt.format(total)}', color: AppTheme.mintPrimary),
                        const SizedBox(width: 20),
                        _CostStat(label: '집행 완료', value: '₩${fmt.format(executed)}', subValue: '${executionRate.toStringAsFixed(0)}%', color: executionRate >= 90 ? AppTheme.error : AppTheme.success),
                        const SizedBox(width: 20),
                        _CostStat(label: '잔여', value: '₩${fmt.format(total - executed)}', subValue: '${(100 - executionRate).clamp(0, 100).toStringAsFixed(0)}%', color: AppTheme.info),
                      ]),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (executionRate / 100).clamp(0, 1),
                          backgroundColor: AppTheme.bgCardLight,
                          valueColor: AlwaysStoppedAnimation(executionRate >= 90 ? AppTheme.error : AppTheme.mintPrimary),
                          minHeight: 8,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ] else
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline, color: AppTheme.warning, size: 16),
                      const SizedBox(width: 8),
                      const Text('예산이 설정되지 않았습니다', style: TextStyle(color: AppTheme.warning, fontSize: 12)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _showSetBudgetDialog(context, provider, project, task),
                        child: const Text('설정하기', style: TextStyle(fontSize: 12)),
                      ),
                    ]),
                  ),

                // 비용 내역 목록
                const Text('비용 내역', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Expanded(
                  child: task.costEntries.isEmpty
                      ? const Center(child: Text('등록된 비용이 없습니다', style: TextStyle(color: AppTheme.textMuted)))
                      : ListView.separated(
                          itemCount: task.costEntries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (_, i) {
                            final cost = task.costEntries[i];
                            return _CostEntryTile(
                              cost: cost,
                              projectId: project?.id,
                              taskId: task.id,
                              provider: provider,
                              onToggle: project != null
                                  ? () => provider.toggleCostEntry(project.id, task.id, cost.id)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // ─── 우측: 다통화 집계 분석 패널 ───
          SizedBox(
            width: 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 집계 기준 통화 선택
                Row(children: [
                  const Text('집계 기준 통화', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard, borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.4)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<CurrencyCode>(
                        value: _baseCurrency,
                        dropdownColor: AppTheme.bgCard,
                        style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                        isDense: true,
                        items: [
                          CurrencyCode.krw, CurrencyCode.usd, CurrencyCode.eur,
                          CurrencyCode.jpy, CurrencyCode.cny, CurrencyCode.gbp,
                        ].map((c) => DropdownMenuItem(
                          value: c,
                          child: Text('${c.symbol} ${c.code}'),
                        )).toList(),
                        onChanged: (v) => setState(() => _baseCurrency = v!),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),

                // 다통화 종합 집계
                _MultiCurrencyPanel(
                  entries: task.costEntries,
                  baseCurrency: _baseCurrency,
                  provider: provider,
                  projectId: project?.id,
                ),
                const SizedBox(height: 14),

                // 통화별 분포
                const Text('통화별 분포', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                ...multiCurrSummary.entries.map((e) {
                  final pct = multiCurrSummary.values.fold(0.0, (s, v) => s + v) > 0
                      ? e.value / multiCurrSummary.values.fold(0.0, (s, v) => s + v)
                      : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(e.key, style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text('₩${NumberFormat('#,###').format(e.value)}',
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
                            overflow: TextOverflow.ellipsis)),
                        Text('${(pct * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                      ]),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: AppTheme.bgCardLight,
                          valueColor: const AlwaysStoppedAnimation(AppTheme.mintPrimary),
                          minHeight: 4,
                        ),
                      ),
                    ]),
                  );
                }),
                const SizedBox(height: 14),

                // 월별 비용
                const Text('월별 비용 현황', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                ..._buildMonthlyBreakdown(task.costEntries, NumberFormat('#,###')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 통화별 KRW 합계 맵 (프로젝트 경영환율 적용)
  Map<String, double> _buildMultiCurrSummary(List<CostEntry> entries, AppProvider provider) {
    final Map<String, double> map = {};
    final projectId = widget.project?.id;
    for (final e in entries) {
      final key = e.currency.code;
      map[key] = (map[key] ?? 0) + provider.getAmountInKrwForEntry(e, projectId);
    }
    // 내림차순 정렬
    final sorted = Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
    return sorted;
  }

  List<Widget> _buildMonthlyBreakdown(List<CostEntry> costs, NumberFormat fmt) {
    final Map<String, double> monthly = {};
    for (final c in costs) {
      final key = DateFormat('yyyy년 MM월').format(c.date);
      monthly[key] = (monthly[key] ?? 0) + c.amountInKrw;
    }
    if (monthly.isEmpty) return [const Text('비용 없음', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))];
    return monthly.entries.map((e) => Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Text(e.key, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const Spacer(),
        Text('₩${fmt.format(e.value)}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    )).toList();
  }

  void _showSetBudgetDialog(BuildContext context, AppProvider provider, Project? project, TaskDetail task) {
    if (project == null) return;
    final amountCtrl = TextEditingController(text: task.budget?.totalBudget.toStringAsFixed(0) ?? '');
    CurrencyCode currency = task.budget?.currency ?? CurrencyCode.krw;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('예산 설정', style: TextStyle(color: AppTheme.textPrimary)),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<CurrencyCode>(
                value: currency,
                dropdownColor: AppTheme.bgCard,
                decoration: const InputDecoration(labelText: '통화'),
                style: const TextStyle(color: AppTheme.textPrimary),
                items: CurrencyCode.values.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text('${c.symbol} ${c.code} - ${c.label.split("(").first.trim()}'),
                )).toList(),
                onChanged: (v) => setState(() => currency = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '금액',
                  prefixText: '${currency.symbol} ',
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text.replaceAll(',', ''));
                if (amount != null) {
                  provider.updateTaskBudget(project.id, task.id, BudgetConfig(
                    totalBudget: amount,
                    currency: currency,
                    exchangeRateToKrw: currency.rateToKrw,
                  ));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCostDialog(BuildContext context, AppProvider provider, Project? project, TaskDetail task) {
    if (project == null) return;
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final execRateCtrl = TextEditingController();
    final execRateNoteCtrl = TextEditingController();
    CurrencyCode currency = CurrencyCode.krw;
    String category = '광고비';
    DateTime date = DateTime.now();
    bool isExecuted = false;
    bool useCustomExecRate = false;
    final categories = ['광고비', '인건비', '외주', '툴/소프트웨어', '매체비', '이벤트/프로모션', '기타'];
    // 지역/고객 할당
    String? selectedRegion;
    String? selectedCountry;
    String? selectedClientId;
    String? selectedAssignedTo;
    bool showGeoSection = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('비용 추가', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: '비용 항목명 *'),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<CurrencyCode>(
                      value: currency,
                      dropdownColor: AppTheme.bgCard,
                      decoration: const InputDecoration(labelText: '집행 통화'),
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      items: CurrencyCode.values.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.symbol} ${c.code}'),
                      )).toList(),
                      onChanged: (v) {
                        setState(() {
                          currency = v!;
                          // KRW면 집행환율 불필요
                          if (currency == CurrencyCode.krw) useCustomExecRate = false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: amountCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '금액',
                        prefixText: '${currency.symbol} ',
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),

                // 집행환율 섹션 (KRW 아닌 경우)
                if (currency != CurrencyCode.krw) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCardLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1E3040)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.currency_exchange, color: AppTheme.textMuted, size: 14),
                        const SizedBox(width: 6),
                        const Text('집행환율 설정', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: useCustomExecRate,
                            onChanged: (v) => setState(() => useCustomExecRate = v),
                            activeColor: AppTheme.mintPrimary,
                          ),
                        ),
                      ]),
                      if (!useCustomExecRate) ...[
                        const SizedBox(height: 4),
                        Text(
                          '기준환율: ₩${NumberFormat("#,##0.####").format(provider.getRateToKrw(currency))} / ${currency.code}',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                        Text('(글로벌 기준환율 자동 적용)',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                      ] else ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: execRateCtrl,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: '집행환율 (₩/${currency.code})',
                                isDense: true,
                                hintText: '예: ${provider.getRateToKrw(currency).toStringAsFixed(2)}',
                                hintStyle: const TextStyle(color: AppTheme.textMuted),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: execRateNoteCtrl,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: '환율 메모',
                                isDense: true,
                                hintText: '예: 실거래환율',
                                hintStyle: TextStyle(color: AppTheme.textMuted),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Builder(builder: (ctx) {
                          final rate = double.tryParse(execRateCtrl.text.replaceAll(',', ''));
                          final amount = double.tryParse(amountCtrl.text.replaceAll(',', ''));
                          if (rate != null && amount != null) {
                            return Text(
                              '원화 환산: ₩${NumberFormat("#,###").format(amount * rate)}',
                              style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 11),
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 10),
                ],

                DropdownButtonFormField<String>(
                  value: category,
                  dropdownColor: AppTheme.bgCard,
                  decoration: const InputDecoration(labelText: '카테고리'),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => category = v!),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2030),
                      builder: (_, c) => Theme(data: ThemeData.dark(), child: c!),
                    );
                    if (d != null) setState(() => date = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined, color: AppTheme.textMuted, size: 16),
                      const SizedBox(width: 8),
                      Text(DateFormat('yyyy.MM.dd').format(date), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: '메모 (선택)'),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  dense: true,
                  title: const Text('집행 완료', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                  value: isExecuted,
                  activeColor: AppTheme.mintPrimary,
                  onChanged: (v) => setState(() => isExecuted = v),
                ),
                const SizedBox(height: 6),
                // ── 지역/고객 할당 섹션 ──────────────────────────
                InkWell(
                  onTap: () => setState(() => showGeoSection = !showGeoSection),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCardLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: showGeoSection
                            ? AppTheme.accentPurple.withValues(alpha: 0.5)
                            : AppTheme.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.public, size: 14,
                            color: showGeoSection ? AppTheme.accentPurple : AppTheme.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedRegion != null || selectedClientId != null
                                ? '${selectedRegion ?? ''}${selectedCountry != null ? ' · $selectedCountry' : ''}${selectedClientId != null ? ' · ${provider.clients.where((c) => c.id == selectedClientId).firstOrNull?.name ?? ''}' : ''}'
                                : '지역 / 고객 할당 (선택사항)',
                            style: TextStyle(
                              color: selectedRegion != null || selectedClientId != null
                                  ? AppTheme.textPrimary
                                  : AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Icon(
                          showGeoSection ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                          color: AppTheme.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                if (showGeoSection) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accentPurple.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 권역 선택
                        DropdownButtonFormField<String?>(
                          value: selectedRegion,
                          dropdownColor: AppTheme.bgCard,
                          decoration: const InputDecoration(
                            labelText: '마케팅 권역',
                            isDense: true,
                          ),
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('-- 선택 안 함 --')),
                            ...provider.regions.map((r) => DropdownMenuItem<String?>(
                              value: r.name,
                              child: Text('${r.icon} ${r.name}'),
                            )),
                          ],
                          onChanged: (v) => setState(() {
                            selectedRegion = v;
                            selectedCountry = null; // 권역 바뀌면 나라 초기화
                          }),
                        ),
                        const SizedBox(height: 8),
                        // 국가 선택 (권역 선택 시 해당 국가 목록)
                        Builder(builder: (_) {
                          final region = provider.regions
                              .where((r) => r.name == selectedRegion)
                              .firstOrNull;
                          final countries = region?.countries ?? [];
                          return DropdownButtonFormField<String?>(
                            value: selectedCountry,
                            dropdownColor: AppTheme.bgCard,
                            decoration: const InputDecoration(
                              labelText: '국가',
                              isDense: true,
                            ),
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('-- 선택 안 함 --')),
                              if (countries.isNotEmpty)
                                ...countries.map((c) => DropdownMenuItem<String?>(
                                  value: c,
                                  child: Text(c),
                                ))
                              else
                                ...['KR', 'US', 'VN', 'TH', 'AE', 'JP', 'CN', 'DE', 'FR', 'GB', 'SG', 'MY', 'ID']
                                    .map((c) => DropdownMenuItem<String?>(
                                        value: c, child: Text(c))),
                            ],
                            onChanged: (v) => setState(() => selectedCountry = v),
                          );
                        }),
                        const SizedBox(height: 8),
                        // 고객사 선택
                        DropdownButtonFormField<String?>(
                          value: selectedClientId,
                          dropdownColor: AppTheme.bgCard,
                          decoration: const InputDecoration(
                            labelText: '고객사',
                            isDense: true,
                          ),
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('-- 선택 안 함 --')),
                            ...provider.activeClients.map((c) => DropdownMenuItem<String?>(
                              value: c.id,
                              child: Text('${c.name}${c.country != null ? ' (${c.country})' : ''}'),
                            )),
                          ],
                          onChanged: (v) => setState(() {
                            selectedClientId = v;
                            // 고객사 선택 시 해당 region/country 자동 채우기
                            if (v != null) {
                              final client = provider.clients
                                  .where((c) => c.id == v)
                                  .firstOrNull;
                              if (client != null) {
                                if (client.region != null) selectedRegion = client.region;
                                if (client.country != null) selectedCountry = client.country;
                              }
                            }
                          }),
                        ),
                        const SizedBox(height: 8),
                        // 담당자 선택
                        DropdownButtonFormField<String?>(
                          value: selectedAssignedTo,
                          dropdownColor: AppTheme.bgCard,
                          decoration: const InputDecoration(
                            labelText: '담당자',
                            isDense: true,
                          ),
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('-- 선택 안 함 --')),
                            ...provider.allUsers.map((u) => DropdownMenuItem<String?>(
                              value: u.id,
                              child: Text(u.name),
                            )),
                          ],
                          onChanged: (v) => setState(() => selectedAssignedTo = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text.replaceAll(',', ''));
                if (titleCtrl.text.trim().isNotEmpty && amount != null) {
                  double? execRate;
                  if (useCustomExecRate && currency != CurrencyCode.krw) {
                    execRate = double.tryParse(execRateCtrl.text.replaceAll(',', ''));
                  }
                  provider.addCostEntry(project.id, task.id, CostEntry(
                    id: 'ce_${DateTime.now().millisecondsSinceEpoch}',
                    title: titleCtrl.text.trim(),
                    amount: amount,
                    currency: currency,
                    date: date,
                    category: category,
                    note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                    isExecuted: isExecuted,
                    executionRate: execRate,
                    executionRateNote: execRateNoteCtrl.text.trim().isEmpty ? null : execRateNoteCtrl.text.trim(),
                    region: selectedRegion,
                    country: selectedCountry,
                    clientId: selectedClientId,
                    assignedTo: selectedAssignedTo,
                  ));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 다통화 집계 패널 ─────────────────────────────────────────
class _MultiCurrencyPanel extends StatelessWidget {
  final List<CostEntry> entries;
  final CurrencyCode baseCurrency;
  final AppProvider provider;
  final String? projectId;

  const _MultiCurrencyPanel({
    required this.entries,
    required this.baseCurrency,
    required this.provider,
    this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    // 프로젝트 경영환율 적용 KRW 총합
    final totalKrw = entries.fold(0.0, (s, e) => s + provider.getAmountInKrwForEntry(e, projectId));
    final executedKrw = entries.where((e) => e.isExecuted)
        .fold(0.0, (s, e) => s + provider.getAmountInKrwForEntry(e, projectId));

    // 기준 통화로 환산
    final baseRate = provider.getRateToKrw(baseCurrency);
    final totalBase = baseRate > 0 ? totalKrw / baseRate : totalKrw;
    final executedBase = baseRate > 0 ? executedKrw / baseRate : executedKrw;

    // 집행환율 vs 경영환율 차이 분석
    final rateVarData = _analyzeRateVariance(entries, provider, projectId);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.analytics_outlined, color: AppTheme.mintPrimary, size: 14),
            const SizedBox(width: 6),
            Text('종합 집계 (${baseCurrency.code} 기준)',
                style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          _SummaryRow(
            label: '총 비용',
            value: '${baseCurrency.symbol}${fmt.format(totalBase)}',
            subValue: '₩${fmt.format(totalKrw)}',
            color: AppTheme.textPrimary,
          ),
          const SizedBox(height: 6),
          _SummaryRow(
            label: '집행 완료',
            value: '${baseCurrency.symbol}${fmt.format(executedBase)}',
            subValue: '₩${fmt.format(executedKrw)}',
            color: AppTheme.success,
          ),
          const SizedBox(height: 6),
          _SummaryRow(
            label: '미집행 (예정)',
            value: '${baseCurrency.symbol}${fmt.format(totalBase - executedBase)}',
            subValue: '₩${fmt.format(totalKrw - executedKrw)}',
            color: AppTheme.warning,
          ),

          // 집행환율 분석 (외화 항목 있을 때만)
          if (rateVarData.isNotEmpty) ...[
            const Divider(height: 16, color: Color(0xFF1E3040)),
            Row(children: [
              const Icon(Icons.swap_horiz, color: AppTheme.warning, size: 12),
              const SizedBox(width: 4),
              const Text('집행환율 분석', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            ...rateVarData.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(6),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard, borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(d['code']!, style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        d['title']!,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: d['isGain'] == 'true'
                            ? AppTheme.success.withValues(alpha: 0.15)
                            : AppTheme.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        d['diff']!,
                        style: TextStyle(
                          color: d['isGain'] == 'true' ? AppTheme.success : AppTheme.error,
                          fontSize: 9, fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    '집행: ₩${d["execRate"]!} | 기준: ₩${d["baseRate"]!}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
                  ),
                ]),
              ),
            )),
          ],
        ],
      ),
    );
  }

  List<Map<String, String>> _analyzeRateVariance(List<CostEntry> entries, AppProvider provider, String? projId) {
    final result = <Map<String, String>>[];
    final fmtRate = NumberFormat('#,##0.##');
    final fmtAmt = NumberFormat('#,###');

    for (final e in entries) {
      if (e.currency == CurrencyCode.krw) continue;
      if (e.executionRate == null) continue;

      final execRate = e.executionRate!;
      // 프로젝트 경영환율 우선 비교
      final baseRate = projId != null
          ? provider.getEffectiveRateForTask(projId, e.currency, e.date)
          : provider.getRateToKrw(e.currency);
      final diff = (execRate - baseRate) * e.amount;
      final isGain = diff <= 0; // 집행환율이 낮으면 원화 절약

      result.add({
        'code': e.currency.code,
        'title': e.title,
        'execRate': fmtRate.format(execRate),
        'baseRate': fmtRate.format(baseRate),
        'diff': '${isGain ? "절약" : "추가"} ₩${fmtAmt.format(diff.abs())}',
        'isGain': isGain.toString(),
      });
    }
    return result;
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value, subValue;
  final Color color;
  const _SummaryRow({required this.label, required this.value, required this.subValue, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        Text(subValue, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      ]),
    ]);
  }
}

class _CostStat extends StatelessWidget {
  final String label, value, subValue;
  final Color color;
  const _CostStat({required this.label, required this.value, required this.subValue, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
      Text(subValue, style: TextStyle(color: color, fontSize: 11)),
    ]);
  }
}

class _CostEntryTile extends StatelessWidget {
  final CostEntry cost;
  final String? projectId;
  final String? taskId;
  final AppProvider provider;
  final VoidCallback? onToggle;
  const _CostEntryTile({
    required this.cost,
    this.projectId,
    this.taskId,
    required this.provider,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final fmtRate = NumberFormat('#,##0.##');
    final hasCustomRate = cost.executionRate != null && cost.currency != CurrencyCode.krw;
    // 프로젝트 경영환율 우선, 없으면 글로벌 기준환율
    final baseRate = projectId != null
        ? provider.getEffectiveRateForTask(projectId!, cost.currency, cost.date)
        : provider.getRateToKrw(cost.currency);
    // 실효 원화 금액 (집행환율 → 경영환율 → 글로벌환율)
    final effectiveKrw = provider.getAmountInKrwForEntry(cost, projectId);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cost.isExecuted ? AppTheme.success.withValues(alpha: 0.3) : const Color(0xFF1E3040),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // 집행 토글
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: cost.isExecuted ? AppTheme.success : Colors.transparent,
                border: Border.all(
                  color: cost.isExecuted ? AppTheme.success : AppTheme.textMuted, width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: cost.isExecuted ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cost.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
            Row(children: [
              Text(cost.category, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              const SizedBox(width: 8),
              Text(DateFormat('MM.dd').format(cost.date), style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              if (cost.note != null) ...[
                const SizedBox(width: 8),
                Expanded(child: Text(cost.note!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10), overflow: TextOverflow.ellipsis)),
              ],
            ]),
          ])),
          // 금액
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${cost.currency.symbol}${fmt.format(cost.amount)}',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            if (cost.currency != CurrencyCode.krw)
              Text('₩${fmt.format(effectiveKrw)}',
                  style: TextStyle(
                    color: hasCustomRate ? AppTheme.warning : AppTheme.textMuted,
                    fontSize: 10,
                  )),
          ]),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cost.isExecuted
                  ? AppTheme.success.withValues(alpha: 0.15)
                  : AppTheme.textMuted.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              cost.isExecuted ? '완료' : '예정',
              style: TextStyle(
                color: cost.isExecuted ? AppTheme.success : AppTheme.textMuted,
                fontSize: 9,
              ),
            ),
          ),
        ]),
        // 집행환율 정보 (외화이고 집행 완료된 경우)
        if (cost.currency != CurrencyCode.krw && cost.isExecuted) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(5),
            ),
            child: Row(children: [
              const Icon(Icons.currency_exchange, size: 10, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              if (hasCustomRate) ...[
                Text(
                  '집행환율 ₩${fmtRate.format(cost.executionRate!)}',
                  style: const TextStyle(color: AppTheme.warning, fontSize: 10),
                ),
                const SizedBox(width: 8),
                Text(
                  '기준 ₩${fmtRate.format(baseRate)}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                ),
                const SizedBox(width: 6),
                // 환율 차이 표시
                Builder(builder: (_) {
                  final diff = (cost.executionRate! - baseRate) * cost.amount;
                  final isGain = diff <= 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isGain
                          ? AppTheme.success.withValues(alpha: 0.15)
                          : AppTheme.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '${isGain ? "절약" : "추가"} ₩${NumberFormat("#,###").format(diff.abs())}',
                      style: TextStyle(
                        color: isGain ? AppTheme.success : AppTheme.error,
                        fontSize: 9,
                      ),
                    ),
                  );
                }),
                if (cost.executionRateNote != null) ...[
                  const SizedBox(width: 6),
                  Text('(${cost.executionRateNote})', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                ],
              ] else ...[
                Text(
                  '경영환율 적용 ₩${fmtRate.format(baseRate)}',
                  style: TextStyle(
                    color: projectId != null ? AppTheme.info : AppTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
                if (projectId != null) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.info.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('경영', style: TextStyle(color: AppTheme.info, fontSize: 9)),
                  ),
                ],
              ],
            ]),
          ),
        ],
      ]),
    );
  }
}



// ── Info Tab ───────────────────────────────────────────
class _InfoTab extends StatelessWidget {
  final TaskDetail task;
  final AppProvider provider;
  final Project? project;
  const _InfoTab({required this.task, required this.provider, required this.project});

  @override
  Widget build(BuildContext context) {
    final dfmt = DateFormat('yyyy.MM.dd HH:mm');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('태스크 정보', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                _InfoField(label: '태스크 ID', value: task.id),
                _InfoField(label: '생성일', value: dfmt.format(task.createdAt)),
                _InfoField(label: '최종 수정', value: dfmt.format(task.updatedAt)),
                if (task.startDate != null) _InfoField(label: '시작일', value: DateFormat('yyyy.MM.dd').format(task.startDate!)),
                if (task.dueDate != null) _InfoField(label: '마감일', value: DateFormat('yyyy.MM.dd').format(task.dueDate!)),
                if (task.kpiId != null) _InfoField(label: '연관 KPI', value: task.kpiId!),
                // ── CSV 가져오기 확장 필드 ──────────────────
                if (task.externalId != null) _InfoField(label: '외부 ID', value: task.externalId!),
                if (task.year != null) _InfoField(label: '대상 연도', value: '${task.year}년'),
                if (task.target != null) _InfoField(
                  label: '목표값',
                  value: '${task.target!.toStringAsFixed(task.target!.truncateToDouble() == task.target! ? 0 : 1)}'
                      '${task.unit != null ? ' ${task.unit}' : ''}',
                ),
                if (task.theme != null) _InfoField(label: '테마', value: task.theme!),
                if (task.ownerName != null) _InfoField(label: '담당자명', value: task.ownerName!),
                const SizedBox(height: 16),
                const Text('태그', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: task.tags.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.3))),
                  child: Text('#$t', style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 12)),
                )).toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Task KPI Tracker Tab ──────────────────────────────
class _KpiTrackerTab extends StatefulWidget {
  final TaskDetail task;
  final AppProvider provider;
  final Project? project;
  const _KpiTrackerTab({required this.task, required this.provider, required this.project});

  @override
  State<_KpiTrackerTab> createState() => _KpiTrackerTabState();
}

class _KpiTrackerTabState extends State<_KpiTrackerTab> {
  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final provider = widget.provider;
    final project = widget.project;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('KPI 트래커', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _showAddKpiDialog(context, provider, project, task),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('KPI 추가', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            ),
          ]),
          const SizedBox(height: 6),
          const Text('이 태스크의 월별 KPI 목표와 실제 성과를 트래킹합니다.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          const SizedBox(height: 16),
          if (task.kpiTargets.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.flag_outlined, color: AppTheme.textMuted, size: 48),
                    const SizedBox(height: 12),
                    const Text('등록된 KPI 목표가 없습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showAddKpiDialog(context, provider, project, task),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('KPI 추가하기'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: task.kpiTargets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, i) {
                  final kpi = task.kpiTargets[i];
                  return _KpiTargetCard(
                    kpiTarget: kpi,
                    project: project,
                    task: task,
                    provider: provider,
                    onDelete: () {
                      if (project != null) provider.removeTaskKpiTarget(project.id, task.id, kpi.id);
                    },
                    onUpdateActual: (month, actual) {
                      if (project != null) provider.updateTaskKpiEntry(project.id, task.id, kpi.id, month, actual);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showAddKpiDialog(BuildContext context, AppProvider provider, Project? project, TaskDetail task) {
    if (project == null) return;
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: '원');
    StrategyPillar? pillar;
    final months = ['2025-01', '2025-02', '2025-03', '2025-04', '2025-05', '2025-06'];
    final labels = ['1월', '2월', '3월', '4월', '5월', '6월'];
    final targetCtrls = List.generate(months.length, (_) => TextEditingController(text: '0'));

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('KPI 목표 추가', style: TextStyle(color: AppTheme.textPrimary)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'KPI 이름 *', hintText: '예: 매출액, 전환율, 리드수'),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(
                    controller: unitCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(labelText: '단위', hintText: '원, %, 건, 명'),
                  )),
                ]),
                const SizedBox(height: 12),
                const Text('전략 Pillar', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: StrategyPillar.values.map((p) {
                    final col = Color(int.parse('0xFF${p.colorHex.substring(1)}'));
                    final isSelected = pillar == p;
                    return GestureDetector(
                      onTap: () => setState(() => pillar = isSelected ? null : p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected ? col.withValues(alpha: 0.2) : AppTheme.bgCardLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isSelected ? col : const Color(0xFF1E3040)),
                        ),
                        child: Text('${p.icon} ${p.label}', style: TextStyle(color: isSelected ? col : AppTheme.textMuted, fontSize: 11)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('월별 목표치', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...List.generate(months.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    SizedBox(width: 40, child: Text(labels[i], style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(
                      controller: targetCtrls[i],
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        suffixText: unitCtrl.text,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        filled: true,
                        fillColor: AppTheme.bgCardLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF1E3040))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF1E3040))),
                      ),
                    )),
                  ]),
                )),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                final monthlyTargets = List.generate(months.length, (i) => MonthlyKpiEntry(
                  month: months[i],
                  monthLabel: labels[i],
                  target: double.tryParse(targetCtrls[i].text) ?? 0,
                  actual: 0,
                ));
                provider.addTaskKpiTarget(project.id, task.id, TaskKpiTarget(
                  id: 'kpit_${DateTime.now().millisecondsSinceEpoch}',
                  taskId: task.id,
                  kpiName: nameCtrl.text.trim(),
                  unit: unitCtrl.text.trim().isEmpty ? '건' : unitCtrl.text.trim(),
                  pillar: pillar,
                  monthlyTargets: monthlyTargets,
                ));
                Navigator.pop(ctx);
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiTargetCard extends StatelessWidget {
  final TaskKpiTarget kpiTarget;
  final TaskDetail task;
  final Project? project;
  final AppProvider provider;
  final VoidCallback onDelete;
  final void Function(String month, double actual) onUpdateActual;

  const _KpiTargetCard({
    required this.kpiTarget,
    required this.task,
    required this.project,
    required this.provider,
    required this.onDelete,
    required this.onUpdateActual,
  });

  @override
  Widget build(BuildContext context) {
    final pillar = kpiTarget.pillar;
    final pillarColor = pillar != null
        ? Color(int.parse('0xFF${pillar.colorHex.substring(1)}'))
        : AppTheme.mintPrimary;

    final entries = kpiTarget.monthlyTargets;
    final totalTarget = entries.fold(0.0, (s, e) => s + e.target);
    final totalActual = entries.fold(0.0, (s, e) => s + e.actual);
    final overallRate = totalTarget > 0 ? (totalActual / totalTarget * 100).clamp(0, 200) : 0.0;
    final rateColor = overallRate >= 80 ? AppTheme.success : overallRate >= 60 ? AppTheme.warning : AppTheme.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pillarColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (pillar != null) ...
              [Text(pillar.icon, style: const TextStyle(fontSize: 16)), const SizedBox(width: 6)],
            Expanded(
              child: Text(kpiTarget.kpiName,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            if (pillar != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pillarColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(pillar.label, style: TextStyle(color: pillarColor, fontSize: 10)),
              ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: rateColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${overallRate.toStringAsFixed(0)}%', style: TextStyle(color: rateColor, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.textMuted),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ]),
          const SizedBox(height: 8),
          Text('단위: ${kpiTarget.unit} · 목표 합계: ${_fmt(totalTarget)}${kpiTarget.unit} · 실적 합계: ${_fmt(totalActual)}${kpiTarget.unit}',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          const SizedBox(height: 12),
          // Monthly table
          Container(
            decoration: BoxDecoration(
              color: AppTheme.bgCardLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCardLight,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    border: const Border(bottom: BorderSide(color: Color(0xFF1E3040))),
                  ),
                  child: Row(children: [
                    const SizedBox(width: 40, child: Text('월', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                    const Expanded(child: Text('목표', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                    const Expanded(child: Text('실적', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                    const Expanded(child: Text('달성률', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                    const SizedBox(width: 32),
                  ]),
                ),
                ...entries.map((entry) => _MonthlyEntryRow(
                  entry: entry,
                  unit: kpiTarget.unit,
                  onEditActual: (actual) => onUpdateActual(entry.month, actual),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}억';
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(0)}만';
    return NumberFormat('#,###').format(v);
  }
}

class _MonthlyEntryRow extends StatefulWidget {
  final MonthlyKpiEntry entry;
  final String unit;
  final void Function(double) onEditActual;
  const _MonthlyEntryRow({required this.entry, required this.unit, required this.onEditActual});

  @override
  State<_MonthlyEntryRow> createState() => _MonthlyEntryRowState();
}

class _MonthlyEntryRowState extends State<_MonthlyEntryRow> {
  bool _editing = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.entry.actual.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final rate = entry.achievementRate;
    final rateColor = rate >= 80 ? AppTheme.success : rate >= 60 ? AppTheme.warning : AppTheme.error;
    final gap = entry.gap;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1A2E3E), width: 0.5)),
      ),
      child: Row(children: [
        SizedBox(width: 40, child: Text(entry.monthLabel, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
        Expanded(child: Text(
          '${NumberFormat('#,###').format(entry.target)}${widget.unit}',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          textAlign: TextAlign.right,
        )),
        Expanded(
          child: _editing
              ? TextField(
                  controller: _ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    suffixText: widget.unit,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    filled: true, fillColor: AppTheme.bgCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppTheme.mintPrimary)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppTheme.mintPrimary)),
                  ),
                  onSubmitted: (v) {
                    final val = double.tryParse(v) ?? entry.actual;
                    widget.onEditActual(val);
                    setState(() => _editing = false);
                  },
                )
              : GestureDetector(
                  onTap: () => setState(() { _editing = true; _ctrl.text = entry.actual.toStringAsFixed(0); }),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(
                      '${NumberFormat('#,###').format(entry.actual)}${widget.unit}',
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.edit, size: 10, color: AppTheme.textMuted),
                  ]),
                ),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${rate.toStringAsFixed(0)}%', style: TextStyle(color: rateColor, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right),
            Text(
              '${gap >= 0 ? '+' : ''}${NumberFormat('#,###').format(gap)}',
              style: TextStyle(color: gap >= 0 ? AppTheme.success : AppTheme.error, fontSize: 9),
              textAlign: TextAlign.right,
            ),
          ]),
        ),
        SizedBox(
          width: 32,
          child: _editing
              ? IconButton(
                  onPressed: () {
                    final val = double.tryParse(_ctrl.text) ?? entry.actual;
                    widget.onEditActual(val);
                    setState(() => _editing = false);
                  },
                  icon: const Icon(Icons.check, size: 14, color: AppTheme.success),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                )
              : null,
        ),
      ]),
    );
  }
}

// ── Comment Tab ────────────────────────────────────────
class _CommentTab extends StatefulWidget {
  final TaskDetail task;
  final AppProvider provider;
  final Project? project;
  const _CommentTab({required this.task, required this.provider, required this.project});

  @override
  State<_CommentTab> createState() => _CommentTabState();
}

class _CommentTabState extends State<_CommentTab> {
  final _ctrl = TextEditingController();
  final List<String> _selectedMentions = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final provider = widget.provider;
    final project = widget.project;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('코멘트', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text('(${task.comments.length})', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ]),
          const SizedBox(height: 16),
          // Comment list
          Expanded(
            child: task.comments.isEmpty
                ? const Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.chat_bubble_outline, color: AppTheme.textMuted, size: 40),
                      SizedBox(height: 8),
                      Text('아직 코멘트가 없습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    ]),
                  )
                : ListView.separated(
                    itemCount: task.comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = task.comments[i];
                      final author = provider.getUserById(c.authorId);
                      final avatarColor = author?.avatarColor != null
                          ? Color(int.parse('0xFF${author!.avatarColor!.substring(1)}'))
                          : AppTheme.mintPrimary;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1E3040)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: avatarColor.withValues(alpha: 0.2),
                              child: Text(author?.avatarInitials ?? '?', style: TextStyle(color: avatarColor, fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(author?.displayName ?? '사용자', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                              Text('${author?.jobTitle.label ?? ''} · ${_timeAgo(c.createdAt)}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                            ])),
                            // DM button for the author
                            if (author != null && author.id != provider.currentUser.id)
                              IconButton(
                                onPressed: () => provider.openDm(author.id),
                                icon: const Icon(Icons.mail_outline, size: 14, color: AppTheme.textMuted),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                tooltip: 'DM 보내기',
                              ),
                          ]),
                          const SizedBox(height: 8),
                          _buildCommentContent(c.content, provider),
                          if (c.mentionedUserIds.isNotEmpty) ...
                            [const SizedBox(height: 6),
                            Wrap(spacing: 6, children: c.mentionedUserIds.map((uid) {
                              final u = provider.getUserById(uid);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppTheme.mintPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text('@${u?.displayName ?? uid}', style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 10)),
                              );
                            }).toList())],
                        ]),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          // Mention selector
          if (_selectedMentions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(8)),
              child: Wrap(spacing: 6, children: [
                const Text('@멘션: ', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ..._selectedMentions.map((uid) {
                  final u = provider.getUserById(uid);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMentions.remove(uid)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.mintPrimary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('@${u?.displayName ?? uid}', style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 11)),
                        const SizedBox(width: 4),
                        const Icon(Icons.close, size: 10, color: AppTheme.mintPrimary),
                      ]),
                    ),
                  );
                }),
              ]),
            ),
          // Input area
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLines: 3, minLines: 1,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: '코멘트를 입력하세요... (@멘션 버튼으로 담당자를 멘션할 수 있습니다)',
                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  filled: true, fillColor: AppTheme.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E3040))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E3040))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.mintPrimary)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(children: [
              // Mention button
              IconButton(
                onPressed: () => _showMentionPicker(context, provider, task),
                icon: const Icon(Icons.alternate_email, color: AppTheme.textMuted, size: 18),
                tooltip: '@멘션',
                style: IconButton.styleFrom(backgroundColor: AppTheme.bgCard),
              ),
              const SizedBox(height: 4),
              // Send button
              ElevatedButton(
                onPressed: () => _sendComment(provider, project, task),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mintPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  minimumSize: const Size(44, 44),
                ),
                child: const Icon(Icons.send, size: 16, color: Colors.white),
              ),
            ]),
          ]),
        ],
      ),
    );
  }

  Widget _buildCommentContent(String content, AppProvider provider) {
    // Parse @mentions
    final parts = content.split(RegExp(r'(@\S+)'));
    if (parts.length <= 1) {
      return Text(content, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5));
    }
    return RichText(
      text: TextSpan(
        children: content.split(' ').map((word) {
          if (word.startsWith('@')) {
            return TextSpan(
              text: '$word ',
              style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            );
          }
          return TextSpan(
            text: '$word ',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          );
        }).toList(),
      ),
    );
  }

  void _showMentionPicker(BuildContext context, AppProvider provider, TaskDetail task) {
    final users = provider.allUsers.where((u) => u.id != provider.currentUser.id).toList();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('@멘션할 사용자 선택', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: users.map((u) {
              final col = u.avatarColor != null ? Color(int.parse('0xFF${u.avatarColor!.substring(1)}')) : AppTheme.mintPrimary;
              final isSelected = _selectedMentions.contains(u.id);
              return ListTile(
                dense: true,
                onTap: () {
                  setState(() {
                    if (isSelected) _selectedMentions.remove(u.id);
                    else _selectedMentions.add(u.id);
                  });
                  Navigator.pop(context);
                },
                leading: CircleAvatar(
                  radius: 14, backgroundColor: col.withValues(alpha: 0.2),
                  child: Text(u.avatarInitials, style: TextStyle(color: col, fontSize: 10)),
                ),
                title: Text(u.displayName, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                subtitle: Text('${u.jobTitle.label} · ${u.department ?? ''}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                trailing: isSelected ? const Icon(Icons.check, color: AppTheme.mintPrimary, size: 16) : null,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _sendComment(AppProvider provider, Project? project, TaskDetail task) {
    final text = _ctrl.text.trim();
    if (text.isEmpty || project == null) return;
    provider.addTaskComment(project.id, task.id, text, List.from(_selectedMentions));
    _ctrl.clear();
    setState(() => _selectedMentions.clear());
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

class _InfoField extends StatelessWidget {
  final String label, value;
  const _InfoField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
        Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
      ]),
    );
  }
}

// ── Unused import fix ─────────────────────────────────
String _fmtNum(double v) {
  if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}억';
  if (v >= 10000) return '${(v / 10000).toStringAsFixed(0)}만';
  return v.toStringAsFixed(0);
}

class _PillBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _PillBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}

class _QuickInfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _QuickInfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: AppTheme.textMuted, size: 14),
      const SizedBox(width: 4),
      Text('$label: ', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      Text(value, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
    ]);
  }
}
