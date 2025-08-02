import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/adaptive_scaffold.dart';
import '../models/material.dart';
import '../providers/material_provider.dart';
import '../widgets/app_loading_error_widget.dart';

class ManageMaterialsScreen extends ConsumerStatefulWidget {
  const ManageMaterialsScreen({super.key});

  @override
  ConsumerState<ManageMaterialsScreen> createState() =>
      _ManageMaterialsScreenState();
}

class _ManageMaterialsScreenState extends ConsumerState<ManageMaterialsScreen> {
  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(materialNotifierProvider);

    return AdaptiveScaffold(
      title: 'إدارة المواد الخام',
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showAddMaterialDialog(),
          child: const Icon(CupertinoIcons.add),
        ),
      ],
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: materialsAsync.when(
          data: (materials) => _buildMaterialsList(materials),
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, stack) => AppLoadingErrorWidget(
            title: 'خطأ في تحميل المواد الخام',
            message: error.toString(),
            onRetry: () => ref.refresh(materialNotifierProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialsList(List<Material> materials) {
    if (materials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.cube,
              size: 80,
              color: CupertinoColors.systemGrey3,
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد مواد خام',
              style: TextStyle(
                fontSize: 18,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: () => _showAddMaterialDialog(),
              child: const Text('إضافة مادة جديدة'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: materials.length,
      itemBuilder: (context, index) {
        final material = materials[index];
        return _buildMaterialCard(material);
      },
    );
  }

  Widget _buildMaterialCard(Material material) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _getMaterialColor(material.nameAr).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              CupertinoIcons.cube,
              color: _getMaterialColor(material.nameAr),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              material.nameAr,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showEditMaterialDialog(material),
            child: const Icon(
              CupertinoIcons.pencil,
              color: CupertinoColors.activeBlue,
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showDeleteConfirmation(material),
            child: const Icon(
              CupertinoIcons.trash,
              color: CupertinoColors.systemRed,
            ),
          ),
        ],
      ),
    );
  }

  Color _getMaterialColor(String materialName) {
    switch (materialName.toLowerCase()) {
      case 'ذهب':
        return CupertinoColors.systemYellow;
      case 'فضة':
        return CupertinoColors.systemGrey;
      case 'بلاتين':
        return CupertinoColors.systemGrey2;
      default:
        return CupertinoColors.activeBlue;
    }
  }

  void _showAddMaterialDialog() {
    final nameController = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('إضافة مادة خام جديدة'),
        content: Column(
          children: [
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: nameController,
              placeholder: 'اسم المادة الخام',
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
                  final material = Material(nameAr: nameController.text);

                  await ref
                      .read(materialNotifierProvider.notifier)
                      .addMaterial(material);
                  navigator.pop();
                  _showSuccessMessage('تم إضافة المادة بنجاح');
                } catch (error) {
                  _showErrorMessage('خطأ في إضافة المادة: $error');
                }
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showEditMaterialDialog(Material material) {
    final nameController = TextEditingController(text: material.nameAr);

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('تعديل المادة'),
        content: Column(
          children: [
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: nameController,
              placeholder: 'اسم المادة الخام',
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
                  final updatedMaterial = material.copyWith(
                    nameAr: nameController.text,
                  );

                  await ref
                      .read(materialNotifierProvider.notifier)
                      .updateMaterial(updatedMaterial);
                  navigator.pop();
                  _showSuccessMessage('تم تحديث المادة بنجاح');
                } catch (error) {
                  _showErrorMessage('خطأ في تحديث المادة: $error');
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Material material) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('حذف المادة'),
        content: Text('هل أنت متأكد من حذف مادة "${material.nameAr}"؟'),
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
                    .read(materialNotifierProvider.notifier)
                    .deleteMaterial(material.id!);
                navigator.pop();
                _showSuccessMessage('تم حذف المادة بنجاح');
              } catch (error) {
                navigator.pop();
                _showErrorMessage('خطأ في حذف المادة: $error');
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
