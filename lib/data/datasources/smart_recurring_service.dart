import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../presentation/providers/database_providers.dart';
import '../database/drift_database.dart';

// ─── Modelos ──────────────────────────────────────────────────────────────────

/// Un patrón detectado de posible pago recurrente.
class RecurringSuggestion {
  final String name; // Descripción limpia
  final double amount; // Monto promedio
  final String frequency; // 'monthly' | 'weekly' | 'biweekly'
  final String? categoryId; // Categoría más frecuente
  final String? accountId; // Cuenta más frecuente
  final DateTime lastSeen; // Última vez que apareció
  final int occurrences; // Cuántas veces se detectó
  final double confidence; // 0.0–1.0

  const RecurringSuggestion({
    required this.name,
    required this.amount,
    required this.frequency,
    this.categoryId,
    this.accountId,
    required this.lastSeen,
    required this.occurrences,
    required this.confidence,
  });

  String get frequencyLabel {
    switch (frequency) {
      case 'weekly':
        return 'Semanal';
      case 'biweekly':
        return 'Quincenal';
      case 'monthly':
        return 'Mensual';
      case 'yearly':
        return 'Anual';
      default:
        return frequency;
    }
  }

  String get confidenceLabel {
    if (confidence >= 0.8) return 'Alta';
    if (confidence >= 0.5) return 'Media';
    return 'Baja';
  }
}

// ─── Servicio ─────────────────────────────────────────────────────────────────

class SmartRecurringService {
  final Ref ref;

  SmartRecurringService(this.ref);

  /// Analiza el historial de transacciones y devuelve sugerencias de recurrentes.
  ///
  /// Algoritmo:
  ///  1. Carga transacciones de los últimos [lookbackDays] días.
  ///  2. Agrupa por descripción normalizada.
  ///  3. Para cada grupo con 2+ ocurrencias, calcula el intervalo promedio.
  ///  4. Si el intervalo encaja con weekly/biweekly/monthly, genera la sugerencia.
  ///  5. Excluye transacciones que ya están registradas como recurrentes.
  Future<List<RecurringSuggestion>> detectSuggestions({
    int lookbackDays = 90,
  }) async {
    try {
      final db = ref.read(databaseProvider);

      // 1. Leer transacciones recientes (solo gastos e ingresos, no transferencias)
      final since = DateTime.now().subtract(Duration(days: lookbackDays));
      final allTxs = await (db.select(
        db.transactions,
      )..where((t) => t.type.isNotIn(['transfer']))).get();

      // Filtrar por fecha y ordenar en Dart (evitar limitaciones de API de columna DateTime)
      final transactions = allTxs.where((t) => t.date.isAfter(since)).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      // 2. Leer recurrentes existentes para excluirlos
      final existingRecurring = await db.select(db.recurringPayments).get();
      final existingNames = existingRecurring
          .map((r) => _normalize(r.name))
          .toSet();

      // 3. Agrupar por descripción normalizada
      final Map<String, List<Transaction>> groups = {};
      for (final t in transactions) {
        final desc = t.description ?? '';
        if (desc.isEmpty || desc.length < 3) continue;
        final key = _normalize(desc);
        if (existingNames.contains(key)) continue;
        groups.putIfAbsent(key, () => []).add(t);
      }

      // 4. Analizar cada grupo
      final suggestions = <RecurringSuggestion>[];
      for (final entry in groups.entries) {
        final group = entry.value;
        if (group.length < 2) continue;

        final suggestion = _analyzeGroup(entry.key, group);
        if (suggestion != null) suggestions.add(suggestion);
      }

      // Ordenar por confianza descendente
      suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));
      return suggestions.take(10).toList();
    } catch (e) {
      debugPrint('SmartRecurringService.detectSuggestions: $e');
      return [];
    }
  }

  /// Convierte una sugerencia en un pago recurrente real.
  Future<void> acceptSuggestion(RecurringSuggestion suggestion) async {
    final dao = ref.read(recurringPaymentsDaoProvider);
    final nextDue = _inferNextDate(suggestion.lastSeen, suggestion.frequency);

    await dao.createRecurringPayment(
      RecurringPaymentsCompanion.insert(
        id: const Uuid().v4(),
        name: suggestion.name,
        amount: suggestion.amount,
        accountId: suggestion.accountId ?? '',
        categoryId: Value(suggestion.categoryId),
        frequency: suggestion.frequency == 'biweekly'
            ? 'weekly'
            : suggestion.frequency,
        nextDueDate: nextDue,
        createdAt: DateTime.now(),
      ),
    );
  }

  // ─── Helpers Privados ───────────────────────────────────────────────────────

  RecurringSuggestion? _analyzeGroup(
    String normalizedKey,
    List<Transaction> txs,
  ) {
    if (txs.length < 2) return null;

    // Calcular intervalos en días entre ocurrencias consecutivas
    final dates = txs.map((t) => t.date).toList()..sort();
    final intervals = <double>[];
    for (int i = 1; i < dates.length; i++) {
      intervals.add(dates[i].difference(dates[i - 1]).inDays.toDouble());
    }

    final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    final stdDev = _stdDev(intervals, avgInterval);

    // Detectar frecuencia según el intervalo promedio
    String? frequency;
    double baseConfidence;

    if (avgInterval >= 6 && avgInterval <= 9) {
      frequency = 'weekly';
      baseConfidence = 0.9;
    } else if (avgInterval >= 12 && avgInterval <= 18) {
      frequency = 'biweekly';
      baseConfidence = 0.75;
    } else if (avgInterval >= 25 && avgInterval <= 35) {
      frequency = 'monthly';
      baseConfidence = 0.85;
    } else if (avgInterval >= 340 && avgInterval <= 390) {
      frequency = 'yearly';
      baseConfidence = 0.7;
    } else {
      return null; // Intervalo no reconocido
    }

    // Penalizar por variabilidad alta en el intervalo
    final variabilityPenalty = (stdDev / avgInterval).clamp(0.0, 0.5);
    final occurrenceBonus = ((txs.length - 2) * 0.05).clamp(0.0, 0.2);
    final confidence = (baseConfidence - variabilityPenalty + occurrenceBonus)
        .clamp(0.2, 1.0);

    if (confidence < 0.3) {
      return null; // Descarta sugerencias de muy baja confianza
    }

    // Calcular monto promedio (excluir outliers simples)
    final amounts = txs.map((t) => t.amount.abs()).toList()..sort();
    final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;

    // Categoría y cuenta más frecuente
    final catFreq = <String, int>{};
    final accFreq = <String, int>{};
    for (final t in txs) {
      if (t.categoryId != null) {
        catFreq[t.categoryId!] = (catFreq[t.categoryId!] ?? 0) + 1;
      }
      accFreq[t.accountId] = (accFreq[t.accountId] ?? 0) + 1;
    }

    final topCat = catFreq.isEmpty
        ? null
        : catFreq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final topAcc = accFreq.isEmpty
        ? null
        : accFreq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    // Capitalizar el nombre limpio
    final displayName = _capitalizeName(normalizedKey);

    return RecurringSuggestion(
      name: displayName,
      amount: double.parse(avgAmount.toStringAsFixed(2)),
      frequency: frequency,
      categoryId: topCat,
      accountId: topAcc,
      lastSeen: dates.last,
      occurrences: txs.length,
      confidence: confidence,
    );
  }

  /// Normaliza una descripción: minúsculas, sin números, sin caracteres especiales.
  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[\d#*\/\-_.,;:!?@]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _capitalizeName(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  double _stdDev(List<double> values, double mean) {
    if (values.length < 2) return 0;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
        values.length;
    return variance <= 0 ? 0 : variance;
  }

  DateTime _inferNextDate(DateTime lastSeen, String frequency) {
    switch (frequency) {
      case 'weekly':
        return lastSeen.add(const Duration(days: 7));
      case 'biweekly':
        return lastSeen.add(const Duration(days: 14));
      case 'monthly':
        return DateTime(lastSeen.year, lastSeen.month + 1, lastSeen.day);
      case 'yearly':
        return DateTime(lastSeen.year + 1, lastSeen.month, lastSeen.day);
      default:
        return DateTime.now().add(const Duration(days: 30));
    }
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final smartRecurringServiceProvider = Provider(
  (ref) => SmartRecurringService(ref),
);

final recurringFromHistory = FutureProvider<List<RecurringSuggestion>>((
  ref,
) async {
  final service = ref.watch(smartRecurringServiceProvider);
  return service.detectSuggestions();
});
