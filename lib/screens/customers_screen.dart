import 'package:flutter/cupertino.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/adaptive_scaffold.dart';
import '../models/customer.dart';
import '../providers/customer_provider.dart';
import '../widgets/app_loading_error_widget.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
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
    final customersAsync = ref.watch(customerNotifierProvider);

    return Container(
      color: Color(0xfff6f8fa), // خلفية موحدة
      child: AdaptiveScaffold(
        title: 'العملاء',
        commandBarItems: [
          CommandBarButton(
            icon: const Icon(FluentIcons.add, size: 20),
            label: const Text(
              'إضافة',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            onPressed: () => _showCustomerFormDialog(),
          ),
        ],
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Column(
            children: [
              // شريط البحث
              Padding(
                padding: const EdgeInsets.all(16),
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: 'البحث بالاسم أو الهاتف...',
                  backgroundColor: Color(0xffFFFFFF),
                  style: TextStyle(color: Color(0xff222B45)),
                  placeholderStyle: TextStyle(color: Color(0xff106EBE)),
                ),
              ),

              // قائمة العملاء
              Expanded(
                child: customersAsync.when(
                  data: (customers) => _buildCustomersList(customers),
                  loading: () =>
                      const Center(child: CupertinoActivityIndicator()),
                  error: (error, stack) => AppLoadingErrorWidget(
                    title: 'خطأ في تحميل العملاء',
                    message: error.toString(),
                    onRetry: () => ref.refresh(customerNotifierProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomersList(List<Customer> customers) {
    final searchQuery = _searchController.text.toLowerCase();
    final filteredCustomers = customers.where((customer) {
      return customer.name.toLowerCase().contains(searchQuery) ||
          (customer.phone?.contains(searchQuery) ?? false);
    }).toList();

    if (filteredCustomers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FluentIcons.people,
              size: 80,
              color: FluentTheme.of(context).inactiveColor,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'لا توجد نتائج'
                  : 'لا يوجد عملاء',
              style: FluentTheme.of(context).typography.subtitle,
            ),
            if (_searchController.text.isEmpty) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _showCustomerFormDialog(),
                child: const Text('إضافة عميل جديد'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredCustomers.length,
      itemBuilder: (context, index) {
        final customer = filteredCustomers[index];
        return _buildCustomerCard(customer);
      },
    );
  }

  Widget _buildCustomerCard(Customer customer) {
    return Card(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            FluentIcons.contact,
            color: FluentTheme.of(context).accentColor,
            size: 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (customer.phone != null) Text(customer.phone!),
              ],
            ),
          ),
          Button(
            onPressed: () => _showCustomerFormDialog(customer: customer),
            child: const Icon(FluentIcons.edit),
          ),
          Button(
            onPressed: () => _showDeleteConfirmation(customer),
            child: Icon(FluentIcons.delete, color: Colors.red),
          ),
        ],
      ),
    );
  }

  void _showCustomerFormDialog({Customer? customer}) {
    final isEditMode = customer != null;

    final nameController = TextEditingController(text: customer?.name ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final emailController = TextEditingController(text: customer?.email ?? '');
    final addressController = TextEditingController(
      text: customer?.address ?? '',
    );

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(isEditMode ? 'تعديل العميل' : 'إضافة عميل جديد'),
        content: Column(
          children: [
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: nameController,
              placeholder: 'الاسم *',
              padding: const EdgeInsets.all(12),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: phoneController,
              placeholder: 'الهاتف',
              keyboardType: TextInputType.phone,
              padding: const EdgeInsets.all(12),
            ),
            const SizedBox(height: 12),
            TextBox(
              controller: emailController,
              placeholder: 'البريد الإلكتروني',
              keyboardType: TextInputType.emailAddress,
              padding: const EdgeInsets.all(12),
            ),
            const SizedBox(height: 12),
            TextBox(controller: addressController, placeholder: 'العنوان'),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final newCustomer = Customer(
                  id: customer?.id,
                  name: nameController.text,
                  phone: phoneController.text.isNotEmpty
                      ? phoneController.text
                      : null,
                  email: emailController.text.isNotEmpty
                      ? emailController.text
                      : null,
                  address: addressController.text.isNotEmpty
                      ? addressController.text
                      : null,
                );

                final notifier = ref.read(customerNotifierProvider.notifier);
                if (isEditMode) {
                  await notifier.updateCustomer(newCustomer);
                } else {
                  await notifier.addCustomer(newCustomer);
                }
                if (mounted && context.mounted) {
                  Navigator.pop(context);
                  _showSuccessMessage(
                    isEditMode ? 'تم تحديث العميل' : 'تم إضافة العميل',
                  );
                }
              }
            },
            child: Text(isEditMode ? 'حفظ' : 'إضافة'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('حذف العميل'),
        content: Text('هل أنت متأكد من حذف "${customer.name}"؟'),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(customerNotifierProvider.notifier)
                  .deleteCustomer(customer.id!);
              if (mounted && context.mounted) {
                Navigator.pop(context);
                _showSuccessMessage('تم حذف العميل بنجاح');
              }
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('نجاح'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('موافق'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
