import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../widgets/adaptive_scaffold.dart';
import '../models/invoice.dart';
import '../providers/invoice_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/app_loading_error_widget.dart';
import '../models/customer.dart';
import '../providers/customer_provider.dart';
import '../services/printer_facade.dart';
import '../services/user_service.dart';
// import '../providers/print_provider.dart'; // Will be used for re-printing

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {}); // Rebuild on search query change
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoiceNotifierProvider);
    final currency = ref.watch(currencyProvider);

    return AdaptiveScaffold(
      title: 'الفواتير',
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => ref.read(invoiceNotifierProvider.notifier).refresh(),
          child: const Icon(CupertinoIcons.refresh),
        ),
      ],
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'بحث برقم الفاتورة أو اسم العميل...',
              ),
            ),
            Expanded(
              child: invoicesAsync.when(
                data: (invoices) => _buildInvoicesList(invoices, currency),
                loading: () =>
                    const Center(child: CupertinoActivityIndicator()),
                error: (err, stack) => AppLoadingErrorWidget(
                  title: 'خطأ في تحميل الفواتير',
                  message: err.toString(),
                  onRetry: () => ref.refresh(invoiceNotifierProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesList(
    List<Invoice> invoices,
    AsyncValue<String> currency,
  ) {
    final customersAsync = ref.watch(customerNotifierProvider);
    final searchQuery = _searchController.text.toLowerCase();

    return customersAsync.when(
      data: (customers) {
        final filteredInvoices = invoices.where((invoice) {
          final customer = customers.firstWhere(
            (c) => c.id == invoice.customerId,
            orElse: () => Customer(
              id: -1,
              name: 'غير معروف',
            ), // Placeholder for unknown customer
          );
          final customerName = customer.name.toLowerCase();
          return invoice.invoiceNumber.toLowerCase().contains(searchQuery) ||
              customerName.contains(searchQuery);
        }).toList();

        if (filteredInvoices.isEmpty) {
          return const Center(child: Text('لا توجد فواتير'));
        }

        return ListView.builder(
          itemCount: filteredInvoices.length,
          itemBuilder: (context, index) {
            final invoice = filteredInvoices[index];
            final customer = customers.firstWhere(
              (c) => c.id == invoice.customerId,
              orElse: () => Customer(id: -1, name: 'غير معروف'),
            );
            return _buildInvoiceCard(invoice, currency, customer);
          },
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, stack) => AppLoadingErrorWidget(
        title: 'خطأ في تحميل العملاء',
        message: error.toString(),
        onRetry: () => ref.refresh(customerNotifierProvider),
      ),
    );
  }

  Widget _buildInvoiceCard(
    Invoice invoice,
    AsyncValue<String> currency,
    Customer customer,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.1),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                invoice.invoiceNumber,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              currency.when(
                data: (curr) => Text(
                  '${invoice.total.toStringAsFixed(2)} $curr',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: CupertinoColors.activeGreen,
                  ),
                ),
                loading: () => const CupertinoActivityIndicator(),
                error: (e, s) => const Text('Error'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('العميل: ${customer.name}'),
          const SizedBox(height: 4),
          Text(
            'التاريخ: ${DateFormat('yyyy-MM-dd – hh:mm a').format(invoice.createdAt)}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                color: CupertinoColors.activeBlue,
                child: const Text(
                  'طباعة حرارية',
                  style: TextStyle(fontSize: 12),
                ),
                onPressed: () => _reprintInvoice(
                  invoice,
                  mode: InvoicePrintMode.thermal,
                  customer: customer,
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                color: CupertinoColors.systemGrey,
                child: const Text('طباعة HTML', style: TextStyle(fontSize: 12)),
                onPressed: () => _reprintInvoice(
                  invoice,
                  mode: InvoicePrintMode.html,
                  customer: customer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _reprintInvoice(
    Invoice invoice, {
    required InvoicePrintMode mode,
    required Customer customer,
  }) async {
    try {
      // لا توجد عناصر محفوظة للفواتير حالياً (invoice_items) — سيتم استخدام بيانات مبسطة
      // TODO: عند تنفيذ حفظ invoice_items يجب جلبها هنا
      final invoiceRepo = ref.read(invoiceRepositoryProvider);
      final items = await invoiceRepo.getInvoiceCartItems(invoice.id!);
      final printer = PrinterFacade();
      final user = UserService().currentUser;
      await printer.printInvoice(
        invoice: invoice,
        items: items,
        mode: mode,
        customerName: customer.name,
        cashierName: user?.fullName,
      );
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (c) => CupertinoAlertDialog(
            title: const Text('خطأ'),
            content: Text('فشل في إعادة الطباعة: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('موافق'),
                onPressed: () => Navigator.pop(c),
              ),
            ],
          ),
        );
      }
    }
  }
}
