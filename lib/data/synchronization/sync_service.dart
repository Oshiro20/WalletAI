import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/database_providers.dart';
import '../database/drift_database.dart';

class SyncService {
  final Ref ref;

  SyncService(this.ref);

  /// Sincronizar items pendientes
  Future<void> syncPendingItems() async {
    final dao = ref.read(syncQueueDaoProvider);
    final pendingItems = await dao.getPendingItems();

    if (pendingItems.isEmpty) return;

    // Simular procesamiento del backend
    for (final item in pendingItems) {
      try {
        await _processItem(item);
        await dao.markAsSynced(item.id);
      } catch (e) {
        // En un caso real, manejar reintento o error
        debugPrint('Error syncing item ${item.id}: $e');
      }
    }
  }

  Future<void> _processItem(SyncQueueItem item) async {
    // Simular delay de red
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint('Synced item: ${item.targetTable} - ${item.operation} - ${item.recordId}');
  }
}

final syncServiceProvider = Provider((ref) => SyncService(ref));
