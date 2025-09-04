import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/material.dart' as local;
import '../providers/material_provider.dart';
import '../widgets/adaptive_scaffold.dart';

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
    final theme = FluentTheme.of(context);

    return AdaptiveScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      title: 'إدارة المواد الخام',
      // لا يوجد زر رجوع في الأعلى
      commandBarItems: [
        CommandBarButton(
          icon: const Icon(FluentIcons.add, size: 20),
          label: const Text(
            'إضافة',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          onPressed: _showAddMaterialDialog,
        ),
      ],
      showBackButton: false,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: materialsAsync.when(
          data: (materials) => _buildMaterialsList(materials),
          loading: () =>
              Center(child: ProgressRing(activeColor: theme.accentColor)),
          error: (error, stack) => Center(
            child: Text(
              'خطأ في تحميل المواد الخام: $error',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialsList(List<local.Material> materials) {
    final theme = FluentTheme.of(context);
    if (materials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FluentIcons.folder_open,
              size: 80,
              color: theme.accentColor.lighter,
            ),
            const SizedBox(height: 16),
            const Text('لا توجد مواد خام', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            AdaptiveButton(
              text: 'إضافة مادة جديدة',
              onPressed: _showAddMaterialDialog,
              icon: FluentIcons.add,
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

  Widget _buildMaterialCard(local.Material material) {
    final theme = FluentTheme.of(context);
    return AdaptiveCard(
      onTap: () => _showEditMaterialDialog(material),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: theme.accentColor.lighter.withAlpha(51),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(FluentIcons.product, color: theme.accentColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AdaptiveText(
              material.nameAr,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 16),
          if (material.isVariable)
            AdaptiveText(
              '${material.pricePerGram} / جرام',
              style: TextStyle(
                fontSize: 14,
                color: theme.typography.body?.color?.withAlpha(179),
              ),
            ),
          const Spacer(),
          AdaptiveButton(
            text: 'تعديل',
            onPressed: () => _showEditMaterialDialog(material),
            icon: FluentIcons.edit,
          ),
          const SizedBox(width: 8),
          AdaptiveButton(
            text: 'حذف',
            onPressed: () => _showDeleteConfirmation(material),
            isDestructive: true,
            icon: FluentIcons.delete,
          ),
        ],
      ),
    );
  }

  void _showAddMaterialDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    bool isVariable = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setStateSB) => ContentDialog(
          title: const Text('إضافة مادة خام جديدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              TextBox(
                controller: nameController,
                placeholder: 'اسم المادة الخام',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text('سعر متغير؟', style: TextStyle(fontSize: 14)),
                  ),
                  ToggleSwitch(
                    checked: isVariable,
                    onChanged: (v) => setStateSB(() {
                      isVariable = v;
                    }),
                  ),
                ],
              ),
              if (isVariable) ...[
                const SizedBox(height: 8),
                TextBox(
                  controller: priceController,
                  placeholder: 'سعر الجرام',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            Button(
              child: const Text('إلغاء'),
              onPressed: () => Navigator.pop(context),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final navigator = Navigator.of(context);
                  try {
                    final material = local.Material(
                      nameAr: nameController.text,
                      isVariable: isVariable,
                      pricePerGram: isVariable
                          ? double.tryParse(priceController.text) ?? 0
                          : 0,
                    );
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
      ),
    );
  }

  void _showEditMaterialDialog(local.Material material) {
    final nameController = TextEditingController(text: material.nameAr);
    final priceController = TextEditingController(
      text: material.isVariable ? material.pricePerGram.toString() : '',
    );
    bool isVariable = material.isVariable;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setStateSB) => ContentDialog(
          title: const Text('تعديل المادة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              TextBox(
                controller: nameController,
                placeholder: 'اسم المادة الخام',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text('سعر متغير؟', style: TextStyle(fontSize: 14)),
                  ),
                  ToggleSwitch(
                    checked: isVariable,
                    onChanged: (v) => setStateSB(() {
                      isVariable = v;
                    }),
                  ),
                ],
              ),
              if (isVariable) ...[
                const SizedBox(height: 8),
                TextBox(
                  controller: priceController,
                  placeholder: 'سعر الجرام',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            Button(
              child: const Text('إلغاء'),
              onPressed: () => Navigator.pop(context),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final navigator = Navigator.of(context);
                  try {
                    final updatedMaterial = material.copyWith(
                      nameAr: nameController.text,
                      isVariable: isVariable,
                      pricePerGram: isVariable
                          ? double.tryParse(priceController.text) ??
                                material.pricePerGram
                          : 0,
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
      ),
    );
  }

  void _showDeleteConfirmation(local.Material material) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('حذف المادة'),
        content: Text('هل أنت متأكد من حذف مادة "${material.nameAr}"؟'),
        actions: [
          Button(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(context),
          ),
          AdaptiveButton(
            text: 'حذف',
            isDestructive: true,
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
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
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

  void _showErrorMessage(String message) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('خطأ'),
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
