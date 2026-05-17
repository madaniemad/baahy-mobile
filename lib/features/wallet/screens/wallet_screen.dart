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
            // Balance card
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
}

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
              color: (isCredit ? AppColors.success : AppColors.danger).withOpacity(0.1),
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
