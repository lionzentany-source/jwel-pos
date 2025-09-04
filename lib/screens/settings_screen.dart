import 'package:flutter/cupertino.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../widgets/branded_logo.dart';

import '../widgets/adaptive_scaffold.dart';
import '../widgets/app_button.dart';
import '../providers/settings_provider.dart';
import '../providers/user_provider.dart';
import '../providers/material_provider.dart';
import 'manage_categories_screen.dart';
import 'manage_materials_screen.dart';
// removed direct manage/advanced screens; use unified instead
import 'unified_user_management_screen.dart';
import 'backup_management_screen.dart';
import 'rfid_settings_screen.dart';
import 'rfid_assignment_screen.dart';
import 'anti_theft_settings_screen.dart';
import 'print_preview_screen.dart';
import '../services/real_printer_service.dart';
import 'package:printing/printing.dart' show Printer;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsNotifierProvider);

    return Container(
      color: Color(0xfff6f8fa), // خلفية موحدة
      child: AdaptiveScaffold(
        title: 'الإعدادات',
        showBackButton: true,
        body: settings.when(
          data: (settingsMap) => _buildSettingsList(context, settingsMap),
          loading: () => const Center(child: ProgressRing()),
          error: (err, stack) =>
              Center(child: Text('خطأ في تحميل الإعدادات: $err')),
        ),
      ),
    );
  }

  Widget _buildSettingsList(
    BuildContext context,
    Map<String, dynamic> settingsMap,
  ) {
    final storeNameController = TextEditingController(
      text: settingsMap['store_name'] ?? '',
    );
    final taxRateController = TextEditingController(
      text: settingsMap['tax_rate']?.toString() ?? '',
    );

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.data?.version ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      const BrandedLogo(size: 96),
                      const SizedBox(height: 12),
                      const Text(
                        'نظام جوهر',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الإصدار $version',
                        style: FluentTheme.of(context).typography.caption,
                      ),
                    ],
                  ),
                );
              },
            ),
            _buildSettingsCard('إعدادات المتجر', [
              _buildTextField('اسم المتجر', storeNameController, (value) {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .updateStoreName(value);
              }),
            ]),
            const SizedBox(height: 20),
            _buildSettingsCard('التسعير', [
              _buildTextField('نسبة الضريبة (%)', taxRateController, (value) {
                final rate = double.tryParse(value);
                if (rate != null) {
                  ref
                      .read(settingsNotifierProvider.notifier)
                      .updateTaxRate(rate);
                }
              }),
            ]),
            const SizedBox(height: 20),
            _buildSettingsCard('تسعير المواد المتغيرة', [
              Consumer(
                builder: (context, ref, _) {
                  final materialsState = ref.watch(materialNotifierProvider);
                  return materialsState.when(
                    data: (materials) {
                      final variableMaterials = materials
                          .where((m) => m.isVariable)
                          .toList();
                      if (variableMaterials.isEmpty) {
                        return Text(
                          'لا توجد مواد متغيرة. يمكنك تعيين ذلك من إدارة المواد الخام.',
                          style: FluentTheme.of(context).typography.caption,
                        );
                      }
                      return Column(
                        children: variableMaterials.map((m) {
                          final controller = TextEditingController(
                            text: m.pricePerGram.toString(),
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    m.nameAr,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 110,
                                  child: TextBox(
                                    controller: controller,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onSubmitted: (val) {
                                      final v = double.tryParse(val);
                                      if (v != null) {
                                        ref
                                            .read(
                                              materialNotifierProvider.notifier,
                                            )
                                            .updateMaterialPrice(m.id!, v);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'د.ل/جم',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: CupertinoColors.secondaryLabel,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const ProgressRing(),
                    error: (e, _) => Text('خطأ: $e'),
                  );
                },
              ),
            ]),
            const SizedBox(height: 20),
            _buildSettingsCard('إدارة البيانات', [
              _buildNavigationButton('إدارة الفئات', FluentIcons.tag, () {
                Navigator.push(
                  context,
                  FluentPageRoute(
                    builder: (context) => const ManageCategoriesScreen(),
                  ),
                );
              }),
              const SizedBox(height: 12),
              _buildNavigationButton(
                'إدارة المواد الخام',
                FluentIcons.cube_shape,
                () {
                  Navigator.push(
                    context,
                    FluentPageRoute(
                      builder: (context) => const ManageMaterialsScreen(),
                    ),
                  );
                },
              ),
              // إضافة إدارة المستخدمين للمدير فقط
              if (ref.watch(userNotifierProvider).value?.role.name ==
                  'admin') ...<Widget>[
                const SizedBox(height: 12),
                _buildNavigationButton(
                  'إدارة المستخدمين',
                  FluentIcons.people,
                  () {
                    Navigator.push(
                      context,
                      FluentPageRoute(
                        builder: (context) =>
                            const UnifiedUserManagementScreen(),
                      ),
                    );
                  },
                ),
              ],
            ]),
            const SizedBox(height: 20),
            _buildSettingsCard('إعدادات الطباعة', [
              _buildNavigationButton(
                'إعدادات الطابعة',
                CupertinoIcons.printer,
                () {
                  _showPrinterSettings(context);
                },
              ),
              const SizedBox(height: 12),
              _buildNavigationButton(
                'معاينة الطباعة',
                FluentIcons.document,
                () {
                  Navigator.push(
                    context,
                    FluentPageRoute(
                      builder: (context) => const PrintPreviewScreen(),
                    ),
                  );
                },
              ),
            ]),
            const SizedBox(height: 20),
            _buildSettingsCard('إعدادات RFID', [
              Consumer(
                builder: (context, ref, _) {
                  final wedgeEnabled = ref.watch(
                    posKeyboardWedgeEnabledProvider,
                  );
                  return wedgeEnabled.when(
                    data: (enabled) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'تفعيل قارئ لوحة المفاتيح في نقطة البيع',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          ToggleSwitch(
                            checked: enabled,
                            onChanged: (v) async {
                              final repo = ref.read(settingsRepositoryProvider);
                              await repo.setPosKeyboardWedgeEnabled(v);
                              ref.invalidate(posKeyboardWedgeEnabledProvider);
                            },
                          ),
                        ],
                      ),
                    ),
                    loading: () => const ProgressRing(),
                    error: (e, _) => Text('خطأ في تحميل الإعداد: $e'),
                  );
                },
              ),
              _buildNavigationButton(
                'تعيين أجهزة القارئ حسب الشاشة',
                FluentIcons.settings,
                () {
                  Navigator.push(
                    context,
                    FluentPageRoute(
                      builder: (context) => const RfidAssignmentScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildNavigationButton('إعدادات قارئ RFID', FluentIcons.wifi, () {
                Navigator.push(
                  context,
                  FluentPageRoute(
                    builder: (context) => const RfidSettingsScreen(),
                  ),
                );
              }),
              const SizedBox(height: 12),
              _buildNavigationButton(
                'منع السرقة (قارئ الباب)',
                FluentIcons.shield,
                () {
                  Navigator.push(
                    context,
                    FluentPageRoute(
                      builder: (context) => const AntiTheftSettingsScreen(),
                    ),
                  );
                },
              ),
              // تمت إضافة القراءات المباشرة كعلامة تبويب داخل شاشة منع السرقة
            ]),
            const SizedBox(height: 20),
            _buildSettingsCard('النسخ الاحتياطي', [
              _buildNavigationButton(
                'إدارة النسخ الاحتياطي',
                FluentIcons.archive,
                () {
                  Navigator.push(
                    context,
                    FluentPageRoute(
                      builder: (context) => const BackupManagementScreen(),
                    ),
                  );
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _showPrinterSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('إعدادات الطباعة العادية'),
        content: const Text('اختر إجراءً:'),
        actions: [
          Button(
            child: const Text('اختيار طابعة'),
            onPressed: () {
              Navigator.pop(context);
              _openPrinterSelectionDialog(context);
            },
          ),
          Button(
            child: const Text('ربط طابعة بلوتوث'),
            onPressed: () {
              Navigator.pop(context);
              _connectBluetoothPrinter(context);
            },
          ),
          FilledButton(
            child: const Text('اختبار الطباعة'),
            onPressed: () {
              Navigator.pop(context);
              _testPrint(context);
            },
          ),
          Button(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _connectBluetoothPrinter(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('ربط طابعة بلوتوث'),
        content: const Column(
          children: [
            SizedBox(height: 16),
            Text('جاري البحث عن طابعات بلوتوث...'),
            SizedBox(height: 16),
            CupertinoActivityIndicator(),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  void _testPrint(BuildContext context) async {
    try {
      if (!context.mounted) return; // تأكد من بقاء الواجهة
      final printerService = RealPrinterService();
      final settingsRepo = ref.read(settingsRepositoryProvider);
      final preferredName = await settingsRepo.getDefaultPrinterName();
      Printer? defaultPrinter;
      List<Printer> candidates = [];

      if (preferredName != null && preferredName.trim().isNotEmpty) {
        candidates = await printerService.findPrintersByName(preferredName);
        if (candidates.length == 1) {
          defaultPrinter = candidates.first;
        } else if (candidates.isEmpty) {
          defaultPrinter = await printerService.getDefaultPrinter();
        }
      } else {
        defaultPrinter = await printerService.getDefaultPrinter();
      }
      if (!context.mounted) return; // بعد الانتظار

      if (!context.mounted) return;
      if (defaultPrinter == null) {
        _showMessage(
          context,
          'لا توجد طابعة افتراضية. يرجى اختيار طابعة أولاً.',
        );
        return;
      }

      // حفظ مرجع للـ Navigator لتفادي استخدام context غير صالح لاحقاً
      final navigator = Navigator.of(context);
      showDialog(
        context: context,
        builder: (dialogCtx) => ContentDialog(
          title: const Text('اختبار الطباعة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الطابعة المختارة حالياً: ${defaultPrinter!.name}'),
              if (preferredName != null && preferredName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'مفضّلة حسب الإعدادات: $preferredName',
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ),
              const SizedBox(height: 12),
              const Text('هل تريد طباعة صفحة اختبار الآن؟'),
            ],
          ),
          actions: [
            Button(
              onPressed: () {
                if (mounted) navigator.pop();
              },
              child: const Text('إلغاء'),
            ),
            if (candidates.length > 1)
              Button(
                onPressed: () {
                  navigator.pop();
                  _showCandidateChooser(context, candidates);
                },
                child: const Text('اختيار من مطابقات متعددة'),
              ),
            FilledButton(
              onPressed: () async {
                if (context.mounted) navigator.pop();
                if (!context.mounted) return;

                // عرض مؤشر الطباعة
                showDialog(
                  context: context,
                  builder: (_) => const ContentDialog(
                    title: Text('جاري الطباعة'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 16),
                        ProgressRing(),
                        SizedBox(height: 16),
                        Text('يرجى الانتظار...'),
                      ],
                    ),
                  ),
                );

                final success = await printerService.testPrint(defaultPrinter!);
                if (!context.mounted) return;
                navigator.pop(); // إغلاق مؤشر الطباعة
                _showMessage(
                  context,
                  success
                      ? 'تم إرسال صفحة الاختبار بنجاح'
                      : 'فشل في طباعة صفحة الاختبار',
                );
              },
              child: const Text('طباعة'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      _showMessage(context, 'خطأ في اختبار الطباعة: $e');
    }
  }

  void _showCandidateChooser(BuildContext context, List<Printer> candidates) {
    showDialog(
      context: context,
      builder: (_) => ContentDialog(
        title: const Text('مطابقات متعددة للاسم'),
        content: SizedBox(
          width: 360,
          height: 240,
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final p in candidates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Button(
                      onPressed: () async {
                        // Close chooser first
                        Navigator.pop(context);
                        final settingsRepo = ref.read(
                          settingsRepositoryProvider,
                        );
                        await settingsRepo.setDefaultPrinterName(p.name);
                        if (!context.mounted) return;
                        _showMessage(
                          context,
                          'تم تعيين ${p.name} كطابعة مفضلة.',
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(p.name),
                          if (p.isDefault)
                            const Text(
                              'افتراضية من النظام',
                              style: TextStyle(color: Color(0xFF6B7280)),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _openPrinterSelectionDialog(BuildContext context) async {
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      builder: (_) => const ContentDialog(
        title: Text('البحث عن طابعات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16),
            ProgressRing(),
            SizedBox(height: 16),
            Text('جاري البحث عن طابعات متاحة...'),
          ],
        ),
      ),
    );

    try {
      final printerService = RealPrinterService();
      final printers = await printerService.getAvailablePrinters();
      if (!context.mounted) return;
      navigator.pop();
      if (printers.isEmpty) {
        _showNoPrintersFound(context);
      } else {
        _showPrintersList(context, printers);
      }
    } catch (e) {
      if (!context.mounted) return;
      navigator.pop();
      _showPrinterError(context, e.toString());
    }
  }

  void _showPrintersList(BuildContext context, List<dynamic> printers) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('اختيار طابعة'),
        content: SizedBox(
          width: 300,
          height: 200,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text('تم العثور على ${printers.length} طابعة:'),
                const SizedBox(height: 16),
                ...printers.map(
                  (printer) => Button(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmPrinterSelection(context, printer);
                    },
                    child: Text(
                      printer.name,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  void _confirmPrinterSelection(BuildContext context, dynamic printer) {
    // حفظ اسم الطابعة المختارة في الإعدادات
    final settingsRepo = ref.read(settingsRepositoryProvider);
    settingsRepo.setDefaultPrinterName(printer.name);
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('تم اختيار الطابعة'),
        content: Text('تم تعيين ${printer.name} كطابعة افتراضية للتطبيق.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showNoPrintersFound(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('لا توجد طابعات'),
        content: const Text(
          'لم يتم العثور على طابعات متاحة.\n\nتأكد من:\n• توصيل الطابعة\n• تشغيل الطابعة\n• تثبيت برامج التشغيل',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _openPrinterSelectionDialog(context);
            },
            child: const Text('إعادة البحث'),
          ),
        ],
      ),
    );
  }

  void _showPrinterError(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('خطأ في الطباعة'),
        content: Text('حدث خطأ أثناء البحث عن الطابعات:\n$error'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('نجاح'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(String title, List<Widget> children) {
    return Card(
      padding: const EdgeInsets.all(16),
      backgroundColor: Color(0xffffffff), // أبيض نقي للبطاقات
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xff222b45),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    Function(String) onSubmitted,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: FluentTheme.of(context).typography.caption),
        const SizedBox(height: 8),
        TextBox(
          controller: controller,
          onSubmitted: (value) {
            if (label == 'اسم المتجر') {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateStoreName(value);
            } else if (label == 'نسبة الضريبة (%)') {
              final rate = double.tryParse(value);
              if (rate != null) {
                ref.read(settingsNotifierProvider.notifier).updateTaxRate(rate);
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildNavigationButton(
    String title,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return AppButton.nav(title: title, icon: icon, onPressed: onPressed);
  }
}
