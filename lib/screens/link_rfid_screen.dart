import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/app_button.dart';

import '../widgets/adaptive_scaffold.dart';
import '../models/item.dart';
import '../providers/item_provider.dart';
import '../services/rfid_service.dart'; // RfidReaderStatus, RfidServiceReal
import '../providers/rfid_role_reader_provider.dart'; // role-based reader provider
import '../services/rfid_session_coordinator.dart';
import '../services/rfid_device_assignments.dart'; // RfidRole enum
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
  bool _rfidListenerAttached = false; // منع تعدد الإرفاقات
  RfidServiceReal? _reader; // قارئ خاص لدور الكاشير
  StreamSubscription<String>? _tagSub;
  StreamSubscription<RfidReaderStatus>? _statusSub;
  RfidReaderStatus _status = RfidReaderStatus.disconnected;

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

    // Initialize role-based RFID reader after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRoleReader();
    });
  }

  Future<void> _loadRoleReader() async {
    try {
      final r = await ref.read(
        rfidReaderForRoleProvider(RfidRole.cashier).future,
      );
      if (!mounted) return;
      setState(() {
        _reader = r;
        _status = r.currentStatus;
      });
      _statusSub = r.statusStream.listen((s) {
        if (!mounted) return;
        setState(() => _status = s);
      });
      if (!_rfidListenerAttached) {
        _rfidListenerAttached = true;
        _tagSub = r.tagStream.listen((tagId) {
          if (mounted && _scannedTag == null) {
            if (!RfidDuplicateFilter.shouldProcess(tagId)) {
              debugPrint('🔁 تجاهل بطاقة مكررة (ربط): $tagId');
              return;
            }
            setState(() => _scannedTag = tagId);
            _animationController.stop();
            _reader?.stopScanning();
            RfidSessionCoordinator.instance.setCashierActive(false);
          }
        });
      }
    } catch (e) {
      debugPrint('فشل تحميل قارئ الدور: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    // إيقاف المسح عند الخروج من الشاشة وإلغاء الاشتراكات
    try {
      _reader?.stopScanning();
    } catch (_) {}
    try {
      _tagSub?.cancel();
    } catch (_) {}
    try {
      _statusSub?.cancel();
    } catch (_) {}
    RfidSessionCoordinator.instance.setCashierActive(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rfidStatus = AsyncValue.data(_status);

    // Control animation based on scanning state
    if (_status == RfidReaderStatus.scanning &&
        !_animationController.isAnimating) {
      _animationController.repeat();
    } else if (_status != RfidReaderStatus.scanning &&
        _animationController.isAnimating) {
      _animationController.stop();
    }

    return Container(
      color: Color(0xfff6f8fa), // خلفية موحدة
      child: AdaptiveScaffold(
        title: 'ربط بطاقة RFID',
        showBackButton: false,
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
      ),
    );
  }

  Widget _buildItemInfo() {
    return AdaptiveCard(
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
              child: AppButton.primary(
                text: 'بدء المسح',
                onPressed: _startScanning,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: AppButton.secondary(
                text: 'اختبار الاتصال',
                onPressed: _testConnection,
              ),
            ),
          ] else if (isScanning) ...[
            SizedBox(
              width: double.infinity,
              child: AppButton.destructive(
                text: 'إيقاف المسح',
                onPressed: () async {
                  await _reader?.stopScanning();
                  RfidSessionCoordinator.instance.setCashierActive(false);
                  setState(() {});
                },
              ),
            ),
          ] else if (_scannedTag != null) ...[
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                text: 'ربط البطاقة',
                onPressed: _linkRfidTag,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: AppButton.secondary(
                text: 'مسح مرة أخرى',
                onPressed: _resetScanning,
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
    if (_reader == null) {
      await _loadRoleReader();
      if (_reader == null) return;
    }
    // Guard: must be connected
    if (_reader!.currentStatus == RfidReaderStatus.disconnected) {
      // Attempt to connect via assignment provider again
      await _loadRoleReader();
    }
    if (_reader!.currentStatus == RfidReaderStatus.connected ||
        _reader!.currentStatus == RfidReaderStatus.scanning) {
      try {
        RfidSessionCoordinator.instance.setCashierActive(true);
        await _reader!.startScanning();
        setState(() {});
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
    } else {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => const CupertinoAlertDialog(
            title: Text('القارئ غير متصل'),
            content: Text('يرجى تعيين جهاز الكاشير والاتصال به من الإعدادات.'),
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

      // إيقاف المسح نهائياً للقارئ الخاص بالشاشة
      try {
        await _reader?.stopScanning();
      } catch (_) {}
      RfidSessionCoordinator.instance.setCashierActive(false);

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
      if (_reader == null) await _loadRoleReader();
      await _reader?.testConnection();

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
