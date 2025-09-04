import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'screens/user_selection_screen.dart';
import 'services/database_service.dart';
import 'services/backup_service.dart';
import 'services/user_service.dart';
// import 'services/sample_data_service.dart'; // متروك للاستخدام التطويري فقط (أعد تفعيله عند الحاجة لإدخال بيانات تجريبية)
import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'repositories/user_repository.dart';
// ...existing code...

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة sqflite_ffi للمنصات المكتبية
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // تهيئة التوطين للعربية
  try {
    await initializeDateFormatting('ar', null);
    Intl.defaultLocale = 'ar';
  } catch (e) {
    debugPrint('خطأ في تهيئة التوطين: $e');
  }

  // فلاغ لتفعيل إدخال بيانات تجريبية (أوقفه في الإنتاج)
  // تم تعطيل إدخال البيانات التجريبية في الإصدار النهائي (أزل هذا التعليق عند الحاجة)
  // const bool kEnableSampleData = true;

  // Initialize services
  try {
    final dbService = DatabaseService();
    await dbService.database;
    final userRepository = UserRepository();
    await UserService().init(userRepository);

    // إدخال بيانات تجريبية معطل حالياً
  } catch (e) {
    debugPrint('Error initializing services: $e');
  }

  // Schedule automatic backups (e.g., every 24 hours)
  try {
    Timer.periodic(const Duration(hours: 24), (timer) async {
      try {
        await BackupService().performBackup();
      } catch (e) {
        debugPrint('خطأ في النسخ الاحتياطي التلقائي: $e');
      }
    });
  } catch (e) {
    debugPrint('خطأ في جدولة النسخ الاحتياطي: $e');
  }

  runApp(const ProviderScope(child: JweApp()));
}

class JweApp extends StatelessWidget {
  const JweApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'نظام جوهر',
      // تطبيق دائم بالوضع الفاتح فقط (خلفية بيضاء ونوافذ بيضاء)
      theme: FluentThemeData(
        accentColor: AccentColor.swatch({
          'darkest': Color(0xff0078d4), // أزرق رئيسي
          'darker': Color(0xff106ebe), // أزرق داكن
          'dark': Color(0xff005a9e),
          'normal': Color(0xff0078d4),
          'light': Color(0xff40e0ff),
          'lighter': Color(0xff99ebff),
          'lightest': Color(0xffffffff), // أبيض نقي للخلفية
        }),
        brightness: Brightness.light,
        scaffoldBackgroundColor: Color(0xffffffff), // أبيض نقي
        cardColor: Color(0xffffffff), // أبيض نقي للبطاقات
        inactiveColor: Color(0xff106ebe).withAlpha(128),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        buttonTheme: ButtonThemeData(
          defaultButtonStyle: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(Color(0xff0078d4)),
            foregroundColor: WidgetStateProperty.all(Color(0xffffffff)),
            shadowColor: WidgetStateProperty.all(
              Color(0xff0078d4).withAlpha(20),
            ),
          ),
        ),
      ),
      // لا يوجد وضع داكن
      darkTheme: null,
      home: const UserSelectionScreen(),
      supportedLocales: const [
        Locale('en', 'US'), // الإنجليزية كاحتياط
        Locale('ar', 'SA'), // العربية
      ],
      localizationsDelegates: [
        FluentLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      // Enable RTL support for Arabic
      locale: const Locale('ar', 'SA'),
    );
  }
}
