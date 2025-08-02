import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice.dart';
import '../repositories/invoice_repository.dart';
import '../models/cart_item.dart';

// Provider for the repository
final invoiceRepositoryProvider = Provider((ref) => InvoiceRepository());

// State Notifier for invoices
class InvoiceNotifier extends StateNotifier<AsyncValue<List<Invoice>>> {
  final InvoiceRepository _repository;

  InvoiceNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadInvoices();
  }

  Future<void> loadInvoices() async {
    try {
      final invoices = await _repository.getAllInvoices();
      state = AsyncValue.data(invoices);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> addInvoice(Invoice invoice, List<CartItem> items) async {
    try {
      await _repository.createSaleTransaction(invoice, items);
      loadInvoices();
    } catch (e) {
      // In a real app, you might want to handle this more gracefully
      // For now, just rethrow the error to be caught by the UI.
      throw Exception('Failed to add invoice: $e');
    }
  }

  void refresh() {
    loadInvoices();
  }
}

// The provider that the UI will interact with
final invoiceNotifierProvider =
    StateNotifierProvider<InvoiceNotifier, AsyncValue<List<Invoice>>>((ref) {
      final repository = ref.watch(invoiceRepositoryProvider);
      return InvoiceNotifier(repository);
    });
