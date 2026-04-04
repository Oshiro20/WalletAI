import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../../data/database/drift_database.dart';
import '../../providers/database_providers.dart';
import '../../providers/transaction_repository_provider.dart';
import 'widgets/account_selector.dart';
import 'widgets/category_selector.dart';
import '../../../data/datasources/notification_service.dart';

class EditTransactionScreen extends ConsumerStatefulWidget {
  final String transactionId;

  const EditTransactionScreen({super.key, required this.transactionId});

  @override
  ConsumerState<EditTransactionScreen> createState() =>
      _EditTransactionScreenState();
}

class _EditTransactionScreenState extends ConsumerState<EditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _productNameController = TextEditingController();

  Transaction? _original;
  DateTime _selectedDate = DateTime.now();
  String _transactionType = 'expense';
  String _currency = 'PEN';
  String? _selectedAccountId;
  String? _destinationAccountId; // Account ID for transfers
  String? _selectedCategoryId;
  String? _selectedSubcategoryId;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _productNameController.dispose();
    super.dispose();
  }

  Future<void> _loadTransaction() async {
    final dao = ref.read(transactionsDaoProvider);
    final t = await dao.getTransactionById(widget.transactionId);
    if (t != null && mounted) {
      setState(() {
        _original = t;
        _transactionType = t.type;
        _amountController.text = t.amount.toStringAsFixed(2);
        _currency = t.currency;
        _productNameController.text = t.productName ?? '';
        _descriptionController.text = t.description ?? '';
        _selectedDate = t.date;
        _selectedAccountId = t.accountId;
        _destinationAccountId = t.destinationAccountId;
        _selectedCategoryId = t.categoryId;
        _selectedSubcategoryId = t.subcategoryId;
        _isLoading = false;
      });
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona una cuenta')));
      return;
    }
    if (_transactionType == 'transfer' && _destinationAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la cuenta de destino')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final amount = double.parse(_amountController.text.replaceAll(',', '.'));

      final updated = _original!.copyWith(
        type: _transactionType,
        amount: amount,
        accountId: _selectedAccountId!,
        destinationAccountId: drift.Value(
          _transactionType == 'transfer' ? _destinationAccountId : null,
        ),
        categoryId: drift.Value(_selectedCategoryId),
        subcategoryId: drift.Value(_selectedSubcategoryId),
        productName: drift.Value(
          _productNameController.text.isEmpty
              ? null
              : _productNameController.text,
        ),
        description: drift.Value(
          _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
        ),
        date: _selectedDate,
        currency: _currency,
        updatedAt: DateTime.now(),
      );

      final repository = ref.read(transactionRepositoryProvider);

      await repository.updateTransaction(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transacción actualizada')),
        );

        // Check budget alerts if expense
        if (_transactionType == 'expense') {
          _checkBudgetAlerts();
        }

        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

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
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final typeColor = _transactionType == 'expense'
        ? Colors.red.shade400
        : _transactionType == 'income'
        ? Colors.green.shade400
        : Colors.blue.shade400;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Transacción'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveChanges,
              child: const Text(
                'Guardar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type selector
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: ['expense', 'income', 'transfer'].map((type) {
                      final labels = {
                        'expense': 'Gasto',
                        'income': 'Ingreso',
                        'transfer': 'Transferencia',
                      };
                      final colors = {
                        'expense': Colors.red.shade400,
                        'income': Colors.green.shade400,
                        'transfer': Colors.blue.shade400,
                      };
                      final isSelected = _transactionType == type;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _transactionType = type),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors[type]!.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              labels[type]!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? colors[type]
                                    : Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Amount
              Row(
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Monto',
                        prefixText: '$_currency ',
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money, color: typeColor),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingresa un monto';
                        if (double.tryParse(v.replaceAll(',', '.')) == null) {
                          return 'Monto inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Producto (nuevo campo)
              TextFormField(
                controller: _productNameController,
                decoration: const InputDecoration(
                  labelText: 'Producto / Ítem (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                  hintText: 'Ej. Mandarina, Leche Gloria',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              // Comercio / Descripción
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Comercio / Descripción (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store_outlined),
                  hintText: 'Ej. Lider Cloud, Mercado Central',
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              // Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  DateFormat('EEEE, dd MMMM yyyy', 'es').format(_selectedDate),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectDate,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              const SizedBox(height: 16),

              // Account (Origen)
              AccountSelector(
                labelText: _transactionType == 'transfer'
                    ? 'Cuenta de Origen'
                    : 'Cuenta',
                selectedAccountId: _selectedAccountId,
                onAccountSelected: (id) =>
                    setState(() => _selectedAccountId = id),
              ),
              const SizedBox(height: 16),

              // Account (Destino)
              if (_transactionType == 'transfer') ...[
                AccountSelector(
                  labelText: 'Cuenta de Destino',
                  selectedAccountId: _destinationAccountId,
                  accountIdToExclude: _selectedAccountId,
                  onAccountSelected: (id) =>
                      setState(() => _destinationAccountId = id),
                ),
                const SizedBox(height: 16),
              ],

              // Category (only for non-transfer)
              if (_transactionType != 'transfer')
                CategorySelector(
                  transactionType: _transactionType,
                  selectedCategoryId: _selectedCategoryId,
                  onCategorySelected: (catId) {
                    setState(() {
                      _selectedCategoryId = catId;
                    });
                  },
                ),

              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: typeColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Guardar Cambios',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
