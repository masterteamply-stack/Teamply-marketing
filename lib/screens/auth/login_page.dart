import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _loginFormKey  = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  final _emailCtrl    = TextEditingController();
  final _pwCtrl       = TextEditingController();
  final _pw2Ctrl      = TextEditingController();
  final _nameCtrl     = TextEditingController();
  bool _obscurePw     = true;
  bool _obscurePw2    = true;
  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Social Login ─────────────────────────────────────────
  Future<void> _socialLogin(Future<bool> Function() loginFn) async {
    final auth = context.read<AuthProvider>();
    if (!auth.privacyAgreed) {
      final agreed = await _showPrivacyDialog();
      if (agreed != true) return;
    }
    final ok = await loginFn();
    if (ok && mounted) _goToDashboard();
  }

  // ── Email Login ──────────────────────────────────────────
  Future<void> _loginWithEmail() async {
    if (!_loginFormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    if (!auth.privacyAgreed) {
      final agreed = await _showPrivacyDialog();
      if (agreed != true) return;
    }
    final ok = await auth.signInWithEmail(_emailCtrl.text.trim(), _pwCtrl.text);
    if (ok && mounted) _goToDashboard();
  }

  // ── Register ─────────────────────────────────────────────
  Future<void> _register() async {
    if (!_signupFormKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('이용약관 및 개인정보처리방침에 동의해주세요'),
        backgroundColor: AppTheme.accentRed,
      ));
      return;
    }
    final auth = context.read<AuthProvider>();
    if (!auth.privacyAgreed) await auth.agreeToPrivacy();
    final ok = await auth.registerWithEmail(
        _emailCtrl.text.trim(), _pwCtrl.text, _nameCtrl.text.trim());
    if (ok && mounted) _goToDashboard();
  }

  Future<bool?> _showPrivacyDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PrivacyDialog(),
    );
  }

  void _goToDashboard() {
    // Replace entire navigator stack
    Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          // Background decoration
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.mintPrimary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentPurple.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? size.width * 0.15 : 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      _buildHeader(l10n),
                      const SizedBox(height: 32),
                      _buildSocialButtons(l10n, auth),
                      const SizedBox(height: 20),
                      _buildDivider(l10n),
                      const SizedBox(height: 20),
                      _buildTabBar(l10n),
                      const SizedBox(height: 20),
                      // Error message
                      if (auth.errorMessage != null)
                        _buildErrorBanner(auth.errorMessage!),
                      // Tab content
                      _tabCtrl.index == 0
                          ? _buildLoginForm(l10n, auth)
                          : _buildSignupForm(l10n, auth),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Language selector top-right
          Positioned(
            top: 12,
            right: 16,
            child: SafeArea(child: _LangButton()),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.mintPrimary, Color(0xFF0097A7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.mintPrimary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.insights_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.welcomeBack,
          style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.welcomeSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSocialButtons(AppLocalizations l10n, AuthProvider auth) {
    return Column(
      children: [
        // Google
        _SocialButton(
          icon: Icons.g_mobiledata_rounded,
          iconColor: const Color(0xFFDB4437),
          label: l10n.continueWithGoogle,
          isLoading: auth.isLoading,
          onTap: () => _socialLogin(auth.signInWithGoogle),
        ),
        const SizedBox(height: 10),
        // Facebook
        _SocialButton(
          icon: Icons.facebook_rounded,
          iconColor: const Color(0xFF1877F2),
          label: l10n.continueWithFacebook,
          isLoading: auth.isLoading,
          onTap: () => _socialLogin(auth.signInWithFacebook),
        ),
        const SizedBox(height: 10),
        // WhatsApp
        _SocialButton(
          icon: Icons.chat_rounded,
          iconColor: const Color(0xFF25D366),
          label: l10n.continueWithWhatsApp,
          isLoading: auth.isLoading,
          onTap: () => _socialLogin(auth.signInWithWhatsApp),
        ),
      ],
    );
  }

  Widget _buildDivider(AppLocalizations l10n) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppTheme.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(l10n.orContinueWith,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ),
        const Expanded(child: Divider(color: AppTheme.border)),
      ],
    );
  }

  Widget _buildTabBar(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabCtrl,
        onTap: (_) => setState(() {}),
        labelColor: AppTheme.mintPrimary,
        unselectedLabelColor: AppTheme.textMuted,
        indicator: BoxDecoration(
          color: AppTheme.mintPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: [Tab(text: l10n.signIn), Tab(text: l10n.signUp)],
      ),
    );
  }

  Widget _buildErrorBanner(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accentRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: const TextStyle(color: AppTheme.accentRed, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(AppLocalizations l10n, AuthProvider auth) {
    return Form(
      key: _loginFormKey,
      child: Column(
        children: [
          _InputField(
            ctrl: _emailCtrl,
            label: l10n.email,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || v.isEmpty) ? l10n.invalidEmail : null,
          ),
          const SizedBox(height: 12),
          _InputField(
            ctrl: _pwCtrl,
            label: l10n.password,
            icon: Icons.lock_outline,
            obscure: _obscurePw,
            onToggleObscure: () => setState(() => _obscurePw = !_obscurePw),
            validator: (v) => (v == null || v.length < 8) ? l10n.passwordMinLength : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: Text(l10n.forgotPassword,
                  style: const TextStyle(color: AppTheme.mintPrimary, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: auth.isLoading ? null : _loginWithEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mintPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: auth.isLoading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l10n.signIn,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupForm(AppLocalizations l10n, AuthProvider auth) {
    return Form(
      key: _signupFormKey,
      child: Column(
        children: [
          _InputField(
            ctrl: _nameCtrl,
            label: l10n.name,
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 12),
          _InputField(
            ctrl: _emailCtrl,
            label: l10n.email,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || v.isEmpty) ? l10n.invalidEmail : null,
          ),
          const SizedBox(height: 12),
          _InputField(
            ctrl: _pwCtrl,
            label: l10n.password,
            icon: Icons.lock_outline,
            obscure: _obscurePw,
            onToggleObscure: () => setState(() => _obscurePw = !_obscurePw),
            validator: (v) => (v == null || v.length < 8) ? l10n.passwordMinLength : null,
          ),
          const SizedBox(height: 12),
          _InputField(
            ctrl: _pw2Ctrl,
            label: l10n.confirmPassword,
            icon: Icons.lock_outline,
            obscure: _obscurePw2,
            onToggleObscure: () => setState(() => _obscurePw2 = !_obscurePw2),
            validator: (v) => v != _pwCtrl.text ? l10n.passwordsDoNotMatch : null,
          ),
          const SizedBox(height: 14),
          // Terms checkbox
          GestureDetector(
            onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _agreedToTerms,
                    onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                    activeColor: AppTheme.mintPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    side: const BorderSide(color: AppTheme.border, width: 1.5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      children: [
                        TextSpan(text: l10n.agreeToTerms.split('Terms')[0]),
                        TextSpan(
                          text: l10n.termsOfService,
                          style: const TextStyle(color: AppTheme.mintPrimary,
                              decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()..onTap = () {},
                        ),
                        const TextSpan(text: ' 및 '),
                        TextSpan(
                          text: l10n.privacyPolicy,
                          style: const TextStyle(color: AppTheme.mintPrimary,
                              decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => showDialog(
                              context: context,
                              builder: (_) => const _PrivacyDialog(showOnly: true),
                            ),
                        ),
                        const TextSpan(text: '에 동의합니다'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: auth.isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mintPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: auth.isLoading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l10n.createAccount,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input Field Widget ────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const _InputField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.onToggleObscure,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 18),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(
                    obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppTheme.textMuted, size: 18),
                onPressed: onToggleObscure,
              )
            : null,
        filled: true,
        fillColor: AppTheme.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.mintPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.accentRed),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ── Social Button ─────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            Expanded(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Language Button ──────────────────────────────────────────
class _LangButton extends StatelessWidget {
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
    final cur = _langs.firstWhere(
      (l) => l['code'] == auth.locale.languageCode, orElse: () => _langs[0]);
    return GestureDetector(
      onTap: () => _showSheet(context, auth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cur['flag']!, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, color: AppTheme.textMuted, size: 14),
          ],
        ),
      ),
    );
  }

  void _showSheet(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('언어 / Language',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ..._langs.map((l) => ListTile(
              dense: true,
              leading: Text(l['flag']!, style: const TextStyle(fontSize: 22)),
              title: Text(l['label']!,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
              trailing: auth.locale.languageCode == l['code']
                  ? const Icon(Icons.check_circle, color: AppTheme.mintPrimary, size: 18)
                  : null,
              onTap: () { auth.setLocale(Locale(l['code']!)); Navigator.pop(context); },
            )),
          ],
        ),
      ),
    );
  }
}

// ── Privacy Dialog ────────────────────────────────────────────
class _PrivacyDialog extends StatelessWidget {
  final bool showOnly;
  const _PrivacyDialog({this.showOnly = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.mintPrimary.withValues(alpha: 0.2), Colors.transparent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.mintPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shield_outlined, color: AppTheme.mintPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.privacyTitle,
                            style: const TextStyle(color: AppTheme.textPrimary,
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        Text(l10n.privacySubtitle,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _privacySectionTitle(l10n.privacyDataCollected),
                    _privacyItem(Icons.email_outlined, l10n.privacyEmailOnly),
                    _privacyItem(Icons.person_outline, l10n.privacyDisplayName),
                    _privacyItem(Icons.analytics_outlined, l10n.privacyUsageData),
                    _privacyItem(Icons.notifications_outlined, l10n.privacyNotificationPref),
                    const SizedBox(height: 16),
                    _privacySectionTitle('보장 사항'),
                    _privacyGuarantee(Icons.block, l10n.privacyDataNotSold, AppTheme.accentRed),
                    _privacyGuarantee(Icons.lock, l10n.privacyDataEncrypted, AppTheme.mintPrimary),
                    _privacyGuarantee(Icons.delete_outline, l10n.privacyDeleteAccount, AppTheme.accentOrange),
                  ],
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: showOnly
                  ? SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.close),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textMuted,
                              side: const BorderSide(color: AppTheme.border),
                            ),
                            child: Text(l10n.decline),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              await context.read<AuthProvider>().agreeToPrivacy();
                              if (context.mounted) Navigator.pop(context, true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.mintPrimary,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(l10n.acceptAndContinue,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _privacySectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              color: AppTheme.textMuted, fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    );
  }

  Widget _privacyItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(text,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _privacyGuarantee(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text,
              style: TextStyle(color: color.withValues(alpha: 0.9), fontSize: 13))),
        ],
      ),
    );
  }
}
