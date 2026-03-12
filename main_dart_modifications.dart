// lib/main.dart - 수정 사항 요약

/*
기존 main.dart 코드를 아래 부분만 수정하면 됩니다:

1️⃣ Import 추가 (최상단)
────────────────────────────────────────────────────
*/

// 기존 imports...
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/team_provider.dart';        // ⭐ 추가
import 'config/hive_config.dart';             // ⭐ 추가
import 'widgets/desktop_shell.dart';
import 'widgets/mobile_shell.dart';
// ... 나머지 imports ...

/*
2️⃣ main() 함수 수정
────────────────────────────────────────────────────
기존 코드:
  await _safeInitFirebase();
  
수정:
*/

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⭐ Hive 초기화 추가 (Firebase 전에)
  await HiveConfig.initialize();

  await _safeInitFirebase();

  final authProvider = AuthProvider();
  try {
    await authProvider.initialize().timeout(const Duration(seconds: 6));
  } catch (e) {
    if (kDebugMode) debugPrint('[Auth] initialize timeout: $e');
    authProvider.forceUnauthenticated();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => AppProvider()),
        // ⭐ TeamProvider 추가
        ChangeNotifierProvider(
          create: (_) => TeamProvider(FirebaseFirestore.instance),
        ),
      ],
      child: const TeamplyApp(),
    ),
  );
}

/*
3️⃣ 네비게이션에 팀 관리 페이지 추가
────────────────────────────────────────────────────
기존 routes 맵에 추가:
*/

routes: {
  '/login':              (_) => const LoginPage(),
  '/dashboard':          (_) => const _ResponsiveShell(),
  '/intro':              (_) => const IntroPage(),
  '/settings/clients':   (_) => const ClientManagementPage(),
  '/settings/regions':   (_) => const RegionManagementPage(),
  '/team/management':    (_) => const TeamManagementPage(),    // ⭐ 추가
  '/team/tasks':         (_) => const TaskManagementPage(),    // ⭐ 추가
},

/*
4️⃣ _AppRouter에 TeamProvider 초기화 로직 추가
────────────────────────────────────────────────────
_AppRouterState의 _handleAuthChange() 메서드에:
*/

void _handleAuthChange() {
  final auth = context.read<AuthProvider>();
  final app  = context.read<AppProvider>();
  final team = context.read<TeamProvider>();  // ⭐ 추가

  if (!auth.isAuthenticated) {
    if (_loadedUid != null) {
      _loadedUid = null;
      app.clearUid();
      team.cleanup();  // ⭐ 추가
    }
    return;
  }

  final uid = auth.user?.id;
  if (uid == null || uid == _loadedUid) return;

  _loadedUid = uid;
  Future.microtask(() async {
    if (!mounted) return;
    final user = auth.user!;
    app.syncAuthUser(
      uid: user.id,
      name: user.displayName,
      email: user.email,
      avatarUrl: user.avatarUrl,
    );
    await app.setUidAndLoad(uid);
    
    // ⭐ TeamProvider 초기화 추가
    if (app.selectedTeam != null) {
      team.initializeTeam(app.selectedTeam!.id);
    }
    
    if (!mounted) return;
    if (app.selectedTeam != null) {
      app.navigateTo('dashboard');
      if (kDebugMode) {
        debugPrint('[AppRouter] Auto-navigated to dashboard for team: ${app.selectedTeam!.name}');
      }
    }
  });
}

/*
5️⃣ desktop_shell.dart 또는 모바일 쉘에 네비게이션 추가
────────────────────────────────────────────────────
사이드바 또는 메뉴에 팀 관리 링크 추가:

ListTile(
  leading: const Icon(Icons.group),
  title: const Text('팀 관리'),
  onTap: () {
    Navigator.pushNamed(context, '/team/management');
  },
),
*/

// ──────────────────────────────────────────────────
// 완료! 이제 pubspec.yaml 의존성 추가:
// ──────────────────────────────────────────────────

/*
pubspec.yaml에 이미 있는 항목:
✅ hive: 2.2.3
✅ hive_flutter: 1.1.0
✅ provider: 6.1.5+1
✅ cloud_firestore: 5.4.3
✅ uuid: ^4.5.1

추가로 필요한 항목 (dev_dependencies에 이미 있으면 OK):
✅ hive_generator: 2.0.1
✅ build_runner: 2.4.13

만약 없다면:
dev_dependencies:
  hive_generator: 2.0.1
  build_runner: 2.4.13
*/

// ──────────────────────────────────────────────────
// Hive 어댑터 생성 명령어:
// ──────────────────────────────────────────────────

/*
터미널에서 실행:
flutter pub run build_runner build

또는 watch 모드:
flutter pub run build_runner watch

이 명령어가 team_member.g.dart 파일을 자동 생성합니다.
*/
