import 'package:flutter/cupertino.dart';
// Removed unnecessary import: 'package:fluent_ui/fluent_ui.dart'
import 'reports_screen.dart';
import 'advanced_reports_screen.dart';

class UnifiedReportsScreen extends StatefulWidget {
  const UnifiedReportsScreen({super.key});

  @override
  State<UnifiedReportsScreen> createState() => _UnifiedReportsScreenState();
}

class _UnifiedReportsScreenState extends State<UnifiedReportsScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xfff6f8fa),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _selectedTab,
              children: const {
                0: Text('تقارير أساسية'),
                1: Text('تقارير متقدمة'),
              },
              onValueChanged: (v) => setState(() => _selectedTab = v ?? 0),
            ),
          ),
          Expanded(
            child: _selectedTab == 0
                ? const ReportsScreen()
                : const AdvancedReportsScreen(),
          ),
        ],
      ),
    );
  }
}
