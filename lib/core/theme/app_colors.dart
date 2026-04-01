import 'package:flutter/material.dart';

/// Paleta de colores "Indigo Vault" — Design System premium
class AppColors {
  AppColors._();

  // ─── Primary Indigo ────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDim = Color(0xFF6063EE);
  static const Color primarySoft = Color(0xFFA3A6FF);

  // ─── Semantic: Estado financiero ───────────────────────────────────────
  static const Color income = Color(0xFF10B981);       // Esmeralda
  static const Color incomeDim = Color(0xFF58E7AB);
  static const Color expense = Color(0xFFEF4444);       // Rojo
  static const Color expenseDim = Color(0xFFFF716A);
  static const Color transfer = Color(0xFF3B82F6);       // Azul
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // ─── Indigo Vault Surfaces (Dark mode first) ──────────────────────────
  static const Color surface = Color(0xFF060E20);                 // Base
  static const Color surfaceContainerLowest = Color(0xFF000000);  // Etched inputs
  static const Color surfaceContainerLow = Color(0xFF091328);     // Section layer
  static const Color surfaceContainer = Color(0xFF0F1930);        // Content areas
  static const Color surfaceContainerHigh = Color(0xFF141F38);    // Elevated
  static const Color surfaceContainerHighest = Color(0xFF192540); // Cards
  static const Color surfaceBright = Color(0xFF1F2B49);           // Glass layer base
  static const Color surfaceVariant = Color(0xFF192540);

  // ─── Text / On-Surface ────────────────────────────────────────────────
  static const Color onSurface = Color(0xFFDEE5FF);           // Primary text
  static const Color onSurfaceVariant = Color(0xFFA3AAC4);    // Secondary text
  static const Color outline = Color(0xFF6D758C);
  static const Color outlineVariant = Color(0xFF40485D);

  // ─── Light mode legacy ────────────────────────────────────────────────
  static const Color surfaceLight = Color(0xFFFAFAFA);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);

  // ─── Category colors ──────────────────────────────────────────────────
  static const Color categoryFood = Color(0xFFF59E0B);
  static const Color categoryTransport = Color(0xFF3B82F6);
  static const Color categoryHome = Color(0xFF8B5CF6);
  static const Color categoryHealth = Color(0xFFEC4899);
  static const Color categoryEducation = Color(0xFF06B6D4);
  static const Color categoryEntertainment = Color(0xFFF43F5E);
  static const Color categoryServices = Color(0xFF8B5CF6);

  // ─── Gradients ────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primarySoft, primaryDim],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient incomeGradient = LinearGradient(
    colors: [Color(0xFF34D399), income],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient expenseGradient = LinearGradient(
    colors: [Color(0xFFFF928B), expense],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Glassmorphic card decoration — reutilizable
  static BoxDecoration glassCard({
    Color? color,
    double borderRadius = 16,
    double opacity = 0.6,
    bool withBorder = true,
  }) {
    return BoxDecoration(
      color: (color ?? surfaceContainerHighest).withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: withBorder
          ? Border.all(color: outlineVariant.withValues(alpha: 0.15), width: 1)
          : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: primary.withValues(alpha: 0.05),
          blurRadius: 20,
        ),
      ],
    );
  }

  /// Tonal card decoration (sin glass, con separación tonal)
  static BoxDecoration tonalCard({
    Color? color,
    double borderRadius = 16,
  }) {
    return BoxDecoration(
      color: color ?? surfaceContainerHigh,
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  // Legacy aliases
  static const Color secondary = income;
  static const Color secondaryDark = Color(0xFF059669);
  static const Color secondaryLight = Color(0xFF34D399);
  static const Color success = income;
  static const Color error = expense;
}
