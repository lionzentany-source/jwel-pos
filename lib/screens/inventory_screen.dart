import 'package:flutter/cupertino.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as m show Material;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io';

import '../widgets/adaptive_scaffold.dart';
import '../models/item.dart';
import '../providers/item_provider.dart';
import '../providers/category_provider.dart';
import '../models/category.dart';
// import '../providers/category_provider.dart'; // للاستخدام المستقبلي
import '../providers/material_provider.dart';
import '../providers/settings_provider.dart';
import '../services/rfid_service.dart';
import '../providers/rfid_role_reader_provider.dart';
import '../services/rfid_device_assignments.dart';
import '../utils/rfid_duplicate_filter.dart';
import 'add_item_screen.dart';
import '../widgets/side_sheet.dart';
import 'item_details_screen.dart';
import '../widgets/app_loading_error_widget.dart';
import '../services/sample_data_service.dart';
import '../widgets/app_button.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();
  ItemStatus? _selectedStatusFilter;
  ItemLocation? _selectedLocationFilter;
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
  // تمت إزالة أعلام التسجيل اليدوي – سيتم استخدام ref.listen داخل build وفق توصيات Riverpod
  bool _rfidListenersAttached = false; // منع التكرار والتسريبات
  // قارئ دور الجرد
  RfidServiceReal? _inventoryReader;
  StreamSubscription<String>? _inventoryTagSub;
  StreamSubscription<RfidReaderStatus>? _inventoryStatusSub;
  // حالة القارئ غير مطلوبة للعرض حالياً
  String? _inventoryDeviceLabel;

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

    // لم نعد نسجل المستمعين هنا لتفادي مخالفة: ref.listen can only be used within build
  }

  @override
  void dispose() {
    _searchController.dispose();
    _rfidInputTimer?.cancel();
    _keyboardFocusNode.dispose();
    try {
      _inventoryReader?.stopScanning();
    } catch (_) {}
    try {
      _inventoryTagSub?.cancel();
    } catch (_) {}
    try {
      _inventoryStatusSub?.cancel();
    } catch (_) {}
    // عند الخروج من الجرد، أوقف قراءة RFID وامسح البيانات المؤقتة
    _scannedItems.clear();
    _rfidBuffer = '';
    _isAuditScanning = false;
    // تجنب استخدام ref مباشرة بعد بدء عملية التخلص
    // جدولة الإيقاف في إطار لاحق إذا كان المزود ما يزال صالحاً
    // لم يعد هناك استدعاء لموفر قديم هنا
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wedgeEnabled = ref.watch(posKeyboardWedgeEnabledProvider);
    // تسجيل المستمعين مرة واحدة فقط
    if (!_rfidListenersAttached) {
      _rfidListenersAttached = true;
      // سيتم توصيل قارئ الجرد عند تفعيل تبويب الجرد وبدء القراءة
    }

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: wedgeEnabled.maybeWhen(data: (v) => v, orElse: () => true),
      onKeyEvent: (event) {
        final enabled = wedgeEnabled.maybeWhen(
          data: (v) => v,
          orElse: () => true,
        );
        if (!enabled) return;
        _handleKeyEvent(event);
      },
      child: Container(
        color: Color(0xfff6f8fa), // خلفية موحدة
        child: AdaptiveScaffold(
          // عنوان في المنتصف
          titleWidget: Center(
            child: Text(
              'المخزون',
              style: FluentTheme.of(context).typography.title,
            ),
          ),
          // زر الجرد يسار العنوان
          leading: Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: ToggleSwitch(
              checked: _selectedTabIndex == 1,
              onChanged: (v) {
                setState(() => _selectedTabIndex = v ? 1 : 0);
                if (v) {
                  _startAuditScanning();
                } else {
                  _stopAuditScanning();
                  _scannedItems.clear();
                }
              },
              content: const Text('الجرد'),
              leadingContent: true,
            ),
          ),
          // إضافة يمين شريط العنوان
          commandBarItems: [
            if (_selectedTabIndex == 0)
              CommandBarButton(
                icon: const Icon(FluentIcons.add, size: 20),
                label: const Text(
                  'إضافة',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  showSideSheet(
                    context,
                    child: const AddItemScreen(),
                    width: 560,
                  );
                },
              )
            else if (_scannedItems.isNotEmpty)
              CommandBarButton(
                icon: const Icon(FluentIcons.refresh, size: 20),
                label: const Text(
                  'إعادة تعيين',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                onPressed: _resetAudit,
              ),
          ],
          body: Column(
            children: [
              // محتوى التبويب
              Expanded(child: _buildInventoryTab()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryTab() {
    final itemsAsync = ref.watch(itemsProvider);
    final statsAsync = ref.watch(inventoryStatsProvider);
    final goldPrice = ref.watch(goldPriceProvider);

    if (_selectedTabIndex == 1) {
      // تبويب الجرد الجديد
      return Column(
        children: [
          // إحصائيات الجرد
          itemsAsync.when(
            data: (items) => _buildNewAuditStats(items, goldPrice),
            loading: () => const ProgressRing(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // أزرار التحكم
          _buildAuditControlButtons(),
          if (_inventoryDeviceLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'قارئ الجرد: ${_inventoryDeviceLabel!}',
                style: FluentTheme.of(context).typography.caption,
              ),
            ),
          const SizedBox(height: 16),

          // قائمة الأصناف للجرد
          Expanded(
            child: itemsAsync.when(
              data: (items) => _buildAuditItemsList(items),
              loading: () => const Center(child: ProgressRing()),
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
              TextBox(
                controller: _searchController,
                placeholder: 'بحث بالـ SKU أو بطاقة RFID... (اضغط Enter)',
                onSubmitted: (value) {
                  _scannedItems.clear();
                  _handleSearchSubmit(value);
                },
              ),
              const SizedBox(height: 16),
              _buildStatusFilters(),
              const SizedBox(height: 10),
              _buildLocationFilters(),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // قائمة الأصناف
        Expanded(
          child: itemsAsync.when(
            data: (items) => _buildItemsList(items),
            loading: () => const Center(child: ProgressRing()),
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

        return AdaptiveCard(
          padding: const EdgeInsets.all(16),
          backgroundColor: Color(0xFFF6F8FA),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'إجمالي الأصناف',
                totalAvailable.toString(),
                Color(0xFF0078D4),
              ),
              _buildStatItem(
                'يحتاج لبطاقة',
                needsRfid.toString(),
                Color(0xFFFFA500),
              ),
              _buildStatItem(
                'في المخزون',
                inStock.toString(),
                Color(0xFF22C55E),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 80, child: ProgressRing()),
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
          style: FluentTheme.of(context).typography.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatusFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: 8,
        children: [
          _buildFilterChip('الكل', null),
          ...ItemStatus.values.map(
            (status) => _buildFilterChip(status.displayName, status),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: 8,
        children: [
          _buildLocationChip('كل الأماكن', null),
          ...ItemLocation.values.map(
            (loc) => _buildLocationChip(loc.displayName, loc),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationChip(String label, ItemLocation? loc) {
    final isSelected = _selectedLocationFilter == loc;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLocationFilter = loc;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? FluentTheme.of(context).accentColor
              : FluentTheme.of(context).resources.controlAltFillColorSecondary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : FluentTheme.of(context).resources.textFillColorPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
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
              ? FluentTheme.of(context).accentColor
              : FluentTheme.of(context).resources.controlAltFillColorSecondary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : FluentTheme.of(context).resources.textFillColorPrimary,
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
      final locationMatches =
          _selectedLocationFilter == null ||
          item.location == _selectedLocationFilter;
      final searchMatches =
          searchQuery.isEmpty ||
          item.sku.toLowerCase().contains(searchQuery) ||
          item.rfidTag?.toLowerCase().contains(searchQuery) == true;
      return statusMatches && locationMatches && searchMatches;
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
            Icon(
              FluentIcons.cube_shape,
              size: 80,
              color: FluentTheme.of(context).inactiveColor,
            ),
            const SizedBox(height: 16),
            Text(
              allItems.isEmpty
                  ? 'لا توجد أصناف في المخزون'
                  : 'لا توجد أصناف تطابق البحث',
              style: FluentTheme.of(context).typography.subtitle,
            ),
            const SizedBox(height: 8),
            Text(
              allItems.isEmpty
                  ? 'ابدأ بإضافة أصناف جديدة'
                  : 'جرّب تغيير الفلاتر أو مصطلح البحث',
              style: FluentTheme.of(context).typography.caption,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppButton.secondary(
                  text: 'إضافة بيانات تجريبية',
                  icon: FluentIcons.database,
                  onPressed: () async {
                    final sampleService = SampleDataService();
                    await sampleService.resetAndAddSampleItems();
                    ref.invalidate(itemsProvider);
                    ref.invalidate(inventoryStatsProvider);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppButton.primary(
              text: 'إضافة صنف جديد',
              icon: FluentIcons.add,
              onPressed: () {
                showSideSheet(
                  context,
                  child: const AddItemScreen(),
                  width: 560,
                );
              },
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
    final goldPrice = ref.watch(goldPriceProvider);
    // final categoriesAsync = ref.watch(categoryNotifierProvider); // للاستخدام المستقبلي
    final materialsAsync = ref.watch(materialNotifierProvider);
    final categoriesAsync = ref.watch(categoryNotifierProvider);
    final isScanned = _scannedItems.contains(item.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Button(
        onPressed: () {
          Navigator.of(context).push(
            FluentPageRoute(
              builder: (_) => ItemDetailsScreen(itemId: item.id!),
            ),
          );
        },
        child: AdaptiveCard(
          padding: const EdgeInsets.all(16),
          backgroundColor: isScanned ? Color(0xFFE6F4EA) : Color(0xFFF6F8FA),
          child: Row(
            children: [
              // صورة المنتج أو أيقونة افتراضية
              SizedBox(
                width: 60,
                height: 60,
                child: AdaptiveCard(
                  padding: EdgeInsets.zero,
                  backgroundColor: Color(0xFFF6F8FA),
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
                      return Icon(
                        FluentIcons.cube_shape,
                        color: FluentTheme.of(context).inactiveColor,
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // معلومات المنتج
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اسم عرض تلقائي: الفئة + العيار + الوزن
                    categoriesAsync.when(
                      data: (cats) {
                        final cat = cats.firstWhere(
                          (c) => c.id == item.categoryId,
                          orElse: () => cats.isNotEmpty
                              ? cats.first
                              : Category(nameAr: '', iconName: ''),
                        );
                        final catName = cat.nameAr;
                        final display = (catName.isNotEmpty)
                            ? '$catName ${item.karat}K ${item.weightGrams}g'
                            : item.sku;
                        return Text(
                          display,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                      loading: () => Text(
                        item.sku,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      error: (_, __) => Text(
                        item.sku,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
                          style: TextStyle(
                            color: Color(0xFF0078D4),
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
                          style: FluentTheme.of(context).typography.caption,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.karat}K',
                          style: FluentTheme.of(context).typography.caption,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFFE5F1FB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.location.displayName,
                            style: FluentTheme.of(context).typography.caption,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        double? materialPrice;
                        final mats = materialsAsync.valueOrNull;
                        if (mats != null) {
                          final mat = mats.firstWhere(
                            (m) => m.id == item.materialId,
                            orElse: () => mats.first,
                          );
                          if (mat.isVariable) materialPrice = mat.pricePerGram;
                        }
                        final selling = item.calculateTotalPrice(
                          goldPrice,
                          materialSpecificPrice: materialPrice,
                        );
                        return Text(
                          '${selling.toStringAsFixed(2)} د.ل',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // علامة الجرد أو حالة RFID
              isScanned
                  ? Icon(FluentIcons.check_mark, color: Colors.green, size: 20)
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
        color = Colors.orange;
        icon = FluentIcons.warning;
        break;
      case ItemStatus.inStock:
        color = Colors.green;
        icon = FluentIcons.check_mark;
        break;
      case ItemStatus.sold:
        color = Colors.grey;
        icon = FluentIcons.money;
        break;
      case ItemStatus.reserved:
        color = Colors.orange;
        icon = FluentIcons.clock;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
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
      // إذا كان التركيز داخل عنصر إدخال نصي (مثل حقل البحث) فلا نعترض ضغطات لوحة المفاتيح
      final primaryFocus = FocusManager.instance.primaryFocus;
      if (primaryFocus != null && primaryFocus.context != null) {
        final widget = primaryFocus.context!.widget;
        // EditableText تستخدم داخلياً في TextBox
        if (widget is EditableText) {
          return; // السماح بالكتابة الطبيعية
        }
      }
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
        // تنظيف: إزالة التشكيل والمحارف غير الهكس/الأرقام
        final cleaned = character
            .replaceAll(
              RegExp(r'[\u0610-\u061A\u064B-\u065F\u06D6-\u06ED]'),
              '',
            )
            .trim();
        if (cleaned.isEmpty) return;
        // السماح فقط بمحارف HEX (قد تأتي بالأحرف الصغيرة)
        final hexOnly = cleaned.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
        if (hexOnly.isEmpty) return;
        _rfidBuffer += hexOnly.toUpperCase();
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
    _showOverlayMessage(message, Colors.green, FluentIcons.check_mark);
  }

  /// عرض رسالة تحذير سريعة
  void _showWarningMessage(String message) {
    _showOverlayMessage(message, Colors.orange, FluentIcons.warning);
  }

  /// عرض رسالة خطأ سريعة
  void _showErrorMessage(String message) {
    _showOverlayMessage(message, Colors.red, FluentIcons.cancel);
  }

  /// عرض رسالة عدم وجود الصنف
  void _showNotFoundDialog(String tagId) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('لم يتم العثور على الصنف'),
        content: Text('لم يتم العثور على صنف ببطاقة RFID:\n$tagId'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  /// إعادة تعيين الجرد
  void _resetAudit() {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('إعادة تعيين الجرد'),
        content: Text(
          'هل أنت متأكد من إعادة تعيين جرد $_scannedItems.length صنف؟',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
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
    final materials = ref
        .read(materialNotifierProvider)
        .maybeWhen(data: (list) => list, orElse: () => null);
    final totalScannedValue = scannedItems.fold<double>(0.0, (sum, item) {
      double? materialPrice;
      if (materials != null) {
        final mat = materials.firstWhere(
          (m) => m.id == item.materialId,
          orElse: () => materials.first,
        );
        if (mat.isVariable) materialPrice = mat.pricePerGram;
      }
      return sum +
          item.calculateTotalPrice(
            goldPrice,
            materialSpecificPrice: materialPrice,
          );
    });

    final totalAuditable = auditableItems.length;
    final progress = totalAuditable == 0
        ? 0.0
        : (scannedCount / totalAuditable).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: AdaptiveCard(
        padding: const EdgeInsets.all(16),
        backgroundColor: Color(0xFFF6F8FA),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('تم جردها', '$scannedCount', Colors.green),
                _buildStatItem('غير مجرودة', '$unscannedCount', Colors.red),
                _buildStatItem(
                  'إجمالي التكلفة',
                  '${totalScannedValue.toStringAsFixed(2)} د.ل',
                  Color(0xFF0078D4),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'التقدم: ${(progress * 100).toStringAsFixed(1)}% ($scannedCount/$totalAuditable)',
              textAlign: TextAlign.center,
              style: FluentTheme.of(context).typography.caption,
            ),
            const SizedBox(height: 6),
            ProgressBar(value: progress),
          ],
        ),
      ),
    );
  }

  /// أزرار تحكم الجرد
  Widget _buildAuditControlButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          AppButton.secondary(
            text: _enableBeep ? 'صوت مفعل' : 'صوت مطفأ',
            icon: _enableBeep
                ? CupertinoIcons.speaker_2_fill
                : CupertinoIcons.speaker_slash_fill,
            onPressed: () {
              setState(() => _enableBeep = !_enableBeep);
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppButton.primary(
              text: 'بدء القراءة',
              icon: FluentIcons.play,
              onPressed: !_isAuditScanning ? _startAuditScanning : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AppButton.destructive(
              text: 'إيقاف القراءة',
              icon: FluentIcons.stop,
              onPressed: _isAuditScanning ? _stopAuditScanning : null,
            ),
          ),
        ],
      ),
    );
  }

  /// قائمة الأصناف للجرد
  Widget _buildAuditItemsList(List<Item> items) {
    var auditableItems = items
        .where(
          (item) =>
              item.status == ItemStatus.inStock ||
              item.status == ItemStatus.needsRfid,
        )
        .toList();
    if (_selectedLocationFilter != null) {
      auditableItems = auditableItems
          .where((i) => i.location == _selectedLocationFilter)
          .toList();
    }
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
              FluentIcons.camera,
              size: 80,
              color: FluentTheme.of(context).inactiveColor,
            ),
            SizedBox(height: 16),
            Text(
              'لا توجد أصناف في المخزون للجرد',
              style: TextStyle(
                fontSize: 18,
                color: FluentTheme.of(context).resources.textFillColorSecondary,
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
                ? Colors.green.withAlpha(26)
                : Colors.red.withAlpha(13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isScanned
                  ? Colors.green.withAlpha(77)
                  : Colors.red.withAlpha(77),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isScanned ? Colors.green : Colors.red,
                ),
                child: Icon(
                  isScanned ? FluentIcons.check_mark : FluentIcons.cancel,
                  color: Colors.white,
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
                      style: TextStyle(
                        color: FluentTheme.of(
                          context,
                        ).resources.textFillColorSecondary,
                      ),
                    ),
                    if (item.rfidTag != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'RFID: ${item.rfidTag}',
                        style: TextStyle(
                          fontSize: 12,
                          color: FluentTheme.of(
                            context,
                          ).resources.textFillColorTertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      'المكان: ${item.location.displayName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: FluentTheme.of(
                          context,
                        ).resources.textFillColorSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isScanned)
                Button(
                  onPressed: () {
                    setState(() {
                      _scannedItems.remove(item.id);
                    });
                  },
                  child: Icon(
                    FluentIcons.remove_content,
                    color: Colors.red,
                    size: 20,
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
      // توصيل قارئ دور الجرد وبدء المسح
      final r = await ref.read(
        rfidReaderForRoleProvider(RfidRole.inventory).future,
      );
      final assign = RfidDeviceAssignmentsStorage();
      final cfg = await assign.load(RfidRole.inventory);
      if (!mounted) return;
      setState(() {
        _inventoryReader = r;
        _inventoryDeviceLabel = cfg != null
            ? '${cfg.interface}:${cfg.identifier}'
            : 'غير معيّن';
      });
      _inventoryStatusSub?.cancel();
      _inventoryStatusSub = r.statusStream.listen((s) {});
      _inventoryTagSub?.cancel();
      _inventoryTagSub = r.tagStream.listen((tagId) {
        if (_isAuditScanning && tagId.isNotEmpty) {
          _handleAuditRfidTag(tagId);
        }
      });
      if (r.currentStatus == RfidReaderStatus.connected ||
          r.currentStatus == RfidReaderStatus.scanning) {
        await r.startScanning();
      }
      debugPrint('✅ تم بدء قراءة الجرد على جهاز الدور المعين');
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
      await _inventoryReader?.stopScanning();
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
          // تشغيل صوت القارئ إن أمكن
          try {
            await _inventoryReader?.playBeep();
          } catch (_) {}
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

  // تم حذف _registerRfidListeners – لم يعد ضرورياً
  // دالة موحدة لعرض رسائل علوية (نجاح / تحذير / خطأ) لتقليل التكرار
  void _showOverlayMessage(String message, Color color, IconData icon) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 100,
        left: 20,
        right: 20,
        child: m.Material(
          color: Colors.transparent,
          child: AnimatedOpacity(
            opacity: 1,
            duration: const Duration(milliseconds: 150),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(38),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Timer(const Duration(seconds: 2), () {
      if (mounted) entry.remove();
    });
  }
}
