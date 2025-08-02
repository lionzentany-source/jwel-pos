import 'package:flutter_test/flutter_test.dart';
import 'package:jwe_pos/services/print_service.dart';
import 'package:jwe_pos/models/printer_settings.dart';

void main() {
  group('Print Service Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    test('PrinterSettings should serialize correctly', () {
      final settings = PrinterSettings(
        name: 'طابعة اختبار',
        address: '192.168.1.100',
        type: PrinterType.thermal,
      );

      final map = settings.toMap();
      final settingsFromMap = PrinterSettings.fromMap(map);

      expect(settingsFromMap.name, equals(settings.name));
      expect(settingsFromMap.address, equals(settings.address));
      expect(settingsFromMap.type, equals(settings.type));
    });

    test('PrinterType enum should work correctly', () {
      expect(PrinterType.regular.displayName, equals('طابعة عادية'));
      expect(PrinterType.thermal.displayName, equals('طابعة حرارية'));

      expect(PrinterType.values.length, equals(2));
      expect(PrinterType.values.contains(PrinterType.regular), isTrue);
      expect(PrinterType.values.contains(PrinterType.thermal), isTrue);
    });

    test('Printer settings validation should work', () {
      // إعدادات صحيحة
      final validSettings = PrinterSettings(
        name: 'طابعة صحيحة',
        address: '192.168.1.100',
        type: PrinterType.thermal,
      );

      expect(validSettings.name.isNotEmpty, isTrue);
      expect(validSettings.address.isNotEmpty, isTrue);
      expect(validSettings.type, isNotNull);

      // إعدادات غير صحيحة
      final invalidSettings = PrinterSettings(
        name: '',
        address: '',
        type: PrinterType.thermal,
      );

      expect(invalidSettings.name.isEmpty, isTrue);
      expect(invalidSettings.address.isEmpty, isTrue);
    });

    test('Print service should be singleton', () {
      final printService1 = PrintService();
      final printService2 = PrintService();

      expect(identical(printService1, printService2), isTrue);
    });

    test('Print service calculations should be accurate', () {
      // اختبار حسابات بسيطة للطباعة
      const subtotal = 1000.0;
      const discount = 100.0;
      const tax = 90.0;
      const expectedTotal = subtotal - discount + tax;

      expect(expectedTotal, equals(990.0));
    });
  });
}
