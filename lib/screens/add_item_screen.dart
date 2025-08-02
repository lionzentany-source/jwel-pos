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
import '../providers/rfid_provider.dart';
import '../providers/user_provider.dart';
import '../services/user_activity_service.dart';
import '../models/user_activity.dart';
import '../widgets/adaptive_button.dart' as ab;

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
    _costPriceController.text = item.costPrice.toString();
    _rfidTagController.text = item.rfidTag ?? '';
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
    return AdaptiveScaffold(
      title: _isEditMode ? 'تعديل الصنف' : 'إضافة صنف جديد',
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionTitle('الفئة'),
                categoriesAsync.when(
                  data: (categories) => _buildCategoryPicker(categories),
                  loading: () => const CupertinoActivityIndicator(),
                  error: (error, stack) => Text('خطأ في تحميل الفئات: $error'),
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('المادة الخام'),
                materialsAsync.when(
                  data: (materials) => _buildMaterialPicker(materials),
                  loading: () => const CupertinoActivityIndicator(),
                  error: (error, stack) => Text('خطأ في تحميل المواد: $error'),
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('الوزن (جرام)'),
                CupertinoTextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  placeholder: 'أدخل الوزن بالجرام',
                  padding: const EdgeInsets.all(16),
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('العيار'),
                CupertinoTextField(
                  controller: _karatController,
                  keyboardType: TextInputType.number,
                  placeholder: 'أدخل العيار (مثل: 18، 21، 24)',
                  padding: const EdgeInsets.all(16),
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('المصنعية (د.ل)'),
                CupertinoTextField(
                  controller: _workmanshipController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  placeholder: 'أدخل قيمة المصنعية',
                  padding: const EdgeInsets.all(16),
                ),
                const SizedBox(height: 20),
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
                _buildSectionTitle('سعر التكلفة (د.ل)'),
                CupertinoTextField(
                  controller: _costPriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  placeholder: 'أدخل سعر التكلفة الفعلي',
                  padding: const EdgeInsets.all(16),
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('بطاقة RFID (اختياري)'),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: _rfidTagController,
                        placeholder: 'امسح بطاقة RFID أو أدخلها يدوياً',
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(width: 10),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        final rfidService = ref.read(rfidServiceProvider);
                        final tag = await rfidService.readSingleTag();
                        if (!context.mounted) return;
                        if (tag != null) {
                          if (!context.mounted) return;
                          setState(() {
                            _rfidTagController.text = tag;
                          });
                        } else if (context.mounted) {
                          showCupertinoDialog(
                            context: context,
                            builder: (dialogContext) => CupertinoAlertDialog(
                              title: const Text('خطأ في قراءة RFID'),
                              content: const Text(
                                'لم يتم العثور على بطاقة RFID أو حدث خطأ.',
                              ),
                              actions: [
                                CupertinoDialogAction(
                                  child: const Text('موافق'),
                                  onPressed: () => Navigator.pop(dialogContext),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      child: const Icon(CupertinoIcons.barcode_viewfinder),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('صورة المنتج'),
                _buildImagePicker(),
                const SizedBox(height: 30),
                ab.AdaptiveButton(
                  label: _isLoading ? 'جاري الحفظ...' : 'حفظ الصنف',
                  onPressed: _isLoading
                      ? () {}
                      : () {
                          _saveItem().ignore();
                        },
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
    return CupertinoButton(
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
    );
  }

  Widget _buildMaterialPicker(List<Material> materials) {
    return CupertinoButton(
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
              color: CupertinoColors.systemGrey6,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(_selectedImage!, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 10),
        ],
        ab.AdaptiveButton(
          label: _selectedImage != null ? 'تغيير الصورة' : 'اختيار صورة',
          onPressed: _isLoading
              ? () {}
              : () {
                  _pickImage();
                },
        ),
      ],
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
              height: 56,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: CupertinoColors.separator),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: TextDirection.rtl,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: const Text('إلغاء', overflow: TextOverflow.visible),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'اختر الفئة',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: const Text('تم', overflow: TextOverflow.visible),
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
              height: 56,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: CupertinoColors.separator),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: TextDirection.rtl,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: const Text('إلغاء', overflow: TextOverflow.visible),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'اختر المادة',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: const Text('تم', overflow: TextOverflow.visible),
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
    if (!_validateInputs()) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final itemNotifier = ref.read(itemNotifierProvider.notifier);
      final repository = ref.read(itemRepositoryProvider);

      // تنسيق بطاقة RFID (إزالة الفراغات وتحويلها لأحرف كبيرة)
      String? normalizedTag;
      if (_rfidTagController.text.trim().isNotEmpty) {
        normalizedTag = _rfidTagController.text.trim().toUpperCase();
      }

      // التحقق من عدم تكرار بطاقة RFID قبل محاولة الحفظ لتفادي خطأ UNIQUE
      if (normalizedTag != null) {
        final existing = await repository.getItemByRfidTag(normalizedTag);
        if (existing != null) {
          // في وضع التعديل: إذا كانت نفس البطاقة لنفس الصنف فمسموح، غير ذلك خطأ
          if (!_isEditMode || (_isEditMode && existing.id != widget.item!.id)) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              showCupertinoDialog(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: const Text('بطاقة مكررة'),
                  content: Text(
                    'هذه البطاقة مستخدمة بالفعل مع الصنف: ${existing.sku}\nلا يمكن ربطها بصنف آخر.',
                  ),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text('موافق'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            }
            return; // إيقاف الحفظ
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
        createdAt: _isEditMode ? widget.item!.createdAt : DateTime.now(),
      );
      if (_isEditMode) {
        await itemNotifier.updateItem(item);
      } else {
        await itemNotifier.addItem(item);
      }

      // تسجيل النشاط
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

      // تحديث جميع المزودات المرتبطة
      itemNotifier.refresh();
      ref.invalidate(itemsProvider);
      ref.invalidate(itemsByStatusProvider);
      ref.invalidate(inventoryStatsProvider);

      if (!mounted) return;

      // إظهار رسالة نجاح والعودة مباشرة
      Navigator.pop(context);

      // إظهار رسالة نجاح بسيطة
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('تم بنجاح'),
          content: Text('تم ${_isEditMode ? 'تحديث' : 'حفظ'} الصنف $sku'),
          actions: [
            CupertinoDialogAction(
              child: const Text('موافق'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('خطأ'),
          content: Text(
            'حدث خطأ أثناء حفظ الصنف: $error\nإذا كانت المشكلة تتعلق ببطاقة RFID مكررة، تأكد من عدم استخدامها في صنف آخر.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('موافق'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
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
