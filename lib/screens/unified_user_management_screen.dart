import 'package:flutter/cupertino.dart';
import 'manage_users_screen.dart';
import 'advanced_user_management_screen.dart';

class UnifiedUserManagementScreen extends StatefulWidget {
  const UnifiedUserManagementScreen({super.key});

  @override
  State<UnifiedUserManagementScreen> createState() =>
      _UnifiedUserManagementScreenState();
}

class _UnifiedUserManagementScreenState
    extends State<UnifiedUserManagementScreen> {
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
                0: Text('إدارة المستخدمين'),
                1: Text('إدارة متقدمة'),
              },
              onValueChanged: (v) => setState(() => _selectedTab = v ?? 0),
            ),
          ),
          Expanded(
            child: _selectedTab == 0
                ? const ManageUsersScreen()
                : const AdvancedUserManagementScreen(),
          ),
        ],
      ),
    );
  }
}
