import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/adaptive_scaffold.dart';
import '../models/item.dart';
import '../providers/item_provider.dart';
import '../services/rfid_service.dart'; // Import RfidReaderStatus
import '../providers/rfid_provider.dart'; // Import rfidNotifierProvider and rfidTagProvider

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

    // Start scanning when the screen is opened
    ref.read(rfidNotifierProvider.notifier).startScanning();
  }

  @override
  void dispose() {
    _animationController.dispose();
    // Optional: Stop scanning when leaving the screen
    // ref.read(rfidNotifierProvider.notifier).stopScanning();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rfidStatus = ref.watch(rfidNotifierProvider);

    // Listen for new tags
    ref.listen<AsyncValue<String>>(rfidTagProvider, (previous, next) {
      next.whenData((tagId) {
        if (mounted) {
          setState(() {
            _scannedTag = tagId;
          });
          _animationController.stop();
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
            color: CupertinoColors.systemGrey.withOpacity(0.1),
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
            ? CupertinoColors.activeGreen.withOpacity(0.1)
            : CupertinoColors.systemRed.withOpacity(0.1),
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
            ? CupertinoColors.activeBlue.withOpacity(0.1)
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
                      color: CupertinoColors.activeBlue.withOpacity(0.3),
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
                onPressed: () =>
                    ref.read(rfidNotifierProvider.notifier).startScanning(),
                child: const Text('بدء المسح'),
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
    ref.read(rfidNotifierProvider.notifier).startScanning();
  }

  Future<void> _linkRfidTag() async {
    if (_scannedTag == null) return;

    try {
      final itemNotifier = ref.read(itemNotifierProvider.notifier);
      await itemNotifier.linkRfidTag(widget.item.id!, _scannedTag!);

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
}
