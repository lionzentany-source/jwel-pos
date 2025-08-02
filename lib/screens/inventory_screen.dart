import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Colors, Material, Overlay, OverlayEntry;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io';

import '../widgets/adaptive_scaffold.dart';
import '../models/item.dart';
import '../providers/item_provider.dart';
// import '../providers/category_provider.dart'; // للاستخدام المستقبلي
import '../providers/material_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/rfid_provider.dart';
import '../services/rfid_service.dart';
import '../utils/rfid_duplicate_filter.dart';
import 'add_item_screen.dart';
import 'item_details_screen.dart';
import '../widgets/app_loading_error_widget.dart';
import '../services/sample_data_service.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();
  ItemStatus? _selectedStatusFilter;
  int _selectedTabIndex = 0;

  // لقراءة RFID من لوحة المفاتيح
  String _rfidBuffer = '';
  Timer? _rfidInputTimer;

  // قائمة الأصناف المجردة
  final Set<int> _scannedItems = {};
  bool _isAuditScanning = false;
  bool _enableBeep = true; // تفعيل/تعطيل صوت البيب عند جرد بطاقة ناجحة
  // Focus node to reliably capture keyboard events for wedge RFID scanners
  final FocusNode _keyboardFocusNode = FocusNode();
  // To avoid registering listeners multiple times
  bool _rfidTagListenerRegistered = false;
  bool _rfidStatusListenerRegistered = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {}); // Rebuild the UI on search query change
    });
    // عند الدخول للجرد، أعد تهيئة الجرد والـ RFID
    _scannedItems.clear();
    _rfidBuffer = '';
    _isAuditScanning = false;

    // Defer listener registration to first frame to ensure ref is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _registerRfidListeners();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _rfidInputTimer?.cancel();
    _keyboardFocusNode.dispose();
    // عند الخروج من الجرد، أوقف قراءة RFID وامسح البيانات المؤقتة
    _scannedItems.clear();
    _rfidBuffer = '';
    _isAuditScanning = false;
    ref.read(rfidNotifierProvider.notifier).stopScanning();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listeners now registered once in initState via _registerRfidListeners

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: AdaptiveScaffold(
        title: 'المخزون',
        actions: _selectedTabIndex == 0
            ? [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => const AddItemScreen(),
                      ),
                    );
                  },
                  child: const Icon(CupertinoIcons.add),
                ),
              ]
            : [
                if (_scannedItems.isNotEmpty)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _resetAudit,
                    child: const Icon(CupertinoIcons.refresh),
                  ),
              ],
        body: Column(
          children: [
            // التبويبات
            _buildTabBar(),

            // محتوى التبويب
            Expanded(child: _buildInventoryTab()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: _selectedTabIndex,
        onValueChanged: (value) {
          setState(() {
            _selectedTabIndex = value ?? 0;
          });
          // بدء القراءة تلقائياً عند الانتقال لتبويب الجرد
          if (value == 1) {
            _startAuditScanning();
          } else {
            // عند الخروج من الجرد أوقف كل العمليات المتعلقة بالجرد
            _stopAuditScanning();
            _scannedItems.clear();
          }
        },
        children: const {
          0: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('المخزون'),
          ),
          1: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('الجرد'),
          ),
        },
      ),
    );
  }

  Widget _buildInventoryTab() {
    final itemsAsync = ref.watch(itemsProvider);
    final statsAsync = ref.watch(inventoryStatsProvider);
    final goldPriceAsync = ref.watch(goldPriceProvider);

    if (_selectedTabIndex == 1) {
      // تبويب الجرد الجديد
      return Column(
        children: [
          // إحصائيات الجرد
          itemsAsync.when(
            data: (items) => goldPriceAsync.when(
              data: (goldPrice) => _buildNewAuditStats(items, goldPrice),
              loading: () => const CupertinoActivityIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            loading: () => const CupertinoActivityIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // أزرار التحكم
          _buildAuditControlButtons(),
          const SizedBox(height: 16),

          // قائمة الأصناف للجرد
          Expanded(
            child: itemsAsync.when(
              data: (items) => _buildAuditItemsList(items),
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (error, stack) =>
                  Center(child: Text('خطأ في تحميل البيانات: $error')),
            ),
          ),
        ],
      );
    }

    // تبويب المخزون الأصلي
    return Column(
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
                placeholder: 'بحث بالـ SKU أو بطاقة RFID...',
                onSubmitted: (value) {
                  _scannedItems.clear();
                  _handleSearchSubmit(value);
                },
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
    );
  }

  Widget _buildStatsSection(AsyncValue<Map<String, int>> statsAsync) {
    return statsAsync.when(
      data: (stats) {
        final needsRfid = stats[ItemStatus.needsRfid.name] ?? 0;
        final inStock = stats[ItemStatus.inStock.name] ?? 0;
        final totalAvailable = needsRfid + inStock;

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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'إجمالي الأصناف',
                totalAvailable.toString(),
                CupertinoColors.activeBlue,
              ),
              _buildStatItem(
                'يحتاج لبطاقة',
                needsRfid.toString(),
                CupertinoColors.systemOrange,
              ),
              _buildStatItem(
                'في المخزون',
                inStock.toString(),
                CupertinoColors.activeGreen,
              ),
            ],
          ),
        );
      },
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
      // إخفاء الأصناف المباعة
      if (item.status == ItemStatus.sold) return false;

      final statusMatches =
          _selectedStatusFilter == null || item.status == _selectedStatusFilter;
      final searchMatches =
          searchQuery.isEmpty ||
          item.sku.toLowerCase().contains(searchQuery) ||
          item.rfidTag?.toLowerCase().contains(searchQuery) == true;
      return statusMatches && searchMatches;
    }).toList();

    // ترتيب القائمة: المجردة في الأسفل
    filteredItems.sort((a, b) {
      final aScanned = _scannedItems.contains(a.id);
      final bScanned = _scannedItems.contains(b.id);
      if (aScanned && !bScanned) return 1;
      if (!aScanned && bScanned) return -1;
      return 0;
    });

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
            Text(
              allItems.isEmpty
                  ? 'لا توجد أصناف في المخزون'
                  : 'لا توجد أصناف تطابق البحث',
              style: const TextStyle(
                fontSize: 18,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              allItems.isEmpty
                  ? 'ابدأ بإضافة أصناف جديدة'
                  : 'جرّب تغيير الفلاتر أو مصطلح البحث',
              style: const TextStyle(color: CupertinoColors.tertiaryLabel),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoButton.filled(
                  onPressed: () async {
                    final sampleService = SampleDataService();
                    await sampleService.resetAndAddSampleItems();
                    ref.invalidate(itemsProvider);
                    ref.invalidate(inventoryStatsProvider);
                  },
                  child: const Text('إضافة بيانات تجريبية'),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
    final materialsAsync = ref.watch(materialNotifierProvider);
    final isScanned = _scannedItems.contains(item.id);

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
            color: isScanned
                ? CupertinoColors.systemGreen.withValues(alpha: 0.1)
                : CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(12),
            border: isScanned
                ? Border.all(color: CupertinoColors.systemGreen, width: 2)
                : null,
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
              // صورة المنتج أو أيقونة افتراضية
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Builder(
                  builder: (context) {
                    try {
                      final p = item.imagePath;
                      if (p != null && p.isNotEmpty) {
                        final f = File(p);
                        if (f.existsSync()) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(f, fit: BoxFit.contain),
                          );
                        }
                      }
                    } catch (_) {}
                    return const Icon(
                      CupertinoIcons.cube_box,
                      color: CupertinoColors.systemGrey3,
                    );
                  },
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
                    materialsAsync.when(
                      data: (materials) {
                        final material = materials.firstWhere(
                          (m) => m.id == item.materialId,
                          orElse: () => materials.first,
                        );
                        return Text(
                          material.nameAr,
                          style: const TextStyle(
                            color: CupertinoColors.activeBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 2),
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
                      data: (goldPrice) {
                        double? materialPrice;
                        final mats = materialsAsync.valueOrNull;
                        if (mats != null) {
                          final mat = mats.firstWhere(
                            (m) => m.id == item.materialId,
                            orElse: () => mats.first,
                          );
                          if (mat.isVariable) materialPrice = mat.pricePerGram;
                        }
                        return Text(
                          '${item.calculateTotalPrice(goldPrice, materialSpecificPrice: materialPrice).toStringAsFixed(2)} د.ل',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.activeGreen,
                          ),
                        );
                      },
                      loading: () => const Text('...'),
                      error: (_, __) => const Text('خطأ في السعر'),
                    ),
                  ],
                ),
              ),

              // علامة الجرد أو حالة RFID
              isScanned
                  ? const Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: CupertinoColors.systemGreen,
                      size: 24,
                    )
                  : _buildStatusBadge(item.status),
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

  /// معالجة ضغطات لوحة المفاتيح لقراءة RFID
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;

      // إذا كان Enter أو Return
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        if (_rfidBuffer.isNotEmpty && _rfidBuffer.length >= 8) {
          // معالجة بطاقة RFID
          final tagId = _rfidBuffer.trim();
          debugPrint('📡 تم قراءة بطاقة RFID من لوحة المفاتيح: $tagId');

          // في تبويب الجرد
          if (_selectedTabIndex == 1) {
            _handleAuditRfidTag(tagId);
          }
          // في تبويب المخزون
          else if (_selectedTabIndex == 0) {
            _handleRfidTag(tagId);
          }
          _rfidBuffer = '';
          _rfidInputTimer?.cancel();
        }
        return;
      }

      // تجاهل مفاتيح التحكم
      if (key == LogicalKeyboardKey.shiftLeft ||
          key == LogicalKeyboardKey.shiftRight ||
          key == LogicalKeyboardKey.controlLeft ||
          key == LogicalKeyboardKey.controlRight ||
          key == LogicalKeyboardKey.altLeft ||
          key == LogicalKeyboardKey.altRight) {
        return;
      }

      // إضافة الحرف إلى الbuffer
      final character = event.character;
      if (character != null &&
          character.isNotEmpty &&
          character != '\n' &&
          character != '\r') {
        _rfidBuffer += character;
        debugPrint('📝 RFID Buffer: $_rfidBuffer');

        // إعادة تعيين مؤقت مسح الbuffer
        _rfidInputTimer?.cancel();
        _rfidInputTimer = Timer(const Duration(milliseconds: 500), () {
          if (_rfidBuffer.length < 8) {
            debugPrint('🗑️ مسح RFID Buffer: $_rfidBuffer');
            _rfidBuffer = ''; // مسح إذا لم يكتمل في الوقت المحدد
          }
        });
      }
    }
  }

  /// معالجة بطاقة RFID في الجرد
  Future<void> _handleRfidTag(String tagId) async {
    if (!RfidDuplicateFilter.shouldProcess(tagId)) {
      debugPrint('🔁 تجاهل بطاقة مكررة (مخزون): $tagId');
      return;
    }
    try {
      debugPrint('📡 تم قراءة بطاقة RFID في الجرد: $tagId');

      // الحصول على الأصناف من المزود
      final itemRepository = ref.read(itemRepositoryProvider);
      final allItems = await itemRepository.getAllItems();
      if (!mounted) return;

      // البحث عن الصنف ببطاقة RFID
      final item = allItems.where((i) => i.rfidTag == tagId).firstOrNull;

      if (item != null &&
          (item.status == ItemStatus.inStock ||
              item.status == ItemStatus.needsRfid)) {
        // التحقق من عدم وجود الصنف في قائمة المجردة
        if (!_scannedItems.contains(item.id!)) {
          setState(() {
            _scannedItems.add(item.id!);
          });
          debugPrint('✅ تم جرد الصنف: ${item.sku}');

          // عرض رسالة نجاح سريعة
          _showSuccessMessage('تم جرد الصنف: ${item.sku}');
        } else {
          debugPrint('⚠️ الصنف ${item.sku} تم جرده بالفعل');
          _showWarningMessage('الصنف ${item.sku} تم جرده بالفعل');
        }
      } else if (item != null && item.status == ItemStatus.sold) {
        debugPrint('⚠️ الصنف ${item.sku} مباع بالفعل');
        _showWarningMessage('الصنف ${item.sku} مباع بالفعل');
      } else {
        debugPrint('❌ لم يتم العثور على صنف ببطاقة RFID: $tagId');
        _showNotFoundDialog(tagId);
      }
    } catch (e) {
      debugPrint('❌ خطأ في معالجة بطاقة RFID: $e');
      _showErrorMessage('خطأ في قراءة البطاقة');
    }
  }

  /// معالجة البحث اليدوي
  Future<void> _handleSearchSubmit(String query) async {
    if (query.trim().isNotEmpty) {
      // بحث فقط بدون تنفيذ عملية جرد
      final itemRepository = ref.read(itemRepositoryProvider);
      final allItems = await itemRepository.getAllItems();
      if (!mounted) return;
      final q = query.trim().toLowerCase();
      final found = allItems.where(
        (i) => i.sku.toLowerCase() == q || (i.rfidTag?.toLowerCase() == q),
      );
      if (found.isEmpty) {
        _showWarningMessage('لا يوجد صنف مطابق');
      } else {
        // تمرير البحث إلى حقل البحث العادي لتصفية القائمة
        setState(() {
          _searchController.text = query.trim();
        });
      }
      FocusScope.of(context).unfocus();
    }
  }

  /// عرض رسالة نجاح سريعة
  void _showSuccessMessage(String message) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 100,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.activeGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  color: CupertinoColors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
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
      ),
    );

    overlay.insert(overlayEntry);

    // إزالة الرسالة بعد ثانيتين
    Timer(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  /// عرض رسالة تحذير سريعة
  void _showWarningMessage(String message) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 100,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemOrange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: CupertinoColors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
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
      ),
    );

    overlay.insert(overlayEntry);

    // إزالة الرسالة بعد ثانيتين
    Timer(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  /// عرض رسالة خطأ سريعة
  void _showErrorMessage(String message) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 100,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemRed,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: CupertinoColors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
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
      ),
    );

    overlay.insert(overlayEntry);

    // إزالة الرسالة بعد ثانيتين
    Timer(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  /// عرض رسالة عدم وجود الصنف
  void _showNotFoundDialog(String tagId) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('لم يتم العثور على الصنف'),
        content: Text('لم يتم العثور على صنف ببطاقة RFID:\n$tagId'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  /// إعادة تعيين الجرد
  void _resetAudit() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('إعادة تعيين الجرد'),
        content: Text(
          'هل أنت متأكد من إعادة تعيين جرد ${_scannedItems.length} صنف؟',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              setState(() {
                _scannedItems.clear();
              });
              Navigator.pop(context);
              _showSuccessMessage('تم إعادة تعيين الجرد');
            },
            child: const Text('إعادة تعيين'),
          ),
        ],
      ),
    );
  }

  /// إحصائيات الجرد الجديدة
  Widget _buildNewAuditStats(List<Item> items, double goldPrice) {
    // الأصناف القابلة للجرد: في المخزون + يحتاج بطاقة
    final auditableItems = items
        .where(
          (item) =>
              item.status == ItemStatus.inStock ||
              item.status == ItemStatus.needsRfid,
        )
        .toList();
    final scannedCount = _scannedItems.length;
    final unscannedCount = auditableItems.length - scannedCount;

    final scannedItems = auditableItems
        .where((item) => _scannedItems.contains(item.id))
        .toList();
    final materials = ref.read(materialNotifierProvider).maybeWhen(
          data: (list) => list,
          orElse: () => null,
        );
    final totalScannedValue = scannedItems.fold<double>(0.0, (sum, item) {
      double? materialPrice;
      if (materials != null) {
        final mat = materials.firstWhere(
          (m) => m.id == item.materialId,
          orElse: () => materials.first,
        );
        if (mat.isVariable) materialPrice = mat.pricePerGram;
      }
      return sum + item.calculateTotalPrice(goldPrice, materialSpecificPrice: materialPrice);
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

  /// أزرار تحكم الجرد
  Widget _buildAuditControlButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: () {
              setState(() {
                _enableBeep = !_enableBeep;
              });
            },
            child: Row(
              children: [
                Icon(
                  _enableBeep
                      ? CupertinoIcons.speaker_2_fill
                      : CupertinoIcons.speaker_slash_fill,
                  color: _enableBeep
                      ? CupertinoColors.activeGreen
                      : CupertinoColors.inactiveGray,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  _enableBeep ? 'صوت مفعل' : 'صوت مطفأ',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: CupertinoButton.filled(
              onPressed: !_isAuditScanning ? _startAuditScanning : null,
              child: const Text('بدء القراءة'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: CupertinoButton(
              color: CupertinoColors.systemRed,
              onPressed: _isAuditScanning ? _stopAuditScanning : null,
              child: const Text('إيقاف القراءة'),
            ),
          ),
        ],
      ),
    );
  }

  /// قائمة الأصناف للجرد
  Widget _buildAuditItemsList(List<Item> items) {
    final auditableItems = items
        .where(
          (item) =>
              item.status == ItemStatus.inStock ||
              item.status == ItemStatus.needsRfid,
        )
        .toList();
    final scannedItemsList = auditableItems
        .where((item) => _scannedItems.contains(item.id))
        .toList();
    final unscannedItemsList = auditableItems
        .where((item) => !_scannedItems.contains(item.id))
        .toList();

    // جمع القوائم: غير مجرودة أولاً ثم مجرودة
    final allItemsList = [...unscannedItemsList, ...scannedItemsList];

    if (allItemsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.barcode_viewfinder,
              size: 80,
              color: CupertinoColors.systemGrey3,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد أصناف في المخزون للجرد',
              style: const TextStyle(
                fontSize: 18,
                color: CupertinoColors.secondaryLabel,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: allItemsList.length,
      itemBuilder: (context, index) {
        final item = allItemsList[index];
        final isScanned = _scannedItems.contains(item.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isScanned
                ? CupertinoColors.activeGreen.withValues(alpha: 0.1)
                : CupertinoColors.systemRed.withValues(alpha: 0.05),
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
              const SizedBox(width: 16),
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
                    if (item.rfidTag != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'RFID: ${item.rfidTag}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.tertiaryLabel,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isScanned)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _scannedItems.remove(item.id);
                    });
                  },
                  child: Icon(
                    CupertinoIcons.minus_circle_fill,
                    color: CupertinoColors.systemRed,
                    size: 24,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// بدء قراءة الجرد
  Future<void> _startAuditScanning() async {
    try {
      debugPrint('🚀 بدء قراءة الجرد...');
      if (mounted) {
        setState(() => _isAuditScanning = true);
      }

      // اختبار الاتصال
      debugPrint('🔌 محاولة الاتصال...');
      await ref.read(rfidNotifierProvider.notifier).connect();
      if (!mounted) return; // widget may have been disposed while awaiting

      // بدء المسح
      debugPrint('🔍 بدء المسح...');
      await ref.read(rfidNotifierProvider.notifier).startScanning();
      if (!mounted) return;

      debugPrint('✅ تم بدء قراءة الجرد (وضع المسح المستمر بدون اختبار مفرد)');
    } catch (e) {
      debugPrint('❌ خطأ في بدء القراءة: $e');
      if (mounted) {
        setState(() => _isAuditScanning = false);
      }
    }
  }

  /// إيقاف قراءة الجرد
  Future<void> _stopAuditScanning() async {
    try {
      await ref.read(rfidNotifierProvider.notifier).stopScanning();
      if (mounted) {
        setState(() => _isAuditScanning = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAuditScanning = false);
      }
    }
  }

  /// معالجة بطاقة RFID في الجرد
  Future<void> _handleAuditRfidTag(String tagId) async {
    if (!RfidDuplicateFilter.shouldProcess(tagId)) {
      debugPrint('🔁 تجاهل بطاقة مكررة (جرد تدقيقي): $tagId');
      return;
    }
    try {
      debugPrint('📱 تم قراءة بطاقة RFID في الجرد: $tagId');
      final itemRepository = ref.read(itemRepositoryProvider);
      final item = await itemRepository.getItemByRfidTag(tagId);
      if (!mounted) return;

      if (item != null &&
          (item.status == ItemStatus.inStock ||
              item.status == ItemStatus.needsRfid)) {
        if (!_scannedItems.contains(item.id)) {
          setState(() => _scannedItems.add(item.id!));
          debugPrint('✅ تم جرد الصنف: ${item.sku}');
          if (_enableBeep) {
            ref.read(rfidNotifierProvider.notifier).playBeep();
          }
        } else {
          debugPrint('⚠️ الصنف ${item.sku} تم جرده بالفعل (تجاهل)');
        }
      } else if (item != null && item.status == ItemStatus.sold) {
        debugPrint('⚠️ الصنف ${item.sku} مباع – تم تجاهله');
      } else {
        debugPrint('❌ بطاقة غير معروفة: $tagId');
      }
    } catch (e) {
      debugPrint('❌ خطأ في قراءة البطاقة: $e');
    }
  }

  void _registerRfidListeners() {
    if (!_rfidTagListenerRegistered) {
      _rfidTagListenerRegistered = true;
      ref.listen<AsyncValue<String>>(rfidTagProvider, (previous, next) {
        if (!mounted) return;
        debugPrint('🔍 RFID Provider State: ${next.toString()}');
        next.when(
          data: (tagId) {
            debugPrint(
              '📱 RFID Tag received: "$tagId", Length: ${tagId.length}, Tab: $_selectedTabIndex, Scanning: $_isAuditScanning',
            );
            if (_selectedTabIndex == 1 &&
                _isAuditScanning &&
                tagId.isNotEmpty) {
              _handleAuditRfidTag(tagId);
            } else if (_selectedTabIndex == 0 && tagId.isNotEmpty) {
              // Allow inventory tab key-based tag processing as search (optional)
              _handleRfidTag(tagId);
            }
          },
          loading: () => debugPrint('⏳ RFID Provider Loading...'),
          error: (error, stack) => debugPrint('❌ RFID Provider Error: $error'),
        );
      });
    }
    if (!_rfidStatusListenerRegistered) {
      _rfidStatusListenerRegistered = true;
      ref.listen<AsyncValue<RfidReaderStatus>>(rfidNotifierProvider, (
        previous,
        next,
      ) {
        if (!mounted) return;
        next.when(
          data: (status) => debugPrint('🔌 RFID Status: $status'),
          loading: () => debugPrint('⏳ RFID Status Loading...'),
          error: (error, stack) => debugPrint('❌ RFID Status Error: $error'),
        );
      });
    }
  }
}
