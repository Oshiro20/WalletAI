import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../data/datasources/excel_service.dart';
import '../../providers/database_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'General'),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Categorías'),
            subtitle: const Text('Administra tus categorías y subcategorías'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/categories');
            },
          ),
          ListTile(
            leading: const Icon(Icons.loop),
            title: const Text('Pagos Recurrentes'),
            subtitle: const Text('Administra tus suscripciones y pagos fijos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/recurring');
            },
          ),
          const Divider(),
          _buildSectionHeader(context, '💡 Asesor Financiero'),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Presupuestos'),
            subtitle: const Text('Define límites de gasto por categoría'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/budgets'),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Metas de Ahorro'),
            subtitle: const Text('Sigue el progreso hacia tus objetivos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/savings'),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Reporte PDF Mensual'),
            subtitle: const Text('Genera y comparte tu resumen financiero'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/reports/pdf'),
          ),
          ListTile(
            leading: const Icon(Icons.flight_outlined),
            title: const Text('Viajes Especiales'),
            subtitle: const Text('Agrupa gastos con presupuestos separados'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/travels'),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Datos'),
          ListTile(
            leading: const Icon(
              Icons.file_download_outlined,
            ), // Icono de descarga
            title: const Text('Descargar Plantilla Excel'),
            subtitle: const Text('Obtén el formato correcto para importar'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              try {
                final file = await ref
                    .read(excelServiceProvider)
                    .generateTemplate();
                // Usamos Share para "descargar"/enviar el archivo
                await Share.shareXFiles([
                  XFile(file.path),
                ], text: 'Plantilla de Gastos');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al generar plantilla: $e')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined), // Icono de subida
            title: const Text('Importar desde Excel'),
            subtitle: const Text('Carga masiva con soporte para subcategorías'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['xlsx'],
                );

                if (result != null && result.files.single.path != null) {
                  final file = File(result.files.single.path!);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Procesando archivo...')),
                    );
                  }

                  final count = await ref
                      .read(excelServiceProvider)
                      .importTransactions(file);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '¡Éxito! Se importaron $count transacciones',
                        ),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al importar: $e')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.file_upload_outlined,
            ), // Icono de exportar (subir a nube/compartir)
            title: const Text('Exportar a Excel'),
            subtitle: const Text('Copia de seguridad de tus datos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              try {
                final file = await ref
                    .read(excelServiceProvider)
                    .exportTransactions();
                await Share.shareXFiles([
                  XFile(file.path),
                ], text: 'Mis Transacciones');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al exportar: $e')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_done_outlined),
            title: const Text('Copias de Seguridad'),
            subtitle: const Text('Local, Google Drive y compartir'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/backup'),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Herramientas'),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Conversor de Moneda'),
            subtitle: const Text('Tasas de cambio en tiempo real'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/currency'),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Aplicación'),
          ListTile(
            leading: const Icon(Icons.dashboard_customize_outlined),
            title: const Text('Personalizar Dashboard'),
            subtitle: const Text('Ordena y oculta los widgets del inicio'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/dashboard/customize'),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Integración MyLifeOS'),
            subtitle: const Text('Conecta con tu app personal'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/mylifeos'),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Apariencia'),
            subtitle: const Text('Modo oscuro y color de acento'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/theme'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notificaciones'),
            subtitle: const Text('Recordatorio diario y alertas'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/notifications'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Acerca de WalletAI'),
            onTap: () => context.push('/about'),
          ),
          const Divider(),
          // ZONA DE PELIGRO
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Zona de Peligro',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.orange),
            title: const Text('Borrar Solo Transacciones'),
            subtitle: const Text('Mantiene Cuentas y Categorías'),
            onTap: () => _confirmReset(context, ref, 'transactions'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.deepOrange),
            title: const Text('Borrar Transacciones y Categorías'),
            subtitle: const Text('Mantiene solo tus Cuentas'),
            onTap: () => _confirmReset(context, ref, 'trans_cats'),
          ),
          ListTile(
            leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
            title: const Text('Restablecer Todo (Fábrica)'),
            subtitle: const Text('Borra TODOS los datos de la app'),
            onTap: () => _confirmReset(context, ref, 'all'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    WidgetRef ref,
    String type,
  ) async {
    String title = '';
    String content = '';

    switch (type) {
      case 'transactions':
        title = '¿Borrar solo transacciones?';
        content =
            'Se eliminarán todos los ingresos y gastos. Tus cuentas y categorías se mantendrán.';
        break;
      case 'trans_cats':
        title = '¿Borrar transacciones y categorías?';
        content =
            'Se eliminarán transacciones y categorías personalizadas. Tus cuentas (bancos, efectivo) se mantendrán.';
        break;
      case 'all':
        title = '¿RESTABLECER TODO?';
        content =
            '¡Acción irreversible! Se borrarán cuentas, categorías, transacciones y configuraciones. La app quedará como nueva.';
        break;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('BORRAR DATOS'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await _performReset(context, ref, type);
    }
  }

  Future<void> _performReset(
    BuildContext context,
    WidgetRef ref,
    String type,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Providers
    final transactionsDao = ref.read(transactionsDaoProvider);
    final categoriesDao = ref.read(categoriesDaoProvider);
    final accountsDao = ref.read(accountsDaoProvider);

    try {
      if (type == 'transactions' || type == 'trans_cats' || type == 'all') {
        await transactionsDao.deleteAllTransactions();
        // También resetear pagos recurrentes? Generalmente transacciones van ligadas.
        // El usuario pidió "Borrar Solo Transacciones", recurrentes son "futuras".
        // Dejémoslo opcional, pero "Restablecer Todo" sí debe borrar recurrentes.
      }

      if (type == 'trans_cats' || type == 'all') {
        await categoriesDao.deleteAllSubcategories(); // Primero hijos
        await categoriesDao.deleteAllCategories();
      }

      if (type == 'all') {
        await accountsDao.deleteAllAccounts();
        await ref
            .read(recurringPaymentsDaoProvider)
            .deleteAllRecurringPayments();
      }

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Operación completada con éxito')),
      );

      // Force UI refresh by invalidating providers
      ref.invalidate(totalBalanceProvider);
      ref.invalidate(currentMonthBalanceProvider);
      ref.invalidate(currentMonthIncomeProvider);
      ref.invalidate(currentMonthExpensesProvider);
      ref.invalidate(analyticsSummaryProvider);
      ref.invalidate(transactionsStreamProvider);
      ref.invalidate(accountsStreamProvider);
      // Also invalidate filtered providers if being used
      ref.invalidate(filteredTransactionsProvider);
      ref.invalidate(filteredBalanceProvider);

      // If we are on Home Screen, these invalidations will trigger a re-fetch.
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error al borrar datos: $e')),
      );
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
