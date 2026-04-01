import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/database_providers.dart';
import '../../../data/database/drift_database.dart';
import '../../../core/utils/app_icons.dart';
import 'create_subcategory_screen.dart';

final categorySearchProvider = StateProvider<String>((ref) => '');

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _isSearching 
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                 setState(() {
                   _isSearching = false;
                   _searchController.clear();
                   ref.read(categorySearchProvider.notifier).state = '';
                 });
              },
            )
          : null,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Buscar categoría...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  ref.read(categorySearchProvider.notifier).state = value;
                },
              )
            : const Text('Categorías'),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() => _isSearching = true);
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Gastos'),
            Tab(text: 'Ingresos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CategoryList(type: 'expense'),
          _CategoryList(type: 'income'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Pass type to create screen
          final type = _tabController.index == 0 ? 'expense' : 'income';
          context.push('/categories/create?type=$type');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  final String type;

  const _CategoryList({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = type == 'expense' 
        ? ref.watch(expenseCategoriesStreamProvider) 
        : ref.watch(incomeCategoriesStreamProvider);
    
    final searchQuery = ref.watch(categorySearchProvider).toLowerCase();

    return categoriesAsync.when(
      data: (categories) {
        // Filter by search query
        final filteredCategories = categories.where((c) {
          return c.name.toLowerCase().contains(searchQuery);
        }).toList();

        if (filteredCategories.isEmpty) {
          if (searchQuery.isNotEmpty) {
             return Center(child: Text('No se encontraron resultados para "$searchQuery"'));
          }
          return Center(
            child: Text('No hay categorías de ${type == 'expense' ? 'gastos' : 'ingresos'}'),
          );
        }
        
        return ListView.builder(
          itemCount: filteredCategories.length,
          itemBuilder: (context, index) {
            final category = filteredCategories[index];
            return CategoryTile(category: category);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}

class CategoryTile extends ConsumerWidget {
  final Category category;

  const CategoryTile({super.key, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subcategoriesAsync = ref.watch(subcategoriesStreamProvider(category.id));

    return subcategoriesAsync.when(
      data: (subcategories) {
        return ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (category.color != null 
                  ? Color(int.tryParse(category.color!.replaceFirst('#', '0xff')) ?? 0xFFEEEEEE)
                  : Colors.grey).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: AppIcons.getIcon(category.icon ?? '?', size: 24, color: Theme.of(context).primaryColor),
          ),
          title: Text(category.name),
          subtitle: Text('${subcategories.length} ${subcategories.length == 1 ? "subcategoría" : "subcategorías"}'),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
               if (value == 'edit') {
                 context.push('/categories/edit/${category.id}');
               } else if (value == 'delete') {
                 _confirmDeleteCategory(context, ref, category);
               } else if (value == 'add_sub') {
                 showModalBottomSheet(
                   context: context,
                   isScrollControlled: true,
                   builder: (_) => CreateSubcategoryScreen(categoryId: category.id),
                 );
               }
            },
            itemBuilder: (context) {
              final textColor = Theme.of(context).colorScheme.onSurface;
              return [
                PopupMenuItem(
                  value: 'add_sub',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 18, color: textColor),
                      const SizedBox(width: 8),
                      Text('Agregar Subcategoría', style: TextStyle(color: textColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: textColor),
                      const SizedBox(width: 8),
                      Text('Editar Categoría', style: TextStyle(color: textColor)),
                    ],
                  ),
                ),
                if (!category.isSystem)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text('Eliminar Categoría', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ];
            },
          ),
          children: [
            ...subcategories.map((sub) => ListTile(
              leading: const SizedBox(width: 24), // Indent
              title: Row(
                children: [
                   AppIcons.getIcon(sub.icon ?? 'label_outline', size: 20,
                       color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(sub.name),
                ],
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                 if (value == 'edit') {
                     Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateSubcategoryScreen(
                          categoryId: sub.categoryId,
                          existingSubcategory: sub,
                        ),
                      ),
                    );
                   } else if (value == 'delete') {
                     _confirmDeleteSubcategory(context, ref, sub);
                   }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                ],
              ),
            )),
            ListTile(
              leading: const SizedBox(width: 24),
              title: Text(
                'AÑADIR SUBCATEGORÍA',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              trailing: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
              onTap: () {
                context.push('/categories/${category.id}/subcategories/create');
              },
            ),
          ],
        );
      },
      loading: () => const ListTile(title: Text('Cargando...')),
      error: (e, s) => ListTile(title: Text('Error: $e')),
    );
  }

  void _confirmDeleteCategory(BuildContext context, WidgetRef ref, Category cat) {
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "${cat.name}" y todas sus subcategorías?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              ref.read(categoriesDaoProvider).deleteCategory(cat.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSubcategory(BuildContext context, WidgetRef ref, Subcategory sub) {
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar subcategoría'),
        content: Text('¿Eliminar "${sub.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              ref.read(subcategoriesDaoProvider).deleteSubcategory(sub.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
