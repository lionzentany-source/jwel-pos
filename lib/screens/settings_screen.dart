import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/adaptive_scaffold.dart';
import '../providers/settings_provider.dart';
import 'manage_categories_screen.dart';
import 'manage_materials_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);

    return AdaptiveScaffold(
      title: 'الإعدادات',
      body: settings.when(
        data: (settingsMap) => _buildSettingsList(context, ref, settingsMap),
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (err, stack) =>
            Center(child: Text('خطأ في تحميل الإعدادات: $err')),
      ),
    );
  }

  Widget _buildSettingsList(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> settingsMap,
  ) {
    final storeNameController = TextEditingController(
      text: settingsMap['store_name'] ?? '',
    );
    final goldPriceController = TextEditingController(
      text: settingsMap['gold_price_per_gram'] ?? '',
    );
    final taxRateController = TextEditingController(
      text: settingsMap['tax_rate'] ?? '',
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
              }, ref),
            ]),
            const SizedBox(height: 20),
            _buildSettingsCard('التسعير', [
              _buildTextField('سعر الذهب للجرام', goldPriceController, (value) {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .updateGoldPrice(double.parse(value));
              }, ref),
              const SizedBox(height: 16),
              _buildTextField('نسبة الضريبة (%)', taxRateController, (value) {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .updateTaxRate(double.parse(value));
              }, ref),
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
            ]),
          ],
        ),
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
    WidgetRef ref,
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
            } else if (label == 'سعر الذهب للجرام') {
              final price = double.tryParse(value);
              if (price != null) {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .updateGoldPrice(price);
              }
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
