import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';

class TeamListPage extends StatelessWidget {
  const TeamListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final teams = provider.teams;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      floatingActionButton: isMobile
          ? FloatingActionButton(
              onPressed: () => _showCreateTeamDialog(context, provider),
              backgroundColor: AppTheme.mintPrimary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMobile)
                Row(children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('팀 관리', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('팀 프로젝트 생성 및 멤버 관리', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateTeamDialog(context, provider),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('새 팀 만들기'),
                  ),
                ]),
              if (!isMobile) const SizedBox(height: 24),
              if (teams.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.groups_outlined, color: AppTheme.textMuted, size: 64),
                      const SizedBox(height: 16),
                      const Text('아직 팀이 없습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _showCreateTeamDialog(context, provider),
                        child: const Text('첫 팀 만들기'),
                      ),
                    ]),
                  ),
                )
              else
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isMobile ? 1 : 3,
                      childAspectRatio: isMobile ? 2.2 : 1.4,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: teams.length,
                    itemBuilder: (_, i) => _TeamCard(team: teams[i], provider: provider),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateTeamDialog(BuildContext context, AppProvider provider) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedColor = '#00BFA5';
    String selectedEmoji = '🎯';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) {
          final emojis = ['🎯', '📱', '🚀', '💡', '🌟', '📊', '🎨', '⚡', '🔥', '💎'];
          final colors = ['#00BFA5', '#29B6F6', '#AB47BC', '#FF7043', '#FFB300', '#66BB6A'];
          return AlertDialog(
            backgroundColor: AppTheme.bgCard,
            title: const Text('새 팀 만들기', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('팀 아이콘', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: emojis.map((e) => GestureDetector(
                      onTap: () => setState(() => selectedEmoji = e),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: selectedEmoji == e ? AppTheme.mintPrimary.withValues(alpha: 0.2) : AppTheme.bgCardLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: selectedEmoji == e ? AppTheme.mintPrimary : Colors.transparent),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    )).toList()),
                    const SizedBox(height: 16),
                    const Text('팀 색상', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 10, children: colors.map((c) {
                      final col = Color(int.parse('0xFF${c.substring(1)}'));
                      return GestureDetector(
                        onTap: () => setState(() => selectedColor = c),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: col, shape: BoxShape.circle,
                              border: Border.all(color: selectedColor == c ? Colors.white : Colors.transparent, width: 3)),
                        ),
                      );
                    }).toList()),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: '팀 이름 *', hintText: '예: 마케팅 전략팀'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: '팀 설명', hintText: '팀의 목표와 역할을 설명하세요'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isNotEmpty) {
                    provider.createTeam(
                      name: nameCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      colorHex: selectedColor,
                      iconEmoji: selectedEmoji,
                    );
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('팀 만들기'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final Team team;
  final AppProvider provider;
  const _TeamCard({required this.team, required this.provider});

  @override
  Widget build(BuildContext context) {
    final teamColor = Color(int.parse('0xFF${team.colorHex.substring(1)}'));
    final projects = provider.getProjectsForTeam(team.id);

    return InkWell(
      onTap: () => provider.selectTeam(team.id),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: teamColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: teamColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Text(team.iconEmoji, style: const TextStyle(fontSize: 22)),
              ),
              const Spacer(),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: teamColor, shape: BoxShape.circle),
              ),
            ]),
            const SizedBox(height: 12),
            Text(team.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(team.description, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Row(children: [
              _StatChip(label: '멤버 ${team.members.length}명', icon: Icons.person_outline),
              const SizedBox(width: 8),
              _StatChip(label: '프로젝트 ${projects.length}개', icon: Icons.folder_outlined),
            ]),
            const SizedBox(height: 12),
            // Member avatars
            Row(children: [
              ...team.members.take(5).map((m) {
                final col = Color(int.parse('0xFF${m.user.avatarColor?.substring(1) ?? '00BFA5'}'));
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: CircleAvatar(
                    radius: 13,
                    backgroundColor: col.withValues(alpha: 0.3),
                    child: Text(m.user.avatarInitials, style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                );
              }),
              if (team.members.length > 5)
                CircleAvatar(
                  radius: 13,
                  backgroundColor: AppTheme.bgCardLight,
                  child: Text('+${team.members.length - 5}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => provider.selectTeam(team.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: teamColor.withValues(alpha: 0.2),
                  foregroundColor: teamColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('열기', style: TextStyle(fontSize: 12)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _StatChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: AppTheme.textMuted, size: 12),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ]),
    );
  }
}
