import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer.dart';
import '../repositories/customer_repository.dart';

// Provider for the repository itself
final customerRepositoryProvider = Provider((ref) => CustomerRepository());

// State Notifier for the list of customers
class CustomerNotifier extends StateNotifier<AsyncValue<List<Customer>>> {
  final CustomerRepository _repository;

  CustomerNotifier(this._repository) : super(const AsyncValue.loading()) {
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final customers = await _repository.getAllCustomers();
      state = AsyncValue.data(customers);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> addCustomer(Customer customer) async {
    state = const AsyncValue.loading();
    try {
      await _repository.insertCustomer(customer);
      _loadCustomers();
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateCustomer(customer);
      _loadCustomers();
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> deleteCustomer(int customerId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteCustomer(customerId);
      _loadCustomers();
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  void refresh() {
    _loadCustomers();
  }
}

// The provider that the UI will interact with
final customerNotifierProvider = StateNotifierProvider<CustomerNotifier, AsyncValue<List<Customer>>>((ref) {
  final repository = ref.watch(customerRepositoryProvider);
  return CustomerNotifier(repository);
});
