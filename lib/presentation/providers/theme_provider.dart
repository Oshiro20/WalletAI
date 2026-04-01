import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';

// ─── Claves de persistencia ────────────────────────────────────────────────
const _kThemeMode = 'theme_mode'; // 'light' | 'dark' | 'system'
const _kSeedColor = 'seed_color'; // int (Color value)

// ─── Paleta de temas de color disponibles ─────────────────────────────────

class AppColorTheme {
  final String id;
  final String name;
  final Color seed;
  final IconData icon;

  const AppColorTheme({
    required this.id,
    required this.name,
    required this.seed,
    required this.icon,
  });
}

const List<AppColorTheme> kAvailableThemes = [
  AppColorTheme(
    id: 'indigo',
    name: 'Índigo',
    seed: Color(0xFF6366F1),
    icon: Icons.auto_awesome,
  ),
  AppColorTheme(
    id: 'emerald',
    name: 'Esmeralda',
    seed: Color(0xFF10B981),
    icon: Icons.eco,
  ),
  AppColorTheme(
    id: 'ocean',
    name: 'Océano',
    seed: Color(0xFF0EA5E9),
    icon: Icons.water,
  ),
  AppColorTheme(
    id: 'violet',
    name: 'Violeta',
    seed: Color(0xFF8B5CF6),
    icon: Icons.diamond,
  ),
  AppColorTheme(
    id: 'rose',
    name: 'Rosa',
    seed: Color(0xFFF43F5E),
    icon: Icons.favorite,
  ),
  AppColorTheme(
    id: 'amber',
    name: 'Ámbar',
    seed: Color(0xFFF59E0B),
    icon: Icons.wb_sunny,
  ),
  AppColorTheme(
    id: 'teal',
    name: 'Verde Azulado',
    seed: Color(0xFF14B8A6),
    icon: Icons.spa,
  ),
  AppColorTheme(
    id: 'slate',
    name: 'Pizarra',
    seed: Color(0xFF64748B),
    icon: Icons.palette,
  ),
];

// ─── Estado del tema ───────────────────────────────────────────────────────

class ThemeState {
  final ThemeMode mode;
  final Color seedColor;

  const ThemeState({
    this.mode = ThemeMode.system,
    this.seedColor = const Color(0xFF6366F1), // Indigo por defecto
  });

  ThemeState copyWith({ThemeMode? mode, Color? seedColor}) {
    return ThemeState(
      mode: mode ?? this.mode,
      seedColor: seedColor ?? this.seedColor,
    );
  }

  String get colorThemeId {
    for (final t in kAvailableThemes) {
      if (t.seed.toARGB32() == seedColor.toARGB32()) return t.id;
    }
    return 'indigo';
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(const ThemeState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_kThemeMode) ?? 'system';
    final colorVal = prefs.getInt(_kSeedColor) ?? const Color(0xFF6366F1).toARGB32();

    state = ThemeState(
      mode: _parseMode(modeStr),
      seedColor: Color(colorVal),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, _modeToStr(mode));
  }

  Future<void> setSeedColor(Color color) async {
    state = state.copyWith(seedColor: color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSeedColor, color.toARGB32());
  }

  ThemeMode _parseMode(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _modeToStr(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>(
  (ref) => ThemeNotifier(),
);

// Convenience: computed themes based on state
final lightThemeProvider = Provider<ThemeData>((ref) {
  final seed = ref.watch(themeProvider).seedColor;
  return AppTheme.buildLight(seed);
});

final darkThemeProvider = Provider<ThemeData>((ref) {
  final seed = ref.watch(themeProvider).seedColor;
  return AppTheme.buildDark(seed);
});
