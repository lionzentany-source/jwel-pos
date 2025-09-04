import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/app_button.dart';
import '../providers/anti_theft_provider.dart';
import '../services/anti_theft_settings_storage.dart';
import '../services/rfid_service.dart';
import '../providers/rfid_role_reader_provider.dart';
import '../services/rfid_device_assignments.dart';

class AntiTheftSettingsScreen extends ConsumerStatefulWidget {
  const AntiTheftSettingsScreen({super.key});

  @override
  ConsumerState<AntiTheftSettingsScreen> createState() =>
      _AntiTheftSettingsScreenState();
}

class _AntiTheftSettingsScreenState
    extends ConsumerState<AntiTheftSettingsScreen> {
  final _storage = AntiTheftSettingsStorage();
  final _portCtrl = TextEditingController(text: 'COM4');
  bool _enabled = false;
  bool _autoConnect = true;
  bool _continuous = true;
  String _interface = 'USB';
  int _cooldownSec = 15;
  bool _useAssignedGate = true; // استخدم تعيين الجهاز لدور الباب
  bool _suppressDuringCashier = false; // كتم أثناء مسح الكاشير

  // Tabs: 0 = settings, 1 = live monitor
  int _selectedTab = 0;
  // Live monitor state
  final List<_TagEvent> _events = [];
  StreamSubscription<String>? _sub;
  RfidServiceReal? _reader;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await _storage.load();
    if (!mounted) return;
    setState(() {
      _enabled = m['enabled'] as bool;
      _autoConnect = m['autoConnect'] as bool;
      _continuous = m['continuous'] as bool;
      _portCtrl.text = m['port'] as String;
      _interface = m['interface'] as String;
      _cooldownSec = m['cooldownSec'] as int;
      _useAssignedGate = (m['useAssigned'] as bool?) ?? true;
      _suppressDuringCashier = (m['suppressDuringCashier'] as bool?) ?? false;
    });
    if (_enabled && _autoConnect) {
      _connect();
    }
    // Attach live monitor by default so switching tab is instant
    _attachLiveReader();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F8FA),
      child: AdaptiveScaffold(
        title: 'منع السرقة (قارئ الباب)',
        showBackButton: true,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _selectedTab,
                children: const {
                  0: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('الإعدادات'),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('قراءات مباشرة'),
                  ),
                },
                onValueChanged: (v) {
                  setState(() => _selectedTab = v ?? 0);
                  if (_selectedTab == 1) _attachLiveReader();
                },
              ),
            ),
            Expanded(
              child: _selectedTab == 0
                  ? _buildSettingsContent()
                  : _buildLiveMonitorContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ================= Settings Tab =================
  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _card(
            'الحالة',
            Column(
              children: [
                _rowSwitch('تفعيل النظام', _enabled, (v) {
                  setState(() => _enabled = v);
                }),
                _rowSwitch('اتصال تلقائي', _autoConnect, (v) {
                  setState(() => _autoConnect = v);
                }),
                _rowSwitch('مسح مستمر', _continuous, (v) {
                  setState(() => _continuous = v);
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            'اتصال القارئ',
            Column(
              children: [
                _rowSwitch(
                  'استخدم جهاز الدور (الباب) المعين',
                  _useAssignedGate,
                  (v) {
                    setState(() => _useAssignedGate = v);
                  },
                ),
                const SizedBox(height: 8),
                _row(
                  'المنفذ',
                  CupertinoTextField(
                    controller: _portCtrl,
                    placeholder: 'COM4',
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 8),
                _row(
                  'الواجهة',
                  CupertinoSlidingSegmentedControl<String>(
                    groupValue: _interface,
                    children: const {
                      'USB': Text('USB', style: TextStyle(fontSize: 12)),
                      'CDC_COM': Text('CDC', style: TextStyle(fontSize: 12)),
                    },
                    onValueChanged: (v) =>
                        setState(() => _interface = v ?? 'USB'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.primary(
                        text: 'اتصال وتشغيل',
                        onPressed: _enabled ? _connect : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton.secondary(
                        text: 'قطع الاتصال',
                        onPressed: _disconnect,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            'تهيئة التنبيه',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(
                  'تهدئة (ثواني)',
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoSlider(
                          value: _cooldownSec.toDouble(),
                          min: 5,
                          max: 60,
                          divisions: 11,
                          onChanged: (v) =>
                              setState(() => _cooldownSec = v.round()),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '${_cooldownSec}s',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _rowSwitch('كتم أثناء مسح الكاشير', _suppressDuringCashier, (
                  v,
                ) {
                  setState(() => _suppressDuringCashier = v);
                }),
                const SizedBox(height: 8),
                const Text(
                  'لن يصدر أي رنين لبطاقات غير مسجلة في المنظومة. يتم الرنين فقط للصنف المسجل غير المباع.',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton.primary(text: 'حفظ', onPressed: _save),
          ),
        ],
      ),
    );
  }

  // ================= Live Monitor Tab =================
  Future<void> _attachLiveReader() async {
    try {
      final r = await ref.read(rfidReaderForRoleProvider(RfidRole.gate).future);
      if (!mounted) return;
      setState(() => _reader = r);
      await _sub?.cancel();
      _sub = r.tagStream.listen((epc) {
        if (!mounted) return;
        setState(() {
          _events.insert(0, _TagEvent(epc: epc, time: DateTime.now()));
          if (_events.length > 200) _events.removeLast();
        });
      });
      if (r.currentStatus == RfidReaderStatus.connected) {
        await r.startScanning();
      }
    } catch (_) {
      // ignore attach errors; UI will show disconnected
    }
  }

  Widget _buildLiveMonitorContent() {
    final connected =
        _reader?.currentStatus == RfidReaderStatus.connected ||
        _reader?.currentStatus == RfidReaderStatus.scanning;
    return Column(
      children: [
        // status bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: m.Colors.white,
            boxShadow: [
              BoxShadow(color: m.Colors.black.withAlpha(10), blurRadius: 6),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: connected
                      ? CupertinoColors.activeGreen
                      : CupertinoColors.systemRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(connected ? 'متصل' : 'غير متصل')),
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onPressed: _refreshLiveReader,
                child: const Text('إعادة الاتصال'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _events.isEmpty
              ? const Center(child: Text('لا توجد قراءات بعد'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _events.length,
                  itemBuilder: (_, i) {
                    final e = _events[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: m.Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: m.Colors.black.withAlpha(10),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            e.epc,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                          Text(
                            _fmtTime(e.time),
                            style: const TextStyle(
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _refreshLiveReader() async {
    await _reader?.stopScanning();
    await _reader?.disconnect();
    await _attachLiveReader();
  }

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  Widget _card(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: m.Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: m.Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _row(String label, Widget control) {
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

  Widget _rowSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        CupertinoSwitch(value: value, onChanged: onChanged),
      ],
    );
  }

  Future<void> _connect() async {
    final svc = ref.read(antiTheftServiceProvider);
    svc.cooldown = Duration(seconds: _cooldownSec);
    svc.suppressDuringCashier = _suppressDuringCashier;
    if (_useAssignedGate) {
      await svc.connectUsingAssignedDevice(continuous: _continuous);
    } else {
      await svc.connectAndStart(
        port: _portCtrl.text,
        interface: _interface,
        continuous: _continuous,
      );
    }
  }

  Future<void> _disconnect() async {
    final svc = ref.read(antiTheftServiceProvider);
    await svc.disconnect();
  }

  Future<void> _save() async {
    await _storage.save({
      'enabled': _enabled,
      'autoConnect': _autoConnect,
      'continuous': _continuous,
      'port': _portCtrl.text,
      'interface': _interface,
      'cooldownSec': _cooldownSec,
      'useAssigned': _useAssignedGate,
      'suppressDuringCashier': _suppressDuringCashier,
    });
    if (_enabled && _autoConnect) {
      await _connect();
    }
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (c) => const CupertinoAlertDialog(
        title: Text('تم الحفظ'),
        content: Text('تم حفظ إعدادات منع السرقة'),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class _TagEvent {
  final String epc;
  final DateTime time;
  _TagEvent({required this.epc, required this.time});
}
