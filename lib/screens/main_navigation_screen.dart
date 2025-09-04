import 'package:fluent_ui/fluent_ui.dart';
import 'training_assistant_screen.dart';
import '../theme/app_brand_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import 'pos_screen.dart';
import 'inventory_screen.dart';
import 'invoices_screen.dart';
import 'customers_screen.dart';
import 'unified_reports_screen.dart';
import 'unified_printer_settings_screen.dart';
import 'expenses_screen.dart';
import 'settings_screen.dart';
import 'user_selection_screen.dart';
import 'manage_categories_screen.dart';
import 'manage_materials_screen.dart';

/// Main navigation screen using Fluent Design NavigationView
/// This replaces the traditional stack-based navigation with a modern sidebar approach
class MainNavigationScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  // السلة هي أول شاشة
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _selectedIndex = 0;
  PaneDisplayMode _paneDisplayMode = PaneDisplayMode.compact;

  @override
  void initState() {
    super.initState();
    _selectedIndex = 0; // السلة أول شاشة
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(userNotifierProvider).value;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: Color(0xfff6f8fa),
        child: NavigationView(
          appBar: NavigationAppBar(
            title: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'نظام جوهر',
                      style: FluentTheme.of(
                        context,
                      ).typography.title?.copyWith(color: Color(0xff222b45)),
                    ),
                  ),
                ),
              ],
            ),
            actions: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (currentUser != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: FluentTheme.of(
                        context,
                      ).accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          FluentIcons.contact_info,
                          size: 16,
                          color: FluentTheme.of(context).accentColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          currentUser.fullName,
                          style: FluentTheme.of(context).typography.caption
                              ?.copyWith(
                                color: FluentTheme.of(context).accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Builder(
                  builder: (context) {
                    final t = AppBrandTheme.of(context);
                    return FilledButton(
                      style: t.primaryFilledButtonStyle(),
                      onPressed: () => _showLogoutDialog(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            FluentIcons.sign_out,
                            size: 16,
                            color: const Color(0xffffffff),
                          ),
                          const SizedBox(width: 4),
                          const Text('خروج'),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          pane: NavigationPane(
            selected: _selectedIndex,
            onChanged: (index) => setState(() => _selectedIndex = index),
            displayMode: _paneDisplayMode,
            size: const NavigationPaneSize(openWidth: 180, compactWidth: 48),
            header: Center(
              child: IconButton(
                icon: Icon(
                  _paneDisplayMode == PaneDisplayMode.compact
                      ? FluentIcons.chevron_right
                      : FluentIcons.chevron_left,
                ),
                onPressed: () {
                  setState(() {
                    _paneDisplayMode =
                        _paneDisplayMode == PaneDisplayMode.compact
                        ? PaneDisplayMode.open
                        : PaneDisplayMode.compact;
                  });
                },
              ),
            ),
            items: [
              PaneItem(
                icon: const Icon(FluentIcons.shopping_cart),
                title: const Text('السلة'),
                body: const PosScreen(),
              ),
              PaneItem(
                icon: const Icon(FluentIcons.package),
                title: const Text('المخزون'),
                body: const InventoryScreen(),
              ),
              PaneItem(
                icon: const Icon(FluentIcons.edit),
                title: const Text('تعديل أسعار المواد'),
                body: const ManageMaterialsScreen(),
              ),
              PaneItem(
                icon: const Icon(FluentIcons.package),
                title: const Text('الأصناف'),
                body: const ManageCategoriesScreen(),
              ),
              PaneItem(
                icon: const Icon(FluentIcons.document),
                title: const Text('الفواتير'),
                body: const InvoicesScreen(),
              ),
              PaneItem(
                icon: const Icon(FluentIcons.people),
                title: const Text('العملاء'),
                body: const CustomersScreen(),
              ),
              PaneItem(
                icon: const Icon(FluentIcons.chart),
                title: const Text('التقارير'),
                body: const UnifiedReportsScreen(),
              ),
              PaneItem(
                icon: const Icon(FluentIcons.print),
                title: const Text('إعدادات الطباعة'),
                body: const UnifiedPrinterSettingsScreen(),
              ),
              PaneItem(
                icon: const Icon(FluentIcons.calculator),
                title: const Text('المصروفات'),
                body: const ExpensesScreen(),
              ),
            ],
            footerItems: [
              PaneItem(
                icon: const Icon(FluentIcons.help),
                title: const Text('المساعد التدريبي'),
                body: const TrainingAssistantScreen(),
              ),
              PaneItem(
                icon: const Icon(FluentIcons.settings),
                title: const Text('الإعدادات'),
                body: const SettingsScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
        actions: [
          Button(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _logout();
            },
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }

  void _logout() {
    ref.read(userNotifierProvider.notifier).logout();
    Navigator.of(context).pushReplacement(
      FluentPageRoute(builder: (context) => const UserSelectionScreen()),
    );
  }
}
