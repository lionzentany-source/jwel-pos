import 'package:flutter/cupertino.dart';
import '../models/user.dart';

class UserAvatarHelper {
  static Color getUserColor(User user) {
    switch (user.avatarColor ?? 'systemBlue') {
      case 'systemBlue':
        return CupertinoColors.systemBlue;
      case 'systemGreen':
        return CupertinoColors.systemGreen;
      case 'systemOrange':
        return CupertinoColors.systemOrange;
      case 'systemPurple':
        return CupertinoColors.systemPurple;
      case 'systemRed':
        return CupertinoColors.systemRed;
      case 'systemTeal':
        return CupertinoColors.systemTeal;
      case 'systemYellow':
        return CupertinoColors.systemYellow;
      case 'systemPink':
        return CupertinoColors.systemPink;
      default:
        return CupertinoColors.systemBlue;
    }
  }

  static IconData getUserIcon(User user) {
    switch (user.avatarIcon ?? 'person_circle') {
      case 'person_crop_circle_fill':
        return CupertinoIcons.person_crop_circle_fill;
      case 'person_badge_shield_checkmark':
        return CupertinoIcons.person_badge_plus;
      case 'person_circle':
        return CupertinoIcons.person_circle;
      case 'person_2_circle':
        return CupertinoIcons.person_2;
      case 'person_alt_circle':
        return CupertinoIcons.person_alt_circle;
      case 'person_badge_plus':
        return CupertinoIcons.person_badge_plus;
      case 'person_crop_circle':
        return CupertinoIcons.person_crop_circle;
      default:
        return CupertinoIcons.person_circle;
    }
  }

  static String getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'صلاحيات كاملة للنظام';
      case UserRole.manager:
        return 'إدارة المخزون والتقارير';
      case UserRole.cashier:
        return 'نقطة البيع والعملاء';
      case UserRole.supervisor:
        return 'الإشراف والمتابعة';
    }
  }

  static List<String> getAvailableColors() {
    return [
      'systemBlue',
      'systemGreen',
      'systemOrange',
      'systemPurple',
      'systemRed',
      'systemTeal',
      'systemYellow',
      'systemPink',
    ];
  }

  static List<String> getAvailableIcons() {
    return [
      'person_crop_circle_fill',
      'person_badge_plus',
      'person_circle',
      'person_2',
      'person_alt_circle',
      'person_badge_plus',
      'person_crop_circle',
    ];
  }
}
