import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/datasources/currency_service.dart';
import '../../../core/utils/currency_data.dart';

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() => _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  final _service = CurrencyService();
  final _amountCtrl = TextEditingController();

  String _fromCurrency = 'PEN';
  String _toCurrency = 'USD';
  double? _result;
  bool _isLoading = false;
  Map<String, String> _currencies = {};

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
  }

  Future<void> _loadCurrencies() async {
    setState(() => _isLoading = true);
    try {
      final currencies = await _service.getCurrencies();
      setState(() {
        _currencies = currencies;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar monedas: $e')),
        );
      }
    }
  }

  Future<void> _convert() async {
    if (_amountCtrl.text.isEmpty) return;
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null) return;

    setState(() => _isLoading = true);
    try {
      // Usar servicio para convertir
      // Nota: la API frankfurter requiere 'from' y 'to' distintos o retorna error si es la misma base
      if (_fromCurrency == _toCurrency) {
        setState(() {
          _result = amount;
          _isLoading = false;
        });
        return;
      }
      
      // Llamada directa a API: /latest?amount=10&from=USD&to=EUR
      // Implementación básica en servicio
        // Aquí simulamos uso de cache si ya tenemos tasas base PEN, 
        // pero para simplificar usaremos el endpoint de conversión.
      
      // Ajuste: el servicio en el paso anterior tenía un método convert
      // pero usaba logica de cache base PEN.
      // Vamos a usar endpoint publico directo para conversión exacta.
       final res = await _service.convert(
        amount: amount, 
        from: _fromCurrency, 
        to: _toCurrency
      );

      if (mounted) {
        setState(() {
          _result = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _swapCurrencies() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
      _result = null; // Limpiar resultado al cambiar
    });
    if (_amountCtrl.text.isNotEmpty) _convert();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversor de Moneda'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Card principal
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Campo Monto
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Monto',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                         // Debounce manual o botón "Convertir"
                      },
                      onSubmitted: (_) => _convert(),
                    ),
                    const SizedBox(height: 24),

                    // Selectores de Moneda
                    Row(
                      children: [
                        Expanded(
                          child: _buildCurrencyDropdown(_fromCurrency, (val) {
                            setState(() {
                              _fromCurrency = val!;
                              _result = null;
                            });
                          }),
                        ),
                        IconButton(
                          icon: const Icon(Icons.swap_horiz, size: 32),
                          onPressed: _swapCurrencies,
                          tooltip: 'Invertir monedas',
                          color: theme.colorScheme.primary,
                        ),
                        Expanded(
                          child: _buildCurrencyDropdown(_toCurrency, (val) {
                            setState(() {
                              _toCurrency = val!;
                              _result = null;
                            });
                          }),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),

                    // Resultado
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else if (_result != null)
                      Column(
                        children: [
                          Text(
                            '${_amountCtrl.text} $_fromCurrency =',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_result!.toStringAsFixed(2)} $_toCurrency',
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _convert,
                        icon: const Icon(Icons.currency_exchange),
                        label: const Text('Convertir'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const Spacer(),
            Text(
              'Tasas de cambio aproximadas vía Frankfurter API.\nNo usar para trading real.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyDropdown(String value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: _currencies.containsKey(value) ? value : null,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      isExpanded: true,
      items: _currencies.keys.map((code) {
        final details = kCurrencyDetails[code];
        final displayText = details != null 
            ? '${details.flag} $code - ${details.name}' 
            : code;

        return DropdownMenuItem(
          value: code,
          child: Text(
            displayText, 
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        );
      }).toList(),
      onChanged: onChanged,
      hint: const Text('Cargando...'),
    );
  }
}
