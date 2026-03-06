import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';

class TeamDetailPage extends StatefulWidget {
  const TeamDetailPage({super.key});

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> with SingleTickerProviderStateMixin {
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
    final team = provider.selectedTeam;
    if (team == null) return const Center(child: Text('팀을 선택해주세요', style: TextStyle(color: AppTheme.textMuted)));

    final teamColor = Color(int.parse('0xFF${team.colorHex.substring(1)}'));
    final projects = provider.getProjectsForTeam(team.id);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Column(
        children: [
          // Team Header
          Container(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
            color: AppTheme.bgCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: teamColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: Text(team.iconEmoji, style: const TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(team.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
                    Text(team.description, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(children: [
                      _Badge(label: '멤버 ${team.members.length}명', icon: Icons.people_outline, color: teamColor),
                      const SizedBox(width: 8),
                      _Badge(label: '프로젝트 ${projects.length}개', icon: Icons.folder_outlined, color: AppTheme.info),
                    ]),
                  ])),
                  // Action Buttons
                  ElevatedButton.icon(
                    onPressed: () => _showInviteDialog(context, provider, team),
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: const Text('멤버 초대'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateProjectDialog(context, provider, team),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('프로젝트 추가'),
                    style: ElevatedButton.styleFrom(backgroundColor: teamColor, foregroundColor: Colors.white),
                  ),
                ]),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tab,
                  labelColor: teamColor,
                  unselectedLabelColor: AppTheme.textMuted,
                  indicatorColor: teamColor,
                  tabs: const [
                    Tab(text: '프로젝트'),
                    Tab(text: '팀 멤버'),
                    Tab(text: 'KPI'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _ProjectsTab(provider: provider, team: team),
                _MembersTab(provider: provider, team: team),
                _TeamKpiTab(provider: provider, team: team),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context, AppProvider provider, Team team) {
    final emailCtrl = TextEditingController();
    MemberRole role = MemberRole.editor;
    final allUsers = provider.allUsers.where((u) => team.getMember(u.id) == null).toList();
    AppUser? selectedUser;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('팀 멤버 초대', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('사용자 선택', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                if (allUsers.isEmpty)
                  const Text('초대할 수 있는 사용자가 없습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 13))
                else
                  ...allUsers.map((u) {
                    final color = u.avatarColor != null ? Color(int.parse('0xFF${u.avatarColor!.substring(1)}')) : AppTheme.mintPrimary;
                    return RadioListTile<AppUser>(
                      value: u,
                      groupValue: selectedUser,
                      onChanged: (v) => setState(() => selectedUser = v),
                      activeColor: AppTheme.mintPrimary,
                      title: Row(children: [
                        CircleAvatar(radius: 14, backgroundColor: color.withValues(alpha: 0.3), child: Text(u.avatarInitials, style: TextStyle(color: color, fontSize: 10))),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(u.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                          Text(u.email, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                        ]),
                      ]),
                    );
                  }),
                const SizedBox(height: 16),
                const Text('권한 설정', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCardLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E3040)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<MemberRole>(
                      value: role,
                      isExpanded: true,
                      dropdownColor: AppTheme.bgCard,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textMuted, size: 18),
                      items: MemberRole.values
                          .where((r) => r != MemberRole.owner)
                          .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                          ))
                          .toList(),
                      onChanged: (v) { if (v != null) setState(() => role = v); },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: '이메일로 초대 (선택)',
                    hintText: 'user@company.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                if (selectedUser != null) {
                  provider.inviteMember(team.id, selectedUser!.id, role);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('초대'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateProjectDialog(BuildContext context, AppProvider provider, Team team) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedColor = '#00BFA5';
    String selectedEmoji = '📁';
    String category = '캠페인';
    final categories = ['캠페인', '전략기획', 'SEO/콘텐츠', '광고', '브랜딩', '이벤트', '기타'];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) {
          final emojis = ['📁', '🌸', '📊', '✍️', '🎯', '🚀', '💡', '🔥'];
          final colors = ['#00BFA5', '#29B6F6', '#AB47BC', '#FF7043', '#FFB300', '#66BB6A'];
          return AlertDialog(
            backgroundColor: AppTheme.bgCard,
            title: const Text('새 프로젝트 만들기', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: emojis.map((e) => GestureDetector(
                      onTap: () => setState(() => selectedEmoji = e),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selectedEmoji == e ? AppTheme.mintPrimary.withValues(alpha: 0.2) : AppTheme.bgCardLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: selectedEmoji == e ? AppTheme.mintPrimary : Colors.transparent),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 20)),
                      ),
                    )).toList()),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, children: colors.map((c) {
                      final col = Color(int.parse('0xFF${c.substring(1)}'));
                      return GestureDetector(
                        onTap: () => setState(() => selectedColor = c),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(color: col, shape: BoxShape.circle,
                              border: Border.all(color: selectedColor == c ? Colors.white : Colors.transparent, width: 2.5)),
                        ),
                      );
                    }).toList()),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: '프로젝트 이름 *'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: '설명'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: category,
                      dropdownColor: AppTheme.bgCard,
                      decoration: const InputDecoration(labelText: '카테고리'),
                      style: const TextStyle(color: AppTheme.textPrimary),
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => category = v!),
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
                    provider.createProject(
                      teamId: team.id,
                      name: nameCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      category: category,
                      colorHex: selectedColor,
                      iconEmoji: selectedEmoji,
                    );
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('프로젝트 만들기'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Projects Tab
class _ProjectsTab extends StatelessWidget {
  final AppProvider provider;
  final Team team;
  const _ProjectsTab({required this.provider, required this.team});

  @override
  Widget build(BuildContext context) {
    final projects = provider.getProjectsForTeam(team.id);
    if (projects.isEmpty) {
      return const Center(child: Text('프로젝트가 없습니다', style: TextStyle(color: AppTheme.textMuted)));
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: projects.length,
        itemBuilder: (_, i) => _ProjectCard(project: projects[i], provider: provider),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final AppProvider provider;
  const _ProjectCard({required this.project, required this.provider});

  @override
  Widget build(BuildContext context) {
    final projColor = Color(int.parse('0xFF${project.colorHex.substring(1)}'));
    final doneTasks = project.tasks.where((t) => t.status == TaskStatus.done).length;
    final totalTasks = project.tasks.length;
    final completion = project.completionRate;

    return InkWell(
      onTap: () => provider.selectProject(project.id),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: projColor.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(project.iconEmoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(child: Text(project.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: projColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(project.category, style: TextStyle(color: projColor, fontSize: 10)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(project.description, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: completion / 100,
              backgroundColor: AppTheme.bgCardLight,
              valueColor: AlwaysStoppedAnimation<Color>(projColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Text('$doneTasks/$totalTasks 태스크', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            const Spacer(),
            Text('${completion.toStringAsFixed(0)}%', style: TextStyle(color: projColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}

// Members Tab
class _MembersTab extends StatelessWidget {
  final AppProvider provider;
  final Team team;
  const _MembersTab({required this.provider, required this.team});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy.MM.dd');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${team.members.length}명의 팀 멤버', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: team.members.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1E3040)),
              itemBuilder: (_, i) {
                final m = team.members[i];
                final color = m.user.avatarColor != null
                    ? Color(int.parse('0xFF${m.user.avatarColor!.substring(1)}'))
                    : AppTheme.mintPrimary;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: color.withValues(alpha: 0.3),
                    child: Text(m.user.avatarInitials, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                  ),
                  title: Text(m.user.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
                  subtitle: Text(m.user.email, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('가입 ${dateFormat.format(m.joinedAt)}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    const SizedBox(width: 12),
                    _RoleBadge(role: m.role),
                    const SizedBox(width: 8),
                    if (m.role != MemberRole.owner)
                      PopupMenuButton<MemberRole>(
                        icon: const Icon(Icons.more_vert, color: AppTheme.textMuted, size: 16),
                        color: AppTheme.bgCard,
                        itemBuilder: (_) => [
                          ...MemberRole.values.where((r) => r != MemberRole.owner && r != m.role).map((r) =>
                            PopupMenuItem(value: r, child: Text('${r.label}로 변경', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)))
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(value: null, child: Text('팀에서 제거', style: TextStyle(color: AppTheme.error, fontSize: 13))),
                        ],
                        onSelected: (role) {
                          if (role != null) provider.updateMemberRole(team.id, m.id, role);
                          else provider.removeMember(team.id, m.id);
                        },
                      ),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final MemberRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = role == MemberRole.owner ? AppTheme.warning
        : role == MemberRole.admin ? AppTheme.mintPrimary
        : role == MemberRole.editor ? AppTheme.info
        : AppTheme.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(role.label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// Team KPI Tab
class _TeamKpiTab extends StatelessWidget {
  final AppProvider provider;
  final Team team;
  const _TeamKpiTab({required this.provider, required this.team});

  @override
  Widget build(BuildContext context) {
    final kpis = provider.kpis.where((k) => k.teamId == team.id).toList();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('팀 KPI (${kpis.length}개)', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _showAddKpiDialog(context, provider, team),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('KPI 추가', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: kpis.isEmpty
                ? const Center(child: Text('KPI가 없습니다', style: TextStyle(color: AppTheme.textMuted)))
                : ListView.separated(
                    itemCount: kpis.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _KpiRow(kpi: kpis[i], provider: provider),
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddKpiDialog(BuildContext ctx, AppProvider provider, Team team) {
    final titleCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final currentCtrl = TextEditingController();
    String unit = '건';
    bool isTeamKpi = true;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('KPI 추가', style: TextStyle(color: AppTheme.textPrimary)),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleCtrl, style: const TextStyle(color: AppTheme.textPrimary), decoration: const InputDecoration(labelText: 'KPI 이름 *')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: targetCtrl, style: const TextStyle(color: AppTheme.textPrimary), decoration: const InputDecoration(labelText: '목표값'), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: currentCtrl, style: const TextStyle(color: AppTheme.textPrimary), decoration: const InputDecoration(labelText: '현재값'), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextField(
                  onChanged: (v) => unit = v,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: '단위'),
                )),
              ]),
              const SizedBox(height: 10),
              SwitchListTile(
                dense: true,
                title: const Text('팀 KPI', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                value: isTeamKpi,
                activeColor: AppTheme.mintPrimary,
                onChanged: (v) => setState(() => isTeamKpi = v),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty) {
                  provider.addKpi(KpiModel(
                    id: 'kpi_${DateTime.now().millisecondsSinceEpoch}',
                    title: titleCtrl.text.trim(),
                    category: '기타',
                    target: double.tryParse(targetCtrl.text) ?? 100,
                    current: double.tryParse(currentCtrl.text) ?? 0,
                    unit: unit.isEmpty ? '건' : unit,
                    period: provider.selectedPeriod,
                    isTeamKpi: isTeamKpi,
                    dueDate: DateTime(DateTime.now().year, 12, 31),
                    teamId: team.id,
                  ));
                  Navigator.pop(c);
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

class _KpiRow extends StatelessWidget {
  final KpiModel kpi;
  final AppProvider provider;
  const _KpiRow({required this.kpi, required this.provider});

  @override
  Widget build(BuildContext context) {
    final rate = kpi.achievementRate.clamp(0, 100);
    final color = rate >= 80 ? AppTheme.success : rate >= 60 ? AppTheme.warning : AppTheme.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(kpi.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: rate / 100, backgroundColor: AppTheme.bgCardLight, valueColor: AlwaysStoppedAnimation(color), minHeight: 5),
          ),
          const SizedBox(height: 4),
          Text('${kpi.current.toStringAsFixed(kpi.current < 10 ? 1 : 0)}${kpi.unit} / ${kpi.target.toStringAsFixed(kpi.target < 10 ? 1 : 0)}${kpi.unit}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ])),
        const SizedBox(width: 20),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${rate.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
          if (kpi.isTeamKpi)
            const _SmallBadge(label: '팀 KPI', color: AppTheme.mintPrimary)
          else
            const _SmallBadge(label: '개인 KPI', color: AppTheme.info),
        ]),
      ]),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10)),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _Badge({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ]),
    );
  }
}
