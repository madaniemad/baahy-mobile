import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/app_config.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/widgets/app_button.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  int _step = 1;
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
        'shipping_name': addr['name'] ?? addr['label'] ?? '',
        'shipping_phone': addr['phone'] ?? '',
        'shipping_city': addr['city'] ?? '',
        'shipping_address': addr['address'] ?? '',
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

  void _next() {
    if (_step < 3) {
      setState(() => _step++);
    } else {
      _placeOrder();
    }
  }

  void _back() {
    if (_step > 1) {
      setState(() => _step--);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header with step counter
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
                    child: Row(children: [
                      IconButton(
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back, color: AppColors.ink0)),
                      const Expanded(
                        child: Text('إتمام الطلب',
                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800,
                            fontSize: 17)),
                      ),
                      Text('$_step/3',
                        style: const TextStyle(fontFamily: 'PlusJakartaSans',
                          fontSize: 13, color: AppColors.ink3)),
                    ]),
                  ),
                  // Step indicator
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Row(
                      children: [
                        for (int i = 1; i <= 3; i++) ...[
                          _StepCircle(number: i, current: _step),
                          if (i < 3)
                            Expanded(
                              child: Container(
                                height: 2,
                                color: _step > i ? AppColors.ink0 : AppColors.border,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('العنوان',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: _step == 1 ? AppColors.ink0 : AppColors.ink3)),
                        Text('الدفع',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: _step == 2 ? AppColors.ink0 : AppColors.ink3)),
                        Text('مراجعة',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: _step == 3 ? AppColors.ink0 : AppColors.ink3)),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                ],
              ),
            ),

            // Step content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _step == 1
                        ? _StepAddress(
                            addresses: _addresses,
                            selected: _selectedAddress,
                            onSelect: (a) => setState(() => _selectedAddress = a),
                            onAddNew: () => safePush(context, '/addresses/edit'),
                            deliveryPromise: config.deliveryPromiseAr,
                          )
                        : _step == 2
                            ? _StepPayment(
                                selected: _paymentMethod,
                                onChanged: (v) => setState(() => _paymentMethod = v),
                                notesCtrl: _notesCtrl,
                                config: config,
                              )
                            : _StepReview(
                                cart: cart,
                                address: _selectedAddress,
                                paymentMethod: _paymentMethod,
                                onChangeAddress: () => setState(() => _step = 1),
                                onChangePayment: () => setState(() => _step = 2),
                                config: config,
                              ),
                  ),
                ),
              ),
            ),

            // Bottom bar
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16,
                MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: AppShadows.shadowPop,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الإجمالي',
                        style: TextStyle(fontSize: 13, color: AppColors.ink2)),
                      Text('${cart.total.toStringAsFixed(0)} د.ل',
                        style: const TextStyle(fontFamily: 'PlusJakartaSans',
                          fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    label: _step < 3 ? 'متابعة' : 'تأكيد الطلب',
                    icon: _step < 3
                        ? const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Colors.white)
                        : const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                    onTap: _next,
                    loading: _loading,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int number;
  final int current;
  const _StepCircle({required this.number, required this.current});

  @override
  Widget build(BuildContext context) {
    final isDone = current > number;
    final isActive = current == number;
    return Container(
      width: 26, height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (isDone || isActive) ? AppColors.ink0 : AppColors.surfaceSoft,
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : Text('$number',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : AppColors.ink3)),
      ),
    );
  }
}

// ── Step 1: Address ───────────────────────────────────────────────────────────

class _StepAddress extends StatelessWidget {
  final List<Map<String, dynamic>> addresses;
  final Map<String, dynamic>? selected;
  final void Function(Map<String, dynamic>) onSelect;
  final VoidCallback onAddNew;
  final String deliveryPromise;
  const _StepAddress({required this.addresses, required this.selected,
    required this.onSelect, required this.onAddNew, required this.deliveryPromise});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('عنوان التسليم',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      const Text('أين نوصل الطلب؟',
        style: TextStyle(fontSize: 13, color: AppColors.ink2)),
      const SizedBox(height: 16),

      ...addresses.map((addr) => GestureDetector(
        onTap: () => onSelect(addr),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected?['id'] == addr['id'] ? AppColors.primary : AppColors.border,
              width: selected?['id'] == addr['id'] ? 1.5 : 1),
            boxShadow: AppShadows.shadowCard,
          ),
          child: Row(children: [
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: selected?['id'] == addr['id']
                    ? null
                    : Border.all(color: AppColors.borderStrong, width: 1.5),
                color: selected?['id'] == addr['id']
                    ? AppColors.primary : Colors.transparent,
              ),
              child: selected?['id'] == addr['id']
                  ? const Icon(Icons.circle, size: 8, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${addr['label'] ?? 'عنوان'} · ',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(
                [addr['city'], addr['address']]
                  .where((v) => v != null && v.toString().isNotEmpty)
                  .join('، '),
                style: const TextStyle(fontSize: 12.5, color: AppColors.ink2)),
            ])),
          ]),
        ),
      )),

      if (addresses.isEmpty)
        GestureDetector(
          onTap: onAddNew,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: const Row(children: [
              Icon(Icons.add, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text('إضافة عنوان جديد',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),

      if (addresses.isNotEmpty) ...[
        OutlinedButton.icon(
          onPressed: onAddNew,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('إضافة عنوان جديد'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 44),
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),
      ],

      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.teal600),
          const SizedBox(width: 8),
          Expanded(child: Text(deliveryPromise,
            style: const TextStyle(fontSize: 12.5, color: AppColors.ink1))),
        ]),
      ),
    ]);
  }
}

// ── Step 2: Payment ───────────────────────────────────────────────────────────

class _StepPayment extends StatelessWidget {
  final String selected;
  final void Function(String) onChanged;
  final TextEditingController notesCtrl;
  final dynamic config; // AppConfig
  const _StepPayment({required this.selected, required this.onChanged,
    required this.notesCtrl, required this.config});

  @override
  Widget build(BuildContext context) {
    final methods = (config.paymentMethods as List)
        .where((m) => m.enabled == true)
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('طريقة الدفع',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),

      ...methods.map((m) => GestureDetector(
        onTap: () => onChanged(m.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected == m.id ? const Color(0xFFF5F5F5) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected == m.id ? AppColors.primary : AppColors.border,
              width: selected == m.id ? 1.5 : 1),
          ),
          child: Row(children: [
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: selected == m.id
                    ? null
                    : Border.all(color: AppColors.borderStrong, width: 1.5),
                color: selected == m.id ? AppColors.primary : Colors.transparent,
              ),
              child: selected == m.id
                  ? const Icon(Icons.circle, size: 8, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.labelAr, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(
                m.descriptionAr.isNotEmpty ? m.descriptionAr
                    : (m.fee > 0 ? 'رسوم خدمة ${m.fee.toStringAsFixed(0)} د.ل' : 'بدون رسوم'),
                style: const TextStyle(fontSize: 11.5, color: AppColors.ink2)),
            ])),
          ]),
        ),
      )),

      const SizedBox(height: 16),
      const Text('ملاحظات (اختياري)',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: TextField(
          controller: notesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'أي تعليمات خاصة بطلبك...',
            hintStyle: TextStyle(color: AppColors.ink3, fontSize: 14),
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(14),
          ),
        ),
      ),
    ]);
  }
}

// ── Step 3: Review ────────────────────────────────────────────────────────────

class _StepReview extends StatelessWidget {
  final CartState cart;
  final Map<String, dynamic>? address;
  final String paymentMethod;
  final VoidCallback onChangeAddress;
  final VoidCallback onChangePayment;
  final dynamic config; // AppConfig
  const _StepReview({required this.cart, required this.address,
    required this.paymentMethod, required this.onChangeAddress,
    required this.onChangePayment, required this.config});

  String get _paymentLabel {
    final match = (config.paymentMethods as List<PaymentMethod>)
        .where((m) => m.id == paymentMethod)
        .firstOrNull;
    return match?.labelAr ?? paymentMethod;
  }

  @override
  Widget build(BuildContext context) {
    final addr = address;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('مراجعة الطلب',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),

      // Address card
      Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.location_on_outlined, size: 18, color: AppColors.ink2),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('التسليم إلى',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                  color: AppColors.ink2, letterSpacing: 0.3)),
              GestureDetector(
                onTap: onChangeAddress,
                child: const Text('تغيير',
                  style: TextStyle(fontSize: 12, color: AppColors.teal600,
                    fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 6),
            if (addr != null) ...[
              if ((addr['name'] as String?)?.isNotEmpty == true)
                Text(addr['name'] as String,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              if ((addr['phone'] as String?)?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(addr['phone'] as String,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.ink2,
                      fontFamily: 'PlusJakartaSans')),
                ),
              const SizedBox(height: 3),
              Text(
                [addr['label'], addr['city'], addr['address']]
                  .where((v) => v != null && v.toString().isNotEmpty)
                  .join(' · '),
                style: const TextStyle(fontSize: 12.5, color: AppColors.ink1)),
            ],
          ])),
        ]),
      ),

      // Payment card
      Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.credit_card_outlined, size: 18, color: AppColors.ink2),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('الدفع',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                  color: AppColors.ink2, letterSpacing: 0.3)),
              GestureDetector(
                onTap: onChangePayment,
                child: const Text('تغيير',
                  style: TextStyle(fontSize: 12, color: AppColors.teal600,
                    fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(_paymentLabel, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ])),
        ]),
      ),

      // Product list
      Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('المنتجات (${cart.items.length})',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
              color: AppColors.ink2, letterSpacing: 0.3)),
          const SizedBox(height: 10),
          ...cart.items.map((item) {
            final variationLabel = item.variation?.attributes
                .map((a) => isAr ? a.valueAr : a.value)
                .where((v) => v.isNotEmpty)
                .join(' · ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: item.image != null
                      ? CachedNetworkImage(
                          imageUrl: item.image!,
                          width: 56, height: 56,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 56, height: 56,
                            color: AppColors.surfaceSoft,
                            child: const Icon(Icons.image_not_supported_outlined,
                              size: 20, color: AppColors.ink3),
                          ),
                        )
                      : Container(
                          width: 56, height: 56,
                          color: AppColors.surfaceSoft,
                          child: const Icon(Icons.image_not_supported_outlined,
                            size: 20, color: AppColors.ink3),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isAr ? item.product.nameAr : item.product.name,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  if (variationLabel != null && variationLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(variationLabel,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.ink2)),
                    ),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('× ${item.quantity}',
                      style: const TextStyle(fontSize: 12, color: AppColors.ink2,
                        fontFamily: 'PlusJakartaSans')),
                    Text('${item.total.toStringAsFixed(0)} د.ل',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        fontFamily: 'PlusJakartaSans')),
                  ]),
                ])),
              ]),
            );
          }),
        ]),
      ),

      // Order summary
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: AppShadows.shadowCard,
        ),
        child: Column(children: [
          _SummaryRow('المجموع الفرعي', '${cart.subtotal.toStringAsFixed(0)} د.ل'),
          if (cart.discountAmount > 0)
            _SummaryRow('خصم الكوبون', '− ${cart.discountAmount.toStringAsFixed(0)} د.ل',
              color: AppColors.success),
          _SummaryRow(
            'الشحن',
            cart.deliveryFee == 0 ? 'مجاني' : '${cart.deliveryFee.toStringAsFixed(0)} د.ل',
            color: cart.deliveryFee == 0 ? AppColors.success : null,
          ),
          const Divider(height: 20, color: AppColors.border),
          _SummaryRow('الإجمالي', '${cart.total.toStringAsFixed(0)} د.ل', bold: true),
        ]),
      ),
    ]);
  }
}

Widget _SummaryRow(String label, String value, {Color? color, bool bold = false}) =>
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
