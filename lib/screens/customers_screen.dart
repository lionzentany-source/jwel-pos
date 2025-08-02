import 'package:flutter/cupertino.dart';
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

    return AdaptiveScaffold(
      title: 'العملاء',
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showCustomerFormDialog(),
          child: const Icon(CupertinoIcons.add),
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
            const Icon(
              CupertinoIcons.person_2,
              size: 80,
              color: CupertinoColors.systemGrey3,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'لا توجد نتائج'
                  : 'لا يوجد عملاء',
              style: const TextStyle(
                fontSize: 18,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            if (_searchController.text.isEmpty) ...[
              const SizedBox(height: 24),
              CupertinoButton.filled(
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.person_fill,
            color: CupertinoColors.activeBlue,
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
          CupertinoButton(
            onPressed: () => _showCustomerFormDialog(customer: customer),
            child: const Icon(CupertinoIcons.pencil),
          ),
          CupertinoButton(
            onPressed: () => _showDeleteConfirmation(customer),
            child: const Icon(
              CupertinoIcons.trash,
              color: CupertinoColors.systemRed,
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomerFormDialog({Customer? customer}) {
    final isEditMode = customer != null;
    final formKey = GlobalKey<FormState>();
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
        content: Form(
          key: formKey,
          child: Column(
            children: [
              const SizedBox(height: 16),
              CupertinoTextFormFieldRow(
                controller: nameController,
                placeholder: 'الاسم *',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الاسم مطلوب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              CupertinoTextFormFieldRow(
                controller: phoneController,
                placeholder: 'الهاتف',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              CupertinoTextFormFieldRow(
                controller: emailController,
                placeholder: 'البريد الإلكتروني',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null &&
                      value.isNotEmpty &&
                      !value.contains('@')) {
                    return 'بريد إلكتروني غير صالح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: addressController,
                placeholder: 'العنوان',
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
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
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('حذف العميل'),
        content: Text('هل أنت متأكد من حذف "${customer.name}"؟'),
        actions: [
          CupertinoDialogAction(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
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
