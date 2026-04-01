import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Tema "Indigo Vault" — WalletAI Design System
/// Dual-font: Plus Jakarta Sans (números/headlines) + Manrope (body/labels)
class AppTheme {
  // Colores semánticos de estado — independientes del seed
  static const Color income = AppColors.income;
  static const Color expense = AppColors.expense;
  static const Color transfer = AppColors.transfer;

  // ─── Text Themes ──────────────────────────────────────────────────────

  static TextTheme _buildDarkTextTheme() {
    final jakartaDisplay = GoogleFonts.plusJakartaSans(color: AppColors.onSurface);
    final manropeBody = GoogleFonts.manrope(color: AppColors.onSurface);
    final manropeLabel = GoogleFonts.manrope(color: AppColors.onSurfaceVariant);

    return TextTheme(
      // Plus Jakarta Sans — Numbers & Headlines
      displayLarge: jakartaDisplay.copyWith(fontSize: 57, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      displayMedium: jakartaDisplay.copyWith(fontSize: 45, fontWeight: FontWeight.w700),
      displaySmall: jakartaDisplay.copyWith(fontSize: 36, fontWeight: FontWeight.w700),
      headlineLarge: jakartaDisplay.copyWith(fontSize: 32, fontWeight: FontWeight.w700),
      headlineMedium: jakartaDisplay.copyWith(fontSize: 28, fontWeight: FontWeight.w600),
      headlineSmall: jakartaDisplay.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
      titleLarge: jakartaDisplay.copyWith(fontSize: 22, fontWeight: FontWeight.w600),
      titleMedium: jakartaDisplay.copyWith(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.15),
      titleSmall: jakartaDisplay.copyWith(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),

      // Manrope — Body & Labels
      bodyLarge: manropeBody.copyWith(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: manropeBody.copyWith(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: manropeBody.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.onSurfaceVariant),
      labelLarge: manropeLabel.copyWith(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      labelMedium: manropeLabel.copyWith(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      labelSmall: manropeLabel.copyWith(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
    );
  }

  static TextTheme _buildLightTextTheme() {
    final jakartaDisplay = GoogleFonts.plusJakartaSans(color: AppColors.textPrimary);
    final manropeBody = GoogleFonts.manrope(color: AppColors.textPrimary);
    final manropeLabel = GoogleFonts.manrope(color: AppColors.textSecondary);

    return TextTheme(
      displayLarge: jakartaDisplay.copyWith(fontSize: 57, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      displayMedium: jakartaDisplay.copyWith(fontSize: 45, fontWeight: FontWeight.w700),
      displaySmall: jakartaDisplay.copyWith(fontSize: 36, fontWeight: FontWeight.w700),
      headlineLarge: jakartaDisplay.copyWith(fontSize: 32, fontWeight: FontWeight.w700),
      headlineMedium: jakartaDisplay.copyWith(fontSize: 28, fontWeight: FontWeight.w600),
      headlineSmall: jakartaDisplay.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
      titleLarge: jakartaDisplay.copyWith(fontSize: 22, fontWeight: FontWeight.w600),
      titleMedium: jakartaDisplay.copyWith(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.15),
      titleSmall: jakartaDisplay.copyWith(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      bodyLarge: manropeBody.copyWith(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: manropeBody.copyWith(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: manropeBody.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      labelLarge: manropeLabel.copyWith(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      labelMedium: manropeLabel.copyWith(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      labelSmall: manropeLabel.copyWith(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
    );
  }

  // ─── Light Theme ──────────────────────────────────────────────────────

  static ThemeData buildLight(Color seed) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: _buildLightTextTheme(),
      scaffoldBackgroundColor: scheme.surface,

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),

      chipTheme: ChipThemeData(
        selectedColor: scheme.primaryContainer,
        backgroundColor: scheme.surfaceContainer,
        labelStyle: GoogleFonts.manrope(fontSize: 13, color: scheme.onSurface),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        showCheckmark: false,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.5,
      ),
    );
  }

  // ─── Dark Theme (Indigo Vault) ────────────────────────────────────────

  static ThemeData buildDark(Color seed) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );

    // ── Indigo Vault custom surfaces ──────────────────────────────────
    final refinedScheme = scheme.copyWith(
      surface: AppColors.surface,
      surfaceContainerLowest: AppColors.surfaceContainerLowest,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: refinedScheme,
      textTheme: _buildDarkTextTheme(),
      scaffoldBackgroundColor: AppColors.surface,

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: refinedScheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: refinedScheme.error, width: 2),
        ),
      ),

      chipTheme: ChipThemeData(
        selectedColor: refinedScheme.primaryContainer,
        backgroundColor: AppColors.surfaceContainerHighest,
        labelStyle: GoogleFonts.manrope(fontSize: 13, color: AppColors.onSurface),
        side: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        showCheckmark: false,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primarySoft,
            );
          }
          return GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primarySoft, size: 24);
          }
          return const IconThemeData(color: AppColors.onSurfaceVariant, size: 24);
        }),
      ),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: Colors.transparent,
      ),

      dividerTheme: DividerThemeData(
        color: AppColors.outlineVariant.withValues(alpha: 0.3),
        thickness: 0.5,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceContainer,
        modalBackgroundColor: AppColors.surfaceContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceBright,
        contentTextStyle: GoogleFonts.manrope(color: AppColors.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Legacy: compatibilidad ───────────────────────────────────────────
  static final ThemeData lightTheme = buildLight(const Color(0xFF6366F1));
  static final ThemeData darkTheme  = buildDark(const Color(0xFF6366F1));
}
