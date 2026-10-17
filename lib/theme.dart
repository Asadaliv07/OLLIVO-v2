import 'package:flutter/material.dart';

/// Ollivo Brand Theme & UI Tokens (Overhauled for macOS Elite Desktop Standards)
/// Benchmarked against Linear, Raycast, Craft Docs, and Apple Design Award standards.
class OllivoTheme {
  // --- 1. Color Depth & Surfaces (Dark Onyx System) ---
  static const Color canvasDark = Color(0xFF0D0E11); // Pure deep canvas (#0D0E11 - #121316)
  static const Color onyxDark = Color(0xFF101216);   // Dark Onyx base surface
  static const Color surfaceDark = Color(0xFF14171D); // Layered surface (Sidebar, top bar, headers)
  static const Color cardDark = Color(0xFF1A1D24);    // Layered card & panel surface
  static const Color cardElevatedDark = Color(0xFF21252E); // Inset grouping & elevated controls

  // Light Theme Surfaces (Clean Ceramic)
  static const Color porcelainLight = Color(0xFFF6F8FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E4E8);

  // Layered Border System (1px subtle white gradients)
  static const Color borderDark = Color(0x1AFFFFFF);   // ~10% white for crisp boundary
  static const Color borderSubtle = Color(0x12FFFFFF); // ~7% white for inner dividers
  static const Color borderMuted = Color(0x0AFFFFFF);  // ~4% white for inactive cards
  static const Color borderGlass = Color(0x28FFFFFF);  // ~16% white for hover/focus illumination

  // Accent System (Electric Mint & Emerald - Restrained)
  static const Color mintPrimary = Color(0xFF10B981); // Electric Emerald CTA
  static const Color mintAccent = Color(0xFF4ADE80);  // Bright Mint accent
  static const Color mintSubtle = Color(0x144ADE80);  // 8% mint fill for active pill backgrounds
  static const Color oliveEmerald = Color(0xFF10B981); // Primary emerald token (backward-compatible)
  static const Color oliveEmeraldDark = Color(0xFF059669);

  // Text Tokens
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF9CA3AF); // Muted secondary
  static const Color textTertiaryDark = Color(0xFF6B7280);  // Inactive / section label

  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF4B5563);

  // Status System
  static const Color statusSuccess = Color(0xFF10B981);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusError = Color(0xFFEF4444);

  // --- 2. Spacing Tokens ---
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;

  // --- 3. Radius Tokens ---
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;

  // --- 4. Ambient Shadows & Glows ---
  static const List<BoxShadow> ambientShadow = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static List<BoxShadow> hoverGlow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.16),
      blurRadius: 14,
      spreadRadius: 1,
      offset: const Offset(0, 2),
    ),
  ];

  // --- 5. Typography Hierarchy (Apple SF Pro & Inter Standards) ---
  static const TextStyle h1Style = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.42, // -0.02em tracking
    color: textPrimaryDark,
    height: 1.25,
  );

  static const TextStyle h2Style = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: textPrimaryDark,
    height: 1.3,
  );

  static const TextStyle sectionLabelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.55, // +0.05em tracking
    color: textTertiaryDark,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    color: textPrimaryDark,
    height: 1.4,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondaryDark,
    height: 1.3,
  );

  // --- 6. Dark Theme Definition ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: canvasDark,
      colorScheme: const ColorScheme.dark(
        primary: mintPrimary,
        surface: surfaceDark,
        onPrimary: onyxDark,
        onSurface: textPrimaryDark,
        error: statusError,
      ),
      focusColor: const Color(0x3310B981),
      dividerColor: borderDark,
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: borderDark, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimaryDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mintPrimary,
          foregroundColor: onyxDark,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: mintPrimary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textSecondaryDark, fontSize: 13),
      ),
    );
  }

  // --- 7. Light Theme Definition ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: porcelainLight,
      colorScheme: const ColorScheme.light(
        primary: oliveEmeraldDark,
        surface: surfaceLight,
        onPrimary: Colors.white,
        onSurface: textPrimaryLight,
        error: statusError,
      ),
      focusColor: const Color(0x33059669),
      dividerColor: borderLight,
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimaryLight,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: oliveEmeraldDark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: oliveEmeraldDark, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textSecondaryLight, fontSize: 13),
      ),
    );
  }
}
