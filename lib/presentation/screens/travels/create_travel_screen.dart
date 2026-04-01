import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;

import '../../../data/database/drift_database.dart';
import '../../providers/database_providers.dart';

class CreateTravelScreen extends ConsumerStatefulWidget {
  const CreateTravelScreen({super.key});

  @override
  ConsumerState<CreateTravelScreen> createState() => _CreateTravelScreenState();
}

class _CreateTravelScreenState extends ConsumerState<CreateTravelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _activateNow = true;

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _saveTravel() async {
    if (_formKey.currentState!.validate() && _startDate != null && _endDate != null) {
      final travelId = const Uuid().v4();
      final travel = TravelsCompanion.insert(
        id: travelId,
        name: _nameController.text.trim(),
        budget: drift.Value(double.tryParse(_budgetController.text) ?? 0.0),
        startDate: _startDate!,
        endDate: _endDate!,
        isActive: const drift.Value(false), // Lo manejamos después si _activateNow es true
      );

      final dao = ref.read(travelsDaoProvider);
      await dao.insertTravel(travel);

      if (_activateNow) {
        await dao.setActiveTravel(travelId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Viaje creado y activado exitosamente.')),
          );
        }
      }

      if (mounted) {
        context.pop();
      }
    } else if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona las fechas del viaje.')),
      );
    }
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Viaje'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Viaje',
                  hintText: 'Ej. Viaje a Colombia',
                  prefixIcon: Icon(Icons.flight),
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Ingresa un nombre' : null,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(_startDate != null && _endDate != null
                    ? '${dateFormat.format(_startDate!)} - ${dateFormat.format(_endDate!)}'
                    : 'Seleccionar Fechas'),
                onPressed: _pickDateRange,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _budgetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Presupuesto Inicial (Opcional)',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Activar ahora'),
                subtitle: const Text('Los gastos futuros se asignarán a este viaje'),
                value: _activateNow,
                onChanged: (val) => setState(() => _activateNow = val),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saveTravel,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Guardar Viaje', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
