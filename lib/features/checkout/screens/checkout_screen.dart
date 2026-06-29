import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/deep_link_service.dart';
import '../../../core/models/shipping_rate.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/reorder_provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/shipping_provider.dart';
import '../../../core/providers/welcome_coupon_provider.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/widgets/app_button.dart';

const _kLastPaymentKey = 'baahy_last_payment';

Color _accent(BuildContext context) => AppColors.adaptive(context);

// Normalizes Libyan phone numbers to display format (0XXXXXXXXX)
String _fmtPhone(String phone) {
  final p = phone.trim();
  if (p.isEmpty) return p;
  if (p.startsWith('+')) return p;          // already international
  if (p.startsWith('00')) return '+${p.substring(2)}'; // 00218...
  if (p.startsWith('0')) return p;           // already 09x...
  return '0$p';                              // raw 9x... → 09x...
}

Color _cardFill(BuildContext context) => context.col.surface;

Color _softFill(BuildContext context) => context.col.surfaceSoft;

// Selected card/radio border
Color _selBorder(BuildContext context) => AppColors.adaptive(context);

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _notesCtrl = TextEditingController();
  final _walletAmountCtrl = TextEditingController();
  String _paymentMethod = 'cash_on_delivery';
  Map<String, dynamic>? _selectedAddress;
  bool _loading = false;
  bool _waitingForPaypal = false;
  List<Map<String, dynamic>> _addresses = [];
  double _walletBalance = 0;
  bool _useWallet = false;
  bool _walletLoading = false;
  bool _itemsExpanded = false;
  StreamSubscription<String>? _paypalSub;

  @override
  void initState() {
    super.initState();
    _initCheckout();
    _loadWallet();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCheckoutSession();
      // Auto-expand items in reorder mode so user sees what they're ordering
      if (ref.read(reorderSessionProvider) != null) {
        setState(() => _itemsExpanded = true);
      }
    });
  }

  // Load address + saved payment together, then validate COD for the resolved address
  Future<void> _initCheckout() async {
    await Future.wait([_loadAddresses(), _loadSavedPayment()]);
    if (!mounted) return;
    if (_paymentMethod == 'cash_on_delivery' && !_codAllowedForAddress) {
      final altMethods = (ref.read(appConfigProvider).paymentMethods as List)
          .where((m) => m.enabled == true && m.id != 'sadad' && m.id != 'wallet' && m.id != 'cash_on_delivery')
          .toList();
      if (altMethods.isNotEmpty) _setPaymentMethod(altMethods.first.id as String);
    }
  }

  void _updateReorderQty(String itemKey, int newQty) {
    final session = ref.read(reorderSessionProvider);
    if (session == null) return;
    final updated = session.items
        .map((i) => i.key == itemKey ? i.copyWith(quantity: newQty) : i)
        .toList();
    ref.read(reorderSessionProvider.notifier).state = ReorderSession(
      items: updated,
      address: session.address,
      paymentMethod: session.paymentMethod,
    );
  }

  Future<void> _startCheckoutSession() async {
    try {
      final session = ref.read(reorderSessionProvider);
      final items = session?.items ?? ref.read(cartProvider).items;
      final subtotal = session?.subtotal ?? ref.read(cartProvider).subtotal;
      await ApiClient.instance.dio.post('/checkout/session/start', data: {
        'items': items.map((i) => {
          'product_id': i.productId,
          if (i.variationId != null) 'variation_id': i.variationId,
          'quantity': i.quantity,
        }).toList(),
        'subtotal': subtotal,
      });
    } catch (_) {}
  }

  Future<void> _loadAddresses() async {
    try {
      final res = await ApiClient.instance.dio.get('/addresses');
      final list = (res.data['data'] as List?)
          ?.map((a) => Map<String, dynamic>.from(a)).toList() ?? [];
      if (mounted) {
        final reorderAddr = ref.read(reorderSessionProvider)?.address;
        setState(() {
          _addresses = list;
          // Reorder pre-fills address from original order; otherwise use default
          if (reorderAddr != null && reorderAddr.isNotEmpty) {
            _selectedAddress = reorderAddr;
          } else {
            _selectedAddress = list.firstWhere(
              (a) => a['is_default'] == true, orElse: () => list.isNotEmpty ? list.first : {});
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadWallet() async {
    setState(() => _walletLoading = true);
    try {
      final res = await ApiClient.instance.dio.get('/wallet');
      final balance = (res.data['data']?['balance'] as num?)?.toDouble() ?? 0.0;
      if (mounted) setState(() => _walletBalance = balance);
    } catch (_) {}
    if (mounted) setState(() => _walletLoading = false);
  }

  Future<void> _loadSavedPayment() async {
    // Reorder pre-fills payment method from original order
    final reorderMethod = ref.read(reorderSessionProvider)?.paymentMethod;
    if (reorderMethod != null) {
      if (mounted) setState(() => _paymentMethod = reorderMethod);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLastPaymentKey);
    if (saved != null && mounted) setState(() => _paymentMethod = saved);
  }

  void _setPaymentMethod(String method) {
    setState(() => _paymentMethod = method);
    SharedPreferences.getInstance().then((p) => p.setString(_kLastPaymentKey, method));
  }

  void _selectAddress(Map<String, dynamic> addr) {
    setState(() => _selectedAddress = addr);
    // Auto-switch away from COD if the new city doesn't allow it
    final city = addr['city']?.toString() ?? '';
    if (city.isNotEmpty && _paymentMethod == 'cash_on_delivery') {
      final rates = ref.read(shippingRatesProvider).valueOrNull ?? [];
      bool codAllowed = true;
      try {
        final rate = rates.firstWhere(
          (r) => r.cityAr == city || r.city.toLowerCase() == city.toLowerCase());
        codAllowed = rate.codAllowed;
      } catch (_) {
        codAllowed = city.contains('طرابلس') || city.toLowerCase().contains('tripoli');
      }
      if (!codAllowed) {
        final altMethods = (ref.read(appConfigProvider).paymentMethods as List)
            .where((m) => m.enabled == true && m.id != 'sadad' && m.id != 'wallet' && m.id != 'cash_on_delivery')
            .toList();
        if (altMethods.isNotEmpty) _setPaymentMethod(altMethods.first.id);
      }
    }
  }

  void _showPaymentSheet(List methods, double cartTotal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.col.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PaymentSheet(
        initialUseWallet: _useWallet,
        initialWalletAmount: _walletAmountCtrl.text,
        initialPaymentMethod: _paymentMethod,
        walletBalance: _walletBalance,
        walletLoading: _walletLoading,
        cartTotal: cartTotal,
        codAllowed: _codAllowedForAddress,
        methods: methods,
        onTopUp: () {
          Navigator.of(context).pop();
          safePush(context, '/wallet').then((_) => _loadWallet());
        },
        onConfirm: (bool useWallet, String walletAmount, String paymentMethod) {
          Navigator.of(context).pop();
          setState(() {
            _useWallet = useWallet;
            _walletAmountCtrl.text = walletAmount;
          });
          if (paymentMethod != _paymentMethod) _setPaymentMethod(paymentMethod);
        },
      ),
    );
  }

  void _showAddressSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.col.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddressSheet(
        addresses: _addresses,
        selected: _selectedAddress,
        onSelect: (addr) {
          Navigator.pop(context);
          _selectAddress(addr);
        },
        onAddNew: () async {
          Navigator.pop(context);
          await safePush(context, '/addresses/edit');
          await _loadAddresses();
        },
      ),
    );
  }

  Future<void> _placeOrder() async {
    if (_selectedAddress == null || _selectedAddress!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.s.pleaseSelectAddr)));
      return;
    }

    final reorderSession = ref.read(reorderSessionProvider);
    final isReorder = reorderSession != null;

    if (!isReorder) {
      // Pre-flight: variable items without a chosen variation.
      final allItems = ref.read(cartProvider).items;
      final unresolved = allItems
          .where((i) => i.variationId == null && i.product.productType == 'variable')
          .toList();
      if (unresolved.isNotEmpty) {
        if (mounted) {
          final names = unresolved.map((i) => i.product.nameAr).join('، ');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('اختر المقاس/اللون لـ: $names'),
            action: SnackBarAction(label: 'مراجعة السلة', onPressed: () => context.pop()),
            backgroundColor: AppColors.danger,
          ));
        }
        return;
      }
    }

    setState(() => _loading = true);

    if (!isReorder) {
      final validationError = await ref.read(cartProvider.notifier).validate();
      if (validationError != null) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(validationError), backgroundColor: AppColors.danger));
        }
        return;
      }
    }

    try {
      final orderItems = isReorder ? reorderSession.items : ref.read(cartProvider).items;
      final orderSubtotal = isReorder ? reorderSession.subtotal : ref.read(cartProvider).subtotal;
      final cart = ref.read(cartProvider);
      final couponCode = isReorder ? null : cart.couponCode;
      final addr = _selectedAddress!;
      final walletActive = _useWallet && _walletBalance > 0;
      final maxUse = walletActive
          ? (_walletBalance < orderSubtotal ? _walletBalance : orderSubtotal)
          : 0.0;
      final walletDeduct = walletActive
          ? (double.tryParse(_walletAmountCtrl.text) ?? maxUse).clamp(0.0, maxUse)
          : 0.0;
      final walletCoversAll = walletActive && walletDeduct >= orderSubtotal;

      final res = await ApiClient.instance.dio.post('/orders', data: {
        'items': orderItems.map((i) => {
          'product_id': i.productId,
          if (i.variationId != null) 'variation_id': i.variationId,
          'quantity': i.quantity,
        }).toList(),
        'payment_method': walletCoversAll ? 'wallet' : _paymentMethod,
        if (walletActive && !walletCoversAll) ...{
          'use_wallet_partial': true,
          'wallet_amount': walletDeduct,
        },
        'shipping_name': addr['name'] ?? addr['label'] ?? '',
        'shipping_phone': addr['phone'] ?? '',
        'shipping_city': addr['city'] ?? '',
        'shipping_address': addr['address'] ?? '',
        if (addr['latitude'] != null) 'shipping_lat': addr['latitude'],
        if (addr['longitude'] != null) 'shipping_lng': addr['longitude'],
        if (couponCode != null) 'coupon_code': couponCode,
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      });

      SharedPreferences.getInstance().then((p) => p.setString(_kLastPaymentKey, _paymentMethod));
      if (!isReorder) await ref.read(cartProvider.notifier).clear();
      ref.read(reorderSessionProvider.notifier).state = null;
      ref.invalidate(welcomeCouponProvider);

      final orderData = Map<String, dynamic>.from(res.data['data'] as Map);
      if (_paymentMethod == 'paypal') {
        await _handlePayPalPayment(orderData['order_number'] as String, orderData);
      } else {
        if (mounted) context.pushReplacement('/order-confirmed', extra: orderData);
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        String msg = context.s.orderError;
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null) msg = data['message'].toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  void dispose() {
    _paypalSub?.cancel();
    _notesCtrl.dispose();
    _walletAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _handlePayPalPayment(String orderNumber, Map<String, dynamic> orderConfirmedData) async {
    try {
      final res = await ApiClient.instance.dio.post('/payment/paypal/initiate', data: {
        'order_number': orderNumber,
      });
      final approvalUrl = res.data['approval_url'] as String?;
      if (approvalUrl == null) throw Exception('No approval URL');

      _paypalSub?.cancel();
      _paypalSub = DeepLinkService.instance.paypalReturnStream.listen((paypalOrderId) async {
        _paypalSub?.cancel();
        _paypalSub = null;
        if (!mounted) return;
        setState(() { _loading = true; _waitingForPaypal = false; });
        try {
          await ApiClient.instance.dio.post('/payment/paypal/capture', data: {
            'order_number': orderNumber,
            'paypal_order_id': paypalOrderId,
          });
          if (mounted) {
            setState(() => _loading = false);
            context.pushReplacement('/order-confirmed', extra: orderConfirmedData);
          }
        } catch (e) {
          if (mounted) {
            setState(() => _loading = false);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('فشل تأكيد الدفع — تواصل مع الدعم'),
              backgroundColor: AppColors.danger,
            ));
          }
        }
      });

      await launchUrl(Uri.parse(approvalUrl), mode: LaunchMode.inAppBrowserView);
      if (mounted) setState(() { _loading = false; _waitingForPaypal = true; });
    } catch (e) {
      _paypalSub?.cancel();
      if (mounted) {
        setState(() { _loading = false; _waitingForPaypal = false; });
        String msg = 'فشل بدء الدفع عبر PayPal';
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null) msg = data['message'].toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg), backgroundColor: AppColors.danger));
      }
    }
  }

  ShippingRate? get _selectedRate {
    final city = (_selectedAddress?['city'] ?? '').toString();
    if (city.isEmpty) return null;
    final rates = ref.read(shippingRatesProvider).valueOrNull ?? [];
    try {
      return rates.firstWhere(
        (r) => r.cityAr == city || r.city.toLowerCase() == city.toLowerCase());
    } catch (_) { return null; }
  }

  String _paymentMethodLabel(BuildContext context, List methods) {
    final isAr = context.isAr;
    try {
      final m = methods.firstWhere((m) => m.id == _paymentMethod);
      return isAr ? m.labelAr : (m.labelEn.isNotEmpty ? m.labelEn : m.labelAr);
    } catch (_) {
      return _paymentMethod;
    }
  }

  bool get _codAllowedForAddress {
    final city = (_selectedAddress?['city'] ?? '').toString();
    if (city.isEmpty) return true;
    final rates = ref.read(shippingRatesProvider).valueOrNull ?? [];
    try {
      final rate = rates.firstWhere(
        (r) => r.cityAr == city || r.city.toLowerCase() == city.toLowerCase());
      return rate.codAllowed;
    } catch (_) {
      return city.contains('طرابلس') || city.toLowerCase().contains('tripoli');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final reorderSession = ref.watch(reorderSessionProvider);
    final isReorder = reorderSession != null;
    final config = ref.watch(appConfigProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accent(context);

    // Effective items and subtotal: reorder session takes priority over cart
    final effectiveItems = isReorder ? reorderSession.items : cart.items;
    final effectiveSubtotal = isReorder ? reorderSession.subtotal : cart.subtotal;
    // Watch shipping rates so delivery fee recalculates when address changes
    ref.watch(shippingRatesProvider);
    final selectedRate = _selectedRate;
    final effectiveDeliveryFee = isReorder
        ? (selectedRate != null
            ? selectedRate.effectiveRate(effectiveSubtotal)
            : (cart.cityRate?.effectiveRate(effectiveSubtotal) ?? cart.fallbackShippingFee))
        : cart.deliveryFee;
    final effectiveTotal = isReorder
        ? effectiveSubtotal + effectiveDeliveryFee
        : cart.total;

    final allMethods = (config.paymentMethods as List)
        .where((m) => m.enabled == true && m.id != 'sadad' && m.id != 'wallet')
        .toList();
    final codValueExceeded = effectiveTotal > 5000;
    final codItemsExceeded = effectiveItems.length > 20;
    final codBlocked = !_codAllowedForAddress || codValueExceeded || codItemsExceeded;
    final methods = codBlocked
        ? allMethods.where((m) => m.id != 'cash_on_delivery').toList()
        : allMethods;

    final walletActive = _useWallet && _walletBalance > 0;
    final maxWalletUse = walletActive
        ? (_walletBalance < effectiveTotal ? _walletBalance : effectiveTotal)
        : 0.0;
    final parsedWalletInput = double.tryParse(_walletAmountCtrl.text) ?? 0.0;
    final walletDeduct = walletActive
        ? parsedWalletInput.clamp(0.0, maxWalletUse)
        : 0.0;
    final walletCoversAll = walletActive && walletDeduct >= effectiveTotal;
    final amountDue = walletActive ? (effectiveTotal - walletDeduct).clamp(0.0, effectiveTotal) : effectiveTotal;
    final isAr = context.isAr;

    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: context.col.bg,
      body: Column(
        children: [
            // ── Header ── extends behind status bar like AppBar ──────────────
            Container(
              color: context.col.surface,
              child: Column(
                children: [
                  SizedBox(height: topPad),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(children: [
                      IconButton(
                        onPressed: () {
                          ref.read(reorderSessionProvider.notifier).state = null;
                          context.pop();
                        },
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                          color: context.col.ink0, size: 20),
                      ),
                      Text(isReorder
                          ? (context.isAr ? 'إعادة الطلب' : 'Reorder')
                          : context.s.cartTitle,
                        style: TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.w600,
                          fontSize: 15, color: context.col.ink2)),
                    ]),
                  ),
                  Divider(height: 1, color: context.col.border),
                ],
              ),
            ),

            // ── Scrollable content ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Delivery address ──────────────────────────────────
                    _SectionLabel(context.s.shippingAddr),
                    const SizedBox(height: 8),
                    _selectedAddress == null || _selectedAddress!.isEmpty
                        ? GestureDetector(
                            onTap: _showAddressSheet,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _cardFill(context),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: accent, width: 1.5),
                              ),
                              child: Row(children: [
                                Icon(Icons.add_location_alt_outlined, color: accent, size: 18),
                                const SizedBox(width: 10),
                                Text(context.s.addNewAddress,
                                  style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          )
                        : GestureDetector(
                            onTap: _showAddressSheet,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _cardFill(context),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: context.col.border),
                                boxShadow: isDark ? null : AppShadows.shadowCard,
                              ),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Icon(Icons.location_on_outlined, size: 18, color: accent),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(
                                    context.s.translateAddrLabel(_selectedAddress!['label'] as String? ?? ''),
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      context.s.translateCity(_selectedAddress!['city']?.toString() ?? ''),
                                      _selectedAddress!['address'],
                                      if ((_selectedAddress!['phone'] as String?)?.isNotEmpty == true)
                                        _fmtPhone(_selectedAddress!['phone'].toString()),
                                    ].where((v) => v.isNotEmpty).join('  ·  '),
                                    style: TextStyle(fontSize: 12.5, color: context.col.ink2)),
                                  if (_selectedRate != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${fmtPrice(_selectedRate!.rate)} ${context.s.lydUnit} · ${_selectedRate!.deliveryDays} ${context.s.daysLabel}',
                                      style: TextStyle(
                                        fontSize: 11.5, color: context.col.ink2, fontWeight: FontWeight.w600)),
                                  ],
                                ])),
                                Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: context.col.ink2),
                              ]),
                            ),
                          ),
                    const SizedBox(height: 24),

                    // ── Payment method ────────────────────────────────────
                    _SectionLabel(context.s.paymentMethod),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _showPaymentSheet(methods, effectiveTotal),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _cardFill(context),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: context.col.border),
                          boxShadow: isDark ? null : AppShadows.shadowCard,
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(Icons.payment_outlined, size: 18, color: accent),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              walletCoversAll
                                  ? context.s.walletTitle
                                  : (walletActive
                                      ? '${context.s.walletTitle} + ${_paymentMethodLabel(context, methods)}'
                                      : _paymentMethodLabel(context, methods)),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            if (walletActive && walletDeduct > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                walletCoversAll
                                    ? context.s.walletCoversAll(fmtPrice(walletDeduct))
                                    : context.s.walletPartial(fmtPrice(walletDeduct), fmtPrice(amountDue)),
                                style: TextStyle(fontSize: 12.5, color: accent)),
                            ],
                          ])),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: context.col.ink2),
                        ]),
                      ),
                    ),
                    if (codValueExceeded || codItemsExceeded) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 13, color: AppColors.danger),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                codValueExceeded
                                    ? 'الدفع عند الاستلام غير متاح — المجموع يتجاوز 5,000 د.ل'
                                    : 'الدفع عند الاستلام غير متاح — الطلب يتجاوز 20 منتج',
                                style: const TextStyle(fontSize: 11.5, color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // ── Order items (collapsible) ─────────────────────────
                    _CollapsibleHeader(
                      title: context.s.productsCountN(effectiveItems.length),
                      subtitle: '${fmtPrice(effectiveSubtotal)} ${context.s.lydUnit}',
                      expanded: _itemsExpanded,
                      onTap: () => setState(() => _itemsExpanded = !_itemsExpanded),
                    ),
                    if (_itemsExpanded) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _cardFill(context),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: context.col.border),
                          boxShadow: isDark ? null : AppShadows.shadowCard,
                        ),
                        child: Column(
                          children: effectiveItems.map((item) {
                            final variationLabel = item.variation?.attributes
                                .map((a) => isAr ? a.valueAr : a.value)
                                .where((v) => v.isNotEmpty)
                                .join(' · ');
                            final maxQty = item.variation != null
                                ? item.variation!.stockQuantity
                                : (item.product.stockQuantity ?? 99);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: item.image != null
                                      ? CachedNetworkImage(
                                          imageUrl: item.image!, width: 52, height: 52,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => _ImagePlaceholder(size: 52),
                                        )
                                      : _ImagePlaceholder(size: 52),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(isAr ? item.product.nameAr : item.product.name,
                                    maxLines: 2, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  if (variationLabel != null && variationLabel.isNotEmpty)
                                    Text(variationLabel,
                                      style: TextStyle(fontSize: 11.5, color: context.col.ink2)),
                                  const SizedBox(height: 6),
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                    if (isReorder) ...[
                                      // Inline qty stepper for reorder mode
                                      Row(children: [
                                        _QtyBtn(
                                          icon: Icons.remove,
                                          enabled: item.quantity > 1,
                                          onTap: () => _updateReorderQty(item.key, item.quantity - 1),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          child: Text('${item.quantity}',
                                            style: const TextStyle(
                                              fontSize: 14, fontWeight: FontWeight.w700,
                                              fontFamily: 'PlusJakartaSans')),
                                        ),
                                        _QtyBtn(
                                          icon: Icons.add,
                                          enabled: item.quantity < maxQty,
                                          onTap: () => _updateReorderQty(item.key, item.quantity + 1),
                                        ),
                                      ]),
                                    ] else ...[
                                      Text('× ${item.quantity}',
                                        style: TextStyle(fontSize: 12, color: context.col.ink2,
                                          fontFamily: 'PlusJakartaSans')),
                                    ],
                                    Text('${fmtPrice(item.total)} ${context.s.lydUnit}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                        fontFamily: 'PlusJakartaSans')),
                                  ]),
                                ])),
                              ]),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // ── Price summary ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _cardFill(context),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: context.col.border),
                        boxShadow: isDark ? null : AppShadows.shadowCard,
                      ),
                      child: Column(children: [
                        _SummaryRow(context.s.subtotalLabel,
                          '${fmtPrice(effectiveSubtotal)} ${context.s.lydUnit}', ctx: context),
                        if (!isReorder && cart.discountAmount > 0)
                          _SummaryRow(context.s.couponDiscount,
                            '− ${fmtPrice(cart.discountAmount)} ${context.s.lydUnit}',
                            color: AppColors.success, ctx: context),
                        _SummaryRow(
                          context.s.shippingCost,
                          effectiveDeliveryFee == 0
                              ? context.s.freeText
                              : '${fmtPrice(effectiveDeliveryFee)} ${context.s.lydUnit}',
                          color: effectiveDeliveryFee == 0 ? AppColors.success : null,
                          ctx: context),
                        Divider(height: 20, color: context.col.border),
                        _SummaryRow(context.s.orderTotal,
                          '${fmtPrice(effectiveTotal)} ${context.s.lydUnit}',
                          bold: true, ctx: context),
                      ]),
                    ),
                    // Cashback earned on this order
                    if (effectiveSubtotal >= config.cashbackMinOrder && config.cashbackRate > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.transparent : AppColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: isDark ? 0.45 : 0.35)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.stars_rounded, size: 18, color: AppColors.success),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            context.s.orderCashbackEarn(
                              fmtPrice(effectiveSubtotal * config.cashbackRate / 100),
                              (effectiveSubtotal * config.cashbackRate / 10).round().clamp(1, 9999).toString()),
                            style: const TextStyle(
                              fontFamily: 'Cairo', fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success))),
                        ]),
                      ),
                    // First-order coupon applied strip
                    if (!isReorder && cart.couponCode?.toUpperCase() == 'FIRSTORDER')
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.transparent : AppColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: isDark ? 0.45 : 0.35)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                          const SizedBox(width: 8),
                          const Expanded(child: Text(
                            '✓ خصم الطلب الأول مطبّق — هذا العرض لن يتكرر',
                            style: TextStyle(
                              fontFamily: 'Cairo', fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success))),
                        ]),
                      ),
                    const SizedBox(height: 16),

                    // ── Trust badges ───────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        color: _cardFill(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.col.border),
                        boxShadow: isDark ? null : AppShadows.shadowCard,
                      ),
                      child: const _TrustRow(),
                    ),
                    const SizedBox(height: 16),

                    // ── Notes ─────────────────────────────────────────────
                    _SectionLabel(context.s.notesOptional),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: _cardFill(context),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: context.col.border),
                      ),
                      child: TextField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          filled: false,
                          hintText: context.s.notesHint,
                          hintStyle: TextStyle(color: context.col.ink3, fontSize: 13.5),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom bar ────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16,
                MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: context.col.surface,
                boxShadow: AppShadows.shadowPop,
              ),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(context.s.total,
                    style: TextStyle(fontSize: 13, color: context.col.ink2)),
                  Text('${fmtPrice(effectiveTotal)} ${context.s.lydUnit}',
                    style: const TextStyle(fontFamily: 'PlusJakartaSans',
                      fontSize: 18, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                if (_waitingForPaypal)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF003087).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF003087).withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2,
                            color: Color(0xFF003087)),
                        ),
                        SizedBox(width: 10),
                        Text('في انتظار إتمام الدفع عبر PayPal...',
                          style: TextStyle(fontFamily: 'Cairo',
                            color: Color(0xFF003087), fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )
                else
                  AppButton(
                    label: context.s.placeOrder,
                    icon: const Icon(Icons.check_rounded, size: 16, color: Color(0xFFF0F0F0)),
                    onTap: _placeOrder,
                    loading: _loading,
                  ),
              ]),
            ),
          ],
        ),
    );
  }
}


// ── Payment picker bottom sheet ───────────────────────────────────────────────

class _PaymentSheet extends StatefulWidget {
  final bool initialUseWallet;
  final String initialWalletAmount;
  final String initialPaymentMethod;
  final double walletBalance;
  final bool walletLoading;
  final double cartTotal;
  final bool codAllowed;
  final List methods;
  final VoidCallback onTopUp;
  final void Function(bool useWallet, String walletAmount, String paymentMethod) onConfirm;

  const _PaymentSheet({
    required this.initialUseWallet,
    required this.initialWalletAmount,
    required this.initialPaymentMethod,
    required this.walletBalance,
    required this.walletLoading,
    required this.cartTotal,
    required this.codAllowed,
    required this.methods,
    required this.onTopUp,
    required this.onConfirm,
  });

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late bool _useWallet;
  late String _paymentMethod;
  late final TextEditingController _walletAmountCtrl;

  @override
  void initState() {
    super.initState();
    _useWallet = widget.initialUseWallet;
    _paymentMethod = widget.initialPaymentMethod;
    _walletAmountCtrl = TextEditingController(text: widget.initialWalletAmount);
  }

  @override
  void dispose() {
    _walletAmountCtrl.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    final parsed = double.tryParse(val) ?? 0.0;
    final maxUse = widget.walletBalance < widget.cartTotal
        ? widget.walletBalance : widget.cartTotal;
    if (parsed > maxUse && maxUse > 0) {
      final clamped = maxUse.toStringAsFixed(0);
      _walletAmountCtrl.value = TextEditingValue(
        text: clamped,
        selection: TextSelection.collapsed(offset: clamped.length),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accent(context);
    final walletActive = _useWallet && widget.walletBalance > 0;
    final maxWalletUse = walletActive
        ? (widget.walletBalance < widget.cartTotal ? widget.walletBalance : widget.cartTotal)
        : 0.0;
    final parsedAmount = double.tryParse(_walletAmountCtrl.text) ?? 0.0;
    final walletDeduct = walletActive ? parsedAmount.clamp(0.0, maxWalletUse) : 0.0;
    final walletCoversAll = walletDeduct >= widget.cartTotal;
    final amountDue = (widget.cartTotal - walletDeduct).clamp(0.0, widget.cartTotal);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 8, 16,
          MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: context.col.border,
              borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text(context.s.paymentMethod,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),

          if (!widget.codAllowed) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warn.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.warn.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.warn),
                const SizedBox(width: 8),
                Expanded(child: Text(context.s.codTripiliOnly,
                  style: const TextStyle(fontSize: 12, color: AppColors.warn, height: 1.4))),
              ]),
            ),
          ],

          // Wallet card
          GestureDetector(
            onTap: widget.walletBalance > 0
                ? () {
                    final enabling = !_useWallet;
                    if (enabling) {
                      final maxUse = widget.walletBalance < widget.cartTotal
                          ? widget.walletBalance : widget.cartTotal;
                      _walletAmountCtrl.text = maxUse.toStringAsFixed(0);
                    }
                    setState(() => _useWallet = enabling);
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: _cardFill(context),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: walletActive ? _selBorder(context) : context.col.border,
                  width: walletActive ? 1.5 : 1),
                boxShadow: isDark ? null : AppShadows.shadowCard,
              ),
              child: Row(children: [
                _RadioDot(selected: walletActive),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(context.s.walletTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onTopUp,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: context.col.borderStrong),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add, size: 10, color: context.col.ink2),
                          const SizedBox(width: 2),
                          Text(context.s.topUpShort,
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 10,
                              fontWeight: FontWeight.w700, color: context.col.ink2)),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  widget.walletLoading
                      ? Text(context.s.loading,
                          style: TextStyle(fontSize: 11.5, color: context.col.ink3))
                      : Text(
                          widget.walletBalance > 0
                              ? context.s.walletBalanceLabel(fmtPrice(widget.walletBalance))
                              : context.s.walletEmpty,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: widget.walletBalance > 0 ? AppColors.success : context.col.ink3)),
                ])),
                const SizedBox(width: 10),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _softFill(context),
                    borderRadius: BorderRadius.circular(6),
                    border: isDark ? Border.all(color: context.col.border) : null,
                  ),
                  child: Icon(Icons.account_balance_wallet_outlined, size: 18,
                    color: walletActive ? accent : context.col.ink3),
                ),
              ]),
            ),
          ),

          // Combined amount input + live summary (no outline)
          if (walletActive) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.transparent : Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('استخدم',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
                      color: context.col.ink2, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _walletAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textDirection: TextDirection.ltr,
                      onChanged: _onAmountChanged,
                      style: const TextStyle(fontFamily: 'PlusJakartaSans',
                        fontSize: 16, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: context.col.ink4),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                  Text('/ ${fmtPrice(maxWalletUse)} د.ل',
                    style: TextStyle(fontFamily: 'PlusJakartaSans',
                      fontSize: 11.5, color: context.col.ink3, fontWeight: FontWeight.w500)),
                ]),
                if (walletDeduct > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    walletCoversAll
                        ? context.s.walletCoversAll(fmtPrice(walletDeduct))
                        : context.s.walletPartial(fmtPrice(walletDeduct), fmtPrice(amountDue)),
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: walletCoversAll ? AppColors.success : accent)),
                ] else ...[
                  const SizedBox(height: 4),
                  Text('أدخل مبلغاً للخصم من محفظتك',
                    style: TextStyle(fontSize: 11.5, color: context.col.ink4)),
                ],
              ]),
            ),
          ],

          if (!walletCoversAll) ...[
            ...widget.methods.map((m) => GestureDetector(
              onTap: () => setState(() => _paymentMethod = m.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _cardFill(context),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _paymentMethod == m.id ? _selBorder(context) : context.col.border,
                    width: _paymentMethod == m.id ? 1.5 : 1),
                  boxShadow: isDark ? null : AppShadows.shadowCard,
                ),
                child: Row(children: [
                  _RadioDot(selected: _paymentMethod == m.id),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.isAr ? m.labelAr : (m.labelEn.isNotEmpty ? m.labelEn : m.labelAr),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      context.isAr
                          ? (m.descriptionAr.isNotEmpty ? m.descriptionAr
                              : (m.fee > 0 ? context.s.serviceFeeN(fmtPrice(m.fee)) : context.s.noFees))
                          : (m.descriptionEn.isNotEmpty ? m.descriptionEn
                              : (m.fee > 0 ? context.s.serviceFeeN(fmtPrice(m.fee)) : context.s.noFees)),
                      style: TextStyle(fontSize: 11.5, color: context.col.ink2)),
                  ])),
                  const SizedBox(width: 10),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _softFill(context),
                      borderRadius: BorderRadius.circular(6),
                      border: isDark ? Border.all(color: context.col.border) : null,
                    ),
                    child: Icon(
                      m.id == 'cash_on_delivery' ? Icons.payments_outlined
                          : m.id == 'paypal' ? Icons.language_outlined
                          : m.id == 'card' ? Icons.credit_card_outlined
                          : Icons.receipt_long_outlined,
                      size: 18,
                      color: _paymentMethod == m.id ? accent : context.col.ink3),
                  ),
                ]),
              ),
            )),
          ],

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => widget.onConfirm(_useWallet, _walletAmountCtrl.text, _paymentMethod),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('تأكيد',
                style: TextStyle(fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Address picker bottom sheet ───────────────────────────────────────────────

class _AddressSheet extends StatelessWidget {
  final List<Map<String, dynamic>> addresses;
  final Map<String, dynamic>? selected;
  final void Function(Map<String, dynamic>) onSelect;
  final VoidCallback onAddNew;
  const _AddressSheet({required this.addresses, required this.selected,
    required this.onSelect, required this.onAddNew});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: context.col.border,
              borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text(context.s.shippingAddr,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ...addresses.map((addr) {
            final isSelected = selected?['id'] == addr['id'];
            return GestureDetector(
              onTap: () => onSelect(addr),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _cardFill(context),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? _selBorder(context) : context.col.border,
                    width: isSelected ? 1.5 : 1),
                  boxShadow: isDark ? null : AppShadows.shadowCard,
                ),
                child: Row(children: [
                  _RadioDot(selected: isSelected),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.s.translateAddrLabel(addr['label'] as String? ?? ''),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        context.s.translateCity(addr['city']?.toString() ?? ''),
                        addr['address']?.toString() ?? '',
                        if ((addr['phone'] as String?)?.isNotEmpty == true)
                          _fmtPhone(addr['phone'].toString()),
                      ].where((v) => v.isNotEmpty).join('  ·  '),
                      style: TextStyle(fontSize: 12.5, color: context.col.ink2)),
                  ])),
                ]),
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: onAddNew,
            icon: const Icon(Icons.add, size: 16),
            label: Text(context.s.addNewAddress),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              side: BorderSide(color: context.col.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ── Trust badges row ──────────────────────────────────────────────────────────

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tiffany = AppColors.adaptive(context);
    final items = [
      (Icons.verified_outlined,          context.s.trustAuthentic,  tiffany),
      (Icons.local_shipping_outlined,   context.s.trustDelivery,   tiffany),
      (Icons.workspace_premium_outlined, context.s.trustWarranty,   tiffany),
      (Icons.replay_rounded,             context.s.trustReturn,     tiffany),
    ];
    final dimColor = tiffany;
    return Row(
      children: items.map((item) => Expanded(
        child: Column(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.transparent : item.$3.withValues(alpha: 0.10),
              border: Border.all(
                color: isDark ? dimColor.withValues(alpha: 0.55) : item.$3.withValues(alpha: 0.35)),
            ),
            child: Icon(item.$1, size: 17, color: isDark ? dimColor : item.$3),
          ),
          const SizedBox(height: 6),
          Text(item.$2,
            textAlign: TextAlign.center, maxLines: 2,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 10.5,
              fontWeight: FontWeight.w600, color: context.col.ink2)),
        ]),
      )).toList(),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700));
}

class _RadioDot extends StatelessWidget {
  final bool selected;
  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accent(context);
    return Container(
      width: 20, height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: selected ? null : Border.all(color: context.col.borderStrong, width: 1.5),
        color: selected ? accent : Colors.transparent,
      ),
      child: selected
          ? Center(child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.black87 : Colors.white,
              ),
            ))
          : null,
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final double size;
  const _ImagePlaceholder({this.size = 56});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    color: context.col.surfaceSoft,
    child: Icon(Icons.image_not_supported_outlined, size: size * 0.36, color: context.col.ink3),
  );
}

Widget _SummaryRow(String label, String value,
    {Color? color, bool bold = false, required BuildContext ctx}) =>
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 14)),
      Text(value, style: TextStyle(
        fontFamily: 'PlusJakartaSans', fontSize: 14,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        color: color ?? ctx.col.ink0)),
    ]),
  );

// ── Collapsible section header ────────────────────────────────────────────────

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.12)
              : context.col.surfaceSoft,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 15,
          color: enabled ? AppColors.primary : context.col.ink4),
      ),
    );
  }
}

class _CollapsibleHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool expanded;
  final VoidCallback onTap;

  const _CollapsibleHeader({
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _cardFill(context),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: context.col.border),
          boxShadow: isDark ? null : AppShadows.shadowCard,
        ),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: context.col.ink2)),
            ],
          )),
          AnimatedRotation(
            turns: expanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(Icons.keyboard_arrow_down_rounded,
              size: 22, color: context.col.ink2),
          ),
        ]),
      ),
    );
  }
}
