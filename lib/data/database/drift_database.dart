import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// Importar todas las tablas
import 'tables/accounts_table.dart';
import 'tables/transactions_table.dart';
import 'tables/categories_table.dart';
import 'tables/subcategories_table.dart';
import 'tables/budgets_table.dart';
import 'tables/savings_goals_table.dart';
import 'tables/recurring_payments_table.dart';
import 'tables/tags_table.dart';
import 'tables/transaction_tags_table.dart';
import 'tables/attachments_table.dart';
import 'tables/contexts_table.dart';
import 'tables/sync_queue_table.dart';
import 'tables/settings_table.dart';
import 'tables/travels_table.dart';
import 'tables/learning_rules_table.dart';

// Importar DAOs
import 'daos/accounts_dao.dart';
import 'daos/transactions_dao.dart';
import 'daos/categories_dao.dart';
import 'daos/budgets_dao.dart';
import 'daos/savings_goals_dao.dart';
import 'daos/recurring_payments_dao.dart';
import 'daos/subcategories_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'daos/travels_dao.dart';
import 'daos/learning_rules_dao.dart';

part 'drift_database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Transactions,
    Categories,
    Subcategories,
    Budgets,
    SavingsGoals,
    RecurringPayments,
    Tags,
    TransactionTags,
    Attachments,
    Contexts,
    SyncQueue,
    Settings,
    Travels,
    LearningRules,
  ],
  daos: [
    AccountsDao,
    TransactionsDao,
    CategoriesDao,
    BudgetsDao,
    SavingsGoalsDao,
    RecurringPaymentsDao,
    SubcategoriesDao,
    SyncQueueDao,
    TravelsDao,
    LearningRulesDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _insertDefaultCategories();
      await _insertDefaultSubcategories();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        try {
          await m.addColumn(accounts, accounts.closingDay);
        } catch (_) {}
        try {
          await m.addColumn(accounts, accounts.paymentDueDay);
        } catch (_) {}
      }
      if (from < 3) {
        await _insertDefaultSubcategories();
      }
      if (from < 4) {
        // Agregar columna aliases a categorías
        try {
          await m.addColumn(categories, categories.aliases);
        } catch (_) {}
      }
      if (from < 5) {
        // Insertar nuevas subcategorías: Delivery, Estacionamiento, Gimnasio, Juegos/Apps
        await _insertDefaultSubcategories();
      }
      if (from < 6) {
        // Agregar columnas GPS a transacciones
        try {
          await m.addColumn(transactions, transactions.latitude);
        } catch (_) {}
        try {
          await m.addColumn(transactions, transactions.longitude);
        } catch (_) {}
        try {
          await m.addColumn(transactions, transactions.locationName);
        } catch (_) {}
      }
      if (from < 7) {
        // Ola 3: Multi-moneda
        try {
          await m.addColumn(transactions, transactions.currency);
        } catch (_) {}
      }
      if (from < 8) {
        // Ola 4: Expansión de categorías (Deporte, Vehículo, Viajes, Regalos, Inversiones)
        await _insertNewCategoriesV8();
        await _insertDefaultSubcategories();
      }
      if (from < 9) {
        // v1.15: Campo nombre del producto en transacciones
        try {
          await m.addColumn(transactions, transactions.productName);
        } catch (_) {}
      }
      if (from < 10) {
        // Ola 5: Tabla de Viajes
        try {
          await m.createTable(travels);
        } catch (_) {}
      }
      if (from < 11) {
        // Ola 6: Aprendizaje y Unidades
        try {
          await m.addColumn(transactions, transactions.quantity);
        } catch (_) {}
        try {
          await m.addColumn(transactions, transactions.unit);
        } catch (_) {}
        try {
          await m.createTable(learningRules);
        } catch (_) {}
      }
    },
  );

  /// Insertar/actualizar todas las subcategorías predefinidas
  Future<void> _insertDefaultSubcategories() async {
    final now = DateTime.now();
    final subcategoriesList = [
      // ── ALIMENTACIÓN ──────────────────────────────────────
      SubcategoriesCompanion.insert(
        id: 'sub_mercado',
        categoryId: 'cat_alimentacion',
        name: 'Mercado/Supermercado',
        icon: const Value('🛒'),
        sortOrder: const Value(1),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_restaurantes',
        categoryId: 'cat_alimentacion',
        name: 'Restaurante',
        icon: const Value('🍽️'),
        sortOrder: const Value(2),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_delivery',
        categoryId: 'cat_alimentacion',
        name: 'Delivery',
        icon: const Value('🛵'),
        sortOrder: const Value(3),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_snacks',
        categoryId: 'cat_antojos',
        name: 'Snacks/Antojos',
        icon: const Value('🍭'),
        sortOrder: const Value(1),
        createdAt: now,
      ),
      // ── TRANSPORTE ────────────────────────────────────────
      SubcategoriesCompanion.insert(
        id: 'sub_publico',
        categoryId: 'cat_transporte',
        name: 'Transporte Público',
        icon: const Value('🚌'),
        sortOrder: const Value(1),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_taxi',
        categoryId: 'cat_transporte',
        name: 'Taxi/Uber',
        icon: const Value('🚕'),
        sortOrder: const Value(2),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_gasolina',
        categoryId: 'cat_transporte',
        name: 'Gasolina',
        icon: const Value('⛽'),
        sortOrder: const Value(3),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_estacionamiento',
        categoryId: 'cat_transporte',
        name: 'Estacionamiento/Peaje',
        icon: const Value('🅿️'),
        sortOrder: const Value(4),
        createdAt: now,
      ),
      // ── ENTRETENIMIENTO ───────────────────────────────────
      SubcategoriesCompanion.insert(
        id: 'sub_streaming',
        categoryId: 'cat_entretenimiento',
        name: 'Streaming',
        icon: const Value('🎬'),
        sortOrder: const Value(1),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_salidas',
        categoryId: 'cat_entretenimiento',
        name: 'Cine/Salidas',
        icon: const Value('🍿'),
        sortOrder: const Value(2),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_juegos',
        categoryId: 'cat_entretenimiento',
        name: 'Videojuegos',
        icon: const Value('🎮'),
        sortOrder: const Value(3),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_libros_revistas',
        categoryId: 'cat_entretenimiento',
        name: 'Libros/Revistas',
        icon: const Value('📚'),
        sortOrder: const Value(4),
        createdAt: now,
      ),
      // ── SALUD ─────────────────────────────────────────────
      SubcategoriesCompanion.insert(
        id: 'sub_farmacia',
        categoryId: 'cat_salud',
        name: 'Farmacia/Botica',
        icon: const Value('💊'),
        sortOrder: const Value(1),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_citas',
        categoryId: 'cat_salud',
        name: 'Citas Médicas',
        icon: const Value('🩺'),
        sortOrder: const Value(2),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_gym',
        categoryId: 'cat_salud',
        name: 'Gimnasio',
        icon: const Value('🏋️'),
        sortOrder: const Value(3),
        createdAt: now,
      ),
      // ── CUIDADO PERSONAL ──────────────────────────────────
      SubcategoriesCompanion.insert(
        id: 'sub_peluqueria',
        categoryId: 'cat_cuidado_personal',
        name: 'Peluquería/Barbería',
        icon: const Value('✂️'),
        sortOrder: const Value(1),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_higiene',
        categoryId: 'cat_cuidado_personal',
        name: 'Higiene/Cosméticos',
        icon: const Value('🧴'),
        sortOrder: const Value(2),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_estetica',
        categoryId: 'cat_cuidado_personal',
        name: 'Estética',
        icon: const Value('💅'),
        sortOrder: const Value(3),
        createdAt: now,
      ),
      // ── ROPA ──────────────────────────────────────────────
      SubcategoriesCompanion.insert(
        id: 'sub_ropa',
        categoryId: 'cat_ropa',
        name: 'Ropa',
        icon: const Value('👕'),
        sortOrder: const Value(1),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_calzado',
        categoryId: 'cat_ropa',
        name: 'Calzado',
        icon: const Value('👟'),
        sortOrder: const Value(2),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_ropa_deportiva',
        categoryId: 'cat_ropa',
        name: 'Ropa Deportiva',
        icon: const Value('🎽'),
        sortOrder: const Value(3),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_accesorios_moda',
        categoryId: 'cat_ropa',
        name: 'Accesorios de Moda',
        icon: const Value('💍'),
        sortOrder: const Value(4),
        createdAt: now,
      ),
      // ── ALOJAMIENTO/HOGAR ─────────────────────────────────
      SubcategoriesCompanion.insert(
        id: 'sub_servicios_hogar',
        categoryId: 'cat_alojamiento',
        name: 'Servicios del Hogar',
        icon: const Value('💡'),
        sortOrder: const Value(1),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_limpieza_hogar',
        categoryId: 'cat_alojamiento',
        name: 'Limpieza del Hogar',
        icon: const Value('🧹'),
        sortOrder: const Value(2),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_mantenimiento_hogar',
        categoryId: 'cat_alojamiento',
        name: 'Mantenimiento',
        icon: const Value('🔧'),
        sortOrder: const Value(3),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_electrodomesticos',
        categoryId: 'cat_alojamiento',
        name: 'Electrodomésticos',
        icon: const Value('🔌'),
        sortOrder: const Value(4),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_decoracion',
        categoryId: 'cat_alojamiento',
        name: 'Decoración/Muebles',
        icon: const Value('🛋️'),
        sortOrder: const Value(5),
        createdAt: now,
      ),
      // ── DEPORTE/FITNESS ───────────────────────────────────
      SubcategoriesCompanion.insert(
        id: 'sub_membresia_gym',
        categoryId: 'cat_deporte',
        name: 'Membresía Gimnasio',
        icon: const Value('🏋️'),
        sortOrder: const Value(1),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_equipo_deportivo',
        categoryId: 'cat_deporte',
        name: 'Equipamiento Deportivo',
        icon: const Value('⚽'),
        sortOrder: const Value(2),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_clases',
        categoryId: 'cat_deporte',
        name: 'Clases/Actividades',
        icon: const Value('🧘'),
        sortOrder: const Value(3),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_nutricion_deportiva',
        categoryId: 'cat_deporte',
        name: 'Nutrición Deportiva',
        icon: const Value('🥗'),
        sortOrder: const Value(4),
        createdAt: now,
      ),
      // ── VEHÍCULO ──────────────────────────────────────────
      SubcategoriesCompanion.insert(
        id: 'sub_lavado_auto',
        categoryId: 'cat_vehiculo',
        name: 'Lavado de Auto',
        icon: const Value('🚿'),
        sortOrder: const Value(1),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_mecanica',
        categoryId: 'cat_vehiculo',
        name: 'Mecánica/Repuestos',
        icon: const Value('🔩'),
        sortOrder: const Value(2),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_peajes',
        categoryId: 'cat_vehiculo',
        name: 'Peajes/SOAT',
        icon: const Value('🛣️'),
        sortOrder: const Value(3),
        createdAt: now,
      ),
      // ── VIAJES ────────────────────────────────────────────
      SubcategoriesCompanion.insert(
        id: 'sub_pasajes',
        categoryId: 'cat_viajes',
        name: 'Pasajes',
        icon: const Value('🛫'),
        sortOrder: const Value(1),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_hospedaje',
        categoryId: 'cat_viajes',
        name: 'Hospedaje',
        icon: const Value('🏨'),
        sortOrder: const Value(2),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_tours',
        categoryId: 'cat_viajes',
        name: 'Tours/Actividades',
        icon: const Value('🗺️'),
        sortOrder: const Value(3),
        createdAt: now,
      ),
      // ── REGALOS/DONACIONES ────────────────────────────────
      SubcategoriesCompanion.insert(
        id: 'sub_regalos',
        categoryId: 'cat_regalos',
        name: 'Regalos',
        icon: const Value('🎁'),
        sortOrder: const Value(1),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_donaciones',
        categoryId: 'cat_regalos',
        name: 'Donaciones/Propinas',
        icon: const Value('💝'),
        sortOrder: const Value(2),
        createdAt: now,
      ),
      // ── MASCOTAS ──────────────────────────────────────────
      SubcategoriesCompanion.insert(
        id: 'sub_alimento_mascota',
        categoryId: 'cat_mascotas',
        name: 'Alimento',
        icon: const Value('🦴'),
        sortOrder: const Value(1),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_veterinario',
        categoryId: 'cat_mascotas',
        name: 'Veterinario',
        icon: const Value('🩺'),
        sortOrder: const Value(2),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_accesorios_mascota',
        categoryId: 'cat_mascotas',
        name: 'Accesorios/Higiene',
        icon: const Value('🛁'),
        sortOrder: const Value(3),
        createdAt: now,
      ),
      // ── PAREJA ────────────────────────────────────────────
      SubcategoriesCompanion.insert(
        id: 'sub_salida_romantica',
        categoryId: 'cat_pareja',
        name: 'Salida Romántica',
        icon: const Value('🥂'),
        sortOrder: const Value(1),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_regalos_pareja',
        categoryId: 'cat_pareja',
        name: 'Regalos/Detalles',
        icon: const Value('🎀'),
        sortOrder: const Value(2),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_plan_especial',
        categoryId: 'cat_pareja',
        name: 'Plan Especial',
        icon: const Value('💒'),
        sortOrder: const Value(3),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_detalles_dia',
        categoryId: 'cat_pareja',
        name: 'Detalles del Día',
        icon: const Value('☕'),
        sortOrder: const Value(4),
        createdAt: now,
      ),
      // ── INVERSIONES ───────────────────────────────────────
      SubcategoriesCompanion.insert(
        id: 'sub_fondo_ahorro',
        categoryId: 'cat_inversiones',
        name: 'Fondo Mutuo/Ahorro',
        icon: const Value('🏦'),
        sortOrder: const Value(1),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_acciones',
        categoryId: 'cat_inversiones',
        name: 'Acciones/Bolsa',
        icon: const Value('📈'),
        sortOrder: const Value(2),
        createdAt: now,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_cripto',
        categoryId: 'cat_inversiones',
        name: 'Criptomonedas',
        icon: const Value('₿'),
        sortOrder: const Value(3),
        createdAt: now,
      ),
    ];

    await batch((batch) {
      batch.insertAllOnConflictUpdate(subcategories, subcategoriesList);
    });
  }

  /// Insertar nuevas categorías de la versión 8 (para usuarios que actualizan)
  Future<void> _insertNewCategoriesV8() async {
    final now = DateTime.now();
    final newCategories = [
      CategoriesCompanion.insert(
        id: 'cat_deporte',
        name: 'Deporte/Fitness',
        type: 'expense',
        icon: const Value('🏋️'),
        color: const Value('#22C55E'),
        isSystem: const Value(true),
        sortOrder: const Value(16),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_vehiculo',
        name: 'Vehículo',
        type: 'expense',
        icon: const Value('🚗'),
        color: const Value('#64748B'),
        isSystem: const Value(true),
        sortOrder: const Value(17),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_viajes',
        name: 'Viajes',
        type: 'expense',
        icon: const Value('✈️'),
        color: const Value('#0EA5E9'),
        isSystem: const Value(true),
        sortOrder: const Value(18),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_regalos',
        name: 'Regalos/Donaciones',
        type: 'expense',
        icon: const Value('🎁'),
        color: const Value('#F43F5E'),
        isSystem: const Value(true),
        sortOrder: const Value(19),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_inversiones',
        name: 'Inversiones',
        type: 'expense',
        icon: const Value('📈'),
        color: const Value('#8B5CF6'),
        isSystem: const Value(true),
        sortOrder: const Value(20),
        createdAt: now,
      ),
    ];
    await batch((batch) {
      batch.insertAllOnConflictUpdate(categories, newCategories);
    });
  }

  /// Insertar categorías predefinidas del sistema
  Future<void> _insertDefaultCategories() async {
    final now = DateTime.now();

    // Categorías de gastos
    final expenseCategories = [
      CategoriesCompanion.insert(
        id: 'cat_alojamiento',
        name: 'Alojamiento',
        type: 'expense',
        icon: const Value('🏠'),
        color: const Value('#8B5CF6'),
        isSystem: const Value(true),
        sortOrder: const Value(1),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_servicios_digitales',
        name: 'Servicios Digitales',
        type: 'expense',
        icon: const Value('💡'),
        color: const Value('#3B82F6'),
        isSystem: const Value(true),
        sortOrder: const Value(2),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_transporte',
        name: 'Transporte',
        type: 'expense',
        icon: const Value('🚗'),
        color: const Value('#06B6D4'),
        isSystem: const Value(true),
        sortOrder: const Value(3),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_educacion',
        name: 'Educación',
        type: 'expense',
        icon: const Value('📚'),
        color: const Value('#10B981'),
        isSystem: const Value(true),
        sortOrder: const Value(4),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_salud',
        name: 'Salud',
        type: 'expense',
        icon: const Value('🏥'),
        color: const Value('#EC4899'),
        isSystem: const Value(true),
        sortOrder: const Value(5),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_alimentacion',
        name: 'Alimentación',
        type: 'expense',
        icon: const Value('🍽️'),
        color: const Value('#F59E0B'),
        isSystem: const Value(true),
        sortOrder: const Value(6),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_pareja',
        name: 'Pareja',
        type: 'expense',
        icon: const Value('❤️'),
        color: const Value('#F43F5E'),
        isSystem: const Value(true),
        sortOrder: const Value(7),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_trabajo',
        name: 'Trabajo',
        type: 'expense',
        icon: const Value('💼'),
        color: const Value('#6366F1'),
        isSystem: const Value(true),
        sortOrder: const Value(8),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_entretenimiento',
        name: 'Entretenimiento',
        type: 'expense',
        icon: const Value('🎮'),
        color: const Value('#A855F7'),
        isSystem: const Value(true),
        sortOrder: const Value(9),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_ropa',
        name: 'Ropa',
        type: 'expense',
        icon: const Value('👕'),
        color: const Value('#EC4899'),
        isSystem: const Value(true),
        sortOrder: const Value(10),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_cuidado_personal',
        name: 'Cuidado Personal',
        type: 'expense',
        icon: const Value('💆'),
        color: const Value('#14B8A6'),
        isSystem: const Value(true),
        sortOrder: const Value(11),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_familia',
        name: 'Familia',
        type: 'expense',
        icon: const Value('👨‍👩‍👧'),
        color: const Value('#F97316'),
        isSystem: const Value(true),
        sortOrder: const Value(12),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_mascotas',
        name: 'Mascotas',
        type: 'expense',
        icon: const Value('🐾'),
        color: const Value('#84CC16'),
        isSystem: const Value(true),
        sortOrder: const Value(13),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_antojos',
        name: 'Antojos',
        type: 'expense',
        icon: const Value('🍭'),
        color: const Value('#EAB308'),
        isSystem: const Value(true),
        sortOrder: const Value(14),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_deporte',
        name: 'Deporte/Fitness',
        type: 'expense',
        icon: const Value('🏋️'),
        color: const Value('#22C55E'),
        isSystem: const Value(true),
        sortOrder: const Value(15),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_vehiculo',
        name: 'Vehículo',
        type: 'expense',
        icon: const Value('🚗'),
        color: const Value('#64748B'),
        isSystem: const Value(true),
        sortOrder: const Value(16),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_viajes',
        name: 'Viajes',
        type: 'expense',
        icon: const Value('✈️'),
        color: const Value('#0EA5E9'),
        isSystem: const Value(true),
        sortOrder: const Value(17),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_regalos',
        name: 'Regalos/Donaciones',
        type: 'expense',
        icon: const Value('🎁'),
        color: const Value('#F43F5E'),
        isSystem: const Value(true),
        sortOrder: const Value(18),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_inversiones',
        name: 'Inversiones',
        type: 'expense',
        icon: const Value('📈'),
        color: const Value('#8B5CF6'),
        isSystem: const Value(true),
        sortOrder: const Value(19),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_otro_gasto',
        name: 'Otro',
        type: 'expense',
        icon: const Value('📦'),
        color: const Value('#6B7280'),
        isSystem: const Value(true),
        sortOrder: const Value(20),
        createdAt: now,
      ),
    ];

    // Categorías de ingresos
    final incomeCategories = [
      CategoriesCompanion.insert(
        id: 'cat_dinero_mensual',
        name: 'Dinero mensual',
        type: 'income',
        icon: const Value('💰'),
        color: const Value('#10B981'),
        isSystem: const Value(true),
        sortOrder: const Value(1),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_salario',
        name: 'Salario',
        type: 'income',
        icon: const Value('💵'),
        color: const Value('#059669'),
        isSystem: const Value(true),
        sortOrder: const Value(2),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_dinero_extra',
        name: 'Dinero extra',
        type: 'income',
        icon: const Value('💸'),
        color: const Value('#34D399'),
        isSystem: const Value(true),
        sortOrder: const Value(3),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_plus',
        name: 'Plus',
        type: 'income',
        icon: const Value('💡'),
        color: const Value('#6EE7B7'),
        isSystem: const Value(true),
        sortOrder: const Value(4),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'cat_otro_ingreso',
        name: 'Otro',
        type: 'income',
        icon: const Value('📦'),
        color: const Value('#6B7280'),
        isSystem: const Value(true),
        sortOrder: const Value(5),
        createdAt: now,
      ),
    ];

    // Insertar todas las categorías
    await batch((batch) {
      batch.insertAll(categories, expenseCategories);
      batch.insertAll(categories, incomeCategories);
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'finanzas.db'));
    return NativeDatabase(file);
  });
}
