import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('es')];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'WalletAI'**
  String get appTitle;

  /// No description provided for @homeGreeting.
  ///
  /// In es, this message translates to:
  /// **'Hola'**
  String get homeGreeting;

  /// No description provided for @totalBalance.
  ///
  /// In es, this message translates to:
  /// **'Saldo Total'**
  String get totalBalance;

  /// No description provided for @income.
  ///
  /// In es, this message translates to:
  /// **'Ingresos'**
  String get income;

  /// No description provided for @expenses.
  ///
  /// In es, this message translates to:
  /// **'Gastos'**
  String get expenses;

  /// No description provided for @recentTransactions.
  ///
  /// In es, this message translates to:
  /// **'Transacciones Recientes'**
  String get recentTransactions;

  /// No description provided for @seeAll.
  ///
  /// In es, this message translates to:
  /// **'Ver todas'**
  String get seeAll;

  /// No description provided for @addTransaction.
  ///
  /// In es, this message translates to:
  /// **'Agregar Transacción'**
  String get addTransaction;

  /// No description provided for @tooltipCustomize.
  ///
  /// In es, this message translates to:
  /// **'Personalizar'**
  String get tooltipCustomize;

  /// No description provided for @showcaseFabTitle.
  ///
  /// In es, this message translates to:
  /// **'¡Empieza aquí!'**
  String get showcaseFabTitle;

  /// No description provided for @showcaseFabDesc.
  ///
  /// In es, this message translates to:
  /// **'Registra tu primer ingreso o gasto.'**
  String get showcaseFabDesc;

  /// No description provided for @actionNew.
  ///
  /// In es, this message translates to:
  /// **'Nueva'**
  String get actionNew;

  /// No description provided for @balanceAvailable.
  ///
  /// In es, this message translates to:
  /// **'Disponible'**
  String get balanceAvailable;

  /// No description provided for @showcaseSummaryTitle.
  ///
  /// In es, this message translates to:
  /// **'Resumen Mensual'**
  String get showcaseSummaryTitle;

  /// No description provided for @showcaseSummaryDesc.
  ///
  /// In es, this message translates to:
  /// **'Toca para ver el detalle de tus finanzas.'**
  String get showcaseSummaryDesc;

  /// No description provided for @transactionsTitle.
  ///
  /// In es, this message translates to:
  /// **'Transacciones'**
  String get transactionsTitle;

  /// No description provided for @showcaseFiltersTitle.
  ///
  /// In es, this message translates to:
  /// **'Filtros Avanzados'**
  String get showcaseFiltersTitle;

  /// No description provided for @showcaseFiltersDesc.
  ///
  /// In es, this message translates to:
  /// **'Filtra por fecha, categoría o tipo.'**
  String get showcaseFiltersDesc;

  /// No description provided for @filterAll.
  ///
  /// In es, this message translates to:
  /// **'Todo'**
  String get filterAll;

  /// No description provided for @filterExpense.
  ///
  /// In es, this message translates to:
  /// **'Gastos'**
  String get filterExpense;

  /// No description provided for @filterIncome.
  ///
  /// In es, this message translates to:
  /// **'Ingresos'**
  String get filterIncome;

  /// No description provided for @filterTransfer.
  ///
  /// In es, this message translates to:
  /// **'Transferencias'**
  String get filterTransfer;

  /// No description provided for @total.
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @deleteTransactionTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar transacción'**
  String get deleteTransactionTitle;

  /// No description provided for @deleteTransactionConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro? Esta acción no se puede deshacer.'**
  String get deleteTransactionConfirm;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @transactionDeleted.
  ///
  /// In es, this message translates to:
  /// **'Transacción eliminada'**
  String get transactionDeleted;

  /// No description provided for @noDescription.
  ///
  /// In es, this message translates to:
  /// **'Sin descripción'**
  String get noDescription;

  /// No description provided for @selectPeriod.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar Periodo'**
  String get selectPeriod;

  /// No description provided for @edit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get edit;

  /// No description provided for @confirmDelete.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro?'**
  String get confirmDelete;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
