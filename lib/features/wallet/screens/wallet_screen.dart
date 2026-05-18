import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/theme/app_theme.dart';

final _walletProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ApiClient.instance.dio.get('/wallet');
  return Map<String, dynamic>.from(res.data['data']);
});

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final walletAsync = ref.watch(_walletProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('المحفظة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink0)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Balance card with top-up button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF2BB8BD)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الرصيد المتاح',
                    style: TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    '${(user?.walletBalance ?? 0).toStringAsFixed(2)} د.ل',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => _showTopUpSheet(context, ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text('شحن الرصيد',
                            style: TextStyle(color: Colors.white, fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Transactions
            walletAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, __) => const SizedBox.shrink(),
              data: (data) {
                final transactions = (data['transactions'] as List?) ?? [];
                if (transactions.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 60, color: AppColors.ink4),
                        SizedBox(height: 12),
                        Text('لا توجد معاملات',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 15, color: AppColors.ink2)),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('المعاملات',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    ...transactions.map((t) => _TransactionRow(tx: Map<String, dynamic>.from(t))),
                  ],
                );
              },
            ),
          ],
        ),
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

// ── Top-up sheet ──────────────────────────────────────────────────────────────

class _TopUpSheet extends StatefulWidget {
  final VoidCallback onSuccess;
  const _TopUpSheet({required this.onSuccess});

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  static const _quickAmounts = [25, 50, 100, 200];
  int? _selected;
  final _customCtrl = TextEditingController();
  int _paymentMethod = 0; // 0=COD/cash, 1=sadad, 2=mobicash
  bool _loading = false;
  String? _error;

  double get _amount {
    if (_selected != null) return _selected!.toDouble();
    return double.tryParse(_customCtrl.text) ?? 0;
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _topUp() async {
    if (_amount < 5) {
      setState(() => _error = 'أقل مبلغ للشحن هو 5 د.ل');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.dio.post('/wallet/topup', data: {
        'amount': _amount,
        'method': ['cash', 'sadad', 'mobicash'][_paymentMethod],
      });
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم طلب الشحن بنجاح'),
            backgroundColor: AppColors.success,
          ));
      }
    } catch (_) {
      setState(() { _loading = false; _error = 'حدث خطأ، حاول مجدداً'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 18),
          const Text('شحن الرصيد',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),

          // Quick amounts
          const Text('اختر المبلغ',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink1)),
          const SizedBox(height: 10),
          Row(children: _quickAmounts.map((amt) {
            final isSelected = _selected == amt;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: amt != _quickAmounts.last ? 8 : 0),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selected = amt;
                    _customCtrl.clear();
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.ink0 : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.ink0 : AppColors.border,
                        width: 1.5),
                    ),
                    child: Center(
                      child: Text('$amt',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w800, fontSize: 15,
                          color: isSelected ? Colors.white : AppColors.ink0)),
                    ),
                  ),
                ),
              ),
            );
          }).toList()),

          const SizedBox(height: 14),

          // Custom amount
          TextField(
            controller: _customCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() => _selected = null),
            decoration: InputDecoration(
              hintText: 'مبلغ مخصص',
              hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.ink3),
              suffixText: 'د.ل',
              suffixStyle: const TextStyle(fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w700, color: AppColors.ink2),
              filled: true, fillColor: AppColors.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),

          const SizedBox(height: 20),

          // Payment method
          const Text('طريقة الدفع',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink1)),
          const SizedBox(height: 10),
          ...List.generate(3, (i) {
            final labels = ['نقدي / عند الاستلام', 'سداد', 'موبيكاش'];
            final icons = [Icons.money_outlined, Icons.credit_card_outlined, Icons.phone_android_outlined];
            return GestureDetector(
              onTap: () => setState(() => _paymentMethod = i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _paymentMethod == i
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _paymentMethod == i ? AppColors.primary : AppColors.border,
                    width: _paymentMethod == i ? 2 : 1),
                ),
                child: Row(children: [
                  Icon(icons[i], size: 20,
                    color: _paymentMethod == i ? AppColors.primary : AppColors.ink2),
                  const SizedBox(width: 12),
                  Text(labels[i],
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600,
                      color: _paymentMethod == i ? AppColors.ink0 : AppColors.ink1)),
                  const Spacer(),
                  if (_paymentMethod == i)
                    const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primary),
                ]),
              ),
            );
          }),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _topUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      _amount > 0
                        ? 'شحن ${_amount.toStringAsFixed(0)} د.ل'
                        : 'شحن الرصيد',
                      style: const TextStyle(fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink0)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transaction row ───────────────────────────────────────────────────────────

class _TransactionRow extends StatelessWidget {
  final Map<String, dynamic> tx;
  const _TransactionRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
    final isCredit = tx['type'] == 'credit' || amount > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.shadowCard,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isCredit ? AppColors.success : AppColors.danger).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.add_rounded : Icons.remove_rounded,
              color: isCredit ? AppColors.success : AppColors.danger, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx['description'] ?? (isCredit ? 'إيداع' : 'سحب'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (tx['created_at'] != null)
                  Text(
                    () {
                      final dt = DateTime.tryParse(tx['created_at']);
                      return dt != null ? '${dt.day}/${dt.month}/${dt.year}' : '';
                    }(),
                    style: const TextStyle(fontFamily: 'PlusJakartaSans',
                      fontSize: 11, color: AppColors.ink3),
                  ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}${amount.abs().toStringAsFixed(2)} د.ل',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w800, fontSize: 14,
              color: isCredit ? AppColors.success : AppColors.danger),
          ),
        ],
      ),
    );
  }
}
