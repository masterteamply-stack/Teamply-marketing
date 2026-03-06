import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../widgets/edit_dialog.dart';

// ─── 정렬 기준 열거형 ───────────────────────────────────────
enum TaskSortBy { dueDate, priority, status, progress, title }

extension TaskSortByLabel on TaskSortBy {
  String get label {
    switch (this) {
      case TaskSortBy.dueDate:    return '마감일';
      case TaskSortBy.priority:   return '우선순위';
      case TaskSortBy.status:     return '진행상태';
      case TaskSortBy.progress:   return '진행률';
      case TaskSortBy.title:      return '이름순';
    }
  }
  IconData get icon {
    switch (this) {
      case TaskSortBy.dueDate:    return Icons.calendar_today_outlined;
      case TaskSortBy.priority:   return Icons.flag_outlined;
      case TaskSortBy.status:     return Icons.track_changes_outlined;
      case TaskSortBy.progress:   return Icons.pie_chart_outline;
      case TaskSortBy.title:      return Icons.sort_by_alpha;
    }
  }
}

// ─── 메인 페이지 ───────────────────────────────────────────
class CampaignPage extends StatefulWidget {
  const CampaignPage({super.key});
  @override
  State<CampaignPage> createState() => _CampaignPageState();
}

class _CampaignPageState extends State<CampaignPage> {
  String? _selectedCampaignId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final campaigns = provider.campaigns;
    final fmt = NumberFormat('#,###');
    final isMobile = MediaQuery.of(context).size.width < 768;

    // 선택된 캠페인 객체
    final selectedCampaign = _selectedCampaignId != null
        ? campaigns.where((c) => c.id == _selectedCampaignId).firstOrNull
        : null;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: isMobile
            ? _buildMobileLayout(context, provider, campaigns, fmt, selectedCampaign)
            : _buildDesktopLayout(context, provider, campaigns, fmt, selectedCampaign),
      ),
    );
  }

  // ── 데스크탑 레이아웃: 좌측 캠페인 리스트 + 우측 태스크 패널 ──
  Widget _buildDesktopLayout(
    BuildContext context,
    AppProvider provider,
    List<CampaignModel> campaigns,
    NumberFormat fmt,
    CampaignModel? selectedCampaign,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('캠페인 & ROI', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('캠페인 성과 및 ROI 분석 · 캠페인을 클릭하면 연결된 태스크를 확인할 수 있습니다',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            ])),
          ]),
        ),
        const SizedBox(height: 20),

        // 요약 카드
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(children: [
            _RoiCard(title: '전체 ROI', value: '${provider.overallRoi.toStringAsFixed(0)}%', icon: Icons.trending_up, color: AppTheme.mintPrimary),
            const SizedBox(width: 14),
            _RoiCard(title: '총 매출', value: '₩${_short(provider.totalRevenue)}', icon: Icons.attach_money, color: AppTheme.success),
            const SizedBox(width: 14),
            _RoiCard(title: '광고비 집행', value: '₩${_short(provider.totalSpent)}', icon: Icons.account_balance_wallet_outlined, color: AppTheme.warning),
            const SizedBox(width: 14),
            _RoiCard(title: '활성 캠페인', value: '${provider.activeCampaigns}개', icon: Icons.campaign_outlined, color: AppTheme.info),
          ]),
        ),
        const SizedBox(height: 20),

        // 본문: 좌측 테이블 + 우측 태스크 패널
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── 좌측: 캠페인 테이블 ───
                Expanded(
                  flex: selectedCampaign != null ? 5 : 10,
                  child: _CampaignTable(
                    campaigns: campaigns,
                    fmt: fmt,
                    selectedId: _selectedCampaignId,
                    provider: provider,
                    onSelect: (id) => setState(() =>
                        _selectedCampaignId = _selectedCampaignId == id ? null : id),
                  ),
                ),

                // ─── 우측: 태스크 카드 패널 ───
                if (selectedCampaign != null) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 5,
                    child: _TaskCardPanel(
                      campaign: selectedCampaign,
                      provider: provider,
                      onClose: () => setState(() => _selectedCampaignId = null),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── 모바일 레이아웃 ──────────────────────────────────────
  Widget _buildMobileLayout(
    BuildContext context,
    AppProvider provider,
    List<CampaignModel> campaigns,
    NumberFormat fmt,
    CampaignModel? selectedCampaign,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 요약
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _RoiCardMobile(title: '전체 ROI', value: '${provider.overallRoi.toStringAsFixed(0)}%', icon: Icons.trending_up, color: AppTheme.mintPrimary),
              _RoiCardMobile(title: '총 매출', value: '₩${_short(provider.totalRevenue)}', icon: Icons.attach_money, color: AppTheme.success),
              _RoiCardMobile(title: '광고비 집행', value: '₩${_short(provider.totalSpent)}', icon: Icons.account_balance_wallet_outlined, color: AppTheme.warning),
              _RoiCardMobile(title: '활성 캠페인', value: '${provider.activeCampaigns}개', icon: Icons.campaign_outlined, color: AppTheme.info),
            ],
          ),
          const SizedBox(height: 16),

          // 캠페인 리스트
          ...campaigns.map((c) {
            final isSelected = _selectedCampaignId == c.id;
            return Column(
              children: [
                _CampaignMobileCard(
                  c: c, fmt: fmt,
                  isSelected: isSelected,
                  onTap: () => setState(() =>
                      _selectedCampaignId = isSelected ? null : c.id),
                ),
                if (isSelected)
                  _TaskCardPanel(
                    campaign: c,
                    provider: provider,
                    onClose: () => setState(() => _selectedCampaignId = null),
                    isMobile: true,
                  ),
                const SizedBox(height: 8),
              ],
            );
          }),
        ],
      ),
    );
  }

  static String _short(double v) {
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}억';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(0)}만';
    return v.toStringAsFixed(0);
  }
}

// ══════════════════════════════════════════════════════════
// 캠페인 테이블 (데스크탑)
// ══════════════════════════════════════════════════════════
class _CampaignTable extends StatelessWidget {
  final List<CampaignModel> campaigns;
  final NumberFormat fmt;
  final String? selectedId;
  final void Function(String) onSelect;
  final AppProvider provider;

  const _CampaignTable({
    required this.campaigns,
    required this.fmt,
    required this.selectedId,
    required this.onSelect,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E3040)),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1E3040))),
            ),
            child: const Row(children: [
              Expanded(flex: 3, child: Text('캠페인', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
              Expanded(flex: 1, child: Text('상태', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
              Expanded(flex: 1, child: Text('ROI', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
              Expanded(flex: 1, child: Text('ROAS', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
              Expanded(flex: 1, child: Text('CTR', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
              Expanded(flex: 2, child: Text('예산 사용률', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
              SizedBox(width: 36),
            ]),
          ),
          // 캠페인 행 목록
          Expanded(
            child: ListView.builder(
              itemCount: campaigns.length,
              itemBuilder: (_, i) {
                final c = campaigns[i];
                final isSelected = selectedId == c.id;
                final statusColor = _statusColor(c.status);
                final statusLabel = _statusLabel(c.status);
                final roiColor = c.roi >= 200
                    ? AppTheme.success
                    : c.roi >= 100
                        ? AppTheme.mintPrimary
                        : c.roi >= 0
                            ? AppTheme.warning
                            : AppTheme.error;

                return InkWell(
                  onTap: () => onSelect(c.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.mintPrimary.withValues(alpha: 0.07)
                          : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(color: const Color(0xFF1E3040)),
                        left: isSelected
                            ? const BorderSide(color: AppTheme.mintPrimary, width: 3)
                            : const BorderSide(color: Colors.transparent, width: 3),
                      ),
                    ),
                    child: Row(children: [
                      // 캠페인명
                      Expanded(flex: 3, child: Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.mintPrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.campaign, color: AppTheme.mintPrimary, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.name,
                              style: TextStyle(
                                color: isSelected ? AppTheme.mintPrimary : AppTheme.textPrimary,
                                fontSize: 12, fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis),
                          Text('${c.type} · ${c.channel}',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                        ])),
                        Icon(
                          isSelected ? Icons.chevron_right : Icons.chevron_right,
                          color: isSelected ? AppTheme.mintPrimary : AppTheme.textMuted,
                          size: 16,
                        ),
                      ])),
                      // 상태
                      Expanded(flex: 1, child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10)),
                      )),
                      // ROI
                      Expanded(flex: 1, child: Text(
                        '${c.roi.toStringAsFixed(0)}%',
                        style: TextStyle(color: roiColor, fontSize: 12, fontWeight: FontWeight.w600),
                      )),
                      // ROAS
                      Expanded(flex: 1, child: Text(
                        '${c.roas.toStringAsFixed(1)}x',
                        style: const TextStyle(color: AppTheme.info, fontSize: 12),
                      )),
                      // CTR
                      Expanded(flex: 1, child: Text(
                        '${c.ctr.toStringAsFixed(2)}%',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      )),
                      // 예산 사용률
                      Expanded(flex: 2, child: Row(children: [
                        Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: c.budgetUsedPercent / 100,
                            backgroundColor: AppTheme.bgCardLight,
                            valueColor: AlwaysStoppedAnimation(
                              c.budgetUsedPercent >= 90 ? AppTheme.error : AppTheme.mintPrimary,
                            ),
                            minHeight: 5,
                          ),
                        )),
                        const SizedBox(width: 6),
                        Text('${c.budgetUsedPercent.toStringAsFixed(0)}%',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                      ])),
                      // 편집 버튼
                      Builder(builder: (ctx) => SizedBox(width: 36, child: IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 14, color: AppTheme.textMuted),
                        tooltip: '캠페인 편집',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: () => showDialog(
                          context: ctx,
                          builder: (_) => CampaignEditDialog(campaign: c, provider: provider),
                        ),
                      ))),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'active': return AppTheme.success;
      case 'completed': return AppTheme.info;
      default: return AppTheme.warning;
    }
  }
  String _statusLabel(String s) {
    switch (s) {
      case 'active': return '진행 중';
      case 'completed': return '완료';
      default: return '예정';
    }
  }
}

// ══════════════════════════════════════════════════════════
// 태스크 카드 패널 (캠페인 선택 시 우측 또는 아래에 표시)
// ══════════════════════════════════════════════════════════
class _TaskCardPanel extends StatefulWidget {
  final CampaignModel campaign;
  final AppProvider provider;
  final VoidCallback onClose;
  final bool isMobile;

  const _TaskCardPanel({
    required this.campaign,
    required this.provider,
    required this.onClose,
    this.isMobile = false,
  });

  @override
  State<_TaskCardPanel> createState() => _TaskCardPanelState();
}

class _TaskCardPanelState extends State<_TaskCardPanel> {
  TaskSortBy _sortBy = TaskSortBy.dueDate;
  bool _sortAsc = true;
  String _filterStatus = 'all'; // all / todo / inProgress / inReview / done

  List<TaskWithProject> _sortedTasks(List<TaskWithProject> tasks) {
    // 상태 필터
    var filtered = _filterStatus == 'all'
        ? tasks
        : tasks.where((t) => t.task.status.name == _filterStatus).toList();

    // 정렬
    filtered.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case TaskSortBy.dueDate:
          final ad = a.task.dueDate;
          final bd = b.task.dueDate;
          if (ad == null && bd == null) cmp = 0;
          else if (ad == null) cmp = 1;
          else if (bd == null) cmp = -1;
          else cmp = ad.compareTo(bd);
          break;
        case TaskSortBy.priority:
          cmp = b.task.priority.index.compareTo(a.task.priority.index); // urgent→low
          break;
        case TaskSortBy.status:
          cmp = a.task.status.index.compareTo(b.task.status.index);
          break;
        case TaskSortBy.progress:
          cmp = b.task.checklistProgress.compareTo(a.task.checklistProgress);
          break;
        case TaskSortBy.title:
          cmp = a.task.title.compareTo(b.task.title);
          break;
      }
      return _sortAsc ? cmp : -cmp;
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.provider.getTasksByCampaignId(widget.campaign.id);
    final sorted = _sortedTasks(tasks);
    final fmt = DateFormat('MM/dd');
    final c = widget.campaign;
    final statusColor = c.status == 'active'
        ? AppTheme.success
        : c.status == 'completed'
            ? AppTheme.info
            : AppTheme.warning;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 패널 헤더 ────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: AppTheme.mintPrimary.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: const Border(bottom: BorderSide(color: Color(0xFF1E3040))),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.mintPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.campaign, color: AppTheme.mintPrimary, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.name,
                      style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        c.status == 'active' ? '진행 중' : c.status == 'completed' ? '완료' : '예정',
                        style: TextStyle(color: statusColor, fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${c.type} · ${c.channel}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                  ]),
                ])),
                // 닫기 버튼
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCardLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.close, color: AppTheme.textMuted, size: 14),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              // 캠페인 지표 요약
              Row(children: [
                _MiniStat(label: 'ROI', value: '${c.roi.toStringAsFixed(0)}%',
                    color: c.roi >= 200 ? AppTheme.success : c.roi >= 100 ? AppTheme.mintPrimary : AppTheme.warning),
                const SizedBox(width: 12),
                _MiniStat(label: 'ROAS', value: '${c.roas.toStringAsFixed(1)}x', color: AppTheme.info),
                const SizedBox(width: 12),
                _MiniStat(label: '매출', value: '₩${_shortNum(c.revenue)}', color: AppTheme.success),
                const SizedBox(width: 12),
                _MiniStat(label: '집행', value: '₩${_shortNum(c.spent)}', color: AppTheme.textSecondary),
              ]),
            ]),
          ),

          // ── 정렬 & 필터 툴바 ─────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1E3040))),
            ),
            child: Row(children: [
              // 태스크 수 뱃지
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.bgCardLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.task_alt, color: AppTheme.mintPrimary, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '${sorted.length} / ${tasks.length}개',
                    style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
              const SizedBox(width: 8),

              // 상태 필터 칩
              _FilterChip(
                label: '전체',
                selected: _filterStatus == 'all',
                onTap: () => setState(() => _filterStatus = 'all'),
              ),
              const SizedBox(width: 4),
              _FilterChip(
                label: '진행',
                selected: _filterStatus == 'inProgress',
                color: AppTheme.info,
                onTap: () => setState(() => _filterStatus = 'inProgress'),
              ),
              const SizedBox(width: 4),
              _FilterChip(
                label: '검토',
                selected: _filterStatus == 'inReview',
                color: AppTheme.warning,
                onTap: () => setState(() => _filterStatus = 'inReview'),
              ),
              const SizedBox(width: 4),
              _FilterChip(
                label: '완료',
                selected: _filterStatus == 'done',
                color: AppTheme.success,
                onTap: () => setState(() => _filterStatus = 'done'),
              ),
              const Spacer(),

              // 정렬 기준 드롭다운
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.bgCardLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1E3040)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<TaskSortBy>(
                    value: _sortBy,
                    isDense: true,
                    dropdownColor: AppTheme.bgCard,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    icon: const Icon(Icons.sort, color: AppTheme.textMuted, size: 14),
                    items: TaskSortBy.values.map((s) => DropdownMenuItem(
                      value: s,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(s.icon, size: 12, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(s.label),
                      ]),
                    )).toList(),
                    onChanged: (v) => setState(() => _sortBy = v!),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 오름/내림차순 토글
              GestureDetector(
                onTap: () => setState(() => _sortAsc = !_sortAsc),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCardLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                    color: AppTheme.mintPrimary,
                    size: 14,
                  ),
                ),
              ),
            ]),
          ),

          // ── 태스크 카드 목록 ────────────────────────────────
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.task_alt_outlined,
                            color: AppTheme.textMuted.withValues(alpha: 0.4), size: 40),
                        const SizedBox(height: 10),
                        const Text('연결된 태스크가 없습니다',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: sorted.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TaskCard(
                        tp: sorted[i],
                        provider: widget.provider,
                        fmt: fmt,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static String _shortNum(double v) {
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}억';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(0)}만';
    return v.toStringAsFixed(0);
  }
}

// ══════════════════════════════════════════════════════════
// 태스크 카드 (개별)
// ══════════════════════════════════════════════════════════
class _TaskCard extends StatelessWidget {
  final TaskWithProject tp;
  final AppProvider provider;
  final DateFormat fmt;

  const _TaskCard({required this.tp, required this.provider, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final task = tp.task;
    final project = tp.project;
    final statusColor = _statusColor(task.status);
    final statusLabel = _statusLabel(task.status);
    final priorityColor = _priorityColor(task.priority);
    final priorityLabel = _priorityLabel(task.priority);
    final progress = task.checklistProgress;
    final daysLeft = task.dueDate?.difference(DateTime.now()).inDays;
    final isOverdue = task.isOverdue;

    return InkWell(
      onTap: () => provider.navigateToTask(task.id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgCardLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isOverdue
                ? AppTheme.error.withValues(alpha: 0.3)
                : statusColor.withValues(alpha: 0.2),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ─── 상단: 제목 + 상태 ───
          Row(children: [
            // 우선순위 도트
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task.title,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            // 상태 뱃지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ]),

          const SizedBox(height: 8),

          // ─── 프로젝트 + 담당자 ───
          Row(children: [
            Icon(Icons.folder_outlined, size: 11, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                project.name,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 담당자 아바타
            if (task.assigneeIds.isNotEmpty) ...[
              ...task.assigneeIds.take(3).map((uid) {
                final user = provider.allUsers.where((u) => u.id == uid).firstOrNull;
                return Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: AppTheme.mintPrimary.withValues(alpha: 0.3),
                    child: Text(
                      user?.avatarInitials.substring(0, 1) ?? '?',
                      style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 8, fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              }),
              if (task.assigneeIds.length > 3)
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: AppTheme.bgCard,
                    child: Text('+${task.assigneeIds.length - 3}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 8)),
                  ),
                ),
            ],
          ]),

          const SizedBox(height: 10),

          // ─── 체크리스트 진행률 ───
          if (task.checklist.isNotEmpty) ...[
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    backgroundColor: const Color(0xFF1E3040),
                    valueColor: AlwaysStoppedAnimation(statusColor),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${progress.toInt()}%',
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ]),
            const SizedBox(height: 8),
          ],

          // ─── 하단: 우선순위 + 태그 + D-day ───
          Row(children: [
            // 우선순위 칩
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(priorityLabel,
                  style: TextStyle(color: priorityColor, fontSize: 9, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 6),
            // 태그 (최대 2개)
            ...task.tags.take(2).map((tag) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF1E3040)),
                ),
                child: Text(tag, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
              ),
            )),
            const Spacer(),
            // D-day
            if (task.dueDate != null) ...[
              Icon(
                Icons.calendar_today_outlined,
                size: 10,
                color: isOverdue ? AppTheme.error : AppTheme.textMuted,
              ),
              const SizedBox(width: 3),
              Text(
                fmt.format(task.dueDate!),
                style: TextStyle(
                  color: isOverdue ? AppTheme.error : AppTheme.textMuted,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isOverdue
                      ? AppTheme.error.withValues(alpha: 0.15)
                      : AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  daysLeft == null
                      ? ''
                      : isOverdue
                          ? 'D+${daysLeft.abs()}'
                          : daysLeft == 0
                              ? 'D-Day'
                              : 'D-$daysLeft',
                  style: TextStyle(
                    color: isOverdue ? AppTheme.error : AppTheme.textSecondary,
                    fontSize: 9, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.open_in_new, size: 12, color: AppTheme.textMuted),
          ]),
        ]),
      ),
    );
  }

  Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.todo:       return AppTheme.textMuted;
      case TaskStatus.inProgress: return AppTheme.info;
      case TaskStatus.inReview:   return AppTheme.warning;
      case TaskStatus.done:       return AppTheme.success;
    }
  }
  String _statusLabel(TaskStatus s) {
    switch (s) {
      case TaskStatus.todo:       return '대기';
      case TaskStatus.inProgress: return '진행';
      case TaskStatus.inReview:   return '검토';
      case TaskStatus.done:       return '완료';
    }
  }
  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.low:    return AppTheme.textMuted;
      case TaskPriority.medium: return AppTheme.info;
      case TaskPriority.high:   return AppTheme.warning;
      case TaskPriority.urgent: return AppTheme.error;
    }
  }
  String _priorityLabel(TaskPriority p) {
    switch (p) {
      case TaskPriority.low:    return '낮음';
      case TaskPriority.medium: return '보통';
      case TaskPriority.high:   return '높음';
      case TaskPriority.urgent: return '긴급';
    }
  }
}

// ══════════════════════════════════════════════════════════
// 보조 위젯들
// ══════════════════════════════════════════════════════════

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.mintPrimary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.2) : AppTheme.bgCardLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? c.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? c : AppTheme.textMuted,
            fontSize: 10,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 모바일 캠페인 카드
// ══════════════════════════════════════════════════════════
class _CampaignMobileCard extends StatelessWidget {
  final CampaignModel c;
  final NumberFormat fmt;
  final bool isSelected;
  final VoidCallback onTap;

  const _CampaignMobileCard({
    required this.c, required this.fmt,
    this.isSelected = false, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = c.status == 'active'
        ? AppTheme.success
        : c.status == 'completed' ? AppTheme.info : AppTheme.warning;
    final statusLabel = c.status == 'active' ? '진행 중' : c.status == 'completed' ? '완료' : '예정';
    final roiColor = c.roi >= 200
        ? AppTheme.success
        : c.roi >= 100
            ? AppTheme.mintPrimary
            : c.roi >= 0 ? AppTheme.warning : AppTheme.error;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.mintPrimary.withValues(alpha: 0.05)
              : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.mintPrimary.withValues(alpha: 0.3)
                : const Color(0xFF1E3040),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.mintPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.campaign, color: AppTheme.mintPrimary, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
              Text('${c.type} · ${c.channel}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10)),
            ),
            const SizedBox(width: 4),
            Icon(isSelected ? Icons.expand_less : Icons.expand_more,
                color: AppTheme.textMuted, size: 16),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _MetricChip(label: 'ROI', value: '${c.roi.toStringAsFixed(0)}%', color: roiColor),
            const SizedBox(width: 8),
            _MetricChip(label: 'ROAS', value: '${c.roas.toStringAsFixed(1)}x', color: AppTheme.info),
            const SizedBox(width: 8),
            _MetricChip(label: 'CTR', value: '${c.ctr.toStringAsFixed(2)}%', color: AppTheme.textSecondary),
          ]),
        ]),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MetricChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label ', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// Desktop ROI card
class _RoiCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _RoiCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
        ]),
      ]),
    ));
  }
}

// Mobile ROI card
class _RoiCardMobile extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _RoiCardMobile({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }
}
