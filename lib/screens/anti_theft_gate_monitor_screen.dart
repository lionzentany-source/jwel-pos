import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/adaptive_scaffold.dart';
import '../services/rfid_service.dart';
import '../services/rfid_device_assignments.dart';
import '../providers/rfid_role_reader_provider.dart';

class AntiTheftGateMonitorScreen extends ConsumerStatefulWidget {
  const AntiTheftGateMonitorScreen({super.key});

  @override
  ConsumerState<AntiTheftGateMonitorScreen> createState() =>
      _AntiTheftGateMonitorScreenState();
}

class _AntiTheftGateMonitorScreenState
    extends ConsumerState<AntiTheftGateMonitorScreen> {
  final List<_TagEvent> _events = [];
  StreamSubscription<String>? _sub;
  RfidServiceReal? _reader;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  Future<void> _attach() async {
    final r = await ref.read(rfidReaderForRoleProvider(RfidRole.gate).future);
    setState(() => _reader = r);
    _sub?.cancel();
    _sub = r.tagStream.listen((epc) {
      setState(() {
        _events.insert(0, _TagEvent(epc: epc, time: DateTime.now()));
        if (_events.length > 200) _events.removeLast();
      });
    });
    // ensure scanning to get live data
    if (r.currentStatus == RfidReaderStatus.connected) {
      await r.startScanning();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F8FA),
      child: AdaptiveScaffold(
        title: 'قراءات قارئ الباب (مباشر)',
        showBackButton: true,
        body: Column(
          children: [
            _statusBar(),
            Expanded(child: _list()),
          ],
        ),
      ),
    );
  }

  Widget _statusBar() {
    final connected =
        _reader?.currentStatus == RfidReaderStatus.connected ||
        _reader?.currentStatus == RfidReaderStatus.scanning;
    return Container(
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
            onPressed: _refresh,
            child: const Text('إعادة الاتصال'),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    await _reader?.stopScanning();
    await _reader?.disconnect();
    await _attach();
  }

  Widget _list() {
    if (_events.isEmpty) {
      return const Center(child: Text('لا توجد قراءات بعد'));
    }
    return ListView.builder(
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
              BoxShadow(color: m.Colors.black.withAlpha(10), blurRadius: 6),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(e.epc, style: const TextStyle(fontFamily: 'monospace')),
              Text(
                _fmt(e.time),
                style: const TextStyle(color: CupertinoColors.secondaryLabel),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}

class _TagEvent {
  final String epc;
  final DateTime time;
  _TagEvent({required this.epc, required this.time});
}
