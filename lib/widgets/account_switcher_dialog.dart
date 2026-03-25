import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/app_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AccountSwitcherDialog — 계정 전환 / 로그인 / 로그아웃 통합 다이얼로그
// ─────────────────────────────────────────────────────────────────────────────
class AccountSwitcherDialog extends StatefulWidget {
  const AccountSwitcherDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: context.read<AuthProvider>()),
          ChangeNotifierProvider.value(value: context.read<AppProvider>()),
        ],
        child: const AccountSwitcherDialog(),
      ),
    );
  }

  @override
  State<AccountSwitcherDialog> createState() => _AccountSwitcherDialogState();
}

class _AccountSwitcherDialogState extends State<AccountSwitcherDialog>
    with SingleTickerProviderStateMixin {
  bool _showAddAccount = false;
  bool _showConfirmLogout = false;
  bool _logoutAll = false;

  // 계정 추가 폼 컨트롤러
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _obscurePw = true;
  bool _isRegisterMode = false;
  bool _nameVisible = false;
  String? _formError;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────
  //  Helper: 아바타 색상 계산
  // ────────────────────────────────────────────────
  Color _providerColor(LoginProvider p) {
    switch (p) {
      case LoginProvider.google:
        return const Color(0xFF4285F4);
      case LoginProvider.microsoft:
        return const Color(0xFF00A4EF);
      case LoginProvider.apple:
        return const Color(0xFF555555);
      case LoginProvider.facebook:
        return const Color(0xFF1877F2);
      case LoginProvider.whatsapp:
        return const Color(0xFF25D366);
      case LoginProvider.email:
        return AppTheme.mintPrimary;
    }
  }

  IconData _providerIcon(LoginProvider p) {
    switch (p) {
      case LoginProvider.google:
        return Icons.g_mobiledata_rounded;
      case LoginProvider.microsoft:
        return Icons.window_rounded;
      case LoginProvider.apple:
        return Icons.apple_rounded;
      case LoginProvider.facebook:
        return Icons.facebook_rounded;
      case LoginProvider.whatsapp:
        return Icons.chat_rounded;
      case LoginProvider.email:
        return Icons.email_outlined;
    }
  }

  String _providerLabel(LoginProvider p) {
    switch (p) {
      case LoginProvider.google:
        return 'Google';
      case LoginProvider.microsoft:
        return 'Microsoft';
      case LoginProvider.apple:
        return 'Apple';
      case LoginProvider.facebook:
        return 'Facebook';
      case LoginProvider.whatsapp:
        return 'WhatsApp';
      case LoginProvider.email:
        return '이메일';
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  // ────────────────────────────────────────────────
  //  계정 전환
  // ────────────────────────────────────────────────
  Future<void> _switchAccount(AuthUser account) async {
    final auth = context.read<AuthProvider>();
    final app = context.read<AppProvider>();

    // 이미 현재 계정이면 닫기
    if (account.id == auth.user?.id) {
      Navigator.of(context).pop();
      return;
    }

    // 현재 Supabase 세션 로그아웃 후 저장된 계정으로 재로그인
    // (저장된 계정은 이메일/비밀번호 재입력 없이 토큰으로 복원 불가 →
    //  선택한 계정의 이메일로 이동하여 로그인 유도)
    Navigator.of(context).pop();

    // AppProvider 데이터 초기화
    app.clearUid();

    // AuthProvider: 현재 로그아웃 처리 후 선택 계정 정보로 로컬 복원
    await auth.switchToSavedAccount(account);
  }

  // ────────────────────────────────────────────────
  //  로그아웃
  // ────────────────────────────────────────────────
  Future<void> _doSignOut({required bool all}) async {
    final auth = context.read<AuthProvider>();
    final app = context.read<AppProvider>();
    Navigator.of(context).pop();
    app.clearUid();
    if (all) {
      await auth.signOutAll();
    } else {
      await auth.signOut();
    }
  }

  // ────────────────────────────────────────────────
  //  다른 계정으로 로그인
  // ────────────────────────────────────────────────
  Future<void> _loginWithNewAccount() async {
    if (_formError != null) setState(() => _formError = null);
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text;
    final name = _nameCtrl.text.trim();

    if (email.isEmpty || pw.isEmpty) {
      setState(() => _formError = '이메일과 비밀번호를 입력해주세요.');
      return;
    }

    final auth = context.read<AuthProvider>();
    final app = context.read<AppProvider>();

    bool ok;
    if (_isRegisterMode) {
      ok = await auth.registerWithEmail(email, pw, name);
    } else {
      ok = await auth.signInWithEmail(email, pw);
    }

    if (ok && mounted) {
      final uid = auth.user?.id;
      if (uid != null) {
        app.setUidAndLoad(uid);
      }
      Navigator.of(context).pop();
    } else if (mounted && auth.errorMessage != null) {
      setState(() => _formError = auth.errorMessage);
    }
  }

  // ────────────────────────────────────────────────
  //  Google OAuth 로그인
  // ────────────────────────────────────────────────
  Future<void> _loginWithGoogle() async {
    final auth = context.read<AuthProvider>();
    Navigator.of(context).pop(); // 다이얼로그 닫기
    await auth.signInWithGoogle();
  }

  // ────────────────────────────────────────────────
  //  Build
  // ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: _showConfirmLogout
            ? _buildLogoutConfirm()
            : _showAddAccount
                ? _buildAddAccountPanel()
                : _buildMainPanel(),
      ),
    );
  }

  // ── 메인 패널 ──────────────────────────────────────────────
  Widget _buildMainPanel() {
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.user;
    final savedAccounts = auth.savedAccounts; // 현재 제외한 목록

    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: const Color(0xFF0F2030),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 헤더 ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
            decoration: BoxDecoration(
              color: AppTheme.mintPrimary.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.manage_accounts_rounded,
                    color: AppTheme.mintPrimary, size: 22),
                const SizedBox(width: 10),
                const Text('계정 관리',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded,
                      color: AppTheme.textMuted, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 현재 로그인 계정 ──
                if (currentUser != null) ...[
                  const Text('현재 계정',
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _buildAccountTile(
                    user: currentUser,
                    isCurrent: true,
                    onTap: () {},
                  ),
                  const SizedBox(height: 4),

                  // ── 빠른 액션 버튼 ──
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionBtn(
                          icon: Icons.logout_rounded,
                          label: '로그아웃',
                          color: Colors.redAccent,
                          onTap: () => setState(() {
                            _showConfirmLogout = true;
                            _logoutAll = false;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // ── 저장된 다른 계정 ──
                if (savedAccounts.isNotEmpty) ...[
                  const Text('저장된 계정으로 전환',
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...savedAccounts.map((account) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _buildAccountTile(
                          user: account,
                          isCurrent: false,
                          onTap: () => _switchAccount(account),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () =>
                                    auth.removeSavedAccount(account.id),
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 15, color: AppTheme.textMuted),
                                tooltip: '목록에서 제거',
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded,
                                  color: AppTheme.textMuted, size: 18),
                            ],
                          ),
                        ),
                      )),
                  const SizedBox(height: 12),
                ],

                // ── 다른 계정으로 로그인 ──
                _buildAddAccountBtn(),

                // ── Google로 계정 추가 ──
                const SizedBox(height: 8),
                _buildGoogleAddBtn(),

                // ── 전체 로그아웃 (저장 계정이 있을 때) ──
                if (savedAccounts.isNotEmpty || (auth.totalSavedAccounts > 1))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _buildActionBtn(
                      icon: Icons.logout_rounded,
                      label: '모든 계정에서 로그아웃',
                      color: Colors.red.shade700,
                      onTap: () => setState(() {
                        _showConfirmLogout = true;
                        _logoutAll = true;
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 계정 타일 ──────────────────────────────────────────────
  Widget _buildAccountTile({
    required AuthUser user,
    required bool isCurrent,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final color = _providerColor(user.provider);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrent
              ? AppTheme.mintPrimary.withValues(alpha: 0.12)
              : const Color(0xFF1A3044),
          borderRadius: BorderRadius.circular(12),
          border: isCurrent
              ? Border.all(
                  color: AppTheme.mintPrimary.withValues(alpha: 0.4), width: 1)
              : null,
        ),
        child: Row(
          children: [
            // 아바타
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.2),
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? Text(
                          _initials(user.displayName),
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        )
                      : null,
                ),
                if (isCurrent)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF0F2030), width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.displayName,
                          style: TextStyle(
                            color: isCurrent
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.mintPrimary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('활성',
                              style: TextStyle(
                                  color: AppTheme.mintPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(_providerIcon(user.provider),
                          color: color, size: 12),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          user.email.isEmpty
                              ? _providerLabel(user.provider)
                              : user.email,
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  // ── 계정 추가 버튼 ─────────────────────────────────────────
  Widget _buildAddAccountBtn() {
    return InkWell(
      onTap: () => setState(() {
        _showAddAccount = true;
        _isRegisterMode = false;
        _nameVisible = false;
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
              color: AppTheme.mintPrimary.withValues(alpha: 0.3), width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.person_add_outlined,
                color: AppTheme.mintPrimary, size: 18),
            SizedBox(width: 10),
            Text('다른 계정으로 로그인',
                style: TextStyle(
                    color: AppTheme.mintPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ── Google 계정 추가 버튼 ──────────────────────────────────
  Widget _buildGoogleAddBtn() {
    return InkWell(
      onTap: _loginWithGoogle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3044),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF4285F4).withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Text('G',
                    style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontWeight: FontWeight.w900,
                        fontSize: 14)),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Google로 다른 계정 추가',
                style: TextStyle(
                    color: Color(0xFF4285F4),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ── 액션 버튼 ──────────────────────────────────────────────
  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ── 계정 추가/로그인 패널 ──────────────────────────────────
  Widget _buildAddAccountPanel() {
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.isLoading;

    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: const Color(0xFF0F2030),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.mintPrimary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
            decoration: BoxDecoration(
              color: AppTheme.mintPrimary.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () =>
                      setState(() => _showAddAccount = false),
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: AppTheme.textMuted, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Text(
                  _isRegisterMode ? '새 계정 만들기' : '다른 계정으로 로그인',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 오류 메시지
                if (_formError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.redAccent, size: 15),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formError!,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 이름 (회원가입 모드)
                if (_isRegisterMode && _nameVisible) ...[
                  _buildTextField(
                    controller: _nameCtrl,
                    label: '이름',
                    icon: Icons.person_outline_rounded,
                    hint: '표시될 이름을 입력하세요',
                  ),
                  const SizedBox(height: 10),
                ],

                // 이메일
                _buildTextField(
                  controller: _emailCtrl,
                  label: '이메일',
                  icon: Icons.email_outlined,
                  hint: 'example@email.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),

                // 비밀번호
                _buildTextField(
                  controller: _pwCtrl,
                  label: '비밀번호',
                  icon: Icons.lock_outline_rounded,
                  hint: '비밀번호 (6자 이상)',
                  obscureText: _obscurePw,
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePw = !_obscurePw),
                    icon: Icon(
                      _obscurePw
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppTheme.textMuted,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 로그인/가입 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _loginWithNewAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.mintPrimary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : Text(
                            _isRegisterMode ? '계정 만들기' : '로그인',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),

                const SizedBox(height: 12),

                // 모드 전환
                Center(
                  child: TextButton(
                    onPressed: () => setState(() {
                      _isRegisterMode = !_isRegisterMode;
                      _nameVisible = _isRegisterMode;
                      _formError = null;
                    }),
                    child: Text(
                      _isRegisterMode
                          ? '이미 계정이 있나요? 로그인'
                          : '계정이 없나요? 회원가입',
                      style: const TextStyle(
                          color: AppTheme.mintPrimary, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 로그아웃 확인 ──────────────────────────────────────────
  Widget _buildLogoutConfirm() {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2030),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.logout_rounded,
                color: Colors.redAccent, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            _logoutAll ? '모든 계정에서 로그아웃' : '로그아웃',
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _logoutAll
                ? '저장된 모든 계정에서 로그아웃하고\n계정 목록을 초기화합니다.'
                : '현재 계정에서 로그아웃합니다.\n저장된 다른 계정은 유지됩니다.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      setState(() => _showConfirmLogout = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: Color(0xFF2A4055)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _doSignOut(all: _logoutAll),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('로그아웃',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 텍스트 필드 ────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A3044),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppTheme.mintPrimary.withValues(alpha: 0.2), width: 1),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 17),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            ),
          ),
        ),
      ],
    );
  }
}
