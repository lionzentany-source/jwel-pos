import 'package:flutter/cupertino.dart';
import '../widgets/thin_divider.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/adaptive_scaffold.dart';
import '../models/expense.dart';
import '../widgets/app_loading_error_widget.dart';
import '../repositories/expense_repository.dart';
import 'dart:async';

final _expensesRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

// كائن كاش بسيط بمدة صلاحية
class _ExpensesCacheEntry {
  final List<Expense> data;
  final DateTime fetchedAt;
  _ExpensesCacheEntry(this.data, this.fetchedAt);
}

class _ExpensesCache {
  final Map<String, _ExpensesCacheEntry> _store = {};
  Duration ttl = const Duration(seconds: 30);

  List<Expense>? get(String key) {
    final e = _store[key];
    if (e == null) return null;
    if (DateTime.now().difference(e.fetchedAt) > ttl) {
      _store.remove(key);
      return null;
    }
    return e.data;
  }

  void set(String key, List<Expense> data) {
    _store[key] = _ExpensesCacheEntry(data, DateTime.now());
  }

  void invalidateAll() => _store.clear();
  void invalidateKey(String key) => _store.remove(key);
}

final _expensesCacheProvider = Provider<_ExpensesCache>((ref) {
  return _ExpensesCache();
});

class ExpenseDateRange {
  final DateTime start;
  final DateTime end;
  const ExpenseDateRange({required this.start, required this.end});
}

final expensesFutureProvider = FutureProvider.autoDispose
    .family<List<Expense>, ExpenseDateRange>((ref, range) async {
      // إبقاء المزود حي لفترة قصيرة لتجنب التخلص السريع أثناء التبديل
      final link = ref.keepAlive();
      Timer(const Duration(minutes: 2), () {
        link.close();
      });

      final cache = ref.read(_expensesCacheProvider);
      final key =
          '${range.start.toIso8601String()}|${range.end.toIso8601String()}';
      final cached = cache.get(key);
      if (cached != null) {
        return cached;
      }
      final repo = ref.read(_expensesRepositoryProvider);
      final result = await repo
          .getExpensesByDateRange(start: range.start, end: range.end)
          .timeout(const Duration(seconds: 8), onTimeout: () => <Expense>[]);
      cache.set(key, result);
      return result;
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
    return Container(
      color: Color(0xfff6f8fa), // خلفية موحدة
      child: AdaptiveScaffold(
        title: 'المصروفات',
        commandBarItems: [
          CommandBarButton(
            icon: const Icon(FluentIcons.calendar, size: 20),
            label: const Text(
              'الفترة',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            onPressed: _pickDates,
          ),
          CommandBarButton(
            icon: const Icon(FluentIcons.add, size: 20),
            label: const Text(
              'إضافة',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            onPressed: _showAddExpense,
          ),
        ],
        body: expensesAsync.when(
          data: (list) => _buildList(list),
          loading: () => const Center(child: ProgressRing()),
          error: (e, _) => AppLoadingErrorWidget(
            title: 'خطأ في تحميل المصروفات',
            message: e.toString(),
            onRetry: () => setState(() {}),
          ),
        ),
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
              Text(
                'الإجمالي: ${total.toStringAsFixed(2)} د.ل',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('${expenses.length} سجل'),
            ],
          ),
        ),
        _separator(),
        Expanded(
          child: expenses.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  itemCount: expenses.length,
                  separatorBuilder: (_, __) => const ThinDivider(),
                  itemBuilder: (c, i) {
                    final e = expenses[i];
                    return Dismissible(
                      key: ValueKey(e.id ?? '${e.title}-${e.date}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Icon(
                          FluentIcons.delete,
                          color: Colors.white,
                        ),
                      ),
                      confirmDismiss: (_) async => await _confirmDelete(),
                      onDismissed: (_) => _deleteExpense(e),
                      child: GestureDetector(
                        onTap: () => _showAddExpense(edit: e),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${e.category.displayName} • ${e.date.toString().split(' ').first}',
                                      style: FluentTheme.of(
                                        context,
                                      ).typography.caption,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${e.amount.toStringAsFixed(2)} د.ل',
                                style: TextStyle(
                                  color: FluentTheme.of(context).accentColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
    DateTime tempStart = _from;
    DateTime tempEnd = _to;
    await showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 420,
        color: CupertinoColors.systemBackground,
        child: Column(
          children: [
            Container(
              height: 50,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: CupertinoColors.separator),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('إلغاء'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'اختيار الفترة',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  CupertinoButton(
                    child: const Text('تطبيق'),
                    onPressed: () {
                      setState(() {
                        _from = tempStart;
                        _to = tempEnd;
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    const Text('من'),
                    SizedBox(
                      height: 160,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: tempStart,
                        onDateTimeChanged: (d) => tempStart = d,
                      ),
                    ),
                    const Text('إلى'),
                    SizedBox(
                      height: 160,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: tempEnd,
                        onDateTimeChanged: (d) => tempEnd = d,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddExpense({Expense? edit}) async {
    final titleCtrl = TextEditingController(text: edit?.title);
    final amountCtrl = TextEditingController(
      text: edit != null ? edit.amount.toStringAsFixed(2) : '',
    );
    final notesCtrl = TextEditingController(text: edit?.notes ?? '');
    ExpenseCategory category = edit?.category ?? ExpenseCategory.other;
    DateTime date = edit?.date ?? DateTime.now();

    await showCupertinoModalPopup(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setInner) {
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
                        CupertinoTextField(
                          controller: titleCtrl,
                          placeholder: 'مثال: رواتب شهرية',
                        ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? CupertinoColors.activeBlue
                                      : CupertinoColors.systemGrey5,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  c.displayName,
                                  style: TextStyle(
                                    color: selected
                                        ? CupertinoColors.white
                                        : CupertinoColors.label,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        const Text('المبلغ'),
                        const SizedBox(height: 4),
                        CupertinoTextField(
                          controller: amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
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
                                      onDateTimeChanged: (d) =>
                                          setInner(() => date = d),
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
                          if (titleCtrl.text.trim().isEmpty || amount <= 0) {
                            return;
                          }
                          final repo = ref.read(_expensesRepositoryProvider);
                          final expense = Expense(
                            id: edit?.id,
                            title: titleCtrl.text.trim(),
                            category: category,
                            amount: amount,
                            date: date,
                            notes: notesCtrl.text.trim().isEmpty
                                ? null
                                : notesCtrl.text.trim(),
                          );
                          if (edit == null) {
                            await repo.insert(expense);
                          } else {
                            await repo.update(expense);
                          }
                          // تنظيف الكاش لضمان التحديث
                          ref.read(_expensesCacheProvider).invalidateAll();
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
        },
      ),
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
      ref.read(_expensesCacheProvider).invalidateAll();
      setState(() {});
    }
  }

  Widget _modalBar(String title) => Container(
    height: 50,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: CupertinoColors.separator)),
    ),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
  );

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              CupertinoIcons.doc_plaintext,
              size: 48,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'لا توجد مصروفات ضمن الفترة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            onPressed: () => setState(() {}),
            child: const Text('تحديث'),
          ),
        ],
      ),
    );
  }
}

Widget _separator() => Container(height: 1, color: CupertinoColors.separator);
