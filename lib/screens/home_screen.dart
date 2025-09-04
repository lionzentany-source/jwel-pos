import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/adaptive_scaffold.dart';
import 'inventory_screen.dart';
import 'pos_screen.dart';
import 'invoices_screen.dart';
import 'customers_screen.dart';
import 'settings_screen.dart';
import 'reports_screen.dart';
import 'expenses_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialIndex == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context,
          FluentPageRoute(builder: (context) => const PosScreen()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F8FA),
      child: AdaptiveScaffold(
        title: 'نظام جوهر',
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth > 600;
            final crossAxisCount = isTablet ? 4 : 2;

            return GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildMenuCard(
                  context,
                  title: 'نقطة البيع',
                  icon: FluentIcons.money,
                  color: const Color(0xFF0078D4),
                  onTap: () {
                    Navigator.push(
                      context,
                      FluentPageRoute(builder: (context) => const PosScreen()),
                    );
                  },
                ),
                _buildMenuCard(
                  context,
                  title: 'المخزون',
                  icon: FluentIcons.package,
                  color: const Color(0xFF106EBE),
                  onTap: () {
                    Navigator.push(
                      context,
                      FluentPageRoute(
                        builder: (context) => const InventoryScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuCard(
                  context,
                  title: 'الفواتير',
                  icon: FluentIcons.document,
                  color: const Color(0xFF005A9E),
                  onTap: () {
                    Navigator.push(
                      context,
                      FluentPageRoute(
                        builder: (context) => const InvoicesScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuCard(
                  context,
                  title: 'العملاء',
                  icon: FluentIcons.people,
                  color: const Color(0xFF2B88D8),
                  onTap: () {
                    Navigator.push(
                      context,
                      FluentPageRoute(
                        builder: (context) => const CustomersScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuCard(
                  context,
                  title: 'التقارير',
                  icon: FluentIcons.chart,
                  color: const Color(0xFF0078D4),
                  onTap: () {
                    Navigator.push(
                      context,
                      FluentPageRoute(
                        builder: (context) => const ReportsScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuCard(
                  context,
                  title: 'المصروفات',
                  icon: FluentIcons.calculator,
                  color: const Color(0xFF106EBE),
                  onTap: () {
                    Navigator.push(
                      context,
                      FluentPageRoute(
                        builder: (context) => const ExpensesScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuCard(
                  context,
                  title: 'الإعدادات',
                  icon: FluentIcons.settings,
                  color: const Color(0xFF005A9E),
                  onTap: () {
                    Navigator.push(
                      context,
                      FluentPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // (تم دمج التقارير الأساسية والمتقدمة في شاشة واحدة)

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AdaptiveCard(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withAlpha(31),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 12),
            AdaptiveText(
              title,
              style: FluentTheme.of(context).typography.subtitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}