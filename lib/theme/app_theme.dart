import 'package:flutter/material.dart';

class AppTheme {
  // ── Mint Color Palette ─────────────────────────────────
  static const Color mintPrimary  = Color(0xFF00C9A7);   // 채도↑ 민트
  static const Color mintLight    = Color(0xFF5DEDD6);
  static const Color mintDark     = Color(0xFF00A085);
  static const Color mintAccent   = Color(0xFF1DFFC8);
  static const Color mintSurface  = Color(0xFFE0FAF4);

  // ── Background (다크 네이비 계열, 명도 상향) ────────────
  // 이전: 0x0D1B2A → 0x1A2B3C → 0x243447
  // 개선: 더 밝고 채도 있는 슬레이트 계열로 가시성 확보
  static const Color bgDark       = Color(0xFF141F2E);   // 메인 배경 (살짝 밝아짐)
  static const Color bgCard       = Color(0xFF1C2D40);   // 카드 배경
  static const Color bgCardLight  = Color(0xFF253A50);   // 카드 밝은 배경
  static const Color bgSurface    = Color(0xFF2D4560);   // 서피스 / 입력창 배경

  // ── Text Colors (명도·채도 상향 → 가시성 개선) ─────────
  // 이전: E8F5F3(주) / 90A4AE(보조) / 546E7A(뮤트)
  // 개선: 흰색에 가깝게 주텍스트, 보조도 충분한 명도 확보
  static const Color textPrimary   = Color(0xFFF0F8FF);  // 거의 흰색, 눈부심 없음
  static const Color textSecondary = Color(0xFFB0C8D8);  // 밝은 청회색
  static const Color textMuted     = Color(0xFF7A99B0);  // 충분히 읽히는 뮤트
  static const Color textDisabled  = Color(0xFF4A6070);

  // ── Semantic Colors ───────────────────────────────────
  static const Color success = Color(0xFF2ECC8A);   // 밝은 녹색
  static const Color warning = Color(0xFFFFC93C);   // 노란 주황 (명도↑)
  static const Color error   = Color(0xFFFF6B6B);   // 부드러운 빨강
  static const Color info    = Color(0xFF4DB8FF);   // 밝은 파랑

  // ── Accent Colors ─────────────────────────────────────
  static const Color accentGreen  = Color(0xFF2ECC8A);
  static const Color accentBlue   = Color(0xFF4DB8FF);
  static const Color accentRed    = Color(0xFFFF6B6B);
  static const Color accentOrange = Color(0xFFFF8C5A);
  static const Color accentPurple = Color(0xFFBD7FEB);
  static const Color accentYellow = Color(0xFFFFC93C);

  // ── UI Borders ────────────────────────────────────────
  // 이전: 0x1E3040 (너무 어두워 카드 경계 안 보임)
  // 개선: 약간 밝혀서 카드/섹션 구분 명확화
  static const Color border      = Color(0xFF2A4060);   // 기본 테두리
  static const Color borderLight = Color(0xFF3A5570);   // 강조 테두리

  // alias
  static const Color cardBg = bgCard;

  // ── Chart Colors ─────────────────────────────────────
  static const List<Color> chartColors = [
    Color(0xFF00C9A7),
    Color(0xFF4DB8FF),
    Color(0xFFBD7FEB),
    Color(0xFFFF8C5A),
    Color(0xFFFFC93C),
    Color(0xFF6EE79C),
  ];

  // ── ThemeData ─────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary:    mintPrimary,
        secondary:  mintAccent,
        surface:    bgCard,
        onPrimary:  Colors.white,
        onSecondary: Colors.white,
        onSurface:  textPrimary,
      ),
      scaffoldBackgroundColor: bgDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: mintPrimary),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgCard,
        indicatorColor: mintPrimary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
                color: mintPrimary, fontSize: 11, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: textSecondary, fontSize: 11);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: mintPrimary, size: 24);
          }
          return const IconThemeData(color: textSecondary, size: 22);
        }),
      ),
      textTheme: const TextTheme(
        displayLarge:  TextStyle(color: textPrimary,   fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        displayMedium: TextStyle(color: textPrimary,   fontSize: 24, fontWeight: FontWeight.w600),
        displaySmall:  TextStyle(color: textPrimary,   fontSize: 20, fontWeight: FontWeight.w600),
        bodyLarge:     TextStyle(color: textPrimary,   fontSize: 16, height: 1.6),
        bodyMedium:    TextStyle(color: textSecondary, fontSize: 14, height: 1.5),
        bodySmall:     TextStyle(color: textMuted,     fontSize: 12, height: 1.4),
        labelLarge:    TextStyle(color: mintPrimary,   fontSize: 14, fontWeight: FontWeight.w600),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bgCardLight,
        labelStyle: const TextStyle(color: textSecondary, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: border),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mintPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textSecondary,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: mintPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: mintPrimary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: textDisabled, fontSize: 13),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: bgSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
        titleTextStyle: const TextStyle(
            color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        textColor: textPrimary,
        iconColor: textSecondary,
        subtitleTextStyle: TextStyle(color: textMuted, fontSize: 12),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: bgSurface,
          borderRadius: BorderRadius.circular(6),
          border: const Border.fromBorderSide(BorderSide(color: border)),
        ),
        textStyle: const TextStyle(color: textPrimary, fontSize: 12),
      ),
    );
  }
}
