// ════════════════════════════════════════════════════════════════
//  Universal Edit Dialog
//  태스크 / 프로젝트 / KPI / 캠페인 인라인 편집 다이얼로그
// ════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

// ────────────────────────────────────────────────────────────────
//  태스크 편집 다이얼로그
// ────────────────────────────────────────────────────────────────
class TaskEditDialog extends StatefulWidget {
  final TaskDetail task;
  final Project project;
  final AppProvider provider;
  const TaskEditDialog({super.key, required this.task, required this.project, required this.provider});

  @override State<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<TaskEditDialog> with SingleTickerProviderStateMixin {
  late TabController _tab;
  late TextEditingController _titleCtrl, _descCtrl, _tagCtrl;
  late TextEditingController _budgetCtrl, _regionCtrl, _countryCtrl;
  late TaskStatus _status;
  late TaskPriority _priority;
  late StrategyPillar? _pillar;
  DateTime? _startDate, _dueDate;
  late List<String> _assigneeIds;
  late List<String> _tags;
  String? _kpiId;
  // 고객사·지역·예산
  String? _clientId;
  CurrencyCode _budgetCurrency = CurrencyCode.krw;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    final t = widget.task;
    _titleCtrl   = TextEditingController(text: t.title);
    _descCtrl    = TextEditingController(text: t.description);
    _tagCtrl     = TextEditingController();
    _regionCtrl  = TextEditingController(text: t.defaultRegion ?? '');
    _countryCtrl = TextEditingController(text: t.defaultCountry ?? '');
    _budgetCtrl  = TextEditingController(
      text: t.taskAllocatedBudget != null ? t.taskAllocatedBudget!.toStringAsFixed(0) : '');
    _status    = t.status;
    _priority  = t.priority;
    _pillar    = t.pillar;
    _startDate = t.startDate;
    _dueDate   = t.dueDate;
    _assigneeIds = List<String>.from(t.assigneeIds);
    _tags      = List<String>.from(t.tags);
    _kpiId     = t.kpiId;
    _clientId  = t.defaultClientId;
    _budgetCurrency = t.taskBudgetCurrency ?? CurrencyCode.krw;
  }

  @override void dispose() {
    _tab.dispose(); _titleCtrl.dispose(); _descCtrl.dispose(); _tagCtrl.dispose();
    _budgetCtrl.dispose(); _regionCtrl.dispose(); _countryCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.provider.updateTask(
      widget.project.id, widget.task.id,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      status: _status, priority: _priority,
      pillar: _pillar, kpiId: _kpiId,
      startDate: _startDate, dueDate: _dueDate,
      assigneeIds: _assigneeIds, tags: _tags,
    );
    widget.provider.updateTaskClientBudget(
      widget.project.id, widget.task.id,
      defaultClientId: _clientId,
      defaultRegion: _regionCtrl.text.trim().isEmpty ? null : _regionCtrl.text.trim(),
      defaultCountry: _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim(),
      taskAllocatedBudget: double.tryParse(_budgetCtrl.text),
      taskBudgetCurrency: _budgetCurrency,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Column(children: [
          _header('태스크 편집', Icons.task_alt_rounded, AppTheme.mintPrimary),
          TabBar(
            controller: _tab,
            labelColor: AppTheme.mintPrimary,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.mintPrimary,
            tabs: const [Tab(text: '기본 정보'), Tab(text: '담당자 & 태그'), Tab(text: '전략 연결'), Tab(text: '고객사 & 예산')],
          ),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(child: TabBarView(controller: _tab, children: [
            // ── 탭 1: 기본 정보 ──────────────────────────────
            _scrollPad(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _field('제목 *', _titleCtrl),
              const SizedBox(height: 12),
              _field('설명', _descCtrl, maxLines: 3),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _dropdownSection<TaskStatus>('상태', TaskStatus.values, _status,
                  _statusLabel, (v) => setState(() => _status = v!))),
                const SizedBox(width: 12),
                Expanded(child: _dropdownSection<TaskPriority>('우선순위', TaskPriority.values, _priority,
                  _priorityLabel, (v) => setState(() => _priority = v!))),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _datePicker('시작일', _startDate,
                  (d) => setState(() => _startDate = d))),
                const SizedBox(width: 12),
                Expanded(child: _datePicker('마감일', _dueDate,
                  (d) => setState(() => _dueDate = d))),
              ]),
            ])),

            // ── 탭 2: 담당자 & 태그 ──────────────────────────
            _scrollPad(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('담당자', style: _labelStyle),
              const SizedBox(height: 8),
              _AssigneeSelector(
                allUsers: widget.provider.allUsers,
                selectedIds: _assigneeIds,
                onChanged: (ids) => setState(() => _assigneeIds = ids),
              ),
              const SizedBox(height: 20),
              const Text('태그', style: _labelStyle),
              const SizedBox(height: 8),
              _TagEditor(
                tags: _tags,
                controller: _tagCtrl,
                onAdd: (t) { if (t.isNotEmpty) setState(() { _tags.add(t); _tagCtrl.clear(); }); },
                onRemove: (t) => setState(() => _tags.remove(t)),
              ),
            ])),

            // ── 탭 3: 전략 연결 ──────────────────────────────
            _scrollPad(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('전략 Pillar', style: _labelStyle),
              const SizedBox(height: 8),
              _PillarSelector(
                selected: _pillar,
                onChanged: (p) => setState(() => _pillar = p),
              ),
              const SizedBox(height: 20),
              const Text('연결 KPI', style: _labelStyle),
              const SizedBox(height: 8),
              _KpiSelector(
                kpis: widget.provider.kpis,
                selectedId: _kpiId,
                onChanged: (id) => setState(() => _kpiId = id),
              ),
            ])),

            // ── 탭 4: 고객사 & 예산 ──────────────────────────
            _scrollPad(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 안내 배너
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.25)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: AppTheme.accentBlue, size: 14),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    '태스크 기본 고객사·지역을 설정하면 체크리스트 항목에 자동으로 적용됩니다.',
                    style: TextStyle(color: AppTheme.accentBlue, fontSize: 11),
                  )),
                ]),
              ),
              const SizedBox(height: 16),
              // 고객사 선택
              const Text('기본 고객사', style: _labelStyle),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _clientId,
                decoration: InputDecoration(
                  isDense: true, hintText: '고객사를 선택하세요',
                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true, fillColor: AppTheme.bgCardLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.border)),
                ),
                dropdownColor: AppTheme.bgCard,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                items: [
                  const DropdownMenuItem<String>(value: null,
                      child: Text('없음', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                  ...widget.provider.clients.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Row(children: [
                      const Icon(Icons.business_rounded, size: 14, color: AppTheme.accentBlue),
                      const SizedBox(width: 6),
                      Expanded(child: Text(c.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                      if (c.country != null) Text(' (${c.country})',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ]),
                  )),
                ],
                onChanged: (v) {
                  setState(() {
                    _clientId = v;
                    if (v != null) {
                      final c = widget.provider.clients.firstWhere((c) => c.id == v);
                      if ((c.region ?? '').isNotEmpty) _regionCtrl.text = c.region!;
                      if ((c.country ?? '').isNotEmpty) _countryCtrl.text = c.country!;
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _field('권역', _regionCtrl, hint: '예: 동남아, 중동, 북미')),
                const SizedBox(width: 12),
                Expanded(child: _field('국가', _countryCtrl, hint: '예: KR, SG, AE')),
              ]),
              const SizedBox(height: 14),
              // 태스크 전체 할당 예산
              const Text('태스크 할당 예산', style: _labelStyle),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(flex: 3, child: _field('예산 금액', _budgetCtrl,
                    keyboardType: TextInputType.number, hint: '예: 5000000')),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: _dropdownSection<CurrencyCode>(
                  '통화', CurrencyCode.values, _budgetCurrency,
                  (c) => c.code,
                  (v) => setState(() => _budgetCurrency = v!),
                )),
              ]),
              // 현재 예산 요약
              if (widget.task.taskAllocatedBudget != null || widget.task.checklistTotalAllocated > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(children: [
                    _BudgetSummaryRow('태스크 할당 예산',
                        widget.task.taskAllocatedBudget != null
                          ? '${_fmtNum(widget.task.taskAllocatedBudget!)}${(widget.task.taskBudgetCurrency ?? CurrencyCode.krw).code}'
                          : '-',
                        AppTheme.accentBlue),
                    const SizedBox(height: 6),
                    _BudgetSummaryRow('체크리스트 총 할당',
                        '${_fmtNum(widget.task.checklistTotalAllocated)}원',
                        AppTheme.mintPrimary),
                    const SizedBox(height: 6),
                    _BudgetSummaryRow('체크리스트 총 집행',
                        '${_fmtNum(widget.task.checklistTotalExecuted)}원',
                        AppTheme.accentOrange),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (widget.task.checklistBudgetUsageRate / 100).clamp(0.0, 1.0),
                        backgroundColor: AppTheme.bgCardLight,
                        valueColor: AlwaysStoppedAnimation(
                          widget.task.checklistBudgetUsageRate > 90
                            ? AppTheme.accentRed : AppTheme.mintPrimary),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('집행률 ${widget.task.checklistBudgetUsageRate.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: widget.task.checklistBudgetUsageRate > 90
                            ? AppTheme.accentRed : AppTheme.textMuted,
                          fontSize: 10,
                        )),
                  ]),
                ),
              ],
            ])),
          ])),
          _footer(_save),
        ]),
      ),
    );
  }

  static const _labelStyle = TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600);

  static String _statusLabel(TaskStatus s) {
    switch (s) {
      case TaskStatus.todo: return '할 일';
      case TaskStatus.inProgress: return '진행 중';
      case TaskStatus.inReview: return '검토 중';
      case TaskStatus.done: return '완료';
    }
  }
  static String _priorityLabel(TaskPriority p) {
    switch (p) {
      case TaskPriority.low: return '낮음';
      case TaskPriority.medium: return '보통';
      case TaskPriority.high: return '높음';
      case TaskPriority.urgent: return '긴급';
    }
  }
}

// ────────────────────────────────────────────────────────────────
//  프로젝트 편집 다이얼로그
// ────────────────────────────────────────────────────────────────
class ProjectEditDialog extends StatefulWidget {
  final Project project;
  final AppProvider provider;
  const ProjectEditDialog({super.key, required this.project, required this.provider});

  @override State<ProjectEditDialog> createState() => _ProjectEditDialogState();
}

class _ProjectEditDialogState extends State<ProjectEditDialog> {
  late TextEditingController _nameCtrl, _descCtrl, _catCtrl;
  late ProjectStatus _status;
  late String _colorHex, _icon;
  late List<String> _memberIds;
  DateTime? _dueDate;

  static const _colors = [
    '#00BFA5','#29B6F6','#AB47BC','#FF6D00','#EF5350',
    '#4CAF50','#FFC107','#607D8B','#E91E63','#3F51B5',
  ];
  static const _icons = ['📊','📈','🚀','🎯','💡','🔥','⚡','🌟','💎','🤝','🌐','🏆'];

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _nameCtrl = TextEditingController(text: p.name);
    _descCtrl = TextEditingController(text: p.description);
    _catCtrl  = TextEditingController(text: p.category);
    _status   = p.status;
    _colorHex = p.colorHex;
    _icon     = p.iconEmoji;
    _memberIds = List<String>.from(p.memberIds);
    _dueDate  = p.dueDate;
  }

  @override void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); _catCtrl.dispose(); super.dispose(); }

  void _save() {
    widget.provider.updateProject(
      widget.project.id,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: _catCtrl.text.trim(),
      status: _status, colorHex: _colorHex, iconEmoji: _icon,
      dueDate: _dueDate, memberIds: _memberIds,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(children: [
          _header('프로젝트 편집', Icons.folder_rounded, AppTheme.accentBlue),
          Expanded(child: _scrollPad(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 아이콘 + 색상 선택
            Row(children: [
              // 이모지 선택
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('아이콘', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: _icons.map((e) => GestureDetector(
                  onTap: () => setState(() => _icon = e),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _icon == e ? AppTheme.accentBlue.withValues(alpha: 0.15) : AppTheme.bgCardLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _icon == e ? AppTheme.accentBlue : AppTheme.border),
                    ),
                    child: Center(child: Text(e, style: const TextStyle(fontSize: 18))),
                  ),
                )).toList()),
              ]),
              const SizedBox(width: 20),
              // 색상 선택
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('색상', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: _colors.map((c) {
                  final color = Color(int.parse('0xFF${c.substring(1)}'));
                  return GestureDetector(
                    onTap: () => setState(() => _colorHex = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _colorHex == c ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: _colorHex == c ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)] : null,
                      ),
                    ),
                  );
                }).toList()),
              ]),
            ]),
            const SizedBox(height: 16),
            _field('프로젝트명 *', _nameCtrl),
            const SizedBox(height: 12),
            _field('설명', _descCtrl, maxLines: 2),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field('분류/카테고리', _catCtrl, hint: '예: 브랜딩, 퍼포먼스, 리텐션')),
              const SizedBox(width: 12),
              Expanded(child: _dropdownSection<ProjectStatus>('상태', ProjectStatus.values, _status,
                _projectStatusLabel, (v) => setState(() => _status = v!))),
            ]),
            const SizedBox(height: 12),
            _datePicker('마감일', _dueDate, (d) => setState(() => _dueDate = d)),
            const SizedBox(height: 20),
            const Text('멤버', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _AssigneeSelector(
              allUsers: widget.provider.allUsers,
              selectedIds: _memberIds,
              onChanged: (ids) => setState(() => _memberIds = ids),
            ),
          ]))),
          _footer(_save),
        ]),
      ),
    );
  }

  static String _projectStatusLabel(ProjectStatus s) {
    switch (s) {
      case ProjectStatus.active:    return '진행 중';
      case ProjectStatus.paused:    return '보류';
      case ProjectStatus.completed: return '완료';
      case ProjectStatus.archived:  return '아카이브';
    }
  }
}

// ────────────────────────────────────────────────────────────────
//  KPI 편집 다이얼로그
// ────────────────────────────────────────────────────────────────
class KpiEditDialog extends StatefulWidget {
  final KpiModel kpi;
  final AppProvider provider;
  const KpiEditDialog({super.key, required this.kpi, required this.provider});

  @override State<KpiEditDialog> createState() => _KpiEditDialogState();
}

class _KpiEditDialogState extends State<KpiEditDialog> {
  late TextEditingController _titleCtrl, _catCtrl, _unitCtrl, _targetCtrl, _currentCtrl, _descCtrl;
  late StrategyPillar? _pillar;

  @override
  void initState() {
    super.initState();
    final k = widget.kpi;
    _titleCtrl   = TextEditingController(text: k.title);
    _catCtrl     = TextEditingController(text: k.category);
    _unitCtrl    = TextEditingController(text: k.unit);
    _targetCtrl  = TextEditingController(text: k.target.toString());
    _currentCtrl = TextEditingController(text: k.current.toString());
    _descCtrl    = TextEditingController(text: k.pillarDescription ?? '');
    _pillar      = k.pillar;
  }

  @override void dispose() {
    _titleCtrl.dispose(); _catCtrl.dispose(); _unitCtrl.dispose();
    _targetCtrl.dispose(); _currentCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.provider.updateKpiFull(widget.kpi.id,
      title: _titleCtrl.text.trim(),
      category: _catCtrl.text.trim(),
      unit: _unitCtrl.text.trim(),
      target: double.tryParse(_targetCtrl.text) ?? widget.kpi.target,
      current: double.tryParse(_currentCtrl.text) ?? widget.kpi.current,
      pillar: _pillar,
      pillarDescription: _descCtrl.text.trim(),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(children: [
          _header('KPI 편집', Icons.track_changes_rounded, AppTheme.accentGreen),
          Expanded(child: _scrollPad(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _field('KPI 제목 *', _titleCtrl),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field('분류', _catCtrl, hint: '예: 리드창출, 매출, 브랜드인지')),
              const SizedBox(width: 12),
              Expanded(child: _field('단위', _unitCtrl, hint: '예: 건, %, 원, 명')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field('목표값', _targetCtrl, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _field('현재값', _currentCtrl, keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 16),
            const Text('전략 Pillar', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _PillarSelector(selected: _pillar, onChanged: (p) => setState(() => _pillar = p)),
            const SizedBox(height: 12),
            _field('Pillar 설명 (선택)', _descCtrl, maxLines: 2),
          ]))),
          _footer(_save),
        ]),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//  캠페인 편집 다이얼로그
// ────────────────────────────────────────────────────────────────
class CampaignEditDialog extends StatefulWidget {
  final CampaignModel campaign;
  final AppProvider provider;
  const CampaignEditDialog({super.key, required this.campaign, required this.provider});

  @override State<CampaignEditDialog> createState() => _CampaignEditDialogState();
}

class _CampaignEditDialogState extends State<CampaignEditDialog> {
  late TextEditingController _nameCtrl, _budgetCtrl, _revenueCtrl;
  late String _type, _status, _channel;

  static const _types = ['매출 독려','브랜드 인지','리드 창출','리텐션','신규 고객','퍼포먼스','콘텐츠'];
  static const _statuses = ['계획', '진행중', '완료', '일시중지', '취소'];
  static const _channels = ['소셜미디어', '이메일', 'SEO', 'SEM', '오프라인', '유튜브', '인플루언서', '디스플레이'];

  @override
  void initState() {
    super.initState();
    final c = widget.campaign;
    _nameCtrl    = TextEditingController(text: c.name);
    _budgetCtrl  = TextEditingController(text: c.budget.toStringAsFixed(0));
    _revenueCtrl = TextEditingController(text: c.revenue.toStringAsFixed(0));
    _type   = _types.contains(c.type) ? c.type : _types.first;
    _status = _statuses.contains(c.status) ? c.status : _statuses.first;
    _channel = _channels.contains(c.channel) ? c.channel : _channels.first;
  }

  @override void dispose() { _nameCtrl.dispose(); _budgetCtrl.dispose(); _revenueCtrl.dispose(); super.dispose(); }

  void _save() {
    widget.provider.updateCampaignField(widget.campaign.id,
      name: _nameCtrl.text.trim(),
      type: _type, status: _status, channel: _channel,
      budget: double.tryParse(_budgetCtrl.text) ?? widget.campaign.budget,
      revenue: double.tryParse(_revenueCtrl.text) ?? widget.campaign.revenue,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 580),
        child: Column(children: [
          _header('캠페인 편집', Icons.campaign_rounded, AppTheme.accentOrange),
          Expanded(child: _scrollPad(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _field('캠페인명 *', _nameCtrl),
            const SizedBox(height: 16),
            const Text('캠페인 분류', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: _types.map((t) => _chip(t, _type == t,
              () => setState(() => _type = t), AppTheme.accentOrange)).toList()),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('상태', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: _statuses.map((s) => _chip(s, _status == s,
                  () => setState(() => _status = s), AppTheme.accentBlue)).toList()),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('채널', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: _channels.map((ch) => _chip(ch, _channel == ch,
                  () => setState(() => _channel = ch), AppTheme.mintPrimary)).toList()),
              ])),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _field('예산 (원)', _budgetCtrl, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _field('매출 (원)', _revenueCtrl, keyboardType: TextInputType.number)),
            ]),
          ]))),
          _footer(_save),
        ]),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, Color color) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.15) : AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: selected ? color : AppTheme.border, width: selected ? 1.5 : 1),
      ),
      child: Text(label, style: TextStyle(
        color: selected ? color : AppTheme.textMuted,
        fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      )),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
//  공통 헬퍼 위젯들
// ════════════════════════════════════════════════════════════════

Widget _header(String title, IconData icon, Color color) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
  child: Row(children: [
    Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 18),
    ),
    const SizedBox(width: 10),
    Expanded(child: Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700))),
  ]),
);

Widget _footer(VoidCallback onSave) => Column(children: [
  const Divider(height: 1, color: AppTheme.border),
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: Row(children: [
      const Spacer(),
      Builder(builder: (ctx) => TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('취소', style: TextStyle(color: AppTheme.textMuted)),
      )),
      const SizedBox(width: 8),
      ElevatedButton.icon(
        icon: const Icon(Icons.save_rounded, size: 14),
        label: const Text('저장'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.mintPrimary, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onSave,
      ),
    ]),
  ),
]);

Widget _scrollPad(Widget child) => SingleChildScrollView(
  padding: const EdgeInsets.all(20), child: child,
);

Widget _field(String label, TextEditingController ctrl, {
  int maxLines = 1, String? hint, TextInputType? keyboardType,
}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
  const SizedBox(height: 5),
  TextField(
    controller: ctrl, maxLines: maxLines, keyboardType: keyboardType,
    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
    decoration: InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true, fillColor: AppTheme.bgCardLight,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.border)),
    ),
  ),
]);

Widget _datePicker(String label, DateTime? value, void Function(DateTime?) onChanged) => Builder(
  builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
    const SizedBox(height: 5),
    InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: ctx,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020), lastDate: DateTime(2030),
          builder: (c, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: AppTheme.mintPrimary),
            ),
            child: child!,
          ),
        );
        onChanged(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.bgCardLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, color: AppTheme.textMuted, size: 14),
          const SizedBox(width: 8),
          Text(
            value != null ? DateFormat('yyyy.MM.dd').format(value) : '날짜 선택',
            style: TextStyle(
              color: value != null ? AppTheme.textPrimary : AppTheme.textMuted,
              fontSize: 13,
            ),
          ),
          if (value != null) ...[
            const Spacer(),
            GestureDetector(
              onTap: () => onChanged(null),
              child: const Icon(Icons.clear, color: AppTheme.textMuted, size: 14),
            ),
          ],
        ]),
      ),
    ),
  ]),
);

Widget _dropdownSection<T>(String label, List<T> values, T selected,
    String Function(T) labelFn, void Function(T?) onChanged) =>
  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
    const SizedBox(height: 5),
    DropdownButtonFormField<T>(
      value: selected,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true, fillColor: AppTheme.bgCardLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.border)),
      ),
      dropdownColor: AppTheme.bgCard,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      items: values.map((v) => DropdownMenuItem(value: v, child: Text(labelFn(v)))).toList(),
      onChanged: onChanged,
    ),
  ]);

// ── 담당자 선택기 ──────────────────────────────────────────────
class _AssigneeSelector extends StatelessWidget {
  final List<AppUser> allUsers;
  final List<String> selectedIds;
  final void Function(List<String>) onChanged;
  const _AssigneeSelector({required this.allUsers, required this.selectedIds, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      ...allUsers.map((u) {
        final selected = selectedIds.contains(u.id);
        final color = (u.avatarColor != null && u.avatarColor!.isNotEmpty)
          ? Color(int.parse('0xFF${u.avatarColor!.substring(1)}'))
          : AppTheme.mintPrimary;
        return GestureDetector(
          onTap: () {
            final updated = List<String>.from(selectedIds);
            if (selected) updated.remove(u.id); else updated.add(u.id);
            onChanged(updated);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.15) : AppTheme.bgCardLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? color : AppTheme.border, width: selected ? 1.5 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(radius: 10, backgroundColor: color,
                  child: Text(u.avatarInitials.substring(0, 1),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
              const SizedBox(width: 5),
              Text(u.name, style: TextStyle(
                color: selected ? color : AppTheme.textSecondary,
                fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              )),
              if (selected) ...[const SizedBox(width: 4), Icon(Icons.check_circle, color: color, size: 12)],
            ]),
          ),
        );
      }),
    ]);
  }
}

// ── 태그 편집기 ────────────────────────────────────────────────
class _TagEditor extends StatelessWidget {
  final List<String> tags;
  final TextEditingController controller;
  final void Function(String) onAdd;
  final void Function(String) onRemove;
  const _TagEditor({required this.tags, required this.controller, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        ...tags.map((t) => Chip(
          label: Text('#$t', style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 12)),
          backgroundColor: AppTheme.mintPrimary.withValues(alpha: 0.12),
          side: BorderSide(color: AppTheme.mintPrimary.withValues(alpha: 0.3)),
          deleteIcon: const Icon(Icons.close, size: 13, color: AppTheme.mintPrimary),
          onDeleted: () => onRemove(t),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        )),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(
          controller: controller,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
          decoration: InputDecoration(
            hintText: '태그 입력 후 Enter',
            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true, fillColor: AppTheme.bgCardLight,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: AppTheme.border)),
          ),
          onSubmitted: onAdd,
        )),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add_circle_rounded, color: AppTheme.mintPrimary),
          onPressed: () => onAdd(controller.text.trim()),
        ),
      ]),
    ]);
  }
}

// ── 전략 Pillar 선택기 ─────────────────────────────────────────
class _PillarSelector extends StatelessWidget {
  final StrategyPillar? selected;
  final void Function(StrategyPillar?) onChanged;
  const _PillarSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      GestureDetector(
        onTap: () => onChanged(null),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected == null ? AppTheme.textMuted.withValues(alpha: 0.15) : AppTheme.bgCardLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected == null ? AppTheme.textMuted : AppTheme.border),
          ),
          child: Text('없음', style: TextStyle(
            color: selected == null ? AppTheme.textPrimary : AppTheme.textMuted, fontSize: 12)),
        ),
      ),
      ...StrategyPillar.values.map((p) {
        final isSelected = selected == p;
        final color = Color(int.parse('0xFF${p.colorHex.substring(1)}'));
        return GestureDetector(
          onTap: () => onChanged(p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.bgCardLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? color : AppTheme.border, width: isSelected ? 1.5 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(p.icon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(p.name, style: TextStyle(
                color: isSelected ? color : AppTheme.textMuted,
                fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              )),
            ]),
          ),
        );
      }),
    ]);
  }
}

// ── KPI 선택기 ────────────────────────────────────────────────
class _KpiSelector extends StatelessWidget {
  final List<KpiModel> kpis;
  final String? selectedId;
  final void Function(String?) onChanged;
  const _KpiSelector({required this.kpis, required this.selectedId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedId,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true, fillColor: AppTheme.bgCardLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.border)),
        hintText: 'KPI를 선택하세요',
        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
      ),
      dropdownColor: AppTheme.bgCard,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      items: [
        const DropdownMenuItem(value: null,
            child: Text('연결 안함', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
        ...kpis.map((k) => DropdownMenuItem(
          value: k.id,
          child: Row(children: [
            if (k.pillar != null) Text(k.pillar!.icon, style: const TextStyle(fontSize: 12)),
            if (k.pillar != null) const SizedBox(width: 5),
            Expanded(child: Text(k.title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
            Text(' (${(k.current / (k.target == 0 ? 1 : k.target) * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ]),
        )),
      ],
      onChanged: onChanged,
    );
  }
}

// ── 예산 요약 행 ──────────────────────────────────────────────
class _BudgetSummaryRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _BudgetSummaryRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11))),
    Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
  ]);
}

String _fmtNum(double v) {
  if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}억';
  if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(0)}만';
  if (v == 0)   return '0';
  return v.toStringAsFixed(0);
}
