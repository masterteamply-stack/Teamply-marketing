import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../screens/dashboard/overview_page.dart';
import '../screens/team/team_list_page.dart';
import '../screens/team/team_detail_page.dart';
import '../screens/project/project_detail_page.dart';
import '../screens/task/task_detail_page.dart';
import '../screens/kpi/kpi_page.dart';
import '../screens/campaign/campaign_page.dart';
import '../screens/funnel/funnel_page.dart';
import '../screens/settings/exchange_rate_page.dart';
import '../screens/settings/app_settings_page.dart';
import '../screens/dashboard/geo_analysis_page.dart';
import 'ai_developer_panel.dart';
import 'notification_panel.dart';
import 'dm_panel.dart';
import 'user_profile_dialog.dart';

class DesktopShell extends StatelessWidget {
  const DesktopShell({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Row(
        children: [
          const _LeftNavPanel(),
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF1E3040)),
          // Main content
          Expanded(
            child: Column(
              children: [
                // Top bar with AI, notification, user
                _TopBar(),
                Expanded(child: _ContentArea()),
              ],
            ),
          ),
          // Right panels (AI, Notification, DM)
          if (provider.aiPanelOpen) const AiDeveloperPanel(),
          if (provider.notificationPanelOpen) const NotificationPanel(),
          if (provider.activeDmUserId != null) const DmPanel(),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  TOP BAR
// ──────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final user = provider.currentUser;
    final unreadCount = provider.unreadNotificationCount;
    final avatarColor = user.avatarColor != null
        ? Color(int.parse('0xFF${user.avatarColor!.substring(1)}'))
        : AppTheme.mintPrimary;
    final activeDmCount = provider.dmConversations
        .fold(0, (s, c) => s + c.unreadCount(user.id));

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(bottom: BorderSide(color: Color(0xFF1E3040), width: 1)),
      ),
      child: Row(
        children: [
          // Breadcrumb
          _BreadcrumbBar(provider: provider),
          const Spacer(),
          // Action buttons
          _TopBarIconButton(
            icon: Icons.smart_toy_outlined,
            activeIcon: Icons.smart_toy,
            tooltip: 'AI Developer',
            isActive: provider.aiPanelOpen,
            onTap: () {
              provider.toggleAiPanel();
              if (provider.notificationPanelOpen) provider.closeNotificationPanel();
              if (provider.activeDmUserId != null) provider.closeDm();
            },
          ),
          const SizedBox(width: 4),
          // DM
          _TopBarIconButton(
            icon: Icons.mail_outline,
            activeIcon: Icons.mail,
            tooltip: 'DM',
            isActive: provider.activeDmUserId != null,
            badge: activeDmCount > 0 ? '$activeDmCount' : null,
            onTap: () {
              // Open DM list or first conversation
              if (provider.dmConversations.isNotEmpty) {
                final myId = provider.currentUser.id;
                final conv = provider.dmConversations.first;
                provider.openDm(conv.otherUserId(myId));
                if (provider.aiPanelOpen) provider.closeAiPanel();
                if (provider.notificationPanelOpen) provider.closeNotificationPanel();
              }
            },
          ),
          const SizedBox(width: 4),
          // Notifications
          _TopBarIconButton(
            icon: Icons.notifications_outlined,
            activeIcon: Icons.notifications,
            tooltip: '알림',
            isActive: provider.notificationPanelOpen,
            badge: unreadCount > 0 ? '$unreadCount' : null,
            onTap: () {
              provider.toggleNotificationPanel();
              if (provider.aiPanelOpen) provider.closeAiPanel();
              if (provider.activeDmUserId != null) provider.closeDm();
            },
          ),
          const SizedBox(width: 12),
          // User avatar
          GestureDetector(
            onTap: () => UserProfileDialog.show(context),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: avatarColor.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: avatarColor, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      user.avatarInitials,
                      style: TextStyle(color: avatarColor, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(_jobTitleLabel(user.jobTitle), style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more, color: AppTheme.textMuted, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreadcrumbBar extends StatelessWidget {
  final AppProvider provider;
  const _BreadcrumbBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final section = provider.currentSection;
    Widget crumb(String label, {VoidCallback? onTap, bool isLast = false}) {
      return GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: TextStyle(
            color: isLast ? AppTheme.textPrimary : AppTheme.textMuted,
            fontSize: 12,
            fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      );
    }

    final divider = const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Icon(Icons.chevron_right, size: 14, color: AppTheme.textMuted),
    );

    List<Widget> parts = [];
    switch (section) {
      case 'dashboard':
        parts = [crumb('대시보드', isLast: true)];
        break;
      case 'kpi':
        parts = [crumb('KPI 관리', isLast: true)];
        break;
      case 'campaign':
        parts = [crumb('캠페인', isLast: true)];
        break;
      case 'funnel':
        parts = [crumb('마케팅 퍼널', isLast: true)];
        break;
      case 'exchange_rate':
        parts = [crumb('환율 관리', isLast: true)];
        break;
      case 'app_settings':
        parts = [crumb('앱 설정', isLast: true)];
        break;
      case 'geo_analysis':
        parts = [crumb('지역 비용 분석', isLast: true)];
        break;
      case 'teams':
        parts = [crumb('팀 관리', isLast: true)];
        break;
      case 'team_detail':
        final team = provider.selectedTeam;
        parts = [
          crumb('팀 관리', onTap: () => provider.navigateTo('teams')),
          divider,
          crumb(team?.name ?? '팀 상세', isLast: true),
        ];
        break;
      case 'project_detail':
        final team = provider.selectedTeam;
        final proj = provider.selectedProject;
        parts = [
          crumb('팀 관리', onTap: () => provider.navigateTo('teams')),
          divider,
          if (team != null) ...[crumb(team.name, onTap: () => provider.selectTeam(team.id)), divider],
          crumb(proj?.name ?? '프로젝트', isLast: true),
        ];
        break;
      case 'task_detail':
        final team = provider.selectedTeam;
        final proj = provider.selectedProject;
        TaskDetail? task;
        for (final p in provider.projectStore) {
          for (final t in p.tasks) {
            if (t.id == provider.selectedTaskId) { task = t; break; }
          }
        }
        parts = [
          crumb('팀 관리', onTap: () => provider.navigateTo('teams')),
          divider,
          if (team != null) ...[crumb(team.name, onTap: () => provider.selectTeam(team.id)), divider],
          if (proj != null) ...[crumb(proj.name, onTap: () => provider.selectProject(proj.id)), divider],
          crumb(task?.title ?? '태스크', isLast: true),
        ];
        break;
      default:
        parts = [crumb('대시보드', isLast: true)];
    }

    return Row(children: parts);
  }
}

class _TopBarIconButton extends StatelessWidget {
  final IconData icon, activeIcon;
  final String tooltip;
  final bool isActive;
  final String? badge;
  final VoidCallback onTap;

  const _TopBarIconButton({
    required this.icon,
    required this.activeIcon,
    required this.tooltip,
    required this.isActive,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.mintPrimary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? AppTheme.mintPrimary : AppTheme.textSecondary,
                size: 18,
              ),
              if (badge != null)
                Positioned(
                  top: 4, right: 4,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  LEFT NAVIGATION PANEL
// ──────────────────────────────────────────────
class _LeftNavPanel extends StatelessWidget {
  const _LeftNavPanel();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Container(
      width: 240,
      color: AppTheme.bgCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo / Header
          _NavHeader(user: provider.currentUser),
          const Divider(height: 1, thickness: 1, color: Color(0xFF1E3040)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main navigation
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    selectedIcon: Icons.dashboard,
                    label: '대시보드',
                    section: 'dashboard',
                    current: provider.currentSection,
                    onTap: () => provider.navigateTo('dashboard'),
                  ),
                  _NavItem(
                    icon: Icons.flag_outlined,
                    selectedIcon: Icons.flag,
                    label: 'KPI 관리',
                    section: 'kpi',
                    current: provider.currentSection,
                    onTap: () => provider.navigateTo('kpi'),
                  ),
                  _NavItem(
                    icon: Icons.campaign_outlined,
                    selectedIcon: Icons.campaign,
                    label: '캠페인',
                    section: 'campaign',
                    current: provider.currentSection,
                    onTap: () => provider.navigateTo('campaign'),
                  ),
                  _NavItem(
                    icon: Icons.filter_alt_outlined,
                    selectedIcon: Icons.filter_alt,
                    label: '마케팅 퍼널',
                    section: 'funnel',
                    current: provider.currentSection,
                    onTap: () => provider.navigateTo('funnel'),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text('팀 & 프로젝트',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                  ),
                  _NavItem(
                    icon: Icons.groups_outlined,
                    selectedIcon: Icons.groups,
                    label: '팀 관리',
                    section: 'teams',
                    current: provider.currentSection,
                    onTap: () => provider.navigateTo('teams'),
                  ),
                  // Team list
                  ...provider.teams.map((team) => _TeamNavItem(
                    team: team,
                    isSelected: provider.selectedTeamId == team.id &&
                        (provider.currentSection == 'team_detail' || provider.currentSection == 'project_detail' || provider.currentSection == 'task_detail'),
                    isExpanded: provider.selectedTeamId == team.id,
                    onTap: () => provider.selectTeam(team.id),
                    provider: provider,
                  )),
                  _NavItem(
                    icon: Icons.add_circle_outline,
                    selectedIcon: Icons.add_circle,
                    label: '팀 추가',
                    section: '_new_team',
                    current: '',
                    onTap: () => _showCreateTeamDialog(context, provider),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text('설정',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                  ),
                  _NavItem(
                    icon: Icons.currency_exchange_outlined,
                    selectedIcon: Icons.currency_exchange,
                    label: '환율 관리',
                    section: 'exchange_rate',
                    current: provider.currentSection,
                    onTap: () => provider.navigateTo('exchange_rate'),
                  ),
                  _NavItem(
                    icon: Icons.public_outlined,
                    selectedIcon: Icons.public,
                    label: '지역 비용 분석',
                    section: 'geo_analysis',
                    current: provider.currentSection,
                    onTap: () => provider.navigateTo('geo_analysis'),
                  ),
                  _NavItem(
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: '앱 설정',
                    section: 'app_settings',
                    current: provider.currentSection,
                    onTap: () => provider.navigateTo('app_settings'),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text('메시지',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                  ),
                  // DM list
                  ...provider.dmConversations.map((conv) {
                    final otherId = conv.otherUserId(provider.currentUser.id);
                    final other = provider.getUserById(otherId);
                    final unread = conv.unreadCount(provider.currentUser.id);
                    final avatarColor = other?.avatarColor != null
                        ? Color(int.parse('0xFF${other!.avatarColor!.substring(1)}'))
                        : AppTheme.mintPrimary;
                    return InkWell(
                      onTap: () {
                        provider.openDm(otherId);
                        if (provider.aiPanelOpen) provider.closeAiPanel();
                        if (provider.notificationPanelOpen) provider.closeNotificationPanel();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                        decoration: BoxDecoration(
                          color: provider.activeDmUserId == otherId
                              ? AppTheme.mintPrimary.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Stack(children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: avatarColor.withValues(alpha: 0.2),
                              child: Text(other?.avatarInitials ?? '?', style: TextStyle(color: avatarColor, fontSize: 9, fontWeight: FontWeight.w700)),
                            ),
                            if (unread > 0)
                              Positioned(right: 0, top: 0,
                                child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppTheme.mintPrimary, shape: BoxShape.circle))),
                          ]),
                          const SizedBox(width: 8),
                          Expanded(child: Text(other?.displayName ?? '?', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis)),
                          if (unread > 0)
                            Container(
                              width: 16, height: 16,
                              decoration: const BoxDecoration(color: AppTheme.mintPrimary, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                            ),
                        ]),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFF1E3040)),
          // User profile footer
          _NavFooter(user: provider.currentUser),
        ],
      ),
    );
  }

  void _showCreateTeamDialog(BuildContext context, AppProvider provider) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedColor = '#00BFA5';
    String selectedEmoji = '🎯';
    final emojis = ['🎯', '📱', '🚀', '💡', '🌟', '📊', '🎨', '⚡'];
    final colors = ['#00BFA5', '#29B6F6', '#AB47BC', '#FF7043', '#FFB300', '#66BB6A'];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('새 팀 만들기', style: TextStyle(color: AppTheme.textPrimary)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: emojis.map((e) => GestureDetector(
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
                  )).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '팀 이름', hintText: '마케팅 전략팀'),
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: '설명', hintText: '팀 설명을 입력하세요'),
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: colors.map((c) {
                    final col = Color(int.parse('0xFF${c.substring(1)}'));
                    return GestureDetector(
                      onTap: () => setState(() => selectedColor = c),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                          border: Border.all(color: selectedColor == c ? Colors.white : Colors.transparent, width: 2.5),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
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
              child: const Text('만들기'),
            ),
          ],
        ),
      ),
    );
  }
}

// Team nav item with sub-projects
class _TeamNavItem extends StatelessWidget {
  final dynamic team;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;
  final AppProvider provider;

  const _TeamNavItem({
    required this.team,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final teamColor = Color(int.parse('0xFF${team.colorHex.substring(1)}'));
    final projects = provider.getProjectsForTeam(team.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: isSelected ? teamColor.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: teamColor, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Text(team.iconEmoji, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    team.name,
                    style: TextStyle(
                      color: isSelected ? teamColor : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('${team.members.length}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
        ),
        if (isExpanded)
          ...projects.map((proj) {
            final projColor = Color(int.parse('0xFF${proj.colorHex.substring(1)}'));
            final isSelectedProj = provider.selectedProjectId == proj.id;
            return InkWell(
              onTap: () => provider.selectProject(proj.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                margin: const EdgeInsets.only(left: 20, right: 8, top: 1),
                decoration: BoxDecoration(
                  color: isSelectedProj ? projColor.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Text(proj.iconEmoji, style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        proj.name,
                        style: TextStyle(
                          color: isSelectedProj ? projColor : AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: isSelectedProj ? FontWeight.w600 : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('${proj.tasks.length}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _NavHeader extends StatelessWidget {
  final dynamic user;
  const _NavHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.mintPrimary, AppTheme.mintDark],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Text('M', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Marketing HQ', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                Text('Dashboard v2.0', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavFooter extends StatelessWidget {
  final dynamic user;
  const _NavFooter({required this.user});

  @override
  Widget build(BuildContext context) {
    final color = user.avatarColor != null
        ? Color(int.parse('0xFF${user.avatarColor!.substring(1)}'))
        : AppTheme.mintPrimary;

    return InkWell(
      onTap: () => UserProfileDialog.show(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: color.withValues(alpha: 0.3),
              child: Text(user.avatarInitials, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(_jobTitleLabel(user.jobTitle), style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, color: AppTheme.textMuted, size: 14),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, selectedIcon;
  final String label, section, current;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon, required this.selectedIcon,
    required this.label, required this.section, required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == section;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.mintPrimary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(isSelected ? selectedIcon : icon,
                color: isSelected ? AppTheme.mintPrimary : AppTheme.textSecondary, size: 17),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(
              color: isSelected ? AppTheme.mintPrimary : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            )),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  MAIN CONTENT AREA (route-based)
// ──────────────────────────────────────────────
class _ContentArea extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final section = provider.currentSection;

    switch (section) {
      case 'dashboard':
        return const OverviewPage();
      case 'kpi':
        return const KpiPage();
      case 'campaign':
        return const CampaignPage();
      case 'funnel':
        return const FunnelPage();
      case 'teams':
        return const TeamListPage();
      case 'team_detail':
        return const TeamDetailPage();
      case 'project_detail':
        return const ProjectDetailPage();
      case 'task_detail':
        return const TaskDetailPage();
      case 'exchange_rate':
        return const ExchangeRatePage();
      case 'app_settings':
        return const AppSettingsPage();
      case 'geo_analysis':
        return const GeoAnalysisPage();
      default:
        return const OverviewPage();
    }
  }
}

// ── Helper function for JobTitle label ──
String _jobTitleLabel(JobTitle title) {
  switch (title) {
    case JobTitle.ceo: return '대표';
    case JobTitle.coo: return '임원(COO)';
    case JobTitle.cmo: return '임원(CMO)';
    case JobTitle.director: return '이사';
    case JobTitle.teamLead: return '팀장';
    case JobTitle.partLead: return '파트장';
    case JobTitle.senior: return '선임';
    case JobTitle.member: return '팀원';
    case JobTitle.intern: return '인턴';
    case JobTitle.advisor: return '어드바이저';
  }
}
