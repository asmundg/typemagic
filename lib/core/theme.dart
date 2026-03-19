import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Color palette for a theme. Each theme provides its own instance.
class ThemeColors {
  // Background layers
  final Color background;
  final Color surface;
  final Color surfaceLight;

  // Text
  final Color textPrimary;
  final Color textMuted;
  final Color textSubtle;

  // Typing feedback
  final Color correct;
  final Color incorrect;
  final Color extra;
  final Color cursor;

  // Accent
  final Color accent;
  final Color accentDim;

  // Stats / charts
  final Color speedLine;
  final Color accuracyLine;

  // Achievement
  final Color gold;
  final Color silver;
  final Color bronze;

  // XP bar
  final Color xpBar;
  final Color xpBarBg;

  final Brightness brightness;

  const ThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.textPrimary,
    required this.textMuted,
    required this.textSubtle,
    required this.correct,
    required this.incorrect,
    required this.extra,
    required this.cursor,
    required this.accent,
    required this.accentDim,
    required this.speedLine,
    required this.accuracyLine,
    required this.gold,
    required this.silver,
    required this.bronze,
    required this.xpBar,
    required this.xpBarBg,
    this.brightness = Brightness.dark,
  });

  static const dark = ThemeColors(
    background: Color(0xFF1a1a2e),
    surface: Color(0xFF16213e),
    surfaceLight: Color(0xFF1f3460),
    textPrimary: Color(0xFFe2e2e2),
    textMuted: Color(0xFF525868),
    textSubtle: Color(0xFF3a3f4b),
    correct: Color(0xFFd1d0c5),
    incorrect: Color(0xFFca4754),
    extra: Color(0xFF7e2a33),
    cursor: Color(0xFFe2b714),
    accent: Color(0xFFe2b714),
    accentDim: Color(0xFF7a6310),
    speedLine: Color(0xFF4ec9b0),
    accuracyLine: Color(0xFFe2b714),
    gold: Color(0xFFffd700),
    silver: Color(0xFFc0c0c0),
    bronze: Color(0xFFcd7f32),
    xpBar: Color(0xFF4ec9b0),
    xpBarBg: Color(0xFF2a2d35),
  );

  static const light = ThemeColors(
    background: Color(0xFFf5f5f5),
    surface: Color(0xFFffffff),
    surfaceLight: Color(0xFFe8e8e8),
    textPrimary: Color(0xFF2c2c2c),
    textMuted: Color(0xFF888888),
    textSubtle: Color(0xFFbababa),
    correct: Color(0xFF3a3a3a),
    incorrect: Color(0xFFca4754),
    extra: Color(0xFFe08080),
    cursor: Color(0xFFd4a017),
    accent: Color(0xFFd4a017),
    accentDim: Color(0xFFb8941a),
    speedLine: Color(0xFF2ea08e),
    accuracyLine: Color(0xFFd4a017),
    gold: Color(0xFFd4a200),
    silver: Color(0xFF909090),
    bronze: Color(0xFFb06828),
    xpBar: Color(0xFF2ea08e),
    xpBarBg: Color(0xFFd5d5d5),
    brightness: Brightness.light,
  );

  static const northernLights = ThemeColors(
    background: Color(0xFF0a1628),
    surface: Color(0xFF0f1f38),
    surfaceLight: Color(0xFF162a4a),
    textPrimary: Color(0xFFd8e8e8),
    textMuted: Color(0xFF4a6070),
    textSubtle: Color(0xFF2a3a4a),
    correct: Color(0xFFc8e0d0),
    incorrect: Color(0xFFe05070),
    extra: Color(0xFF8a2040),
    cursor: Color(0xFF00d4aa),
    accent: Color(0xFF00d4aa),
    accentDim: Color(0xFF007a66),
    speedLine: Color(0xFF00d4aa),
    accuracyLine: Color(0xFF7c3aed),
    gold: Color(0xFFffd700),
    silver: Color(0xFFc0c0c0),
    bronze: Color(0xFFcd7f32),
    xpBar: Color(0xFF7c3aed),
    xpBarBg: Color(0xFF1a2440),
  );

  static const fjordBlue = ThemeColors(
    background: Color(0xFF0c1929),
    surface: Color(0xFF102238),
    surfaceLight: Color(0xFF183050),
    textPrimary: Color(0xFFd0e0f0),
    textMuted: Color(0xFF506880),
    textSubtle: Color(0xFF2a3a50),
    correct: Color(0xFFb8d0e8),
    incorrect: Color(0xFFe06060),
    extra: Color(0xFF903030),
    cursor: Color(0xFF4a9eff),
    accent: Color(0xFF4a9eff),
    accentDim: Color(0xFF2a6ab8),
    speedLine: Color(0xFF87ceeb),
    accuracyLine: Color(0xFF4a9eff),
    gold: Color(0xFFffd700),
    silver: Color(0xFFc0c0c0),
    bronze: Color(0xFFcd7f32),
    xpBar: Color(0xFF87ceeb),
    xpBarBg: Color(0xFF162030),
  );

  static const vikingGold = ThemeColors(
    background: Color(0xFF1a1408),
    surface: Color(0xFF241c0e),
    surfaceLight: Color(0xFF302618),
    textPrimary: Color(0xFFe8dcc8),
    textMuted: Color(0xFF7a6840),
    textSubtle: Color(0xFF4a3e28),
    correct: Color(0xFFd8ccb0),
    incorrect: Color(0xFFc85040),
    extra: Color(0xFF882828),
    cursor: Color(0xFFc8a654),
    accent: Color(0xFFc8a654),
    accentDim: Color(0xFF8a7238),
    speedLine: Color(0xFFd4a017),
    accuracyLine: Color(0xFFc8a654),
    gold: Color(0xFFffd700),
    silver: Color(0xFFc0c0c0),
    bronze: Color(0xFFcd7f32),
    xpBar: Color(0xFFd4a017),
    xpBarBg: Color(0xFF2a2010),
  );

  /// Look up a ThemeColors by id.
  static ThemeColors forId(String id) {
    switch (id) {
      case 'light':
        return light;
      case 'northern_lights':
        return northernLights;
      case 'fjord_blue':
        return fjordBlue;
      case 'viking_gold':
        return vikingGold;
      default:
        return dark;
    }
  }
}

/// Backward-compatible static color constants (dark theme).
/// Existing code that uses AppColors.xyz continues to work unchanged.
class AppColors {
  // Background layers
  static const background = Color(0xFF1a1a2e);
  static const surface = Color(0xFF16213e);
  static const surfaceLight = Color(0xFF1f3460);

  // Text
  static const textPrimary = Color(0xFFe2e2e2);
  static const textMuted = Color(0xFF525868);
  static const textSubtle = Color(0xFF3a3f4b);

  // Typing feedback
  static const correct = Color(0xFFd1d0c5);
  static const incorrect = Color(0xFFca4754);
  static const extra = Color(0xFF7e2a33);
  static const cursor = Color(0xFFe2b714);

  // Accent
  static const accent = Color(0xFFe2b714);
  static const accentDim = Color(0xFF7a6310);

  // Stats / charts
  static const speedLine = Color(0xFF4ec9b0);
  static const accuracyLine = Color(0xFFe2b714);

  // Achievement
  static const gold = Color(0xFFffd700);
  static const silver = Color(0xFFc0c0c0);
  static const bronze = Color(0xFFcd7f32);

  // XP bar
  static const xpBar = Color(0xFF4ec9b0);
  static const xpBarBg = Color(0xFF2a2d35);
}

class AppTheme {
  /// Build a ThemeData from a ThemeColors palette.
  static ThemeData _fromColors(ThemeColors c) {
    final base = c.brightness == Brightness.light
        ? ThemeData.light()
        : ThemeData.dark();

    return ThemeData(
      brightness: c.brightness,
      scaffoldBackgroundColor: c.background,
      colorScheme: ColorScheme(
        brightness: c.brightness,
        primary: c.accent,
        onPrimary: c.brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF1a1a2e),
        secondary: c.speedLine,
        onSecondary: c.textPrimary,
        error: c.incorrect,
        onError: Colors.white,
        surface: c.surface,
        onSurface: c.textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      useMaterial3: true,
    );
  }

  /// Get a theme by id. Falls back to dark.
  static ThemeData getTheme(String themeId) {
    return _fromColors(ThemeColors.forId(themeId));
  }

  /// Original dark theme (backward compat).
  static ThemeData dark() => _fromColors(ThemeColors.dark);

  static TextStyle get monoStyle => GoogleFonts.jetBrainsMono(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        height: 1.8,
      );

  static TextStyle get monoStyleSmall => GoogleFonts.jetBrainsMono(
        fontSize: 16,
        fontWeight: FontWeight.w400,
      );
}
