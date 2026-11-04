import 'package:flutter/material.dart';

class AppColors {
  // AppColors._();

  static Color colorScheme = const Color(0xff0077b6);
  static Color primaryColor = const Color(0xff0077b6);
  static Color secondaryColor = const Color(0xffe3e8f0);
  static Color whiteColor = const Color(0xffF2F2F2);
  static Color pureWhiteColor = const Color(0xffFFFFFF);
  static Color blackColor = const Color(0xff000000);
  static Color greyColor = const Color(0xff808080);
  static Color redColor = const Color(0xffD70040);
  static Color greenColor = const Color(0xff008000);

  // ---- Core brand colors ----
  static const Color primary = Color(0xFF2E5EAA); // teal
  static const Color primaryVariant = Color(0xFF3B8EA5);
  static const Color secondary = Color(0xFF0A73FF); // blue
  static const Color accent = Color(0xFFFFC107); // amber
  static const Color orange = Color(0xFFFF9800);
  static const Color lightText = Color(0xFFFFFFFF);
  static const Color lightTextSecondary = Color(0xB3FFFFFF);
  static const Color hover = Color(0x1AFFFFFF);
  static const Color selectionTile = Color(0x1FFFFFFF);

  // ---- Neutrals ----
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color blueGrey = Color(0xFF607D8B);
  static const surface = Color(0xFFFFFFFF);

  static const Color grey = Color(0xFF6B7785);
  static const Color grey50 = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF2F4F7);
  static const Color grey200 = Color(0xFFE6E9EE);
  static const Color grey300 = Color(0xFFD1D7E0);
  static const Color grey400 = Color(0xFF9AA4B2);
  static const Color grey500 = Color(0xFF6B7785);
  static const Color grey600 = Color(0xFF495263);
  static const Color grey700 = Color(0xFF2E3742);
  static const Color grey800 = Color(0xFF1B2024);
  static const Color grey900 = Color(0xFF111418);
  static const Color blue = Color(0xFF2E5EAA);
  static const Color blue50 = Color(0xFFE6F2FF);
  static const Color blue100 = Color(0xFFE6F2FF);
  static const Color blue200 = Color(0xFFB3D6FF);
  static const Color blue300 = Color(0xFF80B9FF);
  static const Color blue400 = Color(0xFF4D9CFF);
  static const Color blue500 = Color(0xFF1A7EFF);
  static const Color blue600 = Color(0xFF0062FF);
  static const Color blue700 = Color(0xFF004ECC);
  static const Color blue800 = Color(0xFF003999);

  // ---- Semantic ----
  static const Color success = Color(0xFF28A745);
  static const Color info = Color(0xFF0DCAF0);
  static const Color warning = Color(0xFFFFA000);
  static const Color danger = Color(0xFFDC3545);

  // ---- Transparent helpers ----
  static Color overlay(Color base, double opacity) =>
      base.withValues(alpha: opacity);
  static const Color transparent = Colors.transparent;

  // ---- Black helpers ----
  static const Color black12 = Colors.black12;
  static const Color black26 = Colors.black26;
  static const Color black38 = Colors.black38;
  static const Color black45 = Colors.black45;
  static const Color black54 = Colors.black54;
  static const Color black87 = Colors.black87;
  static const Color white10 = Color(0x1AFFFFFF);
  static const Color white12 = Color(0x1FFFFFFF);
  static const Color white24 = Color(0x3DFFFFFF);
  static const Color white38 = Color(0x62FFFFFF);
  static const Color white70 = Color(0xB3FFFFFF);

  // ---- Utility: Convert hex string to Color ----
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  // ---- MaterialColor generator (useful for primary swatches) ----
  static MaterialColor materialColor(Color color) {
    final strengths = <double>[.05];
    final swatch = <int, Color>{};
    // ignore: deprecated_member_use
    final r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.toARGB32(), swatch);
  }

  // ---- Contrast helper (returns black or white based on luminance) ----
  static Color contrastColor(Color c) =>
      c.computeLuminance() > 0.5 ? black : white;

  // ---- Example grouped usage (for widgets) ----
  static const Color cardBackground = white;
  static const Color inputFill = grey100;
  static const Color disabled = grey300;
  static const Color scaffoldBackgroundColor = Color(0xFFE7ECEF);
  static const Color sidebarBackground = Color(0xFF1E293B);
  static const Color primaryLight = Color(0xFFEBF5FF);
  static const Color text = Color(0xFF1F2937);
  static const Color textLight = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color teal = Colors.teal;
}

class LetterColors {
  static const Map<String, Color> colors = {
    'A': Color(0xFF2E7D32), // Dark Green
    'B': Color(0xFF00695C), // Dark Teal
    'C': Color(0xFF1565C0), // Dark Blue
    'D': Color(0xFF4527A0), // Deep Purple
    'E': Color(0xFF6A1B9A), // Dark Violet
    'F': Color(0xFFC2185B), // Dark Pink
    'G': Color(0xFFD32F2F), // Dark Red
    'H': Color(0xFFF57C00), // Dark Orange
    'I': Color(0xFFFFA000), // Dark Amber
    'J': Color(0xFF5D4037), // Dark Brown
    'K': Color(0xFF455A64), // Dark Blue Grey
    'L': Color(0xFF283593), // Indigo
    'M': Color(0xFF00838F), // Cyan
    'N': Color(0xFF558B2F), // Olive Green
    'O': Color(0xFFE64A19), // Deep Orange
    'P': Color(0xFF7B1FA2), // Magenta Purple
    'Q': Color(0xFF616161), // Medium Grey
    'R': Color(0xFFB71C1C), // Strong Red
    'S': Color(0xFF303F9F), // Navy Blue
    'T': Color(0xFF37474F), // Charcoal
    'U': Color(0xFF00796B), // Teal
    'V': Color(0xFF512DA8), // Deep Violet
    'W': Color(0xFF388E3C), // Forest Green
    'X': Color(0xFF6D4C41), // Cocoa
    'Y': Color(0xFFEF6C00), // Burnt Orange
    'Z': Color(0xFF424242), // Dark Grey
  };

  static Color getColor(String letter) {
    final upper = letter.toUpperCase();
    return colors[upper] ?? AppColors.grey600; // fallback dark neutral
  }
}
