import 'package:flutter/cupertino.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/adaptive_scaffold.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../widgets/app_loading_error_widget.dart';

class ManageCategoriesScreen extends ConsumerStatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  ConsumerState<ManageCategoriesScreen> createState() =>
      _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState
    extends ConsumerState<ManageCategoriesScreen> {
  final Map<String, IconData> _availableIcons = {
    'ring': CupertinoIcons.circle,
    'bracelet': CupertinoIcons.link,
    'necklace': CupertinoIcons.heart,
    'earrings': CupertinoIcons.circle_grid_hex,
    'tag': CupertinoIcons.tag,
    'star': CupertinoIcons.star,
    'drop': CupertinoIcons.drop,
  };

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryNotifierProvider);

    return Container(
      color: Color(0xfff6f8fa), // خلفية موحدة
      child: AdaptiveScaffold(
        title: 'إدارة الفئات',
        commandBarItems: [
          CommandBarButton(
            icon: const Icon(FluentIcons.add, size: 20),
            label: const Text(
              'إضافة',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            onPressed: () => _showAddCategoryDialog(),
          ),
        ],
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: categoriesAsync.when(
            data: (categories) => _buildCategoriesList(categories),
            loading: () => const Center(child: ProgressRing()),
            error: (error, stack) => AppLoadingErrorWidget(
              title: 'خطأ في تحميل الفئات',
              message: error.toString(),
              onRetry: () => ref.refresh(categoryNotifierProvider),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesList(List<Category> categories) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FluentIcons.tag,
              size: 80,
              color: FluentTheme.of(context).inactiveColor,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد فئات',
              style: FluentTheme.of(context).typography.subtitle,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _showAddCategoryDialog(),
              child: const Text('إضافة فئة جديدة'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _buildCategoryCard(category);
      },
    );
  }

  Widget _buildCategoryCard(Category category) {
    return Card(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              _getIconFromName(category.iconName),
              color: CupertinoColors.activeBlue,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.nameAr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'أيقونة: ${category.iconName}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          // أيقونة تعديل فقط
          GestureDetector(
            onTap: () => _showEditCategoryDialog(category),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(
                FluentIcons.edit,
                color: FluentTheme.of(context).accentColor,
                size: 24,
              ),
            ),
          ),
          // أيقونة حذف فقط
          GestureDetector(
            onTap: () => _showDeleteConfirmation(category),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(FluentIcons.delete, color: Colors.red, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconFromName(String iconName) {
    return _availableIcons[iconName] ?? FluentIcons.tag;
  }

  void _showAddCategoryDialog() {
    _showCategoryFormDialog();
  }

  void _showEditCategoryDialog(Category category) {
    _showCategoryFormDialog(category: category);
  }

  void _showCategoryFormDialog({Category? category}) {
    final bool isEditMode = category != null;
    final nameController = TextEditingController(text: category?.nameAr ?? '');
    String selectedIconName = category?.iconName ?? _availableIcons.keys.first;

    showCupertinoDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return CupertinoAlertDialog(
              title: Text(isEditMode ? 'تعديل الفئة' : 'إضافة فئة جديدة'),
              content: Column(
                children: [
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: nameController,
                    placeholder: 'اسم الفئة',
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    onPressed: () => _showIconPicker(
                      setState,
                      (newIcon) => selectedIconName = newIcon,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(selectedIconName),
                        Icon(_getIconFromName(selectedIconName)),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('إلغاء'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoDialogAction(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      final navigator = Navigator.of(context);
                      try {
                        final newCategory = Category(
                          id: category?.id,
                          nameAr: nameController.text,
                          iconName: selectedIconName,
                        );

                        if (isEditMode) {
                          await ref
                              .read(categoryNotifierProvider.notifier)
                              .updateCategory(newCategory);
                        } else {
                          await ref
                              .read(categoryNotifierProvider.notifier)
                              .addCategory(newCategory);
                        }
                        navigator.pop();
                        _showSuccessMessage(
                          isEditMode
                              ? 'تم تحديث الفئة بنجاح'
                              : 'تم إضافة الفئة بنجاح',
                        );
                      } catch (error) {
                        _showErrorMessage('خطأ: $error');
                      }
                    }
                  },
                  child: Text(isEditMode ? 'حفظ' : 'إضافة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showIconPicker(StateSetter setState, Function(String) onIconSelected) {
    String tempIcon = _availableIcons.keys.first;
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
                    'اختر أيقونة',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  CupertinoButton(
                    child: const Text('تم'),
                    onPressed: () {
                      setState(() => onIconSelected(tempIcon));
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                onSelectedItemChanged: (index) {
                  tempIcon = _availableIcons.keys.elementAt(index);
                },
                children: _availableIcons.keys
                    .map(
                      (iconName) => Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getIconFromName(iconName)),
                            const SizedBox(width: 8),
                            Text(iconName),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Category category) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('حذف الفئة'),
        content: Text('هل أنت متأكد من حذف فئة "${category.nameAr}"؟'),
        actions: [
          CupertinoDialogAction(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              final navigator = Navigator.of(context);
              try {
                await ref
                    .read(categoryNotifierProvider.notifier)
                    .deleteCategory(category.id!);
                navigator.pop();
                _showSuccessMessage('تم حذف الفئة بنجاح');
              } catch (error) {
                navigator.pop();
                _showErrorMessage('خطأ في حذف الفئة: $error');
              }
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('تم بنجاح'),
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

  void _showErrorMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('خطأ'),
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
