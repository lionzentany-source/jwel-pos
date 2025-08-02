import 'package:flutter/cupertino.dart';
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
import '../providers/rfid_provider.dart';
import '../services/rfid_service.dart';
import '../utils/rfid_duplicate_filter.dart';
import 'checkout_screen.dart';
import 'home_screen.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _goldPriceController = TextEditingController();
  final _silverPriceController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isListeningToRfid = false;
  int? _selectedCategoryId;
  // Focus node to keep keyboard focus for wedge RFID scanners
  final FocusNode _keyboardFocusNode = FocusNode();
  // Prevent duplicate listener registrations
  bool _rfidTagListenerRegistered = false;

  // لقراءة RFID من لوحة المفاتيح
  String _rfidBuffer = '';
  Timer? _rfidInputTimer;

  // تنظيف مدخلات RFID من الضجيج (محارف التحكم والتشكيل العربي)
  String _sanitizeRfidInput(String raw) {
    // إزالة محارف التحكم عدا \n
    String cleaned = raw.replaceAll(RegExp(r'[\x00-\x09\x0B-\x1F]'), '');
    // إزالة التشكيل العربي
    cleaned = cleaned.replaceAll(
      RegExp(r'[\u0610-\u061A\u064B-\u065F\u06D6-\u06ED]'),
      '',
    );
    return cleaned.trim();
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentPrices();
    _rfidBuffer = '';
    _isListeningToRfid = false;
    _startRfidListening();
  }

  @override
  void dispose() {
    _goldPriceController.dispose();
    _silverPriceController.dispose();
    _searchController.dispose();
    _rfidInputTimer?.cancel();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPrices() async {
    final settingsRepository = ref.read(settingsRepositoryProvider);
    final goldPrice = await settingsRepository.getGoldPrice();
    final silverPrice = await settingsRepository.getSilverPrice();
    if (!mounted) return;
    _goldPriceController.text = goldPrice.toString();
    _silverPriceController.text = silverPrice.toString();
  }

  void _startRfidListening() {
    if (!_isListeningToRfid) {
      _isListeningToRfid = true;
      // في بيئة الاختبار (widget tests) نتجنب تشغيل المسح لتفادي المؤقتات المعلقة
      final isTestEnv =
          const bool.fromEnvironment('FLUTTER_TEST') ||
          Platform.environment.containsKey('FLUTTER_TEST');
      if (isTestEnv) return;
      Future.microtask(() {
        if (mounted) {
          ref.read(rfidNotifierProvider.notifier).startScanning();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final rfidStatus = ref.watch(rfidNotifierProvider);
    final currency = ref.watch(currencyProvider);
    // Register RFID tag listener only once to avoid callbacks after dispose
    if (!_rfidTagListenerRegistered) {
      _rfidTagListenerRegistered = true;
      ref.listen<AsyncValue<String>>(rfidTagProvider, (previous, next) {
        // If widget disposed, skip (avoid Bad state: ref after dispose)
        if (!mounted) return;
        next.whenData((tagId) {
          if (tagId.isNotEmpty) {
            _handleRfidTag(tagId);
          }
        });
      });
    }

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: AdaptiveScaffold(
        title: 'نقطة البيع',
        actions: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              Navigator.of(context).pushReplacement(
                CupertinoPageRoute(builder: (_) => const HomeScreen()),
              );
            },
            // استبدال أيقونة البيت بسهم الرجوع
            child: const Icon(CupertinoIcons.back),
          ),
        ],
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth > 800;

            if (isTablet) {
              return _buildTabletLayout(cart, rfidStatus, currency);
            } else {
              return _buildPhoneLayout(cart, rfidStatus, currency);
            }
          },
        ),
      ),
    );
  }

  Widget _buildTabletLayout(
    Cart cart,
    AsyncValue<RfidReaderStatus> rfidStatus,
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
        SizedBox(width: 250, child: _buildControlPanel(rfidStatus, currency)),
      ],
    );
  }

  Widget _buildPhoneLayout(
    Cart cart,
    AsyncValue<RfidReaderStatus> rfidStatus,
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
          child: CupertinoSearchTextField(
            controller: _searchController,
            placeholder: 'بحث برقم بطاقة RFID أو SKU...',
            onSubmitted: _handleSearchSubmit,
          ),
        ),
        categoriesAsyncValue.when(
          data: (categories) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                CupertinoButton(
                  child: Text(
                    "الكل",
                    style: TextStyle(
                      color: _selectedCategoryId == null
                          ? CupertinoColors.activeBlue
                          : CupertinoColors.secondaryLabel,
                    ),
                  ),
                  onPressed: () => setState(() => _selectedCategoryId = null),
                ),
                ...categories.map(
                  (category) => CupertinoButton(
                    child: Text(
                      category.nameAr,
                      style: TextStyle(
                        color: _selectedCategoryId == category.id
                            ? CupertinoColors.activeBlue
                            : CupertinoColors.secondaryLabel,
                      ),
                    ),
                    onPressed: () =>
                        setState(() => _selectedCategoryId = category.id),
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
            loading: () => const Center(child: CupertinoActivityIndicator()),
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
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 80,
              width: double.infinity,
              color: CupertinoColors.systemGrey6,
              child: Builder(
                builder: (context) {
                  try {
                    if (item.imagePath != null && item.imagePath!.isNotEmpty) {
                      final f = File(item.imagePath!);
                      if (f.existsSync()) {
                        return Image.file(f, fit: BoxFit.contain);
                      }
                    }
                  } catch (_) {}
                  return const Center(
                    child: Icon(
                      CupertinoIcons.photo,
                      size: 30,
                      color: CupertinoColors.systemGrey,
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
                        style: const TextStyle(
                          fontSize: 10,
                          color: CupertinoColors.activeBlue,
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
    AsyncValue<RfidReaderStatus> rfidStatus,
    AsyncValue<String> currency,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // حالة RFID
        _buildRfidStatusCard(rfidStatus),

        const SizedBox(height: 16),

        // تحديث أسعار الجرام
        _buildPriceUpdateCard(currency),

        const SizedBox(height: 16),

        // أزرار سريعة
        _buildQuickActions(),
      ],
    );
  }

  Widget _buildRfidStatusCard(AsyncValue<RfidReaderStatus> rfidStatus) {
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
          const Text(
            'حالة قارئ RFID',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          rfidStatus.when(
            data: (status) => _buildStatusIndicator(status),
            loading: () => const Row(
              children: [
                CupertinoActivityIndicator(),
                SizedBox(width: 12),
                Text('جاري الاتصال...'),
              ],
            ),
            error: (error, stack) => Row(
              children: [
                const Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: CupertinoColors.systemRed,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('خطأ: $error')),
              ],
            ),
          ),
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
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              ref.read(rfidNotifierProvider.notifier).testConnection();
            },
            child: const Text('إعادة الاتصال'),
          ),
      ],
    );
  }

  Widget _buildPriceUpdateCard(AsyncValue<String> currency) {
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
          const Text(
            'أسعار الجرام',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('سعر الذهب'),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: _goldPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onSubmitted: _updateGoldPrice,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('سعر الفضة'),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: _silverPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onSubmitted: _updateSilverPrice,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CupertinoButton.filled(
                  onPressed: () => _updateGoldPrice(_goldPriceController.text),
                  child: const Text('تحديث سعر الذهب'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoButton.filled(
                  onPressed: () =>
                      _updateSilverPrice(_silverPriceController.text),
                  child: const Text('تحديث سعر الفضة'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'إجراءات سريعة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          CupertinoButton.filled(
            onPressed: () {
              if (_searchController.text.isNotEmpty) {
                _handleSearchSubmit(_searchController.text);
              }
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.search, color: CupertinoColors.white),
                SizedBox(width: 8),
                Text('بحث عن صنف'),
              ],
            ),
          ),

          const SizedBox(height: 8),
          CupertinoButton(
            color: CupertinoColors.systemGrey,
            onPressed: _clearCart,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.trash, color: CupertinoColors.white),
                SizedBox(width: 8),
                Text('مسح السلة'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSection(Cart cart, AsyncValue<String> currency) {
    return Container(
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
        children: [
          // رأس السلة
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: CupertinoColors.separator),
              ),
            ),
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
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _clearCart,
                    child: const Icon(
                      CupertinoIcons.trash,
                      color: CupertinoColors.systemRed,
                    ),
                  ),
              ],
            ),
          ),

          // قائمة الأصناف
          Expanded(
            child: cart.isEmpty
                ? _buildEmptyCart()
                : _buildCartItems(cart.items, currency),
          ),

          // ملخص الفاتورة
          if (cart.isNotEmpty) _buildCartSummary(cart, currency),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.cart,
            size: 80,
            color: CupertinoColors.systemGrey3,
          ),
          SizedBox(height: 16),
          Text(
            'السلة فارغة',
            style: TextStyle(
              fontSize: 18,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'امسح بطاقة RFID لإضافة صنف',
            style: TextStyle(color: CupertinoColors.tertiaryLabel),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // صورة المنتج
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(6),
            ),
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
                  color: CupertinoColors.systemGrey3,
                );
              },
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

          // زر الحذف فقط
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: () => _removeFromCart(cartItem.item.id!),
            child: const Icon(
              CupertinoIcons.delete,
              color: CupertinoColors.systemRed,
              size: 24,
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
        border: Border(top: BorderSide(color: CupertinoColors.separator)),
      ),
      child: Column(
        children: [
          // ملخص الأسعار
          _buildSummaryRow('المجموع الفرعي', cart.subtotal, currency),
          if (cart.totalDiscount > 0)
            _buildSummaryRow('الخصم', -cart.totalDiscount, currency),
          if (cart.taxAmount > 0)
            _buildSummaryRow('الضريبة', cart.taxAmount, currency),

          const SizedBox(height: 8),
          Container(height: 1, color: CupertinoColors.separator),
          const SizedBox(height: 8),

          // الإجمالي
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الإجمالي',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              currency.when(
                data: (curr) => Text(
                  '${cart.total.toStringAsFixed(2)} $curr',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.activeGreen,
                  ),
                ),
                loading: () => const Text('...'),
                error: (_, __) => const Text('خطأ'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // زر الدفع
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
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

  void _updateGoldPrice(String value) async {
    final price = double.tryParse(value);
    if (price != null && price > 0) {
      try {
        final settingsNotifier = ref.read(settingsNotifierProvider.notifier);
        await settingsNotifier.updateGoldPrice(price);
        if (!mounted) return; // widget might have been disposed
        _showSuccessMessage('تم تحديث سعر الذهب');
        // إعادة حساب أسعار السلة
        _recalculateCartPrices();
      } catch (error) {
        if (!mounted) return;
        _showErrorMessage('خطأ في تحديث سعر الذهب');
      }
    } else {
      if (!mounted) return;
      _showErrorMessage('يرجى إدخال سعر صحيح');
    }
  }

  void _updateSilverPrice(String value) async {
    final price = double.tryParse(value);
    if (price != null && price > 0) {
      try {
        final settingsNotifier = ref.read(settingsNotifierProvider.notifier);
        await settingsNotifier.updateSilverPrice(price);
        if (!mounted) return;
        _showSuccessMessage('تم تحديث سعر الفضة');
        // إعادة حساب أسعار السلة
        _recalculateCartPrices();
      } catch (error) {
        if (!mounted) return;
        _showErrorMessage('خطأ في تحديث سعر الفضة');
      }
    } else {
      if (!mounted) return;
      _showErrorMessage('يرجى إدخال سعر صحيح');
    }
  }

  void _recalculateCartPrices() async {
    if (!mounted) return; // guard against dispose mid-process
    // إعادة حساب أسعار جميع الأصناف في السلة بناءً على الأسعار الجديدة
    final cart = ref.read(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    // مسح السلة وإعادة إضافة الأصناف بالأسعار الجديدة
    cartNotifier.clearCart();

    for (final cartItem in cart.items) {
      cartNotifier.addItem(cartItem.item);

      // إعادة تطبيق الكمية والخصم إذا كانت مختلفة عن الافتراضي
      if (cartItem.quantity != 1.0) {
        cartNotifier.updateQuantity(cartItem.item.id!, cartItem.quantity);
      }
      if (cartItem.discount > 0) {
        cartNotifier.updateDiscount(cartItem.item.id!, cartItem.discount);
      }
    }
  }

  void _removeFromCart(int itemId) {
    ref.read(cartProvider.notifier).removeItem(itemId);
  }

  void _clearCart() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('مسح السلة'),
        content: const Text('هل أنت متأكد من مسح جميع الأصناف من السلة؟'),
        actions: [
          CupertinoDialogAction(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              Navigator.pop(context);
              _isListeningToRfid = false;
              _startRfidListening();
            },
            child: const Text('مسح'),
          ),
        ],
      ),
    );
  }

  void _proceedToCheckout() {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => const CheckoutScreen()),
    ).then((_) {
      // بعد العودة من شاشة الدفع، أعد تشغيل قراءة RFID
      _isListeningToRfid = false;
      _startRfidListening();
    });
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

  /// معالجة ضغطات لوحة المفاتيح لقراءة RFID
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;

      // تجاهل مفاتيح التحكم / المعدِّلات لتقليل التحذيرات
      if (key == LogicalKeyboardKey.shiftLeft ||
          key == LogicalKeyboardKey.shiftRight ||
          key == LogicalKeyboardKey.controlLeft ||
          key == LogicalKeyboardKey.controlRight ||
          key == LogicalKeyboardKey.altLeft ||
          key == LogicalKeyboardKey.altRight ||
          key == LogicalKeyboardKey.metaLeft ||
          key == LogicalKeyboardKey.metaRight ||
          key == LogicalKeyboardKey.capsLock ||
          key == LogicalKeyboardKey.numLock ||
          key == LogicalKeyboardKey.scrollLock ||
          key == LogicalKeyboardKey.contextMenu) {
        return;
      }

      // إذا كان Enter أو Return
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        if (_rfidBuffer.isNotEmpty && _rfidBuffer.length >= 8) {
          // معالجة بطاقة RFID
          final tagId = _rfidBuffer.trim();
          debugPrint('📡 تم قراءة بطاقة RFID من لوحة المفاتيح: $tagId');
          _handleRfidTag(tagId);
          _rfidBuffer = '';
          _rfidInputTimer?.cancel();
        }
        return;
      }

      // إضافة الحرف إلى الbuffer
      final character = event.character;
      if (character != null && character.isNotEmpty) {
        final sanitized = _sanitizeRfidInput(character);
        if (sanitized.isEmpty) return;
        _rfidBuffer += sanitized;

        // إعادة تعيين مؤقت مسح الbuffer
        _rfidInputTimer?.cancel();
        _rfidInputTimer = Timer(const Duration(milliseconds: 500), () {
          if (_rfidBuffer.length < 8) {
            _rfidBuffer = ''; // مسح إذا لم يكتمل في الوقت المحدد
          }
        });
      }
    }
  }
}
