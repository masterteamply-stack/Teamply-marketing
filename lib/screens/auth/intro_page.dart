import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});
  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;

  final _pages = const [
    _IntroData(
      icon: Icons.public_rounded,
      gradient: [Color(0xFF00BFA5), Color(0xFF0097A7)],
      bgIcon: Icons.language,
    ),
    _IntroData(
      icon: Icons.analytics_rounded,
      gradient: [Color(0xFF7C4DFF), Color(0xFF3D5AFE)],
      bgIcon: Icons.bar_chart,
    ),
    _IntroData(
      icon: Icons.currency_exchange_rounded,
      gradient: [Color(0xFFFF6D00), Color(0xFFFF9100)],
      bgIcon: Icons.attach_money,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishIntro();
    }
  }

  void _finishIntro() {
    // completeIntro() 호출만 하면 _AppRouter가 자동으로 LoginPage로 전환
    // Navigator.pushReplacement를 사용하면 라우터 충돌 발생
    context.read<AuthProvider>().completeIntro();
  }

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context);
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          // ── PageView ─────────────────────────────────────
          PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _pages.length,
            itemBuilder: (ctx, i) => _IntroPageView(
              data: _pages[i],
              index: i,
              l10n: l10n,
            ),
          ),
          // ── Top: Skip ────────────────────────────────────
          Positioned(
            top: 48,
            right: 20,
            child: SafeArea(
              child: TextButton(
                onPressed: _finishIntro,
                child: Text(
                  l10n.skip,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          // ── Bottom Controls ───────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  children: [
                    // Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? Colors.white
                              : Colors.white38,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )),
                    ),
                    const SizedBox(height: 32),
                    // Next / Get Started button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _pages[_currentPage].gradient[0],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(
                          isLastPage ? l10n.getStarted : l10n.next,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Language selector ─────────────────────────────
          Positioned(
            top: 48,
            left: 20,
            child: SafeArea(
              child: _LanguagePill(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single intro page ─────────────────────────────────────────
class _IntroPageView extends StatelessWidget {
  final _IntroData data;
  final int index;
  final AppLocalizations l10n;
  const _IntroPageView({required this.data, required this.index, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final titles    = [l10n.introTitle1, l10n.introTitle2, l10n.introTitle3];
    final subtitles = [l10n.introSubtitle1, l10n.introSubtitle2, l10n.introSubtitle3];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [data.gradient[0], data.gradient[1], AppTheme.bgDark],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Background decorative icon
          Positioned(
            right: -40,
            top: -40,
            child: Opacity(
              opacity: 0.07,
              child: Icon(data.bgIcon, size: 280, color: Colors.white),
            ),
          ),
          // Content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // Animated icon circle
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 700),
                builder: (_, v, child) => Transform.scale(
                  scale: v,
                  child: child,
                ),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.white30, width: 2),
                  ),
                  child: Icon(data.icon, size: 56, color: Colors.white),
                ),
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  titles[index],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  subtitles[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Language pill selector ─────────────────────────────────────
class _LanguagePill extends StatelessWidget {
  final _langs = const [
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
    final current = _langs.firstWhere(
      (l) => l['code'] == auth.locale.languageCode,
      orElse: () => _langs[0],
    );

    return GestureDetector(
      onTap: () => _showLangSheet(context, auth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(current['flag']!, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(current['label']!,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }

  void _showLangSheet(BuildContext context, AuthProvider auth) {
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
            const Text('언어 선택 / Select Language',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ..._langs.map((l) => ListTile(
              leading: Text(l['flag']!, style: const TextStyle(fontSize: 24)),
              title: Text(l['label']!,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
              trailing: auth.locale.languageCode == l['code']
                  ? const Icon(Icons.check_circle, color: AppTheme.mintPrimary)
                  : null,
              onTap: () {
                auth.setLocale(Locale(l['code']!));
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }
}

class _IntroData {
  final IconData icon;
  final List<Color> gradient;
  final IconData bgIcon;
  const _IntroData({required this.icon, required this.gradient, required this.bgIcon});
}
