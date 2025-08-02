import 'dart:collection';

/// Global helper to prevent processing the same RFID tag repeatedly
/// within a short configurable time window across the whole app.
class RfidDuplicateFilter {
  // tag -> last processed time
  static final Map<String, DateTime> _recent = HashMap();
  static const Duration _window = Duration(seconds: 5); // تجاهل خلال 5 ثوانٍ

  /// Returns true if the tag should be processed now (i.e. not a duplicate
  /// within the suppression window). Returns false if it must be ignored.
  static bool shouldProcess(String tag) {
    final now = DateTime.now();
    final last = _recent[tag];
    if (last != null && now.difference(last) < _window) {
      return false; // duplicate inside window
    }
    _recent[tag] = now;
    // خفض الذاكرة كل فترة عند زيادة الحجم
    if (_recent.length > 200) {
      final threshold = now.subtract(_window * 2);
      _recent.removeWhere((_, dt) => dt.isBefore(threshold));
    }
    return true;
  }

  /// Clears all remembered tags (e.g. after مسح السلة أو إنهاء عملية)
  static void clear() => _recent.clear();
}
