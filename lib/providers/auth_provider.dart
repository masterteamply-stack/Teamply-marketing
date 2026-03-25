// ════════════════════════════════════════════════════════════
//  AuthProvider – Supabase Auth 기반 (Firebase Auth fallback)
//  우선순위: Supabase Auth → Firebase Auth → 로컬 fallback
// ════════════════════════════════════════════════════════════
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';
import '../services/security_service.dart';

export 'package:firebase_auth/firebase_auth.dart' show User;

enum AuthStatus { unknown, unauthenticated, authenticated }
enum LoginProvider { google, microsoft, apple, facebook, whatsapp, email }

class AuthUser {
  final String id;
  final String email;
  final String displayName;
  final LoginProvider provider;
  final String? avatarUrl;
  final DateTime createdAt;

  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.provider,
    this.avatarUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'email': email, 'displayName': displayName,
    'provider': provider.name, 'avatarUrl': avatarUrl,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id: j['id'] as String? ?? '',
    email: j['email'] as String? ?? '',
    displayName: j['displayName'] as String? ?? '',
    provider: LoginProvider.values.firstWhere(
      (p) => p.name == (j['provider'] as String?),
      orElse: () => LoginProvider.email,
    ),
    avatarUrl: j['avatarUrl'] as String?,
    createdAt: j['createdAt'] != null
        ? DateTime.tryParse(j['createdAt'] as String) ?? DateTime.now()
        : DateTime.now(),
  );

  /// Firebase User로부터 AuthUser 생성
  factory AuthUser.fromFirebase(User fbUser,
      {LoginProvider provider = LoginProvider.email}) {
    return AuthUser(
      id: fbUser.uid,
      email: fbUser.email ?? '',
      displayName: fbUser.displayName ??
          fbUser.email?.split('@').first ??
          'User',
      provider: provider,
      avatarUrl: fbUser.photoURL,
      createdAt: fbUser.metadata.creationTime ?? DateTime.now(),
    );
  }

  /// SSO provider label
  String get providerLabel {
    switch (provider) {
      case LoginProvider.google:    return 'Google';
      case LoginProvider.microsoft: return 'Microsoft';
      case LoginProvider.apple:     return 'Apple';
      case LoginProvider.facebook:  return 'Facebook';
      case LoginProvider.whatsapp:  return 'WhatsApp';
      case LoginProvider.email:     return 'Email';
    }
  }

  /// Supabase User로부터 AuthUser 생성
  factory AuthUser.fromSupabase(sb.User sbUser,
      {String? displayName}) {
    final meta = sbUser.userMetadata;
    final name = displayName ??
        (meta?['display_name'] as String?) ??
        (meta?['full_name'] as String?) ??
        sbUser.email?.split('@').first ??
        'User';
    return AuthUser(
      id: sbUser.id,
      email: sbUser.email ?? '',
      displayName: name,
      provider: LoginProvider.email,
      avatarUrl: meta?['avatar_url'] as String?,
      createdAt: sbUser.createdAt != null
          ? DateTime.tryParse(sbUser.createdAt) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class NotificationPrefs {
  bool enabled;
  bool taskUpdate;
  bool campaignAlert;
  bool budgetAlert;
  bool teamMention;
  bool weeklyReport;

  NotificationPrefs({
    this.enabled = true,
    this.taskUpdate = true,
    this.campaignAlert = true,
    this.budgetAlert = true,
    this.teamMention = true,
    this.weeklyReport = false,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled, 'taskUpdate': taskUpdate,
    'campaignAlert': campaignAlert, 'budgetAlert': budgetAlert,
    'teamMention': teamMention, 'weeklyReport': weeklyReport,
  };

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) =>
      NotificationPrefs(
        enabled: j['enabled'] as bool? ?? true,
        taskUpdate: j['taskUpdate'] as bool? ?? true,
        campaignAlert: j['campaignAlert'] as bool? ?? true,
        budgetAlert: j['budgetAlert'] as bool? ?? true,
        teamMention: j['teamMention'] as bool? ?? true,
        weeklyReport: j['weeklyReport'] as bool? ?? false,
      );
}

// In-app notification model
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });
}

class AuthProvider extends ChangeNotifier {
  static const _userKey       = 'auth_user';
  static const _privacyKey    = 'privacy_agreed';
  static const _localeKey     = 'app_locale';
  static const _notifKey      = 'notif_prefs';
  static const _introKey      = 'intro_done';
  // 저장된 계정 목록 (계정 전환용)
  static const _savedAccountsKey = 'saved_accounts_v2';

  final SecurityService _sec = SecurityService();

  // ── 인증 백엔드 가용 여부 ──────────────────────────────────
  bool _supabaseAuthAvailable = false;
  bool _firebaseAuthAvailable = false;
  FirebaseAuth? _fbAuth;

  AuthStatus _status = AuthStatus.unknown;
  AuthUser? _user;
  bool _privacyAgreed = false;
  bool _introDone = false;
  Locale _locale = const Locale('ko');
  NotificationPrefs _notifPrefs = NotificationPrefs();
  bool _isLoading = false;
  String? _errorMessage;
  final List<AppNotification> _notifications = [];

  // ── 저장된 계정 목록 (계정 전환) ─────────────────────────
  List<AuthUser> _savedAccounts = [];

  // ── Getters ───────────────────────────────────────────────
  AuthStatus get status => _status;
  AuthUser? get user => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get privacyAgreed => _privacyAgreed;
  bool get introDone => _introDone;
  Locale get locale => _locale;
  NotificationPrefs get notifPrefs => _notifPrefs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get isFirebaseAvailable => _firebaseAuthAvailable;
  bool get isSupabaseAuthAvailable => _supabaseAuthAvailable;
  /// 저장된 계정 목록 (현재 로그인 계정 제외)
  List<AuthUser> get savedAccounts => List.unmodifiable(
    _savedAccounts.where((a) => a.id != _user?.id).toList(),
  );
  /// 저장된 계정 수 (현재 포함)
  int get totalSavedAccounts => _savedAccounts.length;

  // ── Supabase Auth 클라이언트 ──────────────────────────────
  sb.SupabaseClient? get _sbClient {
    try {
      return sb.Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  void _initSupabaseAuth() {
    if (_supabaseAuthAvailable) return;
    try {
      sb.Supabase.instance.client;
      _supabaseAuthAvailable = true;
      if (kDebugMode) debugPrint('[AuthProvider] Supabase Auth available ✅');
    } catch (e) {
      _supabaseAuthAvailable = false;
      if (kDebugMode) debugPrint('[AuthProvider] Supabase Auth not available: $e');
    }
  }

  void _initFirebaseAuth() {
    if (_firebaseAuthAvailable) return;
    try {
      Firebase.app();
      _fbAuth = FirebaseAuth.instance;
      _firebaseAuthAvailable = true;
      if (kDebugMode) debugPrint('[AuthProvider] Firebase Auth available ✅');
    } catch (e) {
      _firebaseAuthAvailable = false;
      if (kDebugMode) debugPrint('[AuthProvider] Firebase Auth not available: $e');
    }
  }

  // ── Initialization ────────────────────────────────────────
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      _initSupabaseAuth();
      _initFirebaseAuth();

      final prefs = await SharedPreferences.getInstance();

      final localeCode = prefs.getString(_localeKey) ?? 'ko';
      _locale = Locale(localeCode);

      _privacyAgreed = prefs.getBool(_privacyKey) ?? false;
      _introDone = prefs.getBool(_introKey) ?? false;

      final notifJson = prefs.getString(_notifKey);
      if (notifJson != null) {
        try {
          final decoded = jsonDecode(notifJson);
          if (decoded is Map<String, dynamic>) {
            _notifPrefs = NotificationPrefs.fromJson(decoded);
          }
        } catch (_) {}
      }

      // ── 저장된 계정 목록 로드 ────────────────────────────
      await _loadSavedAccounts(prefs);

      // ── 1순위: Supabase Auth 세션 복원 ──────────────────
      if (_supabaseAuthAvailable && _sbClient != null) {
        final sbUser = _sbClient!.auth.currentUser;
        if (sbUser != null) {
          _user = AuthUser.fromSupabase(sbUser);
          _status = AuthStatus.authenticated;
          if (kDebugMode) {
            debugPrint('[AuthProvider] Supabase session restored: ${sbUser.id}');
          }
        } else {
          // Supabase 세션 없음 → Firebase 시도 (await 필수)
          await _tryRestoreSessionFallback(prefs);
        }
      } else {
        // Supabase 불가 → Firebase 시도
        await _tryRestoreSessionFallback(prefs);
      }

      _loadSampleNotifications();
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthProvider] initialize error: $e');
      _status = AuthStatus.unauthenticated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── 세션 복원 fallback (Firebase → 로컬 SharedPreferences) ──
  Future<void> _tryRestoreSessionFallback(SharedPreferences prefs) async {
    // Firebase Auth 세션 확인
    if (_firebaseAuthAvailable && _fbAuth != null) {
      final fbUser = _fbAuth!.currentUser;
      if (fbUser != null) {
        _user = AuthUser.fromFirebase(fbUser);
        _status = AuthStatus.authenticated;
        if (kDebugMode) {
          debugPrint('[AuthProvider] Firebase session restored: ${fbUser.uid}');
        }
        return;
      }
    }
    // SharedPreferences 로컬 세션 확인
    final isValid = await _sec.isSessionValid();
    if (isValid) {
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        try {
          final map = jsonDecode(userJson);
          if (map is Map<String, dynamic> && map.isNotEmpty) {
            _user = AuthUser.fromJson(map);
            _status = AuthStatus.authenticated;
            if (kDebugMode) {
              debugPrint('[AuthProvider] Local session restored: ${_user!.id}');
            }
            return;
          }
        } catch (_) {}
      }
    }
    _status = AuthStatus.unauthenticated;
    if (kDebugMode) debugPrint('[AuthProvider] No session found → unauthenticated');
  }

  // ── Email Login ───────────────────────────────────────────
  Future<bool> signInWithEmail(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    if (await _sec.isAccountLocked()) {
      final remaining = await _sec.lockRemainingTime();
      final mins = remaining?.inMinutes ?? 15;
      _errorMessage = 'Account locked. Try again in $mins minutes.';
      _setLoading(false);
      return false;
    }

    if (!SecurityService.isValidEmail(email)) {
      _errorMessage = 'invalidEmail';
      _setLoading(false);
      return false;
    }
    if (!SecurityService.isStrongPassword(password)) {
      _errorMessage = 'passwordMinLength';
      _setLoading(false);
      return false;
    }

    _initSupabaseAuth();
    _initFirebaseAuth();

    // ── 1순위: Supabase Auth 로그인 ──────────────────────
    if (_supabaseAuthAvailable && _sbClient != null) {
      try {
        final res = await _sbClient!.auth.signInWithPassword(
          email: SecurityService.sanitize(email),
          password: password,
        );
        if (res.user != null) {
          await _sec.recordLoginSuccess();
          final authUser = AuthUser.fromSupabase(res.user!);
          await _completeLogin(authUser);
          return true;
        }
      } on sb.AuthException catch (e) {
        await _sec.recordLoginFailure();
        // email_not_confirmed → 이메일 인증 비활성화 안내
        if (e.message.toLowerCase().contains('email not confirmed')) {
          _errorMessage = '이메일 인증이 필요합니다.\nSupabase → Authentication → Email Confirm을 OFF로 설정하거나\n가입 시 받은 인증 이메일을 확인해주세요.';
        } else {
          _errorMessage = _mapSupabaseError(e.message);
        }
        _setLoading(false);
        return false;
      } catch (e) {
        if (kDebugMode) debugPrint('[Auth] Supabase signIn error: $e');
        // Supabase 실패 → Firebase fallback
      }
    }

    // ── 2순위: Firebase Auth 로그인 ──────────────────────
    if (_firebaseAuthAvailable && _fbAuth != null) {
      try {
        final credential = await _fbAuth!.signInWithEmailAndPassword(
          email: SecurityService.sanitize(email),
          password: password,
        );
        if (credential.user != null) {
          await _sec.recordLoginSuccess();
          final authUser = AuthUser.fromFirebase(credential.user!);
          await _completeLogin(authUser);
          return true;
        }
      } on FirebaseAuthException catch (e) {
        await _sec.recordLoginFailure();
        _errorMessage = _mapFirebaseError(e.code);
        _setLoading(false);
        return false;
      } catch (e) {
        if (kDebugMode) debugPrint('[Auth] Firebase signIn error: $e');
      }
    }

    // ── 3순위: 로컬 Fallback ──────────────────────────────
    await Future.delayed(const Duration(milliseconds: 600));
    try {
      await _sec.recordLoginSuccess();
      final user = AuthUser(
        id: const Uuid().v4(),
        email: SecurityService.sanitize(email),
        displayName: email.split('@').first,
        provider: LoginProvider.email,
        createdAt: DateTime.now(),
      );
      await _completeLogin(user);
      return true;
    } catch (e) {
      await _sec.recordLoginFailure();
      _errorMessage = 'loginFailed';
      _setLoading(false);
      return false;
    }
  }

  // ── Email Register ────────────────────────────────────────
  Future<bool> registerWithEmail(
      String email, String password, String name) async {
    _setLoading(true);
    _errorMessage = null;

    if (!SecurityService.isValidEmail(email)) {
      _errorMessage = 'invalidEmail';
      _setLoading(false);
      return false;
    }
    if (!SecurityService.isStrongPassword(password)) {
      _errorMessage = 'passwordMinLength';
      _setLoading(false);
      return false;
    }

    _initSupabaseAuth();
    _initFirebaseAuth();

    // ── 1순위: Supabase Auth 회원가입 ─────────────────────
    if (_supabaseAuthAvailable && _sbClient != null) {
      try {
        final cleanName = SecurityService.sanitize(
            name.trim().isEmpty ? email.split('@').first : name);
        final res = await _sbClient!.auth.signUp(
          email: SecurityService.sanitize(email),
          password: password,
          data: {'display_name': cleanName, 'full_name': cleanName},
        );
        if (res.user != null) {
          // 세션이 있으면 즉시 로그인 (이메일 인증 OFF 상태)
          if (res.session != null) {
            final authUser = AuthUser.fromSupabase(res.user!, displayName: cleanName);
            await _completeLogin(authUser);
            return true;
          } else {
            // 이메일 인증 ON 상태 → 안내 메시지
            _errorMessage = '가입 확인 이메일을 발송했습니다.\n받은 편지함을 확인해 인증 후 로그인해주세요.\n\n⚠️ 이메일 인증을 비활성화하려면:\nSupabase Dashboard → Authentication → Email Confirm → OFF';
            _setLoading(false);
            return false;
          }
        }
      } on sb.AuthException catch (e) {
        _errorMessage = _mapSupabaseError(e.message);
        _setLoading(false);
        return false;
      } catch (e) {
        if (kDebugMode) debugPrint('[Auth] Supabase signUp error: $e');
      }
    }

    // ── 2순위: Firebase Auth 회원가입 ─────────────────────
    if (_firebaseAuthAvailable && _fbAuth != null) {
      try {
        final credential = await _fbAuth!.createUserWithEmailAndPassword(
          email: SecurityService.sanitize(email),
          password: password,
        );
        if (credential.user != null) {
          final cleanName = SecurityService.sanitize(
              name.trim().isEmpty ? email.split('@').first : name);
          await credential.user!.updateDisplayName(cleanName);
          await credential.user!.reload();
          final updatedUser = _fbAuth!.currentUser!;
          final authUser = AuthUser.fromFirebase(updatedUser);
          await _completeLogin(authUser);
          return true;
        }
      } on FirebaseAuthException catch (e) {
        _errorMessage = _mapFirebaseError(e.code);
        _setLoading(false);
        return false;
      } catch (e) {
        if (kDebugMode) debugPrint('[Auth] Firebase register error: $e');
      }
    }

    // ── 3순위: 로컬 Fallback ──────────────────────────────
    await Future.delayed(const Duration(milliseconds: 800));
    try {
      final cleanName = SecurityService.sanitize(
          name.trim().isEmpty ? email.split('@').first : name);
      final user = AuthUser(
        id: const Uuid().v4(),
        email: SecurityService.sanitize(email),
        displayName: cleanName,
        provider: LoginProvider.email,
        createdAt: DateTime.now(),
      );
      await _completeLogin(user);
      return true;
    } catch (e) {
      _errorMessage = 'loginFailed';
      _setLoading(false);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  SSO 로그인 (Google / Microsoft / Apple)
  //  우선순위: Supabase OAuth → Firebase OAuthProvider → 로컬 fallback
  // ═══════════════════════════════════════════════════════════

  // ── Google SSO ──────────────────────────────────────────────
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _errorMessage = null;
    _initSupabaseAuth();
    _initFirebaseAuth();

    // 1순위: Supabase OAuth (Web에서 가장 안정적)
    if (_supabaseAuthAvailable && _sbClient != null) {
      try {
        final redirectTo = _getOAuthRedirectUrl();
        if (kDebugMode) debugPrint('[Auth] Google OAuth → Supabase: $redirectTo');
        await _sbClient!.auth.signInWithOAuth(
          sb.OAuthProvider.google,
          redirectTo: redirectTo,
          authScreenLaunchMode: sb.LaunchMode.platformDefault,
        );
        _setLoading(false);
        return false; // 리다이렉트 진행 중 → onAuthStateChange로 완료
      } catch (e) {
        if (kDebugMode) debugPrint('[Auth] Supabase Google error: $e');
        // Supabase 실패 시 Firebase로 fallback
      }
    }

    // 2순위: Firebase OAuthProvider (google.com)
    if (_firebaseAuthAvailable && _fbAuth != null) {
      try {
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');
        if (kDebugMode) debugPrint('[Auth] Google OAuth → Firebase signInWithPopup');
        final result = await _fbAuth!.signInWithPopup(provider);
        if (result.user != null) {
          final authUser = AuthUser.fromFirebase(
            result.user!, provider: LoginProvider.google);
          await _completeLogin(authUser);
          return true;
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
          if (kDebugMode) debugPrint('[Auth] Firebase Google popup closed by user');
          _setLoading(false);
          return false;
        }
        _errorMessage = 'Google 로그인 중 오류가 발생했습니다. (${e.code})';
        if (kDebugMode) debugPrint('[Auth] Firebase Google error: ${e.code}');
      } catch (e) {
        if (kDebugMode) debugPrint('[Auth] Firebase Google error: $e');
      }
    }

    _errorMessage ??= 'Google 로그인을 사용하려면 Supabase 또는 Firebase 설정이 필요합니다.';
    _setLoading(false);
    return false;
  }

  // ── Microsoft SSO ───────────────────────────────────────────
  Future<bool> signInWithMicrosoft() async {
    _setLoading(true);
    _errorMessage = null;
    _initSupabaseAuth();
    _initFirebaseAuth();

    // 1순위: Supabase OAuth azure provider
    if (_supabaseAuthAvailable && _sbClient != null) {
      try {
        final redirectTo = _getOAuthRedirectUrl();
        if (kDebugMode) debugPrint('[Auth] Microsoft OAuth → Supabase: $redirectTo');
        await _sbClient!.auth.signInWithOAuth(
          sb.OAuthProvider.azure,
          redirectTo: redirectTo,
          authScreenLaunchMode: sb.LaunchMode.platformDefault,
          queryParams: {
            'prompt': 'select_account',
            'response_mode': 'query',
          },
        );
        _setLoading(false);
        return false; // 리다이렉트 → onAuthStateChange 처리
      } catch (e) {
        if (kDebugMode) debugPrint('[Auth] Supabase Microsoft error: $e');
      }
    }

    // 2순위: Firebase OAuthProvider (microsoft.com)
    if (_firebaseAuthAvailable && _fbAuth != null) {
      try {
        final provider = OAuthProvider('microsoft.com');
        provider.addScope('email');
        provider.addScope('profile');
        provider.addScope('openid');
        if (kDebugMode) debugPrint('[Auth] Microsoft OAuth → Firebase signInWithPopup');
        final result = await _fbAuth!.signInWithPopup(provider);
        if (result.user != null) {
          final authUser = AuthUser.fromFirebase(
            result.user!, provider: LoginProvider.microsoft);
          await _completeLogin(authUser);
          return true;
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
          _setLoading(false);
          return false;
        }
        _errorMessage = 'Microsoft 로그인 중 오류가 발생했습니다. (${e.code})';
        if (kDebugMode) debugPrint('[Auth] Firebase Microsoft error: ${e.code} - ${e.message}');
      } catch (e) {
        if (kDebugMode) debugPrint('[Auth] Firebase Microsoft error: $e');
      }
    }

    _errorMessage ??= 'Microsoft 로그인을 사용하려면 Firebase Console에서 Microsoft 공급자를 활성화하세요.';
    _setLoading(false);
    return false;
  }

  // ── Apple SSO ───────────────────────────────────────────────
  Future<bool> signInWithApple() async {
    _setLoading(true);
    _errorMessage = null;
    _initSupabaseAuth();
    _initFirebaseAuth();

    // 1순위: Supabase OAuth apple provider
    if (_supabaseAuthAvailable && _sbClient != null) {
      try {
        final redirectTo = _getOAuthRedirectUrl();
        if (kDebugMode) debugPrint('[Auth] Apple OAuth → Supabase: $redirectTo');
        await _sbClient!.auth.signInWithOAuth(
          sb.OAuthProvider.apple,
          redirectTo: redirectTo,
          authScreenLaunchMode: sb.LaunchMode.platformDefault,
        );
        _setLoading(false);
        return false; // 리다이렉트 → onAuthStateChange 처리
      } catch (e) {
        if (kDebugMode) debugPrint('[Auth] Supabase Apple error: $e');
      }
    }

    // 2순위: Firebase OAuthProvider (apple.com)
    if (_firebaseAuthAvailable && _fbAuth != null) {
      try {
        final provider = OAuthProvider('apple.com');
        provider.addScope('email');
        provider.addScope('name');
        if (kDebugMode) debugPrint('[Auth] Apple OAuth → Firebase signInWithPopup');
        final result = await _fbAuth!.signInWithPopup(provider);
        if (result.user != null) {
          final authUser = AuthUser.fromFirebase(
            result.user!, provider: LoginProvider.apple);
          await _completeLogin(authUser);
          return true;
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
          _setLoading(false);
          return false;
        }
        _errorMessage = 'Apple 로그인 중 오류가 발생했습니다. (${e.code})';
        if (kDebugMode) debugPrint('[Auth] Firebase Apple error: ${e.code} - ${e.message}');
      } catch (e) {
        if (kDebugMode) debugPrint('[Auth] Firebase Apple error: $e');
      }
    }

    _errorMessage ??= 'Apple 로그인을 사용하려면 Firebase Console에서 Apple 공급자를 활성화하고 Team ID를 설정하세요.';
    _setLoading(false);
    return false;
  }

  /// OAuth 리다이렉트 URL — 각 SSO 공급자에서 돌아올 주소
  String _getOAuthRedirectUrl() {
    if (kIsWeb) {
      return '${Uri.base.origin}/';
    }
    return 'io.supabase.teamply://login-callback/';
  }

  /// Supabase Auth State Change 리스너 등록 (main에서 호출)
  /// Google OAuth 리다이렉트 콜백도 여기서 처리됨
  void listenToAuthStateChanges() {
    if (!_supabaseAuthAvailable || _sbClient == null) return;

    _sbClient!.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;
      if (kDebugMode) debugPrint('[Auth] onAuthStateChange: $event');

      switch (event) {
        // Google OAuth 리다이렉트 후 복귀 시 발생
        case sb.AuthChangeEvent.signedIn:
        case sb.AuthChangeEvent.initialSession:
          if (session != null) {
            final sbUser = session.user;
            if (_status != AuthStatus.authenticated || _user?.id != sbUser.id) {
              if (kDebugMode) debugPrint('[Auth] 세션 감지 → 로그인 처리: ${sbUser.id}');
              final authUser = AuthUser.fromSupabase(sbUser);
              await _completeLogin(authUser);
            }
          }
          break;

        case sb.AuthChangeEvent.signedOut:
          if (_status == AuthStatus.authenticated) {
            await _handleRemoteSignOut();
          }
          break;

        case sb.AuthChangeEvent.tokenRefreshed:
          if (session != null && _user != null) {
            _user = AuthUser.fromSupabase(session.user);
            notifyListeners();
          }
          break;

        default:
          break;
      }
    });
  }

  Future<void> _handleRemoteSignOut() async {
    await _sec.clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ── Social Login (Facebook/WhatsApp – mock) ───────────────
  Future<bool> signInWithFacebook() => _socialLoginMock(LoginProvider.facebook);
  Future<bool> signInWithWhatsApp() => _socialLoginMock(LoginProvider.whatsapp);

  Future<bool> _socialLoginMock(LoginProvider provider) async {
    _setLoading(true);
    _errorMessage = null;
    await Future.delayed(const Duration(milliseconds: 800));
    try {
      final mockUser = AuthUser(
        id: const Uuid().v4(),
        email: '${provider.name}.user@teamply.io',
        displayName: _providerDisplayName(provider),
        provider: provider,
        createdAt: DateTime.now(),
      );
      await _completeLogin(mockUser);
      return true;
    } catch (e) {
      _errorMessage = '로그인에 실패했습니다.';
      _setLoading(false);
      return false;
    }
  }

  String _providerDisplayName(LoginProvider p) {
    switch (p) {
      case LoginProvider.google:
        return 'Google User';
      case LoginProvider.microsoft:
        return 'Microsoft User';
      case LoginProvider.apple:
        return 'Apple User';
      case LoginProvider.facebook:
        return 'Facebook User';
      case LoginProvider.whatsapp:
        return 'WhatsApp User';
      case LoginProvider.email:
        return 'Email User';
    }
  }

  // ── 로그인 완료 공통 처리 ─────────────────────────────────
  Future<void> _completeLogin(AuthUser user) async {
    _user = user;
    _status = AuthStatus.authenticated;
    // ① SecurityService 세션 생성
    await _sec.createSession(user.id);
    // ② SharedPreferences 백업 (오프라인 복원용)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    // ③ 계정 목록에 추가/갱신
    await _addToSavedAccounts(user, prefs);
    // ④ Supabase user_meta 업데이트 (연결된 경우)
    if (_supabaseAuthAvailable && _sbClient != null) {
      try {
        await _sbClient!.from('user_meta').upsert({
          'uid': user.id,
          'email': user.email,
          'display_name': user.displayName,
          'last_seen': DateTime.now().toIso8601String(),
        }, onConflict: 'uid');
      } catch (e) {
        if (kDebugMode) debugPrint('[Auth] user_meta upsert error: $e');
      }
    }
    if (kDebugMode) debugPrint('[Auth] Login complete: ${user.id} (${user.email})');
    _setLoading(false);
    notifyListeners();
  }

  // ── Sign Out ──────────────────────────────────────────────
  /// 현재 계정만 로그아웃 (저장 목록 유지)
  Future<void> signOut() async {
    if (_supabaseAuthAvailable && _sbClient != null) {
      try { await _sbClient!.auth.signOut(); } catch (e) {
        if (kDebugMode) debugPrint('[Auth] Supabase signOut error: $e');
      }
    }
    if (_firebaseAuthAvailable && _fbAuth != null) {
      try { await _fbAuth!.signOut(); } catch (e) {
        if (kDebugMode) debugPrint('[Auth] Firebase signOut error: $e');
      }
    }
    await _sec.clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// 모든 계정에서 로그아웃 + 저장 목록 초기화
  Future<void> signOutAll() async {
    await signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedAccountsKey);
    _savedAccounts.clear();
    notifyListeners();
  }

  /// 저장 목록에서 특정 계정 제거
  Future<void> removeSavedAccount(String uid) async {
    _savedAccounts.removeWhere((a) => a.id == uid);
    await _persistSavedAccounts();
    notifyListeners();
  }

  /// 저장된 계정으로 전환 (현재 세션 로그아웃 후 저장된 계정으로 복원)
  Future<void> switchToSavedAccount(AuthUser account) async {
    _isLoading = true;
    notifyListeners();
    try {
      // 현재 Supabase/Firebase 세션 로그아웃
      if (_supabaseAuthAvailable && _sbClient != null) {
        try { await _sbClient!.auth.signOut(); } catch (_) {}
      }
      if (_firebaseAuthAvailable && _fbAuth != null) {
        try { await _fbAuth!.signOut(); } catch (_) {}
      }
      await _sec.clearSession();

      // 선택된 계정을 현재 계정으로 복원 (로컬 세션 기반)
      _user = account;
      _status = AuthStatus.authenticated;
      await _sec.createSession(account.id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(account.toJson()));
      // 계정 목록 순서 업데이트 (선택 계정을 맨 앞으로)
      await _addToSavedAccounts(account, prefs);

      // Supabase user_meta 업데이트
      if (_supabaseAuthAvailable && _sbClient != null) {
        try {
          await _sbClient!.from('user_meta').upsert({
            'uid': account.id,
            'email': account.email,
            'display_name': account.displayName,
            'last_seen': DateTime.now().toIso8601String(),
          }, onConflict: 'uid');
        } catch (e) {
          if (kDebugMode) debugPrint('[Auth] switchToSavedAccount user_meta error: $e');
        }
      }
      if (kDebugMode) debugPrint('[Auth] Switched to account: ${account.id}');
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] switchToSavedAccount error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════
  //  저장된 계정 관리
  // ══════════════════════════════════════════════════════════
  Future<void> _loadSavedAccounts(SharedPreferences prefs) async {
    try {
      final raw = prefs.getString(_savedAccountsKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List;
      _savedAccounts = list
          .map((e) {
            try { return AuthUser.fromJson(e as Map<String, dynamic>); }
            catch (_) { return null; }
          })
          .whereType<AuthUser>()
          .toList();
      if (kDebugMode) debugPrint('[Auth] Loaded ${_savedAccounts.length} saved accounts');
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] _loadSavedAccounts error: $e');
    }
  }

  Future<void> _addToSavedAccounts(AuthUser user, SharedPreferences prefs) async {
    // 기존 계정 업데이트 또는 신규 추가 (최대 5개)
    _savedAccounts.removeWhere((a) => a.id == user.id);
    _savedAccounts.insert(0, user);
    if (_savedAccounts.length > 5) {
      _savedAccounts = _savedAccounts.sublist(0, 5);
    }
    await _persistSavedAccounts(prefs: prefs);
  }

  Future<void> _persistSavedAccounts({SharedPreferences? prefs}) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      await p.setString(
        _savedAccountsKey,
        jsonEncode(_savedAccounts.map((a) => a.toJson()).toList()),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] _persistSavedAccounts error: $e');
    }
  }

  /// initialize() 타임아웃 시 강제로 unauthenticated 상태로 전환
  void forceUnauthenticated() {
    if (_status == AuthStatus.unknown) {
      _status = AuthStatus.unauthenticated;
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Supabase 오류 코드 → 사용자 친화적 메시지 ──────────────
  String _mapSupabaseError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid email or password')) {
      return '이메일 또는 비밀번호가 올바르지 않습니다.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('email already')) {
      return '이미 사용 중인 이메일입니다.';
    }
    if (lower.contains('email not confirmed')) {
      return '이메일 인증이 필요합니다. 받은 편지함을 확인해주세요.';
    }
    if (lower.contains('password should be at least')) {
      return '비밀번호는 최소 6자 이상이어야 합니다.';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return '너무 많은 시도입니다. 잠시 후 다시 시도해주세요.';
    }
    if (lower.contains('network')) {
      return '네트워크 오류가 발생했습니다.';
    }
    return 'loginFailed';
  }

  // ── Firebase 오류 코드 → 사용자 친화적 메시지 ──────────────
  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return '등록되지 않은 이메일입니다.';
      case 'wrong-password':
        return '비밀번호가 올바르지 않습니다.';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'weak-password':
        return '비밀번호가 너무 약합니다. (6자 이상)';
      case 'invalid-email':
        return '유효하지 않은 이메일 형식입니다.';
      case 'too-many-requests':
        return '너무 많은 시도입니다. 잠시 후 다시 시도해주세요.';
      case 'network-request-failed':
        return '네트워크 오류가 발생했습니다.';
      case 'operation-not-allowed':
        return '이 로그인 방식이 허용되지 않습니다.';
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 올바르지 않습니다.';
      default:
        return 'loginFailed';
    }
  }

  // ── Privacy Agreement ─────────────────────────────────────
  Future<void> agreeToPrivacy() async {
    _privacyAgreed = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyKey, true);
    notifyListeners();
  }

  // ── Intro Done ────────────────────────────────────────────
  Future<void> completeIntro() async {
    _introDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introKey, true);
    notifyListeners();
  }

  // ── Locale ────────────────────────────────────────────────
  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
    notifyListeners();
  }

  // ── Notification Prefs ────────────────────────────────────
  Future<void> updateNotifPrefs(NotificationPrefs newPrefs) async {
    _notifPrefs = newPrefs;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_notifKey, jsonEncode(newPrefs.toJson()));
    notifyListeners();
  }

  // ── In-App Notifications ──────────────────────────────────
  void addNotification(AppNotification notif) {
    _notifications.insert(0, notif);
    notifyListeners();
  }

  void markAllRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void markRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _notifications[idx].isRead = true;
      notifyListeners();
    }
  }

  void pushNotification({
    required String title,
    required String body,
    required String type,
  }) {
    if (!_notifPrefs.enabled) return;
    if (type == 'task' && !_notifPrefs.taskUpdate) return;
    if (type == 'campaign' && !_notifPrefs.campaignAlert) return;
    if (type == 'budget' && !_notifPrefs.budgetAlert) return;
    if (type == 'mention' && !_notifPrefs.teamMention) return;
    if (type == 'report' && !_notifPrefs.weeklyReport) return;

    addNotification(AppNotification(
      id: const Uuid().v4(),
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
    ));
  }

  void _loadSampleNotifications() {
    final now = DateTime.now();
    _notifications.addAll([
      AppNotification(
          id: 'n1',
          title: '캠페인 예산 알림',
          body: 'Q2 디지털 캠페인 예산이 80%에 달했습니다',
          type: 'budget',
          createdAt: now.subtract(const Duration(minutes: 5))),
      AppNotification(
          id: 'n2',
          title: '태스크 업데이트',
          body: '브랜드 가이드라인 제작이 검토 단계로 이동했습니다',
          type: 'task',
          createdAt: now.subtract(const Duration(hours: 1))),
      AppNotification(
          id: 'n3',
          title: '팀 멘션',
          body: '홍길동님이 당신을 SNS 광고 전략에서 언급했습니다',
          type: 'mention',
          createdAt: now.subtract(const Duration(hours: 3))),
      AppNotification(
          id: 'n4',
          title: 'KPI 달성 알림',
          body: '전환율 KPI가 목표치를 초과했습니다! 🎉',
          type: 'campaign',
          createdAt: now.subtract(const Duration(days: 1))),
    ]);
  }

  // ── Helpers ───────────────────────────────────────────────
  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
