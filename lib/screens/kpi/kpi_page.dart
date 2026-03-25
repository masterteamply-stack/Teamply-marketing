import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    _tab = TabController(length: 5, vsync: this);
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
    final selectedTeam = provider.selectedTeam;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      floatingActionButton: isMobile
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'fab_upload',
                  onPressed: () => _showCsvKpiUploadDialog(context, provider),
                  backgroundColor: AppTheme.bgCardLight,
                  child: const Icon(Icons.upload_file, color: AppTheme.mintPrimary, size: 20),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'fab_add',
                  onPressed: () => _showAddKpiDialog(context, provider),
                  backgroundColor: AppTheme.mintPrimary,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
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
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Text('KPI 관리', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 12),
                            if (selectedTeam != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Color(int.parse('0xFF${selectedTeam.colorHex.substring(1)}')).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Color(int.parse('0xFF${selectedTeam.colorHex.substring(1)}')).withValues(alpha: 0.4)),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(selectedTeam.iconEmoji, style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 4),
                                  Text(selectedTeam.name,
                                      style: TextStyle(color: Color(int.parse('0xFF${selectedTeam.colorHex.substring(1)}')), fontSize: 12, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ],
                          ]),
                          const SizedBox(height: 4),
                          const Text('선택된 팀의 KPI와 개인별 KPI 설정 및 추적', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                        ]),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showCsvKpiUploadDialog(context, provider),
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('CSV 업로드'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.bgCardLight, foregroundColor: AppTheme.textPrimary),
                      ),
                      const SizedBox(width: 8),
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
                    labelStyle: TextStyle(fontSize: isMobile ? 11 : 13),
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: const [
                      Tab(text: '팀 전략 KPI'),
                      Tab(text: '개인별 KPI'),
                      Tab(text: '전략 연결'),
                      Tab(text: '월별 트래커'),
                      Tab(text: '연도/분기 타깃'),
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
                  _StrategyLinkTab(provider: provider),
                  _KpiTrackerTab(provider: provider),
                  _YearlyQuarterlyTab(provider: provider),
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
    bool isTeamKpi = true;
    String? assignedTo;
    final categoryCtrl = TextEditingController(text: '매출');
    final unitCtrl = TextEditingController(text: '건');
    final suggestedCategories = ['매출', 'ROI', 'ROAS', '리드', 'CTR', 'SEO', '콘텐츠', 'SNS', '이메일', '광고', '전환', 'Subscribe', 'Engagement', 'Click', '배포율', '대응율', '완료율', '가입자수', '생성', '기타'];

    // 연도별 목표 입력 컨트롤러 (현재년 ~ 현재년+2)
    final now = DateTime.now();
    final years = [now.year - 1, now.year, now.year + 1, now.year + 2];
    final yearCtrls = {for (final y in years) '$y': TextEditingController()};

    // 분기별 목표 입력 컨트롤러 (현재년, 내년)
    final qYears = [now.year, now.year + 1];
    final quarterCtrls = <String, TextEditingController>{};
    for (final y in qYears) {
      for (int q = 1; q <= 4; q++) {
        quarterCtrls['$y-Q$q'] = TextEditingController();
      }
    }

    bool showYearlyTargets = false;
    bool showQuarterlyTargets = false;
    bool showLinkSection = false;
    String? selectedCampaignId;
    String? selectedFunnelStageKey;
    String? selectedDeliverableId;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.mintPrimary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.track_changes, color: AppTheme.mintPrimary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('KPI 추가', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
          ]),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 팀/개인 토글
                Container(
                  decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(10)),
                  child: SwitchListTile(
                    dense: true,
                    title: const Text('팀 KPI', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                    subtitle: const Text('팀 전체 공유 목표', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    value: isTeamKpi,
                    activeColor: AppTheme.mintPrimary,
                    onChanged: (v) => setState(() => isTeamKpi = v),
                  ),
                ),
                const SizedBox(height: 12),

                // KPI 이름
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'KPI 이름 *', hintText: '예: 분기 총 매출'),
                ),
                const SizedBox(height: 10),

                // 카테고리 (자유 입력 + 빠른 선택 칩)
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextField(
                    controller: categoryCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: '카테고리',
                      hintText: '예: 매출, Subscribe, 배포율 등 자유 입력',
                    ),
                    onChanged: (v) => setState(() => category = v),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: suggestedCategories.map((c) => GestureDetector(
                      onTap: () {
                        categoryCtrl.text = c;
                        setState(() => category = c);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (categoryCtrl.text == c) ? AppTheme.mintPrimary.withValues(alpha: 0.2) : AppTheme.bgCardLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (categoryCtrl.text == c) ? AppTheme.mintPrimary : const Color(0xFF1E3040),
                          ),
                        ),
                        child: Text(c, style: TextStyle(
                          color: (categoryCtrl.text == c) ? AppTheme.mintPrimary : AppTheme.textMuted,
                          fontSize: 10,
                        )),
                      ),
                    )).toList(),
                  ),
                ]),
                const SizedBox(height: 10),
                // 단위
                TextField(
                  controller: unitCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: '단위', hintText: '예: 원, %, 건, 명, USD, ea'),
                  onChanged: (v) => setState(() => unit = v.isEmpty ? '건' : v),
                ),
                const SizedBox(height: 10),

                // 목표/현재값 행
                Row(children: [
                  Expanded(child: TextField(
                    controller: targetCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '목표값 *'),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(
                    controller: currentCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '현재값'),
                  )),
                ]),
                const SizedBox(height: 10),

                // 담당자 (개인 KPI일 때)
                if (!isTeamKpi) ...[
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
                  const SizedBox(height: 10),
                ],

                const Divider(color: Color(0xFF1E3040)),
                const SizedBox(height: 4),

                // 캠페인/퍼널/Deliverable 연결 섹션
                InkWell(
                  onTap: () => setState(() => showLinkSection = !showLinkSection),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(showLinkSection ? Icons.expand_less : Icons.expand_more, color: AppTheme.mintPrimary, size: 18),
                      const SizedBox(width: 6),
                      const Text('전략 연결 설정 (선택)', style: TextStyle(color: AppTheme.mintPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.mintPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text('캠페인·퍼널·Deliverable', style: TextStyle(color: AppTheme.mintPrimary, fontSize: 10)),
                      ),
                    ]),
                  ),
                ),
                if (showLinkSection) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCardLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // 캠페인 연결
                      DropdownButtonFormField<String?>(
                        value: selectedCampaignId,
                        dropdownColor: AppTheme.bgCard,
                        decoration: const InputDecoration(
                          labelText: '연결 캠페인',
                          prefixIcon: Icon(Icons.campaign_outlined, color: AppTheme.textMuted, size: 16),
                        ),
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('없음', style: TextStyle(color: AppTheme.textMuted))),
                          ...provider.teamCampaigns.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name, style: const TextStyle(color: AppTheme.textPrimary)),
                          )),
                        ],
                        onChanged: (v) => setState(() => selectedCampaignId = v),
                      ),
                      const SizedBox(height: 10),
                      // 퍼널 단계 연결
                      DropdownButtonFormField<String?>(
                        value: selectedFunnelStageKey,
                        dropdownColor: AppTheme.bgCard,
                        decoration: const InputDecoration(
                          labelText: '퍼널 단계',
                          prefixIcon: Icon(Icons.filter_alt_outlined, color: AppTheme.textMuted, size: 16),
                        ),
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('없음', style: TextStyle(color: AppTheme.textMuted))),
                          DropdownMenuItem(value: 'awareness', child: Text('🌐 인지 (Awareness)')),
                          DropdownMenuItem(value: 'consideration', child: Text('🤔 고려 (Consideration)')),
                          DropdownMenuItem(value: 'conversion', child: Text('✅ 전환 (Conversion)')),
                          DropdownMenuItem(value: 'retention', child: Text('🔄 유지 (Retention)')),
                          DropdownMenuItem(value: 'advocacy', child: Text('📣 추천 (Advocacy)')),
                        ],
                        onChanged: (v) => setState(() => selectedFunnelStageKey = v),
                      ),
                      const SizedBox(height: 10),
                      // Deliverable 연결 (전략 프레임워크)
                      Builder(builder: (ctx) {
                        final fw = provider.selectedTeamId != null
                            ? provider.getFrameworkForTeam(provider.selectedTeamId!)
                            : null;
                        final deliverables = fw?.allDeliverables ?? [];
                        if (deliverables.isEmpty) {
                          return const Text('전략 프레임워크에 Deliverable이 없습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 11));
                        }
                        return DropdownButtonFormField<String?>(
                          value: selectedDeliverableId,
                          dropdownColor: AppTheme.bgCard,
                          decoration: const InputDecoration(
                            labelText: '전략 과제 (Deliverable)',
                            prefixIcon: Icon(Icons.account_tree_outlined, color: AppTheme.textMuted, size: 16),
                          ),
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('없음', style: TextStyle(color: AppTheme.textMuted))),
                            ...deliverables.map((d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(d.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                            )),
                          ],
                          onChanged: (v) => setState(() => selectedDeliverableId = v),
                        );
                      }),
                    ]),
                  ),
                  const SizedBox(height: 6),
                ],

                const Divider(color: Color(0xFF1E3040)),
                const SizedBox(height: 6),

                // 연도별 목표 섹션 토글
                InkWell(
                  onTap: () => setState(() => showYearlyTargets = !showYearlyTargets),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(showYearlyTargets ? Icons.expand_less : Icons.expand_more, color: AppTheme.info, size: 18),
                      const SizedBox(width: 6),
                      const Text('연도별 목표 설정 (선택)', style: TextStyle(color: AppTheme.info, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text('연간 트래킹', style: TextStyle(color: AppTheme.info, fontSize: 10)),
                      ),
                    ]),
                  ),
                ),
                if (showYearlyTargets) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1E3040))),
                    child: Column(children: years.map((y) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        SizedBox(
                          width: 60,
                          child: Text('$y년', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ),
                        Expanded(child: TextField(
                          controller: yearCtrls['$y'],
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '목표값 ($y년)',
                            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF1E3040))),
                          ),
                        )),
                      ]),
                    )).toList()),
                  ),
                  const SizedBox(height: 6),
                ],

                // 분기별 목표 섹션 토글
                InkWell(
                  onTap: () => setState(() => showQuarterlyTargets = !showQuarterlyTargets),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(showQuarterlyTargets ? Icons.expand_less : Icons.expand_more, color: AppTheme.warning, size: 18),
                      const SizedBox(width: 6),
                      const Text('분기별 목표 설정 (선택)', style: TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text('분기 트래킹', style: TextStyle(color: AppTheme.warning, fontSize: 10)),
                      ),
                    ]),
                  ),
                ),
                if (showQuarterlyTargets) ...[
                  const SizedBox(height: 8),
                  ...qYears.map((y) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1E3040))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$y년', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(children: List.generate(4, (qi) {
                        final key = '$y-Q${qi + 1}';
                        return Expanded(child: Padding(
                          padding: EdgeInsets.only(right: qi < 3 ? 8 : 0),
                          child: TextField(
                            controller: quarterCtrls[key],
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Q${qi + 1}',
                              labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF1E3040))),
                            ),
                          ),
                        ));
                      })),
                    ]),
                  )),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소', style: TextStyle(color: AppTheme.textMuted))),
            ElevatedButton.icon(
              onPressed: () {
                final title = titleCtrl.text.trim();
                final target = double.tryParse(targetCtrl.text.replaceAll(',', '')) ?? 0;
                if (title.isNotEmpty) {
                  // 연도별 목표 수집
                  final Map<String, double> yearlyTargets = {};
                  for (final y in years) {
                    final v = double.tryParse(yearCtrls['$y']?.text.replaceAll(',', '') ?? '');
                    if (v != null) yearlyTargets['$y'] = v;
                  }
                  // 분기별 목표 수집
                  final Map<String, double> quarterlyTargets = {};
                  quarterCtrls.forEach((k, ctrl) {
                    final v = double.tryParse(ctrl.text.replaceAll(',', '') ?? '');
                    if (v != null) quarterlyTargets[k] = v;
                  });

                  final finalCategory = categoryCtrl.text.trim().isEmpty ? '기타' : categoryCtrl.text.trim();
                  final finalUnit = unitCtrl.text.trim().isEmpty ? '건' : unitCtrl.text.trim();
                  provider.addKpi(KpiModel(
                    id: 'kpi_${DateTime.now().millisecondsSinceEpoch}',
                    title: title,
                    category: finalCategory,
                    target: target,
                    current: double.tryParse(currentCtrl.text.replaceAll(',', '')) ?? 0,
                    unit: finalUnit,
                    period: provider.selectedPeriod,
                    isTeamKpi: isTeamKpi,
                    assignedTo: assignedTo,
                    dueDate: DateTime(DateTime.now().year, 12, 31),
                    campaignId: selectedCampaignId,
                    funnelStageKey: selectedFunnelStageKey,
                    deliverableId: selectedDeliverableId,
                    yearlyTargets: yearlyTargets,
                    quarterlyTargets: quarterlyTargets,
                  ));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('✅ "$title" KPI가 추가되었습니다'),
                    backgroundColor: AppTheme.success,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ));
                }
              },
              icon: const Icon(Icons.add, size: 15),
              label: const Text('추가하기'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.mintPrimary, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _showCsvKpiUploadDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => _CsvKpiUploadDialog(provider: provider),
    );
  }
}

// ─── CSV KPI 업로드 다이얼로그 ───────────────────────────────────────────────
class _CsvKpiUploadDialog extends StatefulWidget {
  final AppProvider provider;
  const _CsvKpiUploadDialog({required this.provider});

  @override
  State<_CsvKpiUploadDialog> createState() => _CsvKpiUploadDialogState();
}

class _CsvKpiUploadDialogState extends State<_CsvKpiUploadDialog> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  List<Map<String, String>> _parsed = [];
  List<String> _parseErrors = [];
  bool _imported = false;
  String _detectedDelimiter = '';
  int _detectedCols = 0;

  // 사용자가 제공한 12개 항목 샘플
  static const _sampleCsv =
      'name\tcurrent\ttarget\tunit\tcategory\tdate\n'
      'SteerStar 리포지셔닝\t0\t100000\t\$\t매출\t2026-02-28\n'
      '고객사 스토리 협업 콘텐츠 강화\t48\t293\t명\tSubscribe\t2026-02-28\n'
      'Choice kit 확장 전개\t20\t100000\t\$\t매출\t2026-02-28\n'
      'O2O 마케팅 리드 연계\t100\t7259\t회\t리드\t2026-02-28\n'
      '신규시장 진입 마케팅 패키지 설계\t10\t100\t%\t배포율\t2026-02-28\n'
      'Value Proposition New arrivals\t20\t100\t%\t배포율\t2026-02-28\n'
      'Chago 프로모션 콘텐츠 강화\t20\t100\t%\t생성\t2026-02-28\n'
      '지역별 리스크 대응 자료 선제적 제공\t14\t80\t%\t대응율\t2026-02-28\n'
      'BizRewards 브랜딩 플랫폼으로 활용\t0\t29\tea\t가입자수\t2026-02-28\n'
      '데이터 기반 콘텐츠 마케팅\t403833\t142576866\t회\tEngagement\t2026-02-28\n'
      '소셜 광고 효율성 제고\t845045\t4180179\t회\tClick\t2026-02-28\n'
      '지역별 마케팅 메시지맵\t20\t100\t%\t완료율\t2026-02-28';

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
    // 다이얼로그 열리자마자 포커스 → 바로 붙여넣기 가능
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // 텍스트 변경 시 자동 파싱 (300ms 디바운스 효과)
  void _onTextChanged() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      if (_parsed.isNotEmpty || _parseErrors.isNotEmpty) {
        setState(() { _parsed = []; _parseErrors = []; _detectedDelimiter = ''; });
      }
      return;
    }
    _doParse(text);
  }

  void _doParse(String text) {
    final allLines = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty)
        .toList();
    if (allLines.isEmpty) return;

    final firstLine = allLines.first;
    final tabCount = '\t'.allMatches(firstLine).length;
    final commaCount = ','.allMatches(firstLine).length;
    final delimiter = tabCount >= commaCount && tabCount > 0 ? '\t' : ',';

    // 헤더 정규화
    final rawHeaders = _splitLine(firstLine, delimiter);
    final headers = rawHeaders.map((h) {
      var s = h.toLowerCase().trim().replaceAll('\ufeff', '');
      return s.replaceAll(' ', '').replaceAll('\t', '');
    }).toList();

    final hasNameCol = headers.contains('name') || headers.contains('title');

    // 헤더가 없으면 기본 컬럼 순서로 매핑
    final effectiveHeaders = hasNameCol
        ? headers
        : ['name', 'current', 'target', 'unit', 'category', 'date'];
    final startLine = hasNameCol ? 1 : 0;

    final rows = <Map<String, String>>[];
    final errors = <String>[];

    for (int i = startLine; i < allLines.length; i++) {
      final cells = _splitLine(allLines[i], delimiter);
      if (cells.every((c) => c.trim().isEmpty)) continue;

      final row = <String, String>{};
      for (int j = 0; j < effectiveHeaders.length; j++) {
        row[effectiveHeaders[j]] = j < cells.length ? cells[j].trim() : '';
      }

      final name = (row['name'] ?? row['title'] ?? '').trim();
      if (name.isEmpty) {
        errors.add('행 ${i + 1}: 이름이 비어 있음');
        continue;
      }

      // target 정리
      final targetStr = (row['target'] ?? '0').replaceAll(',', '').trim();
      if (targetStr.isNotEmpty && double.tryParse(targetStr) == null) {
        errors.add('행 ${i + 1}: target "$targetStr" → 0으로 처리');
        row['target'] = '0';
      }

      // current 정리
      final curStr = (row['current'] ?? '0').replaceAll(',', '').trim();
      if (curStr.isNotEmpty && double.tryParse(curStr) == null) {
        row['current'] = '0';
      }

      rows.add(row);
    }

    setState(() {
      _parsed = rows;
      _parseErrors = errors;
      _detectedDelimiter = delimiter == '\t' ? '탭(엑셀)' : '쉼표(CSV)';
      _detectedCols = headers.length;
    });
  }

  List<String> _splitLine(String line, [String delimiter = ',']) {
    if (delimiter == '\t') {
      return line.split('\t').map((s) => s.trim()).toList();
    }
    final result = <String>[];
    final buf = StringBuffer();
    bool inQuote = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuote && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"'); i++;
        } else {
          inQuote = !inQuote;
        }
      } else if (c == ',' && !inQuote) {
        result.add(buf.toString()); buf.clear();
      } else {
        buf.write(c);
      }
    }
    result.add(buf.toString());
    return result;
  }

  void _import() {
    if (_parsed.isEmpty) return;
    final errors = widget.provider.bulkAddKpisFromCsv(_parsed);
    setState(() { _imported = true; _parseErrors = errors; });
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 700;
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 20 : 40,
      ),
      child: SizedBox(
        width: isMobile ? double.infinity : 860,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(children: [
          _buildHeader(),
          Expanded(child: _imported ? _buildResult() : _buildBody(isMobile)),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1E3040)))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.mintPrimary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.upload_file, color: AppTheme.mintPrimary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('KPI 벌크 업로드',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          Text(
            '팀: ${widget.provider.selectedTeam?.name ?? "없음"}  •  엑셀/CSV 붙여넣기 또는 파일 형식으로 입력',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ])),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close, color: AppTheme.textMuted, size: 20),
        ),
      ]),
    );
  }

  Widget _buildBody(bool isMobile) {
    return isMobile ? _buildMobileBody() : _buildDesktopBody();
  }

  // ── 데스크탑: 좌우 2단 ──────────────────────────────────────
  Widget _buildDesktopBody() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 좌측: 입력 영역
      SizedBox(
        width: 400,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildInputGuide(),
          Expanded(child: _buildPasteArea()),
          _buildInputFooter(),
        ]),
      ),
      const VerticalDivider(width: 1, color: Color(0xFF1E3040)),
      // 우측: 미리보기
      Expanded(child: _parsed.isEmpty && _parseErrors.isEmpty
          ? _buildEmptyPreview()
          : _buildPreview()),
    ]);
  }

  // ── 모바일: 상하 분리 ───────────────────────────────────────
  Widget _buildMobileBody() {
    return Column(children: [
      _buildInputGuide(),
      SizedBox(height: 140, child: _buildPasteArea()),
      _buildInputFooter(),
      const Divider(color: Color(0xFF1E3040), height: 1),
      Expanded(child: _parsed.isEmpty && _parseErrors.isEmpty
          ? _buildEmptyPreview()
          : _buildPreview()),
    ]);
  }

  // ── 컬럼 가이드 + 샘플 버튼 ────────────────────────────────
  Widget _buildInputGuide() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 방법 안내 배너
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.mintPrimary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.lightbulb_outline, color: AppTheme.mintPrimary, size: 13),
              SizedBox(width: 6),
              Text('업로드 방법', style: TextStyle(color: AppTheme.mintPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            _tipRow('① 엑셀', '행 선택 후 Ctrl+C → 아래 입력창에 Ctrl+V'),
            _tipRow('② CSV', '헤더 포함 CSV 텍스트를 그대로 붙여넣기'),
            _tipRow('③ 자동인식', '탭/쉼표 구분자·헤더 유무 자동 감지'),
          ]),
        ),
        const SizedBox(height: 10),
        // 컬럼 가이드
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.info.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.info.withValues(alpha: 0.15)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.table_chart, color: AppTheme.info, size: 12),
              SizedBox(width: 6),
              Text('권장 컬럼 순서 (헤더 없어도 됨)', style: TextStyle(color: AppTheme.info, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _colChip('name', '이름*', AppTheme.mintPrimary),
                _colChip('current', '현재값', AppTheme.textMuted),
                _colChip('target', '목표값', AppTheme.warning),
                _colChip('unit', '단위', AppTheme.textMuted),
                _colChip('category', '카테고리', AppTheme.info),
                _colChip('date', '마감일', AppTheme.textMuted),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        // 샘플 불러오기
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () {
              _ctrl.text = _sampleCsv;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('샘플 12개가 입력되었습니다. 확인 후 등록하세요.'),
                backgroundColor: AppTheme.success,
                duration: Duration(seconds: 2),
              ));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.bgCardLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E3040)),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.content_paste, color: AppTheme.textMuted, size: 13),
                SizedBox(width: 6),
                Text('샘플 12개 불러오기', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ]),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(child: GestureDetector(
            onTap: () {
              _ctrl.clear();
              setState(() { _parsed = []; _parseErrors = []; _detectedDelimiter = ''; });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.bgCardLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E3040)),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.clear_all, color: AppTheme.textMuted, size: 13),
                SizedBox(width: 6),
                Text('초기화', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ]),
            ),
          )),
        ]),
      ]),
    );
  }

  Widget _tipRow(String label, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 52, child: Text(label,
            style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 11, fontWeight: FontWeight.w600))),
        Expanded(child: Text(desc,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11))),
      ]),
    );
  }

  Widget _colChip(String key, String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        Text(key, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 9)),
      ]),
    );
  }

  // ── 붙여넣기 입력창 ────────────────────────────────────────
  Widget _buildPasteArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('데이터 입력',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (_detectedDelimiter.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle, color: AppTheme.success, size: 10),
                const SizedBox(width: 3),
                Text('$_detectedDelimiter · ${_detectedCols}컬럼 인식',
                    style: const TextStyle(color: AppTheme.success, fontSize: 10)),
              ]),
            ),
        ]),
        const SizedBox(height: 6),
        Expanded(
          child: TextField(
            controller: _ctrl,
            focusNode: _focusNode,
            maxLines: null,
            expands: true,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontFamily: 'monospace',
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: '여기에 엑셀 데이터를 붙여넣으세요 (Ctrl+V)\n\n'
                  '엑셀: 원하는 셀 범위 선택 → Ctrl+C → 여기서 Ctrl+V\n'
                  'CSV: 헤더 포함 전체 텍스트 붙여넣기\n\n'
                  '헤더 없이 name,current,target,unit,category,date 순서로도 가능',
              hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.8),
              filled: true,
              fillColor: AppTheme.bgCardLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1E3040)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1E3040)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.mintPrimary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
      ]),
    );
  }

  // ── 하단 버튼 영역 ─────────────────────────────────────────
  Widget _buildInputFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton.icon(
          onPressed: _parsed.isNotEmpty ? _import : null,
          icon: Icon(
            _parsed.isNotEmpty ? Icons.cloud_upload : Icons.upload_file,
            size: 17,
          ),
          label: Text(
            _parsed.isNotEmpty ? '${_parsed.length}개 KPI 등록하기' : '데이터를 붙여넣으면 자동 파싱됩니다',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _parsed.isNotEmpty ? AppTheme.mintPrimary : AppTheme.bgCardLight,
            foregroundColor: _parsed.isNotEmpty ? Colors.white : AppTheme.textMuted,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }

  // ── 비어있는 미리보기 ──────────────────────────────────────
  Widget _buildEmptyPreview() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.content_paste_outlined,
            color: AppTheme.textMuted.withValues(alpha: 0.3), size: 52),
        const SizedBox(height: 14),
        const Text('엑셀/CSV 데이터를 붙여넣으면\n여기에 미리보기가 나타납니다',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.6)),
        const SizedBox(height: 20),
        // 엑셀 사용 방법 안내
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgCardLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1E3040)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('엑셀에서 복사하는 법',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _stepRow('1', '엑셀에서 헤더 행 포함 데이터 선택'),
            _stepRow('2', 'Ctrl+C (복사)'),
            _stepRow('3', '왼쪽 입력창 클릭 후 Ctrl+V (붙여넣기)'),
            _stepRow('4', '자동 파싱 → "등록하기" 버튼 클릭'),
          ]),
        ),
      ]),
    );
  }

  Widget _stepRow(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            color: AppTheme.mintPrimary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(num, style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11))),
      ]),
    );
  }

  // ── 파싱 결과 미리보기 ─────────────────────────────────────
  Widget _buildPreview() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 상태 바
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF1E3040))),
        ),
        child: Row(children: [
          // 성공 카운트
          if (_parsed.isNotEmpty) Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle, color: AppTheme.success, size: 13),
              const SizedBox(width: 4),
              Text('${_parsed.length}개 인식',
                  style: const TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
          if (_parseErrors.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('경고 ${_parseErrors.length}건',
                  style: const TextStyle(color: AppTheme.warning, fontSize: 12)),
            ),
          ],
          if (_parsed.isEmpty && _parseErrors.isNotEmpty) Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, color: AppTheme.error, size: 13),
              SizedBox(width: 4),
              Text('파싱 오류', style: TextStyle(color: AppTheme.error, fontSize: 12)),
            ]),
          ),
          const Spacer(),
          if (_detectedDelimiter.isNotEmpty)
            Text(_detectedDelimiter,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ]),
      ),
      // 오류 목록
      if (_parseErrors.isNotEmpty)
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _parseErrors.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber, color: AppTheme.warning, size: 12),
                const SizedBox(width: 5),
                Expanded(child: Text(e, style: const TextStyle(color: AppTheme.warning, fontSize: 11))),
              ]),
            )).toList(),
          ),
        ),
      // 카드 목록
      Expanded(
        child: _parsed.isEmpty
            ? const SizedBox()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: _parsed.length,
                itemBuilder: (_, i) => _KpiPreviewCard(row: _parsed[i], index: i),
              ),
      ),
    ]);
  }

  // ── 등록 완료 화면 ─────────────────────────────────────────
  Widget _buildResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: AppTheme.success, size: 52),
          ),
          const SizedBox(height: 20),
          Text('${_parsed.length}개 KPI 등록 완료!',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('${widget.provider.selectedTeam?.name ?? "현재 팀"}에 추가되었습니다',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
          if (_parseErrors.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(children: _parseErrors
                  .map((e) => Text(e, style: const TextStyle(color: AppTheme.warning, fontSize: 12)))
                  .toList()),
            ),
          ],
          const SizedBox(height: 28),
          Row(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton.icon(
              onPressed: () {
                setState(() { _imported = false; _parsed = []; _parseErrors = []; _ctrl.clear(); _detectedDelimiter = ''; });
              },
              icon: const Icon(Icons.add, size: 15),
              label: const Text('추가 업로드'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.mintPrimary,
                side: const BorderSide(color: AppTheme.mintPrimary),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 15),
              label: const Text('닫기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mintPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}


class _KpiPreviewCard extends StatelessWidget {
  final Map<String, String> row;
  final int index;
  const _KpiPreviewCard({required this.row, required this.index});

  @override
  Widget build(BuildContext context) {
    final name = row['name'] ?? row['title'] ?? '';
    final target = row['target'] ?? '';
    final current = row['current'] ?? '0';
    final unit = row['unit'] ?? '건';
    final category = row['category'] ?? '기타';
    final date = row['date'] ?? '';
    final targetVal = double.tryParse(target) ?? 0;
    final currentVal = double.tryParse(current) ?? 0;
    final rate = targetVal > 0 ? (currentVal / targetVal * 100).clamp(0.0, 100.0) : 0.0;
    final color = rate >= 80 ? AppTheme.success : rate >= 60 ? AppTheme.warning : AppTheme.info;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(4)),
            child: Center(child: Text('${index + 1}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9))),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
            child: Text(category, style: TextStyle(color: color, fontSize: 10)),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text('현재: $current$unit', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          const SizedBox(width: 12),
          Text('목표: $target$unit', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          if (date.isNotEmpty) ...[const SizedBox(width: 12), Icon(Icons.calendar_today_outlined, size: 10, color: AppTheme.textMuted), const SizedBox(width: 3), Text(date, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10))],
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(value: rate / 100, backgroundColor: AppTheme.bgCardLight, valueColor: AlwaysStoppedAnimation(color), minHeight: 4),
        ),
      ]),
    );
  }
}

// ─── Team KPI Tab ────────────────────────────────────────────────────────────
class _TeamKpiTab extends StatefulWidget {
  final AppProvider provider;
  const _TeamKpiTab({required this.provider});

  @override
  State<_TeamKpiTab> createState() => _TeamKpiTabState();
}

class _TeamKpiTabState extends State<_TeamKpiTab> {
  final Set<String> _selected = {};
  bool _selectMode = false;

  @override
  Widget build(BuildContext context) {
    // 현재 선택된 팀의 팀KPI만 표시
    final kpis = widget.provider.teamKpis;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('팀 전략 KPI (${kpis.length}개)', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const Spacer(),
            if (_selectMode && _selected.isNotEmpty) ...[
              ElevatedButton.icon(
                onPressed: () {
                  _showBulkDeleteConfirm(context, _selected.toList());
                },
                icon: const Icon(Icons.delete_outline, size: 14),
                label: Text('${_selected.length}개 삭제'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
              const SizedBox(width: 8),
            ],
            if (kpis.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() {
                  _selectMode = !_selectMode;
                  if (!_selectMode) _selected.clear();
                }),
                icon: Icon(_selectMode ? Icons.close : Icons.checklist, size: 14),
                label: Text(_selectMode ? '취소' : '선택 삭제', style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.textMuted),
              ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: kpis.isEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.track_changes_outlined, color: AppTheme.textMuted.withValues(alpha: 0.4), size: 48),
                      const SizedBox(height: 12),
                      const Text('이 팀의 KPI가 없습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                      const SizedBox(height: 6),
                      const Text('KPI 추가 버튼 또는 CSV 업로드로 KPI를 추가하세요', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ]),
                  )
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isMobile ? 1 : 3,
                      childAspectRatio: isMobile ? 2.2 : 1.6,
                      crossAxisSpacing: isMobile ? 10 : 16,
                      mainAxisSpacing: isMobile ? 10 : 16,
                    ),
                    itemCount: kpis.length,
                    itemBuilder: (_, i) => _KpiCard(
                      kpi: kpis[i], provider: widget.provider,
                      selectMode: _selectMode,
                      selected: _selected.contains(kpis[i].id),
                      onToggleSelect: (id) => setState(() {
                        if (_selected.contains(id)) _selected.remove(id);
                        else _selected.add(id);
                      }),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showBulkDeleteConfirm(BuildContext context, List<String> ids) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('KPI 일괄 삭제', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('선택한 ${ids.length}개의 KPI를 삭제하시겠습니까?', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              widget.provider.deleteKpisBulk(ids);
              setState(() { _selected.clear(); _selectMode = false; });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text('${ids.length}개 삭제', style: const TextStyle(color: Colors.white)),
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
    // 현재 선택된 팀의 개인 KPI만 필터링
    final teamId = provider.selectedTeamId;
    final members = teamId != null
        ? provider.allUsers.where((u) => provider.selectedTeam?.getMember(u.id) != null).toList()
        : provider.allUsers;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 자동 분류 안내 배너 ────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.auto_awesome, color: AppTheme.warning, size: 16),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('태스크 완료 → 개인 KPI 자동 반영',
                    style: TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                const Text('팀 프로젝트에서 태스크를 완료하면, 담당자의 개인 KPI current 값이 자동으로 업데이트됩니다.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                const Text('개인 KPI를 프로젝트에 연결하려면: 팀 프로젝트 → 전략 연결 탭 → KPI 연결',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ])),
            ]),
          ),
          ...members.map((u) {
          final kpis = provider.kpis.where((k) => !k.isTeamKpi && k.assignedTo == u.id &&
              (teamId == null || k.teamId == teamId)).toList();
          if (kpis.isEmpty) return const SizedBox();
          final col = u.avatarColor != null ? Color(int.parse('0xFF${u.avatarColor!.substring(1)}')) : AppTheme.mintPrimary;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 1 : 4,
                  childAspectRatio: isMobile ? 2.5 : 1.8,
                  crossAxisSpacing: 12, mainAxisSpacing: 12,
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
        ],
      ),
    );
  }
}

class _KpiCard extends StatefulWidget {
  final KpiModel kpi;
  final AppProvider provider;
  final Color? memberColor;
  final bool selectMode;
  final bool selected;
  final void Function(String)? onToggleSelect;
  const _KpiCard({required this.kpi, required this.provider, this.memberColor, this.selectMode = false, this.selected = false, this.onToggleSelect});

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

    return GestureDetector(
      onTap: widget.selectMode ? () => widget.onToggleSelect?.call(kpi.id) : null,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: _showTasks
                  ? const BorderRadius.vertical(top: Radius.circular(14))
                  : BorderRadius.circular(14),
              border: Border.all(
                color: widget.selected ? AppTheme.mintPrimary : color.withValues(alpha: 0.2),
                width: widget.selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  if (widget.selectMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        widget.selected ? Icons.check_box : Icons.check_box_outline_blank,
                        color: widget.selected ? AppTheme.mintPrimary : AppTheme.textMuted,
                        size: 16,
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                    child: Text(kpi.category, style: TextStyle(color: color, fontSize: 10)),
                  ),
                  const Spacer(),
                  // 태스크 링크 버튼
                  if (!widget.selectMode && tasks.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _showTasks = !_showTasks),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: AppTheme.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.task_alt, color: AppTheme.info, size: 10),
                          const SizedBox(width: 3),
                          Text('${tasks.length}', style: const TextStyle(color: AppTheme.info, fontSize: 10)),
                          const SizedBox(width: 2),
                          Icon(_showTasks ? Icons.expand_less : Icons.expand_more, color: AppTheme.info, size: 10),
                        ]),
                      ),
                    ),
                  if (!widget.selectMode) ...[
                    const SizedBox(width: 4),
                    // 직접 삭제 버튼
                    GestureDetector(
                      onTap: () => _confirmDelete(context, kpi, provider),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.delete_outline, color: AppTheme.error, size: 14),
                      ),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton(
                      icon: const Icon(Icons.more_vert, color: AppTheme.textMuted, size: 16),
                      color: AppTheme.bgCard,
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('수정', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
                      ],
                      onSelected: (v) {
                        if (v == 'edit') {
                          showDialog(context: context, builder: (_) => KpiEditDialog(kpi: kpi, provider: provider));
                        }
                      },
                    ),
                  ],
                ]),
                Text(kpi.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: rate / 100, backgroundColor: AppTheme.bgCardLight, valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${rate.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
                Text('${_fmtNum(kpi.current)}${kpi.unit} / ${_fmtNum(kpi.target)}${kpi.unit}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                // ── 연결 프로젝트/캠페인 배지 ────────────────
                if (kpi.projectId != null || kpi.campaignId != null) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 4, runSpacing: 4, children: [
                    if (kpi.projectId != null) Builder(builder: (_) {
                      final proj = provider.projectStore
                          .where((p) => p.id == kpi.projectId)
                          .firstOrNull;
                      if (proj == null) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.mintPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.folder_outlined, color: AppTheme.mintPrimary, size: 9),
                          const SizedBox(width: 3),
                          Text(proj.name, style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 9),
                              overflow: TextOverflow.ellipsis),
                        ]),
                      );
                    }),
                    if (kpi.campaignId != null) Builder(builder: (_) {
                      final c = provider.campaigns
                          .where((c) => c.id == kpi.campaignId)
                          .firstOrNull;
                      if (c == null) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.campaign_outlined, color: AppTheme.info, size: 9),
                          const SizedBox(width: 3),
                          Text(c.name, style: const TextStyle(color: AppTheme.info, fontSize: 9),
                              overflow: TextOverflow.ellipsis),
                        ]),
                      );
                    }),
                  ]),
                ],
              ],
            ),
          ),
          if (_showTasks)
            Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: TaskLinkPanel(title: '연결 태스크', tasks: tasks, provider: provider, accentColor: color, compact: true),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, KpiModel kpi, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('KPI 삭제', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('"${kpi.title}"을(를) 삭제하시겠습니까?', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              provider.deleteKpi(kpi.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"${kpi.title}" 삭제됨'), backgroundColor: AppTheme.error, duration: const Duration(seconds: 2)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
    // 현재 팀의 KPI만 표시
    final kpis = provider.currentTeamKpis.isNotEmpty ? provider.currentTeamKpis : provider.kpis;
    if (kpis.isEmpty) {
      return const Center(child: Text('KPI가 없습니다', style: TextStyle(color: AppTheme.textMuted)));
    }
    final kpi = kpis.firstWhere((k) => k.id == selectedId, orElse: () => kpis.first);
    final records = provider.getMonthlyRecordsForKpi(selectedId.isNotEmpty && kpis.any((k) => k.id == selectedId) ? selectedId : kpis.first.id);
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                final isSelected = k.id == kpi.id;
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
                    child: Text(k.title, style: TextStyle(color: isSelected ? AppTheme.mintPrimary : AppTheme.textSecondary, fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal), maxLines: 1),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(kpi.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              Text('${kpi.period} · ${kpi.category}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _KpiMiniStat(label: '목표', value: '${_fmtNum(kpi.target)}${kpi.unit}', color: AppTheme.textMuted),
                _KpiMiniStat(label: '현재', value: '${_fmtNum(kpi.current)}${kpi.unit}', color: AppTheme.mintPrimary),
                _KpiMiniStat(label: '달성률', value: '${kpi.achievementRate.toStringAsFixed(0)}%',
                    color: kpi.achievementRate >= 80 ? AppTheme.success : kpi.achievementRate >= 60 ? AppTheme.warning : AppTheme.error),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          if (records.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('이 KPI의 월별 데이터가 없습니다', style: TextStyle(color: AppTheme.textMuted))))
          else ...[
            Container(
              height: 200, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Text('목표 vs 실적 추이', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  Spacer(),
                  _ChartLegend(color: AppTheme.mintPrimary, label: '실적'),
                  SizedBox(width: 12),
                  _ChartLegend(color: AppTheme.textMuted, label: '목표'),
                ]),
                const SizedBox(height: 10),
                Expanded(child: _KpiLineChart(records: records, kpi: kpi)),
              ]),
            ),
            const SizedBox(height: 12),
            Container(
              height: 180, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('월별 달성률', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Expanded(child: _AchievementBarChart(records: records)),
              ]),
            ),
            const SizedBox(height: 12),
            _buildTable(records, kpi.unit, compact: true),
          ],
        ]),
      );
    }

    // Desktop layout
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 220,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('KPI 선택', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: kpis.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  final k = kpis[i];
                  final isSelected = k.id == kpi.id;
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
                        LinearProgressIndicator(value: rate / 100, backgroundColor: AppTheme.bgCardLight, valueColor: AlwaysStoppedAnimation(color), minHeight: 3),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [
                        Text('목표 vs 실적 추이', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                        Spacer(),
                        _ChartLegend(color: AppTheme.mintPrimary, label: '실적'),
                        SizedBox(width: 12),
                        _ChartLegend(color: AppTheme.textMuted, label: '목표'),
                      ]),
                      const SizedBox(height: 12),
                      Expanded(child: _KpiLineChart(records: records, kpi: kpi)),
                    ]),
                  )),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('월별 달성률', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Expanded(child: _AchievementBarChart(records: records)),
                    ]),
                  )),
                ]),
              ),
            const SizedBox(height: 16),
            if (records.isNotEmpty) _buildTable(records, kpi.unit),
          ]),
        ),
      ]),
    );
  }

  Widget _buildTable(List<MonthlyKpiRecord> records, String unit, {bool compact = false}) {
    return Container(
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1E3040)))),
            child: Row(children: [
              Expanded(child: Text('월', style: TextStyle(color: AppTheme.textMuted, fontSize: compact ? 11 : 12))),
              Expanded(child: Text('목표', style: TextStyle(color: AppTheme.textMuted, fontSize: compact ? 11 : 12))),
              Expanded(child: Text('실적', style: TextStyle(color: AppTheme.textMuted, fontSize: compact ? 11 : 12))),
              Expanded(child: Text('달성률', style: TextStyle(color: AppTheme.textMuted, fontSize: compact ? 11 : 12))),
              if (!compact) Expanded(child: Text('Gap', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
            ]),
          ),
          ...records.map((r) {
            final color = r.achievementRate >= 80 ? AppTheme.success : r.achievementRate >= 60 ? AppTheme.warning : AppTheme.error;
            return Container(
              padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1E3040)))),
              child: Row(children: [
                Expanded(child: Text(r.monthLabel, style: TextStyle(color: AppTheme.textSecondary, fontSize: compact ? 11 : 12))),
                Expanded(child: Text('${_fmtNum(r.target)}$unit', style: TextStyle(color: AppTheme.textMuted, fontSize: compact ? 11 : 12))),
                Expanded(child: Text('${_fmtNum(r.actual)}$unit', style: TextStyle(color: AppTheme.textPrimary, fontSize: compact ? 11 : 12))),
                Expanded(child: Text('${r.achievementRate.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: compact ? 11 : 12, fontWeight: FontWeight.w600))),
                if (!compact)
                  Expanded(child: Text(
                    '${r.gap >= 0 ? '+' : ''}${_fmtNum(r.gap)}$unit',
                    style: TextStyle(color: r.gap >= 0 ? AppTheme.success : AppTheme.error, fontSize: 12),
                  )),
              ]),
            );
          }),
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
        minY: minVal * 0.95, maxY: maxVal * 1.05,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFF1E3040), strokeWidth: 1)),
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
            isCurved: true, color: AppTheme.mintPrimary, barWidth: 2.5,
            dotData: FlDotData(show: true, getDotPainter: (s, _, __, i) {
              final r = records[i];
              return FlDotCirclePainter(radius: 4, color: r.isOnTrack ? AppTheme.success : AppTheme.error, strokeWidth: 2, strokeColor: AppTheme.bgCard);
            }),
            belowBarData: BarAreaData(show: true, color: AppTheme.mintPrimary.withValues(alpha: 0.08)),
          ),
          LineChartBarData(
            spots: records.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.target)).toList(),
            isCurved: false, color: AppTheme.textMuted.withValues(alpha: 0.5), barWidth: 1.5,
            dotData: const FlDotData(show: false), dashArray: [4, 4],
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
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFF1E3040), strokeWidth: 1)),
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
          return BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: rate, color: color, width: 18, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]);
        }).toList(),
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(y: 100, color: AppTheme.success.withValues(alpha: 0.4), strokeWidth: 1, dashArray: [4, 4]),
        ]),
      ),
    );
  }
}

// ─── 연도/분기 타깃 트래커 탭 ─────────────────────────────────────────────────
class _YearlyQuarterlyTab extends StatefulWidget {
  final AppProvider provider;
  const _YearlyQuarterlyTab({required this.provider});

  @override
  State<_YearlyQuarterlyTab> createState() => _YearlyQuarterlyTabState();
}

class _YearlyQuarterlyTabState extends State<_YearlyQuarterlyTab> {
  String? _selectedKpiId;
  String _viewMode = 'yearly'; // 'yearly' or 'quarterly'

  static String _fmtNum(double v) {
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}억';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(0)}만';
    return v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final kpis = provider.currentTeamKpis.isNotEmpty ? provider.currentTeamKpis : provider.kpis;
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (kpis.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.calendar_today_outlined, color: AppTheme.textMuted.withValues(alpha: 0.3), size: 48),
          const SizedBox(height: 12),
          const Text('KPI가 없습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
          const SizedBox(height: 6),
          const Text('KPI를 추가하고 연도/분기별 목표를 설정하세요', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ]),
      );
    }

    final selectedKpi = _selectedKpiId != null
        ? kpis.firstWhere((k) => k.id == _selectedKpiId, orElse: () => kpis.first)
        : kpis.first;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: isMobile
          ? _buildMobileLayout(kpis, selectedKpi)
          : _buildDesktopLayout(kpis, selectedKpi),
    );
  }

  Widget _buildDesktopLayout(List<KpiModel> kpis, KpiModel selectedKpi) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 좌측: KPI 목록
      SizedBox(
        width: 220,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('KPI 선택', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: kpis.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) {
                final k = kpis[i];
                final isSelected = k.id == selectedKpi.id;
                final hasYearly = k.yearlyTargets.isNotEmpty;
                final hasQuarterly = k.quarterlyTargets.isNotEmpty;
                return InkWell(
                  onTap: () => setState(() => _selectedKpiId = k.id),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.mintPrimary.withValues(alpha: 0.12) : AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? AppTheme.mintPrimary : Colors.transparent),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(k.title, style: TextStyle(
                        color: isSelected ? AppTheme.mintPrimary : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ), maxLines: 2),
                      const SizedBox(height: 4),
                      Row(children: [
                        if (hasYearly) Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: AppTheme.info.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                          child: const Text('연', style: TextStyle(color: AppTheme.info, fontSize: 9)),
                        ),
                        if (hasYearly) const SizedBox(width: 3),
                        if (hasQuarterly) Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                          child: const Text('분', style: TextStyle(color: AppTheme.warning, fontSize: 9)),
                        ),
                        if (!hasYearly && !hasQuarterly)
                          Text(k.category, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                      ]),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
      const SizedBox(width: 20),
      // 우측: 상세 트래커
      Expanded(child: _buildTrackerDetail(selectedKpi)),
    ]);
  }

  Widget _buildMobileLayout(List<KpiModel> kpis, KpiModel selectedKpi) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // KPI 선택 가로 스크롤
      SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: kpis.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final k = kpis[i];
            final isSelected = k.id == selectedKpi.id;
            return GestureDetector(
              onTap: () => setState(() => _selectedKpiId = k.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.mintPrimary.withValues(alpha: 0.15) : AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? AppTheme.mintPrimary : const Color(0xFF1E3040)),
                ),
                child: Text(k.title, style: TextStyle(
                  color: isSelected ? AppTheme.mintPrimary : AppTheme.textMuted,
                  fontSize: 11,
                ), maxLines: 1),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      Expanded(child: SingleChildScrollView(child: _buildTrackerDetail(selectedKpi))),
    ]);
  }

  Widget _buildTrackerDetail(KpiModel kpi) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // KPI 헤더 카드
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(kpi.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.mintPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                child: Text(kpi.category, style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 10)),
              ),
              const SizedBox(width: 6),
              Text('현재: ${_fmtNum(kpi.current)}${kpi.unit} / 목표: ${_fmtNum(kpi.target)}${kpi.unit}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ]),
          ])),
          // 편집 버튼
          IconButton(
            onPressed: () => _showEditTargetsDialog(context, kpi),
            icon: const Icon(Icons.edit_note, size: 18),
            tooltip: '연도/분기 목표·실적 수정',
            style: IconButton.styleFrom(
              foregroundColor: AppTheme.textMuted,
              backgroundColor: AppTheme.bgCardLight,
              padding: const EdgeInsets.all(8),
            ),
          ),
          const SizedBox(width: 8),
          // 뷰 모드 전환
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: () => setState(() => _viewMode = 'yearly'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _viewMode == 'yearly' ? AppTheme.info : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('연도별', style: TextStyle(
                    color: _viewMode == 'yearly' ? Colors.white : AppTheme.textMuted,
                    fontSize: 11, fontWeight: FontWeight.w600,
                  )),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _viewMode = 'quarterly'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _viewMode == 'quarterly' ? AppTheme.warning : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('분기별', style: TextStyle(
                    color: _viewMode == 'quarterly' ? Colors.white : AppTheme.textMuted,
                    fontSize: 11, fontWeight: FontWeight.w600,
                  )),
                ),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),

      if (_viewMode == 'yearly') _buildYearlyView(kpi),
      if (_viewMode == 'quarterly') _buildQuarterlyView(kpi),
    ]);
  }

  /// 연도/분기 목표 및 실적 편집 다이얼로그
  void _showEditTargetsDialog(BuildContext context, KpiModel kpi) {
    final now = DateTime.now();
    final years = [now.year - 1, now.year, now.year + 1, now.year + 2];
    final qYears = [now.year - 1, now.year, now.year + 1];

    // 컨트롤러 초기화 (기존 값으로)
    final yearTargetCtrls = <String, TextEditingController>{};
    final yearActualCtrls = <String, TextEditingController>{};
    for (final y in years) {
      final yt = kpi.yearlyTargets['$y'];
      yearTargetCtrls['$y'] = TextEditingController(text: yt != null ? _fmtNum(yt) : '');
      // 연간 실적은 분기 합계로 표시 (현재년은 current 값)
      final yearActual = y == now.year
          ? kpi.current
          : kpi.quarterlyActuals.entries.where((e) => e.key.startsWith('$y')).fold(0.0, (s, e) => s + e.value);
      yearActualCtrls['$y'] = TextEditingController(text: yearActual > 0 ? _fmtNum(yearActual) : '');
    }

    final qTargetCtrls = <String, TextEditingController>{};
    final qActualCtrls = <String, TextEditingController>{};
    for (final y in qYears) {
      for (int q = 1; q <= 4; q++) {
        final key = '$y-Q$q';
        qTargetCtrls[key] = TextEditingController(
          text: kpi.quarterlyTargets[key] != null ? _fmtNum(kpi.quarterlyTargets[key]!) : '',
        );
        qActualCtrls[key] = TextEditingController(
          text: kpi.quarterlyActuals[key] != null ? _fmtNum(kpi.quarterlyActuals[key]!) : '',
        );
      }
    }

    String editTab = 'yearly';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.edit_note, color: AppTheme.info, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text('목표/실적 입력: ${kpi.title}',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
          ]),
          content: SizedBox(
            width: 560,
            height: MediaQuery.of(context).size.height * 0.65,
            child: Column(children: [
              // 탭 전환
              Container(
                decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.all(3),
                child: Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => setDlgState(() => editTab = 'yearly'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: editTab == 'yearly' ? AppTheme.info : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text('연도별', style: TextStyle(
                        color: editTab == 'yearly' ? Colors.white : AppTheme.textMuted,
                        fontSize: 12, fontWeight: FontWeight.w600,
                      )),
                    ),
                  )),
                  Expanded(child: GestureDetector(
                    onTap: () => setDlgState(() => editTab = 'quarterly'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: editTab == 'quarterly' ? AppTheme.warning : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text('분기별', style: TextStyle(
                        color: editTab == 'quarterly' ? Colors.white : AppTheme.textMuted,
                        fontSize: 12, fontWeight: FontWeight.w600,
                      )),
                    ),
                  )),
                ]),
              ),
              const SizedBox(height: 12),
              // 안내 텍스트
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: AppTheme.info, size: 13),
                  const SizedBox(width: 6),
                  Text(
                    editTab == 'yearly'
                        ? '연도별 목표와 실제 달성 실적을 입력하세요 (단위: ${kpi.unit})'
                        : '분기별 목표와 실제 달성 실적을 입력하세요 (단위: ${kpi.unit})',
                    style: const TextStyle(color: AppTheme.info, fontSize: 11),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              // 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(children: [
                  SizedBox(width: editTab == 'yearly' ? 60 : 80,
                    child: Text(editTab == 'yearly' ? '연도' : '분기',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                  const Expanded(child: Text('목표', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('실적', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                ]),
              ),
              const SizedBox(height: 6),
              // 입력 필드 목록
              Expanded(child: SingleChildScrollView(
                child: editTab == 'yearly'
                    ? Column(children: years.map((y) {
                        final isCurrentYear = y == now.year;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCurrentYear ? AppTheme.info.withValues(alpha: 0.06) : AppTheme.bgCardLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isCurrentYear ? AppTheme.info.withValues(alpha: 0.3) : const Color(0xFF1E3040)),
                          ),
                          child: Row(children: [
                            SizedBox(width: 60, child: Text(
                              '$y년${isCurrentYear ? "\n(현재)" : ""}',
                              style: TextStyle(
                                color: isCurrentYear ? AppTheme.info : AppTheme.textSecondary,
                                fontSize: 11, fontWeight: isCurrentYear ? FontWeight.w600 : FontWeight.normal,
                              ),
                            )),
                            Expanded(child: TextField(
                              controller: yearTargetCtrls['$y'],
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: '목표 ${kpi.unit}',
                                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF1E3040))),
                              ),
                            )),
                            const SizedBox(width: 8),
                            Expanded(child: TextField(
                              controller: yearActualCtrls['$y'],
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: '실적 ${kpi.unit}',
                                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF1E3040))),
                              ),
                            )),
                          ]),
                        );
                      }).toList())
                    : Column(children: qYears.expand((y) {
                        return [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(children: [
                              Text('$y년', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                              if (y == now.year) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(color: AppTheme.mintPrimary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                                  child: const Text('현재', style: TextStyle(color: AppTheme.mintPrimary, fontSize: 9)),
                                ),
                              ],
                            ]),
                          ),
                          ...List.generate(4, (qi) {
                            final key = '$y-Q${qi + 1}';
                            final isCurrentQ = y == now.year && qi + 1 == ((now.month - 1) ~/ 3) + 1;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isCurrentQ ? AppTheme.warning.withValues(alpha: 0.06) : AppTheme.bgCardLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isCurrentQ ? AppTheme.warning.withValues(alpha: 0.3) : const Color(0xFF1E3040)),
                              ),
                              child: Row(children: [
                                SizedBox(width: 80, child: Text(
                                  'Q${qi + 1}${isCurrentQ ? " ●" : ""}',
                                  style: TextStyle(
                                    color: isCurrentQ ? AppTheme.warning : AppTheme.textSecondary,
                                    fontSize: 12, fontWeight: isCurrentQ ? FontWeight.w700 : FontWeight.normal,
                                  ),
                                )),
                                Expanded(child: TextField(
                                  controller: qTargetCtrls[key],
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    hintText: '목표',
                                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF1E3040))),
                                  ),
                                )),
                                const SizedBox(width: 8),
                                Expanded(child: TextField(
                                  controller: qActualCtrls[key],
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    hintText: '실적',
                                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF1E3040))),
                                  ),
                                )),
                              ]),
                            );
                          }),
                          const SizedBox(height: 8),
                        ];
                      }).toList()),
              )),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                // 연도별 목표 수집
                final newYearlyTargets = Map<String, double>.from(kpi.yearlyTargets);
                final newYearlyActuals = Map<String, double>.from(kpi.quarterlyActuals); // 연간 실적은 분기 실적에 반영
                for (final y in years) {
                  final t = double.tryParse(yearTargetCtrls['$y']!.text.replaceAll(',', ''));
                  if (t != null) newYearlyTargets['$y'] = t;
                  // 연간 실적 = 현재 KPI 값 업데이트 (현재년만)
                }

                // 분기별 목표/실적 수집
                final newQTargets = Map<String, double>.from(kpi.quarterlyTargets);
                final newQActuals = Map<String, double>.from(kpi.quarterlyActuals);
                for (final y in qYears) {
                  for (int q = 1; q <= 4; q++) {
                    final key = '$y-Q$q';
                    final t = double.tryParse(qTargetCtrls[key]!.text.replaceAll(',', ''));
                    final a = double.tryParse(qActualCtrls[key]!.text.replaceAll(',', ''));
                    if (t != null) newQTargets[key] = t;
                    if (a != null) newQActuals[key] = a;
                  }
                }

                // 현재 실적 업데이트 (현재년도 연간 실적 입력 시)
                double newCurrent = kpi.current;
                final currentYearActual = double.tryParse(yearActualCtrls['${now.year}']!.text.replaceAll(',', ''));
                if (currentYearActual != null) newCurrent = currentYearActual;

                final updated = kpi.copyWith(
                  current: newCurrent,
                  yearlyTargets: newYearlyTargets,
                  quarterlyTargets: newQTargets,
                  quarterlyActuals: newQActuals,
                );
                widget.provider.updateKpi(updated);
                Navigator.pop(ctx);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('✅ 목표/실적이 저장되었습니다'),
                  backgroundColor: AppTheme.success,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ));
              },
              icon: const Icon(Icons.save, size: 15),
              label: const Text('저장'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.mintPrimary, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearlyView(KpiModel kpi) {
    final now = DateTime.now();
    final years = <String>{};
    years.addAll(kpi.yearlyTargets.keys);
    // 현재년 ~ +2년 항상 표시
    for (int i = -1; i <= 2; i++) {
      years.add('${now.year + i}');
    }
    final sortedYears = years.toList()..sort();

    if (kpi.yearlyTargets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Icon(Icons.bar_chart_outlined, color: AppTheme.info.withValues(alpha: 0.4), size: 40),
          const SizedBox(height: 10),
          const Text('연도별 목표가 설정되지 않았습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          const SizedBox(height: 6),
          const Text('KPI 추가 다이얼로그에서 "연도별 목표 설정"을 입력하세요', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ]),
      );
    }

    return Column(children: [
      // 연도별 목표 테이블
      Container(
        decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1E3040)))),
            child: Row(children: [
              Expanded(child: Text('연도', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
              Expanded(child: Text('목표', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
              Expanded(child: Text('현재 실적', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
              Expanded(child: Text('달성률', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
              Expanded(child: Text('GAP', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
            ]),
          ),
          ...sortedYears.map((yr) {
            final target = kpi.yearlyTargets[yr] ?? (yr == '${now.year}' ? kpi.target : 0);
            final isCurrentYear = yr == '${now.year}';
            final actual = isCurrentYear ? kpi.current : (kpi.quarterlyActuals.entries
                .where((e) => e.key.startsWith(yr))
                .fold(0.0, (s, e) => s + e.value));
            final rate = target > 0 ? (actual / target * 100).clamp(0, 200) : 0.0;
            final gap = actual - target;
            final color = rate >= 100 ? AppTheme.success : rate >= 80 ? AppTheme.mintPrimary : rate >= 60 ? AppTheme.warning : AppTheme.error;
            final isFuture = int.tryParse(yr)! > now.year;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrentYear ? AppTheme.mintPrimary.withValues(alpha: 0.05) : Colors.transparent,
                border: const Border(bottom: BorderSide(color: Color(0xFF1E3040))),
              ),
              child: Row(children: [
                Expanded(child: Row(children: [
                  Text(yr, style: TextStyle(
                    color: isCurrentYear ? AppTheme.mintPrimary : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: isCurrentYear ? FontWeight.w700 : FontWeight.normal,
                  )),
                  if (isCurrentYear) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: AppTheme.mintPrimary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: const Text('현재', style: TextStyle(color: AppTheme.mintPrimary, fontSize: 9)),
                    ),
                  ],
                ])),
                Expanded(child: Text(
                  target > 0 ? '${_fmtNum(target)}${kpi.unit}' : '-',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                )),
                Expanded(child: Text(
                  isFuture ? '-' : '${_fmtNum(actual)}${kpi.unit}',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                )),
                Expanded(child: isFuture || target == 0
                    ? const Text('-', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))
                    : Row(children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: (rate / 100).clamp(0, 1),
                              backgroundColor: AppTheme.bgCardLight,
                              valueColor: AlwaysStoppedAnimation(color),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${rate.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                ),
                Expanded(child: isFuture || target == 0
                    ? const Text('-', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))
                    : Text(
                        '${gap >= 0 ? '+' : ''}${_fmtNum(gap)}${kpi.unit}',
                        style: TextStyle(color: gap >= 0 ? AppTheme.success : AppTheme.error, fontSize: 12),
                      )),
              ]),
            );
          }),
        ]),
      ),
    ]);
  }

  Widget _buildQuarterlyView(KpiModel kpi) {
    final now = DateTime.now();
    final qYears = [now.year - 1, now.year, now.year + 1];
    final quarters = ['Q1', 'Q2', 'Q3', 'Q4'];

    if (kpi.quarterlyTargets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Icon(Icons.pie_chart_outline, color: AppTheme.warning.withValues(alpha: 0.4), size: 40),
          const SizedBox(height: 10),
          const Text('분기별 목표가 설정되지 않았습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          const SizedBox(height: 6),
          const Text('KPI 추가 다이얼로그에서 "분기별 목표 설정"을 입력하세요', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: qYears.map((yr) {
        final hasData = quarters.any((q) => kpi.quarterlyTargets.containsKey('$yr-$q'));
        if (!hasData && yr != now.year) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1E3040)))),
                child: Row(children: [
                  Text('$yr년', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                  if (yr == now.year) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.mintPrimary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: const Text('현재', style: TextStyle(color: AppTheme.mintPrimary, fontSize: 10)),
                    ),
                  ],
                  const Spacer(),
                  // 연도 합계
                  Text(
                    '연간 합계 목표: ${_fmtNum(quarters.fold(0.0, (s, q) => s + (kpi.quarterlyTargets['$yr-$q'] ?? 0)))}${kpi.unit}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: quarters.asMap().entries.map((e) {
                  final q = e.value;
                  final key = '$yr-$q';
                  final target = kpi.quarterlyTargets[key] ?? 0;
                  final actual = kpi.quarterlyActuals[key] ?? 0;
                  final qNum = e.key + 1;
                  final isCurrentQ = yr == now.year && qNum == ((now.month - 1) ~/ 3) + 1;
                  final isFuture = yr > now.year || (yr == now.year && qNum > ((now.month - 1) ~/ 3) + 1);
                  final rate = target > 0 ? (actual / target * 100).clamp(0, 200) : 0.0;
                  final color = rate >= 100 ? AppTheme.success : rate >= 80 ? AppTheme.mintPrimary : rate >= 60 ? AppTheme.warning : AppTheme.error;

                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: e.key < 3 ? 10 : 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCurrentQ
                            ? AppTheme.mintPrimary.withValues(alpha: 0.08)
                            : AppTheme.bgCardLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCurrentQ ? AppTheme.mintPrimary.withValues(alpha: 0.3) : const Color(0xFF1E3040),
                        ),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(q, style: TextStyle(
                            color: isCurrentQ ? AppTheme.mintPrimary : AppTheme.textSecondary,
                            fontSize: 13, fontWeight: FontWeight.w700,
                          )),
                          if (isCurrentQ) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: AppTheme.mintPrimary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                              child: const Text('진행중', style: TextStyle(color: AppTheme.mintPrimary, fontSize: 8)),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 6),
                        Text(
                          target > 0 ? '${_fmtNum(target)}${kpi.unit}' : '미설정',
                          style: TextStyle(color: target > 0 ? AppTheme.textSecondary : AppTheme.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isFuture ? '예정' : '${_fmtNum(actual)}${kpi.unit}',
                          style: TextStyle(
                            color: isFuture ? AppTheme.textMuted : AppTheme.textPrimary,
                            fontSize: 12, fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!isFuture && target > 0) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: (rate / 100).clamp(0, 1),
                              backgroundColor: AppTheme.bgCard,
                              valueColor: AlwaysStoppedAnimation(color),
                              minHeight: 4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${rate.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                        ] else ...[
                          Text(
                            target == 0 ? '목표 미입력' : '목표: ${_fmtNum(target)}${kpi.unit}',
                            style: TextStyle(color: AppTheme.textMuted.withValues(alpha: target == 0 ? 0.5 : 1.0), fontSize: 9),
                          ),
                        ],
                      ]),
                    ),
                  );
                }).toList()),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════
//  전략 연결 탭 – 마케팅 퍼널 도식화 + 전략-KPI-프로젝트 연결 뷰
// ════════════════════════════════════════════════════════
class _StrategyLinkTab extends StatefulWidget {
  final AppProvider provider;
  const _StrategyLinkTab({required this.provider});
  @override
  State<_StrategyLinkTab> createState() => _StrategyLinkTabState();
}

class _StrategyLinkTabState extends State<_StrategyLinkTab>
    with SingleTickerProviderStateMixin {
  late TabController _subTab;
  String? _selectedObjectiveId;

  @override
  void initState() {
    super.initState();
    _subTab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _subTab.dispose();
    super.dispose();
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('0xFF${hex.replaceAll('#', '')}'));
    } catch (_) {
      return AppTheme.mintPrimary;
    }
  }

  String _funnelLabel(String? key) {
    switch (key) {
      case 'awareness': return '🌐 인지';
      case 'consideration': return '🤔 고려';
      case 'conversion': return '✅ 전환';
      case 'retention': return '🔄 유지';
      case 'advocacy': return '📣 추천';
      default: return key ?? '-';
    }
  }

  Color _funnelColor(String? key) {
    switch (key) {
      case 'awareness': return const Color(0xFF29B6F6);
      case 'consideration': return const Color(0xFFAB47BC);
      case 'conversion': return const Color(0xFF66BB6A);
      case 'retention': return const Color(0xFFFFB300);
      case 'advocacy': return const Color(0xFFFF7043);
      default: return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final teamId = provider.selectedTeamId;

    if (teamId == null) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.group_outlined, color: AppTheme.textMuted, size: 48),
          SizedBox(height: 12),
          Text('팀을 먼저 선택해주세요', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
        ]),
      );
    }

    final fw = provider.getFrameworkForTeam(teamId);
    final kpis = provider.getKpisForTeam(teamId);
    final campaigns = provider.teamCampaigns;

    return Column(
      children: [
        // 서브탭 헤더
        Container(
          color: AppTheme.bgCard,
          child: TabBar(
            controller: _subTab,
            labelColor: AppTheme.mintPrimary,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.mintPrimary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: '🔀 마케팅 퍼널 & 전략'),
              Tab(text: '🌲 전략 트리 & KPI 연결'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _subTab,
            children: [
              // ── 탭1: 마케팅 퍼널 도식화 ─────────────────────
              _FunnelStrategyView(
                provider: provider,
                fw: fw,
                kpis: kpis,
                campaigns: campaigns,
                funnelLabel: _funnelLabel,
                funnelColor: _funnelColor,
                hexColor: _hexColor,
              ),
              // ── 탭2: 전략 트리 & KPI 연결 ────────────────────
              _StrategyTreeView(
                provider: provider,
                fw: fw,
                kpis: kpis,
                campaigns: campaigns,
                funnelLabel: _funnelLabel,
                hexColor: _hexColor,
                selectedObjectiveId: _selectedObjectiveId,
                onObjectiveSelected: (id) => setState(() => _selectedObjectiveId = id),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 마케팅 퍼널 도식화 뷰 ─────────────────────────────────
class _FunnelStrategyView extends StatelessWidget {
  final AppProvider provider;
  final StrategyFramework? fw;
  final List<KpiModel> kpis;
  final List<CampaignModel> campaigns;
  final String Function(String?) funnelLabel;
  final Color Function(String?) funnelColor;
  final Color Function(String) hexColor;

  const _FunnelStrategyView({
    required this.provider,
    required this.fw,
    required this.kpis,
    required this.campaigns,
    required this.funnelLabel,
    required this.funnelColor,
    required this.hexColor,
  });

  static const List<Map<String, dynamic>> _stages = [
    {'key': 'awareness',     'label': '인지',   'icon': Icons.visibility_outlined,  'color': 0xFF29B6F6, 'desc': 'Brand Awareness & Reach'},
    {'key': 'consideration', 'label': '고려',   'icon': Icons.search_outlined,       'color': 0xFFAB47BC, 'desc': 'Engagement & Evaluation'},
    {'key': 'conversion',    'label': '전환',   'icon': Icons.check_circle_outline,  'color': 0xFF66BB6A, 'desc': 'Lead → Customer'},
    {'key': 'retention',     'label': '유지',   'icon': Icons.loop_outlined,         'color': 0xFFFFB300, 'desc': 'Loyalty & Upsell'},
    {'key': 'advocacy',      'label': '추천',   'icon': Icons.campaign_outlined,     'color': 0xFFFF7043, 'desc': 'Referral & Ambassador'},
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 퍼널 도식
        _buildFunnelDiagram(context, isMobile),
        const SizedBox(height: 24),

        // 퍼널 단계별 KPI & 캠페인 카드
        ..._stages.map((stage) => _buildStageSection(context, stage, isMobile)),

        // 연결된 프로젝트 섹션
        const SizedBox(height: 16),
        _buildProjectsSection(context, isMobile),
      ]),
    );
  }

  Widget _buildFunnelDiagram(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3040)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.filter_alt_outlined, color: AppTheme.mintPrimary, size: 18),
          const SizedBox(width: 8),
          const Text('마케팅 퍼널 & 전략 연결', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const Spacer(),
          _StatChip(label: 'KPI', value: '${kpis.where((k) => k.funnelStageKey != null).length}개 연결', color: AppTheme.mintPrimary),
          const SizedBox(width: 8),
          _StatChip(label: '캠페인', value: '${campaigns.length}개', color: AppTheme.info),
        ]),
        const SizedBox(height: 16),
        // 퍼널 시각화
        if (!isMobile)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _stages.asMap().entries.map((entry) {
              final i = entry.key;
              final stage = entry.value;
              final stageKey = stage['key'] as String;
              final stageKpis = kpis.where((k) => k.funnelStageKey == stageKey).toList();
              final stageCampaigns = campaigns.where((c) => c.funnelStageKey == stageKey).toList();
              final color = Color(stage['color'] as int);
              final heightFactor = 1.0 - (i * 0.1);

              return Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  // KPI/캠페인 카운트
                  if (stageKpis.isNotEmpty || stageCampaigns.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'KPI ${stageKpis.length} / 캠페인 ${stageCampaigns.length}',
                        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  // 퍼널 블록
                  Container(
                    height: 80 * heightFactor,
                    margin: EdgeInsets.symmetric(horizontal: i == 0 ? 0 : 2.0),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    child: Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(stage['icon'] as IconData, color: color, size: 18),
                        const SizedBox(height: 4),
                        Text(stage['label'] as String, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(stage['desc'] as String, style: const TextStyle(color: AppTheme.textMuted, fontSize: 8), textAlign: TextAlign.center, maxLines: 2),
                ]),
              );
            }).toList(),
          )
        else
          // 모바일: 수직 퍼널
          Column(children: _stages.asMap().entries.map((entry) {
            final i = entry.key;
            final stage = entry.value;
            final stageKey = stage['key'] as String;
            final stageKpis = kpis.where((k) => k.funnelStageKey == stageKey).toList();
            final stageCampaigns = campaigns.where((c) => c.funnelStageKey == stageKey).toList();
            final color = Color(stage['color'] as int);
            final widthFactor = 1.0 - (i * 0.08);

            return Center(
              child: FractionallySizedBox(
                widthFactor: widthFactor.clamp(0.5, 1.0),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(stage['icon'] as IconData, color: color, size: 14),
                    const SizedBox(width: 6),
                    Text(stage['label'] as String, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                    if (stageKpis.isNotEmpty || stageCampaigns.isNotEmpty) ...[ 
                      const SizedBox(width: 8),
                      Text('KPI ${stageKpis.length}', style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 9)),
                    ],
                  ]),
                ),
              ),
            );
          }).toList()),
      ]),
    );
  }

  Widget _buildStageSection(BuildContext context, Map<String, dynamic> stage, bool isMobile) {
    final stageKey = stage['key'] as String;
    final color = Color(stage['color'] as int);
    final stageKpis = kpis.where((k) => k.funnelStageKey == stageKey).toList();
    final stageCampaigns = campaigns.where((c) => c.funnelStageKey == stageKey).toList();

    if (stageKpis.isEmpty && stageCampaigns.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: EdgeInsets.fromLTRB(14, 0, 14, isMobile ? 10 : 14),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(stage['icon'] as IconData, color: color, size: 16),
        ),
        title: Row(children: [
          Text(stage['label'] as String, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text(stage['desc'] as String, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (stageKpis.isNotEmpty) _StatChip(label: 'KPI', value: '${stageKpis.length}', color: AppTheme.mintPrimary),
          if (stageCampaigns.isNotEmpty) ...[
            const SizedBox(width: 4),
            _StatChip(label: '캠페인', value: '${stageCampaigns.length}', color: AppTheme.info),
          ],
          const Icon(Icons.expand_more, color: AppTheme.textMuted, size: 16),
        ]),
        iconColor: AppTheme.textMuted,
        collapsedIconColor: AppTheme.textMuted,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        children: [
          if (stageKpis.isNotEmpty) ...[
            const Align(alignment: Alignment.centerLeft,
              child: Text('연결 KPI', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6,
              children: stageKpis.map((k) => _KpiChip(kpi: k, campaigns: campaigns, funnelLabel: funnelLabel)).toList()),
            const SizedBox(height: 10),
          ],
          if (stageCampaigns.isNotEmpty) ...[
            const Align(alignment: Alignment.centerLeft,
              child: Text('연결 캠페인', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
            const SizedBox(height: 6),
            ...stageCampaigns.map((c) => _CampaignMiniCard(campaign: c, provider: provider)),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectsSection(BuildContext context, bool isMobile) {
    final teamId = provider.selectedTeamId;
    if (teamId == null) return const SizedBox.shrink();

    final projects = provider.projectStore
        .where((p) => p.teamId == teamId)
        .toList();

    if (projects.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E3040)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.folder_outlined, color: AppTheme.warning, size: 18),
          const SizedBox(width: 8),
          Text('팀 프로젝트 현황 (${projects.length}개)', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 1 : 2,
            childAspectRatio: isMobile ? 3.5 : 2.8,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: projects.length,
          itemBuilder: (ctx, i) => _ProjectCard(project: projects[i], provider: provider),
        ),
      ]),
    );
  }
}

// ── 캠페인 미니 카드 ──────────────────────────────────────
class _CampaignMiniCard extends StatelessWidget {
  final CampaignModel campaign;
  final AppProvider provider;
  const _CampaignMiniCard({required this.campaign, required this.provider});

  @override
  Widget build(BuildContext context) {
    final roi = campaign.roi;
    final roiColor = roi >= 200 ? AppTheme.success : roi >= 100 ? AppTheme.warning : AppTheme.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3040)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.info.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.campaign_outlined, color: AppTheme.info, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(campaign.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('${campaign.channel} | ${campaign.type}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('ROI ${roi.toStringAsFixed(0)}%', style: TextStyle(color: roiColor, fontSize: 11, fontWeight: FontWeight.w700)),
          Text('CTR ${campaign.ctr.toStringAsFixed(1)}%', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
        ]),
        const SizedBox(width: 8),
        InkWell(
          onTap: () {
            provider.selectCampaign(campaign.id);
            provider.navigateTo('campaign');
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.mintPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.3)),
            ),
            child: const Text('이동', style: TextStyle(color: AppTheme.mintPrimary, fontSize: 9)),
          ),
        ),
      ]),
    );
  }
}

// ── 프로젝트 카드 (클릭 시 상세 이동) ─────────────────────
class _ProjectCard extends StatelessWidget {
  final Project project;
  final AppProvider provider;
  const _ProjectCard({required this.project, required this.provider});

  @override
  Widget build(BuildContext context) {
    final completionRate = project.completionRate;
    final totalTasks = project.tasks.length;
    final doneTasks = project.tasks.where((t) => t.status == TaskStatus.done).length;
    final color = project.colorHex.isNotEmpty
        ? Color(int.parse('0xFF${project.colorHex.replaceAll('#', '')}'))
        : AppTheme.mintPrimary;
    final budgetUsage = project.budgetUsageRate;

    return InkWell(
      onTap: () {
        provider.selectProject(project.id);
        provider.navigateTo('project_detail');
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.bgCardLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(project.iconEmoji.isNotEmpty ? project.iconEmoji : '📁',
                  style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(project.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(project.category, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
            ])),
            // 상태 배지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('${completionRate.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 8),
          // 진행률 바
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: completionRate / 100,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.task_alt, color: AppTheme.textMuted, size: 10),
            const SizedBox(width: 3),
            Text('$doneTasks / $totalTasks 완료', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
            const Spacer(),
            if (budgetUsage > 0) ...[
              const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.textMuted, size: 10),
              const SizedBox(width: 3),
              Text('예산 ${budgetUsage.toStringAsFixed(0)}%', style: TextStyle(
                color: budgetUsage > 90 ? AppTheme.error : AppTheme.textMuted,
                fontSize: 9,
              )),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ── 전략 트리 뷰 ──────────────────────────────────────────
class _StrategyTreeView extends StatefulWidget {
  final AppProvider provider;
  final StrategyFramework? fw;
  final List<KpiModel> kpis;
  final List<CampaignModel> campaigns;
  final String Function(String?) funnelLabel;
  final Color Function(String) hexColor;
  final String? selectedObjectiveId;
  final void Function(String?) onObjectiveSelected;

  const _StrategyTreeView({
    required this.provider,
    required this.fw,
    required this.kpis,
    required this.campaigns,
    required this.funnelLabel,
    required this.hexColor,
    required this.selectedObjectiveId,
    required this.onObjectiveSelected,
  });

  @override
  State<_StrategyTreeView> createState() => _StrategyTreeViewState();
}

class _StrategyTreeViewState extends State<_StrategyTreeView> {
  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final fw = widget.fw;
    final kpis = widget.kpis;
    final campaigns = widget.campaigns;

    if (fw == null) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.account_tree_outlined, color: AppTheme.textMuted, size: 48),
          SizedBox(height: 12),
          Text('전략 프레임워크가 없습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
        ]),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 프레임워크 헤더
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.hexColor(fw.colorHex).withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: widget.hexColor(fw.colorHex).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(fw.iconEmoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fw.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              if (fw.description != null) Text(fw.description!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                _StatChip(label: '전략과제', value: '${fw.objectives.length}개', color: AppTheme.mintPrimary),
                _StatChip(label: '실행과제', value: '${fw.objectives.expand((o) => o.actions).length}개', color: AppTheme.info),
                _StatChip(label: 'Deliverable', value: '${fw.allDeliverables.length}개', color: AppTheme.warning),
                _StatChip(label: '연결 KPI', value: '${kpis.where((k) => k.deliverableId != null).length}개', color: AppTheme.success),
              ]),
            ])),
          ]),
        ),
        const SizedBox(height: 20),

        // 전략과제 목록
        ...fw.objectives.map((obj) {
          final isExpanded = widget.selectedObjectiveId == obj.id || widget.selectedObjectiveId == null;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.hexColor(obj.colorHex).withValues(alpha: 0.4)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InkWell(
                onTap: () => widget.onObjectiveSelected(isExpanded ? 'none' : null),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: widget.hexColor(obj.colorHex).withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Row(children: [
                    Container(width: 4, height: 20, decoration: BoxDecoration(color: widget.hexColor(obj.colorHex), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(obj.name, style: TextStyle(color: widget.hexColor(obj.colorHex), fontSize: 14, fontWeight: FontWeight.w700))),
                    if (obj.description != null) Text(obj.description!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    const SizedBox(width: 8),
                    Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: AppTheme.textMuted, size: 18),
                  ]),
                ),
              ),
              if (isExpanded) ...[
                ...obj.actions.map((action) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: AppTheme.bgCardLight.withValues(alpha: 0.5),
                    child: Row(children: [
                      const Icon(Icons.subdirectory_arrow_right, color: AppTheme.textMuted, size: 14),
                      const SizedBox(width: 6),
                      Text(action.name, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  ...action.deliverables.map((d) {
                    final linkedKpis = kpis.where((k) => k.deliverableId == d.id).toList();
                    final linkedCampaigns = campaigns.where((c) => c.deliverableId == d.id || linkedKpis.any((k) => k.campaignId == c.id)).toList();
                    final statusColor = d.status == 'done' ? AppTheme.success : d.status == 'in_progress' ? AppTheme.warning : AppTheme.textMuted;
                    final statusLabel = d.status == 'done' ? '완료' : d.status == 'in_progress' ? '진행중' : '예정';

                    return Container(
                      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCardLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1E3040)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Row(children: [
                            Icon(Icons.task_alt, color: statusColor, size: 14),
                            const SizedBox(width: 6),
                            Expanded(child: Text(d.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                            child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _showLinkKpiDialog(context, d, kpis, campaigns, provider),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.mintPrimary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.3)),
                              ),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.link, color: AppTheme.mintPrimary, size: 11),
                                SizedBox(width: 3),
                                Text('KPI 연결', style: TextStyle(color: AppTheme.mintPrimary, fontSize: 9)),
                              ]),
                            ),
                          ),
                        ]),
                        if (linkedKpis.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 4, children: linkedKpis.map((k) => _KpiChip(kpi: k, campaigns: campaigns, funnelLabel: widget.funnelLabel)).toList()),
                        ],
                        if (linkedCampaigns.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 4, children: linkedCampaigns.map((c) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF29B6F6).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF29B6F6).withValues(alpha: 0.3)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.campaign_outlined, color: Color(0xFF29B6F6), size: 10),
                              const SizedBox(width: 4),
                              Text(c.name, style: const TextStyle(color: Color(0xFF29B6F6), fontSize: 9)),
                            ]),
                          )).toList()),
                        ],
                      ]),
                    );
                  }),
                ])),
              ],
            ]),
          );
        }),

        const SizedBox(height: 8),
        _UnlinkedKpisSection(provider: provider),
      ]),
    );
  }

  void _showLinkKpiDialog(BuildContext context, StrategyDeliverable deliverable, List<KpiModel> allKpis, List<CampaignModel> campaigns, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.link, color: AppTheme.mintPrimary, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('"${deliverable.name}" KPI 연결', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700))),
          ]),
          content: SizedBox(
            width: 480,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: allKpis.isEmpty
                  ? const Padding(padding: EdgeInsets.all(20), child: Text('KPI가 없습니다. 먼저 KPI를 추가해주세요.', style: TextStyle(color: AppTheme.textMuted)))
                  : ListView(children: allKpis.map((k) {
                      final isLinked = k.deliverableId == deliverable.id;
                      final achRate = k.achievementRate;
                      final color = achRate >= 80 ? AppTheme.success : achRate >= 50 ? AppTheme.warning : AppTheme.error;
                      return InkWell(
                        onTap: () {
                          final updated = k.copyWith(deliverableId: isLinked ? null : deliverable.id);
                          provider.updateKpi(updated);
                          setDialogState(() {});
                          setState(() {});
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isLinked ? AppTheme.mintPrimary.withValues(alpha: 0.1) : AppTheme.bgCardLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isLinked ? AppTheme.mintPrimary.withValues(alpha: 0.5) : const Color(0xFF1E3040)),
                          ),
                          child: Row(children: [
                            Icon(isLinked ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: isLinked ? AppTheme.mintPrimary : AppTheme.textMuted, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(k.title, style: TextStyle(color: isLinked ? AppTheme.mintPrimary : AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                              Text('${k.category} | ${k.current.toStringAsFixed(0)} / ${k.target.toStringAsFixed(0)} ${k.unit}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                            ])),
                            Text('${achRate.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      );
                    }).toList()),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.mintPrimary),
              child: const Text('완료', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10)),
      const SizedBox(width: 4),
      Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _KpiChip extends StatelessWidget {
  final KpiModel kpi;
  final List<CampaignModel> campaigns;
  final String Function(String?) funnelLabel;
  const _KpiChip({required this.kpi, required this.campaigns, required this.funnelLabel});

  @override
  Widget build(BuildContext context) {
    final achRate = kpi.achievementRate;
    final color = achRate >= 80 ? AppTheme.success : achRate >= 50 ? AppTheme.warning : AppTheme.error;
    final campaign = kpi.campaignId != null ? campaigns.where((c) => c.id == kpi.campaignId).firstOrNull : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.mintPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.track_changes, color: AppTheme.mintPrimary, size: 10),
          const SizedBox(width: 4),
          Text(kpi.title, style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text('${achRate.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
        if (campaign != null || kpi.funnelStageKey != null) ...[
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (campaign != null) ...[
              const Icon(Icons.campaign_outlined, color: Color(0xFF29B6F6), size: 9),
              const SizedBox(width: 2),
              Text(campaign.name, style: const TextStyle(color: Color(0xFF29B6F6), fontSize: 9)),
              const SizedBox(width: 6),
            ],
            if (kpi.funnelStageKey != null) Text(funnelLabel(kpi.funnelStageKey), style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
          ]),
        ],
      ]),
    );
  }
}

class _UnlinkedKpisSection extends StatelessWidget {
  final AppProvider provider;
  const _UnlinkedKpisSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    final teamId = provider.selectedTeamId;
    if (teamId == null) return const SizedBox.shrink();
    final unlinked = provider.getKpisForTeam(teamId).where((k) => k.deliverableId == null && k.isTeamKpi).toList();
    if (unlinked.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 16),
          const SizedBox(width: 6),
          Text('전략 미연결 KPI (${unlinked.length}개)', style: const TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          const Text('– 전략과제에 연결해주세요', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: unlinked.map((k) {
          final achRate = k.achievementRate;
          final color = achRate >= 80 ? AppTheme.success : achRate >= 50 ? AppTheme.warning : AppTheme.error;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.bgCardLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E3040)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.track_changes, color: AppTheme.textMuted, size: 12),
              const SizedBox(width: 5),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(k.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                Text('${k.category} | ${k.current.toStringAsFixed(0)} / ${k.target.toStringAsFixed(0)} ${k.unit}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
              ]),
              const SizedBox(width: 8),
              Text('${achRate.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
            ]),
          );
        }).toList()),
      ]),
    );
  }
}
