import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primaryTeal = Color(0xFF34A99D);
  static const Color secondaryTeal = Color(0xFF458393);
  static const Color successGreen = Color(0xFF2E7D32);
  static const Color warningOrange = Color(0xFFF57C00);

  static const double radius = 16;
  static const double radiusSm = 12;
  static const double buttonHeight = 54;

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(seedColor: primaryTeal).copyWith(
      primary: primaryTeal,
      secondary: secondaryTeal,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    );

    final borderRadius = BorderRadius.circular(radius);
    final borderRadiusSm = BorderRadius.circular(radiusSm);
    final borderSide = BorderSide(color: colorScheme.outlineVariant);

    final inputDecorationTheme = InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: borderRadiusSm,
        borderSide: borderSide,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadiusSm,
        borderSide: borderSide,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadiusSm,
        borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadiusSm,
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: borderRadiusSm,
        borderSide: BorderSide(color: colorScheme.error, width: 1.6),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF5F7F5),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        color: colorScheme.surface,
      ),
      inputDecorationTheme: inputDecorationTheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, buttonHeight),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, buttonHeight),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          side: borderSide,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
    );
  }
}