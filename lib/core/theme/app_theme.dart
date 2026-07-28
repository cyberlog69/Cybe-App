import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AppTheme supporting Material You (Material 3) Dynamic Wallpaper Colors on Android 12+
/// with fallback to Cybe's Cyberpunk Dark Security Palette.
class AppTheme {
  // Brand fallback security color tokens
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF12121A);
  static const Color surfaceVariant = Color(0xFF1A1A26);
  static const Color cardColor = Color(0xFF16161F);
  static const Color primary = Color(0xFF00E5FF);
  static const Color secondary = Color(0xFF39FF14);
  static const Color accent = Color(0xFF7B2FBE);
  static const Color warning = Color(0xFFFFB300);
  static const Color danger = Color(0xFFFF1744);
  static const Color safe = Color(0xFF00E676);
  static const Color textPrimary = Color(0xFFE8EAF6);
  static const Color textSecondary = Color(0xFF9E9EC8);
  static const Color divider = Color(0xFF1E1E2E);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF7B2FBE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFFF1744), Color(0xFF7B0000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient safeGradient = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00796B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFFFB300), Color(0xFFE65100)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0A0A0F), Color(0xFF0D0D1A), Color(0xFF0A0A0F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Default dark theme
  static ThemeData get darkTheme => buildTheme(ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        surface: surface,
      ));

  /// Light theme fallback
  static ThemeData get lightTheme => buildTheme(ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ));

  /// Dynamically builds a Material 3 Theme from a system dynamic ColorScheme (Material You Monet)
  static ThemeData buildTheme(ColorScheme? dynamicScheme) {
    final bool isDark = (dynamicScheme?.brightness ?? Brightness.dark) == Brightness.dark;

    final ColorScheme scheme = dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: isDark ? Brightness.dark : Brightness.light,
          primary: primary,
          secondary: secondary,
          surface: isDark ? surface : const Color(0xFFF5F5FA),
          error: danger,
        );

    final baseTextTheme = isDark
        ? GoogleFonts.interTextTheme(const TextTheme(
            displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
            headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
            titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
            bodyLarge: TextStyle(color: textPrimary),
            bodyMedium: TextStyle(color: textSecondary),
            labelLarge: TextStyle(color: primary, fontWeight: FontWeight.w600, letterSpacing: 1.2),
          ))
        : GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? background : scheme.surface,
      primaryColor: scheme.primary,

      // Material 3 Typography
      textTheme: baseTextTheme,

      // Material 3 App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? background : scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 2,
        iconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Material You M3 Card Theme
      cardTheme: CardThemeData(
        color: isDark ? cardColor : scheme.surfaceContainerLow,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),

      // Material You M3 Elevated Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.5),
        ),
      ),

      // Material You M3 Outlined Buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),

      // Material You M3 Input Decorations
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? surfaceVariant : scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // Material You M3 Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Material You M3 Navigation Bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? surface : scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface),
        ),
      ),

      // Material You M3 Switches & Toggles
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surfaceContainerHighest;
        }),
      ),

      // Material You M3 Dialogs & Bottom Sheets
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? surface : scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? surface : scheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.4),
        thickness: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? surfaceVariant : scheme.inverseSurface,
        contentTextStyle: TextStyle(color: isDark ? textPrimary : scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
