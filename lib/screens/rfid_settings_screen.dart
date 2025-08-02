import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/adaptive_scaffold.dart';
import '../providers/rfid_provider.dart';
import '../services/rfid_service.dart';
import '../services/rfid_settings_storage.dart';

class RfidSettingsScreen extends ConsumerStatefulWidget {
  const RfidSettingsScreen({super.key});

  @override
  ConsumerState<RfidSettingsScreen> createState() => _RfidSettingsScreenState();
}

class _RfidSettingsScreenState extends ConsumerState<RfidSettingsScreen> {
  final _portController = TextEditingController(text: 'COM3');
  final _baudRateController = TextEditingController(text: '115200');
  final _powerController = TextEditingController(text: '30');
  final _timeoutController = TextEditingController(text: '5000');
  final _deviceAddressController = TextEditingController(text: '0');
  final _startFreqController = TextEditingController(text: '920.125');
  final _endFreqController = TextEditingController(text: '924.875');
  final _settingsStorage = RfidSettingsStorage();
  List<String> _availablePorts = const [];

  bool _autoConnect = true;
  bool _continuousMode = false;
  bool _beepOnRead = true;
  bool _singleFrequency = false;

  String _selectedRegion = 'Custom';
  String _selectedInterface = 'USB';

  final List<String> _interfaces = ['USB', 'KeyBoard', 'CDC_COM'];

  final Map<String, Map<String, double>> _regionFrequencies = {
    'USA': {'start': 902.75, 'end': 927.25},
    'Europe': {'start': 865.7, 'end': 867.5},
    'Korea': {'start': 917.3, 'end': 920.3},
    'Japan': {'start': 916.8, 'end': 920.4},
    'China_1': {'start': 920.125, 'end': 924.875},
    'China_2': {'start': 840.125, 'end': 844.875},
  };

  @override
  void initState() {
    super.initState();
    _loadPersistedSettings();
  }

  Future<void> _loadPersistedSettings() async {
    try {
      final m = await _settingsStorage.load();
      if (!mounted) return;
      setState(() {
        _portController.text = m['port'];
        _baudRateController.text = (m['baud']).toString();
        _timeoutController.text = (m['timeout']).toString();
        _deviceAddressController.text = m['deviceAddress'];
        _startFreqController.text = (m['startFreq']).toString();
        _endFreqController.text = (m['endFreq']).toString();
        _singleFrequency = m['singleFreq'];
        _selectedRegion = m['region'];
        _selectedInterface = m['interface'];
        _autoConnect = m['autoConnect'];
        _continuousMode = m['continuous'];
        _beepOnRead = m['beepOnRead'];
        _powerController.text = (m['power']).toString();
      });
      _refreshPorts();
      // تطبيق الإعدادات على الخدمة (خاصة التنبيه الصوتي)
      ref.read(rfidNotifierProvider.notifier).setBeepOnRead(_beepOnRead);
      if (_autoConnect) {
        // محاولة الاتصال بعد تحميل الإعدادات
        Future.microtask(() => _connect());
      }
    } catch (e) {
      debugPrint('Failed to load persisted RFID settings: $e');
    }
  }

  void _refreshPorts() {
    try {
      final ports = RfidServiceReal().enumeratePorts();
      setState(() {
        _availablePorts = ports;
      });
    } catch (e) {
      debugPrint('فشل في جلب المنافذ: $e');
    }
  }

  @override
  void dispose() {
    _portController.dispose();
    _baudRateController.dispose();
    _powerController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rfidStatus = ref.watch(rfidNotifierProvider);

    // محاولة الاتصال تلقائياً إذا مفعّل ولم يتم الاتصال
    rfidStatus.whenData((status) {
      if (_autoConnect && status == RfidReaderStatus.disconnected) {
        Future.microtask(() {
          if (mounted) _connect();
        });
      }
    });

    return AdaptiveScaffold(
      title: 'إعدادات RFID',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildConnectionSection(rfidStatus),
            const SizedBox(height: 20),
            _buildPortSettings(),
            const SizedBox(height: 20),
            _buildPowerSettings(),
            const SizedBox(height: 20),
            _buildFrequencySettings(),
            const SizedBox(height: 20),
            _buildAdvancedSettings(),
            const SizedBox(height: 20),
            _buildScanSettings(),
            const SizedBox(height: 20),
            _buildTestSection(rfidStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionSection(AsyncValue<RfidReaderStatus> rfidStatus) {
    final status = rfidStatus.asData?.value ?? RfidReaderStatus.disconnected;
    final isConnected =
        status == RfidReaderStatus.connected ||
        status == RfidReaderStatus.scanning;

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
            'حالة الاتصال',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isConnected
                      ? CupertinoColors.activeGreen
                      : CupertinoColors.systemRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getStatusText(status),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isConnected
                        ? CupertinoColors.activeGreen
                        : CupertinoColors.systemRed,
                  ),
                ),
              ),
              if (rfidStatus.isLoading)
                const CupertinoActivityIndicator()
              else
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: isConnected ? _disconnect : _connect,
                  child: Text(isConnected ? 'قطع الاتصال' : 'اتصال'),
                ),
            ],
          ),
          if (rfidStatus.hasError) ...[
            const SizedBox(height: 8),
            Text(
              'خطأ: ${rfidStatus.error}',
              style: const TextStyle(
                color: CupertinoColors.systemRed,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPortSettings() {
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
            'إعدادات المنفذ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _buildSettingRow(
            'منفذ الاتصال',
            Row(
              children: [
                Expanded(
                  child: _availablePorts.isEmpty
                      ? CupertinoTextField(
                          controller: _portController,
                          placeholder: 'COM3',
                          padding: const EdgeInsets.all(12),
                        )
                      : CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          color: CupertinoColors.systemGrey5,
                          onPressed: () async {
                            final selected =
                                await showCupertinoModalPopup<String>(
                                  context: context,
                                  builder: (context) => CupertinoActionSheet(
                                    title: const Text('اختر منفذاً'),
                                    actions: [
                                      for (final p in _availablePorts)
                                        CupertinoActionSheetAction(
                                          onPressed: () =>
                                              Navigator.pop(context, p),
                                          child: Text(p),
                                        ),
                                    ],
                                    cancelButton: CupertinoActionSheetAction(
                                      onPressed: () => Navigator.pop(context),
                                      isDefaultAction: true,
                                      child: const Text('إلغاء'),
                                    ),
                                  ),
                                );
                            if (selected != null) {
                              setState(() => _portController.text = selected);
                            }
                          },
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _portController.text.isEmpty
                                  ? 'اختر منفذاً'
                                  : _portController.text,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  onPressed: _refreshPorts,
                  child: const Text('تحديث', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingRow(
            'معدل البود',
            CupertinoTextField(
              controller: _baudRateController,
              keyboardType: TextInputType.number,
              placeholder: '115200',
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingRow(
            'مهلة الاتصال (مللي ثانية)',
            CupertinoTextField(
              controller: _timeoutController,
              keyboardType: TextInputType.number,
              placeholder: '5000',
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingRow(
            'واجهة الاتصال',
            CupertinoSlidingSegmentedControl<String>(
              groupValue: _selectedInterface,
              children: {
                for (String interface in _interfaces)
                  interface: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      interface,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              },
              onValueChanged: (value) {
                setState(() {
                  _selectedInterface = value!;
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الاتصال التلقائي'),
              CupertinoSwitch(
                value: _autoConnect,
                onChanged: (value) {
                  setState(() {
                    _autoConnect = value;
                  });
                  if (value) {
                    final status = ref.read(rfidNotifierProvider).asData?.value;
                    if (status == RfidReaderStatus.disconnected) {
                      _connect();
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPowerSettings() {
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
            'إعدادات الطاقة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _buildSettingRow(
            'قوة الإشارة (dBm)',
            Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: _powerController,
                    keyboardType: TextInputType.number,
                    placeholder: '30',
                    padding: const EdgeInsets.all(12),
                    onChanged: (value) {
                      final power = double.tryParse(value) ?? 30.0;
                      if (power >= 0 && power <= 20) {
                        // تحديث الشريط التمرير
                        setState(() {});
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'dBm',
                  style: TextStyle(color: CupertinoColors.secondaryLabel),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'النطاق المسموح: 0-20 dBm (حسب التطبيق المكتبي)',
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 16),
          CupertinoSlider(
            value: (double.tryParse(_powerController.text) ?? 20.0).clamp(
              0.0,
              20.0,
            ),
            min: 0.0,
            max: 20.0,
            divisions: 20,
            onChanged: (value) {
              setState(() {
                _powerController.text = value.round().toString();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencySettings() {
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
            'إعدادات التردد',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _buildSettingRow(
            'المنطقة الجغرافية',
            CupertinoSlidingSegmentedControl<String>(
              groupValue: _selectedRegion,
              children: {
                'Custom': const Text('مخصص', style: TextStyle(fontSize: 11)),
                'USA': const Text('أمريكا', style: TextStyle(fontSize: 11)),
                'Europe': const Text('أوروبا', style: TextStyle(fontSize: 11)),
                'China_1': const Text(
                  'الصين 1',
                  style: TextStyle(fontSize: 11),
                ),
              },
              onValueChanged: (value) {
                setState(() {
                  _selectedRegion = value!;
                  _updateFrequencyForRegion(value);
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('تردد واحد'),
              CupertinoSwitch(
                value: _singleFrequency,
                onChanged: (value) {
                  setState(() {
                    _singleFrequency = value;
                    if (value) {
                      _endFreqController.text = _startFreqController.text;
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSettingRow(
            'التردد الابتدائي (MHz)',
            CupertinoTextField(
              controller: _startFreqController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              placeholder: '920.125',
              padding: const EdgeInsets.all(12),
              onChanged: (value) {
                if (_singleFrequency) {
                  _endFreqController.text = value;
                }
              },
            ),
          ),
          if (!_singleFrequency) ...[
            const SizedBox(height: 12),
            _buildSettingRow(
              'التردد النهائي (MHz)',
              CupertinoTextField(
                controller: _endFreqController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                placeholder: '924.875',
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdvancedSettings() {
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
            'الإعدادات المتقدمة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _buildSettingRow(
            'عنوان الجهاز (HEX)',
            CupertinoTextField(
              controller: _deviceAddressController,
              placeholder: '0',
              padding: const EdgeInsets.all(12),
              inputFormatters: [
                // تحديد الإدخال للأرقام السادس عشرية
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'عنوان الجهاز بالنظام السادس عشري (0-FE)',
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanSettings() {
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
            'إعدادات المسح',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المسح المستمر'),
              CupertinoSwitch(
                value: _continuousMode,
                onChanged: (value) {
                  setState(() {
                    _continuousMode = value;
                  });
                  final notifier = ref.read(rfidNotifierProvider.notifier);
                  final status = ref.read(rfidNotifierProvider).asData?.value;
                  if (value) {
                    if (status == RfidReaderStatus.connected) {
                      notifier.startScanning();
                    }
                  } else {
                    if (status == RfidReaderStatus.scanning) {
                      notifier.stopScanning();
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('صوت تنبيه عند القراءة'),
              CupertinoSwitch(
                value: _beepOnRead,
                onChanged: (value) {
                  setState(() {
                    _beepOnRead = value;
                  });
                  ref.read(rfidNotifierProvider.notifier).setBeepOnRead(value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestSection(AsyncValue<RfidReaderStatus> rfidStatus) {
    final status = rfidStatus.asData?.value ?? RfidReaderStatus.disconnected;
    final isConnected =
        status == RfidReaderStatus.connected ||
        status == RfidReaderStatus.scanning;

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
            'اختبار الجهاز',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CupertinoButton.filled(
                  onPressed: isConnected ? _testRead : null,
                  child: const Text('اختبار قراءة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoButton(
                  color: CupertinoColors.systemOrange,
                  onPressed: isConnected ? _testBeep : null,
                  child: const Text('اختبار الصوت'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  color: CupertinoColors.systemPurple,
                  onPressed: isConnected ? _getDeviceInfo : null,
                  child: const Text(
                    'معلومات الجهاز',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoButton(
                  color: CupertinoColors.systemRed,
                  onPressed: isConnected ? _initializeDevice : null,
                  child: const Text(
                    'إعادة تهيئة',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: CupertinoColors.systemGrey,
              onPressed: _saveSettings,
              child: const Text('حفظ الإعدادات'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, Widget control) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(child: control),
      ],
    );
  }

  String _getStatusText(RfidReaderStatus status) {
    switch (status) {
      case RfidReaderStatus.connected:
        return 'متصل وجاهز';
      case RfidReaderStatus.disconnected:
        return 'غير متصل';
      case RfidReaderStatus.scanning:
        return 'جاري المسح...';
      case RfidReaderStatus.connecting:
        return 'جاري الاتصال...';
      case RfidReaderStatus.error:
        return 'خطأ في الاتصال';
    }
  }

  void _connect() {
    ref
        .read(rfidNotifierProvider.notifier)
        .connect(
          port: _portController.text,
          baudRate: int.tryParse(_baudRateController.text) ?? 115200,
          timeout: int.tryParse(_timeoutController.text) ?? 5000,
          deviceAddress: _deviceAddressController.text,
          interface: _selectedInterface,
          startFreq: double.tryParse(_startFreqController.text),
          endFreq: double.tryParse(_endFreqController.text),
          singleFrequency: _singleFrequency,
        );
  }

  void _disconnect() {
    ref.read(rfidNotifierProvider.notifier).disconnect();
  }

  void _testRead() async {
    try {
      ref.read(rfidNotifierProvider.notifier).startScanning();

      // انتظار لمدة 5 ثوان للقراءة
      await Future.delayed(const Duration(seconds: 5));

      ref.read(rfidNotifierProvider.notifier).stopScanning();

      _showMessage('تم اختبار القراءة', 'تم تشغيل وإيقاف المسح بنجاح');
    } catch (e) {
      _showError('خطأ في الاختبار', e.toString());
    }
  }

  void _testBeep() async {
    try {
      final rfidService = RfidServiceReal();
      final success = await rfidService.playBeep();
      if (success) {
        _showMessage('اختبار الصوت', 'تم تشغيل صوت التنبيه بنجاح');
      } else {
        _showError('خطأ في الاختبار', 'فشل في تشغيل صوت التنبيه');
      }
    } catch (e) {
      _showError('خطأ في الاختبار', e.toString());
    }
  }

  void _getDeviceInfo() async {
    try {
      final rfidService = RfidServiceReal();
      final info = await rfidService.getDeviceInfo();
      if (info != null) {
        final infoText = info.entries
            .map((e) => '${_translateInfoKey(e.key)}: ${e.value}')
            .join('\n');
        _showMessage('معلومات الجهاز', infoText);
      } else {
        _showError('خطأ', 'فشل في الحصول على معلومات الجهاز');
      }
    } catch (e) {
      _showError('خطأ', e.toString());
    }
  }

  void _initializeDevice() async {
    try {
      final result = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('تأكيد إعادة التهيئة'),
          content: const Text(
            'هل أنت متأكد من إعادة تهيئة الجهاز؟\nسيتم إعادة تعيين جميع الإعدادات للقيم الافتراضية.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('إلغاء'),
              onPressed: () => Navigator.pop(context, false),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('إعادة تهيئة'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );

      if (result == true) {
        final rfidService = RfidServiceReal();
        final success = await rfidService.initializeDevice();
        if (success) {
          // إعادة تعيين القيم للافتراضية
          setState(() {
            _portController.text = 'COM3';
            _baudRateController.text = '115200';
            _powerController.text = '20';
            _timeoutController.text = '5000';
            _deviceAddressController.text = '0';
            _startFreqController.text = '920.125';
            _endFreqController.text = '924.875';
            _selectedRegion = 'China_1';
            _selectedInterface = 'USB';
            _autoConnect = true;
            _continuousMode = false;
            _beepOnRead = true;
            _singleFrequency = false;
          });
          _showMessage('نجح', 'تم إعادة تهيئة الجهاز بنجاح');
        } else {
          _showError('خطأ', 'فشل في إعادة تهيئة الجهاز');
        }
      }
    } catch (e) {
      _showError('خطأ', e.toString());
    }
  }

  String _translateInfoKey(String key) {
    switch (key) {
      case 'model':
        return 'الطراز';
      case 'version':
        return 'الإصدار';
      case 'power':
        return 'القوة';
      case 'frequency':
        return 'التردد';
      case 'interface':
        return 'الواجهة';
      case 'status':
        return 'الحالة';
      default:
        return key;
    }
  }

  void _updateFrequencyForRegion(String region) {
    if (_regionFrequencies.containsKey(region)) {
      final frequencies = _regionFrequencies[region]!;
      _startFreqController.text = frequencies['start']!.toString();
      _endFreqController.text = frequencies['end']!.toString();
    }
  }

  void _saveSettings() {
    // التحقق من صحة البيانات
    final power = double.tryParse(_powerController.text);
    if (power == null || power < 0 || power > 20) {
      _showError('خطأ في البيانات', 'قوة الإشارة يجب أن تكون بين 0 و 20 dBm');
      return;
    }

    final startFreq = double.tryParse(_startFreqController.text);
    final endFreq = double.tryParse(_endFreqController.text);
    if (startFreq == null || endFreq == null) {
      _showError('خطأ في البيانات', 'يرجى إدخال ترددات صحيحة');
      return;
    }

    if (startFreq > endFreq && !_singleFrequency) {
      _showError(
        'خطأ في البيانات',
        'التردد الابتدائي يجب أن يكون أقل من النهائي',
      );
      return;
    }

    // حفظ الإعدادات في SharedPreferences
    // ملاحظة: نحفظ power كـ int لتوافق مع واجهة الجهاز (نستخدم القيمة في النطاق الحالي 0-20)
    _settingsStorage.save({
      'port': _portController.text,
      'baud': int.tryParse(_baudRateController.text) ?? 115200,
      'timeout': int.tryParse(_timeoutController.text) ?? 5000,
      'deviceAddress': _deviceAddressController.text,
      'startFreq': startFreq,
      'endFreq': _singleFrequency ? startFreq : endFreq,
      'singleFreq': _singleFrequency,
      'region': _selectedRegion,
      'interface': _selectedInterface,
      'autoConnect': _autoConnect,
      'continuous': _continuousMode,
      'beepOnRead': _beepOnRead,
      'power': power.round(),
    });

    final notifier = ref.read(rfidNotifierProvider.notifier);
    final wasScanning =
        ref.read(rfidNotifierProvider).asData?.value ==
        RfidReaderStatus.scanning;

    notifier
        .connect(
          port: _portController.text,
          baudRate: int.tryParse(_baudRateController.text) ?? 115200,
          timeout: int.tryParse(_timeoutController.text) ?? 5000,
          deviceAddress: _deviceAddressController.text,
          interface: _selectedInterface,
          startFreq: startFreq,
          endFreq: _singleFrequency ? startFreq : endFreq,
          singleFrequency: _singleFrequency,
        )
        .then((_) async {
          await notifier.setPower(power.round());
          notifier.setBeepOnRead(_beepOnRead);
          if (_continuousMode) {
            await notifier.startScanning();
          } else if (wasScanning) {
            await notifier.stopScanning();
          }
          _showMessage('تم الحفظ', 'تم حفظ وتطبيق إعدادات RFID بنجاح');
        });
  }

  void _showMessage(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
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

  void _showError(String title, String error) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(error),
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
