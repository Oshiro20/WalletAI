import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/credit_card_calculator.dart';
import '../../../../data/database/drift_database.dart';

/// Selector interactivo y simulador para compras con tarjeta de crédito (Sin cuotas vs Con cuotas)
class CreditCardInstallmentSelector extends StatefulWidget {
  final Account account;
  final double amount;
  final DateTime purchaseDate;
  final bool isInstallment;
  final int installmentsCount;
  final bool hasInterest;
  final TextEditingController teaController;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<int> onInstallmentsCountChanged;
  final ValueChanged<bool> onHasInterestChanged;
  final ValueChanged<String> onTeaChanged;
  final bool useManualMonthlyPayment;
  final TextEditingController? manualMonthlyPaymentController;
  final ValueChanged<bool>? onManualMonthlyPaymentModeChanged;
  final ValueChanged<String>? onManualMonthlyPaymentChanged;
  final String? transactionCurrency;

  const CreditCardInstallmentSelector({
    super.key,
    required this.account,
    required this.amount,
    required this.purchaseDate,
    required this.isInstallment,
    required this.installmentsCount,
    required this.hasInterest,
    required this.teaController,
    required this.onModeChanged,
    required this.onInstallmentsCountChanged,
    required this.onHasInterestChanged,
    required this.onTeaChanged,
    this.useManualMonthlyPayment = false,
    this.manualMonthlyPaymentController,
    this.onManualMonthlyPaymentModeChanged,
    this.onManualMonthlyPaymentChanged,
    this.transactionCurrency,
  });

  @override
  State<CreditCardInstallmentSelector> createState() =>
      _CreditCardInstallmentSelectorState();
}

class _CreditCardInstallmentSelectorState
    extends State<CreditCardInstallmentSelector> {
  late final TextEditingController _installmentsController;
  final FocusNode _installmentsFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _installmentsController = TextEditingController(
      text: widget.installmentsCount.toString(),
    );
  }

  @override
  void didUpdateWidget(covariant CreditCardInstallmentSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincronizar el campo si cambió externamente (por chips o botones +/-)
    // sin interrumpir al usuario mientras escribe en el campo.
    final expected = widget.installmentsCount.toString();
    if (!_installmentsFocusNode.hasFocus &&
        _installmentsController.text != expected) {
      _installmentsController.text = expected;
    }
  }

  @override
  void dispose() {
    _installmentsController.dispose();
    _installmentsFocusNode.dispose();
    super.dispose();
  }

  void _applyInstallmentCount(int newCount, {bool syncText = true}) {
    final clamped = newCount.clamp(1, 120);
    if (syncText) {
      _installmentsController.text = clamped.toString();
      _installmentsController.selection = TextSelection.collapsed(
        offset: _installmentsController.text.length,
      );
    }
    widget.onInstallmentsCountChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayCurrency =
        widget.transactionCurrency ?? widget.account.currency;
    final currencyFmt = NumberFormat.currency(
      locale: 'es_PE',
      symbol: '$displayCurrency ',
    );
    final dateFmt = DateFormat('dd/MM/yyyy');

    final tea =
        double.tryParse(widget.teaController.text.replaceAll(',', '.')) ??
        (widget.account.tea ?? 54.9);

    final manualMonthly = widget.useManualMonthlyPayment
        ? double.tryParse(
                (widget.manualMonthlyPaymentController?.text ?? '')
                    .replaceAll(',', '.'),
              ) ??
              0.0
        : 0.0;

    final plan = widget.useManualMonthlyPayment && manualMonthly > 0
        ? CreditCardCalculator.calculateFromMonthlyPayment(
            principal: widget.amount > 0 ? widget.amount : 0.0,
            installments: widget.installmentsCount,
            monthlyPayment: manualMonthly,
            purchaseDate: widget.purchaseDate,
            closingDay: widget.account.closingDay,
            paymentDueDay: widget.account.paymentDueDay,
          )
        : CreditCardCalculator.calculatePlan(
            principal: widget.amount > 0 ? widget.amount : 0.0,
            installments: widget.installmentsCount,
            tea: tea,
            hasInterest: widget.hasInterest,
            purchaseDate: widget.purchaseDate,
            closingDay: widget.account.closingDay,
            paymentDueDay: widget.account.paymentDueDay,
          );

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade900
            : Colors.blue.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Row(
            children: [
              Icon(
                Icons.credit_card,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tarjeta: ${widget.account.name}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (widget.account.closingDay != null &&
                  widget.account.paymentDueDay != null)
                Text(
                  'Corte: ${widget.account.closingDay} | Pago: ${widget.account.paymentDueDay}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Selector de Modalidad (Segmented Button)
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text('Sin cuotas (Directo)'),
                icon: Icon(Icons.flash_on),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('En cuotas'),
                icon: Icon(Icons.calendar_month),
              ),
            ],
            selected: {widget.isInstallment},
            onSelectionChanged: (newSelection) {
              widget.onModeChanged(newSelection.first);
            },
          ),
          const SizedBox(height: 16),

          // Contenido según la modalidad
          if (!widget.isInstallment)
            _buildDirectPaymentView(context, plan, currencyFmt, dateFmt)
          else
            _buildInstallmentsView(
              context,
              plan,
              currencyFmt,
              dateFmt,
              displayCurrency,
            ),
        ],
      ),
    );
  }

  /// Vista cuando selecciona consumo directo (Sin cuotas)
  Widget _buildDirectPaymentView(
    BuildContext context,
    InstallmentPlanCalculation plan,
    NumberFormat currencyFmt,
    DateFormat dateFmt,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Text(
                '0.0% de Interés (Período de Gracia)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Se facturará en tu próximo estado de cuenta como consumo regular.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vencimiento de pago aprox.:',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                dateFmt.format(plan.firstDueDate),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Vista cuando selecciona pago financiado (En cuotas)
  Widget _buildInstallmentsView(
    BuildContext context,
    InstallmentPlanCalculation plan,
    NumberFormat currencyFmt,
    DateFormat dateFmt,
    String displayCurrency,
  ) {
    final theme = Theme.of(context);
    final quickInstallments = [2, 3, 6, 9, 12, 18, 24, 36];
    final supportsManualMonthly =
        widget.manualMonthlyPaymentController != null &&
        widget.onManualMonthlyPaymentModeChanged != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ingreso manual de cuotas + botones -/+
        Row(
          children: [
            Expanded(
              child: Text(
                'Número de Cuotas:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton.outlined(
              onPressed: widget.installmentsCount > 1
                  ? () => _applyInstallmentCount(widget.installmentsCount - 1)
                  : null,
              icon: const Icon(Icons.remove, size: 18),
              tooltip: 'Disminuir cuotas',
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 78,
              child: TextFormField(
                controller: _installmentsController,
                focusNode: _installmentsFocusNode,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  hintText: 'Cuotas',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed >= 1) {
                    _applyInstallmentCount(parsed, syncText: false);
                  }
                },
                validator: (_) {
                  final parsed = int.tryParse(_installmentsController.text);
                  if (parsed == null || parsed < 1 || parsed > 120) {
                    return '1-120';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 6),
            IconButton.outlined(
              onPressed: widget.installmentsCount < 120
                  ? () => _applyInstallmentCount(widget.installmentsCount + 1)
                  : null,
              icon: const Icon(Icons.add, size: 18),
              tooltip: 'Aumentar cuotas',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Selector rápido de número de cuotas (Chips)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: quickInstallments.map((count) {
              final isSelected = widget.installmentsCount == count;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$count cuotas'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) _applyInstallmentCount(count);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Toggle ¿Cuotas sin intereses? (cuando no se está ingresando cuota fija del banco)
        if (!widget.useManualMonthlyPayment) ...[
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: const Text('¿Cuotas sin intereses?'),
              subtitle: Text(
                widget.hasInterest
                    ? 'Aplica financiamiento bancario con intereses'
                    : 'Promoción o convenio comercial (0% interés)',
                style: theme.textTheme.bodySmall,
              ),
              value: !widget.hasInterest,
              onChanged: (zeroInterest) {
                widget.onHasInterestChanged(!zeroInterest);
              },
              secondary: Icon(
                !widget.hasInterest ? Icons.verified : Icons.percent,
                color: !widget.hasInterest
                    ? Colors.green
                    : theme.colorScheme.primary,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Opción de método de cálculo cuando aplica interés o está disponible la cuota manual
        if (supportsManualMonthly &&
            (widget.hasInterest || widget.useManualMonthlyPayment)) ...[
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text('Calcular por TEA %'),
                icon: Icon(Icons.percent, size: 16),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('Cuota del banco'),
                icon: Icon(Icons.edit_note, size: 16),
              ),
            ],
            selected: {widget.useManualMonthlyPayment},
            onSelectionChanged: (selection) {
              widget.onManualMonthlyPaymentModeChanged!(selection.first);
            },
          ),
          const SizedBox(height: 12),
        ],

        // Campo editable de Cuota del Banco O TEA %
        if (widget.useManualMonthlyPayment &&
            widget.manualMonthlyPaymentController != null) ...[
          TextFormField(
            controller: widget.manualMonthlyPaymentController,
            decoration: InputDecoration(
              labelText: 'Cuota mensual exacta ($displayCurrency)',
              hintText: 'Ej. 115.40',
              helperText:
                  'Calcula interés total y TEA implícita automáticamente',
              prefixText: '$displayCurrency ',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: theme.colorScheme.surface,
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: widget.onManualMonthlyPaymentChanged,
          ),
          const SizedBox(height: 16),
        ] else if (widget.hasInterest) ...[
          TextFormField(
            controller: widget.teaController,
            decoration: InputDecoration(
              labelText: 'Tasa Efectiva Anual (TEA %)',
              hintText: 'Ej. 54.9',
              helperText: 'Tasa editable para esta compra puntual',
              suffixText: '% TEA',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: theme.colorScheme.surface,
              prefixIcon: const Icon(Icons.calculate_outlined),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: widget.onTeaChanged,
          ),
          const SizedBox(height: 16),
        ],

        // Tarjeta de Simulación en Vivo
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.useManualMonthlyPayment
                        ? 'Cuota mensual ingresada:'
                        : 'Cuota mensual estimada:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    currencyFmt.format(plan.monthlyPayment),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Primera fecha de pago:', style: theme.textTheme.bodySmall),
                  Text(
                    dateFmt.format(plan.firstDueDate),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (widget.useManualMonthlyPayment && plan.hasInterest) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TEA implícita:', style: theme.textTheme.bodySmall),
                    Text(
                      '${plan.tea.toStringAsFixed(1)}% (TEM ${plan.tem.toStringAsFixed(2)}%)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Interés total estimado:', style: theme.textTheme.bodySmall),
                  Text(
                    plan.hasInterest && plan.totalInterest > 0
                        ? currencyFmt.format(plan.totalInterest)
                        : '${currencyFmt.format(0)} (Sin intereses)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: plan.hasInterest && plan.totalInterest > 0
                          ? Colors.orange.shade800
                          : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total a pagar:', style: theme.textTheme.bodySmall),
                  Text(
                    currencyFmt.format(plan.totalToPay),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Botón para ver cronograma
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                  label: const Text('Ver Cronograma de Pagos'),
                  onPressed: widget.amount > 0
                      ? () =>
                          _showScheduleModal(context, plan, currencyFmt, dateFmt)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Muestra el modal con el cronograma mensual detallado de cuotas
  void _showScheduleModal(
    BuildContext context,
    InstallmentPlanCalculation plan,
    NumberFormat currencyFmt,
    DateFormat dateFmt,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Cronograma de Pagos (${plan.installments} cuotas)',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total financiado: ${currencyFmt.format(plan.principal)} • TEA: ${plan.hasInterest ? '${plan.tea.toStringAsFixed(1)}%' : '0%'}',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: plan.schedule.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = plan.schedule[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 16,
                            child: Text(
                              '${item.number}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          title: Text(
                            currencyFmt.format(item.payment),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Vence: ${dateFmt.format(item.dueDate)}'
                            '${plan.hasInterest ? ' • Int: ${currencyFmt.format(item.interestPortion)}' : ''}',
                          ),
                          trailing: Text(
                            'Saldo: ${currencyFmt.format(item.remainingBalance)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
