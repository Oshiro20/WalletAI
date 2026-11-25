import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Complementa `LearningRulesDao` recordando también la subcategoría
/// (y opcionalmente la cuenta habitual) aprendida para cada producto/comercio
/// sin requerir migración de esquema SQLite.
class SubcategoryLearningService {
  static const _prefsKey = 'walletai_product_subcategory_rules_v1';

  static String _normalize(String raw) => raw
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll(RegExp(r'\s+'), ' ');

  static Future<Map<String, dynamic>> _loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveRule({
    required String productName,
    String? subcategoryId,
    String? accountId,
  }) async {
    final key = _normalize(productName);
    if (key.isEmpty) return;
    if (subcategoryId == null && accountId == null) return;
    try {
      final all = await _loadAll();
      final existing = all[key] is Map
          ? Map<String, dynamic>.from(all[key] as Map)
          : <String, dynamic>{};
      if (subcategoryId != null) existing['subcategoryId'] = subcategoryId;
      if (accountId != null) existing['accountId'] = accountId;
      existing['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
      all[key] = existing;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(all));
    } catch (_) {}
  }

  static Future<({String? subcategoryId, String? accountId})> getRule(
    String productName,
  ) async {
    final key = _normalize(productName);
    if (key.isEmpty) return (subcategoryId: null, accountId: null);
    final all = await _loadAll();
    final entry = all[key];
    if (entry is Map) {
      return (
        subcategoryId: entry['subcategoryId']?.toString(),
        accountId: entry['accountId']?.toString(),
      );
    }
    return (subcategoryId: null, accountId: null);
  }
}
