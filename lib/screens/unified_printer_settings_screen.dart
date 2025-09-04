import 'package:flutter/cupertino.dart';
// Removed unnecessary import: 'package:fluent_ui/fluent_ui.dart'
import 'enhanced_printer_settings_screen.dart';
import 'print_preview_screen.dart';

class UnifiedPrinterSettingsScreen extends StatefulWidget {
  const UnifiedPrinterSettingsScreen({super.key});

  @override
  State<UnifiedPrinterSettingsScreen> createState() =>
      _UnifiedPrinterSettingsScreenState();
}

class _UnifiedPrinterSettingsScreenState
    extends State<UnifiedPrinterSettingsScreen> {
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
                0: Text('إعدادات الطباعة'),
                1: Text('معاينة الطباعة'),
              },
              onValueChanged: (v) => setState(() => _selectedTab = v ?? 0),
            ),
          ),
          Expanded(
            child: _selectedTab == 0
                ? const EnhancedPrinterSettingsScreen()
                : const PrintPreviewScreen(),
          ),
        ],
      ),
    );
  }
}
