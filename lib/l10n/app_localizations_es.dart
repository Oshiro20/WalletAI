// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'WalletAI';

  @override
  String get homeGreeting => 'Hola';

  @override
  String get totalBalance => 'Saldo Total';

  @override
  String get income => 'Ingresos';

  @override
  String get expenses => 'Gastos';

  @override
  String get recentTransactions => 'Transacciones Recientes';

  @override
  String get seeAll => 'Ver todas';

  @override
  String get addTransaction => 'Agregar Transacción';

  @override
  String get tooltipCustomize => 'Personalizar';

  @override
  String get showcaseFabTitle => '¡Empieza aquí!';

  @override
  String get showcaseFabDesc => 'Registra tu primer ingreso o gasto.';

  @override
  String get actionNew => 'Nueva';

  @override
  String get balanceAvailable => 'Disponible';

  @override
  String get showcaseSummaryTitle => 'Resumen Mensual';

  @override
  String get showcaseSummaryDesc => 'Toca para ver el detalle de tus finanzas.';

  @override
  String get transactionsTitle => 'Transacciones';

  @override
  String get showcaseFiltersTitle => 'Filtros Avanzados';

  @override
  String get showcaseFiltersDesc => 'Filtra por fecha, categoría o tipo.';

  @override
  String get filterAll => 'Todo';

  @override
  String get filterExpense => 'Gastos';

  @override
  String get filterIncome => 'Ingresos';

  @override
  String get filterTransfer => 'Transferencias';

  @override
  String get total => 'Total';

  @override
  String get deleteTransactionTitle => 'Eliminar transacción';

  @override
  String get deleteTransactionConfirm =>
      '¿Estás seguro? Esta acción no se puede deshacer.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get transactionDeleted => 'Transacción eliminada';

  @override
  String get noDescription => 'Sin descripción';

  @override
  String get selectPeriod => 'Seleccionar Periodo';

  @override
  String get edit => 'Editar';

  @override
  String get confirmDelete => '¿Estás seguro?';
}
