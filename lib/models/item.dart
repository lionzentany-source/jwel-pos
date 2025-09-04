enum ItemStatus {
  needsRfid('يحتاج لبطاقة'),
  inStock('مخزون'),
  sold('مباع'),
  reserved('محجوز');

  const ItemStatus(this.displayName);
  final String displayName;
}

enum ItemLocation {
  warehouse('المخزن'),
  showroom('صالة العرض');

  const ItemLocation(this.displayName);
  final String displayName;
}

class Item {
  final int? id;
  final String sku;
  final int categoryId;
  final int materialId;
  final double weightGrams;
  final int karat;
  final double workmanshipFee;
  final double stonePrice;
  final double costPrice;
  final String? imagePath;
  String? rfidTag; // Changed from final to mutable
  final ItemStatus status;
  final ItemLocation location;
  final DateTime createdAt;

  Item({
    this.id,
    required this.sku,
    required this.categoryId,
    required this.materialId,
    required this.weightGrams,
    required this.karat,
    required this.workmanshipFee,
    this.stonePrice = 0.0,
    this.costPrice = 0.0,
    this.imagePath,
    this.rfidTag,
    this.status = ItemStatus.needsRfid,
    this.location = ItemLocation.warehouse,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sku': sku,
      'category_id': categoryId,
      'material_id': materialId,
      'weight_grams': weightGrams,
      'karat': karat,
      'workmanship_fee': workmanshipFee,
      'stone_price': stonePrice,
      'cost_price': costPrice,
      'image_path': imagePath,
      'rfid_tag': rfidTag,
      'status': status.name,
      'location': location.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id']?.toInt(),
      sku: map['sku'] ?? '',
      categoryId: map['category_id']?.toInt() ?? 0,
      materialId: map['material_id']?.toInt() ?? 0,
      weightGrams: map['weight_grams']?.toDouble() ?? 0.0,
      karat: map['karat']?.toInt() ?? 0,
      workmanshipFee: map['workmanship_fee']?.toDouble() ?? 0.0,
      stonePrice: map['stone_price']?.toDouble() ?? 0.0,
      costPrice: map['cost_price']?.toDouble() ?? 0.0,
      imagePath: map['image_path'],
      rfidTag: map['rfid_tag'],
      status: ItemStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ItemStatus.needsRfid,
      ),
      location: ItemLocation.values.firstWhere(
        (e) => e.name == (map['location'] ?? 'warehouse'),
        orElse: () => ItemLocation.warehouse,
      ),
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  // حساب السعر النهائي بناءً على سعر الجرام للمواد
  // gramPrice: السعر الافتراضي (للتوافق السابق) إذا لم يتوفر سعر خاص بالمادة
  double calculateTotalPrice(
    double gramPrice, {
    double? materialSpecificPrice,
  }) {
    final effectivePrice = materialSpecificPrice ?? gramPrice;
    final materialPrice = weightGrams * effectivePrice;
    return materialPrice + workmanshipFee + stonePrice;
  }

  Item copyWith({
    int? id,
    String? sku,
    int? categoryId,
    int? materialId,
    double? weightGrams,
    int? karat,
    double? workmanshipFee,
    double? stonePrice,
    double? costPrice,
    String? imagePath,
    String? rfidTag,
    bool clearRfidTag =
        false, // إذا true سيتم تعيين rfidTag إلى null حتى لو تم تمرير قيمة
    ItemStatus? status,
    ItemLocation? location,
    DateTime? createdAt,
  }) {
    return Item(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      categoryId: categoryId ?? this.categoryId,
      materialId: materialId ?? this.materialId,
      weightGrams: weightGrams ?? this.weightGrams,
      karat: karat ?? this.karat,
      workmanshipFee: workmanshipFee ?? this.workmanshipFee,
      stonePrice: stonePrice ?? this.stonePrice,
      costPrice: costPrice ?? this.costPrice,
      imagePath: imagePath ?? this.imagePath,
      rfidTag: clearRfidTag ? null : (rfidTag ?? this.rfidTag),
      status: status ?? this.status,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Item(id: $id, sku: $sku, weightGrams: $weightGrams, karat: $karat, status: $status)';
  }
}
