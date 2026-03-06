// ════════════════════════════════════════════════════════════════
//  Dashboard Customize Panel
//  위젯 표시/숨김, 순서 조정, 제목 변경, 지표 조합
// ════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

class DashboardCustomizePanel extends StatefulWidget {
  final AppProvider provider;
  const DashboardCustomizePanel({super.key, required this.provider});

  @override
  State<DashboardCustomizePanel> createState() => _DashboardCustomizePanelState();
}

class _DashboardCustomizePanelState extends State<DashboardCustomizePanel>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late List<DashboardWidgetConfig> _localWidgets;

  // 지표 조합 설정
  late List<String> _selectedSummaryMetrics;
  late String _campaignFilter; // 'all', type명
  late bool _showRoiWidgets;

  static const _allSummaryMetrics = [
    '매출', '마케팅 ROI', '광고비', '신규 리드', 'KPI 달성률', '활성 캠페인',
    'ROAS', '전환수', '총 예산', '예산 소진율',
  ];

  static const _campaignTypes = [
    '전체', '매출 독려', '브랜드 인지', '리드 창출', '리텐션', '신규 고객', '퍼포먼스', '콘텐츠',
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _localWidgets = widget.provider.dashboardConfig.widgets
        .map((w) => DashboardWidgetConfig(
              type: w.type,
              isVisible: w.isVisible,
              order: w.order,
              customTitle: w.customTitle,
              isExpanded: w.isExpanded,
            ))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    // 지표 조합 초기값
    _selectedSummaryMetrics = List.from(
      widget.provider.dashboardConfig.selectedSummaryMetrics.isNotEmpty
        ? widget.provider.dashboardConfig.selectedSummaryMetrics
        : ['매출', '마케팅 ROI', '광고비', '신규 리드', 'KPI 달성률', '활성 캠페인'],
    );
    _campaignFilter = widget.provider.dashboardConfig.campaignTypeFilter;
    _showRoiWidgets = widget.provider.dashboardConfig.showRoiWidgets;
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _applyChanges() {
    for (final w in _localWidgets) {
      widget.provider.updateDashboardWidget(
        w.type,
        isVisible: w.isVisible,
        order: w.order,
        customTitle: w.customTitle,
        isExpanded: w.isExpanded,
      );
    }
    widget.provider.updateDashboardMetrics(
      summaryMetrics: _selectedSummaryMetrics,
      campaignTypeFilter: _campaignFilter,
      showRoiWidgets: _showRoiWidgets,
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('✅ 대시보드 설정이 저장되었습니다'),
      backgroundColor: AppTheme.accentGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _resetToDefault() {
    widget.provider.resetDashboardConfig();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 740),
        child: Column(children: [
          // ── 헤더 ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.mintPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.dashboard_customize_rounded,
                    color: AppTheme.mintPrimary, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('대시보드 커스터마이즈',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                Text('위젯 구성, 지표 조합, 캠페인 필터를 원하는 대로 설정하세요',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ])),
              TextButton(
                onPressed: _resetToDefault,
                child: const Text('초기화', style: TextStyle(color: AppTheme.accentRed, fontSize: 12)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 17),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          // ── 탭 바 ─────────────────────────────────────────────
          TabBar(
            controller: _tab,
            labelColor: AppTheme.mintPrimary,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.mintPrimary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: '위젯 구성'),
              Tab(text: '지표 조합'),
              Tab(text: '캠페인 필터'),
            ],
          ),
          const Divider(height: 1, color: AppTheme.border),

          // ── 탭 내용 ───────────────────────────────────────────
          Expanded(child: TabBarView(controller: _tab, children: [
            // ═══ 탭 1: 위젯 구성 ══════════════════════════════
            Column(children: [
              Container(
                padding: const EdgeInsets.all(10),
                color: AppTheme.bgDark,
                child: Row(children: [
                  const Icon(Icons.drag_indicator_rounded, color: AppTheme.textMuted, size: 14),
                  const SizedBox(width: 6),
                  const Expanded(child: Text('드래그로 순서 변경 · 토글로 표시/숨김 · ✏️로 제목 변경',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.mintPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${_localWidgets.where((w) => w.isVisible).length}/${_localWidgets.length} 표시',
                        style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _localWidgets.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _localWidgets.removeAt(oldIndex);
                      _localWidgets.insert(newIndex, item);
                      for (int i = 0; i < _localWidgets.length; i++) {
                        _localWidgets[i].order = i;
                      }
                    });
                  },
                  itemBuilder: (ctx, index) {
                    final w = _localWidgets[index];
                    return _WidgetConfigRow(
                      key: ValueKey(w.type),
                      config: w,
                      onToggleVisible: () => setState(() => w.isVisible = !w.isVisible),
                      onRenameTitle: (newTitle) => setState(() => w.customTitle = newTitle),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(children: [
                  TextButton.icon(
                    icon: const Icon(Icons.visibility_rounded, size: 14),
                    label: const Text('전체 표시', style: TextStyle(fontSize: 11)),
                    onPressed: () => setState(() { for (final w in _localWidgets) w.isVisible = true; }),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    icon: const Icon(Icons.visibility_off_rounded, size: 14),
                    label: const Text('전체 숨김', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.textMuted),
                    onPressed: () => setState(() { for (final w in _localWidgets) w.isVisible = false; }),
                  ),
                ]),
              ),
            ]),

            // ═══ 탭 2: 지표 조합 ══════════════════════════════
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ROI 위젯 토글
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCardLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(children: [
                    const Icon(Icons.analytics_rounded, color: AppTheme.accentBlue, size: 16),
                    const SizedBox(width: 10),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('ROI 분석 위젯 표시', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('권역별 / 국가별 / 고객사별 ROI 분석 패널', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ])),
                    Switch(
                      value: _showRoiWidgets,
                      onChanged: (v) => setState(() => _showRoiWidgets = v),
                      activeColor: AppTheme.mintPrimary,
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  const Text('요약 카드 지표 선택',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.mintPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${_selectedSummaryMetrics.length}/6 선택',
                        style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 4),
                const Text('대시보드 요약 카드에 표시할 지표를 최대 6개 선택하세요',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _allSummaryMetrics.map((m) {
                    final selected = _selectedSummaryMetrics.contains(m);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (selected) {
                            if (_selectedSummaryMetrics.length > 1) _selectedSummaryMetrics.remove(m);
                          } else {
                            if (_selectedSummaryMetrics.length < 6) _selectedSummaryMetrics.add(m);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.mintPrimary.withValues(alpha: 0.15) : AppTheme.bgCardLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected ? AppTheme.mintPrimary : AppTheme.border,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (selected) ...[
                            const Icon(Icons.check_rounded, size: 12, color: AppTheme.mintPrimary),
                            const SizedBox(width: 4),
                          ],
                          Text(m, style: TextStyle(
                            color: selected ? AppTheme.mintPrimary : AppTheme.textMuted,
                            fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          )),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // 선택 순서 미리보기
                if (_selectedSummaryMetrics.isNotEmpty) ...[
                  const Text('미리보기 (선택 순서)',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: _selectedSummaryMetrics.asMap().entries.map((e) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 16, height: 16,
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue, shape: BoxShape.circle,
                          ),
                          child: Center(child: Text('${e.key + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
                        ),
                        const SizedBox(width: 5),
                        Text(e.value, style: const TextStyle(color: AppTheme.accentBlue, fontSize: 11)),
                      ]),
                    )).toList(),
                  ),
                ],
              ]),
            ),

            // ═══ 탭 3: 캠페인 필터 ════════════════════════════
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('캠페인 분류 필터',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('대시보드 "활성 캠페인" 위젯에 표시할 캠페인 분류를 선택하세요.\n캠페인 목표(KPI)가 변경되면 분류 필터도 함께 조정하세요.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                const SizedBox(height: 16),
                ..._campaignTypes.map((t) {
                  final selected = _campaignFilter == t || (t == '전체' && _campaignFilter == 'all');
                  return GestureDetector(
                    onTap: () => setState(() => _campaignFilter = t == '전체' ? 'all' : t),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.mintPrimary.withValues(alpha: 0.12) : AppTheme.bgCardLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? AppTheme.mintPrimary : AppTheme.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Icon(
                          t == '전체' ? Icons.all_inclusive :
                          t == '매출 독려' ? Icons.attach_money :
                          t == '브랜드 인지' ? Icons.branding_watermark :
                          t == '리드 창출' ? Icons.people_outline :
                          t == '리텐션' ? Icons.repeat :
                          t == '신규 고객' ? Icons.person_add_outlined :
                          t == '퍼포먼스' ? Icons.trending_up :
                          Icons.article_outlined,
                          color: selected ? AppTheme.mintPrimary : AppTheme.textMuted, size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(t, style: TextStyle(
                          color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
                          fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ))),
                        if (selected) const Icon(Icons.check_circle_rounded,
                            color: AppTheme.mintPrimary, size: 16),
                      ]),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.2)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: AppTheme.accentBlue, size: 14),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      '캠페인 분류(매출 독려 → 브랜드 인지 등) 변경 시 대시보드 전체 집계도 자동으로 반영됩니다.',
                      style: TextStyle(color: AppTheme.accentBlue, fontSize: 11),
                    )),
                  ]),
                ),
              ]),
            ),
          ])),

          // ── 푸터 ─────────────────────────────────────────────
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소', style: TextStyle(color: AppTheme.textMuted)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_rounded, size: 14),
                label: const Text('적용'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mintPrimary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _applyChanges,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── 개별 위젯 설정 행 ─────────────────────────────────────────
class _WidgetConfigRow extends StatefulWidget {
  final DashboardWidgetConfig config;
  final VoidCallback onToggleVisible;
  final void Function(String) onRenameTitle;

  const _WidgetConfigRow({
    super.key,
    required this.config,
    required this.onToggleVisible,
    required this.onRenameTitle,
  });

  @override
  State<_WidgetConfigRow> createState() => _WidgetConfigRowState();
}

class _WidgetConfigRowState extends State<_WidgetConfigRow> {
  bool _editing = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.config.customTitle);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final w = widget.config;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: w.isVisible ? AppTheme.bgCardLight : AppTheme.bgDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: w.isVisible ? AppTheme.mintPrimary.withValues(alpha: 0.2) : AppTheme.border,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.drag_indicator_rounded, color: AppTheme.textMuted, size: 18),
          const SizedBox(width: 6),
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: w.isVisible
                  ? AppTheme.mintPrimary.withValues(alpha: 0.12)
                  : AppTheme.textMuted.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(child: Text(w.type.icon, style: const TextStyle(fontSize: 14))),
          ),
        ]),
        title: _editing
            ? Row(children: [
                Expanded(child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: w.type.label,
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    filled: true, fillColor: AppTheme.bgCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  autofocus: true,
                  onSubmitted: (v) {
                    widget.onRenameTitle(v);
                    setState(() => _editing = false);
                  },
                )),
                IconButton(
                  icon: const Icon(Icons.check_rounded, size: 14, color: AppTheme.mintPrimary),
                  onPressed: () {
                    widget.onRenameTitle(_ctrl.text);
                    setState(() => _editing = false);
                  },
                ),
              ])
            : Row(children: [
                Expanded(child: Text(
                  w.customTitle.isNotEmpty ? w.customTitle : w.type.label,
                  style: TextStyle(
                    color: w.isVisible ? AppTheme.textPrimary : AppTheme.textMuted,
                    fontSize: 13, fontWeight: FontWeight.w500,
                  ),
                )),
                if (w.customTitle.isNotEmpty)
                  const Text('(커스텀)',
                      style: TextStyle(color: AppTheme.accentBlue, fontSize: 10)),
              ]),
        subtitle: Text(w.type.label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!_editing) IconButton(
            icon: const Icon(Icons.edit_outlined, size: 14, color: AppTheme.textMuted),
            tooltip: '제목 변경',
            onPressed: () => setState(() => _editing = true),
          ),
          Switch(
            value: w.isVisible,
            onChanged: (_) => widget.onToggleVisible(),
            activeColor: AppTheme.mintPrimary,
            trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                ? AppTheme.mintPrimary.withValues(alpha: 0.3)
                : AppTheme.border),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
      ),
    );
  }
}
