import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                  Text('마케팅 퍼널', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Awareness → Retention 퍼널 단계별 전환 분석', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                ]),
                const SizedBox(height: 24),
              ],

              if (isMobile) ...[
                _FunnelVisualization(stages: stages),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _FunnelVisualization(stages: stages)),
                    const SizedBox(width: 20),
                    Expanded(flex: 3, child: _FunnelStageDetails(stages: stages)),
                  ],
                ),
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

class _FunnelVisualization extends StatelessWidget {
  final List<dynamic> stages;
  const _FunnelVisualization({required this.stages});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: stages.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          final maxVal = stages.first.value;
          final widthFactor = s.value / maxVal;
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
              widthFactor: widthFactor.clamp(0.1, 1.0),
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
                    '${s.conversionRate.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: s.conversionRate >= 50 ? AppTheme.success : s.conversionRate >= 25 ? AppTheme.warning : AppTheme.error,
                      fontSize: 10,
                    ),
                  ),
                ]),
              ),
          ]);
        }).toList(),
      ),
    );
  }

  static String _fmtNum(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _FunnelStageDetails extends StatelessWidget {
  final List<dynamic> stages;
  const _FunnelStageDetails({required this.stages});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: stages.asMap().entries.map((e) {
        final s = e.value;
        final colors = [AppTheme.mintPrimary, const Color(0xFF29B6F6), const Color(0xFFAB47BC), const Color(0xFFFF7043), const Color(0xFFFFB300), const Color(0xFF66BB6A)];
        final color = colors[e.key % colors.length];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.2))),
          child: Row(children: [
            Text(s.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
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
              Text(_fmtNum(s.value), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              if (e.key > 0)
                Text('전환 ${s.conversionRate.toStringAsFixed(1)}%',
                    style: TextStyle(color: s.conversionRate >= 50 ? AppTheme.success : AppTheme.warning, fontSize: 11)),
            ]),
          ]),
        );
      }).toList(),
    );
  }

  static String _fmtNum(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}
