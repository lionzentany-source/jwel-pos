import 'package:flutter/cupertino.dart';
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
          CupertinoPageRoute(builder: (context) => const PosScreen()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
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
                icon: CupertinoIcons.money_dollar_circle,
                color: CupertinoColors.activeGreen,
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => const PosScreen()),
                  );
                },
              ),
              _buildMenuCard(
                context,
                title: 'المخزون',
                icon: CupertinoIcons.cube_box,
                color: CupertinoColors.activeBlue,
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => const InventoryScreen(),
                    ),
                  );
                },
              ),
              _buildMenuCard(
                context,
                title: 'الفواتير',
                icon: CupertinoIcons.doc_text,
                color: CupertinoColors.systemOrange,
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => const InvoicesScreen(),
                    ),
                  );
                },
              ),
              _buildMenuCard(
                context,
                title: 'العملاء',
                icon: CupertinoIcons.person_2,
                color: CupertinoColors.systemPurple,
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => const CustomersScreen(),
                    ),
                  );
                },
              ),
              _buildMenuCard(
                context,
                title: 'التقارير',
                icon: CupertinoIcons.chart_bar,
                color: CupertinoColors.systemTeal,
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => const ReportsScreen(),
                    ),
                  );
                },
              ),
              _buildMenuCard(
                context,
                title: 'المصروفات',
                icon: CupertinoIcons.list_bullet_below_rectangle,
                color: CupertinoColors.systemIndigo,
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => const ExpensesScreen(),
                    ),
                  );
                },
              ),
              _buildMenuCard(
                context,
                title: 'الإعدادات',
                icon: CupertinoIcons.settings,
                color: CupertinoColors.systemGrey,
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          );
        },
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(icon, size: 30, color: color),
          ),
          const SizedBox(height: 12),
          AdaptiveText(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
