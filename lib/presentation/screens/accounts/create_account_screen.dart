import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../data/database/drift_database.dart';
import '../../providers/database_providers.dart';
import '../../../core/theme/app_colors.dart';

class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0.00');
  final _descriptionController = TextEditingController();

  // Controles para tarjeta de crédito
  final _creditLimitController = TextEditingController();
  final _closingDayController = TextEditingController();
  final _paymentDayController = TextEditingController();

  String _accountType = 'bank'; // cash, bank, card, savings
  String _currency = 'PEN';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _descriptionController.dispose();
    _creditLimitController.dispose();
    _closingDayController.dispose();
    _paymentDayController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final dao = ref.read(accountsDaoProvider);
      final balance = double.parse(_balanceController.text);
      const uuid = Uuid();

      await dao.createAccount(
        AccountsCompanion.insert(
          id: uuid.v4(),
          name: _nameController.text,
          type: _accountType,
          balance: drift.Value(balance),
          currency: drift.Value(_currency),
          isActive: const drift.Value(true),
          sortOrder: const drift.Value(0),
          creditLimit: _accountType == 'credit_card'
              ? drift.Value(double.tryParse(_creditLimitController.text))
              : const drift.Value.absent(),
          closingDay: _accountType == 'credit_card'
              ? drift.Value(int.tryParse(_closingDayController.text))
              : const drift.Value.absent(),
          paymentDueDay: _accountType == 'credit_card'
              ? drift.Value(int.tryParse(_paymentDayController.text))
              : const drift.Value.absent(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta creada exitosamente')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al crear cuenta: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Cuenta'),
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
            IconButton(icon: const Icon(Icons.check), onPressed: _saveAccount),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Nombre de cuenta
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la cuenta',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa un nombre';
                }
                return null;
              },
              autofocus: true,
            ),

            const SizedBox(height: 16),

            // Tipo de cuenta
            _buildAccountTypeSelector(),

            const SizedBox(height: 16),

            // Campos específicos para tarjeta de crédito
            if (_accountType == 'credit_card') ...[
              TextFormField(
                controller: _creditLimitController,
                decoration: const InputDecoration(
                  labelText: 'Línea de Crédito',
                  prefixText: 'S/ ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_score),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (_accountType == 'credit_card' &&
                      (value == null || value.isEmpty)) {
                    return 'Ingresa la línea de crédito';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _closingDayController,
                      decoration: const InputDecoration(
                        labelText: 'Día de Corte',
                        hintText: 'Ej. 15',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.date_range),
                        counterText: "",
                      ),
                      maxLength: 2,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (_accountType == 'credit_card') {
                          if (value == null || value.isEmpty) {
                            return 'Requerido';
                          }
                          final day = int.tryParse(value);
                          if (day == null || day < 1 || day > 31) {
                            return 'Día inválido';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _paymentDayController,
                      decoration: const InputDecoration(
                        labelText: 'Día de Pago',
                        hintText: 'Ej. 5',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.event),
                        counterText: "",
                      ),
                      maxLength: 2,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (_accountType == 'credit_card') {
                          if (value == null || value.isEmpty) {
                            return 'Requerido';
                          }
                          final day = int.tryParse(value);
                          if (day == null || day < 1 || day > 31) {
                            return 'Día inválido';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Balance inicial / Saldo Actual
            TextFormField(
              controller: _balanceController,
              decoration: InputDecoration(
                labelText: _accountType == 'credit_card'
                    ? 'Saldo Actual'
                    : 'Saldo Actual',
                helperText: _accountType == 'credit_card'
                    ? 'Si ya tienes consumos, ingresa el monto con signo menos (ej: -500)'
                    : 'Dinero disponible en la cuenta',
                prefixText: 'S/ ',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                // Permite números, punto decimal y signo negativo
                FilteringTextInputFormatter.allow(RegExp(r'^\-?\d*\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa el saldo actual';
                }
                final amount = double.tryParse(value);
                if (amount == null) {
                  return 'Ingresa un número válido';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Moneda
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Moneda',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_exchange),
              ),
              items: const [
                DropdownMenuItem(value: 'PEN', child: Text('Soles (S/)')),
                DropdownMenuItem(value: 'USD', child: Text('Dólares (\$)')),
                DropdownMenuItem(value: 'EUR', child: Text('Euros (€)')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _currency = value;
                  });
                }
              },
            ),

            const SizedBox(height: 32),

            // Botón guardar
            FilledButton.icon(
              onPressed: _isLoading ? null : _saveAccount,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isLoading ? 'Guardando...' : 'Crear Cuenta'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de cuenta',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _AccountTypeButton(
                label: 'Efectivo',
                icon: Icons.payments,
                color: AppColors.income,
                isSelected: _accountType == 'cash',
                onTap: () => setState(() => _accountType = 'cash'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AccountTypeButton(
                label: 'Banco (Débito)',
                icon: Icons.account_balance,
                color: AppColors.primary,
                isSelected: _accountType == 'bank',
                onTap: () => setState(() => _accountType = 'bank'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _AccountTypeButton(
                label: 'Billetera (Yape/Plin)',
                icon: Icons
                    .smartphone, // Icono de celular para billeteras digitales
                color: Colors.orange,
                isSelected: _accountType == 'wallet',
                onTap: () => setState(() => _accountType = 'wallet'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AccountTypeButton(
                label: 'Tarjeta Crédito',
                icon: Icons.credit_card,
                color: Colors.purple,
                isSelected: _accountType == 'credit_card',
                onTap: () => setState(() => _accountType = 'credit_card'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _AccountTypeButton(
                label: 'Ahorros',
                icon: Icons.savings,
                color: AppColors.transfer,
                isSelected: _accountType == 'savings',
                onTap: () => setState(() => _accountType = 'savings'),
              ),
            ),
            const Spacer(), // Mantener alineación si hay número impar de botones
          ],
        ),
      ],
    );
  }
}

class _AccountTypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _AccountTypeButton({
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
            Icon(icon, color: isSelected ? color : Colors.grey, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
