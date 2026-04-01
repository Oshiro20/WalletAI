import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../../../data/database/drift_database.dart';
import '../../providers/database_providers.dart';
import '../../../core/utils/app_icons.dart';

class CreateSubcategoryScreen extends ConsumerStatefulWidget {
  final String categoryId;
  /// Si no es null, estamos en modo edición
  final Subcategory? existingSubcategory;

  const CreateSubcategoryScreen({
    super.key,
    required this.categoryId,
    this.existingSubcategory,
  });

  @override
  ConsumerState<CreateSubcategoryScreen> createState() => _CreateSubcategoryScreenState();
}

class _CreateSubcategoryScreenState extends ConsumerState<CreateSubcategoryScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late TabController _iconTabController;

  String _selectedIcon = 'label_outline';
  bool _isSaving = false;

  bool get _isEditing => widget.existingSubcategory != null;

  final List<String> _materialIcons = AppIcons.materialIcons.keys.toList();
  final List<String> _emojis = [
    '🏷️', '🏠', '🍔', '🚗', '💊', '🎬', '✈️', '🛒', '🐾', '📚',
    '🎓', '💼', '💡', '🔧', '🎁', '🎉', '🏋️', '🧘', '💸', '💰',
    '💳', '🏦', '📈', '📉', '🔒', '🔑', '📱', '💻', '📷', '🎵',
    '🎨', '🖌️', '👶', '🧸', '🍺', '🍷', '🍕', '🌮', '🍦', '🍩'
  ];

  @override
  void initState() {
    super.initState();
    _iconTabController = TabController(length: 2, vsync: this);

    // Pre-llenar campos si estamos en modo edición
    if (_isEditing) {
      _nameController.text = widget.existingSubcategory!.name;
      _selectedIcon = widget.existingSubcategory!.icon ?? 'label_outline';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _iconTabController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final dao = ref.read(subcategoriesDaoProvider);

      if (_isEditing) {
        // ─── Modo edición ────────────────────────────────────────────
        final updated = widget.existingSubcategory!.copyWith(
          name: _nameController.text.trim(),
          icon: drift.Value(_selectedIcon),
        );
        await dao.updateSubcategory(updated);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subcategoría actualizada')),
          );
        }
      } else {
        // ─── Modo creación ───────────────────────────────────────────
        final subcategory = SubcategoriesCompanion.insert(
          id: const Uuid().v4(),
          categoryId: widget.categoryId,
          name: _nameController.text.trim(),
          icon: drift.Value<String?>(_selectedIcon),
          sortOrder: const drift.Value(0),
          createdAt: DateTime.now(),
        );
        await dao.createSubcategory(subcategory);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subcategoría creada exitosamente')),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Subcategoría' : 'Nueva Subcategoría'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Nombre
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) =>
                  value == null || value.isEmpty ? 'Ingresa un nombre' : null,
            ),
            const SizedBox(height: 24),

            // Icon Picker
            Text('Icono', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            TabBar(
              controller: _iconTabController,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Iconos'),
                Tab(text: 'Emojis'),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBarView(
                controller: _iconTabController,
                children: [
                  _buildIconGrid(_materialIcons, isMaterial: true),
                  _buildIconGrid(_emojis, isMaterial: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconGrid(List<String> icons, {required bool isMaterial}) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: icons.length,
      itemBuilder: (context, index) {
        final iconName = icons[index];
        final isSelected = _selectedIcon == iconName;
        return InkWell(
          onTap: () => setState(() => _selectedIcon = iconName),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                  : null,
              border: isSelected
                  ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: AppIcons.getIcon(
                iconName,
                size: 24,
                color: isMaterial ? Theme.of(context).primaryColor : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
