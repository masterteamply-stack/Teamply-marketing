import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
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
            ]),
            const SizedBox(height: 20),

            // ── 계정 ─────────────────────────────────────
            if (auth.isAuthenticated) ...[
              _sectionTitle('계정'),
              _settingsCard([
                _accountTile(auth),
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
              await auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
              }
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
              await auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
              }
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
