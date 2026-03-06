import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../widgets/task_link_panel.dart';
import '../../widgets/edit_dialog.dart';

class KpiPage extends StatefulWidget {
  const KpiPage({super.key});

  @override
  State<KpiPage> createState() => _KpiPageState();
}

class _KpiPageState extends State<KpiPage> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      floatingActionButton: isMobile
          ? FloatingActionButton(
              onPressed: () => _showAddKpiDialog(context, provider),
              backgroundColor: AppTheme.mintPrimary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(isMobile ? 16 : 28, isMobile ? 14 : 24, isMobile ? 16 : 28, 0),
              color: AppTheme.bgCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMobile)
                    Row(children: [
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('KPI 관리', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                          SizedBox(height: 4),
                          Text('팀 전략 KPI와 개인별 KPI 설정 및 추적', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                        ]),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAddKpiDialog(context, provider),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('KPI 추가'),
                      ),
                    ]),
                  if (!isMobile) const SizedBox(height: 16),
                  TabBar(
                    controller: _tab,
                    labelColor: AppTheme.mintPrimary,
                    unselectedLabelColor: AppTheme.textMuted,
                    indicatorColor: AppTheme.mintPrimary,
                    labelStyle: TextStyle(fontSize: isMobile ? 12 : 14),
                    tabs: const [
                      Tab(text: '팀 전략 KPI'),
                      Tab(text: '개인별 KPI'),
                      Tab(text: '월별 트래커'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _TeamKpiTab(provider: provider),
                  _PersonalKpiTab(provider: provider),
                  _KpiTrackerTab(provider: provider),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddKpiDialog(BuildContext context, AppProvider provider) {
    final titleCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final currentCtrl = TextEditingController();
    String unit = '건';
    String category = '매출';
    bool isTeamKpi = false;
    String? assignedTo;
    final categories = ['매출', 'ROI', 'ROAS', '리드', 'CTR', 'SEO', '콘텐츠', 'SNS', '이메일', '광고', '전환', '기타'];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('KPI 추가', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                SwitchListTile(
                  dense: true,
                  title: const Text('팀 KPI', style: TextStyle(color: AppTheme.textPrimary)),
                  subtitle: const Text('팀 전체 목표 여부', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  value: isTeamKpi, activeColor: AppTheme.mintPrimary,
                  onChanged: (v) => setState(() => isTeamKpi = v),
                ),
                const SizedBox(height: 8),
                TextField(controller: titleCtrl, style: const TextStyle(color: AppTheme.textPrimary), decoration: const InputDecoration(labelText: 'KPI 이름 *')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category, dropdownColor: AppTheme.bgCard,
                  decoration: const InputDecoration(labelText: '카테고리'),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => category = v!),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: targetCtrl, style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '목표값 *'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: currentCtrl, style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '현재값'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(labelText: '단위', hintText: unit),
                    onChanged: (v) => setState(() => unit = v.isEmpty ? '건' : v),
                  )),
                ]),
                if (!isTeamKpi) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: assignedTo, dropdownColor: AppTheme.bgCard,
                    decoration: const InputDecoration(labelText: '담당자'),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('없음')),
                      ...provider.allUsers.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))),
                    ],
                    onChanged: (v) => setState(() => assignedTo = v),
                  ),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                final target = double.tryParse(targetCtrl.text);
                if (title.isNotEmpty && target != null) {
                  provider.addKpi(KpiModel(
                    id: 'kpi_${DateTime.now().millisecondsSinceEpoch}',
                    title: title, category: category,
                    target: target,
                    current: double.tryParse(currentCtrl.text) ?? 0,
                    unit: unit, period: provider.selectedPeriod,
                    isTeamKpi: isTeamKpi, assignedTo: assignedTo,
                    dueDate: DateTime(DateTime.now().year, 12, 31),
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

// Team KPI Tab
class _TeamKpiTab extends StatelessWidget {
  final AppProvider provider;
  const _TeamKpiTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final kpis = provider.teamKpis;
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('팀 전략 KPI (${kpis.length}개)', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMobile ? 1 : 3,
                childAspectRatio: isMobile ? 2.2 : 1.6,
                crossAxisSpacing: isMobile ? 10 : 16,
                mainAxisSpacing: isMobile ? 10 : 16,
              ),
              itemCount: kpis.length,
              itemBuilder: (_, i) => _KpiCard(kpi: kpis[i], provider: provider),
            ),
          ),
        ],
      ),
    );
  }
}

// Personal KPI Tab
class _PersonalKpiTab extends StatelessWidget {
  final AppProvider provider;
  const _PersonalKpiTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final members = provider.allUsers;
    final isMobile = MediaQuery.of(context).size.width < 768;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: members.map((u) {
          final kpis = provider.kpis.where((k) => !k.isTeamKpi && k.assignedTo == u.id).toList();
          if (kpis.isEmpty) return const SizedBox();
          final col = u.avatarColor != null ? Color(int.parse('0xFF${u.avatarColor!.substring(1)}')) : AppTheme.mintPrimary;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Member header
              Row(children: [
                CircleAvatar(radius: 16, backgroundColor: col.withValues(alpha: 0.3), child: Text(u.avatarInitials, style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w700))),
                const SizedBox(width: 10),
                Text(u.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('KPI ${kpis.length}개', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const Spacer(),
                Text('평균 달성률: ${(kpis.fold(0.0, (s, k) => s + k.achievementRate) / kpis.length).toStringAsFixed(0)}%',
                    style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              // KPIs
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 1 : 4,
                  childAspectRatio: isMobile ? 2.5 : 1.8,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: kpis.length,
                itemBuilder: (_, i) => _KpiCard(kpi: kpis[i], provider: provider, memberColor: col),
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFF1E3040)),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _KpiCard extends StatefulWidget {
  final KpiModel kpi;
  final AppProvider provider;
  final Color? memberColor;
  const _KpiCard({required this.kpi, required this.provider, this.memberColor});

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _showTasks = false;

  @override
  Widget build(BuildContext context) {
    final kpi = widget.kpi;
    final provider = widget.provider;
    final rate = kpi.achievementRate.clamp(0, 100);
    final color = widget.memberColor ?? (rate >= 80 ? AppTheme.success : rate >= 60 ? AppTheme.warning : AppTheme.error);
    final tasks = provider.getTasksByKpiId(kpi.id);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: _showTasks
                ? const BorderRadius.vertical(top: Radius.circular(14))
                : BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(kpi.category, style: TextStyle(color: color, fontSize: 10)),
                ),
                const Spacer(),
                // 태스크 링크 버튼
                if (tasks.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _showTasks = !_showTasks),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.info.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.task_alt, color: AppTheme.info, size: 10),
                        const SizedBox(width: 3),
                        Text('${tasks.length}', style: const TextStyle(color: AppTheme.info, fontSize: 10)),
                        const SizedBox(width: 2),
                        Icon(_showTasks ? Icons.expand_less : Icons.expand_more,
                            color: AppTheme.info, size: 10),
                      ]),
                    ),
                  ),
                const SizedBox(width: 4),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert, color: AppTheme.textMuted, size: 16),
                  color: AppTheme.bgCard,
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('수정', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
                    const PopupMenuItem(value: 'delete', child: Text('삭제', style: TextStyle(color: AppTheme.error, fontSize: 13))),
                  ],
                  onSelected: (v) {
                    if (v == 'delete') provider.deleteKpi(kpi.id);
                    if (v == 'edit') {
                      showDialog(
                        context: context,
                        builder: (_) => KpiEditDialog(kpi: kpi, provider: provider),
                      );
                    }
                  },
                ),
              ]),
              Text(kpi.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: rate / 100,
                      backgroundColor: AppTheme.bgCardLight,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${rate.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
              Text(
                '${_fmtNum(kpi.current)}${kpi.unit} / ${_fmtNum(kpi.target)}${kpi.unit}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        // 태스크 패널 펼쳐짐
        if (_showTasks)
          Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: TaskLinkPanel(
              title: '연결 태스크',
              tasks: tasks,
              provider: provider,
              accentColor: color,
              compact: true,
            ),
          ),
      ],
    );
  }

  String _fmtNum(double v) {
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}억';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(0)}만';
    return v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }
}

// KPI Tracker Tab
class _KpiTrackerTab extends StatelessWidget {
  final AppProvider provider;
  const _KpiTrackerTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final selectedId = provider.selectedKpiTrackerId;
    final kpis = provider.kpis;
    final kpi = kpis.firstWhere((k) => k.id == selectedId, orElse: () => kpis.first);
    final records = provider.getMonthlyRecordsForKpi(selectedId);
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Selector (horizontal scrollable chips on mobile)
            const Text('KPI 선택', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kpis.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final k = kpis[i];
                  final isSelected = k.id == selectedId;
                  final rate = k.achievementRate.clamp(0, 100);
                  final color = rate >= 80 ? AppTheme.success : rate >= 60 ? AppTheme.warning : AppTheme.error;
                  return GestureDetector(
                    onTap: () => provider.selectKpiForTracker(k.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.mintPrimary.withValues(alpha: 0.15) : AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? AppTheme.mintPrimary : color.withValues(alpha: 0.4)),
                      ),
                      child: Text(k.title, style: TextStyle(
                        color: isSelected ? AppTheme.mintPrimary : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ), maxLines: 1),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // KPI Header
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kpi.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('${kpi.period} · ${kpi.category}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _KpiMiniStat(label: '목표', value: '${_fmtNum(kpi.target)}${kpi.unit}', color: AppTheme.textMuted),
                    _KpiMiniStat(label: '현재', value: '${_fmtNum(kpi.current)}${kpi.unit}', color: AppTheme.mintPrimary),
                    _KpiMiniStat(label: '달성률', value: '${kpi.achievementRate.toStringAsFixed(0)}%',
                        color: kpi.achievementRate >= 80 ? AppTheme.success : kpi.achievementRate >= 60 ? AppTheme.warning : AppTheme.error),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (records.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('이 KPI의 월별 데이터가 없습니다', style: TextStyle(color: AppTheme.textMuted)),
              ))
            else ...[
              // Line Chart
              Container(
                height: 200,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Text('목표 vs 실적 추이', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      Spacer(),
                      _ChartLegend(color: AppTheme.mintPrimary, label: '실적'),
                      SizedBox(width: 12),
                      _ChartLegend(color: AppTheme.textMuted, label: '목표'),
                    ]),
                    const SizedBox(height: 10),
                    Expanded(child: _KpiLineChart(records: records, kpi: kpi)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Bar Chart
              Container(
                height: 180,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('월별 달성률', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Expanded(child: _AchievementBarChart(records: records)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Table
              Container(
                decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1E3040)))),
                      child: Row(children: const [
                        Expanded(child: Text('월', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                        Expanded(child: Text('목표', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                        Expanded(child: Text('실적', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                        Expanded(child: Text('달성률', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                      ]),
                    ),
                    ...records.map((r) {
                      final color = r.achievementRate >= 80 ? AppTheme.success : r.achievementRate >= 60 ? AppTheme.warning : AppTheme.error;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1E3040)))),
                        child: Row(children: [
                          Expanded(child: Text(r.monthLabel, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
                          Expanded(child: Text('${_fmtNum(r.target)}${r.unit}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                          Expanded(child: Text('${_fmtNum(r.actual)}${r.unit}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11))),
                          Expanded(child: Text('${r.achievementRate.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600))),
                        ]),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Desktop layout (original)
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: KPI selector
          SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('KPI 선택', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: kpis.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final k = kpis[i];
                      final isSelected = k.id == selectedId;
                      final rate = k.achievementRate.clamp(0, 100);
                      final color = rate >= 80 ? AppTheme.success : rate >= 60 ? AppTheme.warning : AppTheme.error;
                      return InkWell(
                        onTap: () => provider.selectKpiForTracker(k.id),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.mintPrimary.withValues(alpha: 0.12) : AppTheme.bgCard,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSelected ? AppTheme.mintPrimary : Colors.transparent),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(k.title, style: TextStyle(color: isSelected ? AppTheme.mintPrimary : AppTheme.textSecondary, fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal), maxLines: 2),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: rate / 100,
                              backgroundColor: AppTheme.bgCardLight,
                              valueColor: AlwaysStoppedAnimation(color),
                              minHeight: 3,
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Right: Charts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KPI header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(kpi.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                      Text('${kpi.period} · ${kpi.category}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ]),
                    const Spacer(),
                    _KpiMiniStat(label: '목표', value: '${_fmtNum(kpi.target)}${kpi.unit}', color: AppTheme.textMuted),
                    const SizedBox(width: 24),
                    _KpiMiniStat(label: '현재', value: '${_fmtNum(kpi.current)}${kpi.unit}', color: AppTheme.mintPrimary),
                    const SizedBox(width: 24),
                    _KpiMiniStat(label: '달성률', value: '${kpi.achievementRate.toStringAsFixed(0)}%',
                        color: kpi.achievementRate >= 80 ? AppTheme.success : kpi.achievementRate >= 60 ? AppTheme.warning : AppTheme.error),
                  ]),
                ),
                const SizedBox(height: 16),
                if (records.isEmpty)
                  const Expanded(child: Center(child: Text('이 KPI의 월별 데이터가 없습니다', style: TextStyle(color: AppTheme.textMuted))))
                else
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Line chart
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(children: [
                                  Text('목표 vs 실적 추이', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                                  Spacer(),
                                  _ChartLegend(color: AppTheme.mintPrimary, label: '실적'),
                                  SizedBox(width: 12),
                                  _ChartLegend(color: AppTheme.textMuted, label: '목표'),
                                ]),
                                const SizedBox(height: 12),
                                Expanded(child: _KpiLineChart(records: records, kpi: kpi)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Bar chart
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('월별 달성률', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                Expanded(child: _AchievementBarChart(records: records)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                // Table
                if (records.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1E3040)))),
                          child: Row(children: [
                            const Expanded(child: Text('월', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                            const Expanded(child: Text('목표', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                            const Expanded(child: Text('실적', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                            const Expanded(child: Text('달성률', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                            const Expanded(child: Text('Gap', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                          ]),
                        ),
                        ...records.map((r) {
                          final color = r.achievementRate >= 80 ? AppTheme.success : r.achievementRate >= 60 ? AppTheme.warning : AppTheme.error;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1E3040)))),
                            child: Row(children: [
                              Expanded(child: Text(r.monthLabel, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
                              Expanded(child: Text('${_fmtNum(r.target)}${r.unit}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                              Expanded(child: Text('${_fmtNum(r.actual)}${r.unit}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
                              Expanded(child: Text('${r.achievementRate.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
                              Expanded(child: Text(
                                '${r.gap >= 0 ? '+' : ''}${_fmtNum(r.gap)}${r.unit}',
                                style: TextStyle(color: r.gap >= 0 ? AppTheme.success : AppTheme.error, fontSize: 12),
                              )),
                            ]),
                          );
                        }),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtNum(double v) {
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}억';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(0)}만';
    return v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }
}

class _KpiMiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _KpiMiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 12, height: 3, color: color),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
    ]);
  }
}

class _KpiLineChart extends StatelessWidget {
  final List<MonthlyKpiRecord> records;
  final KpiModel kpi;
  const _KpiLineChart({required this.records, required this.kpi});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox();
    final maxVal = records.fold(0.0, (m, r) => r.target > m ? r.target : r.actual > m ? r.actual : m);
    final minVal = records.fold(maxVal, (m, r) => r.actual < m ? r.actual : m) * 0.9;

    return LineChart(
      LineChartData(
        minY: minVal * 0.95,
        maxY: maxVal * 1.05,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFF1E3040), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= records.length) return const SizedBox();
              return Padding(padding: const EdgeInsets.only(top: 6), child: Text(records[i].monthLabel, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)));
            })),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 55,
            getTitlesWidget: (v, _) => Text(_shortNum(v), style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)))),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: records.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.actual)).toList(),
            isCurved: true,
            color: AppTheme.mintPrimary,
            barWidth: 2.5,
            dotData: FlDotData(show: true, getDotPainter: (s, _, __, i) {
              final r = records[i];
              return FlDotCirclePainter(
                radius: 4,
                color: r.isOnTrack ? AppTheme.success : AppTheme.error,
                strokeWidth: 2,
                strokeColor: AppTheme.bgCard,
              );
            }),
            belowBarData: BarAreaData(show: true, color: AppTheme.mintPrimary.withValues(alpha: 0.08)),
          ),
          LineChartBarData(
            spots: records.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.target)).toList(),
            isCurved: false,
            color: AppTheme.textMuted.withValues(alpha: 0.5),
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
            dashArray: [4, 4],
          ),
        ],
      ),
    );
  }

  static String _shortNum(double v) {
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(0)}억';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(0)}M';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(0)}만';
    return v.toStringAsFixed(0);
  }
}

class _AchievementBarChart extends StatelessWidget {
  final List<MonthlyKpiRecord> records;
  const _AchievementBarChart({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox();
    return BarChart(
      BarChartData(
        maxY: 130,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFF1E3040), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= records.length) return const SizedBox();
              return Padding(padding: const EdgeInsets.only(top: 4), child: Text(records[i].monthLabel, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)));
            })),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36,
            getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)))),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: records.asMap().entries.map((e) {
          final rate = e.value.achievementRate.clamp(0, 130).toDouble();
          final color = rate >= 100 ? AppTheme.success : rate >= 80 ? AppTheme.mintPrimary : rate >= 60 ? AppTheme.warning : AppTheme.error;
          return BarChartGroupData(
            x: e.key,
            barRods: [BarChartRodData(toY: rate, color: color, width: 18, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))],
          );
        }).toList(),
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(y: 100, color: AppTheme.success.withValues(alpha: 0.4), strokeWidth: 1, dashArray: [4, 4]),
        ]),
      ),
    );
  }
}
