import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../providers/database_providers.dart';
import '../../../data/database/drift_database.dart';
import '../transactions/widgets/account_selector.dart';
import '../transactions/widgets/category_selector.dart';

class CreateRecurringPaymentScreen extends ConsumerStatefulWidget {
  const CreateRecurringPaymentScreen({super.key});

  @override
  ConsumerState<CreateRecurringPaymentScreen> createState() =>
      _CreateRecurringPaymentScreenState();
}

class _CreateRecurringPaymentScreenState
    extends ConsumerState<CreateRecurringPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedAccountId;
  String? _selectedCategoryId;
  String _frequency = 'monthly';
  DateTime _nextDueDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Pago Recurrente')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre (ej. Netflix)',
              ),
              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: 'S/ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) =>
                  double.tryParse(v ?? '') == null ? 'Monto inválido' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Frecuencia'),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('Diario')),
                DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
                DropdownMenuItem(value: 'monthly', child: Text('Mensual')),
                DropdownMenuItem(value: 'yearly', child: Text('Anual')),
              ],
              onChanged: (v) => setState(() => _frequency = v!),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Primer Cobro'),
              subtitle: Text(
                '${_nextDueDate.day}/${_nextDueDate.month}/${_nextDueDate.year}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _nextDueDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (date != null) setState(() => _nextDueDate = date);
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Cuenta de Cargo',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            AccountSelector(
              selectedAccountId: _selectedAccountId,
              onAccountSelected: (id) =>
                  setState(() => _selectedAccountId = id),
            ),
            const SizedBox(height: 16),
            const Text(
              'Categoría (Opcional)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            CategorySelector(
              selectedCategoryId: _selectedCategoryId,
              transactionType: 'expense',
              onCategorySelected: (id) =>
                  setState(() => _selectedCategoryId = id),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _savePayment,
              child: const Text('Guardar Suscripción'),
            ),
          ],
        ),
      ),
    );
  }

  void _savePayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona una cuenta')));
      return;
    }

    final amount = double.parse(_amountController.text);
    final dao = ref.read(recurringPaymentsDaoProvider);

    await dao.createRecurringPayment(
      RecurringPaymentsCompanion.insert(
        id: const Uuid().v4(),
        name: _nameController.text,
        amount: amount,
        accountId: _selectedAccountId!,
        categoryId: drift.Value(_selectedCategoryId),
        frequency: _frequency,
        nextDueDate: _nextDueDate,
        createdAt: DateTime.now(),
      ),
    );

    if (mounted) context.pop();
  }
}
