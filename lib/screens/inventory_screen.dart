import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import '../widgets/adaptive_scaffold.dart';
import '../models/item.dart';
import '../providers/item_provider.dart';
// import '../providers/category_provider.dart'; // للاستخدام المستقبلي
// import '../providers/material_provider.dart'; // للاستخدام المستقبلي
import '../providers/settings_provider.dart';
import 'add_item_screen.dart';
import 'item_details_screen.dart';
import '../widgets/app_loading_error_widget.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();
  ItemStatus? _selectedStatusFilter;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {}); // Rebuild the UI on search query change
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsProvider);
    final statsAsync = ref.watch(inventoryStatsProvider);

    return AdaptiveScaffold(
      title: 'المخزون',
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (context) => const AddItemScreen()),
            );
          },
          child: const Icon(CupertinoIcons.add),
        ),
      ],
      body: Column(
        children: [
          // إحصائيات المخزون
          _buildStatsSection(statsAsync),
          const SizedBox(height: 16),

          // Search and Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: 'بحث بالـ SKU أو اسم الصنف...',
                ),
                const SizedBox(height: 16),
                _buildStatusFilters(),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // قائمة الأصناف
          Expanded(
            child: itemsAsync.when(
              data: (items) => _buildItemsList(items),
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (error, stack) => AppLoadingErrorWidget(
                title: 'خطأ في تحميل المخزون',
                message: error.toString(),
                onRetry: () => ref.refresh(itemsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(AsyncValue<Map<String, int>> statsAsync) {
    return statsAsync.when(
      data: (stats) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              'إجمالي الأصناف',
              stats.values.fold(0, (sum, count) => sum + count).toString(),
              CupertinoColors.activeBlue,
            ),
            _buildStatItem(
              'يحتاج لبطاقة',
              stats[ItemStatus.needsRfid.name]?.toString() ?? '0',
              CupertinoColors.systemOrange,
            ),
            _buildStatItem(
              'في المخزون',
              stats[ItemStatus.inStock.name]?.toString() ?? '0',
              CupertinoColors.activeGreen,
            ),
            _buildStatItem(
              'مباع',
              stats[ItemStatus.sold.name]?.toString() ?? '0',
              CupertinoColors.systemGrey,
            ),
          ],
        ),
      ),
      loading: () =>
          const SizedBox(height: 80, child: CupertinoActivityIndicator()),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
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

  Widget _buildStatusFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('الكل', null),
          const SizedBox(width: 8),
          ...ItemStatus.values.map(
            (status) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildFilterChip(status.displayName, status),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, ItemStatus? status) {
    final isSelected = _selectedStatusFilter == status;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatusFilter = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? CupertinoColors.activeBlue
              : CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? CupertinoColors.white : CupertinoColors.label,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildItemsList(List<Item> allItems) {
    final searchQuery = _searchController.text.toLowerCase();

    final filteredItems = allItems.where((item) {
      final statusMatches = _selectedStatusFilter == null || item.status == _selectedStatusFilter;
      final searchMatches = searchQuery.isEmpty ||
          item.sku.toLowerCase().contains(searchQuery) ||
          item.rfidTag?.toLowerCase().contains(searchQuery) == true;
      return statusMatches && searchMatches;
    }).toList();

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.cube_box,
              size: 80,
              color: CupertinoColors.systemGrey3,
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد أصناف تطابق البحث',
              style: TextStyle(
                fontSize: 18,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'جرّب تغيير الفلاتر أو مصطلح البحث',
              style: TextStyle(color: CupertinoColors.tertiaryLabel),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => const AddItemScreen(),
                  ),
                );
              },
              child: const Text('إضافة صنف جديد'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return _buildItemCard(item);
      },
    );
  }

  Widget _buildItemCard(Item item) {
    final goldPriceAsync = ref.watch(goldPriceProvider);
    // final categoriesAsync = ref.watch(categoryNotifierProvider); // للاستخدام المستقبلي
    // final materialsAsync = ref.watch(materialNotifierProvider); // للاستخدام المستقبلي

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => ItemDetailsScreen(itemId: item.id!),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.systemGrey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // صورة المنتج أو أيقونة افتراضية
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: item.imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(item.imagePath!),
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.cube_box,
                        color: CupertinoColors.systemGrey3,
                      ),
              ),

              const SizedBox(width: 16),

              // معلومات المنتج
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
                    Row(
                      children: [
                        Text(
                          '${item.weightGrams}g',
                          style: const TextStyle(
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.karat}K',
                          style: const TextStyle(
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    goldPriceAsync.when(
                      data: (goldPrice) => Text(
                        '${item.calculateTotalPrice(goldPrice).toStringAsFixed(2)} د.ل',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.activeGreen,
                        ),
                      ),
                      loading: () => const Text('...'),
                      error: (_, __) => const Text('خطأ في السعر'),
                    ),
                  ],
                ),
              ),

              // حالة RFID
              _buildStatusBadge(item.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ItemStatus status) {
    Color color;
    IconData icon;

    switch (status) {
      case ItemStatus.needsRfid:
        color = CupertinoColors.systemOrange;
        icon = CupertinoIcons.wifi_slash;
        break;
      case ItemStatus.inStock:
        color = CupertinoColors.activeGreen;
        icon = CupertinoIcons.checkmark_circle_fill;
        break;
      case ItemStatus.sold:
        color = CupertinoColors.systemGrey;
        icon = CupertinoIcons.money_dollar_circle;
        break;
      case ItemStatus.reserved:
        color = CupertinoColors.systemYellow;
        icon = CupertinoIcons.clock_fill;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
