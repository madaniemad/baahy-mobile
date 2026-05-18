import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _notesCtrl = TextEditingController();
  String _paymentMethod = 'cash_on_delivery';
  Map<String, dynamic>? _selectedAddress;
  bool _loading = false;
  List<Map<String, dynamic>> _addresses = [];

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final res = await ApiClient.instance.dio.get('/addresses');
      final list = (res.data['data'] as List?)
          ?.map((a) => Map<String, dynamic>.from(a)).toList() ?? [];
      setState(() {
        _addresses = list;
        _selectedAddress = list.firstWhere(
          (a) => a['is_default'] == true, orElse: () => list.isNotEmpty ? list.first : {});
      });
    } catch (_) {}
  }

  Future<void> _placeOrder() async {
    if (_selectedAddress == null || _selectedAddress!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى اختيار عنوان التوصيل')));
      return;
    }
    setState(() => _loading = true);

    // Validate cart stock before placing order
    final validationError = await ref.read(cartProvider.notifier).validate();
    if (validationError != null) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(validationError), backgroundColor: AppColors.danger));
      }
      return;
    }

    try {
      final cart = ref.read(cartProvider);
      final addr = _selectedAddress!;
      final res = await ApiClient.instance.dio.post('/orders', data: {
        'items': cart.items.map((i) => {
          'product_id': i.productId,
          if (i.variationId != null) 'variation_id': i.variationId,
          'quantity': i.quantity,
        }).toList(),
        'payment_method': _paymentMethod,
        'shipping_name': addr['label'] ?? addr['name'] ?? '',
        'shipping_phone': addr['phone'] ?? '',
        'shipping_city': addr['city'] ?? '',
        'shipping_address':
            [addr['district'], addr['street'], addr['notes']].where((v) => v != null && v.toString().isNotEmpty).join('، '),
        if (cart.couponCode != null) 'coupon_code': cart.couponCode,
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      });
      await ref.read(cartProvider.notifier).clear();
      if (mounted) {
        context.pushReplacement('/order-confirmed', extra: res.data['data']);
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('حدث خطأ، حاول مجدداً'),
            backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('إتمام الشراء',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink0)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Address section
                  _SectionTitle('عنوان التوصيل'),
                  const SizedBox(height: 8),
                  if (_addresses.isEmpty)
                    GestureDetector(
                      onTap: () => context.push('/addresses/edit'),
                      child: _AddressCard(
                        child: Row(
                          children: const [
                            Icon(Icons.add, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('إضافة عنوان جديد',
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    )
                  else
                    ...(_addresses.map((addr) => GestureDetector(
                      onTap: () => setState(() => _selectedAddress = addr),
                      child: _AddressCard(
                        selected: _selectedAddress?['id'] == addr['id'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(addr['label'] ?? 'عنوان',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(
                              [addr['city'], addr['district'], addr['street']]
                                .where((v) => v != null && v.toString().isNotEmpty)
                                .join('، '),
                              style: const TextStyle(color: AppColors.ink2, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ))),

                  const SizedBox(height: 20),

                  // Payment method
                  _SectionTitle('طريقة الدفع'),
                  const SizedBox(height: 8),
                  _PaymentOption('cash_on_delivery', 'الدفع عند الاستلام', Icons.payments_outlined,
                    _paymentMethod, (v) => setState(() => _paymentMethod = v)),
                  const SizedBox(height: 8),
                  _PaymentOption('wallet', 'المحفظة', Icons.account_balance_wallet_outlined,
                    _paymentMethod, (v) => setState(() => _paymentMethod = v)),

                  const SizedBox(height: 20),

                  // Notes
                  _SectionTitle('ملاحظات (اختياري)'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'أي تعليمات خاصة بطلبك...',
                        hintStyle: TextStyle(color: AppColors.ink3, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Order summary
                  _SectionTitle('ملخص الطلب'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppShadows.shadowCard,
                    ),
                    child: Column(
                      children: [
                        _SummaryRow('المجموع الفرعي', '${cart.subtotal.toStringAsFixed(0)} د.ل'),
                        if (cart.discountAmount > 0)
                          _SummaryRow('خصم الكوبون',
                            '− ${cart.discountAmount.toStringAsFixed(0)} د.ل',
                            color: AppColors.success),
                        _SummaryRow(
                          'الشحن',
                          cart.deliveryFee == 0 ? 'مجاني' : '${cart.deliveryFee.toStringAsFixed(0)} د.ل',
                          color: cart.deliveryFee == 0 ? AppColors.success : null,
                        ),
                        const Divider(height: 20, color: AppColors.border),
                        _SummaryRow('الإجمالي', '${cart.total.toStringAsFixed(0)} د.ل', bold: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(color: Colors.white, boxShadow: AppShadows.shadowPop),
            child: AppButton(
              label: 'تأكيد الطلب',
              onTap: _placeOrder,
              loading: _loading,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800));
}

class _AddressCard extends StatelessWidget {
  final Widget child;
  final bool selected;
  const _AddressCard({required this.child, this.selected = false});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
      boxShadow: AppShadows.shadowCard,
    ),
    child: child,
  );
}

class _PaymentOption extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final String selected;
  final void Function(String) onChanged;

  const _PaymentOption(this.value, this.label, this.icon, this.selected, this.onChanged);

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.ink2, size: 22),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.primary : AppColors.ink0)),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

Widget _SummaryRow(String label, String value,
    {Color? color, bool bold = false}) =>
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(value, style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 14,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: color ?? AppColors.ink0)),
      ],
    ),
  );
