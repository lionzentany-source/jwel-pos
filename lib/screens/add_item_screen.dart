import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../widgets/adaptive_scaffold.dart';
import '../models/item.dart';
import '../models/category.dart';
import '../models/material.dart';
import '../providers/item_provider.dart';
import '../providers/category_provider.dart';
import '../providers/material_provider.dart';

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

  Category? _selectedCategory;
  Material? _selectedMaterial;
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
    if (item.imagePath != null) {
      _selectedImage = File(item.imagePath!);
    }

    // Fetch and set the initial category and material
    final categories = ref.read(categoryNotifierProvider).asData?.value ?? [];
    final materials = ref.read(materialNotifierProvider).asData?.value ?? [];

    _selectedCategory = categories.firstWhere(
      (c) => c.id == item.categoryId,
      orElse: () => categories.first,
    );
    _selectedMaterial = materials.firstWhere(
      (m) => m.id == item.materialId,
      orElse: () => materials.first,
    );
  }

  @override
  void dispose() {
    _skuController.dispose();
    _weightController.dispose();
    _karatController.dispose();
    _workmanshipController.dispose();
    _stonePriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryNotifierProvider);
    final materialsAsync = ref.watch(materialNotifierProvider);

    return AdaptiveScaffold(
      title: _isEditMode ? 'تعديل الصنف' : 'إضافة صنف جديد',
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // SKU (read-only in edit mode)
                /*
                if (_isEditMode) ...[
                  _buildSectionTitle('SKU'),
                  CupertinoTextField(
                    controller: _skuController,
                    readOnly: true,
                    padding: const EdgeInsets.all(16),
                  ),
                  const SizedBox(height: 20),
                ],
                */

                // اختيار الفئة
                _buildSectionTitle('الفئة'),
                categoriesAsync.when(
                  data: (categories) => _buildCategoryPicker(categories),
                  loading: () => const CupertinoActivityIndicator(),
                  error: (error, stack) => Text('خطأ في تحميل الفئات: $error'),
                ),

                const SizedBox(height: 20),

                // اختيار المادة
                _buildSectionTitle('المادة الخام'),
                materialsAsync.when(
                  data: (materials) => _buildMaterialPicker(materials),
                  loading: () => const CupertinoActivityIndicator(),
                  error: (error, stack) => Text('خطأ في تحميل المواد: $error'),
                ),

                const SizedBox(height: 20),

                // الوزن
                _buildSectionTitle('الوزن (جرام)'),
                CupertinoTextFormFieldRow(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  placeholder: 'أدخل الوزن بالجرام',
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        double.tryParse(value) == null) {
                      return 'الرجاء إدخال وزن صحيح';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // العيار
                _buildSectionTitle('العيار'),
                CupertinoTextFormFieldRow(
                  controller: _karatController,
                  keyboardType: TextInputType.number,
                  placeholder: 'أدخل العيار (مثل: 18، 21، 24)',
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        int.tryParse(value) == null) {
                      return 'الرجاء إدخال عيار صحيح';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // المصنعية
                _buildSectionTitle('المصنعية (د.ل)'),
                CupertinoTextFormFieldRow(
                  controller: _workmanshipController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  placeholder: 'أدخل قيمة المصنعية',
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        double.tryParse(value) == null) {
                      return 'الرجاء إدخال قيمة مصنعية صحيحة';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // سعر الأحجار
                _buildSectionTitle('سعر الأحجار (د.ل) - اختياري'),
                CupertinoTextField(
                  controller: _stonePriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  placeholder: 'أدخل سعر الأحجار إن وجدت',
                  padding: const EdgeInsets.all(16),
                ),

                const SizedBox(height: 20),

                // اختيار الصورة
                _buildSectionTitle('صورة المنتج'),
                _buildImagePicker(),

                const SizedBox(height: 30),

                // زر الحفظ
                CupertinoButton.filled(
                  onPressed: _isLoading ? null : _saveItem,
                  child: Text(_isLoading ? 'جاري الحفظ...' : 'حفظ الصنف'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.label,
        ),
      ),
    );
  }

  Widget _buildCategoryPicker(List<Category> categories) {
    return AdaptiveCard(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _showCategoryPicker(categories),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedCategory?.nameAr ?? 'اختر الفئة',
              style: TextStyle(
                color: _selectedCategory != null
                    ? CupertinoColors.label
                    : CupertinoColors.placeholderText,
              ),
            ),
            const Icon(CupertinoIcons.chevron_down),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialPicker(List<Material> materials) {
    return AdaptiveCard(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _showMaterialPicker(materials),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedMaterial?.nameAr ?? 'اختر المادة الخام',
              style: TextStyle(
                color: _selectedMaterial != null
                    ? CupertinoColors.label
                    : CupertinoColors.placeholderText,
              ),
            ),
            const Icon(CupertinoIcons.chevron_down),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return AdaptiveCard(
      child: Column(
        children: [
          if (_selectedImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _selectedImage!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),
          ],
          AdaptiveButton(
            text: _selectedImage != null ? 'تغيير الصورة' : 'اختيار صورة',
            onPressed: _pickImage,
            icon: CupertinoIcons.camera,
            color: CupertinoColors.systemGrey,
          ),
        ],
      ),
    );
  }

  void _showCategoryPicker(List<Category> categories) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: CupertinoColors.systemBackground,
        child: Column(
          children: [
            Container(
              height: 50,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: CupertinoColors.separator),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('إلغاء'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'اختر الفئة',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  CupertinoButton(
                    child: const Text('تم'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                onSelectedItemChanged: (index) {
                  setState(() {
                    _selectedCategory = categories[index];
                  });
                },
                children: categories
                    .map((category) => Center(child: Text(category.nameAr)))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMaterialPicker(List<Material> materials) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: CupertinoColors.systemBackground,
        child: Column(
          children: [
            Container(
              height: 50,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: CupertinoColors.separator),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('إلغاء'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'اختر المادة',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  CupertinoButton(
                    child: const Text('تم'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                onSelectedItemChanged: (index) {
                  setState(() {
                    _selectedMaterial = materials[index];
                  });
                },
                children: materials
                    .map((material) => Center(child: Text(material.nameAr)))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_validatePickers()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final itemNotifier = ref.read(itemNotifierProvider.notifier);
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
        imagePath: _selectedImage?.path,
        status: _isEditMode ? widget.item!.status : ItemStatus.needsRfid,
        rfidTag: _isEditMode ? widget.item!.rfidTag : null,
        createdAt: _isEditMode ? widget.item!.createdAt : DateTime.now(),
      );

      if (_isEditMode) {
        await itemNotifier.updateItem(item);
      } else {
        await itemNotifier.addItem(item);
      }

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('تم بنجاح'),
            content: Text(
              _isEditMode
                  ? 'تم تحديث الصنف بنجاح'
                  : 'تم إضافة الصنف برقم: $sku',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('موافق'),
                onPressed: () {
                  Navigator.pop(context); // Close the dialog
                  Navigator.pop(context); // Go back to the previous screen
                },
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('خطأ'),
            content: Text('حدث خطأ أثناء حفظ الصنف: $error'),
            actions: [
              CupertinoDialogAction(
                child: const Text('موافق'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _validatePickers() {
    if (_selectedCategory == null) {
      _showError('يرجى اختيار الفئة');
      return false;
    }

    if (_selectedMaterial == null) {
      _showError('يرجى اختيار المادة الخام');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('خطأ في البيانات'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('موافق'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
