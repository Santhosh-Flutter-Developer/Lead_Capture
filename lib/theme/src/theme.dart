import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/theme/theme.dart';

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ),
  fontFamily: 'GoogleSans',
  scaffoldBackgroundColor: const Color(0xFFF8FAFC),
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    backgroundColor: AppColors.primary,
    elevation: 0,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      fontFamily: 'GoogleSans',
    ),
    iconTheme: IconThemeData(color: Colors.white),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.red, width: 1),
    ),
    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
    labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      color: Color(0xFF1E293B),
      fontWeight: FontWeight.bold,
    ),
    displayMedium: TextStyle(
      color: Color(0xFF1E293B),
      fontWeight: FontWeight.bold,
    ),
    displaySmall: TextStyle(
      color: Color(0xFF1E293B),
      fontWeight: FontWeight.bold,
    ),
    headlineMedium: TextStyle(
      color: Color(0xFF1E293B),
      fontWeight: FontWeight.w600,
    ),
    titleLarge: TextStyle(
      color: Color(0xFF1E293B),
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      color: Color(0xFF334155),
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(color: Color(0xFF334155)),
    bodyMedium: TextStyle(color: Color(0xFF475569)),
    bodySmall: TextStyle(color: Color(0xFF64748B)),
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.primary;
      return null;
    }),
  ),
  radioTheme: RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.primary;
      return null;
    }),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.primary;
      return null;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.primary.withValues(alpha: 0.5);
      }
      return null;
    }),
  ),
  scrollbarTheme: ScrollbarThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) {
        return const Color(0xFF94A3B8);
      }
      return const Color(0xFFCBD5E1);
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      return const Color(0xFFE2E8F0).withValues(alpha: 0.5);
    }),
    trackBorderColor: WidgetStateProperty.all(Colors.transparent),
    crossAxisMargin: -4,
    thickness: WidgetStateProperty.all(4),
    radius: const Radius.circular(2),
  ),
  listTileTheme: ListTileThemeData(
    iconColor: const Color(0xFF64748B),
    titleTextStyle: const TextStyle(
      color: Color(0xFF1E293B),
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    subtitleTextStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
  ),
  dataTableTheme: DataTableThemeData(
    headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
    headingTextStyle: const TextStyle(
      color: Color(0xFF1E293B),
      fontWeight: FontWeight.bold,
      fontSize: 14,
    ),
    dataTextStyle: const TextStyle(color: Color(0xFF334155), fontSize: 14),
  ),
  extensions: const [
    AppThemeColors(
      bgColor: Color(0xFFF8FAFC),
      cardColor: Colors.white,
      textPrimary: Color(0xFF1E293B),
      textSecondary: Color(0xFF64748B),
      divider: Color(0xFFE2E8F0),
      sidebarBackground: Color(0xFF1E293B),
    ),
  ],
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ),
  fontFamily: 'GoogleSans',
  scaffoldBackgroundColor: const Color(0xFF0F172A),
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    backgroundColor: Color(0xFF1E293B),
    elevation: 0,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      fontFamily: 'GoogleSans',
    ),
    iconTheme: IconThemeData(color: Colors.white),
  ),
  cardTheme: CardThemeData(
    color: const Color(0xFF1E293B),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFF334155)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF1E293B),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF334155)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF334155)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1),
    ),
    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    displayMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    displaySmall: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(
      color: Color(0xFFE2E8F0),
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(color: Color(0xFFE2E8F0)),
    bodyMedium: TextStyle(color: Color(0xFFCBD5E1)),
    bodySmall: TextStyle(color: Color(0xFF94A3B8)),
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.primary;
      return null;
    }),
  ),
  radioTheme: RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.primary;
      return null;
    }),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.primary;
      return null;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.primary.withValues(alpha: 0.5);
      }
      return null;
    }),
  ),
  scrollbarTheme: ScrollbarThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) {
        return const Color(0xFF64748B);
      }
      return const Color(0xFF475569);
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      return const Color(0xFF334155).withValues(alpha: 0.5);
    }),
    trackBorderColor: WidgetStateProperty.all(Colors.transparent),
    crossAxisMargin: -4,
    thickness: WidgetStateProperty.all(4),
    radius: const Radius.circular(2),
  ),
  listTileTheme: ListTileThemeData(
    iconColor: const Color(0xFF94A3B8),
    titleTextStyle: const TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    subtitleTextStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
  ),
  dataTableTheme: DataTableThemeData(
    headingRowColor: WidgetStateProperty.all(const Color(0xFF1E293B)),
    headingTextStyle: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    ),
    dataTextStyle: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14),
  ),
  extensions: const [
    AppThemeColors(
      bgColor: Color(0xFF0F172A),
      cardColor: Color(0xFF1E293B),
      textPrimary: Colors.white,
      textSecondary: Color(0xFF94A3B8),
      divider: Color(0xFF334155),
      sidebarBackground: Color(0xFF020617),
    ),
  ],
);
