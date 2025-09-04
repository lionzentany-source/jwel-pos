import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../models/material.dart' as posmat;
import '../widgets/adaptive_scaffold.dart';
import '../widgets/app_button.dart';
import '../models/item.dart';
import '../models/category.dart';
import '../providers/item_provider.dart';
import '../providers/category_provider.dart';
import '../providers/material_provider.dart';
import '../providers/rfid_provider.dart';
import '../providers/user_provider.dart';
import '../services/user_activity_service.dart';
import '../models/user_activity.dart';

extension Ignore on Future {
  void ignore() {}
}

class AddItemScreen extends ConsumerStatefulWidget {
  final Item? item;
  const AddItemScreen({super.key, this.item});
  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _skuController = TextEditingController();
  final _weightController = TextEditingController();
  final _karatController = TextEditingController();
  final _workmanshipController = TextEditingController();
  final _stonePriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _rfidTagController = TextEditingController();

  Category? _selectedCategory;
  posmat.Material? _selectedMaterial;
  ItemLocation _selectedLocation = ItemLocation.warehouse;
  File? _selectedImage;
  bool _isLoading = false;
  bool get _isEditMode => widget.item != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _populateFields(widget.item!);
    }
  }

  void _populateFields(Item item) {
    _skuController.text = item.sku;
    _weightController.text = item.weightGrams.toString();
    _karatController.text = item.karat.toString();
    _workmanshipController.text = item.workmanshipFee.toString();
    _stonePriceController.text = item.stonePrice.toString();
    _costPriceController.text = item.costPrice.toString();
    _rfidTagController.text = item.rfidTag ?? '';
    _selectedLocation = item.location;
    if (item.imagePath != null) {
      _selectedImage = File(item.imagePath!);
    }
    final categories = ref.read(categoryNotifierProvider).asData?.value ?? [];
    final materials = ref.read(materialNotifierProvider).asData?.value ?? [];
    _selectedCategory = categories.isNotEmpty
        ? categories.firstWhere(
            (c) => c.id == item.categoryId,
            orElse: () => categories.first,
          )
        : null;
    _selectedMaterial = materials.isNotEmpty
        ? materials.firstWhere(
            (m) => m.id == item.materialId,
            orElse: () => materials.first,
          )
        : null;
  }

  @override
  void dispose() {
    _skuController.dispose();
    _weightController.dispose();
    _karatController.dispose();
    _workmanshipController.dispose();
    _stonePriceController.dispose();
    _costPriceController.dispose();
    _rfidTagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryNotifierProvider);
    final materialsAsync = ref.watch(materialNotifierProvider);
    final theme = FluentTheme.of(context);

    return AdaptiveScaffold(
      title: _isEditMode ? 'تعديل الصنف' : 'إضافة صنف جديد',
      backgroundColor: theme.scaffoldBackgroundColor,
      showBackButton: false,
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdaptiveCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionTitle('الفئة'),
                    categoriesAsync.when(
                      data: (categories) => _buildCategoryPicker(categories),
                      loading: () => const Center(child: ProgressRing()),
                      error: (error, stack) =>
                          Text('خطأ في تحميل الفئات: $error'),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('المادة الخام'),
                    materialsAsync.when(
                      data: (materials) => _buildMaterialPicker(materials),
                      loading: () => const Center(child: ProgressRing()),
                      error: (error, stack) =>
                          Text('خطأ في تحميل المواد: $error'),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('الوزن (جرام)'),
                    TextBox(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      placeholder: 'أدخل الوزن بالجرام',
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('العيار'),
                    TextBox(
                      controller: _karatController,
                      keyboardType: TextInputType.number,
                      placeholder: 'أدخل العيار (مثل: 18، 21، 24)',
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('المصنعية (د.ل)'),
                    TextBox(
                      controller: _workmanshipController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      placeholder: 'أدخل قيمة المصنعية',
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('سعر الأحجار (د.ل) - اختياري'),
                    TextBox(
                      controller: _stonePriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      placeholder: 'أدخل سعر الأحجار إن وجدت',
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('سعر التكلفة (د.ل)'),
                    TextBox(
                      controller: _costPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      placeholder: 'أدخل سعر التكلفة الفعلي',
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('مكان الصنف'),
                    _buildLocationPicker(),
                    const SizedBox(height: 20),

                    _buildSectionTitle('بطاقة RFID (اختياري)'),
                    Row(
                      children: [
                        Expanded(
                          child: TextBox(
                            controller: _rfidTagController,
                            placeholder: 'امسح بطاقة RFID أو أدخلها يدوياً',
                          ),
                        ),
                        const SizedBox(width: 10),
                        AppButton.secondary(
                          text: 'مسح',
                          icon: FluentIcons.search,
                          onPressed: _isLoading
                              ? null
                              : () {
                                  final rfidService = ref.read(
                                    rfidServiceProvider,
                                  );
                                  rfidService.readSingleTag().then((tag) {
                                    if (!mounted) return;
                                    if (tag != null) {
                                      setState(() {
                                        _rfidTagController.text = tag;
                                      });
                                    } else {
                                      _showError(
                                        'لم يتم العثور على بطاقة RFID أو حدث خطأ.',
                                      );
                                    }
                                  });
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('صورة المنتج'),
                    _buildImagePicker(),
                    const SizedBox(height: 30),
                    FilledButton(
                      onPressed: _isLoading ? null : _saveItem,
                      child: _isLoading
                          ? const ProgressRing()
                          : const Text('حفظ الصنف'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: theme.typography.subtitle),
    );
  }

  Widget _buildCategoryPicker(List<Category> categories) {
    return ComboBox<Category>(
      value: _selectedCategory,
      placeholder: const Text('اختر الفئة'),
      isExpanded: true,
      items: [
        for (final category in categories)
          ComboBoxItem<Category>(value: category, child: Text(category.nameAr)),
      ],
      onChanged: (value) {
        setState(() {
          _selectedCategory = value;
        });
      },
    );
  }

  Widget _buildMaterialPicker(List<posmat.Material> materials) {
    return ComboBox<posmat.Material>(
      value: _selectedMaterial,
      placeholder: const Text('اختر المادة الخام'),
      isExpanded: true,
      items: [
        for (final material in materials)
          ComboBoxItem<posmat.Material>(
            value: material,
            child: Text(material.nameAr),
          ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedMaterial = value;
        });
      },
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        if (_selectedImage != null) ...[
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: FluentTheme.of(context).scaffoldBackgroundColor,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(_selectedImage!, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 10),
        ],
        AppButton.secondary(
          text: _selectedImage != null ? 'تغيير الصورة' : 'اختيار صورة',
          icon: FluentIcons.camera,
          onPressed: _isLoading ? null : _pickImage,
        ),
      ],
    );
  }

  Widget _buildLocationPicker() {
    return ComboBox<ItemLocation>(
      value: _selectedLocation,
      placeholder: const Text('اختر مكان الصنف'),
      isExpanded: true,
      items: [
        for (final loc in ItemLocation.values)
          ComboBoxItem<ItemLocation>(value: loc, child: Text(loc.displayName)),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _selectedLocation = value;
        });
      },
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveItem() async {
    if (!_validateInputs()) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final itemNotifier = ref.read(itemNotifierProvider.notifier);
      final repository = ref.read(itemRepositoryProvider);

      String? normalizedTag;
      if (_rfidTagController.text.trim().isNotEmpty) {
        normalizedTag = _rfidTagController.text.trim().toUpperCase();
      }

      if (normalizedTag != null) {
        final existing = await repository.getItemByRfidTag(normalizedTag);
        if (existing != null) {
          final isSameItemInEdit =
              _isEditMode && existing.id == widget.item!.id;
          if (!isSameItemInEdit) {
            if (existing.status == ItemStatus.sold) {
              final cleared = Item(
                id: existing.id,
                sku: existing.sku,
                categoryId: existing.categoryId,
                materialId: existing.materialId,
                weightGrams: existing.weightGrams,
                karat: existing.karat,
                workmanshipFee: existing.workmanshipFee,
                stonePrice: existing.stonePrice,
                costPrice: existing.costPrice,
                imagePath: existing.imagePath,
                rfidTag: null,
                status: existing.status,
                createdAt: existing.createdAt,
              );
              await repository.updateItem(cleared);
            } else {
              if (mounted) {
                setState(() => _isLoading = false);
                _showError(
                  'هذه البطاقة مستخدمة بالفعل مع الصنف: ${existing.sku}\nلا يمكن ربطها بصنف آخر (الحالة الحالية: ${existing.status.displayName}).',
                );
              }
              return;
            }
          }
        }
      }

      final sku = _isEditMode
          ? widget.item!.sku
          : await itemNotifier.generateNextSku();
      final item = Item(
        id: _isEditMode ? widget.item!.id : null,
        sku: sku,
        categoryId: _selectedCategory!.id!,
        materialId: _selectedMaterial!.id!,
        weightGrams: double.parse(_weightController.text),
        karat: int.parse(_karatController.text),
        workmanshipFee: double.parse(_workmanshipController.text),
        stonePrice: _stonePriceController.text.isNotEmpty
            ? double.parse(_stonePriceController.text)
            : 0.0,
        costPrice: _costPriceController.text.isNotEmpty
            ? double.parse(_costPriceController.text)
            : 0.0,
        imagePath: _selectedImage?.path,
        status: _isEditMode ? widget.item!.status : ItemStatus.inStock,
        rfidTag: normalizedTag,
        location: _selectedLocation,
        createdAt: _isEditMode ? widget.item!.createdAt : DateTime.now(),
      );
      if (_isEditMode) {
        await itemNotifier.updateItem(item);
      } else {
        await itemNotifier.addItem(item);
      }

      final currentUser = ref.read(userNotifierProvider).value;
      if (currentUser != null) {
        await UserActivityService().logActivity(
          userId: currentUser.id!,
          username: currentUser.username,
          activityType: _isEditMode
              ? ActivityType.editItem
              : ActivityType.addItem,
          description: _isEditMode
              ? 'تم تعديل الصنف: $sku'
              : 'تم إضافة صنف جديد: $sku',
          metadata: {
            'item_sku': sku,
            'category_id': _selectedCategory!.id,
            'material_id': _selectedMaterial!.id,
            'weight': item.weightGrams,
            'karat': item.karat,
          },
        );
      }

      itemNotifier.refresh();
      ref.invalidate(itemsProvider);
      ref.invalidate(itemsByStatusProvider);
      ref.invalidate(inventoryStatsProvider);

      if (!mounted) return;

      Navigator.pop(context);

      _showSuccessMessage('تم ${_isEditMode ? 'تحديث' : 'حفظ'} الصنف $sku');
    } catch (error) {
      if (!mounted) return;
      _showError(
        'حدث خطأ أثناء حفظ الصنف: $error\nإذا كانت المشكلة تتعلق ببطاقة RFID مكررة، تأكد من عدم استخدامها في صنف آخر.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _validateInputs() {
    if (_selectedCategory == null) {
      _showError('يرجى اختيار الفئة');
      return false;
    }
    if (_selectedMaterial == null) {
      _showError('يرجى اختيار المادة الخام');
      return false;
    }
    if (_weightController.text.isEmpty ||
        double.tryParse(_weightController.text) == null) {
      _showError('الرجاء إدخال وزن صحيح');
      return false;
    }
    if (_karatController.text.isEmpty ||
        int.tryParse(_karatController.text) == null) {
      _showError('الرجاء إدخال عيار صحيح');
      return false;
    }
    if (_workmanshipController.text.isEmpty ||
        double.tryParse(_workmanshipController.text) == null) {
      _showError('الرجاء إدخال قيمة مصنعية صحيحة');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('خطأ في البيانات'),
        content: Text(message),
        actions: [
          Button(
            child: const Text('موافق'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('تم بنجاح'),
        content: Text(message),
        actions: [
          Button(
            child: const Text('موافق'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
