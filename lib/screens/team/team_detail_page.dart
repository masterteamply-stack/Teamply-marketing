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
    _tab = TabController(length: 4, vsync: this);
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
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Column(
        children: [
          // Team Header
          Container(
            padding: EdgeInsets.fromLTRB(isMobile ? 16 : 28, isMobile ? 16 : 24, isMobile ? 16 : 28, 0),
            color: AppTheme.bgCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: teamColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: Text(team.iconEmoji, style: TextStyle(fontSize: isMobile ? 22 : 28)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(team.name, style: TextStyle(color: AppTheme.textPrimary, fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.w700)),
                    if (!isMobile)
                      Text(team.description, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(children: [
                      _Badge(label: '멤버 ${team.members.length}명', icon: Icons.people_outline, color: teamColor),
                      const SizedBox(width: 8),
                      _Badge(label: '프로젝트 ${projects.length}개', icon: Icons.folder_outlined, color: AppTheme.info),
                    ]),
                  ])),
                  if (!isMobile) ...[
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
                  ] else
                    PopupMenuButton(
                      icon: const Icon(Icons.more_vert, color: AppTheme.textMuted),
                      color: AppTheme.bgCard,
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          onTap: () => Future.delayed(Duration.zero, () => _showInviteDialog(context, provider, team)),
                          child: const Row(children: [Icon(Icons.person_add_outlined, size: 16, color: AppTheme.textSecondary), SizedBox(width: 8), Text('멤버 초대', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13))]),
                        ),
                        PopupMenuItem(
                          onTap: () => Future.delayed(Duration.zero, () => _showCreateProjectDialog(context, provider, team)),
                          child: Row(children: [Icon(Icons.add, size: 16, color: teamColor), const SizedBox(width: 8), const Text('프로젝트 추가', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13))]),
                        ),
                      ],
                    ),
                ]),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tab,
                  labelColor: teamColor,
                  unselectedLabelColor: AppTheme.textMuted,
                  indicatorColor: teamColor,
                  labelStyle: TextStyle(fontSize: isMobile ? 12 : 14),
                  tabs: const [
                    Tab(text: '프로젝트'),
                    Tab(text: '팀 멤버'),
                    Tab(text: 'KPI'),
                    Tab(text: '팀 설정'),
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
                _TeamSettingsTab(provider: provider, team: team),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context, AppProvider provider, Team team) {
    // 탭: 0 = 기존 사용자 선택, 1 = 이메일로 신규 초대
    int tabIndex = 0;
    MemberRole role = MemberRole.editor;
    AppUser? selectedUser;

    // 신규 이메일 초대용
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String nameError = '';
    String emailError = '';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // 다이얼로그 내에서 최신 팀 상태 반영 (provider에서 실시간 조회)
          final currentTeam = provider.teams.firstWhere(
            (t) => t.id == team.id,
            orElse: () => team,
          );
          final availableUsers = provider.allUsers
              .where((u) => currentTeam.getMember(u.id) == null)
              .toList();

          bool canInviteExisting = tabIndex == 0 && selectedUser != null;
          bool canInviteNew = tabIndex == 1 &&
              nameCtrl.text.trim().isNotEmpty &&
              emailCtrl.text.trim().contains('@');

          return AlertDialog(
            backgroundColor: AppTheme.bgCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.mintPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_outlined, color: AppTheme.mintPrimary, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('팀 멤버 초대', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
            ]),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 탭 전환 버튼
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCardLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Expanded(child: GestureDetector(
                          onTap: () => setDialogState(() { tabIndex = 0; selectedUser = null; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: tabIndex == 0 ? AppTheme.mintPrimary : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              '기존 멤버 선택',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: tabIndex == 0 ? Colors.white : AppTheme.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )),
                        Expanded(child: GestureDetector(
                          onTap: () => setDialogState(() { tabIndex = 1; selectedUser = null; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: tabIndex == 1 ? AppTheme.mintPrimary : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              '이메일로 신규 초대',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: tabIndex == 1 ? Colors.white : AppTheme.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    // 탭 0: 기존 사용자 목록
                    if (tabIndex == 0) ...[
                      Row(children: [
                        const Text('사용자 선택', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        const Spacer(),
                        Text('${availableUsers.length}명 초대 가능', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      ]),
                      const SizedBox(height: 8),
                      if (availableUsers.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.bgCardLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF1E3040)),
                          ),
                          child: Column(children: [
                            Icon(Icons.check_circle_outline, color: AppTheme.success.withValues(alpha: 0.6), size: 36),
                            const SizedBox(height: 8),
                            const Text('모든 사용자가 이미 팀에 소속되어 있습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 12), textAlign: TextAlign.center),
                            const SizedBox(height: 4),
                            const Text('이메일로 신규 초대 탭을 이용하세요', style: TextStyle(color: AppTheme.mintPrimary, fontSize: 11), textAlign: TextAlign.center),
                          ]),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          decoration: BoxDecoration(
                            color: AppTheme.bgCardLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF1E3040)),
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            children: availableUsers.map((u) {
                              final isSelected = selectedUser?.id == u.id;
                              final color = u.avatarColor != null
                                  ? Color(int.parse('0xFF${u.avatarColor!.substring(1)}'))
                                  : AppTheme.mintPrimary;
                              return InkWell(
                                onTap: () => setDialogState(() => selectedUser = isSelected ? null : u),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.mintPrimary.withValues(alpha: 0.12) : Colors.transparent,
                                    border: isSelected ? Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.3)) : null,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: color.withValues(alpha: 0.25),
                                      child: Text(u.avatarInitials, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(u.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                                      Text(u.email, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                    ])),
                                    if (isSelected)
                                      const Icon(Icons.check_circle, color: AppTheme.mintPrimary, size: 18),
                                  ]),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],

                    // 탭 1: 이메일 직접 입력
                    if (tabIndex == 1) ...[
                      const Text('새 멤버 정보 입력', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.info.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.info_outline, color: AppTheme.info, size: 14),
                          SizedBox(width: 6),
                          Expanded(child: Text(
                            '아직 시스템에 없는 신규 멤버를 이름과 이메일로 추가합니다',
                            style: TextStyle(color: AppTheme.info, fontSize: 11),
                          )),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        onChanged: (_) => setDialogState(() => nameError = ''),
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: '이름 *',
                          hintText: '홍길동',
                          prefixIcon: const Icon(Icons.person_outline, size: 18),
                          errorText: nameError.isEmpty ? null : nameError,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: emailCtrl,
                        onChanged: (_) => setDialogState(() => emailError = ''),
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: '이메일 주소 *',
                          hintText: 'user@company.com',
                          prefixIcon: const Icon(Icons.email_outlined, size: 18),
                          errorText: emailError.isEmpty ? null : emailError,
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    // 권한 설정 (공통)
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
                                child: Row(children: [
                                  Icon(_roleIcon(r), color: _roleColor(r), size: 14),
                                  const SizedBox(width: 8),
                                  Text(r.label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                                  const SizedBox(width: 6),
                                  Text(_roleDesc(r), style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                ]),
                              ))
                              .toList(),
                          onChanged: (v) { if (v != null) setDialogState(() => role = v); },
                        ),
                      ),
                    ),

                    // 선택된 사용자 미리보기 (탭0)
                    if (tabIndex == 0 && selectedUser != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.mintPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.25)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.check_circle, color: AppTheme.mintPrimary, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${selectedUser!.name} (${selectedUser!.email}) → ${role.label}로 초대',
                            style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 12),
                          ),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소', style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton.icon(
                onPressed: (canInviteExisting || canInviteNew) ? () {
                  if (tabIndex == 0 && selectedUser != null) {
                    // 기존 사용자 초대
                    provider.inviteMember(team.id, selectedUser!.id, role);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('✅ ${selectedUser!.name}을(를) ${role.label}로 추가했습니다'),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ));
                  } else if (tabIndex == 1) {
                    // 유효성 검사
                    bool hasError = false;
                    if (nameCtrl.text.trim().isEmpty) {
                      setDialogState(() => nameError = '이름을 입력해주세요');
                      hasError = true;
                    }
                    final email = emailCtrl.text.trim();
                    if (email.isEmpty) {
                      setDialogState(() => emailError = '이메일을 입력해주세요');
                      hasError = true;
                    } else if (!email.contains('@') || !email.contains('.')) {
                      setDialogState(() => emailError = '올바른 이메일 형식이 아닙니다');
                      hasError = true;
                    }
                    // 중복 이메일 체크
                    final alreadyMember = currentTeam.members.any(
                      (m) => m.user.email.toLowerCase() == email.toLowerCase()
                    );
                    if (alreadyMember) {
                      setDialogState(() => emailError = '이미 팀에 소속된 이메일입니다');
                      hasError = true;
                    }
                    if (!hasError) {
                      provider.inviteMemberByEmail(
                        teamId: team.id,
                        email: email,
                        name: nameCtrl.text.trim(),
                        role: role,
                      );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('✅ ${nameCtrl.text.trim()}을(를) ${role.label}로 초대했습니다'),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ));
                    }
                  }
                } : null,
                icon: const Icon(Icons.person_add_outlined, size: 15),
                label: const Text('초대하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mintPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.bgCardLight,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _roleIcon(MemberRole r) {
    switch (r) {
      case MemberRole.admin: return Icons.shield_outlined;
      case MemberRole.editor: return Icons.edit_outlined;
      case MemberRole.viewer: return Icons.visibility_outlined;
      default: return Icons.person_outline;
    }
  }

  Color _roleColor(MemberRole r) {
    switch (r) {
      case MemberRole.admin: return AppTheme.mintPrimary;
      case MemberRole.editor: return AppTheme.info;
      case MemberRole.viewer: return AppTheme.textMuted;
      default: return AppTheme.textMuted;
    }
  }

  String _roleDesc(MemberRole r) {
    switch (r) {
      case MemberRole.admin: return '편집 + 멤버 관리';
      case MemberRole.editor: return '편집 가능';
      case MemberRole.viewer: return '읽기 전용';
      default: return '';
    }
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
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (projects.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.folder_open_outlined, color: AppTheme.textMuted.withValues(alpha: 0.4), size: 48),
          const SizedBox(height: 12),
          const Text('프로젝트가 없습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
          const SizedBox(height: 8),
          const Text('상단 버튼으로 프로젝트를 추가해보세요', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ]),
      );
    }
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isMobile ? 1 : 3,
          childAspectRatio: isMobile ? 2.2 : 1.5,
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

// Members Tab - 팀 중심 멤버 관리
class _MembersTab extends StatefulWidget {
  final AppProvider provider;
  final Team team;
  const _MembersTab({required this.provider, required this.team});

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy.MM.dd');
    final isMobile = MediaQuery.of(context).size.width < 768;

    // 검색 필터 적용
    final members = widget.team.members.where((m) {
      if (_searchQuery.isEmpty) return true;
      return m.user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.user.email.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 및 통계
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${widget.team.members.length}명의 팀 멤버', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('팀에서 멤버를 직접 추가하거나 제거하세요', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ]),
            const Spacer(),
            // 역할별 통계
            ..._buildRoleStats(widget.team.members),
          ]),
          const SizedBox(height: 14),

          // 검색 바
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: '멤버 검색 (이름, 이메일)',
              hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 18),
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
                borderSide: const BorderSide(color: AppTheme.mintPrimary),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppTheme.textMuted, size: 16),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),

          // 멤버 목록
          Expanded(
            child: members.isEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.search_off, color: AppTheme.textMuted.withValues(alpha: 0.4), size: 40),
                      const SizedBox(height: 8),
                      Text(
                        _searchQuery.isEmpty ? '팀 멤버가 없습니다' : '"$_searchQuery" 검색 결과 없음',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    ]),
                  )
                : ListView.separated(
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1E3040)),
                    itemBuilder: (_, i) {
                      final m = members[i];
                      final color = m.user.avatarColor != null
                          ? Color(int.parse('0xFF${m.user.avatarColor!.substring(1)}'))
                          : AppTheme.mintPrimary;
                      final isCurrentUser = widget.provider.currentUser?.id == m.user.id;
                      return _MemberListTile(
                        member: m,
                        color: color,
                        isCurrentUser: isCurrentUser,
                        dateFormat: dateFormat,
                        isMobile: isMobile,
                        onRoleChange: (role) {
                          widget.provider.updateMemberRole(widget.team.id, m.id, role);
                        },
                        onRemove: () => _confirmRemoveMember(context, m),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRoleStats(List<TeamMember> members) {
    final ownerCount = members.where((m) => m.role == MemberRole.owner).length;
    final adminCount = members.where((m) => m.role == MemberRole.admin).length;
    final editorCount = members.where((m) => m.role == MemberRole.editor).length;
    final viewerCount = members.where((m) => m.role == MemberRole.viewer).length;

    return [
      if (ownerCount > 0) _RoleStatChip(label: '오너', count: ownerCount, color: AppTheme.warning),
      if (adminCount > 0) ...[const SizedBox(width: 4), _RoleStatChip(label: '관리자', count: adminCount, color: AppTheme.mintPrimary)],
      if (editorCount > 0) ...[const SizedBox(width: 4), _RoleStatChip(label: '편집자', count: editorCount, color: AppTheme.info)],
      if (viewerCount > 0) ...[const SizedBox(width: 4), _RoleStatChip(label: '뷰어', count: viewerCount, color: AppTheme.textMuted)],
    ];
  }

  void _confirmRemoveMember(BuildContext context, TeamMember m) {
    final isCurrentUser = widget.provider.currentUser?.id == m.user.id;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text(isCurrentUser ? '팀 나가기' : '멤버 제거', style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          isCurrentUser
              ? '정말로 "${widget.team.name}" 팀을 나가시겠습니까?'
              : '"${m.user.name}"을(를) 팀에서 제거하시겠습니까?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              widget.provider.removeMember(widget.team.id, m.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isCurrentUser ? '팀을 나갔습니다' : '${m.user.name}을(를) 팀에서 제거했습니다'),
                  backgroundColor: AppTheme.error,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text(isCurrentUser ? '나가기' : '제거', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _RoleStatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _RoleStatChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text('$label $count', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}

class _MemberListTile extends StatelessWidget {
  final TeamMember member;
  final Color color;
  final bool isCurrentUser;
  final DateFormat dateFormat;
  final bool isMobile;
  final void Function(MemberRole) onRoleChange;
  final VoidCallback onRemove;

  const _MemberListTile({
    required this.member,
    required this.color,
    required this.isCurrentUser,
    required this.dateFormat,
    required this.isMobile,
    required this.onRoleChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.3),
              child: Text(member.user.avatarInitials, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            ),
            if (isCurrentUser)
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 12, height: 12,
                  decoration: const BoxDecoration(color: AppTheme.mintPrimary, shape: BoxShape.circle),
                  child: const Icon(Icons.person, color: Colors.white, size: 8),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(member.user.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
              if (isCurrentUser) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: AppTheme.mintPrimary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                  child: const Text('나', style: TextStyle(color: AppTheme.mintPrimary, fontSize: 9, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
            Text(member.user.email, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ]),
        ),
        if (!isMobile) ...[
          Text('가입 ${dateFormat.format(member.joinedAt)}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          const SizedBox(width: 12),
        ],
        _RoleBadge(role: member.role),
        const SizedBox(width: 8),
        if (member.role != MemberRole.owner)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.textMuted, size: 16),
            color: AppTheme.bgCard,
            itemBuilder: (_) => [
              ...MemberRole.values.where((r) => r != MemberRole.owner && r != member.role).map((r) =>
                PopupMenuItem<String>(
                  value: 'role_${r.name}',
                  child: Row(children: [
                    Icon(_roleIcon(r), color: _roleColor(r), size: 14),
                    const SizedBox(width: 8),
                    Text('${r.label}로 변경', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                  ]),
                )
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'remove',
                child: Row(children: [
                  Icon(Icons.person_remove_outlined, color: AppTheme.error, size: 14),
                  SizedBox(width: 8),
                  Text('팀에서 제거', style: TextStyle(color: AppTheme.error, fontSize: 13)),
                ]),
              ),
            ],
            onSelected: (value) {
              if (value == 'remove') {
                onRemove();
              } else if (value.startsWith('role_')) {
                final roleName = value.substring(5);
                final role = MemberRole.values.firstWhere((r) => r.name == roleName);
                onRoleChange(role);
              }
            },
          )
        else
          const SizedBox(width: 40),
      ]),
    );
  }

  IconData _roleIcon(MemberRole r) {
    switch (r) {
      case MemberRole.admin: return Icons.shield_outlined;
      case MemberRole.editor: return Icons.edit_outlined;
      case MemberRole.viewer: return Icons.visibility_outlined;
      default: return Icons.person_outline;
    }
  }

  Color _roleColor(MemberRole r) {
    switch (r) {
      case MemberRole.admin: return AppTheme.mintPrimary;
      case MemberRole.editor: return AppTheme.info;
      case MemberRole.viewer: return AppTheme.textMuted;
      default: return AppTheme.textMuted;
    }
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
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('팀 KPI (${kpis.length}개)', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('이 팀의 KPI만 표시됩니다', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ]),
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
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.track_changes_outlined, color: AppTheme.textMuted.withValues(alpha: 0.4), size: 48),
                      const SizedBox(height: 12),
                      const Text('이 팀의 KPI가 없습니다', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                      const SizedBox(height: 8),
                      const Text('"KPI 추가" 버튼으로 팀 KPI를 설정해보세요', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ]),
                  )
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
    String category = '매출';
    bool isTeamKpi = true;
    final categories = ['매출', 'ROI', 'ROAS', '리드', 'CTR', 'SEO', '콘텐츠', 'SNS', '이메일', '광고', '전환', '기타'];

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('KPI 추가', style: TextStyle(color: AppTheme.textPrimary)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SwitchListTile(
                  dense: true,
                  title: const Text('팀 KPI', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                  subtitle: const Text('팀 전체 목표 여부', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  value: isTeamKpi,
                  activeColor: AppTheme.mintPrimary,
                  onChanged: (v) => setState(() => isTeamKpi = v),
                ),
                const SizedBox(height: 8),
                TextField(controller: titleCtrl, style: const TextStyle(color: AppTheme.textPrimary), decoration: const InputDecoration(labelText: 'KPI 이름 *')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  dropdownColor: AppTheme.bgCard,
                  decoration: const InputDecoration(labelText: '카테고리'),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => category = v!),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: targetCtrl, style: const TextStyle(color: AppTheme.textPrimary), decoration: const InputDecoration(labelText: '목표값'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: currentCtrl, style: const TextStyle(color: AppTheme.textPrimary), decoration: const InputDecoration(labelText: '현재값'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(
                    onChanged: (v) => unit = v.isEmpty ? '건' : v,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(labelText: '단위'),
                  )),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty) {
                  provider.addKpi(KpiModel(
                    id: 'kpi_${DateTime.now().millisecondsSinceEpoch}',
                    title: titleCtrl.text.trim(),
                    category: category,
                    target: double.tryParse(targetCtrl.text) ?? 100,
                    current: double.tryParse(currentCtrl.text) ?? 0,
                    unit: unit,
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
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.15))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
              child: Text(kpi.category, style: TextStyle(color: color, fontSize: 10)),
            ),
            const SizedBox(width: 6),
            if (kpi.isTeamKpi)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.mintPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                child: const Text('팀', style: TextStyle(color: AppTheme.mintPrimary, fontSize: 10)),
              ),
          ]),
          const SizedBox(height: 6),
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
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${rate.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          // 삭제 버튼
          GestureDetector(
            onTap: () => _confirmDelete(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.delete_outline, color: AppTheme.error, size: 12),
                SizedBox(width: 3),
                Text('삭제', style: TextStyle(color: AppTheme.error, fontSize: 10)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }

  void _confirmDelete(BuildContext context) {
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
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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

// ════════════════════════════════════════════════════════
//  팀 설정 탭 – 예산, 환율, 고객 파라미터
// ════════════════════════════════════════════════════════
class _TeamSettingsTab extends StatefulWidget {
  final AppProvider provider;
  final Team team;
  const _TeamSettingsTab({required this.provider, required this.team});
  @override
  State<_TeamSettingsTab> createState() => _TeamSettingsTabState();
}

class _TeamSettingsTabState extends State<_TeamSettingsTab> {
  late TextEditingController _budgetCtrl;
  late TextEditingController _usdRateCtrl;
  late TextEditingController _eurRateCtrl;
  late TextEditingController _marketCtrl;
  late String _selectedCurrency;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.team;
    _budgetCtrl = TextEditingController(text: t.annualBudget != null ? t.annualBudget!.toStringAsFixed(0) : '');
    _usdRateCtrl = TextEditingController(text: t.exchangeRateUsd.toStringAsFixed(0));
    _eurRateCtrl = TextEditingController(text: t.exchangeRateEur.toStringAsFixed(0));
    _marketCtrl = TextEditingController(text: t.targetMarket ?? '');
    _selectedCurrency = t.budgetCurrency;
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    _usdRateCtrl.dispose();
    _eurRateCtrl.dispose();
    _marketCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    setState(() => _saving = true);
    widget.provider.updateTeamSettings(
      widget.team.id,
      annualBudget: double.tryParse(_budgetCtrl.text.replaceAll(',', '')),
      budgetCurrency: _selectedCurrency,
      exchangeRateUsd: double.tryParse(_usdRateCtrl.text.replaceAll(',', '')) ?? widget.team.exchangeRateUsd,
      exchangeRateEur: double.tryParse(_eurRateCtrl.text.replaceAll(',', '')) ?? widget.team.exchangeRateEur,
      targetMarket: _marketCtrl.text.trim().isEmpty ? null : _marketCtrl.text.trim(),
    );
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ 팀 설정이 저장되었습니다'),
        backgroundColor: Color(0xFF00BFA5),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = widget.team;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final teamColor = Color(int.parse('0xFF${team.colorHex.substring(1)}'));
    final clients = widget.provider.teamClients;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 예산 섹션
        _SettingsSection(
          title: '예산 설정',
          icon: Icons.account_balance_wallet_outlined,
          color: AppTheme.success,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('연간 팀 예산', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _budgetCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: '예: 500000000',
                    hintStyle: const TextStyle(color: AppTheme.textMuted),
                    prefixIcon: Text(_selectedCurrency == 'KRW' ? '₩' : _selectedCurrency == 'USD' ? '\$' : '€',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 16)),
                  ),
                ),
              ])),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('통화', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButton<String>(
                  value: _selectedCurrency,
                  dropdownColor: AppTheme.bgCard,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  items: const [
                    DropdownMenuItem(value: 'KRW', child: Text('🇰🇷 KRW')),
                    DropdownMenuItem(value: 'USD', child: Text('🇺🇸 USD')),
                    DropdownMenuItem(value: 'EUR', child: Text('🇪🇺 EUR')),
                  ],
                  onChanged: (v) => setState(() => _selectedCurrency = v ?? 'KRW'),
                ),
              ]),
            ]),
          ],
        ),
        const SizedBox(height: 20),

        // 환율 섹션
        _SettingsSection(
          title: '환율 설정',
          icon: Icons.currency_exchange,
          color: AppTheme.info,
          children: [
            const Text('1 USD = ? KRW', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _usdRateCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: '예: 1350',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                prefixIcon: Icon(Icons.attach_money, color: AppTheme.textMuted, size: 16),
                suffixText: 'KRW',
                suffixStyle: TextStyle(color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            const Text('1 EUR = ? KRW', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _eurRateCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: '예: 1480',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                prefixIcon: Icon(Icons.euro, color: AppTheme.textMuted, size: 16),
                suffixText: 'KRW',
                suffixStyle: TextStyle(color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 고객/시장 섹션
        _SettingsSection(
          title: '타겟 시장 & 고객',
          icon: Icons.public,
          color: AppTheme.warning,
          children: [
            const Text('타겟 시장/권역', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _marketCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: '예: 동남아시아, 북미, 글로벌',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                prefixIcon: Icon(Icons.map_outlined, color: AppTheme.textMuted, size: 16),
              ),
            ),
            const SizedBox(height: 16),
            // 연결 고객사 목록 (읽기 전용 표시)
            Row(children: [
              const Icon(Icons.business_outlined, color: AppTheme.textMuted, size: 14),
              const SizedBox(width: 6),
              Text('연결 고객사 (${clients.length}개)', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            if (clients.isEmpty)
              const Text('등록된 고객사가 없습니다. 고객사 관리에서 추가하세요.', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))
            else
              Wrap(
                spacing: 8, runSpacing: 6,
                children: clients.map((c) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCardLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E3040)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.business, color: AppTheme.textMuted, size: 12),
                    const SizedBox(width: 5),
                    Text(c.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
                    if (c.isActive) ...[
                      const SizedBox(width: 5),
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
                      ),
                    ],
                  ]),
                )).toList(),
              ),
          ],
        ),
        const SizedBox(height: 24),

        // 저장 버튼
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined, size: 16),
            label: Text(_saving ? '저장 중...' : '설정 저장'),
            style: ElevatedButton.styleFrom(
              backgroundColor: teamColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ]),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;
  const _SettingsSection({required this.title, required this.icon, required this.color, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.bgCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 14),
      ...children,
    ]),
  );
}
