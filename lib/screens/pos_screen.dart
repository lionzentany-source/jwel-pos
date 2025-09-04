import 'package:flutter/cupertino.dart';
import 'package:fluent_ui/fluent_ui.dart';

import 'package:flutter/material.dart'
    show Material; // لاستخدام Material في الـ Overlay
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../models/item.dart';
import '../providers/category_provider.dart';
import '../providers/item_provider.dart';
import '../providers/material_provider.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/app_loading_error_widget.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../providers/settings_provider.dart';
import '../services/rfid_service.dart';
import '../providers/rfid_role_reader_provider.dart';
import '../services/rfid_device_assignments.dart';
import '../services/rfid_session_coordinator.dart';
import '../utils/rfid_duplicate_filter.dart';
import 'checkout_screen.dart';
import '../widgets/side_sheet.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  // Dynamic controllers for each material that has a price (variable materials)
  final Map<int, TextEditingController> _materialPriceControllers = {};
  final _searchController = TextEditingController();
  int? _selectedCategoryId;
  // Focus node to keep keyboard focus for wedge RFID scanners
  final FocusNode _keyboardFocusNode = FocusNode();
  // (تمت إزالة مستمعي Riverpod لبطاقات RFID – نستخدم اشتراك القارئ مباشرة)
  OverlayEntry? _checkoutOverlay;

  // لقراءة RFID من لوحة المفاتيح
  String _rfidBuffer = '';
  Timer? _rfidInputTimer;

  // (تم حذف دالة تنظيف مدخلات RFID لعدم استخدامها)

  // قارئ مخصص لدور الكاشير
  RfidServiceReal? _cashierReader;
  StreamSubscription<String>? _cashierTagSub;
  StreamSubscription<RfidReaderStatus>? _cashierStatusSub;
  RfidReaderStatus _cashierStatus = RfidReaderStatus.disconnected;
  String? _cashierDeviceLabel;

  @override
  void initState() {
    super.initState();
    _loadCurrentPrices();
    _rfidBuffer = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCashierReader();
    });
  }

  @override
  void dispose() {
    for (final c in _materialPriceControllers.values) {
      c.dispose();
    }
    _searchController.dispose();
    _rfidInputTimer?.cancel();
    _keyboardFocusNode.dispose();
    try {
      _cashierReader?.stopScanning();
    } catch (_) {}
    try {
      _cashierTagSub?.cancel();
    } catch (_) {}
    try {
      _cashierStatusSub?.cancel();
    } catch (_) {}
    RfidSessionCoordinator.instance.setCashierActive(false);
    super.dispose();
  }

  Future<void> _loadCurrentPrices() async {
    // Load materials and initialize controllers
    final materials = await ref
        .read(materialRepositoryProvider)
        .getAllMaterials();
    if (!mounted) return;
    for (final m in materials) {
      // Consider a material with a price if variable OR price_per_gram > 0
      if (m.isVariable || (m.pricePerGram > 0)) {
        _materialPriceControllers.putIfAbsent(
          m.id!,
          () => TextEditingController(text: m.pricePerGram.toString()),
        );
      }
    }
  }

  Future<void> _initCashierReader() async {
    try {
      final reader = await ref.read(
        rfidReaderForRoleProvider(RfidRole.cashier).future,
      );
      final assign = RfidDeviceAssignmentsStorage();
      final cfg = await assign.load(RfidRole.cashier);
      if (!mounted) return;
      setState(() {
        _cashierReader = reader;
        _cashierStatus = reader.currentStatus;
        _cashierDeviceLabel = cfg != null
            ? '${cfg.interface}:${cfg.identifier}'
            : 'غير معيّن';
      });
      _cashierStatusSub?.cancel();
      _cashierStatusSub = reader.statusStream.listen((s) {
        if (!mounted) return;
        setState(() => _cashierStatus = s);
      });
      _cashierTagSub?.cancel();
      _cashierTagSub = reader.tagStream.listen((tagId) {
        if (tagId.isNotEmpty) _handleRfidTag(tagId);
      });
      // ابدأ المسح إذا كان متصلاً
      if (reader.currentStatus == RfidReaderStatus.connected) {
        await reader.startScanning();
        RfidSessionCoordinator.instance.setCashierActive(true);
        if (mounted) setState(() {});
      }
    } catch (e) {
      // صامت: قد لا يكون الجهاز معيناً
    }
  }

  // تم الاستغناء عن دالة بدء الاستماع القديمة

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final currency = ref.watch(currencyProvider);
    final wedgeEnabled = ref.watch(posKeyboardWedgeEnabledProvider);
    final rfidStatusLocal = _cashierStatus;

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: wedgeEnabled.maybeWhen(data: (v) => v, orElse: () => true),
      onKeyEvent: (event) {
        final enabled = wedgeEnabled.maybeWhen(
          data: (v) => v,
          orElse: () => true,
        );
        if (!enabled) return; // ignore keyboard input when disabled
        _handleKeyEvent(event);
      },
      child: Container(
        color: Color(0xfff6f8fa), // خلفية موحدة
        child: AdaptiveScaffold(
          title: 'نقطة البيع',
          commandBarItems: [], // حذف زر الرجوع
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth > 800;

              if (isTablet) {
                return _buildTabletLayout(cart, rfidStatusLocal, currency);
              } else {
                return _buildPhoneLayout(cart, rfidStatusLocal, currency);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTabletLayout(
    Cart cart,
    RfidReaderStatus rfidStatus,
    AsyncValue<String> currency,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Side - Cart
        Expanded(flex: 2, child: _buildCartSection(cart, currency)),
        const SizedBox(width: 16),
        // Middle - Items Grid
        Expanded(flex: 3, child: _buildItemsGrid()),
        const SizedBox(width: 16),
        // Right Side - Controls
        SizedBox(width: 260, child: _buildControlPanel(rfidStatus, currency)),
      ],
    );
  }

  Widget _buildPhoneLayout(
    Cart cart,
    RfidReaderStatus rfidStatus,
    AsyncValue<String> currency,
  ) {
    return Column(
      children: [
        // سلة المشتريات
        Expanded(flex: 2, child: _buildCartSection(cart, currency)),
        const SizedBox(height: 16),
        // عرض المنتجات
        Expanded(flex: 3, child: _buildItemsGrid()),
      ],
    );
  }

  Widget _buildItemsGrid() {
    final itemsAsyncValue = ref.watch(itemsProvider);
    final categoriesAsyncValue = ref.watch(categoriesProvider);

    return Column(
      children: [
        // مربع بحث RFID
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextBox(
            controller: _searchController,
            placeholder:
                'بحث برقم بطاقة RFID أو SKU...'
                ' (اضغط Enter للبحث)',
            onSubmitted: _handleSearchSubmit,
          ),
        ),
        categoriesAsyncValue.when(
          data: (categories) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Button(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                        _selectedCategoryId == null
                            ? Color(0xff0078D4)
                            : Color(0xffe5e5e5),
                      ),
                    ),
                    child: Text(
                      'الكل',
                      style: TextStyle(
                        color: _selectedCategoryId == null
                            ? Colors.white
                            : Color(0xff0078D4),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => setState(() => _selectedCategoryId = null),
                  ),
                ),
                ...categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Button(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                          _selectedCategoryId == category.id
                              ? Color(0xff0078D4)
                              : Color(0xffe5e5e5),
                        ),
                      ),
                      child: Text(
                        category.nameAr,
                        style: TextStyle(
                          color: _selectedCategoryId == category.id
                              ? Colors.white
                              : Color(0xff0078D4),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () =>
                          setState(() => _selectedCategoryId = category.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (err, stack) => const Text("Error loading categories"),
        ),
        Expanded(
          child: itemsAsyncValue.when(
            data: (allItems) {
              // فلترة الأصناف المتاحة للبيع (في المخزون أو يحتاج لبطاقة)
              final availableItems = allItems
                  .where(
                    (item) =>
                        item.status == ItemStatus.inStock ||
                        item.status == ItemStatus.needsRfid,
                  )
                  .toList();

              final filteredItems = _selectedCategoryId == null
                  ? availableItems
                  : availableItems
                        .where((item) => item.categoryId == _selectedCategoryId)
                        .toList();

              if (filteredItems.isEmpty) {
                return const Center(
                  child: Text("لا توجد أصناف متاحة في هذا القسم"),
                );
              }

              return MasonryGridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return _buildItemCard(item);
                },
              );
            },
            loading: () => const Center(child: ProgressRing()),
            error: (err, stack) => AppLoadingErrorWidget(
              title: 'خطأ في تحميل الأصناف',
              message: err.toString(),
              onRetry: () => ref.refresh(itemsProvider),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(Item item) {
    final materialsAsync = ref.watch(materialNotifierProvider);

    return GestureDetector(
      onTap: () => _handleManualItemAdd(item),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 80,
              width: double.infinity,
              color: Colors.black.withAlpha(8),
              child: Builder(
                builder: (context) {
                  try {
                    if (item.imagePath != null && item.imagePath!.isNotEmpty) {
                      final f = File(item.imagePath!);
                      if (f.existsSync()) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(f, fit: BoxFit.contain),
                        );
                      }
                    }
                  } catch (_) {}
                  return Center(
                    child: Icon(
                      FluentIcons.photo,
                      size: 30,
                      color: FluentTheme.of(context).inactiveColor,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.sku,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  materialsAsync.when(
                    data: (materials) {
                      final material = materials.firstWhere(
                        (m) => m.id == item.materialId,
                        orElse: () => materials.first,
                      );
                      return Text(
                        material.nameAr,
                        style: TextStyle(
                          fontSize: 10,
                          color: FluentTheme.of(context).accentColor,
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  Text(
                    "${item.weightGrams}g, ${item.karat}K",
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel(
    RfidReaderStatus rfidStatus,
    AsyncValue<String> currency,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRfidStatusCard(rfidStatus),
          const SizedBox(height: 16),
          _buildPriceUpdateCard(currency),
        ],
      ),
    );
  }

  Widget _buildRfidStatusCard(RfidReaderStatus status) {
    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'حالة قارئ RFID',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildStatusIndicator(status),
          if (_cashierDeviceLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              'الجهاز: ${_cashierDeviceLabel!}',
              style: FluentTheme.of(context).typography.caption,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(RfidReaderStatus status) {
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case RfidReaderStatus.connected:
        color = CupertinoColors.activeGreen;
        icon = CupertinoIcons.checkmark_circle_fill;
        text = 'متصل - جاهز للقراءة';
        break;
      case RfidReaderStatus.scanning:
        color = CupertinoColors.activeBlue;
        icon = CupertinoIcons.wifi;
        text = 'جاري المسح...';
        break;
      case RfidReaderStatus.connecting:
        color = CupertinoColors.systemOrange;
        icon = CupertinoIcons.antenna_radiowaves_left_right;
        text = 'جاري الاتصال...';
        break;
      case RfidReaderStatus.disconnected:
        color = CupertinoColors.systemGrey;
        icon = CupertinoIcons.wifi_slash;
        text = 'غير متصل';
        break;
      case RfidReaderStatus.error:
        color = CupertinoColors.systemRed;
        icon = CupertinoIcons.xmark_circle_fill;
        text = 'خطأ في الاتصال';
        break;
    }

    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ),
        if (status == RfidReaderStatus.disconnected ||
            status == RfidReaderStatus.error)
          Button(
            onPressed: () async {
              await _initCashierReader();
            },
            child: const Text('إعادة الاتصال'),
          ),
      ],
    );
  }

  Widget _buildPriceUpdateCard(AsyncValue<String> currency) {
    final materialsState = ref.watch(materialNotifierProvider);

    return materialsState.when(
      data: (materials) {
        final pricedMaterials = (materials.where(
          (m) => m.isVariable || m.pricePerGram > 0,
        )).toList()..sort((a, b) => a.nameAr.compareTo(b.nameAr));
        if (pricedMaterials.isEmpty) {
          return const InfoBar(
            title: Text('لا توجد مواد ذات سعر متغير'),
            severity: InfoBarSeverity.info,
          );
        }

        // Ensure controllers exist
        for (final m in pricedMaterials) {
          _materialPriceControllers.putIfAbsent(
            m.id!,
            () => TextEditingController(text: m.pricePerGram.toString()),
          );
        }

        return Card(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'أسعار الجرام',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ...pricedMaterials.map((m) {
                final controller = _materialPriceControllers[m.id]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.nameAr,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextBox(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        placeholder: 'سعر الجرام',
                        onChanged: (v) {
                          final value = double.tryParse(v) ?? 0.0;
                          ref
                              .read(materialNotifierProvider.notifier)
                              .updateMaterialPrice(m.id!, value);
                        },
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _updateAllMaterialPrices,
                  child: const Text('تحديث السعر'),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: ProgressRing()),
      error: (e, _) => Container(
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
        child: Text('خطأ في تحميل المواد: $e'),
      ),
    );
  }

  // Removed quick actions panel per user request

  Widget _buildCartSection(Cart cart, AsyncValue<String> currency) {
    return Card(
      child: Column(
        children: [
          // رأس السلة
          Acrylic(
            luminosityAlpha: 0.03,
            tintAlpha: 0.08,
            blurAmount: 8.0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'سلة المشتريات (${cart.itemCount})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (cart.isNotEmpty)
                    GestureDetector(
                      onTap: _clearCart,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          FluentIcons.delete,
                          color: Colors.red,
                          size: 22,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // قائمة الأصناف
          Expanded(
            child: cart.isEmpty
                ? _buildEmptyCart()
                : _buildCartItems(cart.items, currency),
          ),

          // ملخص الفاتورة
          cart.isNotEmpty
              ? _buildCartSummary(cart, currency)
              : const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.shopping_cart,
            size: 80,
            color: FluentTheme.of(context).inactiveColor,
          ),
          const SizedBox(height: 16),
          Text(
            'السلة فارغة',
            style: FluentTheme.of(context).typography.subtitle,
          ),
          const SizedBox(height: 8),
          Text(
            'امسح بطاقة RFID لإضافة صنف',
            style: FluentTheme.of(context).typography.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems(List<CartItem> items, AsyncValue<String> currency) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final cartItem = items[index];
        return _buildCartItemCard(cartItem, currency);
      },
    );
  }

  Widget _buildCartItemCard(CartItem cartItem, AsyncValue<String> currency) {
    return Card(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // صورة المنتج
          SizedBox(
            width: 50,
            height: 50,
            child: Card(
              padding: EdgeInsets.zero,
              child: Builder(
                builder: (context) {
                  try {
                    final path = cartItem.item.imagePath;
                    if (path != null && path.isNotEmpty) {
                      final f = File(path);
                      if (f.existsSync()) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(f, fit: BoxFit.contain),
                        );
                      }
                    }
                  } catch (_) {}
                  return const Icon(
                    CupertinoIcons.cube_box,
                    color: CupertinoColors.systemGrey,
                  );
                },
              ),
            ),
          ),

          const SizedBox(width: 12),

          // معلومات المنتج
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cartItem.item.sku,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${cartItem.item.weightGrams}g - ${cartItem.item.karat}K',
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 4),
                currency.when(
                  data: (curr) => Text(
                    '${cartItem.totalPrice.toStringAsFixed(2)} $curr',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.activeGreen,
                    ),
                  ),
                  loading: () => const Text('...'),
                  error: (_, __) => const Text('خطأ'),
                ),
              ],
            ),
          ),

          // أيقونة حذف فقط بدون زر
          GestureDetector(
            onTap: () => _removeFromCart(cartItem.item.id!),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(FluentIcons.delete, color: Colors.red, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummary(Cart cart, AsyncValue<String> currency) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0x14000000)),
        ), // subtle divider
      ),
      child: Column(
        children: [
          // تم إخفاء المجموع الفرعي بناءً على طلب المستخدم
          if (cart.totalDiscount > 0)
            _buildSummaryRow('الخصم', -cart.totalDiscount, currency),
          if (cart.taxAmount > 0)
            _buildSummaryRow('الضريبة', cart.taxAmount, currency),

          const SizedBox(height: 8),
          Container(height: 1, color: const Color(0x14000000)),
          const SizedBox(height: 8),

          // الإجمالي
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                cart.total.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.activeGreen,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const Text(
                'الإجمالي',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // زر الدفع
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: cart.isNotEmpty ? _proceedToCheckout : null,
              child: const Text(
                'متابعة للدفع',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount,
    AsyncValue<String> currency,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          currency.when(
            data: (curr) => Text(
              '${amount.toStringAsFixed(2)} $curr',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: amount < 0 ? CupertinoColors.systemRed : null,
              ),
            ),
            loading: () => const Text('...'),
            error: (_, __) => const Text('خطأ'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleManualItemAdd(Item item) async {
    final cartNotifier = ref.read(cartProvider.notifier);
    await cartNotifier.addItem(item);
  }

  Future<void> _handleRfidTag(String tagId) async {
    debugPrint('📱 POS Screen: تم استقبال بطاقة RFID: $tagId');
    // منع التكرار العالمي خلال نافذة زمنية قصيرة
    if (!RfidDuplicateFilter.shouldProcess(tagId)) {
      debugPrint('🔁 تم تجاهل بطاقة مكررة (POS): $tagId');
      return;
    }
    if (!mounted) return;
    final cartNotifier = ref.read(cartProvider.notifier);
    await cartNotifier.addItemByRfidTag(tagId);
  }

  Future<void> _handleSearchSubmit(String query) async {
    if (query.trim().isEmpty) return;
    if (!mounted) return;
    final cartNotifier = ref.read(cartProvider.notifier);
    await cartNotifier.addItemBySearch(query.trim());
    _searchController.clear();
  }

  void _updateAllMaterialPrices() async {
    try {
      final repo = ref.read(materialNotifierProvider.notifier);
      bool updatedAny = false;
      for (final entry in _materialPriceControllers.entries) {
        final id = entry.key;
        final txt = entry.value.text.trim();
        final v = double.tryParse(txt);
        if (v != null && v > 0) {
          await repo.updateMaterialPrice(id, v);
          updatedAny = true;
        }
      }
      if (updatedAny) {
        _showTransientMessage('تم تحديث الأسعار');
      } else {
        _showTransientMessage('لا تغييرات في الأسعار');
      }
    } catch (e) {
      _showTransientMessage('خطأ في تحديث الأسعار');
    }
  }

  void _showTransientMessage(String message) {
    if (!mounted) return;
    _checkoutOverlay?.remove();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 80,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.activeGreen,
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
                const Icon(
                  CupertinoIcons.check_mark_circled,
                  color: Colors.white,
                ),
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
    );
    overlay.insert(entry);
    _checkoutOverlay = entry;
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _checkoutOverlay?.remove();
        _checkoutOverlay = null;
      }
    });
  }

  void _clearCart() {
    ref.read(cartProvider.notifier).clearCart();
  }

  void _removeFromCart(int itemId) {
    ref.read(cartProvider.notifier).removeItem(itemId);
  }

  void _proceedToCheckout() {
    if (!mounted) return;
    showSideSheet(
      context,
      title: 'الدفع/الخروج',
      width: 560,
      child: CheckoutScreen(
        embedded: true,
        onClose: () {
          Navigator.of(context).maybePop();
        },
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary.context?.widget is EditableText) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_rfidBuffer.isNotEmpty && _rfidBuffer.length >= 8) {
        final tag = _rfidBuffer.trim();
        _rfidBuffer = '';
        _rfidInputTimer?.cancel();
        _handleRfidTag(tag);
      }
      return;
    }
    if (key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight) {
      return;
    }
    final ch = event.character;
    if (ch == null || ch.isEmpty || ch == '\n' || ch == '\r') return;
    final cleaned = ch
        .replaceAll(RegExp(r'[\u0610-\u061A\u064B-\u065F\u06D6-\u06ED]'), '')
        .trim();
    if (cleaned.isEmpty) return;
    final hexOnly = cleaned.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (hexOnly.isEmpty) return;
    _rfidBuffer += hexOnly.toUpperCase();
    _rfidInputTimer?.cancel();
    _rfidInputTimer = Timer(const Duration(milliseconds: 500), () {
      if (_rfidBuffer.length < 8) {
        _rfidBuffer = '';
      }
    });
  }
}
