enum PrinterType {
  usb('طابعة USB'),
  network('طابعة شبكة'),
  bluetooth('طابعة بلوتوث'),
  windows('طابعة Windows'),
  thermal('طابعة حرارية');

  const PrinterType(this.displayName);
  final String displayName;
}

class PrinterSettings {
  final String? id;
  final String name;
  final String address;
  final PrinterType type;
  final int? vendorId;
  final int? productId;

  PrinterSettings({
    this.id,
    required this.name,
    required this.address,
    required this.type,
    this.vendorId,
    this.productId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'type': type.name,
      'vendorId': vendorId,
      'productId': productId,
    };
  }

  factory PrinterSettings.fromMap(Map<String, dynamic> map) {
    return PrinterSettings(
      id: map['id'],
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      type: PrinterType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PrinterType.thermal,
      ),
      vendorId: map['vendorId']?.toInt(),
      productId: map['productId']?.toInt(),
    );
  }

  PrinterSettings copyWith({
    String? id,
    String? name,
    String? address,
    PrinterType? type,
    int? vendorId,
    int? productId,
  }) {
    return PrinterSettings(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      type: type ?? this.type,
      vendorId: vendorId ?? this.vendorId,
      productId: productId ?? this.productId,
    );
  }

  @override
  String toString() {
    return 'PrinterSettings(id: $id, name: $name, address: $address, type: $type, vendorId: $vendorId, productId: $productId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrinterSettings &&
        other.id == id &&
        other.name == name &&
        other.address == address &&
        other.type == type &&
        other.vendorId == vendorId &&
        other.productId == productId;
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ address.hashCode ^ type.hashCode ^ vendorId.hashCode ^ productId.hashCode;
  }
}
