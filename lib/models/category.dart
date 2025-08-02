class Category {
  final int? id;
  final String nameAr;
  final String iconName;

  Category({
    this.id,
    required this.nameAr,
    required this.iconName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name_ar': nameAr,
      'icon_name': iconName,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id']?.toInt(),
      nameAr: map['name_ar'] ?? '',
      iconName: map['icon_name'] ?? '',
    );
  }

  Category copyWith({
    int? id,
    String? nameAr,
    String? iconName,
  }) {
    return Category(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      iconName: iconName ?? this.iconName,
    );
  }

  @override
  String toString() {
    return 'Category(id: $id, nameAr: $nameAr, iconName: $iconName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category &&
        other.id == id &&
        other.nameAr == nameAr &&
        other.iconName == iconName;
  }

  @override
  int get hashCode {
    return id.hashCode ^ nameAr.hashCode ^ iconName.hashCode;
  }
}
