// ════════════════════════════════════════════════════════════════
//  AdService  –  App Open Ad (앱 열기 광고) 관리
//
//  사용 흐름:
//    1. main()에서 AdService.instance.initialize() 호출
//    2. 앱이 포그라운드로 전환될 때마다 자동으로 광고 표시
//    3. 테스트 환경: 테스트 광고 ID 사용
//    4. 실제 배포 전: _appOpenAdUnitId 를 실제 AdMob ID로 교체
// ════════════════════════════════════════════════════════════════
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ── Ad Unit ID ───────────────────────────────────────────────
  // ⚠️  실제 배포 전에 아래 테스트 ID를 실제 AdMob App Open Ad Unit ID로 교체하세요.
  // Android 테스트 ID: ca-app-pub-3940256099942544/9257395921
  // iOS     테스트 ID: ca-app-pub-3940256099942544/5575463023
  static String get _adUnitId {
    if (kDebugMode) {
      // 테스트 광고 ID (개발/테스트용)
      if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/9257395921';
      if (Platform.isIOS)     return 'ca-app-pub-3940256099942544/5575463023';
    }
    // 🔑 실제 Ad Unit ID로 교체 (배포 시 아래 값을 실제 ID로 변경)
    if (Platform.isAndroid) return 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
    if (Platform.isIOS)     return 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
    return '';
  }

  AppOpenAd?  _appOpenAd;
  bool        _isAdLoading     = false;
  bool        _isAdShowing     = false;
  DateTime?   _adLoadTime;

  // 광고 유효 시간 (4시간 이후 로드된 광고는 폐기)
  static const Duration _adExpiry = Duration(hours: 4);

  // ── 초기화 ───────────────────────────────────────────────────
  Future<void> initialize() async {
    if (kIsWeb) return; // 웹 플랫폼은 미지원
    await MobileAds.instance.initialize();
    _loadAd();
  }

  // ── 광고 로드 ────────────────────────────────────────────────
  void _loadAd() {
    if (kIsWeb) return;
    if (_isAdLoading || _adUnitId.isEmpty) return;
    _isAdLoading = true;

    AppOpenAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd  = ad;
          _adLoadTime = DateTime.now();
          _isAdLoading = false;
          if (kDebugMode) debugPrint('[AdService] App Open Ad loaded ✅');
        },
        onAdFailedToLoad: (error) {
          _isAdLoading = false;
          if (kDebugMode) debugPrint('[AdService] Failed to load: $error');
          // 실패 시 1분 후 재시도
          Future.delayed(const Duration(minutes: 1), _loadAd);
        },
      ),
    );
  }

  // ── 광고 유효성 검사 ─────────────────────────────────────────
  bool get _isAdAvailable {
    if (_appOpenAd == null) return false;
    if (_adLoadTime == null) return false;
    return DateTime.now().difference(_adLoadTime!) < _adExpiry;
  }

  // ── 광고 표시 ────────────────────────────────────────────────
  Future<void> showAdIfAvailable() async {
    if (kIsWeb) return;
    if (_isAdShowing) return;
    if (!_isAdAvailable) {
      if (kDebugMode) debugPrint('[AdService] Ad not available, loading new one...');
      _loadAd();
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isAdShowing = true;
        if (kDebugMode) debugPrint('[AdService] Ad showed ✅');
      },
      onAdDismissedFullScreenContent: (ad) {
        _isAdShowing = false;
        ad.dispose();
        _appOpenAd = null;
        if (kDebugMode) debugPrint('[AdService] Ad dismissed, loading next...');
        _loadAd(); // 다음 광고 미리 로드
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isAdShowing = false;
        ad.dispose();
        _appOpenAd = null;
        if (kDebugMode) debugPrint('[AdService] Failed to show: $error');
        _loadAd();
      },
    );

    await _appOpenAd!.show();
  }

  // ── 리소스 해제 ──────────────────────────────────────────────
  void dispose() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
  }
}
