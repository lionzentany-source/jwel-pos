enum PrinterType {
  regular('طابعة عادية'),
  thermal('طابعة حرارية');

  const PrinterType(this.displayName);
  final String displayName;
}

class PrinterSettings {
  final String? id;
  final String name;
  final String address;
  final PrinterType type;

  PrinterSettings({
    this.id,
    required this.name,
    required this.address,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'type': type.name,
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
    );
  }

  PrinterSettings copyWith({
    String? id,
    String? name,
    String? address,
    PrinterType? type,
  }) {
    return PrinterSettings(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      type: type ?? this.type,
    );
  }

  @override
  String toString() {
    return 'PrinterSettings(id: $id, name: $name, address: $address, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrinterSettings &&
        other.id == id &&
        other.name == name &&
        other.address == address &&
        other.type == type;
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ address.hashCode ^ type.hashCode;
  }
}
