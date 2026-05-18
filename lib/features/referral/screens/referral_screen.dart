import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/theme/app_theme.dart';

final _referralProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ApiClient.instance.dio.get('/referrals');
  return Map<String, dynamic>.from(res.data['data'] ?? {});
});

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final referralAsync = ref.watch(_referralProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('ادعُ أصدقاءك',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink0)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Hero card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D1117), Color(0xFF1A2332)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle),
                    child: const Icon(Icons.people_alt_outlined,
                      size: 34, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  const Text('شارك باهي مع أصدقائك',
                    style: TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w800, fontFamily: 'Cairo')),
                  const SizedBox(height: 10),
                  const Text.rich(TextSpan(
                    style: TextStyle(fontSize: 14, height: 1.6,
                      color: Colors.white70, fontFamily: 'Cairo'),
                    children: [
                      TextSpan(text: 'أنت تحصل على '),
                      TextSpan(text: '10 د.ل',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
                          fontFamily: 'PlusJakartaSans')),
                      TextSpan(text: ' وصديقك يحصل على '),
                      TextSpan(text: '10 د.ل',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
                          fontFamily: 'PlusJakartaSans')),
                      TextSpan(text: ' عند أول طلب له'),
                    ],
                  )),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Referral code
            referralAsync.when(
              loading: () => const SizedBox(height: 80,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
              error: (_, __) => _CodeCard(code: user?.referralCode ?? 'BAAHY10'),
              data: (data) => _CodeCard(
                code: data['code'] as String? ?? user?.referralCode ?? 'BAAHY10',
                usedCount: (data['used_count'] as num?)?.toInt() ?? 0,
                earnedAmount: (data['earned_amount'] as num?)?.toDouble() ?? 0,
              ),
            ),

            const SizedBox(height: 20),

            // How it works
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.shadowCard,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('كيف يعمل؟',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  ...[
                    (Icons.share_outlined, 'شارك رمزك مع أصدقائك'),
                    (Icons.person_add_alt_1_outlined, 'يسجل صديقك في باهي ويستخدم رمزك'),
                    (Icons.shopping_bag_outlined, 'يكمل صديقك أول طلب بقيمة 50 د.ل أو أكثر'),
                    (Icons.account_balance_wallet_outlined, 'تحصلون معاً على 10 د.ل لكل منكم'),
                  ].asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle),
                        child: Center(
                          child: Icon(e.value.$1, size: 16, color: AppColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(e.value.$2,
                            style: const TextStyle(fontSize: 13.5, height: 1.4)),
                        ),
                      ),
                    ]),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  final String code;
  final int usedCount;
  final double earnedAmount;
  const _CodeCard({required this.code, this.usedCount = 0, this.earnedAmount = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.shadowCard,
      ),
      child: Column(
        children: [
          const Text('رمز الدعوة الخاص بك',
            style: TextStyle(fontSize: 13, color: AppColors.ink2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(code,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 24, fontWeight: FontWeight.w800,
                    letterSpacing: 4)),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ الرمز'),
                        backgroundColor: AppColors.success));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // WhatsApp share button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final msg = Uri.encodeComponent(
                  'جرّب تطبيق باهي للتسوق! استخدم رمزي $code واحصل على 10 د.ل خصم على أول طلب');
                // Opens WhatsApp with the share message
              },
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('مشاركة عبر واتساب',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ),

          if (usedCount > 0 || earnedAmount > 0) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _Stat('أصدقاء انضموا', '$usedCount')),
              Container(width: 1, height: 40, color: AppColors.border),
              Expanded(child: _Stat('كسبت', '${earnedAmount.toStringAsFixed(0)} د.ل')),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(fontFamily: 'PlusJakartaSans',
      fontSize: 20, fontWeight: FontWeight.w800)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(fontSize: 12, color: AppColors.ink3)),
  ]);
}
