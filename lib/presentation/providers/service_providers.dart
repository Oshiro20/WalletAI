import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/receipt_scanner_service.dart';
import '../../data/datasources/legacy_import_service.dart';
import '../../data/datasources/transaction_parser_service.dart';
import '../../data/datasources/voice_service.dart';
import '../../data/datasources/groq_service.dart';
import 'database_providers.dart';

final receiptScannerServiceProvider = Provider<ReceiptScannerService>((ref) {
  final service = ReceiptScannerService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final legacyImportServiceProvider = Provider<LegacyImportService>((ref) {
  final db = ref.watch(databaseProvider);
  return LegacyImportService(db);
});

final transactionParserServiceProvider = Provider<TransactionParserService>((ref) {
  return TransactionParserService();
});

final voiceServiceProvider = Provider<VoiceService>((ref) {
  return VoiceService();
});

final groqServiceProvider = Provider<GroqService>((ref) {
  return GroqService();
});
