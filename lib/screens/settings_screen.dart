import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/adaptive_scaffold.dart';
import '../providers/settings_provider.dart';
import '../providers/user_provider.dart';
import '../providers/material_provider.dart';
import 'manage_categories_screen.dart';
import 'manage_materials_screen.dart';
import 'manage_users_screen.dart';
import 'backup_management_screen.dart';
import 'advanced_user_management_screen.dart';
import 'rfid_settings_screen.dart';
import 'print_preview_screen.dart';
import '../services/real_printer_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsNotifierProvider);

    return AdaptiveScaffold(
      title: 'الإعدادات',
      body: settings.when(
        data: (settingsMap) => _buildSettingsList(context, settingsMap),
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (err, stack) =>
            Center(child: Text('خطأ في تحميل الإعدادات: $err')),
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
                      final variableMaterials = materials.where((m) => m.isVariable).toList();
                      if (variableMaterials.isEmpty) {
                        return const Text(
                          'لا توجد مواد متغيرة. يمكنك تعيين ذلك من إدارة المواد الخام.',
                          style: TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 14),
                        );
                      }
                      return Column(
                        children: variableMaterials.map((m) {
                          final controller = TextEditingController(text: m.pricePerGram.toString());
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    m.nameAr,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                SizedBox(
                                  width: 110,
                                  child: CupertinoTextField(
                                    controller: controller,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onSubmitted: (val) {
                                      final v = double.tryParse(val);
                                      if (v != null) {
                                        ref.read(materialNotifierProvider.notifier).updateMaterialPrice(m.id!, v);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text('د.ل/جم', style: TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel)),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const CupertinoActivityIndicator(),
                    error: (e, _) => Text('خطأ: $e'),
                  );
                },
              ),
            ]),
            const SizedBox(height: 20),
            _buildSettingsCard('إدارة البيانات', [
              _buildNavigationButton('إدارة الفئات', CupertinoIcons.tag, () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => const ManageCategoriesScreen(),
                  ),
                );
              }),
              const SizedBox(height: 12),
              _buildNavigationButton(
                'إدارة المواد الخام',
                CupertinoIcons.cube,
                () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
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
                  CupertinoIcons.person_2,
                  () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => const ManageUsersScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildNavigationButton(
                  'إدارة متقدمة',
                  CupertinoIcons.person_3,
                  () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) =>
                            const AdvancedUserManagementScreen(),
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
                CupertinoIcons.doc_text,
                () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => const PrintPreviewScreen(),
                    ),
                  );
                },
              ),
            ]),
            const SizedBox(height: 20),
            _buildSettingsCard('إعدادات RFID', [
              _buildNavigationButton(
                'إعدادات قارئ RFID',
                CupertinoIcons.wifi,
                () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => const RfidSettingsScreen(),
                    ),
                  );
                },
              ),
            ]),
            const SizedBox(height: 20),
            _buildSettingsCard('النسخ الاحتياطي', [
              _buildNavigationButton(
                'إدارة النسخ الاحتياطي',
                CupertinoIcons.archivebox,
                () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
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
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('إعدادات الطباعة العادية'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('اختيار طابعة'),
            onPressed: () {
              Navigator.pop(context);
              _openPrinterSelectionDialog(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('ربط طابعة بلوتوث'),
            onPressed: () {
              Navigator.pop(context);
              _connectBluetoothPrinter(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('اختبار الطباعة'),
            onPressed: () {
              Navigator.pop(context);
              _testPrint(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('إلغاء'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _connectBluetoothPrinter(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
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
          CupertinoDialogAction(
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
      final defaultPrinter = await printerService.getDefaultPrinter();
      if (!context.mounted) return; // بعد الانتظار

      if (defaultPrinter == null) {
        _showMessage(
          context,
          'لا توجد طابعة افتراضية. يرجى اختيار طابعة أولاً.',
        );
        return;
      }

      // حفظ مرجع للـ Navigator لتفادي استخدام context غير صالح لاحقاً
      final navigator = Navigator.of(context);
      showCupertinoDialog(
        context: context,
        builder: (dialogCtx) => CupertinoAlertDialog(
          title: const Text('اختبار الطباعة'),
          content: Text(
            'هل تريد طباعة صفحة اختبار على:\n${defaultPrinter.name}',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                if (mounted) navigator.pop();
              },
              child: const Text('إلغاء'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                if (context.mounted) navigator.pop();
                if (!context.mounted) return;

                // عرض مؤشر الطباعة (نستخدم navigator نفسه)
                showCupertinoDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const CupertinoAlertDialog(
                    title: Text('جاري الطباعة'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 16),
                        CupertinoActivityIndicator(),
                        SizedBox(height: 16),
                        Text('يرجى الانتظار...'),
                      ],
                    ),
                  ),
                );

                final success = await printerService.testPrint(defaultPrinter);
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

  void _openPrinterSelectionDialog(BuildContext context) async {
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        title: Text('البحث عن طابعات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16),
            CupertinoActivityIndicator(),
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
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
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
                  (printer) => CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
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
          CupertinoDialogAction(
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
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('تم اختيار الطابعة'),
        content: Text('تم تعيين ${printer.name} كطابعة افتراضية للتطبيق.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showNoPrintersFound(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('لا توجد طابعات'),
        content: const Text(
          'لم يتم العثور على طابعات متاحة.\n\nتأكد من:\n• توصيل الطابعة\n• تشغيل الطابعة\n• تثبيت برامج التشغيل',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
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
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('خطأ في الطباعة'),
        content: Text('حدث خطأ أثناء البحث عن الطابعات:\n$error'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('نجح'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.1),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
        Text(
          label,
          style: const TextStyle(color: CupertinoColors.secondaryLabel),
        ),
        const SizedBox(height: 8),
        CupertinoTextField(
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
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: CupertinoColors.activeBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: CupertinoColors.label),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey,
            ),
          ],
        ),
      ),
    );
  }
}
