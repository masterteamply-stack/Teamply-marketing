import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';

// ═══════════════════════════════════════════════════════════════
//  IntroPage — 모션그래픽 인트로 (단일 페이지, 풀스크린 애니메이션)
// ═══════════════════════════════════════════════════════════════
class IntroPage extends StatefulWidget {
  const IntroPage({super.key});
  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> with TickerProviderStateMixin {
  // ── 메인 컨트롤러들 ──────────────────────────────────────────
  late final AnimationController _bgCtrl;     // 배경 그라디언트 회전
  late final AnimationController _logoCtrl;   // 로고 등장
  late final AnimationController _titleCtrl;  // 타이틀 페이드업
  late final AnimationController _particleCtrl; // 파티클 루프
  late final AnimationController _pulseCtrl;  // 로고 펄스
  late final AnimationController _iconsCtrl;  // 아이콘 오비탈

  // ── 애니메이션 값 ────────────────────────────────────────────
  late final Animation<double> _bgRotation;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _btnOpacity;
  late final Animation<double> _pulse;
  late final Animation<double> _iconsRotation;

  // 파티클 데이터
  final List<_Particle> _particles = [];
  final math.Random _rnd = math.Random();

  static const List<Map<String, dynamic>> _featureIcons = [
    {'icon': Icons.analytics_rounded,    'color': Color(0xFF00BFA5), 'label': 'KPI'},
    {'icon': Icons.campaign_rounded,     'color': Color(0xFF7C4DFF), 'label': 'Campaign'},
    {'icon': Icons.groups_rounded,       'color': Color(0xFF00B0FF), 'label': 'Team'},
    {'icon': Icons.trending_up_rounded,  'color': Color(0xFFFF6D00), 'label': 'Growth'},
    {'icon': Icons.task_alt_rounded,     'color': Color(0xFF00E676), 'label': 'Tasks'},
    {'icon': Icons.public_rounded,       'color': Color(0xFFFFD740), 'label': 'Global'},
  ];

  final List<Map<String, String>> _langData = const [
    {'code': 'ko', 'flag': '🇰🇷', 'label': '한국어'},
    {'code': 'en', 'flag': '🇺🇸', 'label': 'English'},
    {'code': 'ja', 'flag': '🇯🇵', 'label': '日本語'},
    {'code': 'zh', 'flag': '🇨🇳', 'label': '中文'},
    {'code': 'es', 'flag': '🇪🇸', 'label': 'Español'},
    {'code': 'ar', 'flag': '🇸🇦', 'label': 'العربية'},
  ];

  @override
  void initState() {
    super.initState();
    _initParticles();
    _setupControllers();
    _startSequence();
  }

  void _initParticles() {
    for (int i = 0; i < 35; i++) {
      _particles.add(_Particle(
        x: _rnd.nextDouble(),
        y: _rnd.nextDouble(),
        size: _rnd.nextDouble() * 4 + 1,
        speed: _rnd.nextDouble() * 0.3 + 0.1,
        opacity: _rnd.nextDouble() * 0.6 + 0.1,
        color: _featureIcons[_rnd.nextInt(_featureIcons.length)]['color'] as Color,
        angle: _rnd.nextDouble() * 2 * math.pi,
      ));
    }
  }

  void _setupControllers() {
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _titleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _iconsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // 배경 그라디언트 회전
    _bgRotation = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(_bgCtrl);

    // 로고 팝 애니메이션
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0)
          .chain(CurveTween(curve: Curves.elasticOut)), weight: 40),
    ]).animate(_logoCtrl);

    _logoOpacity = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.4)));

    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOutCubic));

    _titleOpacity = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _titleCtrl, curve: const Interval(0, 0.6)));

    _subtitleOpacity = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _titleCtrl, curve: const Interval(0.3, 0.9)));

    _btnOpacity = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _titleCtrl, curve: const Interval(0.6, 1.0)));

    _pulse = Tween<double>(begin: 0.92, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _iconsRotation = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(_iconsCtrl);
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _titleCtrl.forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _logoCtrl.dispose();
    _titleCtrl.dispose();
    _particleCtrl.dispose();
    _pulseCtrl.dispose();
    _iconsCtrl.dispose();
    super.dispose();
  }

  void _finish() {
    context.read<AuthProvider>().completeIntro();
    // _AppRouter가 introDone 변화를 감지해 자동으로 LoginPage로 전환
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          // ── 1. 배경 애니메이션 그라디언트 ──────────────────────
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _BackgroundPainter(_bgRotation.value),
            ),
          ),

          // ── 2. 파티클 ───────────────────────────────────────────
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _ParticlePainter(_particles, _particleCtrl.value),
            ),
          ),

          // ── 3. 오비탈 아이콘 ────────────────────────────────────
          AnimatedBuilder(
            animation: _iconsCtrl,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _OrbitalIconsPainter(
                _iconsRotation.value,
                _featureIcons,
                size,
              ),
            ),
          ),

          // ── 4. 메인 콘텐츠 ──────────────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 로고
                AnimatedBuilder(
                  animation: _logoCtrl,
                  builder: (_, __) => Opacity(
                    opacity: _logoOpacity.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, child) => Transform.scale(
                          scale: _pulse.value,
                          child: child,
                        ),
                        child: _LogoWidget(),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 타이틀
                SlideTransition(
                  position: _titleSlide,
                  child: FadeTransition(
                    opacity: _titleOpacity,
                    child: Column(
                      children: [
                        Text(
                          'Teamply',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(
                                color: AppTheme.mintPrimary.withValues(alpha: 0.6),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        FadeTransition(
                          opacity: _subtitleOpacity,
                          child: Text(
                            l10n.appSubtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 피처 칩들
                FadeTransition(
                  opacity: _subtitleOpacity,
                  child: _FeatureChips(icons: _featureIcons),
                ),

                const SizedBox(height: 48),

                // 시작 버튼
                FadeTransition(
                  opacity: _btnOpacity,
                  child: _StartButton(onTap: _finish, l10n: l10n),
                ),
              ],
            ),
          ),

          // ── 5. 상단 - 언어 선택 + 스킵 ─────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _LangButton(
                      auth: auth,
                      langData: _langData,
                    ),
                    FadeTransition(
                      opacity: _btnOpacity,
                      child: TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        child: Text(
                          l10n.skip,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 로고 위젯 ────────────────────────────────────────────────
class _LogoWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00BFA5), Color(0xFF0097A7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.mintPrimary.withValues(alpha: 0.5),
            blurRadius: 30,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: const Color(0xFF0097A7).withValues(alpha: 0.3),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 글로우 링
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
          ),
          const Icon(
            Icons.insights_rounded,
            color: Colors.white,
            size: 48,
          ),
        ],
      ),
    );
  }
}

// ─── 피처 칩 ─────────────────────────────────────────────────
class _FeatureChips extends StatelessWidget {
  final List<Map<String, dynamic>> icons;
  const _FeatureChips({required this.icons});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: icons.map((item) {
        final color = item['color'] as Color;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item['icon'] as IconData, color: color, size: 14),
              const SizedBox(width: 5),
              Text(
                item['label'] as String,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── 시작 버튼 ───────────────────────────────────────────────
class _StartButton extends StatefulWidget {
  final VoidCallback onTap;
  final AppLocalizations l10n;
  const _StartButton({required this.onTap, required this.l10n});

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _pressing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { setState(() => _pressing = true); _ctrl.forward(); },
      onTapUp: (_) { setState(() => _pressing = false); _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () { setState(() => _pressing = false); _ctrl.reverse(); },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          width: 220,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00BFA5), Color(0xFF00ACC1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppTheme.mintPrimary.withValues(alpha: _pressing ? 0.2 : 0.45),
                blurRadius: _pressing ? 10 : 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.l10n.getStarted,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 언어 버튼 ───────────────────────────────────────────────
class _LangButton extends StatelessWidget {
  final AuthProvider auth;
  final List<Map<String, String>> langData;
  const _LangButton({required this.auth, required this.langData});

  @override
  Widget build(BuildContext context) {
    final current = langData.firstWhere(
      (l) => l['code'] == auth.locale.languageCode,
      orElse: () => langData.first,
    );

    return GestureDetector(
      onTap: () => _showSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(current['flag']!, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 5),
            Text(
              current['label']!,
              style: const TextStyle(
                color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.expand_more, color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '언어 선택 / Select Language',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ...langData.map((l) => ListTile(
              leading: Text(l['flag']!, style: const TextStyle(fontSize: 24)),
              title: Text(
                l['label']!,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              ),
              trailing: auth.locale.languageCode == l['code']
                  ? const Icon(Icons.check_circle, color: AppTheme.mintPrimary)
                  : null,
              onTap: () {
                auth.setLocale(Locale(l['code']!));
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  CustomPainter들
// ═══════════════════════════════════════════════════════════════

// ─── 배경 그라디언트 페인터 ───────────────────────────────────
class _BackgroundPainter extends CustomPainter {
  final double rotation;
  _BackgroundPainter(this.rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 어두운 베이스
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0A1628),
    );

    // 회전하는 방사형 글로우들
    final glows = [
      {'color': const Color(0xFF00BFA5), 'x': 0.2, 'y': 0.3, 'r': 0.5},
      {'color': const Color(0xFF7C4DFF), 'x': 0.8, 'y': 0.2, 'r': 0.4},
      {'color': const Color(0xFF00B0FF), 'x': 0.7, 'y': 0.8, 'r': 0.45},
    ];

    for (final g in glows) {
      final ox = math.cos(rotation) * 0.08;
      final oy = math.sin(rotation) * 0.06;
      final gx = ((g['x'] as double) + ox) * size.width;
      final gy = ((g['y'] as double) + oy) * size.height;
      final gr = (g['r'] as double) * size.width;
      final gc = (g['color'] as Color);

      canvas.drawCircle(
        Offset(gx, gy),
        gr,
        Paint()
          ..shader = RadialGradient(
            colors: [
              gc.withValues(alpha: 0.18),
              gc.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: Offset(gx, gy), radius: gr)),
      );
    }

    // 그리드 라인 (매우 연하게)
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;

    const gridSpacing = 60.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => old.rotation != rotation;
}

// ─── 파티클 페인터 ────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  _ParticlePainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final px = (p.x + math.cos(p.angle + progress * 2 * math.pi) * p.speed * 0.15)
          .remainder(1.0)
          .abs() * size.width;
      final py = (p.y + math.sin(p.angle + progress * 2 * math.pi) * p.speed * 0.12)
          .remainder(1.0)
          .abs() * size.height;

      canvas.drawCircle(
        Offset(px, py),
        p.size,
        Paint()..color = p.color.withValues(alpha: p.opacity * (0.5 + 0.5 * math.sin(progress * 2 * math.pi + p.angle))),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

// ─── 오비탈 아이콘 페인터 ─────────────────────────────────────
class _OrbitalIconsPainter extends CustomPainter {
  final double rotation;
  final List<Map<String, dynamic>> icons;
  final Size canvasSize;

  _OrbitalIconsPainter(this.rotation, this.icons, this.canvasSize);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius1 = size.width * 0.32;
    final radius2 = size.width * 0.44;

    // 오비탈 링 그리기
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset(cx, cy), radius1, ringPaint);
    canvas.drawCircle(Offset(cx, cy), radius2, ringPaint);

    // 아이콘 배치
    for (int i = 0; i < icons.length; i++) {
      final item = icons[i];
      final color = item['color'] as Color;
      final isOuter = i % 2 == 0;
      final r = isOuter ? radius2 : radius1;
      final angleOffset = (i * 2 * math.pi / icons.length);
      final angle = rotation + angleOffset + (isOuter ? rotation * 0.3 : -rotation * 0.2);

      final ix = cx + r * math.cos(angle);
      final iy = cy + r * math.sin(angle);

      // 글로우 원
      canvas.drawCircle(
        Offset(ix, iy),
        18,
        Paint()
          ..color = color.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // 아이콘 배경
      canvas.drawCircle(
        Offset(ix, iy),
        14,
        Paint()..color = color.withValues(alpha: 0.22),
      );
      canvas.drawCircle(
        Offset(ix, iy),
        14,
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitalIconsPainter old) => old.rotation != rotation;
}

// ─── 파티클 데이터 클래스 ─────────────────────────────────────
class _Particle {
  double x, y, size, speed, opacity, angle;
  Color color;
  _Particle({
    required this.x, required this.y, required this.size,
    required this.speed, required this.opacity, required this.color,
    required this.angle,
  });
}
