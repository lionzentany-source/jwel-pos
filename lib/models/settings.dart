class Settings {
  final int? id;
  final String key;
  final String value;
  final DateTime updatedAt;

  Settings({
    this.id,
    required this.key,
    required this.value,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'key': key,
      'value': value,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Settings.fromMap(Map<String, dynamic> map) {
    return Settings(
      id: map['id']?.toInt(),
      key: map['key'] ?? '',
      value: map['value'] ?? '',
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Settings copyWith({
    int? id,
    String? key,
    String? value,
    DateTime? updatedAt,
  }) {
    return Settings(
      id: id ?? this.id,
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Settings(key: $key, value: $value)';
  }
}

// مفاتيح الإعدادات المحددة مسبقاً
class SettingsKeys {
  static const String goldPricePerGram = 'gold_price_per_gram';
  static const String silverPricePerGram = 'silver_price_per_gram';
  static const String storeName = 'store_name';
  static const String storeAddress = 'store_address';
  static const String storePhone = 'store_phone';
  static const String taxRate = 'tax_rate';
  static const String currency = 'currency';
  static const String printerName = 'printer_name';
  static const String rfidReaderPort = 'rfid_reader_port';
}
