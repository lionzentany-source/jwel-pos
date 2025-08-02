import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import '../widgets/adaptive_scaffold.dart';
import '../models/item.dart';
import '../providers/item_provider.dart';
import '../providers/category_provider.dart';
import '../providers/material_provider.dart';
import '../providers/settings_provider.dart';
import 'link_rfid_screen.dart';
import 'edit_item_screen.dart';

class ItemDetailsScreen extends ConsumerStatefulWidget {
  final int itemId;

  const ItemDetailsScreen({super.key, required this.itemId});

  @override
  ConsumerState<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends ConsumerState<ItemDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemByIdProvider(widget.itemId));
    final goldPriceAsync = ref.watch(goldPriceProvider);

    return itemAsync.when(
      data: (item) {
        if (item == null) {
          return AdaptiveScaffold(
            title: 'تفاصيل الصنف',
            body: const Center(child: Text('الصنف غير موجود')),
          );
        }

        return AdaptiveScaffold(
          title: 'تفاصيل الصنف',
          actions: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showOptionsMenu(context, item),
              child: const Icon(CupertinoIcons.ellipsis),
            ),
          ],
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // صورة المنتج
                _buildImageSection(item),

                const SizedBox(height: 20),

                // معلومات أساسية
                _buildInfoCard('معلومات أساسية', [
                  _buildInfoRow('رقم الصنف', item.sku),
                  _buildInfoRow('الوزن', '${item.weightGrams} جرام'),
                  _buildInfoRow('العيار', '${item.karat} قيراط'),
                  _buildInfoRow('المصنعية', '${item.workmanshipFee} د.ل'),
                  if (item.stonePrice > 0)
                    _buildInfoRow('سعر الأحجار', '${item.stonePrice} د.ل'),
                ]),

                const SizedBox(height: 16),

                // معلومات الفئة والمادة
                _buildCategoryMaterialInfo(ref, item),

                const SizedBox(height: 16),

                // السعر
                goldPriceAsync.when(
                  data: (goldPrice) => _buildPriceCard(item, goldPrice),
                  loading: () => const CupertinoActivityIndicator(),
                  error: (error, stack) => _buildInfoCard('السعر', [
                    _buildInfoRow('خطأ', 'لا يمكن حساب السعر'),
                  ]),
                ),

                const SizedBox(height: 16),

                // حالة RFID
                _buildRfidStatusCard(context, ref, item),

                const SizedBox(height: 16),

                // معلومات إضافية
                _buildInfoCard('معلومات إضافية', [
                  _buildInfoRow('الحالة', item.status.displayName),
                  _buildInfoRow('تاريخ الإضافة', _formatDate(item.createdAt)),
                ]),
              ],
            ),
          ),
        );
      },
      loading: () => AdaptiveScaffold(
        title: 'تفاصيل الصنف',
        body: const Center(child: CupertinoActivityIndicator()),
      ),
      error: (error, stack) => AdaptiveScaffold(
        title: 'تفاصيل الصنف',
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 50,
                color: CupertinoColors.systemRed,
              ),
              const SizedBox(height: 16),
              Text('خطأ في تحميل البيانات: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(Item item) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Builder(
        builder: (context) {
          try {
            final p = item.imagePath;
            if (p != null && p.isNotEmpty) {
              final f = File(p);
              if (f.existsSync()) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    f,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                );
              }
            }
          } catch (_) {}
          return const Center(
            child: Icon(
              CupertinoIcons.cube_box,
              size: 80,
              color: CupertinoColors.systemGrey3,
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: CupertinoColors.secondaryLabel),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildCategoryMaterialInfo(WidgetRef ref, Item item) {
    final categoryAsync = ref.watch(categoryByIdProvider(item.categoryId));
    final materialAsync = ref.watch(materialByIdProvider(item.materialId));

    return _buildInfoCard('الفئة والمادة', [
      categoryAsync.when(
        data: (category) =>
            _buildInfoRow('الفئة', category?.nameAr ?? 'غير محدد'),
        loading: () => _buildInfoRow('الفئة', '...'),
        error: (_, __) => _buildInfoRow('الفئة', 'خطأ'),
      ),
      materialAsync.when(
        data: (material) =>
            _buildInfoRow('المادة', material?.nameAr ?? 'غير محدد'),
        loading: () => _buildInfoRow('المادة', '...'),
        error: (_, __) => _buildInfoRow('المادة', 'خطأ'),
      ),
    ]);
  }

  Widget _buildPriceCard(Item item, double goldPrice) {
    // الحصول على سعر المادة الخاص إن وجد
    double? materialPrice;
    final materials = ref.watch(materialNotifierProvider).maybeWhen(
          data: (list) => list,
          orElse: () => null,
        );
    if (materials != null) {
      final mat = materials.firstWhere(
        (m) => m.id == item.materialId,
        orElse: () => materials.first,
      );
      if (mat.isVariable) materialPrice = mat.pricePerGram;
    }
  final totalPrice = item.calculateTotalPrice(goldPrice, materialSpecificPrice: materialPrice);
  final baseMaterialPrice = item.weightGrams * (materialPrice ?? goldPrice);

    return _buildInfoCard('تفاصيل السعر', [
      _buildInfoRow(
        'سعر المادة الخام',
  '${baseMaterialPrice.toStringAsFixed(2)} د.ل',
      ),
      _buildInfoRow('المصنعية', '${item.workmanshipFee} د.ل'),
      if (item.stonePrice > 0)
        _buildInfoRow('سعر الأحجار', '${item.stonePrice} د.ل'),
      Container(
        height: 1,
        color: CupertinoColors.separator,
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'السعر الإجمالي',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            '${totalPrice.toStringAsFixed(2)} د.ل',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.activeGreen,
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _buildRfidStatusCard(BuildContext context, WidgetRef ref, Item item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: item.status == ItemStatus.needsRfid
            ? CupertinoColors.systemOrange.withValues(alpha: 0.1)
            : CupertinoColors.activeGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.status == ItemStatus.needsRfid
              ? CupertinoColors.systemOrange
              : CupertinoColors.activeGreen,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.status == ItemStatus.needsRfid
                    ? CupertinoIcons.wifi_slash
                    : CupertinoIcons.checkmark_circle_fill,
                color: item.status == ItemStatus.needsRfid
                    ? CupertinoColors.systemOrange
                    : CupertinoColors.activeGreen,
              ),
              const SizedBox(width: 8),
              Text(
                'حالة RFID',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: item.status == ItemStatus.needsRfid
                      ? CupertinoColors.systemOrange
                      : CupertinoColors.activeGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.status == ItemStatus.needsRfid
                ? 'هذا الصنف يحتاج لربط بطاقة RFID'
                : 'تم ربط بطاقة RFID بنجاح',
            style: const TextStyle(color: CupertinoColors.secondaryLabel),
          ),
          if (item.rfidTag != null) ...[
            const SizedBox(height: 8),
            Text(
              'رقم البطاقة: ${item.rfidTag}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
          if (item.status == ItemStatus.needsRfid) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => LinkRfidScreen(item: item),
                    ),
                  ).then((_) {
                    ref.invalidate(itemByIdProvider(widget.itemId));
                  });
                },
                child: const Text('ربط بطاقة RFID'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showOptionsMenu(BuildContext context, Item item) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('خيارات الصنف'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => EditItemScreen(item: item),
                ),
              ).then((_) {
                ref.invalidate(itemByIdProvider(widget.itemId));
              });
            },
            child: const Text('تعديل'),
          ),
          if (item.status == ItemStatus.needsRfid)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => LinkRfidScreen(item: item),
                  ),
                ).then((_) {
                  ref.invalidate(itemByIdProvider(widget.itemId));
                });
              },
              child: const Text('ربط بطاقة RFID'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
      ),
    );
  }
}
