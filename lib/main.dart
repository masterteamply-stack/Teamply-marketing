import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'widgets/desktop_shell.dart';
import 'widgets/mobile_shell.dart';
import 'screens/auth/intro_page.dart';
import 'screens/auth/login_page.dart';
import 'screens/settings/client_management_page.dart';
import 'screens/settings/region_management_page.dart';
import 'l10n/app_localizations.dart';

// ─────────────────────────────────────────────────────────────
//  Firebase 안전 초기화
//  - PlatformException(channel-error) 차단
//  - 타임아웃(3초) 적용
//  - 실패 시 앱은 로컬 모드로 계속 동작
// ─────────────────────────────────────────────────────────────
Future<void> _safeInitFirebase() async {
  // 이미 초기화됐는지 확인
  try {
    Firebase.app(); // throws if not initialized
    if (kDebugMode) debugPrint('[Firebase] already initialized');
    return;
  } catch (_) {
    // 아직 초기화되지 않음 → 계속 진행
  }

  final completer = Completer<void>();

  // 타임아웃 타이머 (3초)
  final timer = Timer(const Duration(seconds: 3), () {
    if (!completer.isCompleted) {
      if (kDebugMode) debugPrint('[Firebase] init timeout → offline mode');
      completer.complete();
    }
  });

  // Firebase 초기화 시도
  Future(() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (kDebugMode) debugPrint('[Firebase] initialized ✅');
    } catch (e) {
      if (kDebugMode) debugPrint('[Firebase] init error: $e → offline mode');
    } finally {
      timer.cancel();
      if (!completer.isCompleted) completer.complete();
    }
  });

  await completer.future;
}

// ─────────────────────────────────────────────────────────────
//  main
// ─────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Firebase 초기화 (실패 허용)
  await _safeInitFirebase();

  // 2) Auth 초기화 (5초 타임아웃)
  final authProvider = AuthProvider();
  try {
    await authProvider.initialize().timeout(const Duration(seconds: 5));
  } catch (e) {
    if (kDebugMode) debugPrint('[Auth] initialize timeout: $e');
    // 타임아웃 시 unauthenticated 상태로 강제 전환
    authProvider.forceUnauthenticated();
  }

  // 3) 앱 실행
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(
          create: (_) => AppProvider()..initSampleData(),
        ),
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
//  _AppRouter — 인증 상태 기반 라우터
//  세션 복원 시 setUidAndLoad 자동 호출
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
    _syncUid();
  }

  void _syncUid() {
    final auth = context.read<AuthProvider>();

    if (!auth.isAuthenticated) {
      if (_loadedUid != null) {
        _loadedUid = null;
        context.read<AppProvider>().clearUid();
      }
      return;
    }

    final uid = auth.user?.id;
    if (uid == null || uid == _loadedUid) return;

    _loadedUid = uid;
    Future.microtask(() {
      if (mounted) {
        context.read<AppProvider>().setUidAndLoad(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.status == AuthStatus.unknown) return const _SplashScreen();
    if (!auth.introDone)                    return const IntroPage();
    if (!auth.isAuthenticated)              return const LoginPage();
    return const _ResponsiveShell();
  }
}

// ─────────────────────────────────────────────────────────────
//  _SplashScreen
// ─────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.mintPrimary, Color(0xFF0097A7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Teamply',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.mintPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  _ResponsiveShell — Mobile / Desktop 분기
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
