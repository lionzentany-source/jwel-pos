class Material {
  final int? id;
  final String nameAr;

  Material({
    this.id,
    required this.nameAr,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name_ar': nameAr,
    };
  }

  factory Material.fromMap(Map<String, dynamic> map) {
    return Material(
      id: map['id']?.toInt(),
      nameAr: map['name_ar'] ?? '',
    );
  }

  Material copyWith({
    int? id,
    String? nameAr,
  }) {
    return Material(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
    );
  }

  @override
  String toString() {
    return 'Material(id: $id, nameAr: $nameAr)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Material &&
        other.id == id &&
        other.nameAr == nameAr;
  }

  @override
  int get hashCode {
    return id.hashCode ^ nameAr.hashCode;
  }
}
