class Material {
  final int? id;
  final String nameAr;
  final bool isVariable; // هل السعر متغير ويظهر في شاشة التسعير
  final double pricePerGram; // السعر الحالي للجرام (للمواد المتغيرة)

  Material({
    this.id,
    required this.nameAr,
    this.isVariable = false,
    this.pricePerGram = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name_ar': nameAr,
      'is_variable': isVariable ? 1 : 0,
      'price_per_gram': pricePerGram,
    };
  }

  factory Material.fromMap(Map<String, dynamic> map) {
    return Material(
      id: map['id']?.toInt(),
      nameAr: map['name_ar'] ?? '',
      isVariable: (map['is_variable'] ?? 0) == 1,
      pricePerGram: (map['price_per_gram'] is num)
          ? (map['price_per_gram'] as num).toDouble()
          : double.tryParse(map['price_per_gram']?.toString() ?? '0') ?? 0.0,
    );
  }

  Material copyWith({
    int? id,
    String? nameAr,
    bool? isVariable,
    double? pricePerGram,
  }) {
    return Material(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      isVariable: isVariable ?? this.isVariable,
      pricePerGram: pricePerGram ?? this.pricePerGram,
    );
  }

  @override
  String toString() {
    return 'Material(id: $id, nameAr: $nameAr, isVariable: $isVariable, pricePerGram: $pricePerGram)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Material &&
        other.id == id &&
        other.nameAr == nameAr &&
        other.isVariable == isVariable &&
        other.pricePerGram == pricePerGram;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        nameAr.hashCode ^
        isVariable.hashCode ^
        pricePerGram.hashCode;
  }
}
