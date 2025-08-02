// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jwe_pos/main.dart';
import 'package:jwe_pos/services/rfid_service.dart';

void main() {
  tearDown(() {
    // محاولة تحرير أي موارد أو مؤقتات قيد التشغيل (الخدمة مستخدمة كنمط singleton)
    try {
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      RfidServiceReal().dispose();
    } catch (_) {}
  });
  testWidgets('JweApp loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: JweApp()));

    // Verify that the app loads without errors
    expect(find.byType(CupertinoApp), findsOneWidget);
  });
}
