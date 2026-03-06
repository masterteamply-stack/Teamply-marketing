import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

/// AI Developer 사이드 패널 (데스크톱 우측 슬라이드 패널)
class AiDeveloperPanel extends StatefulWidget {
  const AiDeveloperPanel({super.key});

  @override
  State<AiDeveloperPanel> createState() => _AiDeveloperPanelState();
}

class _AiDeveloperPanelState extends State<AiDeveloperPanel> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  // Predefined quick prompts
  static const _quickPrompts = [
    '현재 KPI 달성률 요약해줘',
    '위험도 높은 태스크 알려줘',
    '이번 달 ROI 분석해줘',
    '캠페인 성과 비교해줘',
    '팀별 진행 현황 알려줘',
  ];

  // Simulated AI responses
  String _generateAiResponse(String query, AppProvider provider) {
    final q = query.toLowerCase();
    if (q.contains('kpi') || q.contains('달성')) {
      final avg = provider.avgKpiAchievement;
      final kpis = provider.kpis;
      final onTrack = kpis.where((k) => k.isOnTrack).length;
      return '📊 **KPI 현황 요약**\n\n'
          '• 전체 KPI 수: ${kpis.length}개\n'
          '• 달성 중: $onTrack개 (${(onTrack / kpis.length * 100).toStringAsFixed(0)}%)\n'
          '• 평균 달성률: ${avg.toStringAsFixed(1)}%\n\n'
          '⚠️ 주의 필요: ${kpis.where((k) => k.achievementRate < 70).map((k) => k.title).join(', ')}\n\n'
          '✅ 순항 중: ${kpis.where((k) => k.achievementRate >= 80).map((k) => k.title).join(', ')}';
    }
    if (q.contains('위험') || q.contains('리스크')) {
      final risks = provider.top5RiskItems;
      if (risks.isEmpty) return '✅ 현재 위험도 높은 항목이 없습니다. 모든 태스크와 KPI가 정상 궤도에 있어요!';
      final buf = StringBuffer('🚨 **위험 항목 TOP ${risks.length}**\n\n');
      for (final r in risks) {
        final icon = r.riskLevel == 'critical' ? '🔴' : r.riskLevel == 'high' ? '🟠' : '🟡';
        buf.writeln('$icon ${r.title}');
        buf.writeln('   담당: ${r.assignedTo} · ${r.reason}\n');
      }
      return buf.toString();
    }
    if (q.contains('roi') || q.contains('매출') || q.contains('분석')) {
      final roi = provider.overallRoi;
      final revenue = provider.totalRevenue;
      final spent = provider.totalSpent;
      return '💰 **마케팅 ROI 분석**\n\n'
          '• 총 매출: ₩${_fmt(revenue)}\n'
          '• 총 집행 비용: ₩${_fmt(spent)}\n'
          '• 전체 ROI: ${roi.toStringAsFixed(1)}%\n\n'
          '${roi >= 200 ? "✅ 우수한 ROI입니다! 현재 전략을 유지하세요." : roi >= 100 ? "👍 양호한 수준입니다. 퍼포먼스 채널 집중 검토 권장." : "⚠️ ROI 개선 필요. 비효율 채널 재검토 바랍니다."}';
    }
    if (q.contains('캠페인')) {
      final campaigns = provider.campaigns;
      final active = campaigns.where((c) => c.status == 'active');
      final buf = StringBuffer('📣 **캠페인 성과 요약**\n\n');
      for (final c in active) {
        buf.writeln('• **${c.name}**');
        buf.writeln('  ROI: ${c.roi.toStringAsFixed(0)}% · CTR: ${c.ctr.toStringAsFixed(2)}% · 전환: ${c.conversions.toInt()}건\n');
      }
      buf.writeln('\n최고 성과 캠페인: ${active.reduce((a, b) => a.roi > b.roi ? a : b).name}');
      return buf.toString();
    }
    if (q.contains('팀') || q.contains('진행')) {
      final teams = provider.teams;
      final buf = StringBuffer('👥 **팀별 현황**\n\n');
      for (final t in teams) {
        final projects = provider.getProjectsForTeam(t.id);
        final totalTasks = projects.fold(0, (s, p) => s + p.tasks.length);
        final doneTasks = projects.fold(0, (s, p) => s + p.tasks.where((tk) => tk.status == TaskStatus.done).length);
        buf.writeln('**${t.iconEmoji} ${t.name}**');
        buf.writeln('  멤버: ${t.members.length}명 · 프로젝트: ${projects.length}개 · 태스크: $doneTasks/$totalTasks 완료\n');
      }
      return buf.toString();
    }
    return '🤖 안녕하세요! Marketing Dashboard AI 어시스턴트입니다.\n\n'
        '다음과 같은 질문을 해보세요:\n'
        '• KPI 현황 및 달성률 분석\n'
        '• 위험 태스크/KPI 확인\n'
        '• 캠페인 ROI 분석\n'
        '• 팀별 진행 현황\n\n'
        '무엇이든 물어보세요! 💪';
  }

  String _fmt(double v) {
    if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}억';
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(0)}만';
    return v.toStringAsFixed(0);
  }

  void _sendMessage(AppProvider provider) {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    provider.addAiMessage(text, isUser: true);
    provider.addAiLoadingMessage();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        final response = _generateAiResponse(text, provider);
        provider.replaceLastAiMessage(response);
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });
    Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (!provider.aiPanelOpen) return const SizedBox.shrink();

    return Container(
      width: 360,
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(left: BorderSide(color: Color(0xFF1E3040), width: 1)),
      ),
      child: Column(
        children: [
          _buildHeader(provider),
          Expanded(child: _buildMessageList(provider)),
          _buildQuickPrompts(provider),
          _buildInput(provider),
        ],
      ),
    );
  }

  Widget _buildHeader(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.bgCardLight,
        border: Border(bottom: BorderSide(color: Color(0xFF1E3040))),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.mintPrimary, Color(0xFF00897B)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Developer', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                Text('마케팅 인사이트 어시스턴트', style: TextStyle(color: AppTheme.mintPrimary, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            onPressed: provider.closeAiPanel,
            icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(AppProvider provider) {
    final messages = provider.aiMessages;
    if (messages.isEmpty) {
      return _buildWelcomeScreen();
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      itemBuilder: (ctx, i) => _buildMessage(messages[i]),
    );
  }

  Widget _buildWelcomeScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.mintPrimary, Color(0xFF00897B)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('AI Developer', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const Center(
            child: Text('대시보드 인사이트를 빠르게 분석해드려요', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ),
          const SizedBox(height: 24),
          const Text('💡 무엇을 도와드릴까요?', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._quickPrompts.map((p) => _QuickPromptChip(
            prompt: p,
            onTap: () {
              final prov = context.read<AppProvider>();
              prov.addAiMessage(p, isUser: true);
              prov.addAiLoadingMessage();
              final response = _generateAiResponse(p, prov);
              Future.delayed(const Duration(milliseconds: 800), () {
                if (mounted) {
                  prov.replaceLastAiMessage(response);
                  Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
                }
              });
            },
          )),
        ],
      ),
    );
  }

  Widget _buildMessage(AiMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.mintPrimary.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12), topRight: Radius.circular(12),
              bottomLeft: Radius.circular(12), bottomRight: Radius.circular(4),
            ),
            border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.4)),
          ),
          child: Text(msg.content, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.bgCardLight,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4), topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12),
          ),
        ),
        child: msg.isLoading
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.mintPrimary)),
                const SizedBox(width: 8),
                const Text('분석 중...', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ])
            : _buildFormattedText(msg.content),
      ),
    );
  }

  Widget _buildFormattedText(String content) {
    final lines = content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.startsWith('**') && line.endsWith('**')) {
          return Text(
            line.replaceAll('**', ''),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
          );
        }
        if (line.startsWith('• **') || line.contains('**')) {
          // Bold inline
          final parts = line.split('**');
          return RichText(
            text: TextSpan(
              children: parts.asMap().entries.map((e) => TextSpan(
                text: e.key.isOdd ? e.value : e.value,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: e.key.isOdd ? FontWeight.w600 : FontWeight.normal,
                ),
              )).toList(),
            ),
          );
        }
        return Text(
          line,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5),
        );
      }).toList(),
    );
  }

  Widget _buildQuickPrompts(AppProvider provider) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _quickPrompts.map((p) => GestureDetector(
          onTap: () {
            _inputCtrl.text = p;
            _sendMessage(provider);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.bgCardLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E3040)),
            ),
            child: Text(p, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildInput(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppTheme.bgCardLight,
        border: Border(top: BorderSide(color: Color(0xFF1E3040))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요...',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppTheme.bgDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFF1E3040)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFF1E3040)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppTheme.mintPrimary),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onSubmitted: (_) => _sendMessage(provider),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(provider),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.mintPrimary, Color(0xFF00897B)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.send, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPromptChip extends StatelessWidget {
  final String prompt;
  final VoidCallback onTap;
  const _QuickPromptChip({required this.prompt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.bgCardLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1E3040)),
        ),
        child: Row(
          children: [
            const Icon(Icons.chat_bubble_outline, color: AppTheme.mintPrimary, size: 14),
            const SizedBox(width: 8),
            Expanded(child: Text(prompt, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
            const Icon(Icons.arrow_forward_ios, color: AppTheme.textMuted, size: 10),
          ],
        ),
      ),
    );
  }
}
