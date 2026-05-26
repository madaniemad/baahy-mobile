import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/app_config_provider.dart';
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
    final balance = user?.walletBalance ?? 0.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('محفظة باهي',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
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
                title: 'استرداد فوري',
                subtitle: 'مقابل 3-5 أيام للبطاقة',
              )),
              const SizedBox(width: 8),
              Expanded(child: _InfoTile(
                icon: Icons.auto_awesome_rounded,
                title: 'لا تنتهي صلاحيته',
                subtitle: 'استخدمه متى شئت',
              )),
            ]),
          ),

          // Transactions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('السجل',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    letterSpacing: 0.4, color: AppColors.ink1)),
              ),
              walletAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppColors.primary))),
                error: (_, __) => const SizedBox.shrink(),
                data: (data) {
                  final txns = (data['transactions'] as List?) ?? [];
                  if (txns.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(children: [
                          Icon(Icons.receipt_long_outlined, size: 60, color: AppColors.ink4),
                          const SizedBox(height: 12),
                          const Text('لا توجد معاملات',
                            style: TextStyle(fontSize: 15, color: AppColors.ink2)),
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
        gradient: const LinearGradient(
          colors: [AppColors.ink0, Color(0xFF1a3838)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        // Background glow
        Positioned(
          right: -40, top: -40,
          child: Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.18),
            ),
          ),
        ),
        Positioned(
          left: -30, bottom: -30,
          child: Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('الرصيد المتاح',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                letterSpacing: 1.2, color: Colors.white70)),
            const Icon(Icons.qr_code_2_rounded, color: Colors.white60, size: 20),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
            children: [
              Text(balance.toStringAsFixed(2),
                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                  fontSize: 42, fontWeight: FontWeight.w800, color: Colors.white,
                  letterSpacing: -1, height: 1)),
              const SizedBox(width: 8),
              const Text('د.ل',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                  color: Colors.white70)),
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
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_rounded, color: AppColors.ink0, size: 16),
                    SizedBox(width: 6),
                    Text('شحن',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                        fontSize: 13, color: AppColors.ink0)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.upload_outlined, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('إرسال',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                      fontSize: 13, color: Colors.white)),
                ]),
              ),
            ),
          ]),
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
        Icon(icon, size: 20, color: AppColors.teal600),
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
  int? _selected;
  int _paymentIdx = 0;
  bool _loading = false;
  String? _error;

  final _methods = [
    ('sadad', 'سداد'),
    ('mobicash', 'موبيكاش'),
  ];

  double get _amount => _selected?.toDouble() ?? 0;

  List<int> _buildAmounts(double minTopup) {
    final min = minTopup.toInt().clamp(1, 100);
    // Build 4 tiers: min, 2x, 4x, 10x (all >= min)
    final tiers = [min, min * 2, min * 4, min * 10];
    return tiers.toSet().toList()..sort();
  }

  Future<void> _topUp(double minTopup) async {
    if (_amount < minTopup) {
      setState(() => _error = 'أقل مبلغ للشحن هو ${minTopup.toStringAsFixed(0)} د.ل');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.dio.post('/wallet/topup', data: {
        'amount': _amount,
        'method': _methods[_paymentIdx].$1,
      });
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
      }
    } catch (_) {
      setState(() { _loading = false; _error = 'حدث خطأ، حاول مجدداً'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final minTopup = config.minWalletTopup;
    final quickAmounts = _buildAmounts(minTopup);
    _selected ??= quickAmounts.length >= 2 ? quickAmounts[1] : quickAmounts.first;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
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
          const Text('شحن المحفظة',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('ادفع مرة، استخدمه عبر الطلبات.',
            style: TextStyle(fontSize: 13, color: AppColors.ink2)),
          const SizedBox(height: 20),

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
                Text('${_selected ?? 0}',
                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                    fontSize: 42, fontWeight: FontWeight.w800, color: AppColors.ink0)),
                const SizedBox(width: 8),
                const Text('د.ل',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink2)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Quick amounts (dynamic from AppConfig.minWalletTopup)
          Row(children: quickAmounts.map((amt) {
            final isSelected = _selected == amt;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: amt != quickAmounts.last ? 6 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _selected = amt),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.ink0 : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.ink0 : AppColors.border, width: 1.5),
                    ),
                    child: Center(
                      child: Text('$amt',
                        style: TextStyle(fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w800, fontSize: 14,
                          color: isSelected ? Colors.white : AppColors.ink0)),
                    ),
                  ),
                ),
              ),
            );
          }).toList()),

          const SizedBox(height: 20),

          // Payment methods
          ...List.generate(_methods.length, (i) {
            final isSelected = _paymentIdx == i;
            return GestureDetector(
              onTap: () => setState(() => _paymentIdx = i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF5F5F5) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 1.5 : 1),
                ),
                child: Row(children: [
                  Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      border: isSelected ? null : Border.all(color: AppColors.borderStrong, width: 1.5),
                    ),
                    child: isSelected
                        ? const Icon(Icons.circle, size: 8, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(_methods[i].$2,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const Spacer(),
                  const Icon(Icons.credit_card_outlined, size: 18, color: AppColors.ink3),
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
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : () => _topUp(minTopup),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink0))
                  : Text(
                      _amount > 0 ? 'شحن ${_amount.toStringAsFixed(0)} د.ل' : 'شحن المحفظة',
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
          '${isCredit ? '+' : ''}${amount.toStringAsFixed(0)} د.ل',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800, fontSize: 14,
            color: isCredit ? AppColors.success : AppColors.ink0)),
      ]),
    );
  }
}
