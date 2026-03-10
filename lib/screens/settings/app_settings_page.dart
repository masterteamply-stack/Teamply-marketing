import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';
import '../../l10n/app_localizations.dart';
import 'client_management_page.dart';
import 'region_management_page.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});
  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  static const _langs = [
    {'code': 'ko', 'flag': '🇰🇷', 'label': '한국어'},
    {'code': 'en', 'flag': '🇺🇸', 'label': 'English'},
    {'code': 'ja', 'flag': '🇯🇵', 'label': '日本語'},
    {'code': 'zh', 'flag': '🇨🇳', 'label': '中文'},
    {'code': 'es', 'flag': '🇪🇸', 'label': 'Español'},
    {'code': 'ar', 'flag': '🇸🇦', 'label': 'العربية'},
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final app  = context.watch<AppProvider>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.mintPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.settings_outlined, color: AppTheme.mintPrimary, size: 20),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.settings,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                Text('앱 설정, 알림, 보안',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ]),
            ]),
            const SizedBox(height: 24),

            // ── 데이터 관리 ───────────────────────────────
            _sectionTitle('데이터 관리'),
            _settingsCard([
              _settingsTile(
                icon: Icons.business_rounded,
                iconColor: AppTheme.accentBlue,
                title: '고객사 관리',
                subtitle: '고객사 추가·편집·삭제, 바이어코드, CSV 업로드',
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ClientManagementPage())),
              ),
              _settingsTile(
                icon: Icons.map_rounded,
                iconColor: AppTheme.mintPrimary,
                title: '권역 & 나라 관리',
                subtitle: '권역 추가·편집·삭제, 국가 코드 설정, CSV 업로드',
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RegionManagementPage())),
              ),
              _settingsTile(
                icon: Icons.group_remove_outlined,
                iconColor: AppTheme.accentOrange,
                title: '팀 관리',
                subtitle: '팀 삭제, 프로젝트 일괄 삭제',
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
                onTap: () => _showTeamManagementSheet(context),
              ),
              _settingsTile(
                icon: Icons.restore_rounded,
                iconColor: AppTheme.accentRed,
                title: '데이터 초기화',
                subtitle: '모든 데이터를 디폴트 샘플 데이터로 리셋',
                onTap: () => _showResetDataConfirm(context),
              ),
            ]),
            const SizedBox(height: 20),

            // ── 계정 ─────────────────────────────────────
            if (auth.isAuthenticated) ...[
              _sectionTitle('계정'),
              _settingsCard([
                _accountTile(auth),
              ]),
              const SizedBox(height: 20),

              // ── 앱 설정 (디폴트 페이지) ──────────────────
              _sectionTitle('앱 설정'),
              _settingsCard([
                _defaultPageTile(context, app),
              ]),
              const SizedBox(height: 20),
            ],

            // ── 언어 ─────────────────────────────────────
            _sectionTitle(l10n.language),
            _settingsCard([
              ..._langs.map((lang) => _langTile(context, auth, lang)),
            ]),
            const SizedBox(height: 20),

            // ── 알림 설정 ─────────────────────────────────
            _sectionTitle(l10n.notificationSettings),
            _notifSection(context, auth, l10n),
            const SizedBox(height: 20),

            // ── 보안 ─────────────────────────────────────
            _sectionTitle(l10n.security),
            _securitySection(context, auth, l10n),
            const SizedBox(height: 20),

            // ── 개인정보 ──────────────────────────────────
            _sectionTitle(l10n.privacyPolicy),
            _settingsCard([
              _settingsTile(
                icon: Icons.shield_outlined,
                iconColor: AppTheme.mintPrimary,
                title: l10n.privacyPolicy,
                subtitle: auth.privacyAgreed ? '동의함' : '미동의',
                trailing: auth.privacyAgreed
                    ? const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 18)
                    : const Icon(Icons.warning_amber_rounded, color: AppTheme.accentOrange, size: 18),
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => _PrivacyInfoDialog(),
                ),
              ),
              _settingsTile(
                icon: Icons.delete_outline,
                iconColor: AppTheme.accentRed,
                title: '계정 및 데이터 삭제',
                subtitle: '모든 데이터를 영구 삭제합니다',
                onTap: () => _showDeleteConfirm(context, auth),
              ),
            ]),
            const SizedBox(height: 20),

            // ── 로그아웃 ──────────────────────────────────
            if (auth.isAuthenticated)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmSignOut(context, auth),
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(l10n.signOut),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentRed,
                    side: const BorderSide(color: AppTheme.accentRed),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Sections ─────────────────────────────────────────────
  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(title,
        style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8)),
  );

  Widget _settingsCard(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(children: children),
  );

  Widget _accountTile(AuthProvider auth) {
    final user = auth.user!;
    final providerIcon = _providerIcon(user.provider);
    final providerColor = _providerColor(user.provider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.mintPrimary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                style: const TextStyle(
                    color: AppTheme.mintPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.displayName,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              Text(user.email,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: providerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(providerIcon, size: 12, color: providerColor),
              const SizedBox(width: 4),
              Text(user.provider.name,
                  style: TextStyle(color: providerColor, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
    );
  }

  // ── 디폴트 페이지 선택 타일 ──────────────────────────────
  static const List<Map<String, dynamic>> _pageOptions = [
    {'id': 'dashboard',   'label': '대시보드',    'icon': Icons.dashboard_rounded},
    {'id': 'kpi',         'label': 'KPI',         'icon': Icons.bar_chart_rounded},
    {'id': 'campaign',    'label': '캠페인',       'icon': Icons.campaign_rounded},
    {'id': 'funnel',      'label': '퍼널',         'icon': Icons.filter_alt_rounded},
    {'id': 'teams',       'label': '팀 목록',      'icon': Icons.groups_rounded},
    {'id': 'geo_analysis','label': '지역 분석',    'icon': Icons.public_rounded},
  ];

  Widget _defaultPageTile(BuildContext context, AppProvider app) {
    final current = _pageOptions.firstWhere(
      (p) => p['id'] == app.defaultSection,
      orElse: () => _pageOptions.first,
    );

    return _settingsTile(
      icon: current['icon'] as IconData,
      iconColor: AppTheme.mintPrimary,
      title: '시작 페이지',
      subtitle: '로그인 후 표시할 기본 페이지: ${current['label']}',
      onTap: () => _showDefaultPageSheet(context, app),
    );
  }

  void _showDefaultPageSheet(BuildContext context, AppProvider app) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '시작 페이지 설정',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '로그인 후 자동으로 이동할 페이지를 선택하세요',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ..._pageOptions.map((opt) {
                final isSelected = app.defaultSection == opt['id'];
                return InkWell(
                  onTap: () async {
                    await app.setDefaultSection(opt['id'] as String);
                    if (context.mounted) Navigator.pop(context);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('시작 페이지가 "${opt['label']}"으로 설정되었습니다'),
                          backgroundColor: AppTheme.mintPrimary,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.mintPrimary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.mintPrimary.withValues(alpha: 0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          opt['icon'] as IconData,
                          color: isSelected ? AppTheme.mintPrimary : AppTheme.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          opt['label'] as String,
                          style: TextStyle(
                            color: isSelected ? AppTheme.mintPrimary : AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: AppTheme.mintPrimary, size: 18),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langTile(BuildContext context, AuthProvider auth, Map<String, String> lang) {
    final isSelected = auth.locale.languageCode == lang['code'];
    return InkWell(
      onTap: () => auth.setLocale(Locale(lang['code']!)),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(lang['flag']!, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(lang['label']!,
                  style: TextStyle(
                      color: isSelected ? AppTheme.mintPrimary : AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.mintPrimary, size: 20)
            else
              const Icon(Icons.circle_outlined, color: AppTheme.border, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _notifSection(BuildContext context, AuthProvider auth, AppLocalizations l10n) {
    final prefs = auth.notifPrefs;
    return _settingsCard([
      _switchTile(
        icon: Icons.notifications_outlined,
        iconColor: AppTheme.mintPrimary,
        title: l10n.enableNotifications,
        value: prefs.enabled,
        onChanged: (v) => auth.updateNotifPrefs(NotificationPrefs(
          enabled: v,
          taskUpdate:    prefs.taskUpdate,
          campaignAlert: prefs.campaignAlert,
          budgetAlert:   prefs.budgetAlert,
          teamMention:   prefs.teamMention,
          weeklyReport:  prefs.weeklyReport,
        )),
      ),
      if (prefs.enabled) ...[
        const Divider(height: 1, color: AppTheme.border, indent: 52),
        _switchTile(
          icon: Icons.task_alt_outlined,
          iconColor: AppTheme.accentBlue,
          title: l10n.notifTaskUpdate,
          value: prefs.taskUpdate,
          onChanged: (v) => auth.updateNotifPrefs(prefs..taskUpdate = v),
        ),
        const Divider(height: 1, color: AppTheme.border, indent: 52),
        _switchTile(
          icon: Icons.campaign_outlined,
          iconColor: AppTheme.mintPrimary,
          title: l10n.notifCampaignAlert,
          value: prefs.campaignAlert,
          onChanged: (v) => auth.updateNotifPrefs(prefs..campaignAlert = v),
        ),
        const Divider(height: 1, color: AppTheme.border, indent: 52),
        _switchTile(
          icon: Icons.account_balance_wallet_outlined,
          iconColor: AppTheme.accentOrange,
          title: l10n.notifBudgetAlert,
          value: prefs.budgetAlert,
          onChanged: (v) => auth.updateNotifPrefs(prefs..budgetAlert = v),
        ),
        const Divider(height: 1, color: AppTheme.border, indent: 52),
        _switchTile(
          icon: Icons.alternate_email,
          iconColor: AppTheme.accentPurple,
          title: l10n.notifTeamMention,
          value: prefs.teamMention,
          onChanged: (v) => auth.updateNotifPrefs(prefs..teamMention = v),
        ),
        const Divider(height: 1, color: AppTheme.border, indent: 52),
        _switchTile(
          icon: Icons.bar_chart_outlined,
          iconColor: AppTheme.accentGreen,
          title: l10n.notifWeeklyReport,
          value: prefs.weeklyReport,
          onChanged: (v) => auth.updateNotifPrefs(prefs..weeklyReport = v),
        ),
      ],
    ]);
  }

  Widget _securitySection(BuildContext context, AuthProvider auth, AppLocalizations l10n) {
    return _settingsCard([
      _settingsTile(
        icon: Icons.lock_outline,
        iconColor: AppTheme.accentBlue,
        title: l10n.sessionTimeout,
        subtitle: '8시간 후 자동 로그아웃',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.accentGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('활성화',
              style: TextStyle(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ),
      const Divider(height: 1, color: AppTheme.border, indent: 52),
      _settingsTile(
        icon: Icons.security,
        iconColor: AppTheme.mintPrimary,
        title: '비밀번호 해시',
        subtitle: 'SHA-256 + Salt 암호화',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.mintPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('적용됨',
              style: TextStyle(color: AppTheme.mintPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ),
      const Divider(height: 1, color: AppTheme.border, indent: 52),
      _settingsTile(
        icon: Icons.block,
        iconColor: AppTheme.accentOrange,
        title: '브루트포스 방지',
        subtitle: '5회 실패 시 15분 잠금',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.accentGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('활성화',
              style: TextStyle(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ),
      const Divider(height: 1, color: AppTheme.border, indent: 52),
      _settingsTile(
        icon: Icons.sanitizer_outlined,
        iconColor: AppTheme.accentBlue,
        title: 'XSS 방지',
        subtitle: '입력값 자동 무해화 처리',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.accentGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('적용됨',
              style: TextStyle(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }

  Widget _settingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (onTap != null && trailing == null)
              const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.mintPrimary,
          ),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────

  void _showTeamManagementSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _TeamManagementSheet(),
    );
  }

  void _showResetDataConfirm(BuildContext context) {
    final app = context.read<AppProvider>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.accentOrange, size: 22),
          SizedBox(width: 8),
          Text('데이터 초기화', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        ]),
        content: const Text(
          '모든 팀, 프로젝트, 태스크, KPI 데이터를\n디폴트 샘플 데이터로 초기화합니다.\n\n이 작업은 되돌릴 수 없습니다.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('데이터 초기화 중...'), duration: Duration(seconds: 2)),
                );
              }
              await app.resetAllData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('데이터가 초기화되었습니다.'),
                    backgroundColor: AppTheme.accentGreen,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentOrange),
            child: const Text('초기화', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('로그아웃', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('로그아웃 하시겠습니까?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (context.mounted) {
                context.read<AppProvider>().clearUid();
              }
              await auth.signOut();
              // _AppRouter가 auth 상태 변화를 감지해 자동으로 로그인 페이지로 전환
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            child: const Text('로그아웃', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('계정 삭제', style: TextStyle(color: AppTheme.accentRed)),
        content: const Text('모든 데이터가 영구 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (context.mounted) {
                context.read<AppProvider>().clearUid();
              }
              await auth.signOut();
              // _AppRouter가 auth 상태 변화를 감지해 자동으로 로그인 페이지로 전환
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            child: const Text('삭제 확인', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  IconData _providerIcon(LoginProvider p) {
    switch (p) {
      case LoginProvider.google:   return Icons.g_mobiledata_rounded;
      case LoginProvider.facebook: return Icons.facebook_rounded;
      case LoginProvider.whatsapp: return Icons.chat_rounded;
      case LoginProvider.email:    return Icons.email_outlined;
    }
  }

  Color _providerColor(LoginProvider p) {
    switch (p) {
      case LoginProvider.google:   return const Color(0xFFDB4437);
      case LoginProvider.facebook: return const Color(0xFF1877F2);
      case LoginProvider.whatsapp: return const Color(0xFF25D366);
      case LoginProvider.email:    return AppTheme.accentBlue;
    }
  }
}

// ── Privacy Info Dialog ───────────────────────────────────────
class _PrivacyInfoDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: AppTheme.bgCard,
      title: Row(children: [
        const Icon(Icons.shield_outlined, color: AppTheme.mintPrimary),
        const SizedBox(width: 8),
        Text(l10n.privacyTitle,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.privacySubtitle,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          _row(Icons.email_outlined, l10n.privacyEmailOnly),
          _row(Icons.analytics_outlined, l10n.privacyUsageData),
          _row(Icons.notifications_outlined, l10n.privacyNotificationPref),
          const SizedBox(height: 8),
          _row(Icons.block, l10n.privacyDataNotSold, AppTheme.accentRed),
          _row(Icons.lock, l10n.privacyDataEncrypted, AppTheme.mintPrimary),
          _row(Icons.delete_outline, l10n.privacyDeleteAccount, AppTheme.accentOrange),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String text, [Color? color]) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(icon, size: 14, color: color ?? AppTheme.textSecondary),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: TextStyle(color: color ?? AppTheme.textSecondary, fontSize: 12))),
    ]),
  );
}

// ── Team Management BottomSheet ───────────────────────────────
class _TeamManagementSheet extends StatefulWidget {
  const _TeamManagementSheet();
  @override
  State<_TeamManagementSheet> createState() => _TeamManagementSheetState();
}

class _TeamManagementSheetState extends State<_TeamManagementSheet> {
  final Set<String> _selectedProjects = {};
  String? _expandedTeamId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final teams = app.teams;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(children: [
              const Icon(Icons.group_remove_outlined, color: AppTheme.accentOrange, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('팀 & 프로젝트 관리',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: AppTheme.textMuted)),
            ]),
          ),
          const Divider(height: 1, color: AppTheme.border),
          // 팀 목록
          Flexible(
            child: teams.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('팀이 없습니다', style: TextStyle(color: AppTheme.textMuted)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: teams.length,
                    itemBuilder: (ctx, i) {
                      final team = teams[i];
                      final projects = app.getProjectsForTeam(team.id);
                      final isExpanded = _expandedTeamId == team.id;
                      return Column(
                        children: [
                          // 팀 행
                          Container(
                            color: AppTheme.bgCard,
                            child: ListTile(
                              leading: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: Color(int.tryParse('0xFF${team.colorHex.replaceAll('#', '')}') ?? 0xFF00BFA5)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Center(
                                  child: Text(team.iconEmoji, style: const TextStyle(fontSize: 18)),
                                ),
                              ),
                              title: Text(team.name,
                                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text('프로젝트 ${projects.length}개',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                // 프로젝트 보기 토글
                                if (projects.isNotEmpty)
                                  IconButton(
                                    icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                                        color: AppTheme.textMuted, size: 20),
                                    onPressed: () => setState(() {
                                      _expandedTeamId = isExpanded ? null : team.id;
                                      _selectedProjects.clear();
                                    }),
                                  ),
                                // 팀 삭제 버튼
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.accentRed, size: 20),
                                  tooltip: '팀 삭제',
                                  onPressed: () => _confirmDeleteTeam(context, app, team.id, team.name),
                                ),
                              ]),
                            ),
                          ),
                          // 프로젝트 목록 (확장 시)
                          if (isExpanded && projects.isNotEmpty) ...[
                            Container(
                              color: AppTheme.bgDark,
                              child: Column(children: [
                                // 일괄 삭제 툴바
                                if (_selectedProjects.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Row(children: [
                                      Text('${_selectedProjects.length}개 선택됨',
                                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: () => _confirmBulkDelete(context, app),
                                        icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: AppTheme.accentRed),
                                        label: const Text('일괄 삭제', style: TextStyle(color: AppTheme.accentRed, fontSize: 12)),
                                      ),
                                    ]),
                                  ),
                                ...projects.map((proj) {
                                  final isSelected = _selectedProjects.contains(proj.id);
                                  return CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (v) => setState(() {
                                      if (v == true) _selectedProjects.add(proj.id);
                                      else _selectedProjects.remove(proj.id);
                                    }),
                                    dense: true,
                                    contentPadding: const EdgeInsets.only(left: 24, right: 16),
                                    checkColor: Colors.white,
                                    activeColor: AppTheme.mintPrimary,
                                    title: Row(children: [
                                      Text(proj.iconEmoji, style: const TextStyle(fontSize: 14)),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(proj.name,
                                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
                                    ]),
                                    subtitle: Text('태스크 ${proj.tasks.length}개',
                                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                    secondary: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppTheme.accentRed, size: 18),
                                      tooltip: '삭제',
                                      onPressed: () => _confirmDeleteProject(context, app, proj.id, proj.name),
                                    ),
                                  );
                                }),
                              ]),
                            ),
                          ],
                          const Divider(height: 1, color: AppTheme.border),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _confirmDeleteTeam(BuildContext context, AppProvider app, String teamId, String teamName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('팀 삭제', style: TextStyle(color: AppTheme.accentRed)),
        content: Text('"$teamName" 팀과 팀에 속한 모든 프로젝트를 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await app.deleteTeam(teamId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('팀이 삭제되었습니다.'), backgroundColor: AppTheme.accentRed),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProject(BuildContext context, AppProvider app, String projectId, String projectName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('프로젝트 삭제', style: TextStyle(color: AppTheme.accentRed)),
        content: Text('"$projectName" 프로젝트를 삭제하시겠습니까?',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await app.deleteProject(projectId);
              setState(() { _selectedProjects.remove(projectId); });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('프로젝트가 삭제되었습니다.'), backgroundColor: AppTheme.accentRed),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmBulkDelete(BuildContext context, AppProvider app) {
    final count = _selectedProjects.length;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('프로젝트 일괄 삭제', style: TextStyle(color: AppTheme.accentRed)),
        content: Text('선택한 $count개의 프로젝트를 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ids = List<String>.from(_selectedProjects);
              await app.deleteProjectsBulk(ids);
              setState(() { _selectedProjects.clear(); });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$count개 프로젝트가 삭제되었습니다.'),
                    backgroundColor: AppTheme.accentRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            child: const Text('일괄 삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
