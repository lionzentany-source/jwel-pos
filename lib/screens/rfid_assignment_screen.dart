import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/app_button.dart';
import '../services/rfid_service.dart';
import '../services/rfid_device_assignments.dart';

class RfidAssignmentScreen extends ConsumerStatefulWidget {
  const RfidAssignmentScreen({super.key});

  @override
  ConsumerState<RfidAssignmentScreen> createState() =>
      _RfidAssignmentScreenState();
}

class _RfidAssignmentScreenState extends ConsumerState<RfidAssignmentScreen> {
  final _assign = RfidDeviceAssignmentsStorage();
  final _interfaces = const ['USB', 'CDC_COM', 'BLE'];

  final Map<RfidRole, TextEditingController> _idCtrls = {
    for (final role in RfidRole.values) role: TextEditingController(),
  };
  final Map<RfidRole, String> _iface = {
    for (final role in RfidRole.values) role: 'USB',
  };
  final Map<RfidRole, TextEditingController> _baudCtrls = {
    for (final role in RfidRole.values)
      role: TextEditingController(text: '115200'),
  };

  List<String> _ports = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final map = await _assign.loadAll();
    if (!mounted) return;
    setState(() {
      for (final e in map.entries) {
        _iface[e.key] = e.value.interface;
        _idCtrls[e.key]!.text = e.value.identifier;
        _baudCtrls[e.key]!.text = e.value.baudRate.toString();
      }
      _ports = RfidServiceReal().enumeratePorts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F8FA),
      child: AdaptiveScaffold(
        title: 'تعيين أجهزة قارئ RFID حسب الشاشة',
        showBackButton: true,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _card('شاشة البيع (الكاشير)', _buildRow(RfidRole.cashier)),
              const SizedBox(height: 16),
              _card('قارئ الباب (منع السرقة)', _buildRow(RfidRole.gate)),
              const SizedBox(height: 16),
              _card('المخزون والجرد', _buildRow(RfidRole.inventory)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  text: 'حفظ التعيينات',
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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

  Widget _buildRow(RfidRole role) {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 120, child: Text('الواجهة')),
            Expanded(
              child: CupertinoSlidingSegmentedControl<String>(
                groupValue: _iface[role],
                children: {
                  for (final x in _interfaces)
                    x: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(x, style: const TextStyle(fontSize: 12)),
                    ),
                },
                onValueChanged: (v) =>
                    setState(() => _iface[role] = v ?? 'USB'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 120, child: Text('المعرف')),
            Expanded(
              child: (_iface[role] == 'USB' || _iface[role] == 'CDC_COM')
                  ? (_ports.isEmpty
                        ? CupertinoTextField(
                            controller: _idCtrls[role],
                            placeholder: 'COM3',
                            padding: const EdgeInsets.all(12),
                          )
                        : CupertinoButton(
                            color: CupertinoColors.systemGrey5,
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            onPressed: () async {
                              final selected =
                                  await showCupertinoModalPopup<String>(
                                    context: context,
                                    builder: (c) => CupertinoActionSheet(
                                      title: const Text('اختر منفذاً'),
                                      actions: [
                                        for (final p in _ports)
                                          CupertinoActionSheetAction(
                                            onPressed: () =>
                                                Navigator.pop(c, p),
                                            child: Text(p),
                                          ),
                                      ],
                                      cancelButton: CupertinoActionSheetAction(
                                        onPressed: () => Navigator.pop(c),
                                        isDefaultAction: true,
                                        child: const Text('إلغاء'),
                                      ),
                                    ),
                                  );
                              if (selected != null) {
                                setState(() => _idCtrls[role]!.text = selected);
                              }
                            },
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _idCtrls[role]!.text.isEmpty
                                    ? 'اختر منفذاً'
                                    : _idCtrls[role]!.text,
                              ),
                            ),
                          ))
                  : CupertinoTextField(
                      controller: _idCtrls[role],
                      placeholder: 'BLE Name/ID',
                      padding: const EdgeInsets.all(12),
                    ),
            ),
            if (_iface[role] == 'USB' || _iface[role] == 'CDC_COM') ...[
              const SizedBox(width: 8),
              AppButton.secondary(
                text: 'تحديث',
                onPressed: _refreshPorts,
                height: 36,
              ),
            ],
          ],
        ),
        if (_iface[role] == 'USB' || _iface[role] == 'CDC_COM') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 120, child: Text('Baud Rate')),
              Expanded(
                child: CupertinoTextField(
                  controller: _baudCtrls[role],
                  keyboardType: TextInputType.number,
                  padding: const EdgeInsets.all(12),
                  placeholder: '115200',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _refreshPorts() {
    setState(() {
      _ports = RfidServiceReal().enumeratePorts();
    });
  }

  Future<void> _save() async {
    for (final role in RfidRole.values) {
      final cfg = RfidDeviceConfig(
        interface: _iface[role]!,
        identifier: _idCtrls[role]!.text.trim(),
        baudRate: int.tryParse(_baudCtrls[role]!.text) ?? 115200,
      );
      await _assign.save(role, cfg);
    }
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (c) => const CupertinoAlertDialog(
        title: Text('تم'),
        content: Text('تم حفظ تعيينات الأجهزة'),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.pop(context);
  }
}
