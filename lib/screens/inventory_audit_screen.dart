import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'dart:async';

import '../widgets/adaptive_scaffold.dart';
import '../models/item.dart';
import '../providers/item_provider.dart';
import '../services/rfid_service.dart';
import '../providers/rfid_role_reader_provider.dart';
import '../services/rfid_device_assignments.dart'; // RfidRole enum
import '../providers/settings_provider.dart';
import '../providers/material_provider.dart';
import '../widgets/app_button.dart';

class InventoryAuditScreen extends ConsumerStatefulWidget {
  const InventoryAuditScreen({super.key});

  @override
  ConsumerState<InventoryAuditScreen> createState() =>
      _InventoryAuditScreenState();
}

class _InventoryAuditScreenState extends ConsumerState<InventoryAuditScreen> {
  final Set<int> _scannedItemIds = {};
  bool _isScanning = false;
  String? _debugMessage;
  bool _rfidListenerAttached = false;
  RfidServiceReal? _reader;
  StreamSubscription<String>? _tagSub;

  @override
  void dispose() {
    try {
      _reader?.stopScanning();
    } catch (_) {}
    try {
      _tagSub?.cancel();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsProvider);
    final goldPrice = ref.watch(goldPriceProvider);

    // الاستماع لقراءة البطاقات (مرة واحدة)
    if (!_rfidListenerAttached && _reader != null) {
      _rfidListenerAttached = true;
      _tagSub = _reader!.tagStream.listen((tagId) {
        if (_isScanning && tagId.isNotEmpty) {
          setState(() => _debugMessage = 'تم قراءة البطاقة: $tagId');
          _handleScannedTag(tagId);
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() => _debugMessage = null);
            }
          });
        }
      });
    }
    return Container(
      color: Color(0xfff6f8fa), // خلفية موحدة
      child: AdaptiveScaffold(
        title: 'جرد المخزون',
        body: Stack(
          children: [
            Column(
              children: [
                // إحصائيات الجرد
                itemsAsync.when(
                  data: (items) => _buildAuditStats(items, goldPrice),
                  loading: () => const CupertinoActivityIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 16),

                // أزرار التحكم
                _buildControlButtons(),

                const SizedBox(height: 16),

                // قائمة الأصناف
                Expanded(
                  child: itemsAsync.when(
                    data: (items) => _buildItemsList(items),
                    loading: () =>
                        const Center(child: CupertinoActivityIndicator()),
                    error: (error, stack) =>
                        Center(child: Text('خطأ في تحميل البيانات: $error')),
                  ),
                ),
              ],
            ),
            // نافذة تصحيح RFID
            if (_debugMessage != null)
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.activeGreen,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        color: CupertinoColors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _debugMessage!,
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditStats(List<Item> items, double goldPrice) {
    final materialsState = ref.watch(materialNotifierProvider);
    final inStockItems = items
        .where((item) => item.status == ItemStatus.inStock)
        .toList();
    final scannedCount = _scannedItemIds.length;
    final unscannedCount = inStockItems.length - scannedCount;

    final scannedItems = inStockItems
        .where((item) => _scannedItemIds.contains(item.id))
        .toList();
    final mats = materialsState.maybeWhen(
      data: (list) => list,
      orElse: () => null,
    );
    final totalScannedValue = scannedItems.fold<double>(0.0, (sum, item) {
      double? materialPrice;
      if (mats != null) {
        final mat = mats.firstWhere(
          (m) => m.id == item.materialId,
          orElse: () => mats.first,
        );
        if (mat.isVariable) materialPrice = mat.pricePerGram;
      }
      return sum +
          item.calculateTotalPrice(
            goldPrice,
            materialSpecificPrice: materialPrice,
          );
    });

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'تم جردها',
            '$scannedCount',
            CupertinoColors.activeGreen,
          ),
          _buildStatItem(
            'غير مجرودة',
            '$unscannedCount',
            CupertinoColors.systemRed,
          ),
          _buildStatItem(
            'إجمالي التكلفة',
            '${totalScannedValue.toStringAsFixed(2)} د.ل',
            CupertinoColors.activeBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: AppButton.primary(
              text: 'بدء القراءة',
              icon: FluentIcons.play_solid,
              onPressed: !_isScanning ? _startScanning : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AppButton.destructive(
              text: 'إيقاف القراءة',
              icon: FluentIcons.stop_solid,
              onPressed: _isScanning ? _stopScanning : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(List<Item> items) {
    final inStockItems = items
        .where((item) => item.status == ItemStatus.inStock)
        .toList();

    // ترتيب الأصناف: غير المجرودة أولاً، المجرودة في الأسفل
    inStockItems.sort((a, b) {
      final aScanned = _scannedItemIds.contains(a.id);
      final bScanned = _scannedItemIds.contains(b.id);

      if (!aScanned && bScanned) return -1;
      if (aScanned && !bScanned) return 1;
      return a.sku.compareTo(b.sku);
    });

    if (inStockItems.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد أصناف في المخزون للجرد',
          style: TextStyle(fontSize: 18, color: CupertinoColors.secondaryLabel),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: inStockItems.length,
      itemBuilder: (context, index) {
        final item = inStockItems[index];
        final isScanned = _scannedItemIds.contains(item.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isScanned
                  ? CupertinoColors.activeGreen.withValues(alpha: 0.3)
                  : CupertinoColors.systemRed.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.sku,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.weightGrams}g - ${item.karat}K',
                      style: const TextStyle(
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isScanned
                      ? CupertinoColors.activeGreen
                      : CupertinoColors.systemRed,
                ),
                child: Icon(
                  isScanned ? CupertinoIcons.checkmark : CupertinoIcons.xmark,
                  color: CupertinoColors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startScanning() async {
    try {
      if (_reader == null) {
        final r = await ref.read(
          rfidReaderForRoleProvider(RfidRole.inventory).future,
        );
        if (!mounted) return;
        setState(() => _reader = r);
      }
      if (_reader!.currentStatus == RfidReaderStatus.connected ||
          _reader!.currentStatus == RfidReaderStatus.scanning) {
        await _reader!.startScanning();
        setState(() => _isScanning = true);
      } else {
        setState(() => _isScanning = false);
        _debugMessage = 'القارئ (الجرد) غير متصل. عيّن الجهاز من الإعدادات.';
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _stopScanning() async {
    try {
      await _reader?.stopScanning();
    } catch (_) {}
    setState(() {
      _isScanning = false;
    });
  }

  void _handleScannedTag(String tagId) async {
    try {
      final itemRepository = ref.read(itemRepositoryProvider);
      final allItems = await itemRepository.getAllItems();

      final item = allItems.firstWhere(
        (item) => item.rfidTag == tagId && item.status == ItemStatus.inStock,
        orElse: () => Item(
          sku: '',
          categoryId: 0,
          materialId: 0,
          weightGrams: 0,
          karat: 0,
          workmanshipFee: 0,
        ),
      );

      if (item.sku.isNotEmpty && !_scannedItemIds.contains(item.id)) {
        setState(() {
          _scannedItemIds.add(item.id!);
          _debugMessage = 'تم جرد الصنف: ${item.sku}';
        });
      } else if (item.sku.isEmpty) {
        setState(() {
          _debugMessage = 'بطاقة غير مسجلة: $tagId';
        });
      } else {
        setState(() {
          _debugMessage = 'الصنف مجرود مسبقاً: ${item.sku}';
        });
      }
    } catch (e) {
      setState(() {
        _debugMessage = 'خطأ في قراءة البطاقة: $e';
      });
    }
  }
}
