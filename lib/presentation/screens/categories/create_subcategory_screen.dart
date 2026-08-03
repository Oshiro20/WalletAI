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
  ConsumerState<CreateSubcategoryScreen> createState() =>
      _CreateSubcategoryScreenState();
}

class _CreateSubcategoryScreenState
    extends ConsumerState<CreateSubcategoryScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  late TabController _iconTabController;

  String _selectedIcon = 'label_outline';
  bool _isSaving = false;
  bool _userManuallySelectedIcon = false;

  bool get _isEditing => widget.existingSubcategory != null;

  final List<String> _materialIcons = AppIcons.materialIcons.keys.toList();
  final List<String> _emojis = [
    '🏷️', '🏠', '🍔', '🚗', '💊', '🎬', '✈️', '🛒', '🐾', '📚',
    '🎓', '💼', '💡', '🔧', '🎁', '🎉', '🏋️', '🧘', '💸', '💰',
    '💳', '🏦', '📈', '📉', '🔒', '🔑', '📱', '💻', '📷', '🎵',
    '🎨', '🖌️', '👶', '🧸', '🍺', '🍷', '🍕', '🌮', '🍦', '🍩',
  ];

  @override
  void initState() {
    super.initState();
    _iconTabController = TabController(length: 2, vsync: this);

    // Pre-llenar campos si estamos en modo edición
    if (_isEditing) {
      _nameController.text = widget.existingSubcategory!.name;
      _descriptionController.text = widget.existingSubcategory!.description ?? '';
      _selectedIcon = widget.existingSubcategory!.icon ?? 'label_outline';
      _userManuallySelectedIcon = true;
    }

    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    if (_userManuallySelectedIcon || _isEditing) return;
    final text = _nameController.text.toLowerCase().trim();
    if (text.isEmpty) return;

    final inferred = _inferEmoji(text);
    if (inferred != null && inferred != _selectedIcon) {
      setState(() {
        _selectedIcon = inferred;
      });
    }
  }

  String? _inferEmoji(String query) {
    if (RegExp(r'\b(cine|pelicula|película|salida|teatro)\b').hasMatch(query)) return '🍿';
    if (RegExp(r'\b(netflix|spotify|youtube|disney|streaming|hbo)\b').hasMatch(query)) return '🎬';
    if (RegExp(r'\b(taxi|uber|cabify|indrive|yango)\b').hasMatch(query)) return '🚕';
    if (RegExp(r'\b(bus|combi|metro|tren|transporte|publico|público)\b').hasMatch(query)) return '🚌';
    if (RegExp(r'\b(gasolina|grifo|combustible|diesel|diésel|gnv|glp)\b').hasMatch(query)) return '⛽';
    if (RegExp(r'\b(estacionamiento|cochera|parqueo|peaje)\b').hasMatch(query)) return '🅿️';
    if (RegExp(r'\b(mercado|super|supermercado|viveres|víveres|abarrotes)\b').hasMatch(query)) return '🛒';
    if (RegExp(r'\b(restaurante|chifa|polleria|pollería|comida|almuerzo|cena)\b').hasMatch(query)) return '🍽️';
    if (RegExp(r'\b(delivery|rappi|pedidosya|reparto)\b').hasMatch(query)) return '🛵';
    if (RegExp(r'\b(snack|golosina|dulce|helado|antojo|postre)\b').hasMatch(query)) return '🍭';
    if (RegExp(r'\b(farmacia|botica|medicina|remedio|pastilla)\b').hasMatch(query)) return '💊';
    if (RegExp(r'\b(medico|médico|doctor|dentista|cita|clinica|clínica)\b').hasMatch(query)) return '🩺';
    if (RegExp(r'\b(gym|gimnasio|fitness|pesas|ejercicio)\b').hasMatch(query)) return '🏋️';
    if (RegExp(r'\b(peluqueria|peluquería|barberia|barbería|corte)\b').hasMatch(query)) return '✂️';
    if (RegExp(r'\b(higiene|jabon|jabón|champu|champú|crema|cosmetico|cosmético)\b').hasMatch(query)) return '🧴';
    if (RegExp(r'\b(spa|uña|uñas|estetica|estética|manicure)\b').hasMatch(query)) return '💅';
    if (RegExp(r'\b(ropa|camisa|polo|pantalon|pantalón|casaca)\b').hasMatch(query)) return '👕';
    if (RegExp(r'\b(zapatilla|zapato|bota|calzado)\b').hasMatch(query)) return '👟';
    if (RegExp(r'\b(joya|reloj|lentes|correa|cartera|bolso|accesorio)\b').hasMatch(query)) return '💍';
    if (RegExp(r'\b(luz|agua|internet|telefono|teléfono|cable|gas|servicio)\b').hasMatch(query)) return '💡';
    if (RegExp(r'\b(escoba|limpieza|detergente|lejia|lejía)\b').hasMatch(query)) return '🧹';
    if (RegExp(r'\b(herramientas|reparacion|reparación|mantenimiento|gasfiteria|gasfitería)\b').hasMatch(query)) return '🔧';
    if (RegExp(r'\b(electrodomestico|electrodoméstico|lavadora|cocina|refrigeradora)\b').hasMatch(query)) return '🔌';
    if (RegExp(r'\b(mueble|sofa|sofá|cama|decoracion|decoración)\b').hasMatch(query)) return '🛋️';
    if (RegExp(r'\b(pelota|futbol|fútbol|basquet|básquet|padel|pádel|deporte)\b').hasMatch(query)) return '⚽';
    if (RegExp(r'\b(yoga|pilates|baile|danza|natacion|natación|clase)\b').hasMatch(query)) return '🧘';
    if (RegExp(r'\b(suplemento|proteina|proteína|creatina|vitamina|nutricion|nutrición)\b').hasMatch(query)) return '🥗';
    if (RegExp(r'\b(carwash|car wash|auto|carro|coche|vehiculo|vehículo)\b').hasMatch(query)) return '🚗';
    if (RegExp(r'\b(vuelo|pasaje|avion|avión|pasajes)\b').hasMatch(query)) return '🛫';
    if (RegExp(r'\b(hotel|hostal|airbnb|hospedaje)\b').hasMatch(query)) return '🏨';
    if (RegExp(r'\b(tour|excursion|excursión|viaje)\b').hasMatch(query)) return '🗺️';
    if (RegExp(r'\b(regalo|obsequio|cumple|cumpleaños|detalle)\b').hasMatch(query)) return '🎁';
    if (RegExp(r'\b(donacion|donación|propina)\b').hasMatch(query)) return '💝';
    if (RegExp(r'\b(perro|gato|mascota|pet|veterinario)\b').hasMatch(query)) return '🐾';
    if (RegExp(r'\b(cita|romantica|romántica|pareja)\b').hasMatch(query)) return '🥂';
    if (RegExp(r'\b(banco|fondo|ahorro|deposito|depósito)\b').hasMatch(query)) return '🏦';
    if (RegExp(r'\b(acciones|bolsa|etf|inversion|inversión)\b').hasMatch(query)) return '📈';
    if (RegExp(r'\b(cripto|bitcoin|ethereum|btc|eth)\b').hasMatch(query)) return '₿';
    return null;
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    _iconTabController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final dao = ref.read(subcategoriesDaoProvider);
      final descText = _descriptionController.text.trim();

      if (_isEditing) {
        // ─── Modo edición ────────────────────────────────────────────
        final updated = widget.existingSubcategory!.copyWith(
          name: _nameController.text.trim(),
          description: drift.Value(descText.isEmpty ? null : descText),
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
          description: drift.Value(descText.isEmpty ? null : descText),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
            const SizedBox(height: 16),

            // Descripción
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción explicativa (opcional)',
                hintText: 'Ej. Compras de abarrotes, verduras y comida del mes',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description_outlined),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            // Icon Picker
            Text('Icono / Emoji', style: Theme.of(context).textTheme.titleMedium),
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
          onTap: () {
            setState(() {
              _selectedIcon = iconName;
              _userManuallySelectedIcon = true;
            });
          },
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
