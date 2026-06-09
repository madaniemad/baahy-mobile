import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_pages_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

final _icons = <IconData>[
  Icons.assignment_return_outlined,
  Icons.checklist_outlined,
  Icons.account_balance_wallet_outlined,
  Icons.support_agent_outlined,
  Icons.info_outline,
  Icons.verified_outlined,
];

class ReturnPolicyScreen extends ConsumerWidget {
  const ReturnPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = context.isAr;
    final pages = ref.watch(appPagesProvider);
    final sections = pages.returnSections;
    final hasData = sections.isNotEmpty;

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back, color: context.col.ink0),
        ),
        title: Text(
          isAr ? 'الإرجاعات والاسترداد' : 'Returns & Refunds',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (hasData) ...[
            ...sections.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              final title = isAr
                  ? (s['title_ar'] ?? s['title'] ?? '')
                  : (s['title_en']?.isNotEmpty == true ? s['title_en']! : (s['title_ar'] ?? s['title'] ?? ''));
              final body = isAr
                  ? (s['body_ar'] ?? s['body'] ?? '')
                  : (s['body_en']?.isNotEmpty == true ? s['body_en']! : (s['body_ar'] ?? s['body'] ?? ''));
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PolicyCard(
                  icon: _icons[i % _icons.length],
                  title: title,
                  body: body,
                ),
              );
            }),
          ] else ...[
            _PolicyCard(
              icon: Icons.assignment_return_outlined,
              title: isAr ? 'سياسة الإرجاع' : 'Return Policy',
              body: isAr
                  ? 'يمكنك إرجاع المنتجات خلال 7 أيام من تاريخ الاستلام، بشرط أن تكون في حالتها الأصلية وغير مستخدمة.'
                  : 'You may return products within 7 days of delivery, provided they are in their original unused condition.',
            ),
            const SizedBox(height: 12),
            _PolicyCard(
              icon: Icons.checklist_outlined,
              title: isAr ? 'شروط الإرجاع' : 'Conditions',
              body: isAr
                  ? '• المنتج في حالته الأصلية مع التغليف\n• لم يتم استخدام المنتج\n• يُستثنى من الإرجاع: المستلزمات الشخصية والعطور بعد فتحها'
                  : '• Product in original packaging\n• Product unused\n• Exceptions: personal care items and opened perfumes',
            ),
            const SizedBox(height: 12),
            _PolicyCard(
              icon: Icons.account_balance_wallet_outlined,
              title: isAr ? 'طريقة الاسترداد' : 'Refund Method',
              body: isAr
                  ? 'يتم رد المبلغ إلى محفظتك في التطبيق خلال 3–5 أيام عمل بعد استلام المنتج والتحقق منه.'
                  : 'The amount is refunded to your in-app wallet within 3–5 business days after receiving and inspecting the product.',
            ),
            const SizedBox(height: 12),
            _PolicyCard(
              icon: Icons.support_agent_outlined,
              title: isAr ? 'كيفية طلب الإرجاع' : 'How to Request',
              body: isAr
                  ? 'افتح الطلب من صفحة "طلباتي" ثم اضغط على "طلب إرجاع". سيتواصل معك فريقنا لتنسيق الاستلام.'
                  : 'Open the order from "My Orders" and tap "Request Return". Our team will contact you to arrange pickup.',
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.shopping_bag_outlined, size: 18),
            label: Text(
              isAr ? 'عرض طلباتي' : 'View My Orders',
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 15),
            ),
            onPressed: () => safePush(context, '/orders'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _PolicyCard({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.col.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.col.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 6),
              Text(body, style: TextStyle(
                fontSize: 13, color: context.col.ink2, height: 1.6)),
            ],
          ),
        ),
      ],
    ),
  );
}
