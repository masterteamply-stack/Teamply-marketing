import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/task_link_panel.dart';

class FunnelPage extends StatelessWidget {
  const FunnelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final stages = provider.funnelStages;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final allTasks = provider.allTasksWithProject;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMobile) ...[
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('마케팅 퍼널 분석', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Awareness → Retention 단계별 전환율 분석 및 개선 인사이트', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                ]),
                const SizedBox(height: 24),
              ],

              if (stages.isEmpty)
                const Center(child: Text('퍼널 데이터가 없습니다', style: TextStyle(color: AppTheme.textMuted)))
              else if (isMobile) ...[
                _FunnelVisualization(stages: stages),
                const SizedBox(height: 16),
                _FunnelInsightPanel(stages: stages),
                const SizedBox(height: 16),
                _FunnelConversionChart(stages: stages),
                const SizedBox(height: 16),
                _FunnelStageDetails(stages: stages),
                const SizedBox(height: 16),
                TaskLinkPanel(
                  title: '퍼널 관련 전체 태스크',
                  tasks: allTasks,
                  provider: provider,
                  accentColor: const Color(0xFF29B6F6),
                ),
              ] else ...[
                // 상단: 퍼널 + 인사이트
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _FunnelVisualization(stages: stages)),
                    const SizedBox(width: 20),
                    Expanded(flex: 3, child: Column(children: [
                      _FunnelInsightPanel(stages: stages),
                      const SizedBox(height: 16),
                      _FunnelConversionChart(stages: stages),
                    ])),
                  ],
                ),
                const SizedBox(height: 20),
                _FunnelStageDetails(stages: stages),
                const SizedBox(height: 20),
                TaskLinkPanel(
                  title: '퍼널 관련 전체 태스크',
                  tasks: allTasks,
                  provider: provider,
                  accentColor: const Color(0xFF29B6F6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 퍼널 시각화 (삼각형 구조) ─────────────────────────────────────────────
class _FunnelVisualization extends StatelessWidget {
  final List<dynamic> stages;
  const _FunnelVisualization({required this.stages});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('퍼널 단계', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ...stages.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            final maxVal = stages.first.value;
            final widthFactor = (s.value / maxVal).clamp(0.1, 1.0);
            final colors = [
              AppTheme.mintPrimary,
              const Color(0xFF29B6F6),
              const Color(0xFFAB47BC),
              const Color(0xFFFF7043),
              const Color(0xFFFFB300),
              const Color(0xFF66BB6A),
            ];
            final color = colors[i % colors.length];

            return Column(children: [
              FractionallySizedBox(
                widthFactor: widthFactor,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    Text(s.icon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(s.label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    Text(_fmtNum(s.value), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              if (i < stages.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.arrow_downward, color: AppTheme.textMuted, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '전환율 ${s.conversionRate.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: s.conversionRate >= 50 ? AppTheme.success : s.conversionRate >= 25 ? AppTheme.warning : AppTheme.error,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]),
                ),
            ]);
          }),
        ],
      ),
    );
  }

  static String _fmtNum(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ─── 인사이트 패널 (이탈 구간 및 개선 방향) ─────────────────────────────────
class _FunnelInsightPanel extends StatelessWidget {
  final List<dynamic> stages;
  const _FunnelInsightPanel({required this.stages});

  @override
  Widget build(BuildContext context) {
    // 가장 큰 이탈 구간 찾기
    if (stages.length < 2) return const SizedBox();

    // 각 구간 드롭률 계산
    final drops = <Map<String, dynamic>>[];
    for (int i = 0; i < stages.length - 1; i++) {
      final from = stages[i];
      final to = stages[i + 1];
      final dropRate = ((from.value - to.value) / from.value * 100);
      drops.add({
        'from': from.label,
        'to': to.label,
        'fromIcon': from.icon,
        'toIcon': to.icon,
        'dropRate': dropRate,
        'dropCount': from.value - to.value,
        'conversionRate': to.conversionRate as double,
        'index': i,
      });
    }
    drops.sort((a, b) => (b['dropRate'] as double).compareTo(a['dropRate'] as double));
    final biggestDrop = drops.first;

    final colors = [AppTheme.mintPrimary, const Color(0xFF29B6F6), const Color(0xFFAB47BC), const Color(0xFFFF7043), const Color(0xFFFFB300), const Color(0xFF66BB6A)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.insights, color: AppTheme.error, size: 16),
          ),
          const SizedBox(width: 10),
          const Text('이탈 구간 인사이트', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 14),

        // 최대 이탈 구간 강조
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.error.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.warning_amber, color: AppTheme.error, size: 14),
              const SizedBox(width: 6),
              const Text('가장 큰 이탈 구간', style: TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Text('${biggestDrop['fromIcon']} ${biggestDrop['from']}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, color: AppTheme.textMuted, size: 14),
              ),
              Text('${biggestDrop['toIcon']} ${biggestDrop['to']}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  '이탈률 ${(biggestDrop['dropRate'] as double).toStringAsFixed(1)}%',
                  style: const TextStyle(color: AppTheme.error, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '약 ${_fmtNum(biggestDrop['dropCount'] as double)}명 이탈',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 12),

        // 개선 인사이트 제안
        const Text('개선 방향 제안', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ..._buildSuggestions(biggestDrop),
        const SizedBox(height: 12),

        // 전체 구간별 이탈률 요약
        const Text('구간별 이탈률 요약', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...drops.map((d) {
          final idx = d['index'] as int;
          final color = colors[idx % colors.length];
          final dropRate = d['dropRate'] as double;
          final convRate = d['conversionRate'] as double;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(
                child: Text(
                  '${d['fromIcon']} → ${d['toIcon']} ${d['from']} → ${d['to']}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: convRate >= 50 ? AppTheme.success.withValues(alpha: 0.12) : AppTheme.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '전환 ${convRate.toStringAsFixed(1)}%',
                  style: TextStyle(color: convRate >= 50 ? AppTheme.success : AppTheme.error, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  List<Widget> _buildSuggestions(Map<String, dynamic> drop) {
    final from = drop['from'] as String;
    final to = drop['to'] as String;
    final suggestions = _getSuggestions(from, to);

    return suggestions.map((s) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 6, height: 6,
          decoration: const BoxDecoration(color: AppTheme.mintPrimary, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(s, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
      ]),
    )).toList();
  }

  List<String> _getSuggestions(String from, String to) {
    final key = '${from}_$to'.toLowerCase();
    if (key.contains('awareness') || from.contains('인지') || to.contains('관심')) {
      return ['광고 크리에이티브 개선으로 클릭율 향상', 'A/B 테스트로 최적 메시지 발굴', '타겟 오디언스 세분화 재검토'];
    } else if (from.contains('관심') || to.contains('고려')) {
      return ['랜딩페이지 내용 명확화 및 CTA 강화', '사회적 증거(리뷰, 사례) 추가', '이메일/리타겟팅 캠페인 강화'];
    } else if (from.contains('고려') || to.contains('구매의도')) {
      return ['장바구니 이탈 방지 팝업 도입', '한정 혜택/할인 프로모션 검토', '제품 비교 가이드 제공'];
    } else if (from.contains('구매') || to.contains('전환')) {
      return ['결제 프로세스 단순화', '추가 결제 수단 확대', '무료 체험/환불 정책 강조'];
    } else if (from.contains('전환') || to.contains('유지')) {
      return ['온보딩 프로세스 최적화', '첫 구매 후 CS 강화', '포인트/멤버십 프로그램 도입'];
    }
    return ['해당 단계 UX 개선 검토', '사용자 인터뷰를 통한 이탈 원인 파악', '경쟁사 벤치마킹 진행'];
  }

  static String _fmtNum(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ─── 전환율 바 차트 ─────────────────────────────────────────────────────────
class _FunnelConversionChart extends StatelessWidget {
  final List<dynamic> stages;
  const _FunnelConversionChart({required this.stages});

  @override
  Widget build(BuildContext context) {
    if (stages.length < 2) return const SizedBox();

    final convRates = stages.skip(1).map((s) => s.conversionRate as double).toList();
    final labels = stages.skip(1).map((s) => s.label as String).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('단계별 전환율', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 3, color: AppTheme.success),
                const SizedBox(width: 4),
                const Text('50% 이상 양호', style: TextStyle(color: AppTheme.success, fontSize: 10)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: 110,
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFF1E3040), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= labels.length) return const SizedBox();
                      final label = labels[i].length > 6 ? '${labels[i].substring(0, 5)}…' : labels[i];
                      return Padding(padding: const EdgeInsets.only(top: 4), child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9), textAlign: TextAlign.center));
                    })),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)))),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                barGroups: convRates.asMap().entries.map((e) {
                  final rate = e.value.clamp(0.0, 110.0);
                  final color = rate >= 50 ? AppTheme.success : rate >= 30 ? AppTheme.warning : AppTheme.error;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [BarChartRodData(toY: rate, color: color, width: 24, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))],
                    showingTooltipIndicators: [0],
                  );
                }).toList(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.bgCard,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.toStringAsFixed(1)}%',
                        TextStyle(
                          color: rod.toY >= 50 ? AppTheme.success : rod.toY >= 30 ? AppTheme.warning : AppTheme.error,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                extraLinesData: ExtraLinesData(horizontalLines: [
                  HorizontalLine(y: 50, color: AppTheme.success.withValues(alpha: 0.3), strokeWidth: 1.5, dashArray: [4, 4]),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 상세 스테이지 테이블 ────────────────────────────────────────────────────
class _FunnelStageDetails extends StatelessWidget {
  final List<dynamic> stages;
  const _FunnelStageDetails({required this.stages});

  @override
  Widget build(BuildContext context) {
    final colors = [AppTheme.mintPrimary, const Color(0xFF29B6F6), const Color(0xFFAB47BC), const Color(0xFFFF7043), const Color(0xFFFFB300), const Color(0xFF66BB6A)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('단계별 상세 현황', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...stages.asMap().entries.map((e) {
          final s = e.value;
          final color = colors[e.key % colors.length];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(s.icon, style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: s.value / stages.first.value,
                    backgroundColor: AppTheme.bgCardLight,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 5,
                  ),
                ),
              ])),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_fmtNum(s.value), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                Text('전체 대비 ${(s.value / stages.first.value * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                if (e.key > 0) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: s.conversionRate >= 50 ? AppTheme.success.withValues(alpha: 0.12) : AppTheme.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '전환 ${(s.conversionRate as double).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: s.conversionRate >= 50 ? AppTheme.success : AppTheme.warning,
                        fontSize: 10, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ]),
            ]),
          );
        }),
      ],
    );
  }

  static String _fmtNum(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}
