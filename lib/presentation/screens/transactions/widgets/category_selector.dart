import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/database_providers.dart';

class CategorySelector extends ConsumerWidget {
  final String? selectedCategoryId;
  final String transactionType; // expense, income
  final Function(String) onCategorySelected;

  const CategorySelector({
    super.key,
    required this.selectedCategoryId,
    required this.transactionType,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Si es transferencia, no mostramos selector de categoría
    if (transactionType == 'transfer') return const SizedBox.shrink();

    final categoriesAsync = transactionType == 'expense'
        ? ref.watch(expenseCategoriesStreamProvider)
        : ref.watch(incomeCategoriesStreamProvider);

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.warning, color: Colors.orange),
              title: const Text('No hay categorías'),
              subtitle: Text(
                  'Crea una categoría de ${transactionType == 'expense' ? 'gastos' : 'ingresos'}'),
            ),
          );
        }

        return DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: 'Categoría',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            prefixIcon: const Icon(Icons.category),
          ),
          initialValue: selectedCategoryId,
          items: categories.map<DropdownMenuItem<String>>((category) {
            return DropdownMenuItem(
              value: category.id,
              child: Row(
                children: [
                  if (category.icon != null)
                    Text(category.icon!, style: const TextStyle(fontSize: 20)),
                  if (category.icon != null) const SizedBox(width: 8),
                  Text(category.name),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onCategorySelected(value);
            }
          },
          validator: (value) {
            if (value == null) {
              return 'Selecciona una categoría';
            }
            return null;
          },
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
