import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_ai/core/services/subcategory_learning_service.dart';
import 'package:wallet_ai/core/services/update_service.dart';
import 'package:wallet_ai/data/database/drift_database.dart';
import 'package:wallet_ai/data/datasources/groq_service.dart';
import 'package:wallet_ai/data/datasources/transaction_parser_service.dart';

void main() {
  group('UpdateService.isVersionGreater', () {
    test('compara versiones con prefijo v y sufijos +build/-pre', () {
      expect(UpdateService.isVersionGreater('v1.4.2', '1.4.1+24'), isTrue);
      expect(UpdateService.isVersionGreater('v1.4.10', '1.4.2'), isTrue);
      expect(UpdateService.isVersionGreater('v1.4.2-beta', '1.4.2'), isFalse);
      expect(UpdateService.isVersionGreater('v1.4.1', '1.4.1'), isFalse);
    });
  });

  group('GroqService.decodeJsonObject', () {
    test('limpia bloques markdown y extrae JSON válido de respuesta de voz', () {
      const raw = '''Aquí está la transacción:
```json
{
  "tipo": "expense",
  "monto": 24.5,
  "moneda": "PEN",
  "descripcion": "Mercado",
  "producto": "Pollo",
  "cantidad": 2,
  "unidad": "KG",
  "categoria_sugerida": "Alimentación",
  "cuenta_sugerida": "BCP",
  "cuenta_destino_sugerida": null,
  "fecha": "2026-11-16",
  "cuotas": 1
}
```''';

      final parsed = GroqService.decodeJsonObject(raw);
      expect(parsed, isNotNull);
      expect(parsed!['monto'], 24.5);
      expect(parsed['cuenta_sugerida'], 'BCP');
      expect(parsed['cantidad'], 2);
      expect(parsed['unidad'], 'KG');
    });

    test('retorna null ante contenido no JSON', () {
      expect(GroqService.decodeJsonObject('No entendí el audio'), isNull);
    });
  });

  group('TransactionParserService (resolución local rápida)', () {
    final parser = TransactionParserService();
    final categories = [
      Category(
        id: 'cat_alimentacion',
        name: 'Alimentación',
        type: 'expense',
        icon: '🍔',
        color: '#00C896',
        isSystem: true,
        sortOrder: 0,
        createdAt: DateTime(2026),
      ),
    ];
    final accounts = [
      Account(
        id: 'acc_bcp',
        name: 'BCP',
        type: 'bank',
        balance: 500,
        currency: 'PEN',
        color: '#0000FF',
        icon: 'bank',
        sortOrder: 0,
        isActive: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ];

    test('extrae monto monetario sin confundirlo con cantidad y marca alta confianza',
        () {
      final parsed = parser.parse(
        'Compré 2 kilos de pollo a 24.5 soles con BCP',
        categories,
        accounts,
      );

      expect(parsed.amount, 24.5);
      expect(parsed.quantity, 2.0);
      expect(parsed.unit, 'KG');
      expect(parsed.currency, 'PEN');
      expect(parsed.accountId, 'acc_bcp');
      expect(parsed.categoryId, 'cat_alimentacion');
      expect(parsed.isComplexPhrase, isFalse);
      expect(parsed.isHighConfidence, isTrue);
    });

    test('detecta frases con cuotas o transferencia como complejas para usar IA',
        () {
      final parsed = parser.parse(
        'Pagué 300 soles en 3 cuotas ayer con BCP',
        categories,
        accounts,
      );

      expect(parsed.amount, 300.0);
      expect(parsed.isComplexPhrase, isTrue);
      expect(parsed.isHighConfidence, isFalse);
    });
  });

  group('SubcategoryLearningService & AiCategoryPrediction', () {
    test('persiste y recupera subcategoría y cuenta aprendida por producto', () async {
      SharedPreferences.setMockInitialValues({});
      await SubcategoryLearningService.saveRule(
        productName: '  Creatina Monohidratada  ',
        subcategoryId: 'sub_suplementos',
        accountId: 'acc_yape',
      );
      final loaded = await SubcategoryLearningService.getRule(
        'creatina monohidratada',
      );
      expect(loaded.subcategoryId, 'sub_suplementos');
      expect(loaded.accountId, 'acc_yape');

      const sug = AiCategoryPrediction(
        categoryName: 'Deporte/Fitness',
        subcategoryName: 'Suplementos',
        isNewSubcategory: true,
      );
      expect(sug.hasNewSuggestion, isTrue);
    });
  });
}
