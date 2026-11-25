import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../data/database/drift_database.dart';
import '../../providers/database_providers.dart';
import '../../providers/transaction_repository_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../core/utils/amount_input_helper.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/service_providers.dart';
import 'widgets/account_selector.dart';
import 'widgets/category_selector.dart';
import '../../../data/datasources/notification_service.dart';
import '../../../data/datasources/location_service.dart';
import '../../widgets/common/voice_input_button.dart';
import 'widgets/add_receipt_items_screen.dart';
import 'widgets/credit_card_installment_selector.dart';
import '../../../core/utils/credit_card_calculator.dart';
import '../../../core/services/ecosystem_sync_service.dart';
import '../../../core/services/financial_planning_service.dart';
import '../../../core/services/subcategory_learning_service.dart';
import '../../../data/datasources/groq_service.dart';
import 'package:go_router/go_router.dart';

class CreateTransactionScreen extends ConsumerStatefulWidget {
  final String? initialType;
  final double? initialAmount;
  final String? initialDescription;
  final String? initialProductName;
  final String? initialCategoryId;
  final String? initialSubcategoryId;
  final String? initialAccountId;
  final String? initialDestinationAccountId;
  final String? initialCurrency;
  final DateTime? initialDate;
  final double? initialQuantity;
  final String? initialUnit;
  final int? initialInstallments;
  final AiCategoryPrediction? initialAiSuggestion;

  const CreateTransactionScreen({
    super.key,
    this.initialType,
    this.initialAmount,
    this.initialDescription,
    this.initialProductName,
    this.initialCategoryId,
    this.initialSubcategoryId,
    this.initialAccountId,
    this.initialDestinationAccountId,
    this.initialCurrency,
    this.initialDate,
    this.initialQuantity,
    this.initialUnit,
    this.initialInstallments,
    this.initialAiSuggestion,
  });

  @override
  ConsumerState<CreateTransactionScreen> createState() =>
      _CreateTransactionScreenState();
}

class _CreateTransactionScreenState
    extends ConsumerState<CreateTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _productNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _productNameFocusNode = FocusNode();

  DateTime _selectedDate = DateTime.now();
  String _transactionType = 'expense'; // expense, income, transfer
  String _currency = 'PEN';
  String? _selectedAccountId;
  String? _destinationAccountId; // Para transferencias
  String? _selectedCategoryId;
  String? _selectedSubcategoryId;
  bool _isLoading = false;

  // Variables para prediccion de IA (categoría + subcategoría + sugerencias nuevas)
  Timer? _predictionTimer;
  bool _isPredictingCategory = false;
  AiCategoryPrediction? _pendingAiSuggestion;
  bool _isCreatingSuggestedCat = false;
  bool _isParsingClipboard = false;

  // Variables para GPS
  double? _latitude;
  double? _longitude;
  String? _locationName;
  bool _isCapturingLocation = false;

  // Variables para pagos recurrentes
  bool _isRecurring = false;
  String _frequency = 'monthly'; // monthly, weekly, yearly

  // Asignar ingreso de fin de mes (ej. sueldo día 28-31) al mes siguiente
  bool _assignIncomeToNextMonth = false;

  // Variables para compras con Tarjeta de Crédito (cuotas / financiamiento)
  bool _isInstallment = false;
  int _installmentsCount = 3;
  bool _hasInterest = false;
  final _installmentTeaController = TextEditingController();
  bool _useManualMonthlyPayment = false;
  final _manualMonthlyPaymentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
    if (widget.initialType != null &&
        ['expense', 'income', 'transfer'].contains(widget.initialType)) {
      _transactionType = widget.initialType!;
    }
    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount!.toStringAsFixed(2);
    }
    if (widget.initialDescription != null) {
      _descriptionController.text = widget.initialDescription!;
    }
    if (widget.initialProductName != null) {
      _productNameController.text = widget.initialProductName!;
    }
    if (widget.initialCategoryId != null) {
      _selectedCategoryId = widget.initialCategoryId;
    }
    if (widget.initialSubcategoryId != null) {
      _selectedSubcategoryId = widget.initialSubcategoryId;
    }
    if (widget.initialAccountId != null) {
      _selectedAccountId = widget.initialAccountId;
    }
    if (widget.initialDestinationAccountId != null) {
      _destinationAccountId = widget.initialDestinationAccountId;
    }
    if (widget.initialCurrency != null &&
        ['PEN', 'USD', 'EUR'].contains(widget.initialCurrency)) {
      _currency = widget.initialCurrency!;
    }
    if (widget.initialInstallments != null && widget.initialInstallments! > 1) {
      _isInstallment = true;
      _installmentsCount = widget.initialInstallments!;
    }
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }
    if (widget.initialQuantity != null) {
      _quantityController.text = widget.initialQuantity!.toStringAsFixed(2);
    } else {
      _quantityController.text = '1';
    }
    if (widget.initialUnit != null) {
      _unitController.text = widget.initialUnit!;
    } else {
      _unitController.text = 'UND';
    }
    if (widget.initialAiSuggestion != null &&
        widget.initialAiSuggestion!.hasNewSuggestion) {
      _pendingAiSuggestion = widget.initialAiSuggestion;
    }

    _productNameFocusNode.addListener(_onProductNameFocusChanged);
  }

  void _onProductNameFocusChanged() async {
    // Solo auto-categorizar si la transacción es un Gasto
    if (_transactionType != 'expense') return;

    // Cuando el usuario termina de escribir el producto y sale del campo
    if (!_productNameFocusNode.hasFocus) {
      final name = _productNameController.text.trim();
      if (name.isNotEmpty) {
        final db = ref.read(databaseProvider);
        final rule = await db.learningRulesDao.getRuleForProduct(name);
        final subRule = await SubcategoryLearningService.getRule(name);

        if (rule != null && mounted) {
          setState(() {
            _selectedCategoryId = rule.categoryId;
            if (subRule.subcategoryId != null) {
              _selectedSubcategoryId = subRule.subcategoryId;
            }
            if (_selectedAccountId == null && subRule.accountId != null) {
              _selectedAccountId = subRule.accountId;
            }
            _pendingAiSuggestion = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Categoría auto-asignada por aprendizaje: $name'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Subcategory? _findSubcategoryByName(
    String? suggested,
    String categoryId,
    List<Subcategory> allSubcats,
  ) {
    if (suggested == null || suggested.trim().isEmpty) return null;
    final lower = suggested.trim().toLowerCase();
    final scoped =
        allSubcats.where((s) => s.categoryId == categoryId).toList();
    for (final s in scoped) {
      if (s.name.trim().toLowerCase() == lower) return s;
    }
    for (final s in scoped) {
      final n = s.name.trim().toLowerCase();
      if (n.contains(lower) || lower.contains(n)) return s;
    }
    return null;
  }

  void _onProductNameChanged(String value) {
    // Solo auto-categorizar por IA / aprendizaje si es un Gasto
    if (_transactionType != 'expense') return;

    if (value.trim().isEmpty) {
      _predictionTimer?.cancel();
      if (_isPredictingCategory || _pendingAiSuggestion != null) {
        setState(() {
          _isPredictingCategory = false;
          _pendingAiSuggestion = null;
        });
      }
      return;
    }

    _predictionTimer?.cancel();

    _predictionTimer = Timer(const Duration(milliseconds: 800), () async {
      final name = value.trim();

      // 1. Primero intentar autocompletar con reglas locales + historial real (categoría + subcategoría)
      final db = ref.read(databaseProvider);
      final rule = await db.learningRulesDao.getRuleForProduct(name);
      final subRule = await SubcategoryLearningService.getRule(name);
      final categoriesList = await db.categoriesDao.getCategoriesByType(
        'expense',
      );
      final subcatsList = await db.subcategoriesDao.getAllSubcategories();

      String? lockedCategoryName;
      if (rule != null && mounted) {
        String? resolvedSubId = subRule.subcategoryId;
        String? resolvedAccId = subRule.accountId;

        // Verificar que la subcategoría recordada siga existiendo y pertenezca a la categoría
        if (resolvedSubId != null) {
          final validSub = subcatsList.any(
            (s) => s.id == resolvedSubId && s.categoryId == rule.categoryId,
          );
          if (!validSub) resolvedSubId = null;
        }

        // Si la regla vieja solo tenía categoría, buscar la subcategoría más reciente en tu historial
        if (resolvedSubId == null) {
          final historical = await db.transactionsDao
              .getLatestClassificationForProduct(name);
          if (historical?.subcategoryId != null) {
            final belongs = subcatsList.any(
              (s) =>
                  s.id == historical!.subcategoryId &&
                  s.categoryId == rule.categoryId,
            );
            if (belongs) {
              resolvedSubId = historical!.subcategoryId;
              resolvedAccId ??= historical.accountId;
              // Persistir en caché de subcategorías para próximas veces
              unawaited(
                SubcategoryLearningService.saveRule(
                  productName: name,
                  subcategoryId: resolvedSubId,
                  accountId: resolvedAccId,
                ),
              );
            }
          }
        }

        final categoryHasSubs = subcatsList.any(
          (s) => s.categoryId == rule.categoryId,
        );

        setState(() {
          _selectedCategoryId = rule.categoryId;
          _selectedSubcategoryId = resolvedSubId;
          if (_selectedAccountId == null && resolvedAccId != null) {
            _selectedAccountId = resolvedAccId;
          }
          _pendingAiSuggestion = null;
        });

        // Si ya tenemos categoría + subcategoría (o esa categoría no usa subcategorías), terminamos al instante
        if (resolvedSubId != null || !categoryHasSubs) {
          return;
        }

        // Si falta subcategoría, pedir a la IA solo la subcategoría dentro de la categoría memorizada
        lockedCategoryName = categoriesList
            .where((c) => c.id == rule.categoryId)
            .firstOrNull
            ?.name;
      }

      // 2. Si no hay regla completa, usar IA Predictiva con árbol de categorías + subcategorías
      if (mounted) {
        setState(() {
          _isPredictingCategory = true;
          _pendingAiSuggestion = null;
        });
      }

      try {
        final aiService = ref.read(groqServiceProvider);
        final prediction = await aiService.predictCategoryAndSubcategory(
          name,
          categoriesList,
          subcatsList,
          description: _descriptionController.text,
          amount: double.tryParse(_amountController.text.replaceAll(',', '.')),
          quantity: double.tryParse(
            _quantityController.text.replaceAll(',', '.'),
          ),
          unit: _unitController.text.trim().isNotEmpty
              ? _unitController.text.trim()
              : null,
          lockedCategoryName: lockedCategoryName,
        );

        if (prediction != null && mounted) {
          Category? matchedCat;
          if (prediction.categoryName != null &&
              prediction.categoryName!.isNotEmpty) {
            matchedCat = await db.categoriesDao.findCategoryByName(
              prediction.categoryName!,
            );
          }

          Subcategory? matchedSub;
          if (matchedCat != null &&
              prediction.subcategoryName != null &&
              prediction.subcategoryName!.isNotEmpty) {
            matchedSub = _findSubcategoryByName(
              prediction.subcategoryName,
              matchedCat.id,
              subcatsList,
            );
          }

          final needsNewCat =
              matchedCat == null &&
              prediction.categoryName != null &&
              prediction.categoryName!.trim().isNotEmpty &&
              prediction.categoryName!.trim().toUpperCase() != 'OTRO';
          final needsNewSub =
              matchedSub == null &&
              prediction.subcategoryName != null &&
              prediction.subcategoryName!.trim().isNotEmpty &&
              prediction.subcategoryName!.trim().toUpperCase() != 'OTRO';

          if (mounted) {
            setState(() {
              if (matchedCat != null) {
                _selectedCategoryId = matchedCat.id;
                _selectedSubcategoryId = matchedSub?.id;
              }
              if (needsNewCat || needsNewSub) {
                _pendingAiSuggestion = AiCategoryPrediction(
                  categoryName: matchedCat?.name ?? prediction.categoryName,
                  subcategoryName: prediction.subcategoryName,
                  isNewCategory: needsNewCat,
                  isNewSubcategory: needsNewSub,
                  iconEmoji: prediction.iconEmoji,
                  reason: prediction.reason,
                );
              }
            });

            if (matchedCat != null && !needsNewSub) {
              final label = matchedSub != null
                  ? '${matchedCat.name} › ${matchedSub.name}'
                  : matchedCat.name;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('IA clasificó en: $label')),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
          }
        }
      } catch (_) {
        // Non-blocking
      } finally {
        if (mounted) {
          setState(() {
            _isPredictingCategory = false;
          });
        }
      }
    });
  }

  Future<void> _acceptAiCategorySuggestion() async {
    final sug = _pendingAiSuggestion;
    if (sug == null || _isCreatingSuggestedCat) return;
    setState(() => _isCreatingSuggestedCat = true);

    try {
      final db = ref.read(databaseProvider);
      final uuid = const Uuid();
      String? catId = _selectedCategoryId;

      if (sug.categoryName != null && sug.categoryName!.trim().isNotEmpty) {
        final existingCat = await db.categoriesDao.findCategoryByName(
          sug.categoryName!.trim(),
        );
        if (existingCat != null) {
          catId = existingCat.id;
        } else if (sug.isNewCategory) {
          catId = uuid.v4();
          await db.categoriesDao.createCategory(
            CategoriesCompanion.insert(
              id: catId,
              name: sug.categoryName!.trim(),
              type: _transactionType == 'income' ? 'income' : 'expense',
              icon: drift.Value(sug.iconEmoji ?? '🏷️'),
              color: const drift.Value('#6366F1'),
              createdAt: DateTime.now(),
            ),
          );
        }
      }

      String? subId = _selectedSubcategoryId;
      if (catId != null &&
          sug.isNewSubcategory &&
          sug.subcategoryName != null &&
          sug.subcategoryName!.trim().isNotEmpty) {
        final existingSubs = await db.subcategoriesDao
            .getSubcategoriesByCategoryId(catId);
        final match = _findSubcategoryByName(
          sug.subcategoryName,
          catId,
          existingSubs,
        );
        if (match != null) {
          subId = match.id;
        } else {
          subId = uuid.v4();
          await db.subcategoriesDao.createSubcategory(
            SubcategoriesCompanion.insert(
              id: subId,
              categoryId: catId,
              name: sug.subcategoryName!.trim(),
              icon: drift.Value(sug.iconEmoji ?? '✨'),
              createdAt: DateTime.now(),
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          if (catId != null) _selectedCategoryId = catId;
          if (subId != null) _selectedSubcategoryId = subId;
          _pendingAiSuggestion = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sug.isNewCategory
                  ? '✅ Categoría "${sug.categoryName}" creada y aplicada'
                  : '✅ Subcategoría "${sug.subcategoryName}" creada y aplicada',
            ),
            backgroundColor: const Color(0xFF00C896),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo crear la categoría/subcategoría: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingSuggestedCat = false);
    }
  }

  Future<void> _pasteBankOrWalletText() async {
    if (_isParsingClipboard) return;
    final clipData = await Clipboard.getData(Clipboard.kTextPlain);
    String? rawText = clipData?.text?.trim();

    if (!mounted) return;
    final controller = TextEditingController(text: rawText ?? '');
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.content_paste_go_rounded, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text('Pegar Yape / Plin / SMS')),
          ],
        ),
        content: TextField(
          controller: controller,
          maxLines: 5,
          minLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText:
                'Pega aquí tu notificación de Yape, Plin, BCP, Interbank o BBVA...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Extraer con IA'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (confirmed == null || confirmed.isEmpty || !mounted) return;
    setState(() => _isParsingClipboard = true);
    try {
      final db = ref.read(databaseProvider);
      final categories = await db.categoriesDao.getAllCategories();
      final subcats = await db.subcategoriesDao.getAllSubcategories();
      final accounts = await db.accountsDao.getAllAccounts();
      final parsed = await ref.read(groqServiceProvider).parseBankOrWalletText(
        confirmed,
        categories,
        subcats,
        accounts,
      );

      if (parsed == null || !mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo extraer datos del texto pegado.'),
            ),
          );
        }
        return;
      }

      final catName = parsed['categoria_sugerida']?.toString();
      final subName = parsed['subcategoria_sugerida']?.toString();
      final matchedCat = (catName != null && catName.isNotEmpty)
          ? await db.categoriesDao.findCategoryByName(catName)
          : null;
      final matchedSub = matchedCat != null
          ? _findSubcategoryByName(subName, matchedCat.id, subcats)
          : null;
      final accName = parsed['cuenta_sugerida']?.toString().toLowerCase();
      final matchedAcc = (accName != null && accName.isNotEmpty)
          ? accounts
                .where(
                  (a) =>
                      a.isActive &&
                      (a.name.toLowerCase().contains(accName) ||
                          accName.contains(a.name.toLowerCase())),
                )
                .firstOrNull
          : null;
      final parsedDate = parsed['fecha'] != null
          ? DateTime.tryParse(parsed['fecha'].toString())
          : null;

      final bool needsNewCat =
          parsed['es_nueva_categoria'] == true ||
          (matchedCat == null &&
              catName != null &&
              catName.trim().isNotEmpty &&
              catName.trim().toUpperCase() != 'OTRO');
      final bool needsNewSub =
          parsed['es_nueva_subcategoria'] == true ||
          (matchedSub == null &&
              subName != null &&
              subName.trim().isNotEmpty);

      _applyVoiceData({
        'type': parsed['tipo']?.toString() ?? 'expense',
        'amount': (parsed['monto'] as num?)?.toDouble(),
        'currency': parsed['moneda']?.toString() ?? 'PEN',
        'description': parsed['descripcion']?.toString(),
        'productName': parsed['producto']?.toString(),
        'categoryId': matchedCat?.id,
        'subcategoryId': matchedSub?.id,
        'accountId': matchedAcc?.id,
        if (parsedDate != null) 'date': parsedDate.millisecondsSinceEpoch,
        if (needsNewCat || needsNewSub)
          'aiSuggestion': AiCategoryPrediction(
            categoryName: matchedCat?.name ?? catName,
            subcategoryName: subName,
            isNewCategory: needsNewCat,
            isNewSubcategory: needsNewSub,
          ),
      });
    } finally {
      if (mounted) setState(() => _isParsingClipboard = false);
    }
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _predictionTimer?.cancel();
    _amountController.dispose();
    _descriptionController.dispose();
    _productNameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _productNameFocusNode.dispose();
    _installmentTeaController.dispose();
    _manualMonthlyPaymentController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showScanOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.document_scanner),
              title: const Text('Comprobante Único (1 producto)'),
              subtitle: const Text('Ideal para restaurantes o recibos simples'),
              onTap: () {
                Navigator.pop(ctx);
                _showCameraOrGallery(context, isMultiple: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Boleta Múltiple (Supermercado)'),
              subtitle: const Text(
                'Extrae todos los productos como transacciones separadas',
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showCameraOrGallery(context, isMultiple: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCameraOrGallery(BuildContext context, {required bool isMultiple}) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar Foto'),
              onTap: () {
                Navigator.pop(ctx);
                _scanReceipt(ImageSource.camera, isMultiple: isMultiple);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(ctx);
                _scanReceipt(ImageSource.gallery, isMultiple: isMultiple);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanReceipt(
    ImageSource source, {
    bool isMultiple = false,
  }) async {
    setState(() => _isLoading = true);
    try {
      final scanner = ref.read(receiptScannerServiceProvider);
      final receipt = source == ImageSource.camera
          ? await scanner.scanFromCamera(isMultiple: isMultiple)
          : await scanner.scanFromGallery(isMultiple: isMultiple);

      if (receipt != null) {
        if (mounted) {
          setState(() {
            if (receipt.amount != null) {
              _amountController.text = receipt.amount!.toStringAsFixed(2);
            }
            if (receipt.date != null) {
              _selectedDate = receipt.date!;
            }
            if (receipt.merchant != null) {
              _descriptionController.text = receipt.merchant!;
            }
            if (receipt.productName != null &&
                receipt.productName!.isNotEmpty) {
              _productNameController.text = receipt.productName!;
            }
          });

          if (receipt.category != null &&
              receipt.category!.isNotEmpty &&
              _transactionType == 'expense') {
            try {
              final categoriesDao = ref.read(categoriesDaoProvider);
              final categories = await categoriesDao.getAllCategories();

              Category? matchedCategory;
              for (final c in categories) {
                if (c.type == 'expense' &&
                    c.name.toLowerCase() == receipt.category!.toLowerCase()) {
                  matchedCategory = c;
                  break;
                }
              }

              if (matchedCategory != null) {
                final categoryId = matchedCategory.id;

                if (mounted) {
                  setState(() {
                    _selectedCategoryId = categoryId;
                    _selectedSubcategoryId = null; // reset subcategory first
                  });
                }

                if (receipt.subcategory != null &&
                    receipt.subcategory!.isNotEmpty) {
                  final subcategoriesDao = ref.read(subcategoriesDaoProvider);
                  final subcats = await subcategoriesDao
                      .getSubcategoriesByCategoryId(categoryId);
                  for (final sc in subcats) {
                    if (sc.name.toLowerCase() ==
                        receipt.subcategory!.toLowerCase()) {
                      if (mounted) {
                        setState(() {
                          _selectedSubcategoryId = sc.id;
                        });
                      }
                      break;
                    }
                  }
                }
              }
            } catch (_) {}
          }

          if (receipt.items != null && receipt.items!.isNotEmpty) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (ctx) => AddReceiptItemsScreen(receipt: receipt),
                ),
              );
            }
            return;
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Datos extraídos de la boleta ✅')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo leer la boleta')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al escanear: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _captureLocation() async {
    setState(() => _isCapturingLocation = true);
    try {
      final result = await locationServiceInstance.getCurrentLocation();
      if (result != null && mounted) {
        setState(() {
          _latitude = result.latitude;
          _longitude = result.longitude;
          _locationName = result.name;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📍 Ubicación capturada: ${result.name ?? "lat ${result.latitude.toStringAsFixed(4)}"}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo obtener la ubicación. Verifica los permisos.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturingLocation = false);
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una cuenta')),
      );
      return;
    }

    if (_selectedCategoryId == null && _transactionType != 'transfer') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una categoría')),
      );
      return;
    }

    // Validar transferencia
    if (_transactionType == 'transfer') {
      if (_destinationAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona cuenta destino')),
        );
        return;
      }
      if (_selectedAccountId == _destinationAccountId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Las cuentas deben ser diferentes')),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(transactionRepositoryProvider);
      final dao = ref.read(databaseProvider).learningRulesDao;
      final activeTravel = ref.read(activeTravelProvider).valueOrNull;

      final amount = double.parse(_amountController.text);
      const uuid = Uuid();
      final transactionId = uuid.v4();
      String? recurringId;
      drift.Insertable<RecurringPayment>? recurringPayment;

      // Si es recurrente, crear objeto RecurringPaymentsCompanion
      if (_isRecurring && _transactionType != 'transfer') {
        recurringId = uuid.v4();

        // Calcular próxima fecha (la actual cuenta como la primera)
        DateTime nextDate = _selectedDate;
        if (_frequency == 'weekly') {
          nextDate = nextDate.add(const Duration(days: 7));
        } else if (_frequency == 'monthly') {
          nextDate = DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
        } else if (_frequency == 'yearly') {
          nextDate = DateTime(nextDate.year + 1, nextDate.month, nextDate.day);
        }

        recurringPayment = RecurringPaymentsCompanion.insert(
          id: recurringId,
          name: _descriptionController.text.isNotEmpty
              ? _descriptionController.text
              : (_transactionType == 'expense'
                    ? 'Gasto recurrente'
                    : 'Ingreso recurrente'),
          amount: amount,
          accountId: _selectedAccountId!,
          categoryId: drift.Value(_selectedCategoryId),
          frequency: _frequency,
          nextDueDate: nextDate,
          isActive: const drift.Value(true),
          createdAt: DateTime.now(),
        );
      }

      // Si es compra en cuotas con tarjeta de crédito
      String? creditInstallmentId;
      InstallmentPlanCalculation? installmentPlan;
      CreditInstallmentsCompanion? creditInstallmentCompanion;

      if (_transactionType == 'expense' &&
          _selectedAccountId != null &&
          _isInstallment) {
        final accounts = ref.read(accountsStreamProvider).valueOrNull ?? [];
        final account = accounts
            .where((a) => a.id == _selectedAccountId)
            .firstOrNull;

        if (account != null && account.type == 'credit_card') {
          final tea =
              double.tryParse(
                _installmentTeaController.text.replaceAll(',', '.'),
              ) ??
              (account.tea ?? 54.9);
          final manualMonthly = _useManualMonthlyPayment
              ? double.tryParse(
                      _manualMonthlyPaymentController.text.replaceAll(',', '.'),
                    ) ??
                    0.0
              : 0.0;

          installmentPlan = _useManualMonthlyPayment && manualMonthly > 0
              ? CreditCardCalculator.calculateFromMonthlyPayment(
                  principal: amount,
                  installments: _installmentsCount,
                  monthlyPayment: manualMonthly,
                  purchaseDate: _selectedDate,
                  closingDay: account.closingDay,
                  paymentDueDay: account.paymentDueDay,
                )
              : CreditCardCalculator.calculatePlan(
                  principal: amount,
                  installments: _installmentsCount,
                  tea: tea,
                  hasInterest: _hasInterest,
                  purchaseDate: _selectedDate,
                  closingDay: account.closingDay,
                  paymentDueDay: account.paymentDueDay,
                );

          creditInstallmentId = uuid.v4();

          creditInstallmentCompanion = CreditInstallmentsCompanion.insert(
            id: creditInstallmentId,
            accountId: _selectedAccountId!,
            transactionId: drift.Value(transactionId),
            title: _productNameController.text.trim().isNotEmpty
                ? _productNameController.text.trim()
                : (_descriptionController.text.trim().isNotEmpty
                      ? _descriptionController.text.trim()
                      : 'Compra en cuotas'),
            totalAmount: amount,
            totalInstallments: _installmentsCount,
            paidInstallments: const drift.Value(0),
            monthlyPayment: installmentPlan.monthlyPayment,
            hasInterest: drift.Value(installmentPlan.hasInterest),
            tea: drift.Value(installmentPlan.tea),
            totalInterest: drift.Value(installmentPlan.totalInterest),
            purchaseDate: _selectedDate,
            firstDueDate: installmentPlan.firstDueDate,
            status: const drift.Value('active'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
      }

      // Crear objeto TransactionCompanion
      final transaction = TransactionsCompanion.insert(
        id: transactionId,
        type: _transactionType,
        contextId: drift.Value(activeTravel?.id),
        amount: amount,
        accountId: _selectedAccountId!,
        destinationAccountId: drift.Value(_destinationAccountId),
        categoryId: drift.Value(_selectedCategoryId),
        subcategoryId: drift.Value(_selectedSubcategoryId),
        productName: drift.Value(
          _productNameController.text.isEmpty
              ? null
              : _productNameController.text,
        ),
        quantity: drift.Value(double.tryParse(_quantityController.text) ?? 1.0),
        unit: drift.Value(
          _unitController.text.trim().isEmpty
              ? 'UND'
              : _unitController.text.trim().toUpperCase(),
        ),
        description: drift.Value(
          _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
        ),
        date: _selectedDate,
        isRecurring: drift.Value(_isRecurring),
        recurringPaymentId: drift.Value(recurringId),
        latitude: drift.Value(_latitude),
        longitude: drift.Value(_longitude),
        locationName: drift.Value(_locationName),
        currency: drift.Value(_currency),
        creditInstallmentId: drift.Value(creditInstallmentId),
        installmentNumber: drift.Value(creditInstallmentId != null ? 1 : null),
        totalInstallments: drift.Value(
          creditInstallmentId != null ? _installmentsCount : null,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Guardar usando el repositorio (maneja transacción y saldos internamente)
      await repository.addTransaction(
        transaction: transaction,
        accountId: _selectedAccountId!,
        amount: amount,
        type: _transactionType,
        destinationAccountId: _destinationAccountId,
        recurringPayment: recurringPayment,
        creditInstallment: creditInstallmentCompanion,
      );

      // Si es ingreso marcado para el presupuesto del próximo mes (ej. sueldo del 28-31)
      if (_transactionType == 'income' && _assignIncomeToNextMonth) {
        await ref
            .read(incomeMonthOverridesProvider.notifier)
            .assignToNextMonth(transactionId, _selectedDate);
      }

      // Calcular sugerencia de ahorro mensual si el usuario registró un ingreso relevante
      double suggestedMonthlyGoals = 0;
      if (_transactionType == 'income' && amount >= 200) {
        try {
          final activeGoals = await ref
              .read(savingsGoalsDaoProvider)
              .getActiveGoals();
          suggestedMonthlyGoals =
              FinancialPlanningService.totalSuggestedMonthlySavings(
                activeGoals,
              );
        } catch (_) {}
      }

      if (mounted) {
        String successMsg = 'Transacción guardada exitosamente';
        if (creditInstallmentId != null && installmentPlan != null) {
          final fee = installmentPlan.monthlyPayment.toStringAsFixed(2);
          successMsg =
              'Compra registrada en $_installmentsCount cuotas de $_currency $fee';
        } else if (_transactionType == 'income' && _assignIncomeToNextMonth) {
          final nextInfo = FinancialPlanningService.nextMonthOf(_selectedDate);
          successMsg =
              '💰 Ingreso guardado (contará en ${nextInfo.label})'
              '${suggestedMonthlyGoals > 0 ? ' · Metas sugieren separar S/ ${suggestedMonthlyGoals.toStringAsFixed(0)}/mes' : ''}';
        } else if (_transactionType == 'income' && suggestedMonthlyGoals > 0) {
          successMsg =
              '💰 Ingreso guardado · Tus metas sugieren separar S/ ${suggestedMonthlyGoals.toStringAsFixed(0)} este mes';
        } else if (_isRecurring) {
          successMsg = 'Transacción y suscripción guardadas';
        }

        final messenger = ScaffoldMessenger.of(context);
        final router = GoRouter.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(successMsg),
            action: (_transactionType == 'income' && suggestedMonthlyGoals > 0)
                ? SnackBarAction(
                    label: 'Ver Metas',
                    onPressed: () => router.push('/savings'),
                  )
                : null,
          ),
        );

        // Cerrar pantalla INMEDIATAMENTE — las verificaciones corren en background
        Navigator.of(context).pop();

        // 🧠 APRENDIZAJE PERSISTENTE + sincronización ecosistema — en background (unawaited)
        unawaited(
          EcosystemSyncService.publishSummary(ref.read(databaseProvider)),
        );
        if (_transactionType == 'expense') {
          unawaited(_checkBudgetAlerts());
          unawaited(_checkHighExpense(amount, _descriptionController.text));
          if (_productNameController.text.trim().isNotEmpty &&
              _selectedCategoryId != null) {
            unawaited(
              dao.saveRule(
                _productNameController.text.trim(),
                _selectedCategoryId!,
              ),
            );
            unawaited(
              SubcategoryLearningService.saveRule(
                productName: _productNameController.text.trim(),
                subcategoryId: _selectedSubcategoryId,
                accountId: _selectedAccountId,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Verifica presupuestos y dispara notificaciones si es necesario
  Future<void> _checkBudgetAlerts() async {
    try {
      final budgetsDao = ref.read(budgetsDaoProvider);
      final transactionsDao = ref.read(transactionsDaoProvider);
      final categoriesDao = ref.read(categoriesDaoProvider);

      final budgets = await budgetsDao.getActiveBudgets();
      if (budgets.isEmpty) return;

      final categories = await categoriesDao.getAllCategories();

      await NotificationService().checkBudgetAlerts(
        budgets: budgets,
        transactionsDao: transactionsDao,
        categories: categories,
      );
    } catch (_) {
      // Silencioso — no interrumpir el flujo del usuario
    }
  }

  /// Notifica si el gasto supera 3x el promedio diario del mes
  Future<void> _checkHighExpense(double amount, String description) async {
    try {
      final transactionsDao = ref.read(transactionsDaoProvider);
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final monthlyExpenses = await transactionsDao.getExpensesByCategory(
        startOfMonth,
        endOfMonth,
      );
      final totalMonthly = monthlyExpenses.values.fold(0.0, (a, b) => a + b);

      final daysElapsed = now.day.toDouble().clamp(1, 31);
      final dailyAverage = totalMonthly / daysElapsed;

      if (dailyAverage > 0 && amount > dailyAverage * 3) {
        await NotificationService().notifyHighExpense(
          description: description.isEmpty ? 'Sin descripción' : description,
          amount: amount,
          dailyAverage: dailyAverage,
        );
      }
    } catch (_) {
      // Silencioso
    }
  }

  void _applyVoiceData(Map<String, dynamic> data) {
    setState(() {
      final type = data['type']?.toString();
      if (type != null && ['expense', 'income', 'transfer'].contains(type)) {
        _transactionType = type;
      }
      final amount = (data['amount'] as num?)?.toDouble();
      if (amount != null && amount > 0) {
        _amountController.text = amount.toStringAsFixed(2);
      }
      final currency = data['currency']?.toString();
      if (currency != null && ['PEN', 'USD', 'EUR'].contains(currency)) {
        _currency = currency;
      }
      final description = data['description']?.toString();
      if (description != null && description.isNotEmpty) {
        _descriptionController.text = description;
      }
      final productName = data['productName']?.toString();
      if (productName != null && productName.isNotEmpty) {
        _productNameController.text = productName;
      }
      final quantity = (data['quantity'] as num?)?.toDouble();
      if (quantity != null && quantity > 0) {
        _quantityController.text = quantity.toStringAsFixed(2);
      }
      final unit = data['unit']?.toString();
      if (unit != null && unit.isNotEmpty) {
        _unitController.text = unit;
      }
      if (data['categoryId'] != null) {
        _selectedCategoryId = data['categoryId'].toString();
      }
      if (data['subcategoryId'] != null) {
        _selectedSubcategoryId = data['subcategoryId'].toString();
      }
      if (data['accountId'] != null) {
        _selectedAccountId = data['accountId'].toString();
      }
      if (data['destinationAccountId'] != null) {
        _destinationAccountId = data['destinationAccountId'].toString();
      }
      final dateMs = data['date'] as int?;
      if (dateMs != null) {
        _selectedDate = DateTime.fromMillisecondsSinceEpoch(dateMs);
      }
      final installments = (data['installments'] as num?)?.toInt();
      if (installments != null && installments > 1) {
        _isInstallment = true;
        _installmentsCount = installments;
      }
      final aiSug = data['aiSuggestion'];
      if (aiSug is AiCategoryPrediction && aiSug.hasNewSuggestion) {
        _pendingAiSuggestion = aiSug;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎙️ Datos completados desde tu audio'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = _transactionType == 'expense'
        ? ref.watch(expenseCategoriesStreamProvider)
        : ref.watch(incomeCategoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Transacción'),
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
          else ...[
            VoiceInputButton(onVoiceExtracted: _applyVoiceData),
            IconButton(
              icon: _isParsingClipboard
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.content_paste_go_rounded),
              tooltip: 'Pegar Yape / Plin / SMS',
              onPressed: _isParsingClipboard ? null : _pasteBankOrWalletText,
            ),
            IconButton(
              icon: const Icon(Icons.camera_alt),
              tooltip: 'Escanear Boleta',
              onPressed: () => _showScanOptions(context),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveTransaction,
          ),
        ],
      ),

      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Selector de tipo
            _buildTypeSelector(),

            const SizedBox(height: 24),

            // Campo de monto
            _buildAmountField(),

            const SizedBox(height: 16),

            // Selector de cuenta
            _buildAccountSelector(accountsAsync),

            // Selector interactivo de financiamiento/cuotas (solo si es tarjeta de crédito y es gasto)
            if (_transactionType == 'expense' &&
                _selectedAccountId != null) ...[
              accountsAsync.maybeWhen(
                data: (accounts) {
                  final selectedAcc = accounts
                      .where((a) => a.id == _selectedAccountId)
                      .firstOrNull;
                  if (selectedAcc != null &&
                      selectedAcc.type == 'credit_card') {
                    return Column(
                      children: [
                        const SizedBox(height: 16),
                        CreditCardInstallmentSelector(
                          account: selectedAcc,
                          amount:
                              double.tryParse(
                                _amountController.text.replaceAll(',', '.'),
                              ) ??
                              0.0,
                          purchaseDate: _selectedDate,
                          isInstallment: _isInstallment,
                          installmentsCount: _installmentsCount,
                          hasInterest: _hasInterest,
                          teaController: _installmentTeaController,
                          transactionCurrency: _currency,
                          useManualMonthlyPayment: _useManualMonthlyPayment,
                          manualMonthlyPaymentController:
                              _manualMonthlyPaymentController,
                          onModeChanged: (val) =>
                              setState(() => _isInstallment = val),
                          onInstallmentsCountChanged: (val) =>
                              setState(() => _installmentsCount = val),
                          onHasInterestChanged: (val) =>
                              setState(() => _hasInterest = val),
                          onTeaChanged: (_) => setState(() {}),
                          onManualMonthlyPaymentModeChanged: (val) =>
                              setState(() => _useManualMonthlyPayment = val),
                          onManualMonthlyPaymentChanged: (_) => setState(() {}),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],

            const SizedBox(height: 16),

            // Selector de cuenta destino (solo para transferencias)
            if (_transactionType == 'transfer') ...[
              _buildDestinationAccountSelector(accountsAsync),
              const SizedBox(height: 16),
            ],

            // Selector de categoría (solo para income/expense)
            if (_transactionType != 'transfer') ...[
              _buildCategorySelector(categoriesAsync),
              const SizedBox(height: 16),

              // Selector de subcategoría (si hay categoría seleccionada)
              if (_selectedCategoryId != null)
                _buildSubcategorySelector(_selectedCategoryId!),

              if (_pendingAiSuggestion != null &&
                  _pendingAiSuggestion!.hasNewSuggestion) ...[
                const SizedBox(height: 12),
                _buildAiCategorySuggestionBanner(),
              ],
            ],

            if (_transactionType != 'transfer') const SizedBox(height: 16),

            // Campo de producto (nuevo)
            _buildProductNameField(),

            const SizedBox(height: 16),

            // Cantidad y Unidad (opcional, solo gastos o compras)
            if (_transactionType != 'transfer') ...[
              _buildQuantityAndUnitFields(),
              const SizedBox(height: 16),
            ],

            // Campo de comercio/descripción
            _buildDescriptionField(),

            const SizedBox(height: 16),

            // Selector de fecha
            _buildDateSelector(),

            if (_transactionType == 'income') ...[
              const SizedBox(height: 12),
              _buildNextMonthIncomeToggle(),
            ],

            const SizedBox(height: 16),

            // Botón de ubicación GPS
            _buildLocationButton(),

            const SizedBox(height: 16),

            // Opción de pago recurrente (solo para gastos/ingresos)
            if (_transactionType != 'transfer') ...[
              SwitchListTile(
                title: Text(
                  _transactionType == 'expense'
                      ? '¿Es un gasto frecuente?'
                      : '¿Es un ingreso frecuente?',
                ),
                subtitle: Text(
                  _transactionType == 'expense'
                      ? 'Ej. Suscripciones, Alquiler'
                      : 'Ej. Sueldo, Renta',
                ),
                value: _isRecurring,
                onChanged: (value) {
                  setState(() {
                    _isRecurring = value;
                  });
                },
                secondary: const Icon(Icons.loop),
                contentPadding: EdgeInsets.zero,
              ),

              if (_isRecurring) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Frecuencia',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.update),
                  ),
                  initialValue: _frequency,
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
                    DropdownMenuItem(value: 'monthly', child: Text('Mensual')),
                    DropdownMenuItem(value: 'yearly', child: Text('Anual')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _frequency = value);
                    }
                  },
                ),
              ],
            ],

            const SizedBox(height: 32),

            // Botón guardar
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildNextMonthIncomeToggle() {
    final nextInfo = FinancialPlanningService.nextMonthOf(_selectedDate);
    final isEndOfMonth = FinancialPlanningService.isEndOfMonthPayWindow(
      _selectedDate,
    );
    final accent = const Color(0xFF00C896);

    return Container(
      decoration: BoxDecoration(
        color: (_assignIncomeToNextMonth || isEndOfMonth)
            ? accent.withValues(alpha: 0.08)
            : Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (_assignIncomeToNextMonth || isEndOfMonth)
              ? accent.withValues(alpha: 0.4)
              : Theme.of(context).colorScheme.outlineVariant
                    .withValues(alpha: 0.3),
        ),
      ),
      child: SwitchListTile(
        value: _assignIncomeToNextMonth,
        onChanged: (v) => setState(() => _assignIncomeToNextMonth = v),
        activeThumbColor: accent,
        secondary: Icon(
          Icons.calendar_month_rounded,
          color: (_assignIncomeToNextMonth || isEndOfMonth) ? accent : null,
        ),
        title: Text(
          'Contar para el presupuesto de ${nextInfo.label}',
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          isEndOfMonth
              ? '💡 ¿Es tu sueldo de fin de mes? Mantiene su fecha real (${DateFormat('dd/MM').format(_selectedDate)}), pero suma como ingreso de ${nextInfo.label}.'
              : 'Opcional: útil para sueldos cobrados a fin de mes que financian el mes siguiente.',
          style: const TextStyle(fontSize: 11.5),
        ),
      ),
    );
  }

  Widget _buildAiCategorySuggestionBanner() {
    final sug = _pendingAiSuggestion!;
    final cs = Theme.of(context).colorScheme;
    final title = sug.isNewCategory
        ? 'IA sugiere crear categoría "${sug.categoryName}"'
              '${sug.isNewSubcategory && sug.subcategoryName != null ? ' › "${sug.subcategoryName}"' : ''}'
        : 'IA sugiere crear subcategoría "${sug.subcategoryName}"'
              '${sug.categoryName != null ? ' en ${sug.categoryName}' : ''}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF00C896).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00C896).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 18,
                color: Color(0xFF00C896),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: cs.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _pendingAiSuggestion = null),
              ),
            ],
          ),
          if (sug.reason != null && sug.reason!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              sug.reason!,
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isCreatingSuggestedCat
                  ? null
                  : _acceptAiCategorySuggestion,
              icon: _isCreatingSuggestedCat
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.add_circle_outline, size: 16),
              label: const Text(
                'Crear y usar',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00C896),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: _TypeButton(
                label: 'Gasto',
                icon: Icons.arrow_upward,
                color: AppColors.expense,
                isSelected: _transactionType == 'expense',
                onTap: () {
                  setState(() {
                    _transactionType = 'expense';
                    _selectedCategoryId = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TypeButton(
                label: 'Ingreso',
                icon: Icons.arrow_downward,
                color: AppColors.income,
                isSelected: _transactionType == 'income',
                onTap: () {
                  setState(() {
                    _transactionType = 'income';
                    _selectedCategoryId = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TypeButton(
                label: 'Transferir',
                icon: Icons.swap_horiz,
                color: AppColors.transfer,
                isSelected: _transactionType == 'transfer',
                onTap: () {
                  setState(() {
                    _transactionType = 'transfer';
                    _selectedCategoryId = null;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(
              labelText: 'Moneda',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 16,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'PEN', child: Text('PEN')),
              DropdownMenuItem(value: 'USD', child: Text('USD')),
              DropdownMenuItem(value: 'EUR', child: Text('EUR')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _currency = val);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _amountController,
            onTap: () => clearAmountIfZero(_amountController),
            decoration: InputDecoration(
              labelText: 'Monto',
              prefixText: '$_currency ',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa un monto';
              }
              final amount = double.tryParse(value);
              if (amount == null || amount <= 0) {
                return 'Ingresa un monto válido';
              }
              return null;
            },
            autofocus: true,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSelector(AsyncValue<List<Account>> accountsAsync) {
    return AccountSelector(
      selectedAccountId: _selectedAccountId,
      onAccountSelected: (value) {
        setState(() {
          _selectedAccountId = value;
          // Resetear destino si es igual al origen
          if (_destinationAccountId == value) {
            _destinationAccountId = null;
          }

          // Si es tarjeta de crédito, inicializar la TEA configurada
          final accounts = accountsAsync.valueOrNull ?? [];
          final account = accounts.where((a) => a.id == value).firstOrNull;
          if (account != null && account.type == 'credit_card') {
            if (account.tea != null && account.tea! > 0) {
              _installmentTeaController.text = account.tea!.toStringAsFixed(1);
              _hasInterest = true;
            } else {
              _installmentTeaController.text = '54.9';
            }
          }
        });
      },
    );
  }

  Widget _buildDestinationAccountSelector(
    AsyncValue<List<Account>> accountsAsync,
  ) {
    return AccountSelector(
      selectedAccountId: _destinationAccountId,
      accountIdToExclude: _selectedAccountId,
      onAccountSelected: (value) {
        setState(() {
          _destinationAccountId = value;
        });
      },
    );
  }

  Widget _buildCategorySelector(AsyncValue<List<Category>> categoriesAsync) {
    return CategorySelector(
      selectedCategoryId: _selectedCategoryId,
      transactionType: _transactionType,
      onCategorySelected: (value) {
        setState(() {
          _selectedCategoryId = value;
          _selectedSubcategoryId = null; // Resetear subcategoría
        });
      },
    );
  }

  Widget _buildSubcategorySelector(String categoryId) {
    // Usar ref.watch para observar el stream de subcategorías
    final subcategoriesAsync = ref.watch(
      subcategoriesStreamProvider(categoryId),
    );

    return subcategoriesAsync.when(
      data: (subcategories) {
        if (subcategories.isEmpty) {
          return const SizedBox.shrink(); // No mostrar nada si no hay subcategorías
        }

        return Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Subcategoría (opcional)',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                prefixIcon: const Icon(Icons.subdirectory_arrow_right),
              ),
              initialValue: _selectedSubcategoryId,
              items: subcategories.map<DropdownMenuItem<String>>((subcategory) {
                return DropdownMenuItem(
                  value: subcategory.id,
                  child: Row(
                    children: [
                      if (subcategory.icon != null)
                        Text(
                          subcategory.icon!,
                          style: const TextStyle(fontSize: 20),
                        ),
                      if (subcategory.icon != null) const SizedBox(width: 8),
                      Text(subcategory.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSubcategoryId = value;
                });
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, stack) =>
          const SizedBox.shrink(), // Ocultar errores silenciosamente en UI
    );
  }

  Widget _buildProductNameField() {
    return TextFormField(
      controller: _productNameController,
      focusNode: _productNameFocusNode,
      onChanged: _onProductNameChanged,
      decoration: InputDecoration(
        labelText: 'Producto / Ítem (opcional)',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        prefixIcon: const Icon(Icons.inventory_2_outlined),
        suffixIcon: _isPredictingCategory
            ? Container(
                padding: const EdgeInsets.all(12),
                width: 20,
                height: 20,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome, color: Colors.amber),
        hintText: 'Ej. Mandarina, Leche Gloria, NESQUIK',
      ),
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildQuantityAndUnitFields() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: _quantityController,
            decoration: InputDecoration(
              labelText: 'Cantidad',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              prefixIcon: const Icon(Icons.numbers),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            initialValue:
                [
                  'UND',
                  'KG',
                  'GRS',
                  'LTR',
                  'MLS',
                  'CAJA',
                  'MTS',
                ].contains(_unitController.text)
                ? _unitController.text
                : 'UND',
            decoration: InputDecoration(
              labelText: 'Unidad',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
            items: const [
              DropdownMenuItem(value: 'UND', child: Text('Unidad (UND)')),
              DropdownMenuItem(value: 'KG', child: Text('Kilos (KG)')),
              DropdownMenuItem(value: 'GRS', child: Text('Gramos (GRS)')),
              DropdownMenuItem(value: 'LTR', child: Text('Litros (LTR)')),
              DropdownMenuItem(value: 'MLS', child: Text('Mililitros (MLS)')),
              DropdownMenuItem(value: 'CAJA', child: Text('Caja (CAJA)')),
              DropdownMenuItem(value: 'MTS', child: Text('Metros (MTS)')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _unitController.text = val;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: InputDecoration(
        labelText: 'Comercio / Descripción (opcional)',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        prefixIcon: const Icon(Icons.store_outlined),
        hintText: 'Ej. Lider Cloud, Mercado Central',
      ),
      maxLines: 2,
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildDateSelector() {
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'es');

    return InkWell(
      onTap: () => _selectDate(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Fecha',
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          prefixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          dateFormat.format(_selectedDate),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildLocationButton() {
    final hasLocation = _latitude != null && _longitude != null;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: _isCapturingLocation ? null : _captureLocation,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Ubicación (opcional)',
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: colorScheme.surface,
          prefixIcon: _isCapturingLocation
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Icon(
                  hasLocation ? Icons.location_on : Icons.location_off,
                  color: hasLocation ? colorScheme.primary : null,
                ),
          suffixIcon: hasLocation
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Quitar ubicación',
                  onPressed: () => setState(() {
                    _latitude = null;
                    _longitude = null;
                    _locationName = null;
                  }),
                )
              : null,
        ),
        child: Text(
          hasLocation
              ? (_locationName ??
                    'lat ${_latitude!.toStringAsFixed(4)}, lon ${_longitude!.toStringAsFixed(4)}')
              : _isCapturingLocation
              ? 'Obteniendo ubicación...'
              : 'Toca para capturar ubicación',
          style: TextStyle(
            color: hasLocation
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
            fontStyle: hasLocation ? FontStyle.normal : FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return FilledButton.icon(
      onPressed: _isLoading ? null : _saveTransaction,
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save),
      label: Text(_isLoading ? 'Guardando...' : 'Guardar Transacción'),
      style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
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
            Icon(icon, color: isSelected ? color : Colors.grey, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
