import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../data/datasources/receipt_scanner_service.dart';
import '../../../data/datasources/transaction_parser_service.dart';
import '../../../data/database/drift_database.dart';
import '../../providers/database_providers.dart';
import '../../providers/transaction_repository_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'dart:io';

enum ScanMode { simple, multiple }

class ScanReceiptScreen extends ConsumerStatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  ConsumerState<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _EditableItem {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController quantityController;
  final TextEditingController unitController;
  String? categoryId;
  String? subcategoryId;
  bool isSelected = true;

  _EditableItem(String name, double price, {this.categoryId, this.subcategoryId, double? quantity, String? unit})
      : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price.toStringAsFixed(2)),
        quantityController = TextEditingController(text: quantity?.toString() ?? '1'),
        unitController = TextEditingController(text: unit ?? 'UND');

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    quantityController.dispose();
    unitController.dispose();
  }
}

class _ScanReceiptScreenState extends ConsumerState<ScanReceiptScreen> {
  final _scanner = ReceiptScannerService();
  final _parser = TransactionParserService();

  bool _isSaving = false;
  bool _isScanning = false;
  ScannedReceipt? _result;
  ScanMode _selectedMode = ScanMode.simple;

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController(); // comercio
  final _productController = TextEditingController(); // nombre del producto

  // Para modo múltiple
  final List<_EditableItem> _editableItems = [];
  String? _multipleCategoryId;
  String? _multipleAccountId;
  DateTime? _multipleSelectedDate;

  // Para modo simple
  DateTime? _singleSelectedDate;
  String? _singleCategoryId;
  String? _singleSubcategoryId;
  String? _singleAccountId;

  @override
  void dispose() {
    _scanner.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _productController.dispose();
    for (var element in _editableItems) {
      element.dispose();
    }
    super.dispose();
  }

  // ─── Escaneo ──────────────────────────────────────────────────────────────

  Future<void> _scan(ImageSource source) async {
    setState(() {
      _isScanning = true;
      _result = null;
    });

    final dao = ref.read(databaseProvider).learningRulesDao;
    final result = await (source == ImageSource.camera
        ? _scanner.scanFromCamera(isMultiple: _selectedMode == ScanMode.multiple, dao: dao)
        : _scanner.scanFromGallery(isMultiple: _selectedMode == ScanMode.multiple, dao: dao));

    if (!mounted) return;

    if (result == null) {
      setState(() => _isScanning = false);
      return;
    }

    setState(() {
      _isScanning = false;
      _result = result;
      if (result.success) {
        if (_selectedMode == ScanMode.multiple) {
          _descriptionController.text = result.merchant ?? '';
          _multipleSelectedDate = result.date ?? DateTime.now();
          for (var r in _editableItems) {
            r.dispose();
          }
          _editableItems.clear();
          if (result.items != null) {
            final categoriesAsync = ref.read(expenseCategoriesStreamProvider);
            final accountsAsync = ref.read(accountsStreamProvider);
            final subcatsAsync = ref.read(allSubcategoriesStreamProvider);
            List<Category> categories = [];
            List<Account> accounts = [];
            List<Subcategory> subcategories = [];
            categoriesAsync.whenData((cats) => categories = cats);
            accountsAsync.whenData((accs) => accounts = accs);
            subcatsAsync.whenData((subs) => subcategories = subs);

            for (var item in result.items!) {
              final searchText = '${result.merchant ?? ""} ${item.name} ${item.category ?? ""} ${item.subcategory ?? ""}';
              final parsed = _parser.parse(searchText, categories, accounts, subcategories: subcategories);
              _editableItems.add(_EditableItem(item.name, item.price, categoryId: parsed.categoryId ?? item.category, subcategoryId: parsed.subcategoryId ?? item.subcategory, quantity: item.quantity, unit: item.unit));
            }
          }
        } else {
          _amountController.text = result.amount?.toStringAsFixed(2) ?? '';
          _descriptionController.text = result.merchant ?? '';
          _productController.text = result.productName ?? '';
          _singleSelectedDate = result.date ?? DateTime.now();
          
          final categoriesAsync = ref.read(expenseCategoriesStreamProvider);
          final accountsAsync = ref.read(accountsStreamProvider);
          final subcatsAsync = ref.read(allSubcategoriesStreamProvider);
          
          List<Category> categories = [];
          List<Account> accounts = [];
          List<Subcategory> subcategories = [];
          categoriesAsync.whenData((cats) => categories = cats);
          accountsAsync.whenData((accs) => accounts = accs);
          subcatsAsync.whenData((subs) => subcategories = subs);
          
          final searchText = '${result.merchant ?? ""} ${result.productName ?? ""} ${result.category ?? ""} ${result.subcategory ?? ""}';
          final parsed = _parser.parse(searchText, categories, accounts, subcategories: subcategories);
          
          _singleCategoryId = parsed.categoryId ?? result.category;
          _singleSubcategoryId = parsed.subcategoryId ?? result.subcategory;
          _singleAccountId = parsed.accountId ?? (accounts.isNotEmpty ? accounts.first.id : null);
        }
      }
    });
  }

  Future<void> _createTransaction() async {
    if (_selectedMode == ScanMode.multiple) {
      await _createMultipleTransactions();
      return;
    }

    if (_result == null || !_result!.success) return;

    final amount = double.tryParse(_amountController.text);

    if (!mounted) return;

    if (_singleAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una cuenta de origen')));
      return;
    }
    if (_singleCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor selecciona una categoría')));
      return;
    }

    setState(() => _isSaving = true);
    final repo = ref.read(transactionRepositoryProvider);
    final dao = ref.read(databaseProvider).learningRulesDao;

    try {
      final t = TransactionsCompanion.insert(
        id: const Uuid().v4(),
        type: 'expense',
        amount: amount ?? 0.0,
        accountId: _singleAccountId!,
        categoryId: drift.Value(_singleCategoryId),
        subcategoryId: drift.Value(_singleSubcategoryId),
        description: drift.Value(_descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim()),
        productName: drift.Value(_productController.text.trim().isEmpty ? null : _productController.text.trim()),
        quantity: drift.Value(_result!.quantity ?? 1.0),
        unit: drift.Value((_result!.unit ?? 'UND').toUpperCase()),
        date: _singleSelectedDate ?? DateTime.now(),
        currency: const drift.Value('PEN'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.addTransaction(
        transaction: t,
        accountId: _singleAccountId!,
        amount: amount ?? 0.0,
        type: 'expense',
      );
      
      if (_productController.text.trim().isNotEmpty) {
         await dao.saveRule(_productController.text.trim(), _singleCategoryId!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transacción guardada exitosamente 🚀')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _createMultipleTransactions() async {
    if (_result == null || !_result!.success) return;
    final selectedItems = _editableItems.where((e) => e.isSelected).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un ítem')),
      );
      return;
    }
    if (_multipleAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una cuenta de origen')),
      );
      return;
    }

    setState(() => _isSaving = true);
    
    // Default categories if missing
    String catId = _multipleCategoryId ?? (await ref.read(expenseCategoriesStreamProvider.future)).first.id;

    final repo = ref.read(transactionRepositoryProvider);
    final date = _multipleSelectedDate ?? DateTime.now();
    final merchant = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();
    final dao = ref.read(databaseProvider).learningRulesDao;

    try {
      int count = 0;
      for (final item in selectedItems) {
        final amount = double.tryParse(item.priceController.text.replaceAll(',', '.'));
        if (amount == null || amount <= 0) continue;
        
        final name = item.nameController.text.trim();
        final qty = double.tryParse(item.quantityController.text) ?? 1.0;
        final unit = item.unitController.text.trim().isEmpty ? 'UND' : item.unitController.text.trim();
        final finalCatId = item.categoryId ?? catId;
        
        final t = TransactionsCompanion.insert(
          id: const Uuid().v4(),
          type: 'expense',
          amount: amount,
          accountId: _multipleAccountId!,
          categoryId: drift.Value(finalCatId),
          subcategoryId: drift.Value(item.subcategoryId),
          description: drift.Value(merchant),
          productName: drift.Value(name.isEmpty ? null : name),
          quantity: drift.Value(qty),
          unit: drift.Value(unit.toUpperCase()),
          date: date,
          currency: const drift.Value('PEN'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repo.addTransaction(
          transaction: t,
          accountId: _multipleAccountId!,
          amount: amount,
          type: 'expense',
        );
        
        // 🧠 APRENDIZAJE PERSISTENTE: Guardar la regla para la próxima vez
        if (name.isNotEmpty) {
           await dao.saveRule(name, finalCatId);
        }
        
        count++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count transacciones guardadas')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Factura / Boleta'),
        actions: [
          if (_result?.success == true)
            TextButton.icon(
              onPressed: _createTransaction,
              icon: const Icon(Icons.check),
              label: const Text('Registrar'),
            ),
        ],
      ),
      body: _isScanning
          ? _buildScanningState()
          : _result == null
              ? _buildIdleState(colorScheme)
              : _result!.success
                  ? _buildResultState(colorScheme)
                  : _buildErrorState(),
    );
  }

  // ─── Estado inicial ───────────────────────────────────────────────────────

  Widget _buildIdleState(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // ── Selector de modo ──────────────────────────────────────────
          Text('Modo de escaneo',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ModeCard(
                  icon: '🧾',
                  title: 'Simple',
                  subtitle: 'Una sola compra\no total de boleta',
                  isSelected: _selectedMode == ScanMode.simple,
                  onTap: () => setState(() => _selectedMode = ScanMode.simple),
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModeCard(
                  icon: '📋',
                  title: 'Múltiple',
                  subtitle: 'Varios productos\nde distintas categorías',
                  isSelected: _selectedMode == ScanMode.multiple,
                  onTap: () => setState(() => _selectedMode = ScanMode.multiple),
                  color: Colors.teal,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ── Ilustración central ───────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _selectedMode == ScanMode.simple
                        ? Icons.receipt_long
                        : Icons.receipt,
                    size: 64,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedMode == ScanMode.simple
                      ? 'Escanear boleta (Total)'
                      : 'Escanear boleta (Múltiple)',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedMode == ScanMode.simple
                      ? 'WalletAI detecta monto, comercio, fecha\ny nombre del producto automáticamente.'
                      : 'Detecta cada ítem y crea transacciones\nindividuales por categoría.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

            // ── Botones de captura ────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _ScanOptionCard(
                    icon: Icons.camera_alt,
                    label: 'Cámara',
                    subtitle: 'Toma una foto',
                    color: cs.primary,
                    onTap: () => _scan(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ScanOptionCard(
                    icon: Icons.photo_library,
                    label: 'Galería',
                    subtitle: 'Elige una imagen',
                    color: Colors.teal,
                    onTap: () => _scan(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _TipBanner(
              text: _selectedMode == ScanMode.simple
                ? 'Consejo: mejor iluminación = mayor precisión. '
                  'Que el "Importe Total" sea visible.'
                : 'Alinea toda la boleta. WalletAI leerá cada producto y '
                  'estimará su categoría.',
            ),
        ],
      ),
    );
  }

  // ─── Estado escaneando ────────────────────────────────────────────────────

  Widget _buildScanningState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(strokeWidth: 3),
          const SizedBox(height: 24),
          Text(
            'Analizando boleta con IA...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Detectando monto · comercio · producto · fecha',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─── Estado resultado ─────────────────────────────────────────────────────

  Widget _buildResultState(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de éxito
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '✅ Factura leída exitosamente',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      Text(
                        'Revisa y ajusta si es necesario antes de registrar',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Badge de confianza de la IA
          if (_result!.confidence != null) ...[  
            const SizedBox(height: 8),
            _ConfidenceBadge(confidence: _result!.confidence!),
          ],

          const SizedBox(height: 24),
          Text(
              _selectedMode == ScanMode.simple ? 'Datos de la compra' : 'Productos detectados',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          if (_selectedMode == ScanMode.simple)
            _buildSingleForm()
          else
            _buildMultipleForm(),

          const SizedBox(height: 16),

          _ScanResultPreview(
            rawText: _result!.rawText,
            imagePath: _result!.imagePath,
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _result = null),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Volver a escanear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _createTransaction,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add),
                  label: _isSaving 
                      ? const Text('Guardando...') 
                      : Text(_selectedMode == ScanMode.multiple ? 'Guardar lote' : 'Registrar gasto'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleForm() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Monto — SIEMPRE en S/ (soles)
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Monto Total',
                prefixText: 'S/ ',
                prefixIcon: const Icon(Icons.attach_money),
                border: const OutlineInputBorder(),
                helperText: _result!.amount != null
                    ? 'Detectado: S/ ${_result!.amount!.toStringAsFixed(2)}'
                    : '⚠️ No se detectó monto, ingresa manualmente',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            // Nombre del producto
            TextField(
              controller: _productController,
              decoration: InputDecoration(
                labelText: 'Producto / Ítem',
                prefixIcon: const Icon(Icons.inventory_2_outlined),
                border: const OutlineInputBorder(),
                helperText: _result!.productName != null
                    ? 'Producto detectado: ${_result!.productName}'
                    : 'Ingresa el nombre del producto (opcional)',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            // Comercio / Descripción
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Comercio / Lugar',
                prefixIcon: const Icon(Icons.store),
                border: const OutlineInputBorder(),
                helperText: _result!.merchant != null
                    ? 'Comercio detectado: ${_result!.merchant}'
                    : 'No se detectó comercio',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            
            // Selector de Cuenta
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Cuenta de Origen',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
              initialValue: _singleAccountId,
              items: ref.watch(accountsStreamProvider).when(
                    data: (accounts) => accounts.map((acc) {
                      return DropdownMenuItem(value: acc.id, child: Text(acc.name));
                    }).toList(),
                    loading: () => [],
                    error: (_, __) => [],
                  ),
              onChanged: (val) => setState(() => _singleAccountId = val),
            ),
            const SizedBox(height: 16),
            
            // Selector de Categoría
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              initialValue: _singleCategoryId != null && 
                     ref.watch(expenseCategoriesStreamProvider).value?.any((c) => c.id == _singleCategoryId) == true
                 ? _singleCategoryId
                 : null,
              items: ref.watch(expenseCategoriesStreamProvider).when(
                    data: (categories) => categories.map((cat) {
                      return DropdownMenuItem(value: cat.id, child: Text(cat.name));
                    }).toList(),
                    loading: () => [],
                    error: (_, __) => [],
                  ),
              onChanged: (val) {
                setState(() {
                  _singleCategoryId = val;
                  _singleSubcategoryId = null; // Reset subcategory when category changes
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Selector de Subcategoría (condicional)
            if (_singleCategoryId != null)
              ref.watch(subcategoriesStreamProvider(_singleCategoryId!)).when(
                    data: (subcategories) {
                      if (subcategories.isEmpty) return const SizedBox.shrink();
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Subcategoría (Opcional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.subdirectory_arrow_right),
                        ),
                        initialValue: _singleSubcategoryId != null &&
                               subcategories.any((sub) => sub.id == _singleSubcategoryId)
                            ? _singleSubcategoryId
                            : null,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Ninguna')),
                          ...subcategories.map((sub) {
                            return DropdownMenuItem(value: sub.id, child: Text(sub.name));
                          }),
                        ],
                        onChanged: (val) => setState(() => _singleSubcategoryId = val),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
            if (_singleCategoryId != null) const SizedBox(height: 16),

            // Selector de Fecha Editable
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Fecha de la boleta'),
              subtitle: Text(
                _singleSelectedDate != null
                    ? DateFormat('dd/MM/yyyy').format(_singleSelectedDate!)
                    : 'Seleccionar fecha',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.edit, size: 20),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _singleSelectedDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _singleSelectedDate = picked);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Opciones globales
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Datos Generales', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Comercio / Lugar (Para todas)',
                    prefixIcon: const Icon(Icons.store),
                    border: const OutlineInputBorder(),
                    helperText: _result!.merchant != null
                        ? 'Comercio detectado: ${_result!.merchant}'
                        : null,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                
                // Selector de Fecha
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Fecha'),
                  subtitle: Text(
                    _multipleSelectedDate != null
                        ? DateFormat('dd/MM/yyyy').format(_multipleSelectedDate!)
                        : 'Seleccionar fecha',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.edit, size: 20),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _multipleSelectedDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        _multipleSelectedDate = picked;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Cuenta de Origen',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance_wallet),
                  ),
                  initialValue: _multipleAccountId,
                  items: ref.watch(accountsStreamProvider).when(
                        data: (accounts) => accounts.map((acc) {
                          return DropdownMenuItem(value: acc.id, child: Text(acc.name));
                        }).toList(),
                        loading: () => [],
                        error: (_, __) => [],
                      ),
                  onChanged: (val) => setState(() => _multipleAccountId = val),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Categoría para todos los ítems',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  initialValue: _multipleCategoryId,
                  items: ref.watch(expenseCategoriesStreamProvider).when(
                        data: (categories) => categories.map((cat) {
                          return DropdownMenuItem(value: cat.id, child: Text(cat.name));
                        }).toList(),
                        loading: () => [],
                        error: (_, __) => [],
                      ),
                  onChanged: (val) => setState(() => _multipleCategoryId = val),
                  hint: const Text('Ej. Alimentación'),
                ),
                if (_result!.date != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('Fecha de compra: ${DateFormat('dd MM yyyy').format(_result!.date!)}', style: const TextStyle(color: Colors.grey)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Lista de items
        if (_editableItems.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('No se encontraron productos con formato de ítem+precio en la boleta.'),
            ),
          )
        else ...[
          Text('Ítems detectados (${_editableItems.where((e) => e.isSelected).length})', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _editableItems.length,
            itemBuilder: (ctx, idx) {
              final item = _editableItems[idx];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: item.isSelected ? null : Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: item.isSelected,
                            onChanged: (val) => setState(() => item.isSelected = val ?? false),
                          ),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: item.nameController,
                              decoration: const InputDecoration(
                                hintText: 'Nombre',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              enabled: item.isSelected,
                              style: TextStyle(
                                decoration: item.isSelected ? null : TextDecoration.lineThrough,
                                color: item.isSelected ? null : Colors.grey,
                              ),
                            ),
                          ),
                          Container(width: 1, height: 30, color: Colors.grey.shade300),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: item.priceController,
                              decoration: const InputDecoration(
                                prefixText: 'S/ ',
                                hintText: '0.00',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              enabled: item.isSelected,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: item.isSelected ? Colors.green.shade700 : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.isSelected)
                         Padding(
                           padding: const EdgeInsets.only(left: 48.0, right: 8.0, bottom: 4.0),
                           child: Column(
                             children: [
                               DropdownButtonFormField<String>(
                                 decoration: const InputDecoration(
                                   border: InputBorder.none,
                                   isDense: true,
                                   contentPadding: EdgeInsets.zero,
                                   hintText: 'Categoría individual',
                                   hintStyle: TextStyle(fontSize: 12),
                                 ),
                                 isExpanded: true,
                                 initialValue: item.categoryId,
                                 iconSize: 16,
                                 items: ref.watch(expenseCategoriesStreamProvider).when(
                                       data: (categories) => categories.map((cat) {
                                         return DropdownMenuItem(value: cat.id, child: Text(cat.name, style: const TextStyle(fontSize: 13, color: Colors.grey)));
                                       }).toList(),
                                       loading: () => [],
                                       error: (_, __) => [],
                                     ),
                                 onChanged: (val) {
                                   setState(() {
                                     item.categoryId = val;
                                     item.subcategoryId = null; // Reset subcategory when category changes
                                   });
                                 },
                               ),
                               if (item.categoryId != null)
                                 ref.watch(subcategoriesStreamProvider(item.categoryId!)).when(
                                   data: (subcategories) {
                                     if (subcategories.isEmpty) return const SizedBox.shrink();
                                     
                                     // Ensure the selected subcategory is still valid, else clear it
                                     if (item.subcategoryId != null && !subcategories.any((s) => s.id == item.subcategoryId)) {
                                       WidgetsBinding.instance.addPostFrameCallback((_) {
                                         if (mounted) setState(() => item.subcategoryId = null);
                                       });
                                     }
                                     return DropdownButtonFormField<String>(
                                       decoration: const InputDecoration(
                                         border: InputBorder.none,
                                         isDense: true,
                                         contentPadding: EdgeInsets.zero,
                                         hintText: 'Subcategoría',
                                         hintStyle: TextStyle(fontSize: 12),
                                       ),
                                       isExpanded: true,
                                       initialValue: item.subcategoryId,
                                       iconSize: 16,
                                       items: subcategories.map((sub) {
                                         return DropdownMenuItem(value: sub.id, child: Text(sub.name, style: const TextStyle(fontSize: 13, color: Colors.grey)));
                                       }).toList(),
                                       onChanged: (val) => setState(() => item.subcategoryId = val),
                                     );
                                   },
                                   loading: () => const SizedBox.shrink(),
                                   error: (_, __) => const SizedBox.shrink(),
                                 ),
                             ],
                           ),
                         ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _editableItems.add(_EditableItem('', 0.0))),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Añadir ítem manual'),
            ),
          ),
        ]
      ],
    );
  }

  // ─── Estado error ─────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 72, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _result!.errorMessage ?? 'Error desconocido',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => setState(() => _result = null),
            icon: const Icon(Icons.refresh),
            label: const Text('Intentar de nuevo'),
          ),
        ],
      ),
    );
  }
}

// ─── WIDGETS AUXILIARES ────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool comingSoon;
  final VoidCallback onTap;
  final Color color;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.color,
  }) : comingSoon = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                const Spacer(),
                if (comingSoon)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Próx.',
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.amber.shade800,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                if (!comingSoon && isSelected)
                  Icon(Icons.check_circle, size: 16, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? color : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style:
                  TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanOptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ScanOptionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipBanner extends StatelessWidget {
  final String text;
  const _TipBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates, color: Colors.amber.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanResultPreview extends StatelessWidget {
  final String rawText;
  final String? imagePath;

  const _ScanResultPreview({required this.rawText, this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(Icons.saved_search),
        title: const Text('Ver original escaneado', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Revisa la foto o el texto extraído'),
        children: [
          DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  labelColor: Colors.deepPurple,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(icon: Icon(Icons.image), text: 'Foto'),
                    Tab(icon: Icon(Icons.text_snippet), text: 'Texto OCR'),
                  ],
                ),
                SizedBox(
                  height: 400,
                  child: TabBarView(
                    children: [
                      // Pestaña de Foto
                      imagePath != null
                          ? Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(imagePath!),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            )
                          : const Center(child: Text('Imagen no disponible')),
                      // Pestaña de Texto
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(8.0),
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            rawText,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              height: 1.5,
                              color: Colors.black87, // Letra más oscura para mejor contraste
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    if (confidence >= 0.8) {
      badgeColor = Colors.green;
      badgeIcon = Icons.verified;
      badgeText = 'Alta confianza (${(confidence * 100).toStringAsFixed(0)}%)';
    } else if (confidence >= 0.5) {
      badgeColor = Colors.orange;
      badgeIcon = Icons.warning_amber_rounded;
      badgeText = 'Confianza media (${(confidence * 100).toStringAsFixed(0)}%)';
    } else {
      badgeColor = Colors.red;
      badgeIcon = Icons.error_outline;
      badgeText = 'Baja confianza (${(confidence * 100).toStringAsFixed(0)}%)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 14, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}
