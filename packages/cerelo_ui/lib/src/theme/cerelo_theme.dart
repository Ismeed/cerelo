import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cerelo_colors.dart';
import 'cerelo_spacing.dart';
import 'cerelo_text_styles.dart';

/// Cerelo Material Theme configuration.
///
/// Apply this to MaterialApp.theme to get consistent Cerelo branding.
class CereloTheme {
  CereloTheme._();

  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: CereloColors.navy,
      onPrimary: CereloColors.textOnDark,
      primaryContainer: CereloColors.navyLight,
      onPrimaryContainer: CereloColors.textOnDark,
      secondary: CereloColors.orange,
      onSecondary: CereloColors.textOnOrange,
      secondaryContainer: Color(0xFFFFE5D3),
      onSecondaryContainer: CereloColors.orangeDark,
      error: CereloColors.error,
      onError: CereloColors.white,
      surface: CereloColors.surface,
      onSurface: CereloColors.textPrimary,
      surfaceContainerHighest: CereloColors.surfaceVariant,
      onSurfaceVariant: CereloColors.textSecondary,
      outline: CereloColors.border,
      outlineVariant: CereloColors.borderStrong,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: CereloColors.surface,
      fontFamily: 'Inter',
      textTheme: TextTheme(
        displayLarge: CereloTextStyles.displayLg,
        displaySmall: CereloTextStyles.displaySm,
        headlineLarge: CereloTextStyles.h1,
        headlineMedium: CereloTextStyles.h2,
        headlineSmall: CereloTextStyles.h3,
        bodyLarge: CereloTextStyles.bodyLg,
        bodyMedium: CereloTextStyles.bodyMd,
        bodySmall: CereloTextStyles.bodySm,
        labelLarge: CereloTextStyles.labelLg,
        labelMedium: CereloTextStyles.labelMd,
        labelSmall: CereloTextStyles.labelSm,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: CereloColors.navy,
        foregroundColor: CereloColors.textOnDark,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: CereloColors.navy,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CereloColors.orange,
          foregroundColor: CereloColors.textOnOrange,
          minimumSize: const Size(0, CereloSpacing.minTouchTarget),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(CereloSpacing.radiusMd),
            ),
          ),
          textStyle: CereloTextStyles.labelLg,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: CereloColors.navy,
          minimumSize: const Size(0, CereloSpacing.minTouchTarget),
          side: const BorderSide(color: CereloColors.border),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(CereloSpacing.radiusMd),
            ),
          ),
          textStyle: CereloTextStyles.labelLg,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CereloColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CereloSpacing.md,
          vertical: CereloSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
          borderSide: const BorderSide(color: CereloColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
          borderSide: const BorderSide(color: CereloColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
          borderSide: const BorderSide(color: CereloColors.navy, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
          borderSide: const BorderSide(color: CereloColors.error),
        ),
        hintStyle: CereloTextStyles.bodyMd.copyWith(
          color: CereloColors.textTertiary,
        ),
        labelStyle: CereloTextStyles.labelLg,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: CereloColors.white,
        selectedItemColor: CereloColors.navy,
        unselectedItemColor: CereloColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: CereloColors.border,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardTheme(
        color: CereloColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
          side: const BorderSide(color: CereloColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
        ),
      ),
    );
  }
}
