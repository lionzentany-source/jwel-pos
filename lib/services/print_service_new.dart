import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:print_usb/print_usb.dart';
import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'package:bluetooth_print_plus/bluetooth_print_model.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class PrintServiceNew {
  static final PrintServiceNew _instance = PrintServiceNew._internal();
  factory PrintServiceNew() => _instance;
  PrintServiceNew._internal();

  final PrintUsb _printUsb = PrintUsb();
  final BluetoothPrintPlus _bluetoothPrint = BluetoothPrintPlus.instance;

  Future<void> initBluetooth() async {
    if (!kIsWeb) {
      _bluetoothPrint.startScan(timeout: Duration(seconds: 4));
    }
  }

  Stream<List<BluetoothDevice>> get bluetoothDevices =>
      _bluetoothPrint.scanResults;

  Future<bool> connectBluetooth(BluetoothDevice device) async {
    return await _bluetoothPrint.connect(device);
  }

  Future<bool> disconnectBluetooth() async {
    return await _bluetoothPrint.disconnect();
  }

  Future<void> printBluetooth(Uint8List data) async {
    await _bluetoothPrint.printImage(data);
  }

  Future<List<UsbDevice>> getUsbDevices() async {
    return await _printUsb.getUsbDeviceList();
  }

  Future<bool> connectUsb(UsbDevice device) async {
    return await _printUsb.connect(device);
  }

  Future<bool> disconnectUsb() async {
    return await _printUsb.disconnect();
  }

  Future<void> printUsb(Uint8List data) async {
    await _printUsb.writeBytes(data);
  }

  Future<List<int>> generateThermalReceipt(List<String> items) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    bytes += generator.text('JWE POS', styles: PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('Receipt', styles: PosStyles(align: PosAlign.center));
    bytes += generator.feed(1);

    for (var item in items) {
      bytes += generator.text(item);
    }

    bytes += generator.feed(2);
    bytes += generator.cut();
    return bytes;
  }
}
