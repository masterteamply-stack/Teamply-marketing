// ════════════════════════════════════════════════════════════
//  AuthProvider – Firebase Auth 기반 로그인/회원가입/세션 관리
//  - 이메일/비밀번호 실제 Firebase Auth 처리
//  - 소셜 로그인 (UI만 표시, Firebase Auth 소셜 연동 준비)
//  - 인트로/로케일/알림설정 SharedPreferences 저장
// ════════════════════════════════════════════════════════════
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../services/security_service.dart';

export 'package:firebase_auth/firebase_auth.dart' show User;

enum AuthStatus { unknown, unauthenticated, authenticated }
enum LoginProvider { google, facebook, whatsapp, email }

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
  factory AuthUser.fromFirebase(User fbUser, {LoginProvider provider = LoginProvider.email}) {
    return AuthUser(
      id: fbUser.uid,
      email: fbUser.email ?? '',
      displayName: fbUser.displayName ?? fbUser.email?.split('@').first ?? 'User',
      provider: provider,
      avatarUrl: fbUser.photoURL,
      createdAt: fbUser.metadata.creationTime ?? DateTime.now(),
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
    this.enabled       = true,
    this.taskUpdate    = true,
    this.campaignAlert = true,
    this.budgetAlert   = true,
    this.teamMention   = true,
    this.weeklyReport  = false,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled, 'taskUpdate': taskUpdate,
    'campaignAlert': campaignAlert, 'budgetAlert': budgetAlert,
    'teamMention': teamMention, 'weeklyReport': weeklyReport,
  };

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) => NotificationPrefs(
    enabled:       j['enabled']       as bool? ?? true,
    taskUpdate:    j['taskUpdate']     as bool? ?? true,
    campaignAlert: j['campaignAlert']  as bool? ?? true,
    budgetAlert:   j['budgetAlert']    as bool? ?? true,
    teamMention:   j['teamMention']    as bool? ?? true,
    weeklyReport:  j['weeklyReport']   as bool? ?? false,
  );
}

// In-app notification model
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // task / campaign / budget / mention / report / system
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
  static const _userKey    = 'auth_user';
  static const _privacyKey = 'privacy_agreed';
  static const _localeKey  = 'app_locale';
  static const _notifKey   = 'notif_prefs';
  static const _introKey   = 'intro_done';

  final SecurityService _sec = SecurityService();

  // Firebase Auth 가용 여부
  bool _firebaseAuthAvailable = false;
  FirebaseAuth? _fbAuth;

  AuthStatus         _status       = AuthStatus.unknown;
  AuthUser?          _user;
  bool               _privacyAgreed = false;
  bool               _introDone     = false;
  Locale             _locale        = const Locale('ko');
  NotificationPrefs  _notifPrefs   = NotificationPrefs();
  bool               _isLoading    = false;
  String?            _errorMessage;
  final List<AppNotification> _notifications = [];

  // ── Getters ───────────────────────────────────────────────
  AuthStatus get status          => _status;
  AuthUser?  get user            => _user;
  bool   get isAuthenticated     => _status == AuthStatus.authenticated;
  bool   get privacyAgreed       => _privacyAgreed;
  bool   get introDone           => _introDone;
  Locale get locale              => _locale;
  NotificationPrefs get notifPrefs => _notifPrefs;
  bool   get isLoading           => _isLoading;
  String? get errorMessage       => _errorMessage;
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int    get unreadCount         => _notifications.where((n) => !n.isRead).length;
  bool   get isFirebaseAvailable => _firebaseAuthAvailable;

  // ── Firebase Auth 초기화 ──────────────────────────────────
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
      _initFirebaseAuth();

      final prefs = await SharedPreferences.getInstance();

      // Restore locale
      final localeCode = prefs.getString(_localeKey) ?? 'ko';
      _locale = Locale(localeCode);

      // Restore privacy agreement
      _privacyAgreed = prefs.getBool(_privacyKey) ?? false;

      // Restore intro state
      _introDone = prefs.getBool(_introKey) ?? false;

      // Restore notification prefs
      final notifJson = prefs.getString(_notifKey);
      if (notifJson != null) {
        try {
          final decoded = jsonDecode(notifJson);
          if (decoded is Map<String, dynamic>) {
            _notifPrefs = NotificationPrefs.fromJson(decoded);
          }
        } catch (_) {}
      }

      // ── Firebase Auth 세션 복원 시도 ──────────────────────
      if (_firebaseAuthAvailable && _fbAuth != null) {
        final fbUser = _fbAuth!.currentUser;
        if (fbUser != null) {
          // Firebase 세션이 살아있으면 바로 복원
          _user = AuthUser.fromFirebase(fbUser);
          _status = AuthStatus.authenticated;
          if (kDebugMode) debugPrint('[AuthProvider] Firebase session restored: ${fbUser.uid}');
        } else {
          _status = AuthStatus.unauthenticated;
        }
      } else {
        // Firebase 불가 → SharedPreferences 세션으로 복원
        final isValid = await _sec.isSessionValid();
        if (isValid) {
          final userJson = prefs.getString(_userKey);
          if (userJson != null) {
            try {
              final map = jsonDecode(userJson);
              if (map is Map<String, dynamic> && map.isNotEmpty) {
                _user = AuthUser.fromJson(map);
                _status = AuthStatus.authenticated;
              }
            } catch (_) {}
          }
        }
        if (_status == AuthStatus.unknown) {
          _status = AuthStatus.unauthenticated;
        }
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

  // ── Email Login (Firebase Auth 실제 처리) ─────────────────
  Future<bool> signInWithEmail(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    // Rate limit check
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

    _initFirebaseAuth();

    // ── Firebase Auth 로그인 시도 ──────────────────────────
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
        if (kDebugMode) debugPrint('[Auth] signInWithEmail error: $e');
        // Firebase 실패 시 로컬 fallback으로 진행
      }
    }

    // ── 로컬 Fallback (Firebase 불가 시) ──────────────────
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

  // ── Email Register (Firebase Auth 실제 처리) ──────────────
  Future<bool> registerWithEmail(String email, String password, String name) async {
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

    _initFirebaseAuth();

    // ── Firebase Auth 회원가입 시도 ────────────────────────
    if (_firebaseAuthAvailable && _fbAuth != null) {
      try {
        final credential = await _fbAuth!.createUserWithEmailAndPassword(
          email: SecurityService.sanitize(email),
          password: password,
        );
        if (credential.user != null) {
          // displayName 업데이트
          final cleanName = SecurityService.sanitize(
            name.trim().isEmpty ? email.split('@').first : name,
          );
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
        if (kDebugMode) debugPrint('[Auth] registerWithEmail error: $e');
        // Firebase 실패 시 로컬 fallback
      }
    }

    // ── 로컬 Fallback ──────────────────────────────────────
    await Future.delayed(const Duration(milliseconds: 800));
    try {
      final cleanName = SecurityService.sanitize(
        name.trim().isEmpty ? email.split('@').first : name,
      );
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

  // ── Social Login (Mock – Firebase 소셜 연동 준비) ─────────
  Future<bool> signInWithGoogle()    => _socialLogin(LoginProvider.google);
  Future<bool> signInWithFacebook()  => _socialLogin(LoginProvider.facebook);
  Future<bool> signInWithWhatsApp()  => _socialLogin(LoginProvider.whatsapp);

  Future<bool> _socialLogin(LoginProvider provider) async {
    _setLoading(true);
    _errorMessage = null;
    await Future.delayed(const Duration(milliseconds: 1200));
    try {
      final mockUser = AuthUser(
        id: const Uuid().v4(),
        email: '${provider.name}.user@example.com',
        displayName: _providerDisplayName(provider),
        provider: provider,
        createdAt: DateTime.now(),
      );
      await _completeLogin(mockUser);
      return true;
    } catch (e) {
      _errorMessage = 'loginFailed';
      _setLoading(false);
      return false;
    }
  }

  String _providerDisplayName(LoginProvider p) {
    switch (p) {
      case LoginProvider.google:   return 'Google User';
      case LoginProvider.facebook: return 'Facebook User';
      case LoginProvider.whatsapp: return 'WhatsApp User';
      case LoginProvider.email:    return 'Email User';
    }
  }

  // ── 로그인 완료 공통 처리 ─────────────────────────────────
  Future<void> _completeLogin(AuthUser user) async {
    _user = user;
    _status = AuthStatus.authenticated;
    await _sec.createSession(user.id);
    // SharedPreferences에도 백업 저장 (Firebase 불가 시 복원용)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    _setLoading(false);
  }

  // ── Sign Out ──────────────────────────────────────────────
  Future<void> signOut() async {
    // Firebase Auth 로그아웃
    if (_firebaseAuthAvailable && _fbAuth != null) {
      try {
        await _fbAuth!.signOut();
      } catch (e) {
        if (kDebugMode) debugPrint('[Auth] signOut Firebase error: $e');
      }
    }
    await _sec.clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    _user   = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// initialize() 타임아웃 시 강제로 unauthenticated 상태로 전환
  void forceUnauthenticated() {
    if (_status == AuthStatus.unknown) {
      _status = AuthStatus.unauthenticated;
      _isLoading = false;
      notifyListeners();
    }
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
    for (final n in _notifications) { n.isRead = true; }
    notifyListeners();
  }

  void markRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) { _notifications[idx].isRead = true; notifyListeners(); }
  }

  void pushNotification({
    required String title,
    required String body,
    required String type,
  }) {
    if (!_notifPrefs.enabled) return;
    if (type == 'task'     && !_notifPrefs.taskUpdate)    return;
    if (type == 'campaign' && !_notifPrefs.campaignAlert)  return;
    if (type == 'budget'   && !_notifPrefs.budgetAlert)    return;
    if (type == 'mention'  && !_notifPrefs.teamMention)    return;
    if (type == 'report'   && !_notifPrefs.weeklyReport)   return;

    addNotification(AppNotification(
      id: const Uuid().v4(),
      title: title, body: body, type: type,
      createdAt: DateTime.now(),
    ));
  }

  void _loadSampleNotifications() {
    final now = DateTime.now();
    _notifications.addAll([
      AppNotification(id: 'n1', title: '캠페인 예산 알림',   body: 'Q2 디지털 캠페인 예산이 80%에 달했습니다',     type: 'budget',   createdAt: now.subtract(const Duration(minutes: 5))),
      AppNotification(id: 'n2', title: '태스크 업데이트',    body: '브랜드 가이드라인 제작이 검토 단계로 이동했습니다', type: 'task',     createdAt: now.subtract(const Duration(hours: 1))),
      AppNotification(id: 'n3', title: '팀 멘션',           body: '홍길동님이 당신을 SNS 광고 전략에서 언급했습니다',  type: 'mention',  createdAt: now.subtract(const Duration(hours: 3))),
      AppNotification(id: 'n4', title: 'KPI 달성 알림',     body: '전환율 KPI가 목표치를 초과했습니다! 🎉',         type: 'campaign', createdAt: now.subtract(const Duration(days: 1))),
    ]);
  }

  // ── Helpers ───────────────────────────────────────────────
  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }
  void clearError()        { _errorMessage = null; notifyListeners(); }
}
