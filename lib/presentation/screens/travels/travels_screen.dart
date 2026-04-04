import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/database/drift_database.dart';
import '../../providers/database_providers.dart';

class TravelsScreen extends ConsumerWidget {
  const TravelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final travelsAsync = ref.watch(allTravelsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gestor de Viajes')),
      body: travelsAsync.when(
        data: (travels) {
          if (travels.isEmpty) {
            return const Center(child: Text('No has registrado ningún viaje.'));
          }
          return ListView.builder(
            itemCount: travels.length,
            itemBuilder: (context, index) {
              final travel = travels[index];
              final dateFormat = DateFormat('dd/MM/yy');
              final isPast = travel.endDate.isBefore(DateTime.now());

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: travel.isActive
                        ? Theme.of(context).primaryColor
                        : Colors.transparent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    travel.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${dateFormat.format(travel.startDate)} - ${dateFormat.format(travel.endDate)}\nPresupuesto: ${travel.budget.toStringAsFixed(2)} ${travel.baseCurrency}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (travel.isActive)
                        const Chip(
                          label: Text(
                            'Activo',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                          backgroundColor: Colors.green,
                        )
                      else if (isPast)
                        const Chip(
                          label: Text(
                            'Finalizado',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                          backgroundColor: Colors.grey,
                        ),

                      PopupMenuButton<String>(
                        onSelected: (val) {
                          if (val == 'activate') {
                            _showActivationDialog(context, ref, travel);
                          } else if (val == 'finish') {
                            _showDeactivationDialog(context, ref, travel);
                          } else if (val == 'delete') {
                            _showDeleteDialog(context, ref, travel);
                          }
                        },
                        itemBuilder: (ctx) => [
                          if (!travel.isActive && !isPast)
                            const PopupMenuItem(
                              value: 'activate',
                              child: Text('Activar Viaje'),
                            ),
                          if (travel.isActive)
                            const PopupMenuItem(
                              value: 'finish',
                              child: Text('Finalizar Viaje'),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Eliminar',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => context.push('/travels/${travel.id}'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/travels/create'),
        icon: const Icon(Icons.flight_takeoff),
        label: const Text('Nuevo Viaje'),
      ),
    );
  }

  void _showActivationDialog(
    BuildContext context,
    WidgetRef ref,
    Travel travel,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Activar Viaje?'),
        content: Text(
          'Si activas "${travel.name}", todos los gastos nuevos que registres se asignarán automáticamente a este viaje.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(travelsDaoProvider).setActiveTravel(travel.id);
              Navigator.pop(ctx);
            },
            child: const Text('Activar'),
          ),
        ],
      ),
    );
  }

  void _showDeactivationDialog(
    BuildContext context,
    WidgetRef ref,
    Travel travel,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Finalizar Viaje?'),
        content: Text(
          'Estás a punto de desactivar "${travel.name}". Los gastos futuros volverán a registrarse de forma normal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(travelsDaoProvider).deactivateAllTravels();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, finalizar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Travel travel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Viaje?'),
        content: Text(
          'Estás a punto de eliminar "${travel.name}". Esto NO borrará las transacciones asociadas, pero perderás la información del viaje. ¿Estás seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(travelsDaoProvider).deleteTravel(travel.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
