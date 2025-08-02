import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import '../widgets/adaptive_scaffold.dart';
import '../models/item.dart';
import '../providers/item_provider.dart';
import '../providers/category_provider.dart';
import '../providers/material_provider.dart';

class EditItemScreen extends ConsumerStatefulWidget {
  final Item item;

  const EditItemScreen({super.key, required this.item});

  @override
  ConsumerState<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends ConsumerState<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _skuController = TextEditingController();
  final _weightController = TextEditingController();
  final _karatController = TextEditingController();
  final _workmanshipController = TextEditingController();
  final _stonePriceController = TextEditingController();
  final _costPriceController = TextEditingController();

  int? _selectedCategoryId;
  int? _selectedMaterialId;
  String? _imagePath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    _skuController.text = widget.item.sku;
    _weightController.text = widget.item.weightGrams.toString();
    _karatController.text = widget.item.karat.toString();
    _workmanshipController.text = widget.item.workmanshipFee.toString();
    _stonePriceController.text = widget.item.stonePrice.toString();
    _costPriceController.text = widget.item.costPrice.toString();
    _selectedCategoryId = widget.item.categoryId;
    _selectedMaterialId = widget.item.materialId;
    _imagePath = widget.item.imagePath;
  }

  @override
  void dispose() {
    _skuController.dispose();
    _weightController.dispose();
    _karatController.dispose();
    _workmanshipController.dispose();
    _stonePriceController.dispose();
    _costPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryNotifierProvider);
    final materialsAsync = ref.watch(materialNotifierProvider);

    return AdaptiveScaffold(
      title: 'تعديل الصنف',
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _saveItem,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : const Text('حفظ'),
        ),
      ],
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // صورة المنتج
            _buildImageSection(),
            const SizedBox(height: 24),

            // رقم الصنف
            _buildTextField(
              controller: _skuController,
              label: 'رقم الصنف (SKU)',
              validator: (value) => value?.isEmpty == true ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),

            // الفئة والمادة
            Row(
              children: [
                Expanded(
                  child: categoriesAsync.when(
                    data: (categories) => _buildCategoryPicker(categories),
                    loading: () => const CupertinoActivityIndicator(),
                    error: (_, __) => const Text('خطأ في تحميل الفئات'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: materialsAsync.when(
                    data: (materials) => _buildMaterialPicker(materials),
                    loading: () => const CupertinoActivityIndicator(),
                    error: (_, __) => const Text('خطأ في تحميل المواد'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // الوزن والعيار
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _weightController,
                    label: 'الوزن (جرام)',
                    keyboardType: TextInputType.number,
                    validator: (value) => value?.isEmpty == true ? 'مطلوب' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _karatController,
                    label: 'العيار',
                    keyboardType: TextInputType.number,
                    validator: (value) => value?.isEmpty == true ? 'مطلوب' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // المصنعية وسعر الأحجار
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _workmanshipController,
                    label: 'المصنعية (د.ل)',
                    keyboardType: TextInputType.number,
                    validator: (value) => value?.isEmpty == true ? 'مطلوب' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _stonePriceController,
                    label: 'سعر الأحجار (د.ل)',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // سعر التكلفة
            _buildTextField(
              controller: _costPriceController,
              label: 'سعر التكلفة (د.ل)',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          if (_imagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_imagePath!),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            )
          else
            const Center(
              child: Icon(
                CupertinoIcons.camera,
                size: 50,
                color: CupertinoColors.systemGrey3,
              ),
            ),
          Positioned(
            bottom: 8,
            right: 8,
            child: CupertinoButton(
              padding: const EdgeInsets.all(8),
              color: CupertinoColors.activeBlue,
              borderRadius: BorderRadius.circular(20),
              onPressed: _pickImage,
              child: const Icon(
                CupertinoIcons.camera,
                color: CupertinoColors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        CupertinoTextFormFieldRow(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.systemGrey4),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPicker(List<dynamic> categories) {
    final selectedCategory = categories.firstWhere(
      (cat) => cat.id == _selectedCategoryId,
      orElse: () => categories.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الفئة',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showCategoryPicker(categories),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: CupertinoColors.systemGrey4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(selectedCategory.nameAr),
                const Icon(CupertinoIcons.chevron_down),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialPicker(List<dynamic> materials) {
    final selectedMaterial = materials.firstWhere(
      (mat) => mat.id == _selectedMaterialId,
      orElse: () => materials.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المادة',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showMaterialPicker(materials),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: CupertinoColors.systemGrey4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(selectedMaterial.nameAr),
                const Icon(CupertinoIcons.chevron_down),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedItem = Item(
        id: widget.item.id,
        sku: _skuController.text.trim(),
        categoryId: _selectedCategoryId ?? widget.item.categoryId,
        materialId: _selectedMaterialId ?? widget.item.materialId,
        weightGrams: double.parse(_weightController.text),
        karat: int.parse(_karatController.text),
        workmanshipFee: double.parse(_workmanshipController.text),
        stonePrice: double.parse(_stonePriceController.text.isEmpty ? '0' : _stonePriceController.text),
        costPrice: double.parse(_costPriceController.text.isEmpty ? '0' : _costPriceController.text),
        imagePath: _imagePath,
        rfidTag: widget.item.rfidTag,
        status: widget.item.status,
        createdAt: widget.item.createdAt,
      );

      await ref.read(itemNotifierProvider.notifier).updateItem(updatedItem);

      if (mounted) {
        Navigator.pop(context);
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('تم بنجاح'),
            content: const Text('تم تحديث الصنف بنجاح'),
            actions: [
              CupertinoDialogAction(
                child: const Text('موافق'),
                onPressed: () => Navigator.pop(context),
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
            content: Text('حدث خطأ أثناء تحديث الصنف: $error'),
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

  void _showCategoryPicker(List<dynamic> categories) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: CupertinoColors.systemBackground,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  const Text('اختر الفئة', style: TextStyle(fontWeight: FontWeight.w600)),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('تم'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                onSelectedItemChanged: (index) {
                  setState(() {
                    _selectedCategoryId = categories[index].id;
                  });
                },
                children: categories.map((category) => Text(category.nameAr)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMaterialPicker(List<dynamic> materials) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: CupertinoColors.systemBackground,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  const Text('اختر المادة', style: TextStyle(fontWeight: FontWeight.w600)),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('تم'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                onSelectedItemChanged: (index) {
                  setState(() {
                    _selectedMaterialId = materials[index].id;
                  });
                },
                children: materials.map((material) => Text(material.nameAr)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
