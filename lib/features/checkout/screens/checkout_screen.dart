import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/optimized_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import 'payment_webview_screen.dart';
import '../../../core/models/shipping_rate.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/reorder_provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/tier_provider.dart';
import '../../../core/providers/shipping_provider.dart';
import '../../../core/providers/welcome_coupon_provider.dart';
import '../../../core/utils/delivery.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/utils/navigation.dart';
import '../../../core/services/analytics_service.dart';

const _kLastPaymentKey = 'baahy_last_payment';

String? _paymentIconPath(String id) {
  switch (id) {
    case 'cash_on_delivery':
      return 'assets/images/payment/cod.png';
    case 'paypal':
      return 'assets/images/payment/paypal.png';
    case 'moamlat':
      return 'assets/images/payment/moamlat.png';
    case 'mobicash':
      return 'assets/images/payment/mobicash.png';
    case 'tadawul':
    case 'tadawel':
      return 'assets/images/payment/tadawul.png';
    case 'lypay':
      return 'assets/images/payment/lypay.png';
    case 'sadad':
      return 'assets/images/payment/sadad.png';
    default:
      return null;
  }
}

// Backend-uploaded icon URL for a method id (from app-config); null → use the bundled asset.
String? _payIconUrl(List methods, String id) {
  for (final m in methods) {
    if (m.id == id) return m.iconUrl as String?;
  }
  return null;
}

Color _accent(BuildContext context) => AppColors.adaptive(context);

// Normalizes Libyan phone numbers to display format (0XXXXXXXXX)
String _fmtPhone(String phone) {
  final p = phone.trim();
  if (p.isEmpty) return p;
  if (p.startsWith('+')) return p; // already international
  if (p.startsWith('00')) return '+${p.substring(2)}'; // 00218...
  if (p.startsWith('0')) return p; // already 09x...
  return '0$p'; // raw 9x... → 09x...
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
  String _paymentMethod = '';
  Map<String, dynamic>? _selectedAddress;
  bool _loading = false;
  List<Map<String, dynamic>> _addresses = [];
  double _walletBalance = 0;

  /// The part of the balance an offer-blocked order may still use (topped-up money).
  double _walletSpendable = 0;
  bool _useWallet = false;
  bool _walletLoading = false;
  bool _itemsExpanded = false;

  @override
  void initState() {
    super.initState();
    _initCheckout();
    _loadWallet();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCheckoutSession();
      // Analytics: begin_checkout (Firebase + Meta) — once when the screen opens
      final rs = ref.read(reorderSessionProvider);
      final ckItems = rs?.items ?? ref.read(cartProvider).items;
      final ckTotal = rs?.subtotal ?? ref.read(cartProvider).subtotal;
      Analytics.instance
          .beginCheckout(total: ckTotal, itemCount: ckItems.length);
      // Auto-expand items in reorder mode so user sees what they're ordering
      if (ref.read(reorderSessionProvider) != null) {
        setState(() => _itemsExpanded = true);
      }
      _applyPendingAutoOffer();
    });
  }

  /// The server applies the first-order offer even when the app sends no code, so a
  /// checkout reached without the cart having applied it showed a total HIGHER than
  /// what is actually charged — and, with the wallet block keyed off the same offer,
  /// no sign of why the wallet was unavailable. Apply it through the normal
  /// server-validated path so the discount shown is the discount charged, rather than
  /// recomputing it here where eligible-subtotal rules would be guessed at.
  Future<void> _applyPendingAutoOffer() async {
    if (ref.read(reorderSessionProvider) != null) return;
    if ((ref.read(cartProvider).couponCode ?? '').isNotEmpty) return;
    try {
      final offer = await ref.read(welcomeCouponProvider.future);
      if (!mounted || offer == null) return;
      if ((ref.read(cartProvider).couponCode ?? '').isNotEmpty) return;
      await ref.read(cartProvider.notifier).applyCoupon(offer.code);
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }

  // Load address + saved payment together, then validate COD for the resolved address
  Future<void> _initCheckout() async {
    await Future.wait([_loadAddresses(), _loadSavedPayment()]);
    if (!mounted) return;
    if (_paymentMethod == 'cash_on_delivery' && !_codAllowedForAddress) {
      final altMethods = (ref.read(appConfigProvider).paymentMethods as List)
          .where((m) =>
              m.enabled == true &&
              m.id != 'wallet' &&
              m.id != 'cash_on_delivery')
          .toList();
      if (altMethods.isNotEmpty)
        _setPaymentMethod(altMethods.first.id as String);
    }
    // A pre-filled method (reorder of an order paid with the wallet / 'cash' / a since-disabled gateway,
    // or a stale last-used choice) must be one the server will accept now; otherwise the order 422s or,
    // for 'wallet', silently pays from the wallet. Clear it so the customer chooses explicitly.
    final offeredIds = (ref.read(appConfigProvider).paymentMethods as List)
        .where((m) => m.enabled == true && m.id != 'wallet')
        .map((m) => m.id as String)
        .toSet();
    if (offeredIds.isNotEmpty && _paymentMethod.isNotEmpty && !offeredIds.contains(_paymentMethod)) {
      setState(() => _paymentMethod = '');
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
        'items': items
            .map((i) => {
                  'product_id': i.productId,
                  if (i.variationId != null) 'variation_id': i.variationId,
                  'quantity': i.quantity,
                })
            .toList(),
        'subtotal': subtotal,
      });
    } catch (_) {}
  }

  Future<void> _loadAddresses() async {
    try {
      final res = await ApiClient.instance.dio.get('/addresses');
      final list = (res.data['data'] as List?)
              ?.map((a) => Map<String, dynamic>.from(a))
              .toList() ??
          [];
      if (mounted) {
        final reorderAddr = ref.read(reorderSessionProvider)?.address;
        setState(() {
          _addresses = list;
          // Reorder pre-fills address from original order; otherwise use default
          if (reorderAddr != null && reorderAddr.isNotEmpty) {
            _selectedAddress = reorderAddr;
          } else {
            _selectedAddress = list.firstWhere((a) => a['is_default'] == true,
                orElse: () => list.isNotEmpty ? list.first : {});
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadWallet() async {
    setState(() => _walletLoading = true);
    try {
      final res = await ApiClient.instance.dio.get('/wallet');
      final d = res.data['data'];
      final balance = (d?['balance'] as num?)?.toDouble() ?? 0.0;
      // A first-order offer holds back reward credit only. Older servers do not send the
      // split, so fall back to the whole balance being spendable rather than to zero.
      final spendable =
          (d?['spendable_balance'] as num?)?.toDouble() ?? balance;
      if (mounted) {
        setState(() {
          _walletBalance = balance;
          _walletSpendable = spendable;
        });
      }
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
    SharedPreferences.getInstance()
        .then((p) => p.setString(_kLastPaymentKey, method));
  }

  void _selectAddress(Map<String, dynamic> addr) {
    setState(() => _selectedAddress = addr);
    // Auto-switch away from COD if the new city doesn't allow it
    final city = addr['city']?.toString() ?? '';
    if (city.isNotEmpty && _paymentMethod == 'cash_on_delivery') {
      final rates = ref.read(shippingRatesProvider).valueOrNull ?? [];
      bool codAllowed = true;
      try {
        final rate = rates.firstWhere((r) =>
            r.cityAr == city || r.city.toLowerCase() == city.toLowerCase());
        codAllowed = rate.codAllowed;
      } catch (_) {
        codAllowed =
            city.contains('طرابلس') || city.toLowerCase().contains('tripoli');
      }
      if (!codAllowed) {
        final altMethods = (ref.read(appConfigProvider).paymentMethods as List)
            .where((m) =>
                m.enabled == true &&
                m.id != 'wallet' &&
                m.id != 'cash_on_delivery')
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
        // Only call the wallet blocked when NOTHING of it can be used. With topped-up
        // money present the sheet should offer that portion, not refuse the whole balance.
        walletBlockedNote: (ref
                        .read(welcomeCouponProvider)
                        .valueOrNull
                        ?.blocksWallet ==
                    true &&
                _walletSpendable <= 0)
            ? _walletBlockedNoteText(ref.read(welcomeCouponProvider).valueOrNull!, context.isAr)
            : null,
        initialUseWallet: _useWallet,
        initialWalletAmount: _walletAmountCtrl.text,
        initialPaymentMethod: _paymentMethod,
        // The amount the sheet may actually offer. Passing the raw balance made it
        // propose 71 on an order where only 51 is spendable, and quote a remainder
        // 20 LYD lower than the customer would be charged.
        walletBalance:
            (ref.read(welcomeCouponProvider).valueOrNull?.blocksWallet == true)
                ? _walletSpendable
                : _walletBalance,
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
    if (_loading) return; // re-entrancy guard: a second tap while the order request is in flight
    if (_selectedAddress == null || _selectedAddress!.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.s.pleaseSelectAddr)));
      return;
    }

    final reorderSession = ref.read(reorderSessionProvider);
    final isReorder = reorderSession != null;

    if (!isReorder) {
      // Pre-flight: variable items without a chosen variation.
      final allItems = ref.read(cartProvider).items;
      final unresolved = allItems
          .where((i) =>
              i.variationId == null && i.product.productType == 'variable')
          .toList();
      if (unresolved.isNotEmpty) {
        if (mounted) {
          final names = unresolved
              .map((i) => context.isAr ? i.product.nameAr : i.product.name)
              .join(context.isAr ? '، ' : ', ');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr('اختر المقاس/اللون لـ: $names',
                'Choose size/colour for: $names')),
            action: SnackBarAction(
                label: context.tr('مراجعة السلة', 'Review cart'),
                onPressed: () => context.pop()),
            backgroundColor: AppColors.danger,
          ));
        }
        return;
      }
    }

    setState(() => _loading = true);

    if (!isReorder) {
      final validationError =
          await ref.read(cartProvider.notifier).validate(isAr: context.isAr);
      if (!mounted) return;
      if (validationError != null) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(validationError),
              backgroundColor: AppColors.danger));
        }
        return;
      }
    }

    try {
      final orderItems =
          isReorder ? reorderSession.items : ref.read(cartProvider).items;
      final cart = ref.read(cartProvider);
      final orderSubtotal = isReorder ? reorderSession.subtotal : cart.subtotal;
      // Wallet coverage must use the SAME base the UI shows the customer: the full
      // payable total INCLUDING shipping (and any coupon), not the subtotal. Otherwise an
      // order whose balance sits between subtotal and total is sent as "fully covered by
      // wallet" with the shipping fee silently unaccounted (mirrors effectiveTotal in build).
      final orderDeliveryFee = isReorder
          ? (_selectedRate != null
              ? _selectedRate!.effectiveRate(orderSubtotal)
              : (cart.cityRate?.effectiveRate(orderSubtotal) ??
                  cart.fallbackShippingFee))
          : _cartDelivery(cart).fee;
      final orderTotal = isReorder
          ? orderSubtotal + orderDeliveryFee
          : cart.subtotal - cart.discountAmount + orderDeliveryFee;
      final couponCode = isReorder ? null : cart.couponCode;
      final addr = _selectedAddress!;
      // Same fail-closed rule as the build method: an unresolved offer means we
      // cannot claim the wallet is usable.
      final offerState = ref.read(welcomeCouponProvider);
      final blocks = offerState.valueOrNull?.blocksWallet == true;
      final cap = blocks ? _walletSpendable : _walletBalance;
      final walletActive = _useWallet && cap > 0 && offerState.hasValue;
      final maxUse = walletActive ? (cap < orderTotal ? cap : orderTotal) : 0.0;
      final walletDeduct = walletActive
          ? (double.tryParse(_walletAmountCtrl.text) ?? 0.0).clamp(0.0, maxUse)
          : 0.0;
      final walletCoversAll = walletActive && walletDeduct >= orderTotal;
      // The method the SERVER was asked to use. When the wallet covers everything that is 'wallet'
      // (an immediate order, no gateway) even if the last-used method in the picker is a gateway;
      // the response handling below must follow this, not the picker.
      final sentMethod = walletCoversAll ? 'wallet' : _paymentMethod;

      final res = await ApiClient.instance.dio.post('/orders', data: {
        'items': orderItems
            .map((i) => {
                  'product_id': i.productId,
                  if (i.variationId != null) 'variation_id': i.variationId,
                  'quantity': i.quantity,
                })
            .toList(),
        'payment_method': sentMethod,
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

      SharedPreferences.getInstance().then((p) => p.setString(
          _kLastPaymentKey, _paymentMethod)); // remember the picker choice

      final resData = res.data;
      // Gateway payments return pending_ref; COD/wallet return data.data directly
      final pendingRef = resData['pending_ref'] as String?;
      if (pendingRef != null) {
        if (sentMethod == 'paypal') {
          await _handlePayPalPayment(pendingRef, clearCart: !isReorder);
        } else if (sentMethod == 'tadawel') {
          await _handleGatewayPayment('tadawel', pendingRef,
              clearCart: !isReorder);
        } else if (sentMethod == 'moamlat') {
          await _handleGatewayPayment('moamlat', pendingRef,
              clearCart: !isReorder);
        } else if (sentMethod == 'mobicash') {
          await _handleMobicashPayment(pendingRef, clearCart: !isReorder);
        } else if (const ['yousrpay', 'masrafipay', 'saharapay']
            .contains(sentMethod)) {
          // Masarat / One-Pay wallets (Yussor / Musrafy / Sahara) — card + OTP, same 2-call
          // contract as Mobicash. Appears only when enabled in the backend payment_methods list.
          await _handleMasaratPayment(sentMethod, pendingRef,
              clearCart: !isReorder);
        } else if (sentMethod == 'sadad') {
          // NOT symmetrical with the other gateways, despite appearances. OrderController only
          // defers order creation for tadawel/moamlat/mobicash/yousrpay/masrafipay/saharapay/
          // paypal — sadad is absent, and SadadController::initiate validates `order_number`,
          // not `pending_ref`. So enabling Sadad needs a backend decision about which model it
          // follows AND an app change; it is not a flag flip. Kept wired for the day the
          // backend joins the deferred path, but see the guard below for the other direction.
          await _handleGatewayPayment('sadad', pendingRef,
              clearCart: !isReorder);
        } else {
          // Unknown/unsupported gateway id from the backend — never strand the user on an infinite spinner.
          if (!mounted) return;
          setState(() => _loading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(context.s.orderError),
                backgroundColor: AppColors.danger));
          }
        }
      } else if (const [
        'tadawel',
        'moamlat',
        'mobicash',
        'yousrpay',
        'masrafipay',
        'saharapay',
        'paypal',
        'sadad'
      ].contains(sentMethod)) {
        // A redirect/card gateway that came back with NO pending_ref. The order has been created
        // and NOT paid, so showing the confirmation screen would tell the customer they had paid
        // when they had not. Refuse instead — this is the shape a half-enabled gateway takes.
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(context.s.orderError),
              backgroundColor: AppColors.danger));
        }
      } else {
        // COD / wallet / bank transfer (lypay) — order created immediately
        final orderData = Map<String, dynamic>.from(resData['data'] as Map);
        ref.read(reorderSessionProvider.notifier).state = null;
        ref.invalidate(welcomeCouponProvider);
        if (!isReorder) await ref.read(cartProvider.notifier).clear();
        if (mounted)
          context.pushReplacement('/order-confirmed', extra: orderData);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (mounted) {
        String msg = context.s.orderError;
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null)
            msg = data['message'].toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _walletAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _handlePayPalPayment(String pendingRef,
      {bool clearCart = true}) async {
    try {
      final res =
          await ApiClient.instance.dio.post('/payment/paypal/initiate', data: {
        'pending_ref': pendingRef,
        'platform': 'mobile',
      });
      final approvalUrl = res.data['approval_url'] as String?;
      if (approvalUrl == null || approvalUrl.isEmpty)
        throw Exception('No approval URL');
      if (!mounted) return;
      setState(() => _loading = false);

      final Uri? deepLink = await Navigator.of(context).push<Uri?>(
        MaterialPageRoute(
            builder: (_) => PaymentWebViewScreen(
                  url: approvalUrl,
                  title: context.tr('الدفع عبر PayPal', 'Pay with PayPal'),
                )),
      );

      if (!mounted || deepLink == null) return;
      setState(() => _loading = true);

      final paypalOrderId = deepLink.queryParameters['token'] ?? '';
      if (paypalOrderId.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      try {
        final captureRes =
            await ApiClient.instance.dio.post('/payment/paypal/capture', data: {
          'pending_ref': pendingRef,
          'paypal_order_id': paypalOrderId,
        });
        final orderId = captureRes.data['order_id'];
        Map<String, dynamic> orderData = {
          'id': orderId,
          'order_number': captureRes.data['order_number'] ?? '',
        };
        try {
          final orderRes = await ApiClient.instance.dio.get('/orders/$orderId');
          orderData = Map<String, dynamic>.from(orderRes.data['data'] as Map);
        } catch (_) {}
        if (clearCart) await ref.read(cartProvider.notifier).clear();
        ref.read(reorderSessionProvider.notifier).state = null;
        ref.invalidate(welcomeCouponProvider);
        if (mounted) {
          setState(() => _loading = false);
          context.pushReplacement('/order-confirmed', extra: orderData);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          String msg = context.tr('فشل تأكيد الدفع — تواصل مع الدعم',
              'Payment confirmation failed — please contact support');
          if (e is DioException) {
            final d = e.response?.data;
            if (d is Map && d['message'] != null) msg = d['message'].toString();
          }
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: AppColors.danger));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        String msg = context.tr(
            'فشل بدء الدفع عبر PayPal', 'Could not start PayPal payment');
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null)
            msg = data['message'].toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _handleGatewayPayment(String gateway, String pendingRef,
      {bool clearCart = true}) async {
    try {
      final res = await ApiClient.instance.dio
          .post('/payment/$gateway/initiate', data: {
        'pending_ref': pendingRef,
        'platform': 'mobile',
      });
      final paymentUrl = res.data['payment_url'] as String?;
      if (paymentUrl == null || paymentUrl.isEmpty)
        throw Exception('No payment URL');
      if (!mounted) return;
      setState(() => _loading = false);

      final title = gateway == 'tadawel'
          ? context.tr('الدفع عبر تداول', 'Pay with Tadawel')
          : gateway == 'sadad'
              ? context.tr('الدفع عبر سداد', 'Pay with Sadad')
              : context.tr('الدفع بالبطاقة المصرفية', 'Pay by bank card');
      final Uri? deepLink = await Navigator.of(context).push<Uri?>(
        MaterialPageRoute(
            builder: (_) =>
                PaymentWebViewScreen(url: paymentUrl, title: title)),
      );

      if (!mounted) return;
      setState(() => _loading = true);

      // Closed with no return link (back / swipe): the customer may still have paid, so look once more
      // (a few tries) before letting them place the order again; a full poll when a return link came back.
      Map<String, dynamic>? result;
      String? terminal;
      final tries = deepLink == null ? 3 : 15;
      for (int i = 0; i < tries; i++) {
        try {
          final statusRes = await ApiClient.instance.dio
              .get('/payment/pending-status/$pendingRef');
          final status = statusRes.data['status'] as String?;
          if (status == 'completed') {
            result = Map<String, dynamic>.from(statusRes.data as Map);
            break;
          }
          if (status == 'failed' || status == 'expired') {
            terminal = status;
            break;
          }
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 2));
      }

      if (!mounted) return;
      if (result == null) {
        setState(() => _loading = false);
        if (deepLink == null) return; // plain close and nothing was paid
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              terminal != null
                  ? context.tr('لم تكتمل عملية الدفع. يمكنك المحاولة مرة أخرى.',
                      'The payment was not completed. You can try again.')
                  : context.tr(
                      'قد يستغرق تأكيد الدفع بضع دقائق. تحقق من طلباتك بعد قليل — لا تُعِد المحاولة لتجنّب الدفع مرتين.',
                      'Payment confirmation may take a few minutes. Check your orders shortly — do not retry, to avoid paying twice.'),
              // Explicit white: the SnackBar bg is fixed dark (ink1), and the themed
              // default text colour is dark in dark mode (dark on dark).
              style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.ink1,
          duration: const Duration(seconds: 6),
        ));
        return;
      }

      final orderId = result['order_id'];
      Map<String, dynamic> orderData = {
        'id': orderId,
        'order_number': result['order_number'] ?? ''
      };
      try {
        final orderRes = await ApiClient.instance.dio.get('/orders/$orderId');
        orderData = Map<String, dynamic>.from(orderRes.data['data'] as Map);
      } catch (_) {}

      if (clearCart) await ref.read(cartProvider.notifier).clear();
      ref.read(reorderSessionProvider.notifier).state = null;
      ref.invalidate(welcomeCouponProvider);
      if (mounted) {
        setState(() => _loading = false);
        context.pushReplacement('/order-confirmed', extra: orderData);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        String msg =
            context.tr('فشل بدء عملية الدفع', 'Could not start the payment');
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null)
            msg = data['message'].toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.danger));
      }
    }
  }

  /// A failure where the request may have reached the server (no response, or a 5xx).
  bool _isAmbiguous(Object e) =>
      e is DioException &&
      (e.response == null || (e.response!.statusCode ?? 0) >= 500);

  /// Asks the server whether the pending checkout completed. Returns the status payload when it did.
  Future<Map<String, dynamic>?> _confirmPending(String pendingRef,
      {int tries = 3}) async {
    for (int i = 0; i < tries; i++) {
      try {
        final r = await ApiClient.instance.dio
            .get('/payment/pending-status/$pendingRef');
        final status = r.data['status'] as String?;
        if (status == 'completed')
          return Map<String, dynamic>.from(r.data as Map);
        if (status == 'failed' || status == 'expired') return null;
      } catch (_) {}
      if (i < tries - 1) await Future.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  Future<void> _handleMobicashPayment(String pendingRef,
      {bool clearCart = true}) async {
    // Show card number input sheet
    final cardCtrl = TextEditingController();
    final otpCtrl = TextEditingController();
    String? mitfTxId;

    if (!mounted) return;
    setState(() => _loading = false);

    // State for the bottom sheet (declared outside builder to avoid re-initialization)
    bool sheetLoading = false;
    String? sheetError;
    bool otpStep = false;

    final Map<String, dynamic>? result =
        await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      // A tap-outside / swipe-down while the verify request is in flight would abandon a payment the
      // server may already have taken (cart kept, order exists): closing is only via Cancel when idle.
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => PopScope(
          canPop: !sheetLoading,
          child: GestureDetector(
            onTap: () => FocusScope.of(ctx).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              decoration: BoxDecoration(
                color: context.col.surface,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: context.col.border,
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Text(
                      otpStep
                          ? context.tr(
                              'رمز التحقق OTP', 'OTP verification code')
                          : context.tr(
                              'رقم بطاقة موبيكاش', 'Mobicash card number'),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (!otpStep)
                    TextField(
                      controller: cardCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: context.tr('أدخل رقم بطاقة موبيكاش',
                            'Enter your Mobicash card number'),
                        border: const OutlineInputBorder(),
                      ),
                    )
                  else
                    TextField(
                      controller: otpCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: context.tr('أدخل رمز OTP المرسل إليك',
                            'Enter the OTP sent to you'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  if (sheetError != null) ...[
                    const SizedBox(height: 8),
                    Text(sheetError!,
                        style:
                            TextStyle(color: AppColors.danger, fontSize: 13)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: sheetLoading
                          ? null
                          : () async {
                              if (!otpStep) {
                                if (cardCtrl.text.trim().isEmpty) {
                                  setS(() => sheetError = context.tr(
                                      'يرجى إدخال رقم البطاقة',
                                      'Please enter the card number'));
                                  return;
                                }
                                setS(() {
                                  sheetLoading = true;
                                  sheetError = null;
                                });
                                try {
                                  final r = await ApiClient.instance.dio.post(
                                    '/payment/mobicash/initiate',
                                    data: {
                                      'pending_ref': pendingRef,
                                      'card_number': cardCtrl.text.trim()
                                    },
                                  );
                                  mitfTxId =
                                      r.data['mitf_transaction_id']?.toString();
                                  setS(() {
                                    sheetLoading = false;
                                    otpStep = true;
                                  });
                                } catch (e) {
                                  String msg = context.tr(
                                      'البطاقة غير صحيحة أو الخدمة غير متاحة',
                                      'Invalid card or service unavailable');
                                  if (e is DioException) {
                                    final d = e.response?.data;
                                    if (d is Map && d['message'] != null)
                                      msg = d['message'].toString();
                                  }
                                  setS(() {
                                    sheetLoading = false;
                                    sheetError = msg;
                                  });
                                }
                              } else {
                                if (otpCtrl.text.trim().isEmpty) {
                                  setS(() => sheetError = context.tr(
                                      'يرجى إدخال رمز OTP',
                                      'Please enter the OTP'));
                                  return;
                                }
                                setS(() {
                                  sheetLoading = true;
                                  sheetError = null;
                                });
                                try {
                                  final r = await ApiClient.instance.dio.post(
                                    '/payment/mobicash/verify-otp',
                                    data: {
                                      'pending_ref': pendingRef,
                                      'card_number': cardCtrl.text.trim(),
                                      'otp': otpCtrl.text.trim(),
                                      'mitf_transaction_id': mitfTxId ?? '',
                                    },
                                  );
                                  if (ctx.mounted) {
                                    Navigator.of(ctx)
                                        .pop<Map<String, dynamic>>({
                                      'id': r.data['order_id'],
                                      'order_number':
                                          r.data['order_number'] ?? '',
                                    });
                                  }
                                } catch (e) {
                                  if (_isAmbiguous(e)) {
                                    // Timeout / dropped connection / 5xx: the gateway may have charged and the order may
                                    // exist. Ask the server before showing "wrong code" (a retry would send a spent OTP).
                                    final done =
                                        await _confirmPending(pendingRef);
                                    if (!ctx.mounted) return;
                                    if (done != null) {
                                      Navigator.of(ctx)
                                          .pop<Map<String, dynamic>>({
                                        'id': done['order_id'],
                                        'order_number':
                                            done['order_number'] ?? '',
                                      });
                                      return;
                                    }
                                    setS(() {
                                      sheetLoading = false;
                                      sheetError = context.tr(
                                          'تعذّر تأكيد الدفع الآن. تحقق من طلباتك قبل إعادة المحاولة لتجنّب الدفع مرتين.',
                                          'Could not confirm the payment right now. Check your orders before trying again to avoid paying twice.');
                                    });
                                    return;
                                  }
                                  String msg = context.tr(
                                      'رمز OTP غير صحيح، حاول مجدداً',
                                      'Incorrect OTP, please try again');
                                  if (e is DioException) {
                                    final d = e.response?.data;
                                    if (d is Map && d['message'] != null)
                                      msg = d['message'].toString();
                                  }
                                  setS(() {
                                    sheetLoading = false;
                                    sheetError = msg;
                                  });
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: sheetLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              otpStep
                                  ? context.tr('تأكيد الدفع', 'Confirm payment')
                                  : context.tr('إرسال OTP', 'Send OTP'),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  TextButton(
                    onPressed:
                        sheetLoading ? null : () => Navigator.of(ctx).pop(),
                    child: Text(context.tr('إلغاء', 'Cancel')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (result == null) return;
    if (!mounted) return;

    // Fetch full order data for the confirmation screen
    Map<String, dynamic> orderData = result;
    final orderId = result['id'];
    if (orderId != null) {
      try {
        final orderRes = await ApiClient.instance.dio.get('/orders/$orderId');
        orderData = Map<String, dynamic>.from(orderRes.data['data'] as Map);
      } catch (_) {}
    }

    if (clearCart) await ref.read(cartProvider.notifier).clear();
    ref.read(reorderSessionProvider.notifier).state = null;
    ref.invalidate(welcomeCouponProvider);
    if (mounted) context.pushReplacement('/order-confirmed', extra: orderData);
  }

  // Masarat / One-Pay wallets (Yussor / Musrafy / Sahara). Same 2-step card+OTP sheet as Mobicash,
  // but keyed by provider (endpoint `/payment/masarat/$provider/...`) with an `identity_card` field.
  Future<void> _handleMasaratPayment(String provider, String pendingRef,
      {bool clearCart = true}) async {
    final label = provider == 'masrafipay'
        ? context.tr('مصرفي باي', 'Masrafi Pay')
        : provider == 'saharapay'
            ? context.tr('صحارى باي', 'Sahara Pay')
            : context.tr('يسر باي', 'Yousr Pay');
    final cardCtrl = TextEditingController();
    final otpCtrl = TextEditingController();

    if (!mounted) return;
    setState(() => _loading = false);

    bool sheetLoading = false;
    String? sheetError;
    bool otpStep = false;

    final Map<String, dynamic>? result =
        await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      // A tap-outside / swipe-down while the verify request is in flight would abandon a payment the
      // server may already have taken (cart kept, order exists): closing is only via Cancel when idle.
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => PopScope(
          canPop: !sheetLoading,
          child: GestureDetector(
            onTap: () => FocusScope.of(ctx).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              decoration: BoxDecoration(
                color: context.col.surface,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: context.col.border,
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Text(
                      otpStep
                          ? context.tr('رمز التحقق', 'Verification code')
                          : context.tr('الدفع عبر $label', 'Pay with $label'),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (!otpStep)
                    TextField(
                      controller: cardCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: context.tr('أدخل رقم بطاقة $label',
                            'Enter your $label card number'),
                        border: const OutlineInputBorder(),
                      ),
                    )
                  else
                    TextField(
                      controller: otpCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: context.tr('أدخل رمز التحقق المرسل إليك',
                            'Enter the verification code sent to you'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  if (otpStep) ...[
                    const SizedBox(height: 6),
                    Text(
                        context.tr('أدخل الرمز خلال دقيقتين',
                            'Enter the code within two minutes'),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                  if (sheetError != null) ...[
                    const SizedBox(height: 8),
                    Text(sheetError!,
                        style:
                            TextStyle(color: AppColors.danger, fontSize: 13)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: sheetLoading
                          ? null
                          : () async {
                              if (!otpStep) {
                                if (cardCtrl.text.trim().isEmpty) {
                                  setS(() => sheetError = context.tr(
                                      'يرجى إدخال رقم البطاقة',
                                      'Please enter the card number'));
                                  return;
                                }
                                setS(() {
                                  sheetLoading = true;
                                  sheetError = null;
                                });
                                try {
                                  await ApiClient.instance.dio.post(
                                    '/payment/masarat/$provider/initiate',
                                    data: {
                                      'pending_ref': pendingRef,
                                      'identity_card': cardCtrl.text.trim()
                                    },
                                  );
                                  setS(() {
                                    sheetLoading = false;
                                    otpStep = true;
                                  });
                                } catch (e) {
                                  String msg = context.tr(
                                      'البطاقة غير صحيحة أو الخدمة غير متاحة',
                                      'Invalid card or service unavailable');
                                  if (e is DioException) {
                                    final d = e.response?.data;
                                    if (d is Map && d['message'] != null)
                                      msg = d['message'].toString();
                                  }
                                  setS(() {
                                    sheetLoading = false;
                                    sheetError = msg;
                                  });
                                }
                              } else {
                                if (otpCtrl.text.trim().isEmpty) {
                                  setS(() => sheetError = context.tr(
                                      'يرجى إدخال رمز التحقق',
                                      'Please enter the verification code'));
                                  return;
                                }
                                setS(() {
                                  sheetLoading = true;
                                  sheetError = null;
                                });
                                try {
                                  final r = await ApiClient.instance.dio.post(
                                    '/payment/masarat/$provider/verify-otp',
                                    data: {
                                      'pending_ref': pendingRef,
                                      'identity_card': cardCtrl.text.trim(),
                                      'otp': otpCtrl.text.trim(),
                                    },
                                  );
                                  if (ctx.mounted) {
                                    Navigator.of(ctx)
                                        .pop<Map<String, dynamic>>({
                                      'id': r.data['order_id'],
                                      'order_number':
                                          r.data['order_number'] ?? '',
                                    });
                                  }
                                } catch (e) {
                                  if (_isAmbiguous(e)) {
                                    // Timeout / dropped connection / 5xx: the gateway may have charged and the order may
                                    // exist. Ask the server before showing "wrong code" (a retry would send a spent OTP).
                                    final done =
                                        await _confirmPending(pendingRef);
                                    if (!ctx.mounted) return;
                                    if (done != null) {
                                      Navigator.of(ctx)
                                          .pop<Map<String, dynamic>>({
                                        'id': done['order_id'],
                                        'order_number':
                                            done['order_number'] ?? '',
                                      });
                                      return;
                                    }
                                    setS(() {
                                      sheetLoading = false;
                                      sheetError = context.tr(
                                          'تعذّر تأكيد الدفع الآن. تحقق من طلباتك قبل إعادة المحاولة لتجنّب الدفع مرتين.',
                                          'Could not confirm the payment right now. Check your orders before trying again to avoid paying twice.');
                                    });
                                    return;
                                  }
                                  String msg = context.tr(
                                      'رمز التحقق غير صحيح، حاول مجدداً',
                                      'Incorrect verification code, please try again');
                                  if (e is DioException) {
                                    final d = e.response?.data;
                                    if (d is Map && d['message'] != null)
                                      msg = d['message'].toString();
                                  }
                                  setS(() {
                                    sheetLoading = false;
                                    sheetError = msg;
                                  });
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: sheetLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              otpStep
                                  ? context.tr('تأكيد الدفع', 'Confirm payment')
                                  : context.tr('إرسال الرمز', 'Send code'),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  TextButton(
                    onPressed:
                        sheetLoading ? null : () => Navigator.of(ctx).pop(),
                    child: Text(context.tr('إلغاء', 'Cancel')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (result == null) return;
    if (!mounted) return;

    Map<String, dynamic> orderData = result;
    final orderId = result['id'];
    if (orderId != null) {
      try {
        final orderRes = await ApiClient.instance.dio.get('/orders/$orderId');
        orderData = Map<String, dynamic>.from(orderRes.data['data'] as Map);
      } catch (_) {}
    }

    if (clearCart) await ref.read(cartProvider.notifier).clear();
    ref.read(reorderSessionProvider.notifier).state = null;
    ref.invalidate(welcomeCouponProvider);
    if (mounted) context.pushReplacement('/order-confirmed', extra: orderData);
  }

  /// Delivery fee for a NORMAL (cart) checkout. It follows the address chosen on this page — the server
  /// prices by shipping_city — and only falls back to the cart's header-city rate while the chosen
  /// address has no matching rate. (Quoting the header city made the total wrong whenever the customer
  /// picked an address in another city.) Collection fee handling is unchanged.
  ({double fee, bool known}) _cartDelivery(CartState cart) {
    if (cart.couponFreeShipping) return (fee: 0.0, known: true);
    final rate = _selectedRate ?? cart.cityRate;
    if (rate == null) return (fee: 0.0, known: false);
    final base = rate.effectiveRate(cart.subtotal);
    if (base == 0) return (fee: 0.0, known: true); // free shipping — waive collection fee too
    return (fee: base + cart.totalCollectionFee, known: true);
  }

  ShippingRate? get _selectedRate {
    final city = (_selectedAddress?['city'] ?? '').toString();
    if (city.isEmpty) return null;
    final rates = ref.read(shippingRatesProvider).valueOrNull ?? [];
    try {
      return rates.firstWhere((r) =>
          r.cityAr == city || r.city.toLowerCase() == city.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  /// The server-written wallet note in the app language; falls back to the other language only
  /// when this one is empty. Always non-null so the wallet row still reads as blocked.
  String _walletBlockedNoteText(WelcomeCoupon c, bool isAr) {
    final ar = c.walletNoteAr ?? '';
    final en = c.walletNoteEn ?? '';
    if (isAr) return ar.isNotEmpty ? ar : en;
    return en.isNotEmpty ? en : ar;
  }

  String _paymentMethodLabel(BuildContext context, List methods) {
    final isAr = context.isAr;
    try {
      final m = methods.firstWhere((m) => m.id == _paymentMethod);
      return isAr ? m.labelAr : (m.labelEn.isNotEmpty ? m.labelEn : m.labelAr);
    } catch (_) {
      switch (_paymentMethod) {
        case 'cash_on_delivery':
        case 'cash':       return isAr ? 'الدفع عند الاستلام' : 'Cash on Delivery';
        case 'wallet':     return isAr ? 'المحفظة'            : 'Wallet';
        case 'tadawel':    return isAr ? 'تداول'              : 'Tadawel';
        case 'moamlat':    return isAr ? 'بطاقة مصرفية'       : 'Bank Card';
        case 'mobicash':   return isAr ? 'موبي كاش'           : 'Mobicash';
        case 'paypal':     return 'PayPal';
        case 'lypay':      return isAr ? 'تحويل مصرفي'        : 'Bank Transfer';
        case 'sadad':      return isAr ? 'سداد'               : 'Sadad';
        case 'yousrpay':   return isAr ? 'يسر باي'            : 'Yousr Pay';
        case 'masrafipay': return isAr ? 'مصرفي باي'          : 'Masrafi Pay';
        case 'saharapay':  return isAr ? 'صحارى باي'          : 'Sahara Pay';
        case 'crypto':     return isAr ? 'عملات رقمية'        : 'Crypto';
        default:           return _paymentMethod;
      }
    }
  }

  bool get _codAllowedForAddress {
    final city = (_selectedAddress?['city'] ?? '').toString();
    if (city.isEmpty) return true;
    final rates = ref.read(shippingRatesProvider).valueOrNull ?? [];
    try {
      final rate = rates.firstWhere((r) =>
          r.cityAr == city || r.city.toLowerCase() == city.toLowerCase());
      return rate.codAllowed;
    } catch (_) {
      return city.contains('طرابلس') || city.toLowerCase().contains('tripoli');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Leaving while the order request is in flight strands the confirmation screen (the order
    // exists and the cart is already cleared), so back is blocked until it settles.
    return PopScope(
      canPop: !_loading,
      // Android back / iOS swipe-back left a reorder session behind, so the next checkout from the cart
      // showed (and ordered) the old reorder items. Always clear it when this screen is left.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(reorderSessionProvider.notifier).state = null;
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final reorderSession = ref.watch(reorderSessionProvider);
    final isReorder = reorderSession != null;
    final config = ref.watch(appConfigProvider);
    // Cashback shown at checkout uses the shopper's own tier rate, not the base rate.
    final _cbTierRate = ref.watch(tierProvider).valueOrNull?.cashbackRate ?? 0;
    final cbRate = _cbTierRate > 0 ? _cbTierRate : config.cashbackRate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accent(context);
    // The auto-applied offer the backend is holding for this customer, if any.
    final autoOfferAsync = ref.watch(welcomeCouponProvider);
    final autoOffer = autoOfferAsync.valueOrNull;
    // Until the answer arrives — or if the call failed — we do NOT know whether an
    // offer blocks the wallet. valueOrNull is null in all three cases, so
    // `?.blocksWallet == true` read "not blocked" while still loading and the wallet
    // was offered for an order the server then refused with a bare Server Error.
    // The server decides this fail-closed; match it.
    final autoOfferUnknown = !autoOfferAsync.hasValue;

    // Effective items and subtotal: reorder session takes priority over cart
    final effectiveItems = isReorder ? reorderSession.items : cart.items;
    final effectiveSubtotal =
        isReorder ? reorderSession.subtotal : cart.subtotal;
    // Watch shipping rates so delivery fee recalculates when address changes
    ref.watch(shippingRatesProvider);
    final selectedRate = _selectedRate;
    // A reorder with no rate for its city yet must not fall back to the flat fee — that
    // invents a price. Treated as unknown, exactly like the cart does.
    final cartDelivery = _cartDelivery(cart);
    final deliveryKnown = isReorder
        ? (selectedRate != null || cart.cityRate != null)
        : cartDelivery.known;
    final effectiveDeliveryFee = isReorder
        ? (selectedRate != null
            ? selectedRate.effectiveRate(effectiveSubtotal)
            : (cart.cityRate?.effectiveRate(effectiveSubtotal) ?? 0))
        : cartDelivery.fee;
    final effectiveTotal = isReorder
        ? effectiveSubtotal + effectiveDeliveryFee
        : cart.subtotal - cart.discountAmount + effectiveDeliveryFee;

    final allMethods = (config.paymentMethods as List)
        .where((m) => m.enabled == true && m.id != 'wallet')
        .toList();
    final codValueExceeded = effectiveTotal > 5000;
    final codItemsExceeded = effectiveItems.length > 20;
    final codBlocked =
        !_codAllowedForAddress || codValueExceeded || codItemsExceeded;
    final methods = codBlocked
        ? allMethods.where((m) => m.id != 'cash_on_delivery').toList()
        : allMethods;

    // An offer that IS the discount on this order (the first-order 15%) cannot be combined
    // with wallet credit — the balance stays for the next order. The server refuses the
    // combination outright, so offering the toggle here only leads to a dead end.
    // A blocking offer no longer means "no wallet": reward credit waits for the next
    // order, but money the customer topped up stays spendable, so cap rather than hide.
    // Unknown still means blocked — we must not offer what the server may refuse.
    final offerBlocks = autoOffer?.blocksWallet == true;
    final walletCap = offerBlocks ? _walletSpendable : _walletBalance;
    final walletBlocked =
        autoOfferUnknown || (offerBlocks && _walletSpendable <= 0);
    final walletActive = _useWallet && walletCap > 0 && !walletBlocked;
    final maxWalletUse = walletActive
        ? (walletCap < effectiveTotal ? walletCap : effectiveTotal)
        : 0.0;
    final parsedWalletInput = double.tryParse(_walletAmountCtrl.text) ?? 0.0;
    final walletDeduct =
        walletActive ? parsedWalletInput.clamp(0.0, maxWalletUse) : 0.0;
    final walletCoversAll = walletActive && walletDeduct >= effectiveTotal;
    final amountDue = walletActive
        ? (effectiveTotal - walletDeduct).clamp(0.0, effectiveTotal)
        : effectiveTotal;
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(children: [
                    IconButton(
                      onPressed: _loading
                          ? null
                          : () {
                              ref.read(reorderSessionProvider.notifier).state =
                                  null;
                              context.pop();
                            },
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          color: context.col.ink0, size: 20),
                    ),
                    Text(
                        isReorder
                            ? (context.isAr ? 'إعادة الطلب' : 'Reorder')
                            : context.s.cartTitle,
                        style: TextStyle(
                            fontFamily: 'Manrope',
                            fontFamilyFallback: ['Tajawal'],
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: context.col.ink2)),
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
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: accent, width: 1.5),
                            ),
                            child: Row(children: [
                              Icon(Icons.add_location_alt_outlined,
                                  color: accent, size: 18),
                              const SizedBox(width: 10),
                              Text(context.s.addNewAddress,
                                  style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        )
                      : GestureDetector(
                          onTap: _showAddressSheet,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _cardFill(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.col.border),
                            ),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Icon(Icons.location_on_outlined,
                                        size: 18, color: accent),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(
                                            context.s.translateAddrLabel(
                                                _selectedAddress!['label']
                                                        as String? ??
                                                    ''),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14)),
                                        const SizedBox(height: 2),
                                        Text(
                                            [
                                              context.s.translateCity(
                                                  _selectedAddress!['city']
                                                          ?.toString() ??
                                                      ''),
                                              _selectedAddress!['address'],
                                              if ((_selectedAddress!['phone']
                                                          as String?)
                                                      ?.isNotEmpty ==
                                                  true)
                                                _fmtPhone(
                                                    _selectedAddress!['phone']
                                                        .toString()),
                                            ]
                                                .where((v) => v.isNotEmpty)
                                                .join('  ·  '),
                                            style: TextStyle(
                                                fontSize: 12.5,
                                                color: context.col.ink2)),
                                        if (_selectedRate != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                              // Show the SAME delivery fee as the order summary — i.e. incl. the
                                              // per-vendor collection fee (and free-shipping) — not the raw base rate.
                                              '${!deliveryKnown ? '—' : effectiveDeliveryFee == 0 ? context.s.freeText : '${fmtPrice(effectiveDeliveryFee)} ${context.s.lydUnit}'} · ${dayCountLabel(_selectedRate!.deliveryDays, context.isAr)}',
                                              style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: context.col.ink2,
                                                  fontWeight: FontWeight.w600)),
                                        ],
                                      ])),
                                  Icon(Icons.keyboard_arrow_down_rounded,
                                      size: 22, color: context.col.ink2),
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
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.col.border),
                      ),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(builder: (_) {
                              final iconPath = _paymentMethod.isNotEmpty &&
                                      !walletCoversAll
                                  ? _paymentIconPath(_paymentMethod)
                                  : (_paymentMethod == ''
                                      ? null
                                      : 'assets/images/payment/wallet_pay.png');
                              final iconUrl = (_paymentMethod.isNotEmpty &&
                                      !walletCoversAll)
                                  ? _payIconUrl(config.paymentMethods as List,
                                      _paymentMethod)
                                  : null;
                              final fallback = iconPath != null
                                  ? Image.asset(iconPath, fit: BoxFit.contain)
                                  : Icon(Icons.payment_outlined,
                                      size: 18, color: accent);
                              return SizedBox(
                                width: 26,
                                height: 26,
                                child: iconUrl != null
                                    ? Image.network(iconUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => fallback)
                                    : fallback,
                              );
                            }),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      walletCoversAll
                                          ? context.s.walletTitle
                                          : (walletActive &&
                                                  _paymentMethod.isNotEmpty
                                              ? '${context.s.walletTitle} + ${_paymentMethodLabel(context, methods)}'
                                              : (_paymentMethod.isEmpty
                                                  ? (context.isAr
                                                      ? 'اختر طريقة الدفع'
                                                      : 'Select Payment Method')
                                                  : _paymentMethodLabel(
                                                      context, methods))),
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: _paymentMethod.isEmpty
                                              ? const Color(0xFF9CA3AF)
                                              : null)),
                                  if (walletActive && walletDeduct > 0) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                        walletCoversAll
                                            ? context.s.walletCoversAll(
                                                fmtPrice(walletDeduct))
                                            : context.s.walletPartial(
                                                fmtPrice(walletDeduct),
                                                fmtPrice(amountDue)),
                                        style: TextStyle(
                                            fontSize: 12.5, color: accent)),
                                  ],
                                ])),
                            Icon(Icons.keyboard_arrow_down_rounded,
                                size: 22, color: context.col.ink2),
                          ]),
                    ),
                  ),
                  if (codValueExceeded || codItemsExceeded) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 13, color: AppColors.danger),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              codValueExceeded
                                  ? context.tr(
                                      'الدفع عند الاستلام غير متاح — المجموع يتجاوز 5,000 د.ل',
                                      'Cash on delivery is unavailable — total exceeds 5,000 ${context.s.lydUnit}')
                                  : context.tr(
                                      'الدفع عند الاستلام غير متاح — الطلب يتجاوز 20 منتج',
                                      'Cash on delivery is unavailable — order exceeds 20 items'),
                              style: const TextStyle(
                                  fontSize: 11.5, color: AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Order items (collapsible) ─────────────────────────
                  _SectionLabel(
                      context.s.productsCountN(effectiveItems.length)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _itemsExpanded = !_itemsExpanded),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _cardFill(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.col.border),
                      ),
                      child: Row(children: [
                        Expanded(
                            child: Text(
                                '${fmtPrice(effectiveSubtotal)} ${context.s.lydUnit}',
                                style: TextStyle(
                                    fontSize: 12.5, color: context.col.ink2))),
                        AnimatedRotation(
                          turns: _itemsExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.keyboard_arrow_down_rounded,
                              size: 20, color: context.col.ink2),
                        ),
                      ]),
                    ),
                  ),
                  if (_itemsExpanded) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _cardFill(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.col.border),
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
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: item.image != null
                                        ? OptimizedNetworkImage(
                                            url: item.image!,
                                            width: 52,
                                            height: 52,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 104,
                                            variantWidth: 400,
                                            error: _ImagePlaceholder(size: 52),
                                          )
                                        : _ImagePlaceholder(size: 52),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(
                                            isAr
                                                ? item.product.nameAr
                                                : item.product.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600)),
                                        if (variationLabel != null &&
                                            variationLabel.isNotEmpty)
                                          Text(variationLabel,
                                              style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: context.col.ink2)),
                                        const SizedBox(height: 6),
                                        Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              if (isReorder) ...[
                                                // Inline qty stepper for reorder mode
                                                Row(children: [
                                                  _QtyBtn(
                                                    icon: Icons.remove,
                                                    enabled: item.quantity > 1,
                                                    onTap: () =>
                                                        _updateReorderQty(
                                                            item.key,
                                                            item.quantity - 1),
                                                  ),
                                                  Padding(
                                                    // 4 (was 10): each _QtyBtn now has 6pt of hit-area padding.
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 4),
                                                    child: Text(
                                                        '${item.quantity}',
                                                        style: const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontFamily:
                                                                'PlusJakartaSans')),
                                                  ),
                                                  _QtyBtn(
                                                    icon: Icons.add,
                                                    enabled:
                                                        item.quantity < maxQty,
                                                    onTap: () =>
                                                        _updateReorderQty(
                                                            item.key,
                                                            item.quantity + 1),
                                                  ),
                                                ]),
                                              ] else ...[
                                                Text('× ${item.quantity}',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: context.col.ink2,
                                                        fontFamily:
                                                            'PlusJakartaSans')),
                                              ],
                                              Text(
                                                  '${fmtPrice(item.total)} ${context.s.lydUnit}',
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontFamily:
                                                          'PlusJakartaSans')),
                                            ]),
                                      ])),
                                ]),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Price summary ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _cardFill(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.col.border),
                    ),
                    child: Column(children: [
                      _SummaryRow(context.s.subtotalLabel,
                          '${fmtPrice(effectiveSubtotal)} ${context.s.lydUnit}',
                          ctx: context),
                      if (!isReorder && cart.discountAmount > 0)
                        _SummaryRow(context.s.couponDiscount,
                            '− ${fmtPrice(cart.discountAmount)} ${context.s.lydUnit}',
                            color: AppColors.success, ctx: context),
                      // A delivery-only coupon discounts nothing, so it gets its own line
                      // instead of a "− 0" that reads like the code was ignored.
                      if (!isReorder &&
                          cart.discountAmount == 0 &&
                          cart.couponFreeShipping)
                        _SummaryRow(context.s.couponDiscount,
                            context.s.freeDeliveryOffer,
                            color: AppColors.success, ctx: context),
                      // Blank, not zero, until the city's rate is loaded — zero reads as
                      // free delivery. The total is unknowable for the same reason.
                      _SummaryRow(
                          context.s.shippingCost,
                          !deliveryKnown
                              ? '—'
                              : effectiveDeliveryFee == 0
                                  ? context.s.freeText
                                  : '${fmtPrice(effectiveDeliveryFee)} ${context.s.lydUnit}',
                          color: deliveryKnown && effectiveDeliveryFee == 0
                              ? AppColors.success
                              : null,
                          ctx: context),
                      Divider(height: 20, color: context.col.border),
                      _SummaryRow(
                          context.s.orderTotal,
                          deliveryKnown
                              ? '${fmtPrice(effectiveTotal)} ${context.s.lydUnit}'
                              : '—',
                          bold: true,
                          ctx: context),
                    ]),
                  ),
                  // Cashback earned on this order
                  if (effectiveSubtotal >= config.cashbackMinOrder &&
                      cbRate > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.transparent
                            : AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.success
                                .withValues(alpha: isDark ? 0.45 : 0.35)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.stars_rounded,
                            size: 18, color: AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                context.s.orderCashbackEarn(
                                    fmtPrice(effectiveSubtotal * cbRate / 100),
                                    (effectiveSubtotal * cbRate / 10)
                                        .round()
                                        .clamp(1, 9999)
                                        .toString()),
                                style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontFamilyFallback: ['Tajawal'],
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success))),
                      ]),
                    ),
                  // Auto-applied offer strip (currently the second-order win-back)
                  if (!isReorder &&
                      autoOffer != null &&
                      cart.couponCode?.toUpperCase() ==
                          autoOffer.code.toUpperCase())
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.transparent
                            : AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.success
                                .withValues(alpha: isDark ? 0.45 : 0.35)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 18, color: AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                '✓ ${context.tr(autoOffer.appliedAr, autoOffer.appliedEn)}',
                                style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontFamilyFallback: ['Tajawal'],
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success))),
                      ]),
                    ),
                  const SizedBox(height: 24),

                  // ── Trust badges ───────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      color: _cardFill(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.col.border),
                    ),
                    child: const _TrustRow(),
                  ),
                  const SizedBox(height: 24),

                  // ── Notes ─────────────────────────────────────────────
                  _SectionLabel(context.s.notesOptional),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _cardFill(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.col.border),
                    ),
                    child: TextField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        filled: false,
                        hintText: context.s.notesHint,
                        hintStyle:
                            TextStyle(color: context.col.ink3, fontSize: 13.5),
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
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: context.col.surface,
              boxShadow: AppShadows.shadowPop,
            ),
            child: Column(children: [
              if (_paymentMethod.isEmpty)
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: context.col.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.col.border),
                  ),
                  child: Center(
                    child: Text(
                        context.tr('اختر طريقة الدفع', 'Select payment method'),
                        style: TextStyle(
                            fontFamily: 'Manrope',
                            fontFamilyFallback: ['Tajawal'],
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.col.ink3)),
                  ),
                )
              else
                GestureDetector(
                  onTap: _loading ? null : _placeOrder,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_loading)
                          const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                        else
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(context.s.placeOrder,
                                style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontFamilyFallback: ['Tajawal'],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ]),
                        if (!_loading)
                          PositionedDirectional(
                            end: 16,
                            child: Text(
                                '${fmtPrice(effectiveTotal)} ${context.s.lydUnit}',
                                style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ),
                      ],
                    ),
                  ),
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
  final void Function(bool useWallet, String walletAmount, String paymentMethod)
      onConfirm;

  /// Non-null when an offer on this order can't be combined with wallet credit — the text
  /// is the server's explanation, shown on the disabled card.
  final String? walletBlockedNote;

  const _PaymentSheet({
    this.walletBlockedNote,
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

/// Wallet amount text: whole dinars stay whole, fractions keep 2 decimals (rounding 45.50 down to 45
/// used to leave a remainder that forced a second payment method for a few piastres).
String _fmtAmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

class _PaymentSheetState extends State<_PaymentSheet> {
  late bool _useWallet;
  late String _paymentMethod;
  late final TextEditingController _walletAmountCtrl;

  @override
  void initState() {
    super.initState();
    _useWallet = widget.initialUseWallet && widget.walletBlockedNote == null;
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
        ? widget.walletBalance
        : widget.cartTotal;
    if (parsed > maxUse && maxUse > 0) {
      final clamped = _fmtAmt(maxUse);
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
    final walletBlocked = widget.walletBlockedNote != null;
    final walletActive =
        _useWallet && widget.walletBalance > 0 && !walletBlocked;
    final maxWalletUse = walletActive
        ? (widget.walletBalance < widget.cartTotal
            ? widget.walletBalance
            : widget.cartTotal)
        : 0.0;
    final parsedAmount = double.tryParse(_walletAmountCtrl.text) ?? 0.0;
    final walletDeduct =
        walletActive ? parsedAmount.clamp(0.0, maxWalletUse) : 0.0;
    final walletCoversAll = walletDeduct >= widget.cartTotal;
    final amountDue =
        (widget.cartTotal - walletDeduct).clamp(0.0, widget.cartTotal);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: context.col.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text(context.s.paymentMethod,
              style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontFamilyFallback: ['Tajawal'],
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),

          if (!widget.codAllowed) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warn.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.warn.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    size: 15, color: AppColors.warn),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(context.s.codTripiliOnly,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.warn, height: 1.4))),
              ]),
            ),
          ],

          // Wallet card
          GestureDetector(
            onTap: widget.walletBalance > 0 && !walletBlocked
                ? () {
                    final enabling = !_useWallet;
                    if (enabling) {
                      final maxUse = widget.walletBalance < widget.cartTotal
                          ? widget.walletBalance
                          : widget.cartTotal;
                      _walletAmountCtrl.text = _fmtAmt(maxUse);
                    }
                    setState(() => _useWallet = enabling);
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _cardFill(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.col.border),
              ),
              child: Row(children: [
                Opacity(
                    opacity: walletBlocked ? 0.4 : 1,
                    child: _RadioDot(selected: walletActive)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(context.s.walletTitle,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: walletBlocked ? context.col.ink3 : null)),
                      const SizedBox(height: 2),
                      if (walletBlocked)
                        Text(widget.walletBlockedNote!,
                            style: TextStyle(
                                fontSize: 11.5,
                                height: 1.45,
                                color: context.col.ink3))
                      else if (widget.walletLoading)
                        Text(context.s.loading,
                            style: TextStyle(
                                fontSize: 11.5, color: context.col.ink3))
                      else
                        Text(
                            widget.walletBalance > 0
                                ? context.s.walletBalanceLabel(
                                    fmtPrice(widget.walletBalance))
                                : context.s.walletEmpty,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: widget.walletBalance > 0
                                    ? AppColors.success
                                    : context.col.ink3)),
                    ])),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onTopUp,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.col.borderStrong),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add, size: 10, color: context.col.ink2),
                      const SizedBox(width: 2),
                      Text(context.s.topUpShort,
                          style: TextStyle(
                              fontFamily: 'Manrope',
                              fontFamilyFallback: ['Tajawal'],
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: context.col.ink2)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _softFill(context),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        isDark ? Border.all(color: context.col.border) : null,
                  ),
                  child: Image.asset('assets/images/payment/wallet_pay.png',
                      fit: BoxFit.contain),
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(context.tr('استخدم', 'Use'),
                          style: TextStyle(
                              fontFamily: 'Manrope',
                              fontFamilyFallback: ['Tajawal'],
                              fontSize: 12,
                              color: context.col.ink2,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _walletAmountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textDirection: TextDirection.ltr,
                          onChanged: _onAmountChanged,
                          style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: TextStyle(color: context.col.ink4),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 6),
                          ),
                        ),
                      ),
                      Text('/ ${fmtPrice(maxWalletUse)} ${context.s.lydUnit}',
                          style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11.5,
                              color: context.col.ink3,
                              fontWeight: FontWeight.w500)),
                    ]),
                    if (walletDeduct > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                          walletCoversAll
                              ? context.s
                                  .walletCoversAll(fmtPrice(walletDeduct))
                              : context.s.walletPartial(
                                  fmtPrice(walletDeduct), fmtPrice(amountDue)),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: walletCoversAll
                                  ? AppColors.success
                                  : accent)),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(
                          context.tr('أدخل مبلغاً للخصم من محفظتك',
                              'Enter an amount to deduct from your wallet'),
                          style: TextStyle(
                              fontSize: 11.5, color: context.col.ink4)),
                    ],
                  ]),
            ),
          ],

          if (!walletCoversAll) ...[
            ...widget.methods.map((m) => GestureDetector(
                  onTap: () => setState(() => _paymentMethod = m.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _cardFill(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.col.border),
                    ),
                    child: Row(children: [
                      _RadioDot(selected: _paymentMethod == m.id),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                context.isAr
                                    ? m.labelAr
                                    : (m.labelEn.isNotEmpty
                                        ? m.labelEn
                                        : m.labelAr),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                            Text(
                                context.isAr
                                    ? (m.descriptionAr.isNotEmpty
                                        ? m.descriptionAr
                                        : (m.fee > 0
                                            ? context.s
                                                .serviceFeeN(fmtPrice(m.fee))
                                            : context.s.noFees))
                                    : (m.descriptionEn.isNotEmpty
                                        ? m.descriptionEn
                                        : (m.fee > 0
                                            ? context.s
                                                .serviceFeeN(fmtPrice(m.fee))
                                            : context.s.noFees)),
                                style: TextStyle(
                                    fontSize: 11.5, color: context.col.ink2)),
                          ])),
                      const SizedBox(width: 10),
                      Builder(builder: (_) {
                        final iconPath = _paymentIconPath(m.id);
                        final fallback = iconPath != null
                            ? Image.asset(iconPath, fit: BoxFit.contain)
                            : Icon(Icons.credit_card_outlined,
                                size: 18, color: context.col.ink3);
                        return Container(
                          width: 40,
                          height: 40,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _softFill(context),
                            borderRadius: BorderRadius.circular(12),
                            border: isDark
                                ? Border.all(color: context.col.border)
                                : null,
                          ),
                          child: m.iconUrl != null
                              ? Image.network(m.iconUrl!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => fallback)
                              : fallback,
                        );
                      }),
                    ]),
                  ),
                )),
          ],

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => widget.onConfirm(
                  _useWallet, _walletAmountCtrl.text, _paymentMethod),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(context.tr('تأكيد', 'Confirm'),
                  style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontFamilyFallback: ['Tajawal'],
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Colors.white)),
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
  const _AddressSheet(
      {required this.addresses,
      required this.selected,
      required this.onSelect,
      required this.onAddNew});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        // Cap at 80% of the screen; the address list scrolls inside it.
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: context.col.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text(context.s.shippingAddr,
                style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontFamilyFallback: ['Tajawal'],
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Flexible(
                child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: addresses.map((addr) {
                final isSelected = selected?['id'] == addr['id'];
                return GestureDetector(
                  onTap: () => onSelect(addr),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _cardFill(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSelected
                              ? _selBorder(context)
                              : context.col.border,
                          width: isSelected ? 1.5 : 1),
                    ),
                    child: Row(children: [
                      _RadioDot(selected: isSelected),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                context.s.translateAddrLabel(
                                    addr['label'] as String? ?? ''),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(
                                [
                                  context.s.translateCity(
                                      addr['city']?.toString() ?? ''),
                                  addr['address']?.toString() ?? '',
                                  if ((addr['phone'] as String?)?.isNotEmpty ==
                                      true)
                                    _fmtPhone(addr['phone'].toString()),
                                ].where((v) => v.isNotEmpty).join('  ·  '),
                                style: TextStyle(
                                    fontSize: 12.5, color: context.col.ink2)),
                          ])),
                    ]),
                  ),
                );
              }).toList(),
            )),
            OutlinedButton.icon(
              onPressed: onAddNew,
              icon: const Icon(Icons.add, size: 16),
              label: Text(context.s.addNewAddress),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                side: BorderSide(color: context.col.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

// ── Trust badges row ──────────────────────────────────────────────────────────

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    final greyIcon = context.col.ink0;
    final greyBorder = context.col.ink2;
    final items = [
      (Icons.verified_outlined, context.s.trustAuthentic),
      (Icons.local_shipping_outlined, context.s.trustDelivery),
      (Icons.workspace_premium_outlined, context.s.trustWarranty),
      (Icons.replay_rounded, context.s.trustReturn),
    ];
    return Row(
      children: items
          .map((item) => Expanded(
                child: Column(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                      border: Border.all(color: greyBorder),
                    ),
                    child: Icon(item.$1, size: 17, color: greyIcon),
                  ),
                  const SizedBox(height: 6),
                  Text(item.$2,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          fontFamilyFallback: ['Tajawal'],
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: context.col.ink2)),
                ]),
              ))
          .toList(),
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
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: selected
            ? null
            : Border.all(color: context.col.borderStrong, width: 1.5),
        color: selected ? accent : Colors.transparent,
      ),
      child: selected
          ? Center(
              child: Container(
              width: 8,
              height: 8,
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
        width: size,
        height: size,
        color: context.col.surfaceSoft,
        child: Icon(Icons.image_not_supported_outlined,
            size: size * 0.36, color: context.col.ink3),
      );
}

Widget _SummaryRow(String label, String value,
        {Color? color, bool bold = false, required BuildContext ctx}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(value,
            style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color ?? ctx.col.ink0)),
      ]),
    );

// ── Collapsible section header ────────────────────────────────────────────────

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _QtyBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      // 40x40 hit area around the unchanged 28x28 visual.
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : context.col.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                size: 15,
                color: enabled ? AppColors.primary : context.col.ink4),
          ),
        ),
      ),
    );
  }
}
