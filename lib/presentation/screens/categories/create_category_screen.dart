import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../../../data/database/drift_database.dart';
import '../../providers/database_providers.dart'; // Ensure this is correct
import '../../../core/utils/app_icons.dart';

class CreateCategoryScreen extends ConsumerStatefulWidget {
  final String? initialType;
  final String? categoryId; // If provided, we are in Edit Mode

  const CreateCategoryScreen({super.key, this.initialType, this.categoryId});

  @override
  ConsumerState<CreateCategoryScreen> createState() =>
      _CreateCategoryScreenState();
}

class _CreateCategoryScreenState extends ConsumerState<CreateCategoryScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _aliasesController = TextEditingController();
  late TabController _iconTabController;

  String _selectedType = 'expense';
  String _selectedIcon = 'label_outline'; // Default Material Icon
  Color _selectedColor = Colors.blue;
  bool _isSaving = false;
  bool _isEditing = false;
  bool _showAliases = false;
  Category? _existingCategory;

  // 1. Material Icons List (Keys from AppIcons)
  final List<String> _materialIcons = AppIcons.materialIcons.keys.toList();

  // 2. Emojis List
  final List<String> _emojis = [
    '🏷️',
    '🏠',
    '🍔',
    '🚗',
    '💊',
    '🎬',
    '✈️',
    '🛒',
    '🐾',
    '📚',
    '🎓',
    '💼',
    '💡',
    '🔧',
    '🎁',
    '🎉',
    '🏋️',
    '🧘',
    '💸',
    '💰',
    '💳',
    '🏦',
    '📈',
    '📉',
    '🔒',
    '🔑',
    '📱',
    '💻',
    '📷',
    '🎵',
    '🎨',
    '🖌️',
    '👶',
    '🧸',
    '🍺',
    '🍷',
    '🍕',
    '🌮',
    '🍦',
    '🍩',
  ];

  final List<Color> _colors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();
    _iconTabController = TabController(length: 2, vsync: this);

    if (widget.initialType != null &&
        ['expense', 'income'].contains(widget.initialType)) {
      _selectedType = widget.initialType!;
    }

    if (widget.categoryId != null) {
      _isEditing = true;
      _loadExistingCategory();
    }
  }

  Future<void> _loadExistingCategory() async {
    final dao = ref.read(categoriesDaoProvider);
    final cat = await dao.getCategoryById(widget.categoryId!);
    if (cat != null) {
      setState(() {
        _existingCategory = cat;
        _nameController.text = cat.name;
        _selectedType = cat.type;
        _selectedIcon = cat.icon ?? 'label_outline';
        if (cat.color != null) {
          _selectedColor = Color(
            int.tryParse(cat.color!.replaceFirst('#', '0xff')) ?? 0xFF2196F3,
          );
        }
        if (cat.aliases != null && cat.aliases!.isNotEmpty) {
          _aliasesController.text = cat.aliases!;
          _showAliases = true;
        }

        // Determine initial tab based on icon type (Emoji vs Material)
        if (AppIcons.isMaterialIcon(_selectedIcon)) {
          _iconTabController.animateTo(0); // Material
        } else {
          _iconTabController.animateTo(1); // Emoji
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aliasesController.dispose();
    _iconTabController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final dao = ref.read(categoriesDaoProvider);

      final colorHex =
          '#${_selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

      if (_isEditing && _existingCategory != null) {
        // UPDATE
        final updatedCat = _existingCategory!.copyWith(
          name: _nameController.text,
          type: _selectedType,
          icon: drift.Value(_selectedIcon),
          color: drift.Value(colorHex),
          aliases: drift.Value(
            _aliasesController.text.trim().isEmpty
                ? null
                : _aliasesController.text.trim(),
          ),
        );
        await dao.updateCategory(updatedCat);
      } else {
        // CREATE
        final uuid = const Uuid().v4();
        final category = CategoriesCompanion.insert(
          id: uuid,
          name: _nameController.text,
          type: _selectedType,
          icon: drift.Value(_selectedIcon),
          color: drift.Value(colorHex),
          isSystem: const drift.Value(false),
          aliases: drift.Value(
            _aliasesController.text.trim().isEmpty
                ? null
                : _aliasesController.text.trim(),
          ),
          createdAt: DateTime.now(),
        );
        await dao.createCategory(category);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Categoría actualizada' : 'Categoría creada',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Categoría' : 'Nueva Categoría'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isSaving ? null : _saveCategory,
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
            const SizedBox(height: 16),

            // Tipo
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.swap_horiz),
              ),
              items: const [
                DropdownMenuItem(value: 'expense', child: Text('Gasto')),
                DropdownMenuItem(value: 'income', child: Text('Ingreso')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selectedType = value);
              },
            ),
            const SizedBox(height: 24),

            // Aliases para voz (opcional, colapsable)
            InkWell(
              onTap: () => setState(() => _showAliases = !_showAliases),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.mic,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Alias para reconocimiento de voz (opcional)',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _showAliases ? Icons.expand_less : Icons.expand_more,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (_showAliases) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _aliasesController,
                decoration: InputDecoration(
                  labelText: 'Alias (separados por coma)',
                  hintText: 'ej: angie, novia, pareja',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.mic_none),
                  helperText:
                      'Palabras clave para detectar esta categoría por voz',
                  helperMaxLines: 2,
                  suffixIcon: _aliasesController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              setState(() => _aliasesController.clear()),
                        )
                      : null,
                ),
                textCapitalization: TextCapitalization.none,
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 8),
            ],

            // Icon Picker Section
            Text('Icono', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            // Tabs for Material vs Emoji
            TabBar(
              controller: _iconTabController,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              tabs: const [
                Tab(text: 'Iconos'),
                Tab(text: 'Emojis'),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBarView(
                controller: _iconTabController,
                children: [
                  // Material Icons Grid
                  _buildIconGrid(_materialIcons, isMaterial: true),
                  // Emoji Grid
                  _buildIconGrid(_emojis, isMaterial: false),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Color Picker
            Text('Color', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colors.map((color) {
                final isSelected =
                    _selectedColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 2,
                            )
                          : null,
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.shadow.withValues(alpha: 0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
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
