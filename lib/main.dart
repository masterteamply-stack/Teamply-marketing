import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authProvider = AuthProvider();
  await authProvider.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(
          create: (_) => AppProvider()..initSampleData(),
        ),
      ],
      child: const MarketingDashboardApp(),
    ),
  );
}

class MarketingDashboardApp extends StatelessWidget {
  const MarketingDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return MaterialApp(
      title: 'Marketing Dashboard',
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

// ── Router: intro → login → dashboard ────────────────────────
class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Still initializing
    if (auth.status == AuthStatus.unknown) {
      return const _SplashScreen();
    }

    // Not yet seen intro
    if (!auth.introDone) {
      return const IntroPage();
    }

    // Needs login
    if (!auth.isAuthenticated) {
      return const LoginPage();
    }

    // Logged in → main app
    return const _ResponsiveShell();
  }
}

// ── Splash screen ─────────────────────────────────────────────
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
              child: const Icon(Icons.insights_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            const Text('Marketing Dashboard',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 32),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: AppTheme.mintPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Adaptive shell
class _ResponsiveShell extends StatelessWidget {
  const _ResponsiveShell();

  static const double _mobileBreakpoint = 768.0;
  static const double _desktopMinWidth  = 1280.0;
  static const double _desktopMinHeight = 800.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final screenW = constraints.maxWidth  == 0 ? _desktopMinWidth  : constraints.maxWidth;
        final screenH = constraints.maxHeight == 0 ? _desktopMinHeight : constraints.maxHeight;

        if (screenW < _mobileBreakpoint) return const MobileShell();
        if (!kIsWeb) return const DesktopShell();

        if (screenW >= _desktopMinWidth && screenH >= _desktopMinHeight) {
          return const DesktopShell();
        }

        final scaleX = screenW / _desktopMinWidth;
        final scaleY = screenH / _desktopMinHeight;
        final scale  = scaleX < scaleY ? scaleX : scaleY;

        return OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: _desktopMinWidth,
          maxWidth: _desktopMinWidth,
          minHeight: _desktopMinHeight,
          maxHeight: _desktopMinHeight,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: const SizedBox(
              width: _desktopMinWidth,
              height: _desktopMinHeight,
              child: DesktopShell(),
            ),
          ),
        );
      },
    );
  }
}
