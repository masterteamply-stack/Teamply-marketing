import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../widgets/task_link_panel.dart';
import '../../widgets/dashboard_customize_panel.dart';
import '../../widgets/roi_widgets.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final fmt = NumberFormat('#,###');
    final fmtM = NumberFormat('#,##0.0');
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────
              if (!isMobile) ...[
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Text('마케팅 대시보드',
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                          if (provider.selectedTeam != null) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.mintPrimary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                provider.selectedTeam!.iconEmoji + ' ' + provider.selectedTeam!.name,
                                style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Text(_periodLabel(provider),
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                  // 대시보드 커스터마이즈 버튼
                  OutlinedButton.icon(
                    icon: const Icon(Icons.dashboard_customize_rounded, size: 15),
                    label: const Text('대시보드 설정', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.mintPrimary,
                      side: BorderSide(color: AppTheme.mintPrimary.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => DashboardCustomizePanel(provider: provider),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _PeriodSelector(provider: provider),
                ]),
                const SizedBox(height: 24),
              ] else ...[
                Row(children: [
                  const Text('전체 성과 요약', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  const Spacer(),
                  _PeriodSelector(provider: provider),
                ]),
                const SizedBox(height: 12),
              ],

              // ── Summary Cards ─────────────────────────────────
              if (_isVisible(provider, DashboardWidgetType.summaryCards)) ...[
                _SummaryCards(provider: provider, fmt: fmt, fmtM: fmtM, isMobile: isMobile),
                SizedBox(height: isMobile ? 16 : 24),
              ],

              // ── Charts (위젯 설정에 따라 동적 표시) ──────────────
              if (isMobile) ...[
                if (_isVisible(provider, DashboardWidgetType.revenueChart)) ...[
                  _RevenueChart(provider: provider), const SizedBox(height: 16)],
                if (_isVisible(provider, DashboardWidgetType.kpiAchievement)) ...[
                  _KpiAchievementList(provider: provider), const SizedBox(height: 16)],
                if (_isVisible(provider, DashboardWidgetType.activeCampaigns)) ...[
                  _ActiveCampaigns(provider: provider), const SizedBox(height: 16)],
                if (_isVisible(provider, DashboardWidgetType.riskTop5)) ...[
                  _RiskTop5(provider: provider), const SizedBox(height: 16)],
                if (_isVisible(provider, DashboardWidgetType.regionRoi)) ...[
                  RegionRoiWidget(provider: provider,
                      title: _widgetTitle(provider, DashboardWidgetType.regionRoi)),
                  const SizedBox(height: 16)],
                if (_isVisible(provider, DashboardWidgetType.countryRoi)) ...[
                  CountryRoiWidget(provider: provider,
                      title: _widgetTitle(provider, DashboardWidgetType.countryRoi)),
                  const SizedBox(height: 16)],
                if (_isVisible(provider, DashboardWidgetType.clientRoi)) ...[
                  ClientRoiWidget(provider: provider,
                      title: _widgetTitle(provider, DashboardWidgetType.clientRoi)),
                  const SizedBox(height: 16)],
                if (_isVisible(provider, DashboardWidgetType.allTasks))
                  _AllTasksSection(provider: provider),
              ] else ...[
                if (_isVisible(provider, DashboardWidgetType.revenueChart) ||
                    _isVisible(provider, DashboardWidgetType.kpiAchievement)) ...[
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_isVisible(provider, DashboardWidgetType.revenueChart))
                      Expanded(flex: 3, child: _RevenueChart(provider: provider)),
                    if (_isVisible(provider, DashboardWidgetType.revenueChart) &&
                        _isVisible(provider, DashboardWidgetType.kpiAchievement))
                      const SizedBox(width: 20),
                    if (_isVisible(provider, DashboardWidgetType.kpiAchievement))
                      Expanded(flex: 2, child: _KpiAchievementList(provider: provider)),
                  ]),
                  const SizedBox(height: 20),
                ],
                if (_isVisible(provider, DashboardWidgetType.activeCampaigns) ||
                    _isVisible(provider, DashboardWidgetType.riskTop5)) ...[
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_isVisible(provider, DashboardWidgetType.activeCampaigns))
                      Expanded(flex: 2, child: _ActiveCampaigns(provider: provider)),
                    if (_isVisible(provider, DashboardWidgetType.activeCampaigns) &&
                        _isVisible(provider, DashboardWidgetType.riskTop5))
                      const SizedBox(width: 20),
                    if (_isVisible(provider, DashboardWidgetType.riskTop5))
                      Expanded(flex: 3, child: _RiskTop5(provider: provider)),
                  ]),
                  const SizedBox(height: 20),
                ],
              // ── ROI 위젯들 ────────────────────────────────────
                if (provider.dashboardConfig.showRoiWidgets) ...[
                  if (_isVisible(provider, DashboardWidgetType.regionRoi) ||
                      _isVisible(provider, DashboardWidgetType.countryRoi)) ...[
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (_isVisible(provider, DashboardWidgetType.regionRoi))
                        Expanded(child: RegionRoiWidget(provider: provider,
                            title: _widgetTitle(provider, DashboardWidgetType.regionRoi))),
                      if (_isVisible(provider, DashboardWidgetType.regionRoi) &&
                          _isVisible(provider, DashboardWidgetType.countryRoi))
                        const SizedBox(width: 20),
                      if (_isVisible(provider, DashboardWidgetType.countryRoi))
                        Expanded(child: CountryRoiWidget(provider: provider,
                            title: _widgetTitle(provider, DashboardWidgetType.countryRoi))),
                    ]),
                    const SizedBox(height: 20),
                  ],
                  if (_isVisible(provider, DashboardWidgetType.clientRoi)) ...[
                    ClientRoiWidget(provider: provider,
                        title: _widgetTitle(provider, DashboardWidgetType.clientRoi)),
                    const SizedBox(height: 20),
                  ],
                ],
                if (_isVisible(provider, DashboardWidgetType.allTasks)) ...[
                  _AllTasksSection(provider: provider),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _periodLabel(AppProvider p) {
    if (p.selectedQuarter == null) return '${p.selectedYear}년 연간 종합 성과';
    return '${p.selectedYear}년 ${p.selectedQuarter} 분기 성과';
  }

  static bool _isVisible(AppProvider p, DashboardWidgetType type) =>
      p.dashboardConfig.getConfig(type)?.isVisible ?? true;

  static String _widgetTitle(AppProvider p, DashboardWidgetType type) =>
      p.dashboardConfig.getConfig(type)?.displayTitle ?? type.label;
}

// ─────────────────────────────────────────────────────────────
// 기간 선택기: 연도 드롭다운 + 쿼터 탭
// ─────────────────────────────────────────────────────────────
class _PeriodSelector extends StatelessWidget {
  final AppProvider provider;
  const _PeriodSelector({required this.provider});

  @override
  Widget build(BuildContext context) {
    final years = provider.availableYears;
    final quarters = ['연간', 'Q1', 'Q2', 'Q3', 'Q4'];
    final selectedQ = provider.selectedQuarter ?? '연간';

    return Row(children: [
      // ── 연도 드롭다운 ──────────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.3)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: years.contains(provider.selectedYear) ? provider.selectedYear : years.last,
            dropdownColor: AppTheme.bgCard,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y년'))).toList(),
            onChanged: (v) {
              if (v != null) {
                provider.setYearQuarter(v, provider.selectedQuarter);
              }
            },
          ),
        ),
      ),
      const SizedBox(width: 8),
      // ── 쿼터 탭 ──────────────────────────────────────────
      Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: quarters.map((q) {
            final isSelected = q == selectedQ;
            return GestureDetector(
              onTap: () => provider.setYearQuarter(
                provider.selectedYear,
                q == '연간' ? null : q,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.mintPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  q,
                  style: TextStyle(
                    color: isSelected ? Colors.black : AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// Summary Cards: 기간 집계 데이터 반영
// ─────────────────────────────────────────────────────────────
class _SummaryCards extends StatelessWidget {
  final AppProvider provider;
  final NumberFormat fmt, fmtM;
  final bool isMobile;
  const _SummaryCards({
    required this.provider, required this.fmt, required this.fmtM, this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final revenue = provider.periodRevenue;
    final adSpend = provider.periodAdSpend;
    final leads = provider.periodLeads;
    final roi = provider.periodRoi;
    final isYearly = provider.selectedQuarter == null;
    final selectedMetrics = provider.dashboardConfig.selectedSummaryMetrics;

    // 전체 지표 맵
    final allCards = {
      '매출': _CardData('${isYearly ? '연간' : '분기'} 매출', '₩${_shortNum(revenue)}', Icons.attach_money, AppTheme.mintPrimary, _revenueYoY(provider)),
      '마케팅 ROI': _CardData('마케팅 ROI', '${fmtM.format(roi)}%', Icons.trending_up, AppTheme.info, roi >= 200 ? '목표 초과' : roi >= 150 ? '양호' : '개선 필요'),
      '광고비': _CardData('광고비 집행', '₩${_shortNum(adSpend)}', Icons.account_balance_wallet_outlined, AppTheme.warning, '집행 중'),
      '신규 리드': _CardData('신규 리드', '${fmt.format(leads)}건', Icons.people_outline, AppTheme.success, isYearly ? '연간 합계' : '분기 합계'),
      'KPI 달성률': _CardData('KPI 달성률', '${fmtM.format(provider.avgKpiAchievement)}%', Icons.flag_outlined, const Color(0xFFAB47BC), '평균'),
      '활성 캠페인': _CardData('활성 캠페인', '${provider.activeCampaigns}개', Icons.campaign_outlined, const Color(0xFFFF7043), '진행 중'),
      'ROAS': _CardData('ROAS', adSpend > 0 ? '${(revenue / adSpend).toStringAsFixed(1)}x' : '-', Icons.bar_chart, AppTheme.accentBlue, adSpend > 0 && revenue / adSpend >= 2 ? '우수' : '모니터링'),
      '전환수': _CardData('전환수', '${fmt.format(provider.campaigns.fold(0.0, (s, c) => s + c.conversions).toInt())}건', Icons.swap_horiz, AppTheme.accentGreen, '누적'),
      '총 예산': _CardData('총 예산', '₩${_shortNum(provider.campaigns.fold(0.0, (s, c) => s + c.budget))}', Icons.savings_outlined, const Color(0xFF26C6DA), '전체'),
      '예산 소진율': _CardData('예산 소진율', '${provider.campaigns.isEmpty ? 0 : (provider.campaigns.fold(0.0, (s, c) => s + c.spent) / provider.campaigns.fold(0.0, (s, c) => s + c.budget) * 100).toStringAsFixed(0)}%', Icons.donut_small_outlined, const Color(0xFFEF5350), '소진'),
    };

    // 선택된 지표만 표시 (순서 유지)
    final cards = <_CardData>[
      ...selectedMetrics
          .where((m) => allCards.containsKey(m))
          .map((m) => allCards[m]!),
    ];
    if (cards.isEmpty) {
      cards.addAll(allCards.values.take(6));
    }

    if (isMobile) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, childAspectRatio: 1.5, crossAxisSpacing: 10, mainAxisSpacing: 10,
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) => _SummaryCard(data: cards[i], isMobile: true),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cards.length.clamp(3, 6), childAspectRatio: 1.3, crossAxisSpacing: 14, mainAxisSpacing: 14,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) => _SummaryCard(data: cards[i]),
    );
  }

  static String _revenueYoY(AppProvider p) {
    final year = int.tryParse(p.selectedYear) ?? 2025;
    final prevYear = (year - 1).toString();
    double cur = 0, prev = 0;
    for (final d in p.monthlyData) {
      final key = d.monthKey;
      if (key == null) continue;
      final parts = key.split('-');
      if (parts.length != 2) continue;
      final y = parts[0];
      final qOk = p.selectedQuarter == null || _inQuarter(d.monthKey, p.selectedQuarter!);
      if (y == p.selectedYear && qOk) cur += d.revenue;
      if (y == prevYear && qOk) prev += d.revenue;
    }
    if (prev <= 0) return '집계 중';
    final pct = ((cur - prev) / prev * 100);
    return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}% YoY';
  }

  static bool _inQuarter(String? key, String q) {
    if (key == null) return false;
    final m = int.tryParse(key.split('-').last) ?? 0;
    return switch (q) {
      'Q1' => m >= 1 && m <= 3,
      'Q2' => m >= 4 && m <= 6,
      'Q3' => m >= 7 && m <= 9,
      'Q4' => m >= 10 && m <= 12,
      _ => false,
    };
  }

  static String _shortNum(double v) {
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}억';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(0)}만';
    return v.toStringAsFixed(0);
  }
}

class _CardData {
  final String title, value, trend;
  final IconData icon;
  final Color color;
  const _CardData(this.title, this.value, this.icon, this.color, this.trend);
}

class _SummaryCard extends StatelessWidget {
  final _CardData data;
  final bool isMobile;
  const _SummaryCard({required this.data, this.isMobile = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: data.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 5 : 6),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(data.icon, color: data.color, size: isMobile ? 14 : 16),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6),
              ),
              child: Text(data.trend, style: const TextStyle(color: AppTheme.success, fontSize: 9)),
            ),
          ]),
          Text(data.value,
              style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: isMobile ? 17 : 20, fontWeight: FontWeight.w700)),
          Text(data.title, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Revenue Chart: 기간에 따라 월별 또는 쿼터별 집계 바차트
// ─────────────────────────────────────────────────────────────
class _RevenueChart extends StatelessWidget {
  final AppProvider provider;
  const _RevenueChart({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isYearly = provider.selectedQuarter == null;

    // 연간 보기: 쿼터별 집계 / 쿼터 보기: 해당 쿼터 월별
    final List<_ChartBar> bars;
    if (isYearly) {
      bars = _buildYearlyBars(provider);
    } else {
      bars = _buildQuarterlyBars(provider);
    }

    final title = isYearly
        ? '${provider.selectedYear}년 분기별 매출 vs 광고비'
        : '${provider.selectedYear}년 ${provider.selectedQuarter} 월별 매출 vs 광고비';

    if (bars.isEmpty) return const SizedBox();

    final maxY = bars.fold<double>(0, (m, b) => b.revenue > m ? b.revenue : m) * 1.25;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(title,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
            _ChartLegend(color: AppTheme.mintPrimary, label: '매출'),
            const SizedBox(width: 12),
            _ChartLegend(color: AppTheme.warning, label: '광고비'),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY > 0 ? maxY : 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFF1E3040), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 52,
                    getTitlesWidget: (v, _) =>
                        Text(_shortNum(v), style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                  )),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 24,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= bars.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(bars[i].label,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                      );
                    },
                  )),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                barGroups: bars.asMap().entries.map((e) => BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.revenue,
                      width: isYearly ? 28 : 18,
                      color: AppTheme.mintPrimary,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                    BarChartRodData(
                      toY: e.value.adSpend,
                      width: isYearly ? 28 : 18,
                      color: AppTheme.warning.withValues(alpha: 0.8),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                  barsSpace: 4,
                )).toList(),
              ),
            ),
          ),
          // ── 연간일 때: 연도 합계 통계 바 ────────────────────
          if (isYearly) ...[
            const SizedBox(height: 16),
            _YearSummaryRow(provider: provider),
          ],
        ],
      ),
    );
  }

  /// 연간: Q1~Q4 집계
  static List<_ChartBar> _buildYearlyBars(AppProvider p) {
    final qLabels = ['Q1', 'Q2', 'Q3', 'Q4'];
    final qMonthRanges = [[1,2,3],[4,5,6],[7,8,9],[10,11,12]];
    return List.generate(4, (qi) {
      final months = qMonthRanges[qi];
      double rev = 0, spend = 0;
      for (final d in p.monthlyData) {
        final key = d.monthKey;
        if (key == null) continue;
        final parts = key.split('-');
        if (parts.length != 2) continue;
        final y = parts[0];
        final m = int.tryParse(parts[1]) ?? 0;
        if (y == p.selectedYear && months.contains(m)) {
          rev += d.revenue;
          spend += d.adSpend;
        }
      }
      return _ChartBar(label: qLabels[qi], revenue: rev, adSpend: spend);
    });
  }

  /// 쿼터: 해당 분기 3개월
  static List<_ChartBar> _buildQuarterlyBars(AppProvider p) {
    final data = p.filteredMonthlyData;
    return data.map((d) => _ChartBar(label: d.month, revenue: d.revenue, adSpend: d.adSpend)).toList();
  }

  static String _shortNum(double v) {
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(0)}억';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(0)}M';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(0)}만';
    return v.toStringAsFixed(0);
  }
}

class _ChartBar {
  final String label;
  final double revenue, adSpend;
  const _ChartBar({required this.label, required this.revenue, required this.adSpend});
}

/// 연간 보기일 때 상단 총합 통계
class _YearSummaryRow extends StatelessWidget {
  final AppProvider provider;
  const _YearSummaryRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    final rev = provider.periodRevenue;
    final spend = provider.periodAdSpend;
    final leads = provider.periodLeads;
    final roi = provider.periodRoi;
    final fmt = NumberFormat('#,###');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgDark, borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        _YearStat('연간 매출', '₩${_s(rev)}', AppTheme.mintPrimary),
        _div(),
        _YearStat('연간 광고비', '₩${_s(spend)}', AppTheme.warning),
        _div(),
        _YearStat('마케팅 ROI', '${roi.toStringAsFixed(1)}%', AppTheme.info),
        _div(),
        _YearStat('총 리드', '${fmt.format(leads)}건', AppTheme.success),
      ]),
    );
  }

  Widget _div() => Container(width: 1, height: 28, color: AppTheme.bgCardLight, margin: const EdgeInsets.symmetric(horizontal: 12));

  static String _s(double v) {
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}억';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(0)}만';
    return v.toStringAsFixed(0);
  }
}

class _YearStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _YearStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      ]),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// KPI 달성 현황
// ─────────────────────────────────────────────────────────────
class _KpiAchievementList extends StatelessWidget {
  final AppProvider provider;
  const _KpiAchievementList({required this.provider});

  @override
  Widget build(BuildContext context) {
    final kpis = provider.currentTeamKpis.isEmpty
        ? provider.kpis.take(6).toList()
        : provider.currentTeamKpis.take(6).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('KPI 달성 현황',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ...kpis.map((kpi) {
            final rate = kpi.achievementRate.clamp(0, 100);
            final color = rate >= 80 ? AppTheme.success : rate >= 60 ? AppTheme.warning : AppTheme.error;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(kpi.title,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text('${rate.toStringAsFixed(0)}%',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rate / 100,
                    backgroundColor: AppTheme.bgCardLight,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 활성 캠페인
// ─────────────────────────────────────────────────────────────
class _ActiveCampaigns extends StatelessWidget {
  final AppProvider provider;
  const _ActiveCampaigns({required this.provider});

  @override
  Widget build(BuildContext context) {
    final typeFilter = provider.dashboardConfig.campaignTypeFilter;
    var campaigns = provider.campaigns
        .where((c) => c.status == 'active' || c.status == '진행중')
        .toList();
    // 캠페인 분류 필터 적용
    if (typeFilter != 'all' && typeFilter.isNotEmpty) {
      campaigns = campaigns.where((c) => c.type == typeFilter).toList();
    }
    campaigns = campaigns.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('활성 캠페인',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (typeFilter != 'all') Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.mintPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(typeFilter,
                  style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 14),
          if (campaigns.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                typeFilter == 'all' ? '활성 캠페인 없음' : "'$typeFilter' 분류의 활성 캠페인 없음",
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ))
          else
            ...campaigns.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.mintPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.campaign, color: AppTheme.mintPrimary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.name,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                    Row(children: [
                      if (c.type.isNotEmpty) Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(c.type, style: const TextStyle(color: AppTheme.accentBlue, fontSize: 9)),
                      ),
                      Text('ROI ${c.roi.toStringAsFixed(0)}% · ROAS ${c.roas.toStringAsFixed(1)}x',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ]),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('진행 중', style: TextStyle(color: AppTheme.success, fontSize: 10)),
                ),
              ]),
            )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 위험 알림 TOP 5
// ─────────────────────────────────────────────────────────────
class _RiskTop5 extends StatelessWidget {
  final AppProvider provider;
  const _RiskTop5({required this.provider});

  @override
  Widget build(BuildContext context) {
    final risks = provider.top5RiskItems;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 18),
            const SizedBox(width: 6),
            const Text('위험 알림 TOP 5',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${risks.length}건 감지', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ]),
          const SizedBox(height: 14),
          if (risks.isEmpty)
            const Center(
                child: Text('위험 항목이 없습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)))
          else
            ...risks.asMap().entries.map((e) => _RiskRow(rank: e.key + 1, risk: e.value)),
        ],
      ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  final int rank;
  final dynamic risk;
  const _RiskRow({required this.rank, required this.risk});

  @override
  Widget build(BuildContext context) {
    final levelColor = risk.riskLevel == 'critical'
        ? AppTheme.error
        : risk.riskLevel == 'high'
            ? AppTheme.warning
            : AppTheme.info;
    final levelLabel = risk.riskLevel == 'critical'
        ? 'Critical'
        : risk.riskLevel == 'high'
            ? 'High'
            : 'Medium';
    final daysLeft = risk.dueDate != null ? risk.dueDate!.difference(DateTime.now()).inDays : 0;
    final dDayText = daysLeft < 0 ? 'D+${daysLeft.abs()}' : daysLeft == 0 ? 'D-Day' : 'D-$daysLeft';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: levelColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: levelColor.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(color: levelColor.withValues(alpha: 0.2), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('$rank', style: TextStyle(color: levelColor, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Icon(risk.type == 'task' ? Icons.task_alt : Icons.flag_outlined, color: levelColor, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(risk.title,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
            Text('${risk.assignedTo} · ${risk.reason}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: levelColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6),
          ),
          child: Text(levelLabel,
              style: TextStyle(color: levelColor, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Text(dDayText,
            style: TextStyle(
                color: daysLeft < 0 ? AppTheme.error : AppTheme.textMuted,
                fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 전체 태스크 현황 (클릭하면 태스크 상세로 이동)
// ─────────────────────────────────────────────────────────────
class _AllTasksSection extends StatefulWidget {
  final AppProvider provider;
  const _AllTasksSection({required this.provider});

  @override
  State<_AllTasksSection> createState() => _AllTasksSectionState();
}

class _AllTasksSectionState extends State<_AllTasksSection> {
  String _filter = '전체'; // '전체', '진행', '완료', '대기', '위험'

  @override
  Widget build(BuildContext context) {
    final all = widget.provider.allTasksWithProject;
    final filtered = _applyFilter(all, _filter);
    final filterTabs = ['전체', '진행', '검토', '완료', '대기'];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              const Icon(Icons.task_alt, color: AppTheme.mintPrimary, size: 18),
              const SizedBox(width: 8),
              const Text('전체 태스크 현황',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${filtered.length}/${all.length}개',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 12),
          // 필터 탭
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: filterTabs.map((f) {
                final selected = _filter == f;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.mintPrimary : AppTheme.bgCardLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(f,
                        style: TextStyle(
                          color: selected ? Colors.black : AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        )),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1E3040), height: 1),
          // 태스크 테이블 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: const [
              Expanded(flex: 3, child: Text('태스크', style: TextStyle(color: AppTheme.textMuted, fontSize: 10))),
              Expanded(flex: 2, child: Text('프로젝트', style: TextStyle(color: AppTheme.textMuted, fontSize: 10))),
              Expanded(flex: 1, child: Text('상태', style: TextStyle(color: AppTheme.textMuted, fontSize: 10))),
              Expanded(flex: 1, child: Text('우선순위', style: TextStyle(color: AppTheme.textMuted, fontSize: 10))),
              Expanded(flex: 1, child: Text('진행률', style: TextStyle(color: AppTheme.textMuted, fontSize: 10))),
              Expanded(flex: 1, child: Text('마감', style: TextStyle(color: AppTheme.textMuted, fontSize: 10))),
            ]),
          ),
          const Divider(color: Color(0xFF1E3040), height: 1),
          // 태스크 행
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('해당 조건의 태스크가 없습니다',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              ),
            )
          else
            ...filtered.map((tp) => _TaskRow(tp: tp, provider: widget.provider)),
        ],
      ),
    );
  }

  List<TaskWithProject> _applyFilter(List<TaskWithProject> all, String filter) {
    switch (filter) {
      case '진행': return all.where((t) => t.task.status == TaskStatus.inProgress).toList();
      case '검토': return all.where((t) => t.task.status == TaskStatus.inReview).toList();
      case '완료': return all.where((t) => t.task.status == TaskStatus.done).toList();
      case '대기': return all.where((t) => t.task.status == TaskStatus.todo).toList();
      default: return all;
    }
  }
}

class _TaskRow extends StatelessWidget {
  final TaskWithProject tp;
  final AppProvider provider;
  const _TaskRow({required this.tp, required this.provider});

  @override
  Widget build(BuildContext context) {
    final task = tp.task;
    final project = tp.project;
    final statusColor = _sc(task.status);
    final statusLabel = _sl(task.status);
    final priorityColor = _pc(task.priority);
    final priorityLabel = _pl(task.priority);
    final progress = task.checklistProgress;
    final daysLeft = task.dueDate?.difference(DateTime.now()).inDays;
    final isOverdue = task.isOverdue;
    final fmt = DateFormat('MM/dd');

    return InkWell(
      onTap: () => provider.navigateToTask(task.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF1E3040))),
        ),
        child: Row(children: [
          // 태스크명
          Expanded(flex: 3, child: Row(children: [
            Container(width: 6, height: 6,
                decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(task.title,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis)),
          ])),
          // 프로젝트
          Expanded(flex: 2, child: Text(project.name,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              overflow: TextOverflow.ellipsis)),
          // 상태
          Expanded(flex: 1, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(5),
            ),
            child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10)),
          )),
          // 우선순위
          Expanded(flex: 1, child: Text(priorityLabel,
              style: TextStyle(color: priorityColor, fontSize: 11, fontWeight: FontWeight.w500))),
          // 진행률
          Expanded(flex: 1, child: task.checklist.isEmpty
              ? const Text('-', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))
              : Row(children: [
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      backgroundColor: AppTheme.bgCardLight,
                      valueColor: AlwaysStoppedAnimation(statusColor),
                      minHeight: 4,
                    ),
                  )),
                  const SizedBox(width: 4),
                  Text('${progress.toInt()}%',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                ])),
          // 마감
          Expanded(flex: 1, child: task.dueDate == null
              ? const Text('-', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fmt.format(task.dueDate!),
                      style: TextStyle(
                          color: isOverdue ? AppTheme.error : AppTheme.textSecondary,
                          fontSize: 11)),
                  if (daysLeft != null)
                    Text(
                      isOverdue ? 'D+${daysLeft.abs()}' : daysLeft == 0 ? 'D-Day' : 'D-$daysLeft',
                      style: TextStyle(
                          color: isOverdue ? AppTheme.error : AppTheme.textMuted,
                          fontSize: 9),
                    ),
                ])),
          Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 14),
        ]),
      ),
    );
  }

  Color _sc(TaskStatus s) {
    switch (s) {
      case TaskStatus.todo: return AppTheme.textMuted;
      case TaskStatus.inProgress: return AppTheme.info;
      case TaskStatus.inReview: return AppTheme.warning;
      case TaskStatus.done: return AppTheme.success;
    }
  }
  String _sl(TaskStatus s) {
    switch (s) {
      case TaskStatus.todo: return '대기';
      case TaskStatus.inProgress: return '진행';
      case TaskStatus.inReview: return '검토';
      case TaskStatus.done: return '완료';
    }
  }
  Color _pc(TaskPriority p) {
    switch (p) {
      case TaskPriority.low: return AppTheme.textMuted;
      case TaskPriority.medium: return AppTheme.info;
      case TaskPriority.high: return AppTheme.warning;
      case TaskPriority.urgent: return AppTheme.error;
    }
  }
  String _pl(TaskPriority p) {
    switch (p) {
      case TaskPriority.low: return '낮음';
      case TaskPriority.medium: return '보통';
      case TaskPriority.high: return '높음';
      case TaskPriority.urgent: return '긴급';
    }
  }
}
