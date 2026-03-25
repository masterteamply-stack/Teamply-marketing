import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../widgets/edit_dialog.dart';
import '../../widgets/client_csv_upload_dialog.dart';

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
    final campaigns = provider.teamCampaigns; // 팀 캠페인만 표시
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
// 탭: 태스크 목록 | 분석 | KPI 연결 | 프로젝트
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

class _TaskCardPanelState extends State<_TaskCardPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  TaskSortBy _sortBy = TaskSortBy.dueDate;
  bool _sortAsc = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  List<TaskWithProject> _sortedTasks(List<TaskWithProject> tasks) {
    var filtered = _filterStatus == 'all'
        ? tasks
        : tasks.where((t) => t.task.status.name == _filterStatus).toList();

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
          cmp = b.task.priority.index.compareTo(a.task.priority.index);
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
              Row(children: [
                _MiniStat(label: 'ROI', value: '${c.roi.toStringAsFixed(0)}%',
                    color: c.roi >= 200 ? AppTheme.success : c.roi >= 100 ? AppTheme.mintPrimary : AppTheme.warning),
                const SizedBox(width: 12),
                _MiniStat(label: 'ROAS', value: '${c.roas.toStringAsFixed(1)}x', color: AppTheme.info),
                const SizedBox(width: 12),
                _MiniStat(label: '매출', value: '₩${_shortNum(c.revenue)}', color: AppTheme.success),
                const SizedBox(width: 12),
                _MiniStat(label: '집행', value: '₩${_shortNum(c.spent)}', color: AppTheme.textSecondary),
                const Spacer(),
                // 고객사 CSV 업로드 버튼
                GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => ClientCsvUploadDialog(
                      provider: widget.provider,
                      teamId: widget.provider.selectedTeamId,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.upload_file, color: AppTheme.info, size: 11),
                      SizedBox(width: 4),
                      Text('고객사 CSV', style: TextStyle(color: AppTheme.info, fontSize: 9)),
                    ]),
                  ),
                ),
              ]),
            ]),
          ),

          // ── 탭바 ─────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1E3040))),
            ),
            child: TabBar(
              controller: _tabCtrl,
              tabs: [
                Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.task_alt, size: 12),
                  const SizedBox(width: 4),
                  Text('태스크(${tasks.length})', style: const TextStyle(fontSize: 11)),
                ])),
                const Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.analytics_outlined, size: 12),
                  SizedBox(width: 4),
                  Text('분석', style: TextStyle(fontSize: 11)),
                ])),
                const Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.track_changes, size: 12),
                  SizedBox(width: 4),
                  Text('KPI', style: TextStyle(fontSize: 11)),
                ])),
                const Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.folder_outlined, size: 12),
                  SizedBox(width: 4),
                  Text('프로젝트', style: TextStyle(fontSize: 11)),
                ])),
              ],
              labelColor: AppTheme.mintPrimary,
              unselectedLabelColor: AppTheme.textMuted,
              indicatorColor: AppTheme.mintPrimary,
              indicatorSize: TabBarIndicatorSize.tab,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ),

          // ── 탭 뷰 ────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildTaskListTab(sorted, tasks, fmt),
                _buildAnalysisTab(tasks),
                _CampaignKpiSection(campaign: c, provider: widget.provider),
                _CampaignProjectSection(campaign: c, provider: widget.provider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 태스크 목록 탭 ──────────────────────────────────────
  Widget _buildTaskListTab(List<TaskWithProject> sorted, List<TaskWithProject> all, DateFormat fmt) {
    return Column(
      children: [
        // 정렬 & 필터 툴바
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF1E3040))),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.task_alt, color: AppTheme.mintPrimary, size: 12),
                const SizedBox(width: 4),
                Text('${sorted.length} / ${all.length}개',
                    style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 8),
            _FilterChip(label: '전체', selected: _filterStatus == 'all',
                onTap: () => setState(() => _filterStatus = 'all')),
            const SizedBox(width: 4),
            _FilterChip(label: '진행', selected: _filterStatus == 'inProgress',
                color: AppTheme.info, onTap: () => setState(() => _filterStatus = 'inProgress')),
            const SizedBox(width: 4),
            _FilterChip(label: '검토', selected: _filterStatus == 'inReview',
                color: AppTheme.warning, onTap: () => setState(() => _filterStatus = 'inReview')),
            const SizedBox(width: 4),
            _FilterChip(label: '완료', selected: _filterStatus == 'done',
                color: AppTheme.success, onTap: () => setState(() => _filterStatus = 'done')),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.bgCardLight,
                borderRadius: BorderRadius.circular(6),
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
            GestureDetector(
              onTap: () => setState(() => _sortAsc = !_sortAsc),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(6)),
                child: Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                    color: AppTheme.mintPrimary, size: 14),
              ),
            ),
          ]),
        ),
        Expanded(
          child: sorted.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.task_alt_outlined, color: AppTheme.textMuted.withValues(alpha: 0.4), size: 40),
                  const SizedBox(height: 10),
                  const Text('연결된 태스크가 없습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  const SizedBox(height: 6),
                  const Text('프로젝트 탭에서 프로젝트를 연결하세요',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: sorted.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TaskCard(tp: sorted[i], provider: widget.provider, fmt: fmt),
                  ),
                ),
        ),
      ],
    );
  }

  // ── 분석 탭 ─────────────────────────────────────────────
  Widget _buildAnalysisTab(List<TaskWithProject> tasks) {
    if (tasks.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.analytics_outlined, color: AppTheme.textMuted.withValues(alpha: 0.4), size: 48),
        const SizedBox(height: 12),
        const Text('분석할 태스크가 없습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
        const SizedBox(height: 6),
        const Text('프로젝트를 연결하면 태스크보드가 이 캠페인으로 분석됩니다',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      ]));
    }

    // 상태별 집계
    final statusCounts = <String, int>{
      'todo': 0, 'inProgress': 0, 'inReview': 0, 'done': 0
    };
    final priorityCounts = <String, int>{
      'urgent': 0, 'high': 0, 'medium': 0, 'low': 0
    };
    int overdueCount = 0;
    double totalProgress = 0;
    final regionCounts = <String, int>{};
    final countryCounts = <String, int>{};
    final clientIdSet = <String>{};
    final assigneeTaskCount = <String, int>{};
    final projectTaskCount = <String, int>{};
    int checklistTotal = 0, checklistDone = 0;

    for (final tp in tasks) {
      final t = tp.task;
      statusCounts[t.status.name] = (statusCounts[t.status.name] ?? 0) + 1;
      priorityCounts[t.priority.name] = (priorityCounts[t.priority.name] ?? 0) + 1;
      if (t.isOverdue) overdueCount++;
      totalProgress += t.checklistProgress;
      checklistTotal += t.checklist.length;
      checklistDone += t.checklist.where((c) => c.isDone).length;

      // 권역/국가
      for (final r in t.targetRegions) {
        regionCounts[r] = (regionCounts[r] ?? 0) + 1;
      }
      if (t.targetRegions.isEmpty && t.defaultRegion != null) {
        regionCounts[t.defaultRegion!] = (regionCounts[t.defaultRegion!] ?? 0) + 1;
      }
      for (final cc in t.targetCountries) {
        countryCounts[cc] = (countryCounts[cc] ?? 0) + 1;
      }
      if (t.targetCountries.isEmpty && t.defaultCountry != null) {
        countryCounts[t.defaultCountry!] = (countryCounts[t.defaultCountry!] ?? 0) + 1;
      }

      // 고객사
      clientIdSet.addAll(t.targetClientIds);

      // 담당자
      for (final uid in t.assigneeIds) {
        assigneeTaskCount[uid] = (assigneeTaskCount[uid] ?? 0) + 1;
      }

      // 프로젝트
      projectTaskCount[tp.project.name] = (projectTaskCount[tp.project.name] ?? 0) + 1;
    }

    final avgProgress = tasks.isNotEmpty ? totalProgress / tasks.length : 0.0;
    final linkedClients = widget.provider.clients
        .where((c) => clientIdSet.contains(c.id))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 상단 요약 카드들
        Row(children: [
          _AnalysisStat('전체 태스크', '${tasks.length}', Icons.task_alt, AppTheme.mintPrimary),
          const SizedBox(width: 8),
          _AnalysisStat('평균 진행률', '${avgProgress.toStringAsFixed(0)}%', Icons.pie_chart_outline, AppTheme.info),
          const SizedBox(width: 8),
          _AnalysisStat('지연 태스크', '$overdueCount', Icons.warning_amber_outlined,
              overdueCount > 0 ? AppTheme.error : AppTheme.success),
          const SizedBox(width: 8),
          _AnalysisStat('연결 고객사', '${linkedClients.length}', Icons.business_outlined, AppTheme.warning),
        ]),
        const SizedBox(height: 14),

        // 상태 분포
        _SectionHeader('상태 분포'),
        const SizedBox(height: 8),
        _StatusBar(counts: statusCounts, total: tasks.length),
        const SizedBox(height: 14),

        // 체크리스트 진행
        if (checklistTotal > 0) ...[
          _SectionHeader('체크리스트 완료율'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: LinearProgressIndicator(
              value: checklistTotal > 0 ? checklistDone / checklistTotal : 0,
              backgroundColor: AppTheme.bgCardLight,
              valueColor: const AlwaysStoppedAnimation(AppTheme.success),
              minHeight: 8,
            )),
            const SizedBox(width: 10),
            Text('$checklistDone / $checklistTotal',
                style: const TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
        ],

        // 우선순위 분포
        _SectionHeader('우선순위 분포'),
        const SizedBox(height: 8),
        Row(children: [
          _PriorityChip('긴급', priorityCounts['urgent'] ?? 0, AppTheme.error),
          const SizedBox(width: 6),
          _PriorityChip('높음', priorityCounts['high'] ?? 0, AppTheme.warning),
          const SizedBox(width: 6),
          _PriorityChip('보통', priorityCounts['medium'] ?? 0, AppTheme.info),
          const SizedBox(width: 6),
          _PriorityChip('낮음', priorityCounts['low'] ?? 0, AppTheme.textMuted),
        ]),
        const SizedBox(height: 14),

        // 권역별 태스크
        if (regionCounts.isNotEmpty) ...[
          _SectionHeader('권역별 태스크'),
          const SizedBox(height: 8),
          ...regionCounts.entries.map((e) => _RegionBar(
            region: e.key,
            count: e.value,
            total: tasks.length,
          )),
          const SizedBox(height: 14),
        ],

        // 국가별 태스크
        if (countryCounts.isNotEmpty) ...[
          _SectionHeader('국가별 태스크'),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6,
            children: (countryCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
                .take(10)
                .map((e) => _CountryChip(e.key, e.value))
                .toList(),
          ),
          const SizedBox(height: 14),
        ],

        // 연결 고객사
        if (linkedClients.isNotEmpty) ...[
          _SectionHeader('연결 고객사 (${linkedClients.length}개)'),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6,
            children: linkedClients.map((c) => _ClientChip(c)).toList(),
          ),
          const SizedBox(height: 14),
        ],

        // 담당자별 태스크
        if (assigneeTaskCount.isNotEmpty) ...[
          _SectionHeader('담당자별 태스크'),
          const SizedBox(height: 8),
          ...(assigneeTaskCount.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
              .take(8)
              .map((e) {
                final user = widget.provider.allUsers
                    .where((u) => u.id == e.key)
                    .firstOrNull;
                return _AssigneeBar(
                  name: user?.name ?? user?.email ?? e.key,
                  count: e.value,
                  total: tasks.length,
                );
              }),
          const SizedBox(height: 14),
        ],

        // 프로젝트별 태스크
        if (projectTaskCount.length > 1) ...[
          _SectionHeader('프로젝트별 태스크'),
          const SizedBox(height: 8),
          ...(projectTaskCount.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
              .map((e) => _ProjectBar(
                name: e.key,
                count: e.value,
                total: tasks.length,
              )),
        ],
      ]),
    );
  }

  static String _shortNum(double v) {
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}억';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(0)}만';
    return v.toStringAsFixed(0);
  }
}

// ══════════════════════════════════════════════════════════
// 태스크 카드 (개별) - 전략/권역/고객사 정보 포함
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

    // 연결 고객사
    final linkedClients = provider.clients
        .where((c) => task.targetClientIds.contains(c.id))
        .toList();

    // 전략 연결 정보
    final linkedCampaign = task.campaignId != null
        ? provider.campaigns.where((c) => c.id == task.campaignId).firstOrNull
        : null;
    final kpi = task.kpiId != null
        ? provider.kpis.where((k) => k.id == task.kpiId).firstOrNull
        : null;

    // 권역/국가
    final regions = task.targetRegions.isNotEmpty
        ? task.targetRegions
        : (task.defaultRegion != null ? [task.defaultRegion!] : <String>[]);
    final countries = task.targetCountries.isNotEmpty
        ? task.targetCountries
        : (task.defaultCountry != null ? [task.defaultCountry!] : <String>[]);

    return InkWell(
      onTap: () => provider.navigateToTask(task.id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
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
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task.title,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ]),

          const SizedBox(height: 6),

          // ─── 프로젝트 + 담당자 ───
          Row(children: [
            const Icon(Icons.folder_outlined, size: 11, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(project.name,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                  overflow: TextOverflow.ellipsis),
            ),
            if (task.assigneeIds.isNotEmpty) ...[
              ...task.assigneeIds.take(3).map((uid) {
                final user = provider.allUsers.where((u) => u.id == uid).firstOrNull;
                return Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: AppTheme.mintPrimary.withValues(alpha: 0.3),
                    child: Text(
                      user?.avatarInitials.substring(0, 1) ?? '?',
                      style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 7, fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              }),
              if (task.assigneeIds.length > 3)
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: AppTheme.bgCard,
                    child: Text('+${task.assigneeIds.length - 3}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 7)),
                  ),
                ),
            ],
          ]),

          // ─── 전략 연결 배지 ───
          if (linkedCampaign != null || kpi != null) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 4, runSpacing: 4, children: [
              if (linkedCampaign != null)
                _StrategyBadge(icon: Icons.campaign, label: linkedCampaign.name, color: AppTheme.mintPrimary),
              if (kpi != null)
                _StrategyBadge(icon: Icons.track_changes, label: kpi.title, color: AppTheme.info),
            ]),
          ],

          // ─── 권역 / 국가 ───
          if (regions.isNotEmpty || countries.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 4, runSpacing: 4, children: [
              ...regions.take(3).map((r) => _GeoChip(r, Icons.public, _regionColor(r))),
              ...countries.take(3).map((c) => _GeoChip(c, Icons.flag, AppTheme.textMuted)),
            ]),
          ],

          // ─── 연결 고객사 ───
          if (linkedClients.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 4, runSpacing: 4, children: [
              ...linkedClients.take(3).map((c) => _ClientMiniChip(c)),
              if (linkedClients.length > 3)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(4)),
                  child: Text('+${linkedClients.length - 3}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                ),
            ]),
          ],

          // ─── 체크리스트 진행률 ───
          if (task.checklist.isNotEmpty) ...[
            const SizedBox(height: 8),
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
              Text('${progress.toInt()}%',
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ],

          // ─── 하단: 우선순위 + 태그 + D-day ───
          const SizedBox(height: 8),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(priorityLabel,
                  style: TextStyle(color: priorityColor, fontSize: 9, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 4),
            ...task.tags.take(2).map((tag) => Padding(
              padding: const EdgeInsets.only(right: 3),
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
            if (task.dueDate != null) ...[
              Icon(Icons.calendar_today_outlined, size: 10,
                  color: isOverdue ? AppTheme.error : AppTheme.textMuted),
              const SizedBox(width: 3),
              Text(fmt.format(task.dueDate!),
                  style: TextStyle(
                    color: isOverdue ? AppTheme.error : AppTheme.textMuted,
                    fontSize: 10,
                  )),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isOverdue ? AppTheme.error.withValues(alpha: 0.15) : AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  daysLeft == null ? '' : isOverdue ? 'D+${daysLeft.abs()}' :
                      daysLeft == 0 ? 'D-Day' : 'D-$daysLeft',
                  style: TextStyle(
                    color: isOverdue ? AppTheme.error : AppTheme.textSecondary,
                    fontSize: 9, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.open_in_new, size: 11, color: AppTheme.textMuted),
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
  Color _regionColor(String region) {
    final lower = region.toLowerCase();
    if (lower.contains('아시아') || lower.contains('asia')) return const Color(0xFF4CAF50);
    if (lower.contains('중동') || lower.contains('middle')) return const Color(0xFFFF9800);
    if (lower.contains('유럽') || lower.contains('europe')) return const Color(0xFF2196F3);
    if (lower.contains('미주') || lower.contains('america')) return const Color(0xFF9C27B0);
    if (lower.contains('국내') || lower.contains('korea')) return AppTheme.mintPrimary;
    return AppTheme.textSecondary;
  }
}

// 전략 연결 배지
class _StrategyBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StrategyBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 9),
        const SizedBox(width: 3),
        Flexible(child: Text(label,
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

// 지역/국가 칩
class _GeoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _GeoChip(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 8),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color, fontSize: 9)),
      ]),
    );
  }
}

// 고객사 미니 칩
class _ClientMiniChip extends StatelessWidget {
  final ClientAccount client;
  const _ClientMiniChip(this.client);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.business, color: AppTheme.warning, size: 8),
        const SizedBox(width: 3),
        Text(
          client.name.length > 12 ? '${client.name.substring(0, 12)}…' : client.name,
          style: const TextStyle(color: AppTheme.warning, fontSize: 9),
        ),
        if (client.country != null) ...[
          const SizedBox(width: 3),
          Text('(${client.country})',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 8)),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 분석 탭 보조 위젯들
// ══════════════════════════════════════════════════════════

class _AnalysisStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _AnalysisStat(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
      ]),
    ));
  }
}

class _StatusBar extends StatelessWidget {
  final Map<String, int> counts;
  final int total;
  const _StatusBar({required this.counts, required this.total});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('대기', counts['todo'] ?? 0, AppTheme.textMuted),
      ('진행', counts['inProgress'] ?? 0, AppTheme.info),
      ('검토', counts['inReview'] ?? 0, AppTheme.warning),
      ('완료', counts['done'] ?? 0, AppTheme.success),
    ];
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: items.map((item) {
            final ratio = total > 0 ? item.$2 / total : 0.0;
            if (ratio == 0) return const SizedBox.shrink();
            return Expanded(
              flex: (ratio * 100).round().clamp(1, 100),
              child: Container(height: 10, color: item.$3),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 6),
      Row(children: items.map((item) => Expanded(child: Column(children: [
        Text('${item.$2}', style: TextStyle(color: item.$3, fontSize: 12, fontWeight: FontWeight.w700)),
        Text(item.$1, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
      ]))).toList()),
    ]);
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _PriorityChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        Text('$count', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
      ]),
    );
  }
}

class _RegionBar extends StatelessWidget {
  final String region;
  final int count;
  final int total;
  const _RegionBar({required this.region, required this.count, required this.total});

  Color get _color {
    final lower = region.toLowerCase();
    if (lower.contains('아시아') || lower.contains('asia')) return const Color(0xFF4CAF50);
    if (lower.contains('중동') || lower.contains('middle')) return const Color(0xFFFF9800);
    if (lower.contains('유럽') || lower.contains('europe')) return const Color(0xFF2196F3);
    if (lower.contains('미주') || lower.contains('america')) return const Color(0xFF9C27B0);
    if (lower.contains('국내') || lower.contains('korea')) return AppTheme.mintPrimary;
    return AppTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 60,
            child: Text(region, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: AppTheme.bgCardLight,
            valueColor: AlwaysStoppedAnimation(_color),
            minHeight: 6,
          ),
        )),
        const SizedBox(width: 8),
        Text('$count', style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _CountryChip extends StatelessWidget {
  final String country;
  final int count;
  const _CountryChip(this.country, this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1E3040)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.flag, color: AppTheme.textMuted, size: 10),
        const SizedBox(width: 4),
        Text(country, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        const SizedBox(width: 4),
        Text('$count', style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _ClientChip extends StatelessWidget {
  final ClientAccount client;
  const _ClientChip(this.client);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.business, color: AppTheme.warning, size: 10),
        const SizedBox(width: 4),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            client.name.length > 16 ? '${client.name.substring(0, 16)}…' : client.name,
            style: const TextStyle(color: AppTheme.warning, fontSize: 10, fontWeight: FontWeight.w600),
          ),
          if (client.countryName != null || client.country != null)
            Text(client.countryName ?? client.country ?? '',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 8)),
        ]),
      ]),
    );
  }
}

class _AssigneeBar extends StatelessWidget {
  final String name;
  final int count;
  final int total;
  const _AssigneeBar({required this.name, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: AppTheme.mintPrimary.withValues(alpha: 0.2),
          child: Text(name.isNotEmpty ? name[0] : '?',
              style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 9, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 70,
            child: Text(name, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: total > 0 ? count / total : 0,
            backgroundColor: AppTheme.bgCardLight,
            valueColor: const AlwaysStoppedAnimation(AppTheme.mintPrimary),
            minHeight: 5,
          ),
        )),
        const SizedBox(width: 8),
        Text('$count',
            style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _ProjectBar extends StatelessWidget {
  final String name;
  final int count;
  final int total;
  const _ProjectBar({required this.name, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        const Icon(Icons.folder_outlined, color: AppTheme.info, size: 12),
        const SizedBox(width: 6),
        SizedBox(width: 80,
            child: Text(name, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: total > 0 ? count / total : 0,
            backgroundColor: AppTheme.bgCardLight,
            valueColor: const AlwaysStoppedAnimation(AppTheme.info),
            minHeight: 5,
          ),
        )),
        const SizedBox(width: 8),
        Text('$count',
            style: const TextStyle(color: AppTheme.info, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 보조 위젯들
// ══════════════════════════════════════════════════════════

Widget _SectionHeader(String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      title,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
  );
}

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

// ─── 캠페인 연결 KPI 섹션 ─────────────────────────────────────
class _CampaignKpiSection extends StatelessWidget {
  final CampaignModel campaign;
  final AppProvider provider;
  const _CampaignKpiSection({required this.campaign, required this.provider});

  @override
  Widget build(BuildContext context) {
    // 팀 KPI 기준으로 필터링 (currentTeamKpis 우선, 없으면 전체 kpis fallback)
    final teamKpiList = provider.currentTeamKpis.isNotEmpty
        ? provider.currentTeamKpis
        : provider.kpis;

    // 이 캠페인에 연결된 KPI 목록
    final linkedKpis = teamKpiList.where((k) => k.campaignId == campaign.id).toList();
    // kpiIds 리스트로 연결된 KPI도 포함 (campaign.kpiIds)
    final kpiIdSet = campaign.kpiIds.toSet();
    for (final k in teamKpiList) {
      if (kpiIdSet.contains(k.id) && !linkedKpis.any((lk) => lk.id == k.id)) {
        linkedKpis.add(k);
      }
    }

    // 이 캠페인에 연결된 태스크에서 KPI 매칭 (task.kpiId 기반 자동 연동)
    final campaignTasks = provider.getLinkedTasksForCampaign(campaign.id);
    final taskLinkedKpiIds = campaignTasks
        .map((t) => t.task.kpiId)
        .where((id) => id != null && id.isNotEmpty)
        .toSet();
    for (final k in teamKpiList) {
      if (taskLinkedKpiIds.contains(k.id) && !linkedKpis.any((lk) => lk.id == k.id)) {
        linkedKpis.add(k);
      }
    }

    if (linkedKpis.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.track_changes_outlined,
              color: AppTheme.textMuted.withValues(alpha: 0.4), size: 40),
          const SizedBox(height: 10),
          const Text('연결된 KPI가 없습니다',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          const SizedBox(height: 6),
          const Text('KPI 관리에서 이 캠페인에 KPI를 연결하세요',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ]),
      );
    }

    // 태스크 집계 (이 캠페인과 연결된 태스크 요약)
    final totalTasks = campaignTasks.length;
    final doneTasks = campaignTasks.where((t) => t.task.status == TaskStatus.done).length;
    final inProgressTasks = campaignTasks.where((t) => t.task.status == TaskStatus.inProgress).length;
    final taskCompletionRate = totalTasks > 0 ? (doneTasks / totalTasks * 100) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── 태스크 집계 요약 (연동 핵심) ──
        if (totalTasks > 0) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgCardLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.task_alt, color: AppTheme.mintPrimary, size: 12),
                const SizedBox(width: 5),
                Text('태스크 → KPI 연동 현황 ($totalTasks개 태스크)',
                    style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _TaskStatChip('완료', doneTasks, AppTheme.success),
                const SizedBox(width: 6),
                _TaskStatChip('진행', inProgressTasks, AppTheme.info),
                const SizedBox(width: 6),
                _TaskStatChip('대기', totalTasks - doneTasks - inProgressTasks, AppTheme.textMuted),
                const Spacer(),
                Text('완료율 ${taskCompletionRate.toStringAsFixed(0)}%',
                    style: TextStyle(
                        color: taskCompletionRate >= 80 ? AppTheme.success
                            : taskCompletionRate >= 50 ? AppTheme.warning : AppTheme.error,
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (taskCompletionRate / 100).clamp(0, 1),
                  backgroundColor: AppTheme.bgCard,
                  valueColor: AlwaysStoppedAnimation(
                    taskCompletionRate >= 80 ? AppTheme.success
                        : taskCompletionRate >= 50 ? AppTheme.warning : AppTheme.error),
                  minHeight: 5,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],

        // ── KPI 카드 목록 ──
        Row(children: [
          const Icon(Icons.track_changes, color: AppTheme.mintPrimary, size: 12),
          const SizedBox(width: 5),
          Text('연결 KPI (${linkedKpis.length})',
              style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
          if (totalTasks > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.mintPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('태스크 자동 집계',
                  style: TextStyle(color: AppTheme.mintPrimary, fontSize: 9)),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        ...linkedKpis.map((k) {
          // 이 KPI에 연결된 태스크 찾기 (자동 집계)
          final kpiTasks = campaignTasks.where((t) => t.task.kpiId == k.id).toList();
          final kpiTaskDone = kpiTasks.where((t) => t.task.status == TaskStatus.done).length;
          final kpiTaskTotal = kpiTasks.length;

          final achRate = k.achievementRate;
          final color = achRate >= 80 ? AppTheme.success : achRate >= 50 ? AppTheme.warning : AppTheme.error;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgCardLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(k.title,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
                Text('${achRate.toStringAsFixed(0)}%',
                    style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
              Text('${k.current.toStringAsFixed(0)} / ${k.target.toStringAsFixed(0)} ${k.unit}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (achRate / 100).clamp(0, 1),
                  backgroundColor: AppTheme.bgCard,
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 4,
                ),
              ),
              // 연결된 태스크 집계 표시
              if (kpiTaskTotal > 0) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.link, color: AppTheme.textMuted, size: 10),
                  const SizedBox(width: 3),
                  Text('태스크 $kpiTaskDone/$kpiTaskTotal 완료',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                ]),
              ],
            ]),
          );
        }),
      ]),
    );
  }
}

class _TaskStatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _TaskStatChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label $count',
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── 캠페인 연결 프로젝트 섹션 ──────────────────────────────────
class _CampaignProjectSection extends StatefulWidget {
  final CampaignModel campaign;
  final AppProvider provider;
  const _CampaignProjectSection({required this.campaign, required this.provider});
  @override
  State<_CampaignProjectSection> createState() => _CampaignProjectSectionState();
}

class _CampaignProjectSectionState extends State<_CampaignProjectSection> {
  bool _showLinkPicker = false;

  @override
  Widget build(BuildContext context) {
    final linkedProjects = widget.provider.getProjectsByCampaignId(widget.campaign.id);
    final teamId = widget.provider.selectedTeamId;
    final unlinkedProjects = teamId != null
        ? widget.provider.getUnlinkedProjectsForTeam(teamId)
        : <Project>[];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E3040))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 섹션 헤더
        Row(children: [
          const Icon(Icons.folder_outlined, color: AppTheme.info, size: 13),
          const SizedBox(width: 5),
          Text('연결 프로젝트 (${linkedProjects.length})',
              style: const TextStyle(color: AppTheme.info, fontSize: 11, fontWeight: FontWeight.w600)),
          const Spacer(),
          InkWell(
            onTap: () => setState(() => _showLinkPicker = !_showLinkPicker),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_showLinkPicker ? Icons.close : Icons.link, color: AppTheme.info, size: 11),
                const SizedBox(width: 3),
                Text(_showLinkPicker ? '닫기' : '프로젝트 연결',
                    style: const TextStyle(color: AppTheme.info, fontSize: 9)),
              ]),
            ),
          ),
        ]),

        // 연결된 프로젝트 카드들
        if (linkedProjects.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...linkedProjects.map((proj) => _LinkedProjectCard(
            project: proj,
            provider: widget.provider,
            campaignId: widget.campaign.id,
            onUnlink: () {
              widget.provider.updateProjectCampaign(proj.id, null);
              setState(() {});
            },
          )),
        ] else if (!_showLinkPicker) ...[
          const SizedBox(height: 6),
          const Text('연결된 프로젝트가 없습니다. 우측 버튼으로 연결하세요.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ],

        // 프로젝트 연결 피커
        if (_showLinkPicker) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgCardLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('팀 프로젝트 연결', style: TextStyle(color: AppTheme.info, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (unlinkedProjects.isEmpty && linkedProjects.isEmpty)
                const Text('연결 가능한 프로젝트가 없습니다.', style: TextStyle(color: AppTheme.textMuted, fontSize: 10))
              else
                Column(children: [
                  // 미연결 프로젝트 목록
                  ...unlinkedProjects.map((proj) => _ProjectPickerItem(
                    project: proj,
                    isLinked: false,
                    onTap: () {
                      widget.provider.updateProjectCampaign(proj.id, widget.campaign.id);
                      setState(() {});
                    },
                  )),
                  // 이미 연결된 프로젝트도 표시 (해제 가능하도록)
                  ...linkedProjects.map((proj) => _ProjectPickerItem(
                    project: proj,
                    isLinked: true,
                    onTap: () {
                      widget.provider.updateProjectCampaign(proj.id, null);
                      setState(() {});
                    },
                  )),
                ]),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _LinkedProjectCard extends StatelessWidget {
  final Project project;
  final AppProvider provider;
  final String campaignId;
  final VoidCallback onUnlink;
  const _LinkedProjectCard({required this.project, required this.provider, required this.campaignId, required this.onUnlink});

  @override
  Widget build(BuildContext context) {
    Color projColor;
    try { projColor = Color(int.parse('0xFF${project.colorHex.replaceAll('#', '')}')); }
    catch (_) { projColor = AppTheme.info; }

    final taskCount = project.tasks.length;
    final doneCount = project.tasks.where((t) => t.status.name == 'done').length;
    final progress = taskCount > 0 ? doneCount / taskCount : 0.0;
    final progressPct = (progress * 100).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: projColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: projColor.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Text(project.iconEmoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(project.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
          Row(children: [
            Text('태스크 $doneCount/$taskCount', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
            const SizedBox(width: 8),
            Expanded(child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.bgCard,
              valueColor: AlwaysStoppedAnimation(projColor),
              minHeight: 3,
            )),
            const SizedBox(width: 6),
            Text('$progressPct%', style: TextStyle(color: projColor, fontSize: 9, fontWeight: FontWeight.w700)),
          ]),
        ])),
        const SizedBox(width: 8),
        // 프로젝트로 이동
        InkWell(
          onTap: () {
            provider.selectTeam(project.teamId);
            provider.selectProject(project.id);
            provider.navigateTo('project_detail');
          },
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.open_in_new, color: projColor, size: 12),
          ),
        ),
        const SizedBox(width: 4),
        // 연결 해제
        InkWell(
          onTap: onUnlink,
          borderRadius: BorderRadius.circular(4),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.link_off, color: AppTheme.textMuted, size: 12),
          ),
        ),
      ]),
    );
  }
}

class _ProjectPickerItem extends StatelessWidget {
  final Project project;
  final bool isLinked;
  final VoidCallback onTap;
  const _ProjectPickerItem({required this.project, required this.isLinked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color projColor;
    try { projColor = Color(int.parse('0xFF${project.colorHex.replaceAll('#', '')}')); }
    catch (_) { projColor = AppTheme.info; }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isLinked ? projColor.withValues(alpha: 0.1) : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isLinked ? projColor.withValues(alpha: 0.4) : const Color(0xFF1E3040)),
        ),
        child: Row(children: [
          Icon(isLinked ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isLinked ? projColor : AppTheme.textMuted, size: 16),
          const SizedBox(width: 8),
          Text(project.iconEmoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Expanded(child: Text(project.name, style: TextStyle(
            color: isLinked ? projColor : AppTheme.textPrimary,
            fontSize: 11, fontWeight: FontWeight.w600,
          ))),
          Text(
            isLinked ? '연결됨 (탭하여 해제)' : '탭하여 연결',
            style: TextStyle(color: isLinked ? projColor.withValues(alpha: 0.7) : AppTheme.textMuted, fontSize: 9),
          ),
        ]),
      ),
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
