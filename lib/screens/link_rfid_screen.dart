import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/adaptive_scaffold.dart';
import '../models/item.dart';
import '../providers/item_provider.dart';
import '../services/rfid_service.dart'; // Import RfidReaderStatus
import '../providers/rfid_provider.dart'; // Import rfidNotifierProvider and rfidTagProvider
import '../utils/rfid_duplicate_filter.dart';

class LinkRfidScreen extends ConsumerStatefulWidget {
  final Item item;

  const LinkRfidScreen({super.key, required this.item});

  @override
  ConsumerState<LinkRfidScreen> createState() => _LinkRfidScreenState();
}

class _LinkRfidScreenState extends ConsumerState<LinkRfidScreen>
    with TickerProviderStateMixin {
  String? _scannedTag;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Initialize RFID connection after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRfidConnection();
    });
  }

  Future<void> _initializeRfidConnection() async {
    try {
      // محاولة الاتصال بقارئ RFID
      await ref
          .read(rfidNotifierProvider.notifier)
          .connect(port: 'COM3', baudRate: 115200, timeout: 5000);
    } catch (e) {
      debugPrint('فشل في الاتصال بقارئ RFID: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    // إيقاف المسح عند الخروج من الشاشة
    try {
      ref.read(rfidNotifierProvider.notifier).stopScanning();
    } catch (e) {
      // تجاهل الأخطاء عند الخروج
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rfidStatus = ref.watch(rfidNotifierProvider);

    // Listen for new tags
    ref.listen<AsyncValue<String>>(rfidTagProvider, (previous, next) {
      next.whenData((tagId) {
        if (mounted && _scannedTag == null) {
          if (!RfidDuplicateFilter.shouldProcess(tagId)) {
            debugPrint('🔁 تجاهل بطاقة مكررة (ربط): $tagId');
            return;
          }
          // فقط إذا لم يتم قراءة بطاقة من قبل
          setState(() {
            _scannedTag = tagId;
          });
          _animationController.stop();
          // إيقاف المسح فوراً
          ref.read(rfidNotifierProvider.notifier).stopScanning();
        }
      });
    });

    // Control animation based on scanning state
    rfidStatus.whenData((status) {
      if (status == RfidReaderStatus.scanning &&
          !_animationController.isAnimating) {
        _animationController.repeat();
      } else if (status != RfidReaderStatus.scanning &&
          _animationController.isAnimating) {
        _animationController.stop();
      }
    });

    return AdaptiveScaffold(
      title: 'ربط بطاقة RFID',
      body: Column(
        children: [
          // معلومات الصنف
          _buildItemInfo(),

          const SizedBox(height: 30),

          // حالة قارئ RFID
          _buildReaderStatus(rfidStatus),

          const SizedBox(height: 30),

          // منطقة المسح
          Expanded(child: _buildScanningArea(rfidStatus)),

          // الأزرار
          _buildActionButtons(rfidStatus),
        ],
      ),
    );
  }

  Widget _buildItemInfo() {
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
            'الصنف المراد ربطه',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('رقم الصنف:'),
              Text(
                widget.item.sku,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الوزن:'),
              Text('${widget.item.weightGrams} جرام'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('العيار:'),
              Text('${widget.item.karat} قيراط'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReaderStatus(AsyncValue<RfidReaderStatus> rfidStatus) {
    final status = rfidStatus.asData?.value ?? RfidReaderStatus.disconnected;
    final isConnected =
        status == RfidReaderStatus.connected ||
        status == RfidReaderStatus.scanning;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConnected
            ? CupertinoColors.activeGreen.withValues(alpha: 0.1)
            : CupertinoColors.systemRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected
              ? CupertinoColors.activeGreen
              : CupertinoColors.systemRed,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          rfidStatus.isLoading
              ? const CupertinoActivityIndicator()
              : Icon(
                  isConnected
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.xmark_circle_fill,
                  color: isConnected
                      ? CupertinoColors.activeGreen
                      : CupertinoColors.systemRed,
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusText(status),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isConnected
                        ? CupertinoColors.activeGreen
                        : CupertinoColors.systemRed,
                  ),
                ),
                if (rfidStatus.hasError)
                  Text(
                    rfidStatus.error.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(RfidReaderStatus status) {
    switch (status) {
      case RfidReaderStatus.connected:
        return 'قارئ RFID متصل';
      case RfidReaderStatus.disconnected:
        return 'قارئ RFID غير متصل';
      case RfidReaderStatus.scanning:
        return 'جاري المسح...';
      case RfidReaderStatus.connecting:
        return 'جاري الاتصال...';
      case RfidReaderStatus.error:
        return 'خطأ في الاتصال';
    }
  }

  Widget _buildScanningArea(AsyncValue<RfidReaderStatus> rfidStatus) {
    final isScanning = rfidStatus.asData?.value == RfidReaderStatus.scanning;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isScanning
            ? CupertinoColors.activeBlue.withValues(alpha: 0.1)
            : CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isScanning
              ? CupertinoColors.activeBlue
              : CupertinoColors.systemGrey4,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isScanning) ...[
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_animation.value * 0.3),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeBlue.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.wifi,
                      size: 50,
                      color: CupertinoColors.activeBlue,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'جاري البحث عن بطاقة RFID...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.activeBlue,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'ضع البطاقة بالقرب من القارئ',
              style: TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          ] else if (_scannedTag != null) ...[
            const Icon(
              CupertinoIcons.checkmark_circle_fill,
              size: 80,
              color: CupertinoColors.activeGreen,
            ),
            const SizedBox(height: 20),
            const Text(
              'تم العثور على البطاقة!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.activeGreen,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'رقم البطاقة: $_scannedTag',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ] else ...[
            const Icon(
              CupertinoIcons.wifi,
              size: 80,
              color: CupertinoColors.systemGrey3,
            ),
            const SizedBox(height: 20),
            const Text(
              'اضغط "بدء المسح" لقراءة البطاقة',
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(AsyncValue<RfidReaderStatus> rfidStatus) {
    final status = rfidStatus.asData?.value;
    final isScanning = status == RfidReaderStatus.scanning;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (!isScanning && _scannedTag == null) ...[
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: _startScanning,
                child: const Text('بدء المسح'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                onPressed: _testConnection,
                child: const Text('اختبار الاتصال'),
              ),
            ),
          ] else if (isScanning) ...[
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: CupertinoColors.systemRed,
                onPressed: () =>
                    ref.read(rfidNotifierProvider.notifier).stopScanning(),
                child: const Text('إيقاف المسح'),
              ),
            ),
          ] else if (_scannedTag != null) ...[
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: _linkRfidTag,
                child: const Text('ربط البطاقة'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                onPressed: _resetScanning,
                child: const Text('مسح مرة أخرى'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _resetScanning() {
    setState(() {
      _scannedTag = null;
    });
    _startScanning();
  }

  Future<void> _startScanning() async {
    final rfidNotifier = ref.read(rfidNotifierProvider.notifier);
    final currentStatus = ref.read(rfidNotifierProvider);

    // التحقق من حالة الاتصال
    final isConnected = currentStatus.when(
      data: (status) =>
          status == RfidReaderStatus.connected ||
          status == RfidReaderStatus.scanning,
      loading: () => false,
      error: (_, __) => false,
    );

    if (!isConnected) {
      // محاولة الاتصال أولاً
      try {
        await rfidNotifier.connect(
          port: 'COM3',
          baudRate: 115200,
          timeout: 5000,
        );
        // انتظار قصير للتأكد من الاتصال
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('خطأ في الاتصال'),
              content: const Text(
                'لا يمكن الاتصال بقارئ RFID. تأكد من توصيل الجهاز وإعدادات المنفذ.',
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('موافق'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    // بدء المسح
    try {
      await rfidNotifier.startScanning();
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('خطأ في المسح'),
            content: Text('فشل في بدء مسح RFID: $e'),
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
  }

  Future<void> _linkRfidTag() async {
    if (_scannedTag == null) return;

    try {
      final itemNotifier = ref.read(itemNotifierProvider.notifier);
      await itemNotifier.linkRfidTag(widget.item.id!, _scannedTag!);

      // تحديث جميع مزودي البيانات المتعلقة بالأصناف
      ref.invalidate(itemByIdProvider(widget.item.id!));
      ref.invalidate(itemsProvider);
      ref.invalidate(itemNotifierProvider);
      ref.invalidate(inventoryStatsProvider);
      ref.invalidate(itemsByStatusProvider(ItemStatus.needsRfid));
      ref.invalidate(itemsByStatusProvider(ItemStatus.inStock));

      // إيقاف المسح نهائياً
      await ref.read(rfidNotifierProvider.notifier).stopScanning();

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('تم بنجاح'),
            content: Text(
              'تم ربط البطاقة $_scannedTag بالصنف ${widget.item.sku}',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('موافق'),
                onPressed: () {
                  Navigator.pop(context); // إغلاق الحوار
                  Navigator.pop(context); // العودة للشاشة السابقة
                  // تحديث إضافي لضمان تحديث البيانات
                  Future.delayed(const Duration(milliseconds: 100), () {
                    ref.read(itemNotifierProvider.notifier).refresh();
                  });
                },
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('خطأ'),
            content: Text('حدث خطأ أثناء ربط البطاقة: $error'),
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
  }

  Future<void> _testConnection() async {
    try {
      final rfidNotifier = ref.read(rfidNotifierProvider.notifier);
      await rfidNotifier.testConnection();

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('نجح الاختبار'),
            content: const Text('تم الاتصال بقارئ RFID بنجاح'),
            actions: [
              CupertinoDialogAction(
                child: const Text('موافق'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('فشل الاختبار'),
            content: Text('فشل في اختبار الاتصال: $e'),
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
  }
}
