import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// iGPan design tokens and theme.
///
/// Aesthetic: dark industrial — carbon fibre feel, racing telemetry palette.
/// Primary blue is the iGP brand blue. Accent is a warm amber for alerts/actions.
class AppTheme {
  AppTheme._();

  // ─── Palette ──────────────────────────────────────────────
  static const Color primary       = Color(0xFF185FA5); // iGP blue
  static const Color primaryLight  = Color(0xFF2E7BC4);
  static const Color primaryDim    = Color(0xFF0D3D6B);

  static const Color surface       = Color(0xFF0F1117); // near-black
  static const Color surfaceCard   = Color(0xFF181C27); // card bg
  static const Color surfaceRaised = Color(0xFF1E2333); // elevated card

  static const Color onSurface     = Color(0xFFE8EAF0);
  static const Color onSurfaceDim  = Color(0xFF8B91A8);
  static const Color onSurfaceFaint= Color(0xFF3D4259);

  static const Color accent        = Color(0xFFE8A020); // amber — warnings, highlights
  static const Color success       = Color(0xFF1D9E75); // green — session active
  static const Color error         = Color(0xFFE24B4A); // red — session expired
  static const Color sessionActive = success;
  static const Color sessionExpired= error;

  static const Color border        = Color(0xFF252A3A);
  static const Color borderBright  = Color(0xFF353B52);

  // ─── Pill rail ────────────────────────────────────────────
  static const Color pillBg        = Color(0xFF1A1F2E);
  static const Color pillSelected  = primary;
  static const Color pillText      = onSurfaceDim;
  static const Color pillTextSel   = Color(0xFFD6E8FA);

  // ─── Batch bar ────────────────────────────────────────────
  static const Color batchBar      = primaryDim;
  static const Color batchBarText  = Color(0xFFD6E8FA);

  // ─── Typography ───────────────────────────────────────────
  // Using system default (Roboto on Android) — clean and legible on small screens.
  // Heading weight bumped for dashboard readability.
  static const TextTheme textTheme = TextTheme(
    displayLarge:  TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
    displayMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
    headlineMedium:TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    titleLarge:    TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
    titleMedium:   TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    bodyLarge:     TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
    bodyMedium:    TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
    bodySmall:     TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
    labelLarge:    TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3),
    labelSmall:    TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.4),
  );

  // ─── Theme ────────────────────────────────────────────────
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      colorScheme: ColorScheme.dark(
        primary:          primary,
        onPrimary:        Colors.white,
        secondary:        accent,
        onSecondary:      Colors.black,
        surface:          surface,
        onSurface:        onSurface,
        surfaceContainerHighest: surfaceRaised,
        outline:          border,
        error:            error,
      ),
      scaffoldBackgroundColor: surface,
      cardColor:               surfaceCard,
      dividerColor:            border,
      textTheme:               textTheme.apply(
        bodyColor:        onSurface,
        displayColor:     onSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor:  surface,
        surfaceTintColor: Colors.transparent,
        elevation:        0,
        scrolledUnderElevation: 0,
        centerTitle:      false,
        titleTextStyle: TextStyle(
          color:      onSurface,
          fontSize:   16,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: onSurface),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor:            Colors.transparent,
          statusBarIconBrightness:   Brightness.light,
          systemNavigationBarColor:  surface,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:       surfaceCard,
        selectedItemColor:     primary,
        unselectedItemColor:   onSurfaceDim,
        type:                  BottomNavigationBarType.fixed,
        elevation:             0,
        selectedLabelStyle:    TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle:  TextStyle(fontSize: 10),
      ),
      cardTheme: CardThemeData(
        color:        surfaceCard,
        elevation:    0,
        shape:        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side:         const BorderSide(color: border, width: 0.5),
        ),
        margin:       EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:           true,
        fillColor:        surfaceRaised,
        contentPadding:   const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: error),
        ),
        hintStyle: const TextStyle(color: onSurfaceDim, fontSize: 13),
        labelStyle: const TextStyle(color: onSurfaceDim, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation:       0,
          padding:         const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle:       const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side:            const BorderSide(color: primary),
          padding:         const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle:       const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle:       const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:  surfaceRaised,
        contentTextStyle: const TextStyle(color: onSurface, fontSize: 13),
        shape:            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior:         SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor:  surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape:            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle:   const TextStyle(
          color: onSurface, fontSize: 17, fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(color: onSurfaceDim, fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(
        color:     border,
        thickness: 0.5,
        space:     0,
      ),
    );
  }
}