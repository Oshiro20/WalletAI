import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../data/database/drift_database.dart';
import '../../providers/database_providers.dart';
import '../../providers/transaction_repository_provider.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/service_providers.dart';
import 'widgets/account_selector.dart';
import 'widgets/category_selector.dart';
import '../../../data/datasources/notification_service.dart';
import '../../../data/datasources/location_service.dart';
import 'widgets/add_receipt_items_screen.dart';

class CreateTransactionScreen extends ConsumerStatefulWidget {
  final String? initialType;
  final double? initialAmount;
  final String? initialDescription;
  final String? initialProductName;
  final String? initialCategoryId;
  final String? initialSubcategoryId;
  final String? initialAccountId;
  final DateTime? initialDate;
  final double? initialQuantity;
  final String? initialUnit;

  const CreateTransactionScreen({
    super.key,
    this.initialType,
    this.initialAmount,
    this.initialDescription,
    this.initialProductName,
    this.initialCategoryId,
    this.initialSubcategoryId,
    this.initialAccountId,
    this.initialDate,
    this.initialQuantity,
    this.initialUnit,
  });

  @override
  ConsumerState<CreateTransactionScreen> createState() =>
      _CreateTransactionScreenState();
}

class _CreateTransactionScreenState
    extends ConsumerState<CreateTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _productNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _productNameFocusNode = FocusNode();

  DateTime _selectedDate = DateTime.now();
  String _transactionType = 'expense'; // expense, income, transfer
  String _currency = 'PEN';
  String? _selectedAccountId;
  String? _destinationAccountId; // Para transferencias
  String? _selectedCategoryId;
  String? _selectedSubcategoryId;
  bool _isLoading = false;

  // Variables para prediccion de IA
  Timer? _predictionTimer;
  bool _isPredictingCategory = false;

  // Variables para GPS
  double? _latitude;
  double? _longitude;
  String? _locationName;
  bool _isCapturingLocation = false;

  // Variables para pagos recurrentes
  bool _isRecurring = false;
  String _frequency = 'monthly'; // monthly, weekly, yearly

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null &&
        ['expense', 'income', 'transfer'].contains(widget.initialType)) {
      _transactionType = widget.initialType!;
    }
    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount!.toStringAsFixed(2);
    }
    if (widget.initialDescription != null) {
      _descriptionController.text = widget.initialDescription!;
    }
    if (widget.initialProductName != null) {
      _productNameController.text = widget.initialProductName!;
    }
    if (widget.initialCategoryId != null) {
      _selectedCategoryId = widget.initialCategoryId;
    }
    if (widget.initialSubcategoryId != null) {
      _selectedSubcategoryId = widget.initialSubcategoryId;
    }
    if (widget.initialAccountId != null) {
      _selectedAccountId = widget.initialAccountId;
    }
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }
    if (widget.initialQuantity != null) {
      _quantityController.text = widget.initialQuantity!.toStringAsFixed(2);
    } else {
      _quantityController.text = '1';
    }
    if (widget.initialUnit != null) {
      _unitController.text = widget.initialUnit!;
    } else {
      _unitController.text = 'UND';
    }

    _productNameFocusNode.addListener(_onProductNameFocusChanged);
  }

  void _onProductNameFocusChanged() async {
    // Cuando el usuario termina de escribir el producto y sale del campo
    if (!_productNameFocusNode.hasFocus) {
      final name = _productNameController.text.trim();
      if (name.isNotEmpty) {
        final db = ref.read(databaseProvider);
        final rule = await db.learningRulesDao.getRuleForProduct(name);

        if (rule != null && mounted) {
          setState(() {
            _selectedCategoryId = rule.categoryId;
          });

          // Mostrar un pequeño feedback visual
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Categoría auto-asignada por aprendizaje: \$name'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _onProductNameChanged(String value) {
    if (value.trim().isEmpty) {
      _predictionTimer?.cancel();
      if (_isPredictingCategory) {
        setState(() => _isPredictingCategory = false);
      }
      return;
    }

    // Cancelar el timer anterior si el usuario sigue escribiendo
    _predictionTimer?.cancel();

    // Iniciar un nuevo timer de 800ms para hacer debounce
    _predictionTimer = Timer(const Duration(milliseconds: 800), () async {
      final name = value.trim();

      // 1. Primero intentar autocompletar con reglas locales
      final db = ref.read(databaseProvider);
      final rule = await db.learningRulesDao.getRuleForProduct(name);

      if (rule != null && mounted) {
        setState(() {
          _selectedCategoryId = rule.categoryId;
        });
        return; // Si encontró regla local, ya no llama a la API
      }

      // 2. Si no hay regla local, usar IA Predictiva (Fast)
      if (mounted) {
        setState(() {
          _isPredictingCategory = true;
        });
      }

      try {
        final groqService = ref.read(groqServiceProvider);
        final categoriesList = await db.categoriesDao.getAllCategories();
        final predictedCategoryName = await groqService.predictCategoryFast(
          name,
          categoriesList,
        );

        if (predictedCategoryName != null && mounted) {
          final category = await db.categoriesDao.findCategoryByName(
            predictedCategoryName,
          );
          if (category != null && mounted) {
            setState(() {
              _selectedCategoryId = category.id;
            });
            // Mostrar un pequeño feedback visual de éxito
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('IA detectó la categoría: ${category.name}'),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      } catch (e) {
        // Ignorar errores de predicción por timeout (es non-blocking)
      } finally {
        if (mounted) {
          setState(() {
            _isPredictingCategory = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _predictionTimer?.cancel();
    _amountController.dispose();
    _descriptionController.dispose();
    _productNameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _productNameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showScanOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.document_scanner),
              title: const Text('Comprobante Único (1 producto)'),
              subtitle: const Text('Ideal para restaurantes o recibos simples'),
              onTap: () {
                Navigator.pop(ctx);
                _showCameraOrGallery(context, isMultiple: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Boleta Múltiple (Supermercado)'),
              subtitle: const Text(
                'Extrae todos los productos como transacciones separadas',
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showCameraOrGallery(context, isMultiple: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCameraOrGallery(BuildContext context, {required bool isMultiple}) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar Foto'),
              onTap: () {
                Navigator.pop(ctx);
                _scanReceipt(ImageSource.camera, isMultiple: isMultiple);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(ctx);
                _scanReceipt(ImageSource.gallery, isMultiple: isMultiple);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanReceipt(
    ImageSource source, {
    bool isMultiple = false,
  }) async {
    setState(() => _isLoading = true);
    try {
      final scanner = ref.read(receiptScannerServiceProvider);
      final receipt = source == ImageSource.camera
          ? await scanner.scanFromCamera(isMultiple: isMultiple)
          : await scanner.scanFromGallery(isMultiple: isMultiple);

      if (receipt != null) {
        if (mounted) {
          setState(() {
            if (receipt.amount != null) {
              _amountController.text = receipt.amount!.toStringAsFixed(2);
            }
            if (receipt.date != null) {
              _selectedDate = receipt.date!;
            }
            if (receipt.merchant != null) {
              _descriptionController.text = receipt.merchant!;
            }
            if (receipt.productName != null &&
                receipt.productName!.isNotEmpty) {
              _productNameController.text = receipt.productName!;
            }
          });

          if (receipt.category != null &&
              receipt.category!.isNotEmpty &&
              _transactionType == 'expense') {
            try {
              final categoriesDao = ref.read(categoriesDaoProvider);
              final categories = await categoriesDao.getAllCategories();

              Category? matchedCategory;
              for (final c in categories) {
                if (c.type == 'expense' &&
                    c.name.toLowerCase() == receipt.category!.toLowerCase()) {
                  matchedCategory = c;
                  break;
                }
              }

              if (matchedCategory != null) {
                final categoryId = matchedCategory.id;

                if (mounted) {
                  setState(() {
                    _selectedCategoryId = categoryId;
                    _selectedSubcategoryId = null; // reset subcategory first
                  });
                }

                if (receipt.subcategory != null &&
                    receipt.subcategory!.isNotEmpty) {
                  final subcategoriesDao = ref.read(subcategoriesDaoProvider);
                  final subcats = await subcategoriesDao
                      .getSubcategoriesByCategoryId(categoryId);
                  for (final sc in subcats) {
                    if (sc.name.toLowerCase() ==
                        receipt.subcategory!.toLowerCase()) {
                      if (mounted) {
                        setState(() {
                          _selectedSubcategoryId = sc.id;
                        });
                      }
                      break;
                    }
                  }
                }
              }
            } catch (_) {}
          }

          if (receipt.items != null && receipt.items!.isNotEmpty) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (ctx) => AddReceiptItemsScreen(receipt: receipt),
                ),
              );
            }
            return;
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Datos extraídos de la boleta ✅')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo leer la boleta')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al escanear: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _captureLocation() async {
    setState(() => _isCapturingLocation = true);
    try {
      final result = await locationServiceInstance.getCurrentLocation();
      if (result != null && mounted) {
        setState(() {
          _latitude = result.latitude;
          _longitude = result.longitude;
          _locationName = result.name;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📍 Ubicación capturada: ${result.name ?? "lat ${result.latitude.toStringAsFixed(4)}"}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo obtener la ubicación. Verifica los permisos.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturingLocation = false);
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una cuenta')),
      );
      return;
    }

    if (_selectedCategoryId == null && _transactionType != 'transfer') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una categoría')),
      );
      return;
    }

    // Validar transferencia
    if (_transactionType == 'transfer') {
      if (_destinationAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona cuenta destino')),
        );
        return;
      }
      if (_selectedAccountId == _destinationAccountId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Las cuentas deben ser diferentes')),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(transactionRepositoryProvider);
      final dao = ref.read(databaseProvider).learningRulesDao;
      final activeTravel = ref.read(activeTravelProvider).valueOrNull;

      final amount = double.parse(_amountController.text);
      const uuid = Uuid();
      final transactionId = uuid.v4();
      String? recurringId;
      drift.Insertable<RecurringPayment>? recurringPayment;

      // Si es recurrente, crear objeto RecurringPaymentsCompanion
      if (_isRecurring && _transactionType != 'transfer') {
        recurringId = uuid.v4();

        // Calcular próxima fecha (la actual cuenta como la primera)
        DateTime nextDate = _selectedDate;
        if (_frequency == 'weekly') {
          nextDate = nextDate.add(const Duration(days: 7));
        } else if (_frequency == 'monthly') {
          nextDate = DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
        } else if (_frequency == 'yearly') {
          nextDate = DateTime(nextDate.year + 1, nextDate.month, nextDate.day);
        }

        recurringPayment = RecurringPaymentsCompanion.insert(
          id: recurringId,
          name: _descriptionController.text.isNotEmpty
              ? _descriptionController.text
              : (_transactionType == 'expense'
                    ? 'Gasto recurrente'
                    : 'Ingreso recurrente'),
          amount: amount,
          accountId: _selectedAccountId!,
          categoryId: drift.Value(_selectedCategoryId),
          frequency: _frequency,
          nextDueDate: nextDate,
          isActive: const drift.Value(true),
          createdAt: DateTime.now(),
        );
      }

      // Crear objeto TransactionCompanion
      final transaction = TransactionsCompanion.insert(
        id: transactionId,
        type: _transactionType,
        contextId: drift.Value(activeTravel?.id),
        amount: amount,
        accountId: _selectedAccountId!,
        destinationAccountId: drift.Value(_destinationAccountId),
        categoryId: drift.Value(_selectedCategoryId),
        subcategoryId: drift.Value(_selectedSubcategoryId),
        productName: drift.Value(
          _productNameController.text.isEmpty
              ? null
              : _productNameController.text,
        ),
        quantity: drift.Value(double.tryParse(_quantityController.text) ?? 1.0),
        unit: drift.Value(
          _unitController.text.trim().isEmpty
              ? 'UND'
              : _unitController.text.trim().toUpperCase(),
        ),
        description: drift.Value(
          _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
        ),
        date: _selectedDate,
        isRecurring: drift.Value(_isRecurring),
        recurringPaymentId: drift.Value(recurringId),
        latitude: drift.Value(_latitude),
        longitude: drift.Value(_longitude),
        locationName: drift.Value(_locationName),
        currency: drift.Value(_currency),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Guardar usando el repositorio (maneja transacción y saldos internamente)
      await repository.addTransaction(
        transaction: transaction,
        accountId: _selectedAccountId!,
        amount: amount,
        type: _transactionType,
        destinationAccountId: _destinationAccountId,
        recurringPayment: recurringPayment,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isRecurring
                  ? 'Transacción y suscripción guardadas'
                  : 'Transacción guardada exitosamente',
            ),
          ),
        );

        // Cerrar pantalla INMEDIATAMENTE — las verificaciones corren en background
        Navigator.of(context).pop();

        // 🧠 APRENDIZAJE PERSISTENTE + verificaciones — en background (unawaited)
        if (_transactionType == 'expense') {
          unawaited(_checkBudgetAlerts());
          unawaited(_checkHighExpense(amount, _descriptionController.text));
          if (_productNameController.text.trim().isNotEmpty &&
              _selectedCategoryId != null) {
            unawaited(
              dao.saveRule(
                _productNameController.text.trim(),
                _selectedCategoryId!,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Verifica presupuestos y dispara notificaciones si es necesario
  Future<void> _checkBudgetAlerts() async {
    try {
      final budgetsDao = ref.read(budgetsDaoProvider);
      final transactionsDao = ref.read(transactionsDaoProvider);
      final categoriesDao = ref.read(categoriesDaoProvider);

      final budgets = await budgetsDao.getActiveBudgets();
      if (budgets.isEmpty) return;

      final categories = await categoriesDao.getAllCategories();

      await NotificationService().checkBudgetAlerts(
        budgets: budgets,
        transactionsDao: transactionsDao,
        categories: categories,
      );
    } catch (_) {
      // Silencioso — no interrumpir el flujo del usuario
    }
  }

  /// Notifica si el gasto supera 3x el promedio diario del mes
  Future<void> _checkHighExpense(double amount, String description) async {
    try {
      final transactionsDao = ref.read(transactionsDaoProvider);
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final monthlyExpenses = await transactionsDao.getExpensesByCategory(
        startOfMonth,
        endOfMonth,
      );
      final totalMonthly = monthlyExpenses.values.fold(0.0, (a, b) => a + b);

      final daysElapsed = now.day.toDouble().clamp(1, 31);
      final dailyAverage = totalMonthly / daysElapsed;

      if (dailyAverage > 0 && amount > dailyAverage * 3) {
        await NotificationService().notifyHighExpense(
          description: description.isEmpty ? 'Sin descripción' : description,
          amount: amount,
          dailyAverage: dailyAverage,
        );
      }
    } catch (_) {
      // Silencioso
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = _transactionType == 'expense'
        ? ref.watch(expenseCategoriesStreamProvider)
        : ref.watch(incomeCategoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Transacción'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.camera_alt),
              tooltip: 'Escanear Boleta',
              onPressed: () => _showScanOptions(context),
            ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveTransaction,
          ),
        ],
      ),

      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Selector de tipo
            _buildTypeSelector(),

            const SizedBox(height: 24),

            // Campo de monto
            _buildAmountField(),

            const SizedBox(height: 16),

            // Selector de cuenta
            _buildAccountSelector(accountsAsync),

            const SizedBox(height: 16),

            // Selector de cuenta destino (solo para transferencias)
            if (_transactionType == 'transfer') ...[
              _buildDestinationAccountSelector(accountsAsync),
              const SizedBox(height: 16),
            ],

            // Selector de categoría (solo para income/expense)
            if (_transactionType != 'transfer') ...[
              _buildCategorySelector(categoriesAsync),
              const SizedBox(height: 16),

              // Selector de subcategoría (si hay categoría seleccionada)
              if (_selectedCategoryId != null)
                _buildSubcategorySelector(_selectedCategoryId!),
            ],

            if (_transactionType != 'transfer') const SizedBox(height: 16),

            // Campo de producto (nuevo)
            _buildProductNameField(),

            const SizedBox(height: 16),

            // Cantidad y Unidad (opcional, solo gastos o compras)
            if (_transactionType != 'transfer') ...[
              _buildQuantityAndUnitFields(),
              const SizedBox(height: 16),
            ],

            // Campo de comercio/descripción
            _buildDescriptionField(),

            const SizedBox(height: 16),

            // Selector de fecha
            _buildDateSelector(),

            const SizedBox(height: 16),

            // Botón de ubicación GPS
            _buildLocationButton(),

            const SizedBox(height: 16),

            // Opción de pago recurrente (solo para gastos/ingresos)
            if (_transactionType != 'transfer') ...[
              SwitchListTile(
                title: Text(
                  _transactionType == 'expense'
                      ? '¿Es un gasto frecuente?'
                      : '¿Es un ingreso frecuente?',
                ),
                subtitle: Text(
                  _transactionType == 'expense'
                      ? 'Ej. Suscripciones, Alquiler'
                      : 'Ej. Sueldo, Renta',
                ),
                value: _isRecurring,
                onChanged: (value) {
                  setState(() {
                    _isRecurring = value;
                  });
                },
                secondary: const Icon(Icons.loop),
                contentPadding: EdgeInsets.zero,
              ),

              if (_isRecurring) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Frecuencia',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.update),
                  ),
                  initialValue: _frequency,
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
                    DropdownMenuItem(value: 'monthly', child: Text('Mensual')),
                    DropdownMenuItem(value: 'yearly', child: Text('Anual')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _frequency = value);
                    }
                  },
                ),
              ],
            ],

            const SizedBox(height: 32),

            // Botón guardar
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: _TypeButton(
                label: 'Gasto',
                icon: Icons.arrow_upward,
                color: AppColors.expense,
                isSelected: _transactionType == 'expense',
                onTap: () {
                  setState(() {
                    _transactionType = 'expense';
                    _selectedCategoryId = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TypeButton(
                label: 'Ingreso',
                icon: Icons.arrow_downward,
                color: AppColors.income,
                isSelected: _transactionType == 'income',
                onTap: () {
                  setState(() {
                    _transactionType = 'income';
                    _selectedCategoryId = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TypeButton(
                label: 'Transferir',
                icon: Icons.swap_horiz,
                color: AppColors.transfer,
                isSelected: _transactionType == 'transfer',
                onTap: () {
                  setState(() {
                    _transactionType = 'transfer';
                    _selectedCategoryId = null;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(
              labelText: 'Moneda',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 16,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'PEN', child: Text('PEN')),
              DropdownMenuItem(value: 'USD', child: Text('USD')),
              DropdownMenuItem(value: 'EUR', child: Text('EUR')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _currency = val);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Monto',
              prefixText: '$_currency ',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa un monto';
              }
              final amount = double.tryParse(value);
              if (amount == null || amount <= 0) {
                return 'Ingresa un monto válido';
              }
              return null;
            },
            autofocus: true,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSelector(AsyncValue<List<Account>> accountsAsync) {
    return AccountSelector(
      selectedAccountId: _selectedAccountId,
      onAccountSelected: (value) {
        setState(() {
          _selectedAccountId = value;
          // Resetear destino si es igual al origen
          if (_destinationAccountId == value) {
            _destinationAccountId = null;
          }
        });
      },
    );
  }

  Widget _buildDestinationAccountSelector(
    AsyncValue<List<Account>> accountsAsync,
  ) {
    return AccountSelector(
      selectedAccountId: _destinationAccountId,
      accountIdToExclude: _selectedAccountId,
      onAccountSelected: (value) {
        setState(() {
          _destinationAccountId = value;
        });
      },
    );
  }

  Widget _buildCategorySelector(AsyncValue<List<Category>> categoriesAsync) {
    return CategorySelector(
      selectedCategoryId: _selectedCategoryId,
      transactionType: _transactionType,
      onCategorySelected: (value) {
        setState(() {
          _selectedCategoryId = value;
          _selectedSubcategoryId = null; // Resetear subcategoría
        });
      },
    );
  }

  Widget _buildSubcategorySelector(String categoryId) {
    // Usar ref.watch para observar el stream de subcategorías
    final subcategoriesAsync = ref.watch(
      subcategoriesStreamProvider(categoryId),
    );

    return subcategoriesAsync.when(
      data: (subcategories) {
        if (subcategories.isEmpty) {
          return const SizedBox.shrink(); // No mostrar nada si no hay subcategorías
        }

        return Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Subcategoría (opcional)',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                prefixIcon: const Icon(Icons.subdirectory_arrow_right),
              ),
              initialValue: _selectedSubcategoryId,
              items: subcategories.map<DropdownMenuItem<String>>((subcategory) {
                return DropdownMenuItem(
                  value: subcategory.id,
                  child: Row(
                    children: [
                      if (subcategory.icon != null)
                        Text(
                          subcategory.icon!,
                          style: const TextStyle(fontSize: 20),
                        ),
                      if (subcategory.icon != null) const SizedBox(width: 8),
                      Text(subcategory.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSubcategoryId = value;
                });
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, stack) =>
          const SizedBox.shrink(), // Ocultar errores silenciosamente en UI
    );
  }

  Widget _buildProductNameField() {
    return TextFormField(
      controller: _productNameController,
      focusNode: _productNameFocusNode,
      onChanged: _onProductNameChanged,
      decoration: InputDecoration(
        labelText: 'Producto / Ítem (opcional)',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        prefixIcon: const Icon(Icons.inventory_2_outlined),
        suffixIcon: _isPredictingCategory
            ? Container(
                padding: const EdgeInsets.all(12),
                width: 20,
                height: 20,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome, color: Colors.amber),
        hintText: 'Ej. Mandarina, Leche Gloria, NESQUIK',
      ),
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildQuantityAndUnitFields() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: _quantityController,
            decoration: InputDecoration(
              labelText: 'Cantidad',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              prefixIcon: const Icon(Icons.numbers),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            initialValue:
                [
                  'UND',
                  'KG',
                  'GRS',
                  'LTR',
                  'MLS',
                  'CAJA',
                  'MTS',
                ].contains(_unitController.text)
                ? _unitController.text
                : 'UND',
            decoration: InputDecoration(
              labelText: 'Unidad',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
            items: const [
              DropdownMenuItem(value: 'UND', child: Text('Unidad (UND)')),
              DropdownMenuItem(value: 'KG', child: Text('Kilos (KG)')),
              DropdownMenuItem(value: 'GRS', child: Text('Gramos (GRS)')),
              DropdownMenuItem(value: 'LTR', child: Text('Litros (LTR)')),
              DropdownMenuItem(value: 'MLS', child: Text('Mililitros (MLS)')),
              DropdownMenuItem(value: 'CAJA', child: Text('Caja (CAJA)')),
              DropdownMenuItem(value: 'MTS', child: Text('Metros (MTS)')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _unitController.text = val;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: InputDecoration(
        labelText: 'Comercio / Descripción (opcional)',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        prefixIcon: const Icon(Icons.store_outlined),
        hintText: 'Ej. Lider Cloud, Mercado Central',
      ),
      maxLines: 2,
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildDateSelector() {
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'es');

    return InkWell(
      onTap: () => _selectDate(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Fecha',
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          prefixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          dateFormat.format(_selectedDate),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildLocationButton() {
    final hasLocation = _latitude != null && _longitude != null;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: _isCapturingLocation ? null : _captureLocation,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Ubicación (opcional)',
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: colorScheme.surface,
          prefixIcon: _isCapturingLocation
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Icon(
                  hasLocation ? Icons.location_on : Icons.location_off,
                  color: hasLocation ? colorScheme.primary : null,
                ),
          suffixIcon: hasLocation
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Quitar ubicación',
                  onPressed: () => setState(() {
                    _latitude = null;
                    _longitude = null;
                    _locationName = null;
                  }),
                )
              : null,
        ),
        child: Text(
          hasLocation
              ? (_locationName ??
                    'lat ${_latitude!.toStringAsFixed(4)}, lon ${_longitude!.toStringAsFixed(4)}')
              : _isCapturingLocation
              ? 'Obteniendo ubicación...'
              : 'Toca para capturar ubicación',
          style: TextStyle(
            color: hasLocation
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
            fontStyle: hasLocation ? FontStyle.normal : FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return FilledButton.icon(
      onPressed: _isLoading ? null : _saveTransaction,
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save),
      label: Text(_isLoading ? 'Guardando...' : 'Guardar Transacción'),
      style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
