import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/rfid_session_coordinator.dart';

final rfidSessionCoordinatorProvider = Provider<RfidSessionCoordinator>((ref) {
  return RfidSessionCoordinator.instance;
});

final rfidSessionStateStreamProvider = StreamProvider<RfidSessionState>((ref) {
  final coord = ref.watch(rfidSessionCoordinatorProvider);
  return coord.stream;
});
