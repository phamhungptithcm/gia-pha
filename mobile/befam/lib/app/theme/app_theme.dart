import 'package:flutter/material.dart';

import '../../core/widgets/app_motion.dart';
import 'app_ui_tokens.dart';

abstract final class AppTheme {
  static ThemeData light({bool transparentScaffold = false}) {
    const uiTokens = AppUiTokens.light();
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF3155FF),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE4EAFF),
      onPrimaryContainer: Color(0xFF071338),
      secondary: Color(0xFF2FC37D),
      onSecondary: Color(0xFF031C12),
      secondaryContainer: Color(0xFFE4F8EF),
      onSecondaryContainer: Color(0xFF062416),
      tertiary: Color(0xFF8B5CF6),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFF0EAFF),
      onTertiaryContainer: Color(0xFF1D123C),
      error: Color(0xFFB3261E),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      surface: Color(0xFFF8FAFF),
      onSurface: Color(0xFF0F172A),
      surfaceContainerHighest: Color(0xFFEAF0FA),
      onSurfaceVariant: Color(0xFF526076),
      outline: Color(0xFF7E8AA3),
      outlineVariant: Color(0xFFDCE4F2),
      shadow: Color(0x260F172A),
      scrim: Color(0x400F172A),
      inverseSurface: Color(0xFF0F172A),
      onInverseSurface: Color(0xFFF8FAFF),
      inversePrimary: Color(0xFFB8C7FF),
      surfaceTint: Color(0xFF3155FF),
    );

    final textTheme = Typography.material2021().black.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      extensions: const <ThemeExtension<dynamic>>[uiTokens],
      colorScheme: colorScheme,
      scaffoldBackgroundColor: transparentScaffold
          ? Colors.transparent
          : colorScheme.surface,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: BeFamPageTransitionsBuilder(),
          TargetPlatform.iOS: BeFamPageTransitionsBuilder(),
          TargetPlatform.macOS: BeFamPageTransitionsBuilder(),
        },
      ),
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          height: 1.12,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          height: 1.16,
        ),
        displaySmall: textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w900,
          height: 1.06,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          height: 1.22,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.24,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.44),
        bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.42),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white.withValues(alpha: 0.84),
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.88),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(uiTokens.radiusLg),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(0, uiTokens.buttonHeight),
          foregroundColor: colorScheme.onPrimary,
          backgroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(uiTokens.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, uiTokens.buttonHeight),
          side: BorderSide(color: colorScheme.outlineVariant),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(uiTokens.radiusMd),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        extendedTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.90),
        floatingLabelStyle: textTheme.labelLarge?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.error,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
        helperStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: 1.25,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: uiTokens.inputHorizontalPadding,
          vertical: uiTokens.inputVerticalPadding,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(uiTokens.radiusMd),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(uiTokens.radiusMd),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(uiTokens.radiusMd),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(uiTokens.radiusMd),
          borderSide: BorderSide(color: colorScheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(uiTokens.radiusMd),
          borderSide: BorderSide(color: colorScheme.error, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.88),
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            letterSpacing: 0,
          );
        }),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(uiTokens.radiusMd),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(uiTokens.radiusPill),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
      splashFactory: InkSparkle.splashFactory,
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
