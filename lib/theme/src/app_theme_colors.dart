import 'package:flutter/material.dart';

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color bgColor;
  final Color cardColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color sidebarBackground;

  const AppThemeColors({
    required this.bgColor,
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.sidebarBackground,
  });

  @override
  AppThemeColors copyWith({
    Color? bgColor,
    Color? cardColor,
    Color? textPrimary,
    Color? textSecondary,
    Color? divider,
    Color? sidebarBackground,
  }) {
    return AppThemeColors(
      bgColor: bgColor ?? this.bgColor,
      cardColor: cardColor ?? this.cardColor,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      divider: divider ?? this.divider,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;

    return AppThemeColors(
      bgColor: Color.lerp(bgColor, other.bgColor, t)!,
      cardColor: Color.lerp(cardColor, other.cardColor, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      sidebarBackground: Color.lerp(
        sidebarBackground,
        other.sidebarBackground,
        t,
      )!,
    );
  }
}
