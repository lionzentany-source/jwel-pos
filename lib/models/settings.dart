class Settings {
  final int? id;
  final double? goldPrice;
  final double? silverPrice;
  final String? storeName;
  final String? currency;
  final double? taxRate;
  // Add other settings fields as needed, e.g., printer settings, RFID settings

  Settings({
    this.id,
    this.goldPrice,
    this.silverPrice,
    this.storeName,
    this.currency,
    this.taxRate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gold_price': goldPrice,
      'silver_price': silverPrice,
      'store_name': storeName,
      'currency': currency,
      'tax_rate': taxRate,
    };
  }

  factory Settings.fromMap(Map<String, dynamic> map) {
    return Settings(
      id: map['id']?.toInt(),
      goldPrice: map['gold_price']?.toDouble(),
      silverPrice: map['silver_price']?.toDouble(),
      storeName: map['store_name'],
      currency: map['currency'],
      taxRate: map['tax_rate']?.toDouble(),
    );
  }

  Settings copyWith({
    int? id,
    double? goldPrice,
    double? silverPrice,
    String? storeName,
    String? currency,
    double? taxRate,
  }) {
    return Settings(
      id: id ?? this.id,
      goldPrice: goldPrice ?? this.goldPrice,
      silverPrice: silverPrice ?? this.silverPrice,
      storeName: storeName ?? this.storeName,
      currency: currency ?? this.currency,
      taxRate: taxRate ?? this.taxRate,
    );
  }

  @override
  String toString() {
    return 'Settings(id: $id, goldPrice: $goldPrice, silverPrice: $silverPrice, storeName: $storeName, currency: $currency, taxRate: $taxRate)';
  }
}
