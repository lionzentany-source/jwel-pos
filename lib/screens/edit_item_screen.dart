import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import '../widgets/adaptive_scaffold.dart';
import '../widgets/app_button.dart';
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
  void _showCategoryPicker(List<dynamic> categories) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('اختر الفئة'),
          actions: categories.map<Widget>((cat) {
            return CupertinoActionSheetAction(
              child: Text(cat.nameAr),
              onPressed: () {
                setState(() {
                  _selectedCategoryId = cat.id;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }

  void _showMaterialPicker(List<dynamic> materials) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('اختر المادة'),
          actions: materials.map<Widget>((mat) {
            return CupertinoActionSheetAction(
              child: Text(mat.nameAr),
              onPressed: () {
                setState(() {
                  _selectedMaterialId = mat.id;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }

  final _formKey = GlobalKey<FormState>();
  final _skuController = TextEditingController();
  final _weightController = TextEditingController();
  final _karatController = TextEditingController();
  final _workmanshipController = TextEditingController();
  final _stonePriceController = TextEditingController();
  final _costPriceController = TextEditingController();

  int? _selectedCategoryId;
  int? _selectedMaterialId;
  ItemLocation _selectedLocation = ItemLocation.warehouse;
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
    _selectedLocation = widget.item.location;
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
      showBackButton: false,
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: AppButton.primary(
            text: 'حفظ',
            onPressed: _isLoading ? null : _saveItem,
          ),
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
                    validator: (value) =>
                        value?.isEmpty == true ? 'مطلوب' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _karatController,
                    label: 'العيار',
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value?.isEmpty == true ? 'مطلوب' : null,
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
                    validator: (value) =>
                        value?.isEmpty == true ? 'مطلوب' : null,
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
            const SizedBox(height: 16),
            _buildLocationPicker(),
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

    final updatedItem = Item(
      id: widget.item.id,
      sku: _skuController.text.trim(),
      categoryId: _selectedCategoryId ?? widget.item.categoryId,
      materialId: _selectedMaterialId ?? widget.item.materialId,
      weightGrams: double.parse(_weightController.text),
      karat: int.parse(_karatController.text),
      workmanshipFee: double.parse(_workmanshipController.text),
      stonePrice: double.parse(
        _stonePriceController.text.isEmpty ? '0' : _stonePriceController.text,
      ),
      costPrice: double.parse(
        _costPriceController.text.isEmpty ? '0' : _costPriceController.text,
      ),
      imagePath: _imagePath,
      rfidTag: widget.item.rfidTag,
      status: widget.item.status,
      location: _selectedLocation,
      createdAt: widget.item.createdAt,
    );

    await ref.read(itemNotifierProvider.notifier).updateItem(updatedItem);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildLocationPicker() {
    final labelStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('مكان الصنف', style: labelStyle),
        const SizedBox(height: 8),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(8),
          onPressed: () {
            showCupertinoModalPopup(
              context: context,
              builder: (_) => CupertinoActionSheet(
                title: const Text('اختر المكان'),
                actions: ItemLocation.values.map((loc) {
                  return CupertinoActionSheetAction(
                    onPressed: () {
                      setState(() => _selectedLocation = loc);
                      Navigator.pop(context);
                    },
                    child: Text(loc.displayName),
                  );
                }).toList(),
                cancelButton: CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
              ),
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_selectedLocation.displayName),
              const Icon(CupertinoIcons.chevron_down),
            ],
          ),
        ),
      ],
    );
  }
}
