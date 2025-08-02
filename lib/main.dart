import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/home_screen.dart';
import 'services/database_service.dart';
import 'services/backup_service.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة sqflite_ffi للمنصات المكتبية
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // تهيئة التوطين للعربية
  await initializeDateFormatting('ar', null);
  Intl.defaultLocale = 'ar';

  // تهيئة قاعدة البيانات
  await DatabaseService().database;

  // Schedule automatic backups (e.g., every 24 hours)
  Timer.periodic(const Duration(hours: 24), (timer) {
    BackupService().performBackup();
  });

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
      home: const HomeScreen(),
      supportedLocales: const [
        Locale('en', 'US'), // الإنجليزية كاحتياط
        Locale('ar', 'SA'), // العربية
      ],
    );
  }
}
