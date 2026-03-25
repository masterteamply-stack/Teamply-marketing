import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/marketing_dashboard_provider.dart';
import 'widgets/desktop_shell.dart';
import 'widgets/mobile_shell.dart';
import 'screens/auth/intro_page.dart';
import 'screens/auth/login_page.dart';
import 'screens/settings/client_management_page.dart';
import 'screens/settings/region_management_page.dart';
import 'l10n/app_localizations.dart';

// ─────────────────────────────────────────────────────────────
//  Supabase 설정
//  Project ID : waxjtcxdgulbdofycywr
//  URL        : https://waxjtcxdgulbdofycywr.supabase.co
//  Anon Key   : Supabase Dashboard > Settings > API > anon public
// ─────────────────────────────────────────────────────────────
const _supabaseUrl = 'https://waxjtcxdgulbdofycywr.supabase.co';

const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
    '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndheGp0Y3hkZ3VsYmRvZnljeXdyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMyMjc3NTIsImV4cCI6MjA4ODgwMzc1Mn0'
    '.rvkmwG-dsjeFfT2NAMUJaKjCBMm2SOmAQ1SXl3V3jHI';

Future<void> _safeInitSupabase() async {
  if (_supabaseAnonKey == 'PASTE_YOUR_ANON_KEY_HERE' ||
      _supabaseAnonKey.isEmpty) {
    if (kDebugMode) {
      debugPrint('[Supabase] ⚠️  Anon Key 미설정 → 오프라인 모드로 실행');
      debugPrint('[Supabase] lib/main.dart 의 _supabaseAnonKey 를 설정해주세요');
    }
    return;
  }
  try {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
      debug: kDebugMode,
    );
    if (kDebugMode) debugPrint('[Supabase] ✅ 연결 완료 → $_supabaseUrl');
  } catch (e) {
    if (kDebugMode) debugPrint('[Supabase] init error: $e');
  }
}

// ─────────────────────────────────────────────────────────────
//  Firebase 안전 초기화 (타임아웃 5초, 실패 시 오프라인 모드)
// ─────────────────────────────────────────────────────────────
Future<void> _safeInitFirebase() async {
  try {
    Firebase.app();
    if (kDebugMode) debugPrint('[Firebase] already initialized');
    return;
  } catch (_) {}

  final completer = Completer<void>();
  final timer = Timer(const Duration(seconds: 5), () {
    if (!completer.isCompleted) {
      if (kDebugMode) debugPrint('[Firebase] init timeout → offline mode');
      completer.complete();
    }
  });

  Future<void> doInit() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (kDebugMode) debugPrint('[Firebase] initialized ✅');
    } catch (e) {
      if (kDebugMode) debugPrint('[Firebase] init error: $e');
    } finally {
      timer.cancel();
      if (!completer.isCompleted) completer.complete();
    }
  }

  doInit();
  await completer.future;
}

// ─────────────────────────────────────────────────────────────
//  main
// ─────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Supabase 먼저 초기화 (URL/KEY 있을 때만)
  await _safeInitSupabase();

  // 2) Firebase 초기화 (타임아웃 5초)
  await _safeInitFirebase();

  final authProvider = AuthProvider();
  try {
    await authProvider.initialize().timeout(const Duration(seconds: 6));
  } catch (e) {
    if (kDebugMode) debugPrint('[Auth] initialize timeout: $e');
    authProvider.forceUnauthenticated();
  }
  // Supabase OAuth 콜백 리스너 등록 (Google 로그인 콜백 처리)
  authProvider.listenToAuthStateChanges();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => MarketingDashboardProvider()),
      ],
      child: const TeamplyApp(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  TeamplyApp
// ─────────────────────────────────────────────────────────────
class TeamplyApp extends StatelessWidget {
  const TeamplyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return MaterialApp(
      title: 'Teamply',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: auth.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routes: {
        '/login':            (_) => const LoginPage(),
        '/dashboard':        (_) => const _ResponsiveShell(),
        '/intro':            (_) => const IntroPage(),
        '/settings/clients': (_) => const ClientManagementPage(),
        '/settings/regions': (_) => const RegionManagementPage(),
      },
      home: const _AppRouter(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  _AppRouter
//  흐름: unknown → splash → (introDone?) → login → (data loading) → dashboard
// ─────────────────────────────────────────────────────────────
class _AppRouter extends StatefulWidget {
  const _AppRouter();
  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  String? _loadedUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _handleAuthChange();
  }

  void _handleAuthChange() {
    final auth = context.read<AuthProvider>();
    final app  = context.read<AppProvider>();
    final mkt  = context.read<MarketingDashboardProvider>();

    if (!auth.isAuthenticated) {
      // 로그아웃 시 전체 초기화
      if (_loadedUid != null) {
        _loadedUid = null;
        app.clearUid();
        mkt.clearAll();
      }
      return;
    }

    final uid = auth.user?.id;
    if (uid == null || uid == _loadedUid) return;

    _loadedUid = uid;
    // 마이크로태스크로 처리해 build 중 setState 충돌 방지
    Future.microtask(() async {
      if (!mounted) return;
      // 1) AuthUser 정보를 AppProvider에 반영
      final user = auth.user!;
      app.syncAuthUser(
        uid: user.id,
        name: user.displayName,
        email: user.email,
        avatarUrl: user.avatarUrl,
      );
      // 2) AppProvider 데이터 로드 (팀/프로젝트/KPI/캠페인 등)
      await app.setUidAndLoad(uid);
      if (!mounted) return;
      // 3) MarketingDashboardProvider 데이터 로드
      final teamId = app.selectedTeam?.id ?? uid;
      await mkt.loadTeamData(teamId, uid: uid);
      // 4) 대시보드 자동 이동
      if (!mounted) return;
      if (app.selectedTeam != null) {
        app.navigateTo('dashboard');
        if (kDebugMode) {
          debugPrint('[AppRouter] → dashboard (team: ${app.selectedTeam!.name})');
        }
      }
      // 5) Supabase user_meta 업데이트 (로그인 시각 갱신)
      _updateUserMeta(user.id, user.email, user.displayName);
    });
  }

  void _updateUserMeta(String uid, String email, String displayName) {
    try {
      final db = Supabase.instance.client;
      db.from('user_meta').upsert({
        'uid': uid,
        'email': email,
        'display_name': displayName,
        'last_seen': DateTime.now().toIso8601String(),
      }, onConflict: 'uid').then((_) {
        if (kDebugMode) debugPrint('[AppRouter] user_meta updated ✅');
      }).catchError((e) {
        if (kDebugMode) debugPrint('[AppRouter] user_meta update failed: $e');
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final app  = context.watch<AppProvider>();

    // 1) 초기화 중 → splash
    if (auth.status == AuthStatus.unknown) {
      return const _SplashScreen(message: '');
    }

    // 2) 인트로 미완료 → 인트로
    if (!auth.introDone) return const IntroPage();

    // 3) 미인증 → 로그인
    if (!auth.isAuthenticated) return const LoginPage();

    // 4) 인증됐지만 데이터 아직 로딩 중 → 로딩 스플래시
    if (!app.isDataReady) {
      return _SplashScreen(
        message: '데이터를 불러오는 중...',
        showProgress: true,
        userName: auth.user?.displayName,
      );
    }

    // 5) 모든 준비 완료 → 대시보드
    return const _ResponsiveShell();
  }
}

// ─────────────────────────────────────────────────────────────
//  _SplashScreen
// ─────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  final String message;
  final bool showProgress;
  final String? userName;

  const _SplashScreen({
    this.message = '',
    this.showProgress = true,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 로고
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.mintPrimary, Color(0xFF0097A7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.mintPrimary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Teamply',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            if (userName != null) ...[
              const SizedBox(height: 6),
              Text(
                '${userName!}님, 환영합니다',
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 36),
            if (showProgress)
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.mintPrimary,
                ),
              ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  _ResponsiveShell
// ─────────────────────────────────────────────────────────────
class _ResponsiveShell extends StatelessWidget {
  const _ResponsiveShell();

  static const double _mobileBp    = 768.0;
  static const double _desktopMinW = 1280.0;
  static const double _desktopMinH = 800.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth  == 0 ? _desktopMinW : constraints.maxWidth;
      final h = constraints.maxHeight == 0 ? _desktopMinH : constraints.maxHeight;

      if (w < _mobileBp)                          return const MobileShell();
      if (!kIsWeb)                                return const DesktopShell();
      if (w >= _desktopMinW && h >= _desktopMinH) return const DesktopShell();

      final scale = (w / _desktopMinW) < (h / _desktopMinH)
          ? w / _desktopMinW
          : h / _desktopMinH;

      return OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: _desktopMinW, maxWidth: _desktopMinW,
        minHeight: _desktopMinH, maxHeight: _desktopMinH,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topLeft,
          child: const SizedBox(
            width: _desktopMinW,
            height: _desktopMinH,
            child: DesktopShell(),
          ),
        ),
      );
    });
  }
}
