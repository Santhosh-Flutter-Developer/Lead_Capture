import 'package:flutter/material.dart';
import '/theme/theme.dart';

extension ThemeX on BuildContext {
  AppThemeColors get colors => Theme.of(this).extension<AppThemeColors>()!;
}
