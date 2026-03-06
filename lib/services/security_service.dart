// ════════════════════════════════════════════════════════════
//  Security Service – JWT-mock, session, rate-limit, encryption
// ════════════════════════════════════════════════════════════
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SecurityService {
  static const _sessionKey   = 'session_token';
  static const _sessionExp   = 'session_expiry';
  static const _loginAttemptKey = 'login_attempts';
  static const _lockUntilKey    = 'lock_until';
  static const int _maxAttempts  = 5;
  static const int _lockMinutes  = 15;
  static const int _sessionHours = 8; // session expires after 8h

  static final SecurityService _instance = SecurityService._();
  factory SecurityService() => _instance;
  SecurityService._();

  // ── Session ──────────────────────────────────────────────
  Future<String> createSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = _generateToken(userId);
    final expiry = DateTime.now().add(const Duration(hours: _sessionHours));
    await prefs.setString(_sessionKey, token);
    await prefs.setString(_sessionExp, expiry.toIso8601String());
    return token;
  }

  Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final token  = prefs.getString(_sessionKey);
    final expStr = prefs.getString(_sessionExp);
    if (token == null || expStr == null) return false;
    try {
      final expiry = DateTime.parse(expStr);
      return DateTime.now().isBefore(expiry);
    } catch (_) { return false; }
  }

  Future<String?> getSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionKey);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_sessionExp);
  }

  Future<void> extendSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_sessionKey);
    if (token == null) return;
    final expiry = DateTime.now().add(const Duration(hours: _sessionHours));
    await prefs.setString(_sessionExp, expiry.toIso8601String());
  }

  // ── Rate Limiting (brute-force protection) ───────────────
  Future<bool> isAccountLocked() async {
    final prefs = await SharedPreferences.getInstance();
    final lockUntilStr = prefs.getString(_lockUntilKey);
    if (lockUntilStr == null) return false;
    try {
      final lockUntil = DateTime.parse(lockUntilStr);
      if (DateTime.now().isBefore(lockUntil)) return true;
      // Lock expired – clear
      await prefs.remove(_lockUntilKey);
      await prefs.setInt(_loginAttemptKey, 0);
      return false;
    } catch (_) { return false; }
  }

  Future<Duration?> lockRemainingTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lockUntilStr = prefs.getString(_lockUntilKey);
    if (lockUntilStr == null) return null;
    try {
      final lockUntil = DateTime.parse(lockUntilStr);
      final remaining = lockUntil.difference(DateTime.now());
      return remaining.isNegative ? null : remaining;
    } catch (_) { return null; }
  }

  Future<void> recordLoginFailure() async {
    final prefs = await SharedPreferences.getInstance();
    int attempts = (prefs.getInt(_loginAttemptKey) ?? 0) + 1;
    await prefs.setInt(_loginAttemptKey, attempts);
    if (attempts >= _maxAttempts) {
      final lockUntil = DateTime.now().add(Duration(minutes: _lockMinutes));
      await prefs.setString(_lockUntilKey, lockUntil.toIso8601String());
    }
  }

  Future<void> recordLoginSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_loginAttemptKey, 0);
    await prefs.remove(_lockUntilKey);
  }

  Future<int> getRemainingAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = prefs.getInt(_loginAttemptKey) ?? 0;
    return (_maxAttempts - attempts).clamp(0, _maxAttempts);
  }

  // ── Password Hashing ─────────────────────────────────────
  String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$password:$salt');
    return sha256.convert(bytes).toString();
  }

  String generateSalt() => const Uuid().v4();

  bool verifyPassword(String password, String salt, String hash) {
    return hashPassword(password, salt) == hash;
  }

  // ── Token Generation ─────────────────────────────────────
  String _generateToken(String userId) {
    final header  = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
    final payload = base64Url.encode(utf8.encode(jsonEncode({
      'sub': userId,
      'iat': DateTime.now().millisecondsSinceEpoch,
      'exp': DateTime.now().add(const Duration(hours: _sessionHours)).millisecondsSinceEpoch,
      'jti': const Uuid().v4(),
    })));
    final secret = 'mkt_dashboard_secret_${DateTime.now().day}';
    final sig    = sha256.convert(utf8.encode('$header.$payload:$secret')).toString();
    final sigB64 = base64Url.encode(utf8.encode(sig));
    return '$header.$payload.$sigB64';
  }

  // ── Input Validation (XSS prevention) ───────────────────
  static String sanitize(String input) {
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
  }

  static bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  static bool isStrongPassword(String pw) {
    return pw.length >= 8;
  }

  static String? validatePassword(String pw) {
    if (pw.length < 8) return 'passwordMinLength';
    return null;
  }
}
