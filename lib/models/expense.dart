enum ExpenseCategory {
  salaries('رواتب'),
  electricity('كهرباء'),
  rent('إيجار'),
  maintenance('صيانة'),
  other('أخرى');
  const ExpenseCategory(this.displayName);
  final String displayName;
}

class Expense {
  final int? id;
  final String title;
  final ExpenseCategory category;
  final double amount;
  final DateTime date;
  final String? notes;

  Expense({
    this.id,
    required this.title,
    required this.category,
    required this.amount,
    DateTime? date,
    this.notes,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'category': category.name,
        'amount': amount,
        'date': date.toIso8601String(),
        'notes': notes,
      };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
        id: map['id']?.toInt(),
        title: map['title'] ?? '',
        category: ExpenseCategory.values.firstWhere(
          (c) => c.name == map['category'],
          orElse: () => ExpenseCategory.other,
        ),
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        date: DateTime.parse(map['date']),
        notes: map['notes'],
      );
}
