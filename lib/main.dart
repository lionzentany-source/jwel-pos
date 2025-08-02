import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'screens/user_selection_screen.dart';
import 'services/database_service.dart';
import 'services/backup_service.dart';
import 'services/user_service.dart';
import 'services/sample_data_service.dart';
import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'repositories/user_repository.dart';

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

  // Initialize services
  try {
    final dbService = DatabaseService();
    await dbService.database;
    final userRepository = UserRepository();
    await UserService().init(userRepository);

    // إضافة بيانات تجريبية إذا لم تكن موجودة
    final sampleDataService = SampleDataService();
    await sampleDataService.addSampleItems();
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
    return CupertinoApp(
      title: 'نظام جوهر',
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.activeBlue,
        brightness: Brightness.light,
      ),
      // بدء التطبيق بشاشة تسجيل الدخول
      home: const UserSelectionScreen(),
      supportedLocales: const [
        Locale('en', 'US'), // الإنجليزية كاحتياط
        Locale('ar', 'SA'), // العربية
      ],
      localizationsDelegates: [
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    );
  }
}
