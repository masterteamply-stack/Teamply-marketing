import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../screens/dashboard/overview_page.dart';
import '../screens/team/team_list_page.dart';
import '../screens/team/team_detail_page.dart';
import '../screens/project/project_detail_page.dart';
import '../screens/task/task_detail_page.dart';
import '../screens/kpi/kpi_page.dart';
import '../screens/campaign/campaign_page.dart';
import '../screens/funnel/funnel_page.dart';
import '../screens/dashboard/geo_analysis_page.dart';
import '../screens/settings/app_settings_page.dart';
import '../screens/settings/exchange_rate_page.dart';

class MobileShell extends StatelessWidget {
  const MobileShell({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final section = provider.currentSection;

    // Sections that are detail pages (no bottom nav needed)
    final isDetailPage = section == 'team_detail' ||
        section == 'project_detail' ||
        section == 'task_detail';

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: _buildAppBar(context, provider, section),
      drawer: _MobileDrawer(),
      body: _MobileContentArea(section: section),
      bottomNavigationBar: isDetailPage ? null : _MobileBottomNav(section: section),
    );
  }

  PreferredSizeWidget? _buildAppBar(
      BuildContext context, AppProvider provider, String section) {
    String title;
    bool showBackButton = false;

    switch (section) {
      case 'dashboard':
        title = '마케팅 대시보드';
        break;
      case 'kpi':
        title = 'KPI 관리';
        break;
      case 'campaign':
        title = '캠페인';
        break;
      case 'funnel':
        title = '마케팅 퍼널';
        break;
      case 'geo_analysis':
        title = '지역 비용 분석';
        break;
      case 'teams':
        title = '팀 관리';
        break;
      case 'team_detail':
        title = provider.selectedTeam?.name ?? '팀 상세';
        showBackButton = true;
        break;
      case 'project_detail':
        title = provider.selectedProject?.name ?? '프로젝트 상세';
        showBackButton = true;
        break;
      case 'task_detail':
        title = '태스크 상세';
        showBackButton = true;
        break;
      case 'exchange_rate':
        title = '환율 관리';
        break;
      case 'app_settings':
        title = '앱 설정';
        break;
      default:
        title = '마케팅 대시보드';
    }

    return AppBar(
      backgroundColor: AppTheme.bgCard,
      elevation: 0,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 18),
              onPressed: () {
                if (section == 'task_detail') {
                  provider.navigateTo('project_detail');
                } else if (section == 'project_detail') {
                  provider.navigateTo('team_detail');
                } else {
                  provider.navigateTo('teams');
                }
              },
            )
          : Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, color: AppTheme.textPrimary, size: 22),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
      title: Row(
        children: [
          if (!showBackButton) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.mintPrimary, AppTheme.mintDark],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: const Text('M', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        if (!showBackButton)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _UserAvatar(user: provider.currentUser),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFF1E3040)),
      ),
    );
  }
}

// ─────────────────────────────────
//  BOTTOM NAVIGATION
// ─────────────────────────────────
class _MobileBottomNav extends StatelessWidget {
  final String section;
  const _MobileBottomNav({required this.section});

  int _sectionToIndex(String s) {
    switch (s) {
      case 'dashboard': return 0;
      case 'kpi': return 1;
      case 'campaign': return 2;
      case 'funnel': return 3;
      case 'teams':
      case 'team_detail':
      case 'project_detail':
      case 'task_detail':
        return 4;
      default: return 0;
    }
  }

  String _indexToSection(int i) {
    switch (i) {
      case 0: return 'dashboard';
      case 1: return 'kpi';
      case 2: return 'campaign';
      case 3: return 'funnel';
      case 4: return 'teams';
      default: return 'dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currentIndex = _sectionToIndex(section);

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(top: BorderSide(color: Color(0xFF1E3040), width: 1)),
      ),
      child: NavigationBar(
        backgroundColor: Colors.transparent,
        height: 64,
        selectedIndex: currentIndex,
        indicatorColor: AppTheme.mintPrimary.withValues(alpha: 0.15),
        onDestinationSelected: (i) => provider.navigateTo(_indexToSection(i)),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, size: 22),
            selectedIcon: Icon(Icons.dashboard, size: 22),
            label: '대시보드',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined, size: 22),
            selectedIcon: Icon(Icons.flag, size: 22),
            label: 'KPI',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined, size: 22),
            selectedIcon: Icon(Icons.campaign, size: 22),
            label: '캠페인',
          ),
          NavigationDestination(
            icon: Icon(Icons.filter_alt_outlined, size: 22),
            selectedIcon: Icon(Icons.filter_alt, size: 22),
            label: '퍼널',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined, size: 22),
            selectedIcon: Icon(Icons.groups, size: 22),
            label: '팀',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────
//  DRAWER (SIDE MENU)
// ─────────────────────────────────
class _MobileDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Drawer(
      backgroundColor: AppTheme.bgCard,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
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
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Marketing HQ', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                      Text('Dashboard v2.0', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF1E3040)),
            const SizedBox(height: 8),
            // Nav Items
            _DrawerItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: '대시보드', section: 'dashboard', current: provider.currentSection,
              onTap: () { provider.navigateTo('dashboard'); Navigator.pop(context); }),
            _DrawerItem(icon: Icons.flag_outlined, selectedIcon: Icons.flag, label: 'KPI 관리', section: 'kpi', current: provider.currentSection,
              onTap: () { provider.navigateTo('kpi'); Navigator.pop(context); }),
            _DrawerItem(icon: Icons.campaign_outlined, selectedIcon: Icons.campaign, label: '캠페인', section: 'campaign', current: provider.currentSection,
              onTap: () { provider.navigateTo('campaign'); Navigator.pop(context); }),
            _DrawerItem(icon: Icons.filter_alt_outlined, selectedIcon: Icons.filter_alt, label: '마케팅 퍼널', section: 'funnel', current: provider.currentSection,
              onTap: () { provider.navigateTo('funnel'); Navigator.pop(context); }),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text('팀 & 프로젝트',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
            ),
            _DrawerItem(icon: Icons.groups_outlined, selectedIcon: Icons.groups, label: '팀 관리', section: 'teams', current: provider.currentSection,
              onTap: () { provider.navigateTo('teams'); Navigator.pop(context); }),
            // Teams list
            ...provider.teams.map((team) {
              final teamColor = Color(int.parse('0xFF${team.colorHex.substring(1)}'));
              final isSelected = provider.selectedTeamId == team.id;
              return InkWell(
                onTap: () { provider.selectTeam(team.id); Navigator.pop(context); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? teamColor.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: teamColor, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(team.iconEmoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(team.name, style: TextStyle(
                          color: isSelected ? teamColor : AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        )),
                      ),
                      Text('${team.members.length}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
              );
            }),
            const Spacer(),
            const Divider(height: 1, color: Color(0xFF1E3040)),
            // User Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  _UserAvatar(user: provider.currentUser, radius: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(provider.currentUser.name,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(provider.currentUser.email,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const Icon(Icons.settings_outlined, color: AppTheme.textMuted, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon, selectedIcon;
  final String label, section, current;
  final VoidCallback onTap;

  const _DrawerItem({
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.mintPrimary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(isSelected ? selectedIcon : icon,
                color: isSelected ? AppTheme.mintPrimary : AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(
              color: isSelected ? AppTheme.mintPrimary : AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────
//  CONTENT AREA
// ─────────────────────────────────
class _MobileContentArea extends StatelessWidget {
  final String section;
  const _MobileContentArea({required this.section});

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case 'dashboard':
        return const OverviewPage();
      case 'kpi':
        return const KpiPage();
      case 'campaign':
        return const CampaignPage();
      case 'funnel':
        return const FunnelPage();
      case 'geo_analysis':
        return const GeoAnalysisPage();
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
      default:
        return const OverviewPage();
    }
  }
}

// ─────────────────────────────────
//  SHARED USER AVATAR WIDGET
// ─────────────────────────────────
class _UserAvatar extends StatelessWidget {
  final dynamic user;
  final double radius;
  const _UserAvatar({required this.user, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final color = user.avatarColor != null
        ? Color(int.parse('0xFF${user.avatarColor!.substring(1)}'))
        : AppTheme.mintPrimary;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.3),
      child: Text(user.avatarInitials,
          style: TextStyle(color: color, fontSize: radius * 0.65, fontWeight: FontWeight.w700)),
    );
  }
}
