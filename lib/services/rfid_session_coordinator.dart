import 'dart:async';

/// Coordinates access between the cashier (POS) reader flow and the gate anti-theft flow.
/// When cashier scanning is active, the gate must not alarm.
/// We keep scanning shared (single reader instance), but gate logic ignores tags while cashier is active.
class RfidSessionCoordinator {
  RfidSessionCoordinator._();
  static final RfidSessionCoordinator instance = RfidSessionCoordinator._();

  final _controller = StreamController<RfidSessionState>.broadcast();
  RfidSessionState _state = const RfidSessionState();

  Stream<RfidSessionState> get stream => _controller.stream;
  RfidSessionState get state => _state;

  void setCashierActive(bool active) {
    final next = _state.copyWith(cashierActive: active);
    _update(next);
  }

  void setGateDesired(bool desired) {
    final next = _state.copyWith(gateDesired: desired);
    _update(next);
  }

  void _update(RfidSessionState next) {
    _state = next;
    if (!_controller.isClosed) {
      _controller.add(_state);
    }
  }

  void dispose() {
    _controller.close();
  }
}

class RfidSessionState {
  const RfidSessionState({
    this.cashierActive = false,
    this.gateDesired = false,
  });
  final bool cashierActive; // true while POS screens are actively scanning
  final bool
  gateDesired; // true when gate feature is enabled and wants to listen

  bool get gateAllowed => gateDesired && !cashierActive;

  RfidSessionState copyWith({bool? cashierActive, bool? gateDesired}) =>
      RfidSessionState(
        cashierActive: cashierActive ?? this.cashierActive,
        gateDesired: gateDesired ?? this.gateDesired,
      );

  @override
  String toString() =>
      'RfidSessionState(cashierActive: $cashierActive, gateDesired: $gateDesired)';
}
