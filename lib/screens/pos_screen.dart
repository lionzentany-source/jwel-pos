import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../models/item.dart';
import '../providers/category_provider.dart';
import '../providers/item_provider.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/app_loading_error_widget.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/rfid_provider.dart';
import '../services/rfid_service.dart';
import 'checkout_screen.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _goldPriceController = TextEditingController();
  final _silverPriceController = TextEditingController();
  bool _isListeningToRfid = false;
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadCurrentPrices();
    _startRfidListening();
  }

  @override
  void dispose() {
    _goldPriceController.dispose();
    _silverPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPrices() async {
    final settingsRepository = ref.read(settingsRepositoryProvider);
    final goldPrice = await settingsRepository.getGoldPrice();
    final silverPrice = await settingsRepository.getSilverPrice();

    _goldPriceController.text = goldPrice.toString();
    _silverPriceController.text = silverPrice.toString();
  }

  void _startRfidListening() {
    if (!_isListeningToRfid) {
      _isListeningToRfid = true;
      ref.read(rfidNotifierProvider.notifier).startScanning();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final rfidStatus = ref.watch(rfidNotifierProvider);
    final currency = ref.watch(currencyProvider);

    ref.listen<AsyncValue<String>>(rfidTagProvider, (previous, next) {
      next.whenData((tagId) {
        _handleRfidTag(tagId);
      });
    });

    return AdaptiveScaffold(
      title: 'نقطة البيع',
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
    final itemsAsyncValue = ref.watch(
      itemsByStatusProvider(ItemStatus.inStock),
    );
    final categoriesAsyncValue = ref.watch(categoriesProvider);

    return Column(
      children: [
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
            data: (items) {
              final filteredItems = _selectedCategoryId == null
                  ? items
                  : items
                        .where((item) => item.categoryId == _selectedCategoryId)
                        .toList();

              if (filteredItems.isEmpty) {
                return const Center(
                  child: Text("لا توجد أصناف متاحة في هذا القسم"),
                );
              }

              return MasonryGridView.count(
                crossAxisCount: 2,
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
              onRetry: () =>
                  ref.refresh(itemsByStatusProvider(ItemStatus.inStock)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(Item item) {
    return GestureDetector(
      onTap: () => _handleManualItemAdd(item),
      child: AdaptiveCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imagePath != null)
              Image.file(
                File(item.imagePath!),
                fit: BoxFit.cover,
                height: 120,
                width: double.infinity,
              ),
            if (item.imagePath == null)
              Container(
                height: 120,
                color: CupertinoColors.systemGrey5,
                child: const Center(child: Icon(CupertinoIcons.photo)),
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.sku,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text("${item.weightGrams}g, ${item.karat}K"),
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
                      suffix: currency.when(
                        data: (curr) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(curr),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
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
                      suffix: currency.when(
                        data: (curr) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(curr),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
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
              // سيتم إضافة شاشة اختيار الأصناف يدوياً في التحديث القادم
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.search, color: CupertinoColors.white),
                SizedBox(width: 8),
                Text('بحث يدوي عن صنف'),
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
            child: cartItem.item.imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      File(cartItem.item.imagePath!),
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(
                    CupertinoIcons.cube_box,
                    color: CupertinoColors.systemGrey3,
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

          // أزرار التحكم
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.all(4),
                    onPressed: () => _decreaseQuantity(cartItem.item.id!),
                    child: const Icon(
                      CupertinoIcons.minus_circle,
                      color: CupertinoColors.systemRed,
                    ),
                  ),
                  Text(
                    cartItem.quantity.toString(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.all(4),
                    onPressed: () => _increaseQuantity(cartItem.item.id!),
                    child: const Icon(
                      CupertinoIcons.plus_circle,
                      color: CupertinoColors.activeGreen,
                    ),
                  ),
                ],
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(4),
                onPressed: () => _removeFromCart(cartItem.item.id!),
                child: const Icon(
                  CupertinoIcons.delete,
                  color: CupertinoColors.systemRed,
                  size: 20,
                ),
              ),
            ],
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
    final success = await cartNotifier.addItem(item);

    if (success) {
      _showSuccessMessage('تم إضافة الصنف للسلة');
    } else {
      _showErrorMessage('الصنف موجود بالفعل في السلة');
    }
  }

  Future<void> _handleRfidTag(String tagId) async {
    final cartNotifier = ref.read(cartProvider.notifier);
    final success = await cartNotifier.addItemByRfid(tagId);

    if (success) {
      // إظهار رسالة نجاح
      _showSuccessMessage('تم إضافة الصنف للسلة');
    } else {
      // إظهار رسالة خطأ
      _showErrorMessage('لم يتم العثور على الصنف أو غير متاح للبيع');
    }
  }

  void _updateGoldPrice(String value) async {
    final price = double.tryParse(value);
    if (price != null && price > 0) {
      try {
        final settingsNotifier = ref.read(settingsNotifierProvider.notifier);
        await settingsNotifier.updateGoldPrice(price);
        _showSuccessMessage('تم تحديث سعر الذهب');

        // إعادة حساب أسعار السلة
        _recalculateCartPrices();
      } catch (error) {
        _showErrorMessage('خطأ في تحديث سعر الذهب');
      }
    } else {
      _showErrorMessage('يرجى إدخال سعر صحيح');
    }
  }

  void _updateSilverPrice(String value) async {
    final price = double.tryParse(value);
    if (price != null && price > 0) {
      try {
        final settingsNotifier = ref.read(settingsNotifierProvider.notifier);
        await settingsNotifier.updateSilverPrice(price);
        _showSuccessMessage('تم تحديث سعر الفضة');

        // إعادة حساب أسعار السلة
        _recalculateCartPrices();
      } catch (error) {
        _showErrorMessage('خطأ في تحديث سعر الفضة');
      }
    } else {
      _showErrorMessage('يرجى إدخال سعر صحيح');
    }
  }

  void _recalculateCartPrices() async {
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

  void _increaseQuantity(int itemId) {
    final cart = ref.read(cartProvider);
    final cartItem = cart.items.firstWhere((item) => item.item.id == itemId);
    ref
        .read(cartProvider.notifier)
        .updateQuantity(itemId, cartItem.quantity + 1);
  }

  void _decreaseQuantity(int itemId) {
    final cart = ref.read(cartProvider);
    final cartItem = cart.items.firstWhere((item) => item.item.id == itemId);
    if (cartItem.quantity > 1) {
      ref
          .read(cartProvider.notifier)
          .updateQuantity(itemId, cartItem.quantity - 1);
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
