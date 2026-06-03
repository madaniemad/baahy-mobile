import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

final _walletProvider = FutureProvider<List<dynamic>>((ref) async {
  final res = await ApiClient.instance.dio.get('/wallet/transactions');
  return (res.data['data'] as List?) ?? [];
});

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final walletAsync = ref.watch(_walletProvider);
    final balance = user?.walletBalance ?? 0.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: Text(context.s.baahyWallet,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink0)),
      ),
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _BalanceCard(
              balance: balance,
              onTopUp: () => _showTopUpSheet(context, ref),
            ),
          ),

          // Quick info
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              Expanded(child: _InfoTile(
                icon: Icons.refresh_rounded,
                title: context.isAr ? 'استرداد فوري' : 'Instant Refund',
                subtitle: context.isAr ? 'مقابل 3-5 أيام للبطاقة' : 'vs 3-5 days for card',
              )),
              const SizedBox(width: 8),
              Expanded(child: _InfoTile(
                icon: Icons.auto_awesome_rounded,
                title: context.isAr ? 'لا تنتهي صلاحيته' : 'Never Expires',
                subtitle: context.isAr ? 'استخدمه متى شئت' : 'Use it whenever you want',
              )),
            ]),
          ),

          // Transactions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(context.s.walletHistory,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    letterSpacing: 0.4, color: AppColors.ink1)),
              ),
              walletAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppColors.primary))),
                error: (_, __) => const SizedBox.shrink(),
                data: (txns) {
                  if (txns.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(children: [
                          Icon(Icons.receipt_long_outlined, size: 60, color: AppColors.ink4),
                          const SizedBox(height: 12),
                          Text(context.s.noTransactions,
                            style: const TextStyle(fontSize: 15, color: AppColors.ink2)),
                        ]),
                      ),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: List.generate(txns.length, (i) =>
                        _TransactionRow(
                          tx: Map<String, dynamic>.from(txns[i]),
                          hasBorder: i < txns.length - 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _showTopUpSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TopUpSheet(onSuccess: () {
        ref.invalidate(_walletProvider);
        ref.read(authProvider.notifier).refreshProfile();
      }),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double balance;
  final VoidCallback onTopUp;
  const _BalanceCard({required this.balance, required this.onTopUp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(context.s.availableBalance,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
              letterSpacing: 0.4, color: AppColors.ink2)),
          const Icon(Icons.qr_code_2_rounded, color: AppColors.ink3, size: 20),
        ]),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
          children: [
            Text(balance.toStringAsFixed(2),
              style: const TextStyle(fontFamily: 'PlusJakartaSans',
                fontSize: 42, fontWeight: FontWeight.w800, color: AppColors.ink0,
                letterSpacing: -1, height: 1)),
            const SizedBox(width: 8),
            Text(context.s.lydUnit,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                color: AppColors.ink2)),
          ],
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: onTopUp,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.ink0,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(context.s.topUpWallet,
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                      fontSize: 13, color: Colors.white)),
                  const SizedBox(width: 6),
                  const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.upload_outlined, color: AppColors.ink2, size: 16),
                const SizedBox(width: 6),
                Text(context.s.sendMoney,
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                    fontSize: 13, color: AppColors.ink1)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoTile({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(title,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(subtitle,
          style: const TextStyle(fontSize: 11.5, color: AppColors.ink2, height: 1.4)),
      ]),
    );
  }
}

// ── Top-up sheet ──────────────────────────────────────────────────────────────

class _TopUpSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const _TopUpSheet({required this.onSuccess});

  @override
  ConsumerState<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends ConsumerState<_TopUpSheet> {
  // Step 0: amount + method selection
  // Step 1: Mobicash card number
  // Step 2: Mobicash OTP
  int _step = 0;
  int? _selected = 100;
  String _paymentId = 'mobicash';
  bool _loading = false;
  String? _error;
  final _customCtrl = TextEditingController();
  final _cardCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  String? _mobicashReference;
  String? _mitfTransactionId;

  static const _quickAmounts = [100, 200, 500, 1000];

  static const _methods = [
    (id: 'mobicash', label: 'موبيكاش', desc: 'ادفع بكارت موبيكاش'),
    (id: 'tadawel',  label: 'تداول',   desc: 'دفع إلكتروني عبر تداول'),
    (id: 'moamlat', label: 'معاملات', desc: 'دفع إلكتروني عبر معاملات'),
  ];

  double get _amount {
    final custom = double.tryParse(_customCtrl.text.trim());
    if (custom != null && custom > 0) return custom;
    return _selected?.toDouble() ?? 0;
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    _cardCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _proceed(double minTopup) async {
    if (_step == 0) {
      if (_amount < minTopup) {
        setState(() => _error = 'أقل مبلغ للشحن هو ${fmtPrice(minTopup)} د.ل');
        return;
      }
      if (_paymentId == 'mobicash') {
        setState(() { _step = 1; _error = null; });
      } else {
        await _initiateGateway();
      }
    } else if (_step == 1) {
      await _mobicashOpen();
    } else if (_step == 2) {
      await _mobicashComplete();
    }
  }

  Future<void> _initiateGateway() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.dio.post('/wallet/topup/initiate', data: {
        'amount': _amount,
        'gateway': _paymentId,
      });
      final url = res.data['payment_url'] as String?;
      if (url != null && url.isNotEmpty) {
        if (mounted) Navigator.of(context).pop();
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        setState(() { _loading = false; _error = 'لم يتم الحصول على رابط الدفع'; });
      }
    } catch (_) {
      setState(() { _loading = false; _error = 'حدث خطأ، حاول مجدداً'; });
    }
  }

  Future<void> _mobicashOpen() async {
    if (_cardCtrl.text.trim().isEmpty) {
      setState(() => _error = 'يرجى إدخال رقم البطاقة');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.dio.post('/wallet/topup/mobicash/open', data: {
        'amount': _amount,
        'card_number': _cardCtrl.text.trim(),
      });
      _mobicashReference = res.data['reference'] as String?;
      _mitfTransactionId = res.data['mitf_transaction_id']?.toString();
      setState(() { _loading = false; _step = 2; });
    } catch (_) {
      setState(() { _loading = false; _error = 'البطاقة غير صحيحة أو الخدمة غير متاحة'; });
    }
  }

  Future<void> _mobicashComplete() async {
    if (_otpCtrl.text.trim().isEmpty) {
      setState(() => _error = 'يرجى إدخال رمز OTP');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.dio.post('/wallet/topup/mobicash/complete', data: {
        'reference': _mobicashReference,
        'card_number': _cardCtrl.text.trim(),
        'otp': _otpCtrl.text.trim(),
        'mitf_transaction_id': _mitfTransactionId ?? '',
      });
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
      }
    } catch (_) {
      setState(() { _loading = false; _error = 'رمز OTP غير صحيح، حاول مجدداً'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final minTopup = config.minWalletTopup;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          // Header with back button on steps 1+
          Row(children: [
            if (_step > 0)
              GestureDetector(
                onTap: () => setState(() { _step--; _error = null; }),
                child: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(Icons.arrow_back, size: 20, color: AppColors.ink0)),
              ),
            Expanded(
              child: Text(
                _step == 0 ? 'شحن المحفظة'
                    : _step == 1 ? 'رقم بطاقة موبيكاش'
                    : 'رمز التحقق OTP',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            _step == 0 ? 'ادفع مرة، استخدمه عبر الطلبات.'
                : _step == 1 ? 'أدخل رقم البطاقة لإرسال رمز OTP'
                : 'تم إرسال رمز OTP إلى بطاقتك',
            style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
          const SizedBox(height: 20),

          // ── Step 0: amount + method ─────────────────────────────────────────
          if (_step == 0) ...[
            // Amount display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(_amount > 0 ? fmtPrice(_amount) : '0',
                    style: const TextStyle(fontFamily: 'PlusJakartaSans',
                      fontSize: 42, fontWeight: FontWeight.w800, color: AppColors.ink0)),
                  const SizedBox(width: 8),
                  Text(context.s.lydUnit,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink2)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Quick amounts
            Row(children: _quickAmounts.asMap().entries.map((e) {
              final i = e.key; final amt = e.value;
              final isSelected = _customCtrl.text.trim().isEmpty && _selected == amt;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i < _quickAmounts.length - 1 ? 6 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() { _selected = amt; _customCtrl.clear(); }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.ink0 : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.ink0 : AppColors.border, width: 1.5)),
                      child: Center(child: Text('$amt',
                        style: TextStyle(fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w800, fontSize: 14,
                          color: isSelected ? Colors.white : AppColors.ink0))),
                    ),
                  ),
                ),
              );
            }).toList()),
            const SizedBox(height: 10),

            // Custom amount
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _customCtrl.text.trim().isNotEmpty ? AppColors.primary : AppColors.border,
                  width: _customCtrl.text.trim().isNotEmpty ? 1.5 : 1)),
              child: TextField(
                controller: _customCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() => _selected = null),
                decoration: const InputDecoration(
                  hintText: 'أو أدخل مبلغاً آخر',
                  hintStyle: TextStyle(fontSize: 13, color: AppColors.ink3),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  suffixText: 'د.ل',
                  suffixStyle: TextStyle(fontSize: 13, color: AppColors.ink2, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Payment methods
            ..._methods.map((m) {
              final isSelected = _paymentId == m.id;
              return GestureDetector(
                onTap: () => setState(() => _paymentId = m.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF5F5F5) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 1.5 : 1)),
                  child: Row(children: [
                    Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        border: isSelected ? null : Border.all(color: AppColors.borderStrong, width: 1.5)),
                      child: isSelected
                          ? const Icon(Icons.circle, size: 8, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.label,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(m.desc,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.ink2)),
                    ])),
                    Icon(
                      m.id == 'mobicash' ? Icons.credit_card_outlined : Icons.language_rounded,
                      size: 18, color: AppColors.ink3),
                  ]),
                ),
              );
            }),
          ],

          // ── Step 1: Mobicash card number ────────────────────────────────────
          if (_step == 1) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border)),
              child: TextField(
                controller: _cardCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'رقم بطاقة موبيكاش',
                  hintStyle: TextStyle(fontSize: 14, color: AppColors.ink3),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(14),
                  prefixIcon: Icon(Icons.credit_card_outlined, size: 18, color: AppColors.ink3),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(context.isAr ? 'المبلغ: ${fmtPrice(_amount)} د.ل' : 'Amount: ${fmtPrice(_amount)} LYD',
              style: const TextStyle(fontSize: 12.5, color: AppColors.ink2)),
          ],

          // ── Step 2: Mobicash OTP ────────────────────────────────────────────
          if (_step == 2) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border)),
              child: TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: 'أدخل رمز OTP',
                  hintStyle: TextStyle(fontSize: 14, color: AppColors.ink3),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(14),
                ),
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : () => _proceed(minTopup),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink0))
                  : Text(
                      _step == 0
                          ? (_amount > 0 ? 'متابعة · ${fmtPrice(_amount)} د.ل' : 'متابعة')
                          : _step == 1 ? 'إرسال OTP'
                          : 'تأكيد الشحن',
                      style: const TextStyle(fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink0)),
            ),
          ),
        ],
      ),
    )); // GestureDetector + Container
  }
}

// ── Transaction row ───────────────────────────────────────────────────────────

class _TransactionRow extends StatelessWidget {
  final Map<String, dynamic> tx;
  final bool hasBorder;
  const _TransactionRow({required this.tx, required this.hasBorder});

  @override
  Widget build(BuildContext context) {
    final rawAmt = tx['amount'];
    final amount = rawAmt is num ? rawAmt.toDouble() : double.tryParse(rawAmt?.toString() ?? '') ?? 0.0;
    final isCredit = tx['type'] == 'credit' || amount > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: hasBorder
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCredit
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.surfaceSoft,
          ),
          child: Icon(
            isCredit ? Icons.add_rounded : Icons.remove_rounded,
            color: isCredit ? AppColors.success : AppColors.ink2, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx['description'] ?? (isCredit ? 'إيداع' : 'سحب'),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.3)),
            if (tx['created_at'] != null)
              Text(
                () {
                  final dt = DateTime.tryParse(tx['created_at']);
                  return dt != null ? '${dt.day}/${dt.month}/${dt.year}' : '';
                }(),
                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                  fontSize: 11, color: AppColors.ink3),
              ),
          ]),
        ),
        Text(
          '${isCredit ? '+' : ''}${fmtPrice(amount)} د.ل',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800, fontSize: 14,
            color: isCredit ? AppColors.success : AppColors.ink0)),
      ]),
    );
  }
}
