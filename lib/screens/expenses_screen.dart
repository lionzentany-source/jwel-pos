import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/adaptive_scaffold.dart';
import '../models/expense.dart';
import '../repositories/expense_repository.dart';

final _expensesRepositoryProvider = Provider<ExpenseRepository>((ref) => ExpenseRepository());

class ExpenseDateRange {
  final DateTime start;
  final DateTime end;
  const ExpenseDateRange({required this.start, required this.end});
}

final expensesFutureProvider = FutureProvider.family<List<Expense>, ExpenseDateRange>((ref, range) async {
  final repo = ref.watch(_expensesRepositoryProvider);
  return repo.getExpensesByDateRange(start: range.start, end: range.end);
});

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});
  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();

  @override
  Widget build(BuildContext context) {
  final range = ExpenseDateRange(start: _from, end: _to);
  final expensesAsync = ref.watch(expensesFutureProvider(range));
    return AdaptiveScaffold(
      title: 'المصروفات',
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _pickDates,
          child: const Icon(CupertinoIcons.calendar),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showAddExpense,
          child: const Icon(CupertinoIcons.add),
        ),
      ],
      body: expensesAsync.when(
        data: (list) => _buildList(list),
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
    );
  }

  Widget _buildList(List<Expense> expenses) {
    double total = expenses.fold(0, (p, e) => p + e.amount);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الإجمالي: ${total.toStringAsFixed(2)} د.ل', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${expenses.length} سجل'),
            ],
          ),
        ),
  _separator(),
        Expanded(
          child: expenses.isEmpty
              ? const Center(child: Text('لا توجد مصروفات ضمن الفترة'))
              : ListView.separated(
                  itemCount: expenses.length,
                  separatorBuilder: (_, __) => _separator(),
                  itemBuilder: (c, i) {
                    final e = expenses[i];
                    return Dismissible(
                      key: ValueKey(e.id ?? '${e.title}-${e.date}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: CupertinoColors.systemRed,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Icon(CupertinoIcons.trash, color: CupertinoColors.white),
                      ),
                      confirmDismiss: (_) async => await _confirmDelete(),
                      onDismissed: (_) => _deleteExpense(e),
                      child: GestureDetector(
                        onTap: () => _showAddExpense(edit: e),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text('${e.category.displayName} • ${e.date.toString().split(' ').first}', style: const TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel)),
                                  ],
                                ),
                              ),
                              Text('${e.amount.toStringAsFixed(2)} د.ل', style: const TextStyle(color: CupertinoColors.activeBlue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _pickDates() async {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 400,
        color: CupertinoColors.systemBackground,
        child: Column(
          children: [
            _modalBar('اختيار الفترة'),
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  const Text('من'),
                  SizedBox(
                    height: 140,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: _from,
                      onDateTimeChanged: (d) => _from = d,
                    ),
                  ),
                  const Text('إلى'),
                  SizedBox(
                    height: 140,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: _to,
                      onDateTimeChanged: (d) => _to = d,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    child: const Text('إلغاء'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                  child: CupertinoButton(
                    child: const Text('تطبيق'),
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddExpense({Expense? edit}) async {
    final titleCtrl = TextEditingController(text: edit?.title);
    final amountCtrl = TextEditingController(text: edit != null ? edit.amount.toStringAsFixed(2) : '');
    final notesCtrl = TextEditingController(text: edit?.notes ?? '');
    ExpenseCategory category = edit?.category ?? ExpenseCategory.other;
    DateTime date = edit?.date ?? DateTime.now();

    await showCupertinoModalPopup(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setInner) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _modalBar(edit == null ? 'إضافة مصروف' : 'تعديل مصروف'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('العنوان'),
                      const SizedBox(height: 4),
                      CupertinoTextField(controller: titleCtrl, placeholder: 'مثال: رواتب شهرية'),
                      const SizedBox(height: 12),
                      const Text('الفئة'),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: ExpenseCategory.values.map((c) {
                          final selected = c == category;
                          return GestureDetector(
                            onTap: () => setInner(() => category = c),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? CupertinoColors.activeBlue : CupertinoColors.systemGrey5,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(c.displayName, style: TextStyle(color: selected ? CupertinoColors.white : CupertinoColors.label)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      const Text('المبلغ'),
                      const SizedBox(height: 4),
                      CupertinoTextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        placeholder: '0.00',
                      ),
                      const SizedBox(height: 12),
                      const Text('التاريخ'),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => showCupertinoModalPopup(
                          context: context,
                          builder: (_) => SizedBox(
                            height: 300,
                            child: Column(
                              children: [
                                _modalBar('اختيار التاريخ'),
                                Expanded(
                                  child: CupertinoDatePicker(
                                    mode: CupertinoDatePickerMode.date,
                                    initialDateTime: date,
                                    onDateTimeChanged: (d) => setInner(() => date = d),
                                  ),
                                ),
                                CupertinoButton(
                                  child: const Text('تم'),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey5,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(date.toString().split(' ').first),
                              const Icon(CupertinoIcons.calendar),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('ملاحظات (اختياري)'),
                      const SizedBox(height: 4),
                      CupertinoTextField(
                        controller: notesCtrl,
                        maxLines: 3,
                        placeholder: 'ملاحظات إضافية',
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      child: const Text('إلغاء'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Expanded(
                    child: CupertinoButton.filled(
                      child: const Text('حفظ'),
                      onPressed: () async {
                        final amount = double.tryParse(amountCtrl.text) ?? 0;
                        if (titleCtrl.text.trim().isEmpty || amount <= 0) return;
                        final repo = ref.read(_expensesRepositoryProvider);
                        final expense = Expense(
                          id: edit?.id,
                          title: titleCtrl.text.trim(),
                          category: category,
                          amount: amount,
                          date: date,
                          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                        );
                        if (edit == null) {
                          await repo.insert(expense);
                        } else {
                          await repo.update(expense);
                        }
                        if (mounted) Navigator.pop(context);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      }),
    );
  }

  Future<bool> _confirmDelete() async {
    bool confirmed = false;
    await showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('حذف'),
        content: const Text('تأكيد الحذف؟'),
        actions: [
          CupertinoDialogAction(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(context),
          ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('حذف'),
              onPressed: () {
                confirmed = true;
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
    return confirmed;
  }

  Future<void> _deleteExpense(Expense e) async {
  final repo = ref.read(_expensesRepositoryProvider);
    if (e.id != null) {
      await repo.delete(e.id!);
      setState(() {});
    }
  }

  Widget _modalBar(String title) => Container(
        height: 50,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: CupertinoColors.separator),
          ),
        ),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
}

Widget _separator() => Container(height: 1, color: CupertinoColors.separator);
