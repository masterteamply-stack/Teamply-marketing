// ════════════════════════════════════════════════════════════
//  AuthProvider – 로그인 상태, 소셜/이메일 인증, 알림 설정
// ════════════════════════════════════════════════════════════
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../services/security_service.dart';

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
    id: j['id'],
    email: j['email'],
    displayName: j['displayName'],
    provider: LoginProvider.values.firstWhere((p) => p.name == j['provider'],
        orElse: () => LoginProvider.email),
    avatarUrl: j['avatarUrl'],
    createdAt: DateTime.parse(j['createdAt']),
  );
}

class NotificationPrefs {
  bool enabled;
  bool taskUpdate;
  bool campaignAlert;
  bool budgetAlert;
  bool teamMention;
  bool weeklyReport;

  NotificationPrefs({
    this.enabled     = true,
    this.taskUpdate  = true,
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

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) => NotificationPrefs(
    enabled:       j['enabled']       ?? true,
    taskUpdate:    j['taskUpdate']     ?? true,
    campaignAlert: j['campaignAlert']  ?? true,
    budgetAlert:   j['budgetAlert']    ?? true,
    teamMention:   j['teamMention']    ?? true,
    weeklyReport:  j['weeklyReport']   ?? false,
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
  static const _userKey      = 'auth_user';
  static const _privacyKey   = 'privacy_agreed';
  static const _localeKey    = 'app_locale';
  static const _notifKey     = 'notif_prefs';
  static const _introKey     = 'intro_done';

  final SecurityService _sec = SecurityService();

  AuthStatus _status = AuthStatus.unknown;
  AuthUser?  _user;
  bool       _privacyAgreed = false;
  bool       _introDone     = false;
  Locale     _locale        = const Locale('ko');
  NotificationPrefs _notifPrefs = NotificationPrefs();
  bool       _isLoading     = false;
  String?    _errorMessage;
  final List<AppNotification> _notifications = [];

  // Getters
  AuthStatus get status       => _status;
  AuthUser?  get user         => _user;
  bool   get isAuthenticated  => _status == AuthStatus.authenticated;
  bool   get privacyAgreed    => _privacyAgreed;
  bool   get introDone        => _introDone;
  Locale get locale           => _locale;
  NotificationPrefs get notifPrefs => _notifPrefs;
  bool   get isLoading        => _isLoading;
  String? get errorMessage    => _errorMessage;
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int    get unreadCount      => _notifications.where((n) => !n.isRead).length;

  // ── Initialization ───────────────────────────────────────
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
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
          // notifJson is unused in web mock – skip
        } catch (_) {}
      }
      // Restore session
      final isValid = await _sec.isSessionValid();
      if (isValid) {
        final userJson = prefs.getString(_userKey);
        if (userJson != null) {
          try {
            final map = _decodeJson(userJson);
            if (map != null) {
              _user = AuthUser.fromJson(map);
              _status = AuthStatus.authenticated;
            }
          } catch (_) {}
        }
      }
      if (_status == AuthStatus.unknown) {
        _status = AuthStatus.unauthenticated;
      }
      // Load sample notifications
      _loadSampleNotifications();
    } catch (e) {
      _status = AuthStatus.unauthenticated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Social Login (Mock) ──────────────────────────────────
  Future<bool> signInWithGoogle() => _socialLogin(LoginProvider.google);
  Future<bool> signInWithFacebook() => _socialLogin(LoginProvider.facebook);
  Future<bool> signInWithWhatsApp() => _socialLogin(LoginProvider.whatsapp);

  Future<bool> _socialLogin(LoginProvider provider) async {
    _setLoading(true);
    _errorMessage = null;
    await Future.delayed(const Duration(milliseconds: 1200)); // simulate OAuth
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

  // ── Email Login ──────────────────────────────────────────
  Future<bool> signInWithEmail(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    // Check account lock
    if (await _sec.isAccountLocked()) {
      final remaining = await _sec.lockRemainingTime();
      final mins = remaining?.inMinutes ?? 15;
      _errorMessage = 'Account locked. Try again in $mins minutes.';
      _setLoading(false);
      return false;
    }

    // Validate inputs
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

    await Future.delayed(const Duration(milliseconds: 800)); // simulate API

    // Mock: accept any valid-format credentials
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

  // ── Register ─────────────────────────────────────────────
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

    await Future.delayed(const Duration(milliseconds: 1000));
    try {
      final user = AuthUser(
        id: const Uuid().v4(),
        email: SecurityService.sanitize(email),
        displayName: SecurityService.sanitize(name.isEmpty ? email.split('@').first : name),
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

  Future<void> _completeLogin(AuthUser user) async {
    _user = user;
    _status = AuthStatus.authenticated;
    await _sec.createSession(user.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, _encodeJson(user.toJson()));
    _setLoading(false);
  }

  // ── Sign Out ─────────────────────────────────────────────
  Future<void> signOut() async {
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

  // ── Privacy Agreement ────────────────────────────────────
  Future<void> agreeToPrivacy() async {
    _privacyAgreed = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyKey, true);
    notifyListeners();
  }

  // ── Intro Done ───────────────────────────────────────────
  Future<void> completeIntro() async {
    _introDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introKey, true);
    notifyListeners();
  }

  // ── Locale ───────────────────────────────────────────────
  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
    notifyListeners();
  }

  // ── Notification Prefs ───────────────────────────────────
  Future<void> updateNotifPrefs(NotificationPrefs prefs) async {
    _notifPrefs = prefs;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_notifKey, _encodeJson(prefs.toJson()));
    notifyListeners();
  }

  // ── In-App Notifications ─────────────────────────────────
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

  // Push-like notification trigger
  void pushNotification({
    required String title,
    required String body,
    required String type,
  }) {
    if (!_notifPrefs.enabled) return;
    // Filter by type
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
      AppNotification(id: 'n1', title: '캠페인 예산 알림', body: 'Q2 디지털 캠페인 예산이 80%에 달했습니다', type: 'budget', createdAt: now.subtract(const Duration(minutes: 5))),
      AppNotification(id: 'n2', title: '태스크 업데이트', body: '브랜드 가이드라인 제작이 검토 단계로 이동했습니다', type: 'task', createdAt: now.subtract(const Duration(hours: 1))),
      AppNotification(id: 'n3', title: '팀 멘션', body: '홍길동님이 당신을 SNS 광고 전략에서 언급했습니다', type: 'mention', createdAt: now.subtract(const Duration(hours: 3))),
      AppNotification(id: 'n4', title: 'KPI 달성 알림', body: '전환율 KPI가 목표치를 초과했습니다! 🎉', type: 'campaign', createdAt: now.subtract(const Duration(days: 1))),
    ]);
  }

  // ── Helpers ──────────────────────────────────────────────
  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }
  void clearError() { _errorMessage = null; notifyListeners(); }

  String _encodeJson(Map<String, dynamic> map) {
    // simple JSON encoding without dart:convert import conflict
    final buf = StringBuffer('{');
    var first = true;
    map.forEach((k, v) {
      if (!first) buf.write(',');
      buf.write('"$k":');
      if (v == null) buf.write('null');
      else if (v is bool) buf.write(v.toString());
      else if (v is num) buf.write(v.toString());
      else buf.write('"${v.toString().replaceAll('"', '\\"')}"');
      first = false;
    });
    buf.write('}');
    return buf.toString();
  }

  Map<String, dynamic>? _decodeJson(String s) {
    try {
      // Use dart:convert through a workaround
      final result = <String, dynamic>{};
      // Simple key-value extraction for known fields
      final patterns = {
        'id': RegExp(r'"id":"([^"]*)"'),
        'email': RegExp(r'"email":"([^"]*)"'),
        'displayName': RegExp(r'"displayName":"([^"]*)"'),
        'provider': RegExp(r'"provider":"([^"]*)"'),
        'avatarUrl': RegExp(r'"avatarUrl":"([^"]*)"'),
        'createdAt': RegExp(r'"createdAt":"([^"]*)"'),
      };
      for (final entry in patterns.entries) {
        final match = entry.value.firstMatch(s);
        if (match != null) result[entry.key] = match.group(1);
      }
      return result.isEmpty ? null : result;
    } catch (_) { return null; }
  }
}
