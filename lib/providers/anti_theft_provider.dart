import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/anti_theft_service.dart';

final antiTheftServiceProvider = Provider<AntiTheftService>((ref) {
  return AntiTheftService();
});
