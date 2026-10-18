import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/app_pages_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

class ContactScreen extends ConsumerWidget {
  const ContactScreen({super.key});

  Future<void> _openWhatsapp(String number) async {
    final clean = number.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pages = ref.watch(appPagesProvider);
    final isAr = context.isAr;

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: context.col.ink0),
        ),
        title: Text(context.s.contactUs,
            style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          // ── Hero ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.support_agent_rounded,
                    size: 36, color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              Text(context.s.hereToHelp,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: context.col.ink0)),
              const SizedBox(height: 6),
              Text(context.s.supportAvailable,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: context.col.ink2, height: 1.5)),
            ]),
          ),

          // ── Self-service first (Emad, 2026-10-18) ─────────────────────────
          // Order problems are filed on the order itself, then the assistant; WhatsApp and
          // email come last, as buttons only — the number is never printed.
          _ContactCard(
            icon: Icons.receipt_long_rounded,
            color: AppColors.primary,
            bgColor: AppColors.primary.withValues(alpha: 0.10),
            darkBgColor: AppColors.primary.withValues(alpha: 0.18),
            label: isAr ? 'مشكلة في طلب؟' : 'A problem with an order?',
            subtitle: isAr
                ? 'افتح الطلب واضغط «تحتاج مساعدة؟» لتبلغنا أو تطلب تغييراً، ويصلك الرد في التطبيق'
                : 'Open the order and tap "Need help?" to report a problem or ask for a change — we answer in the app',
            onTap: () => safePush(context, '/orders'),
          ),
          const SizedBox(height: 10),
          _ContactCard(
            icon: Icons.auto_awesome_rounded,
            color: const Color(0xFF0EA5B7),
            bgColor: const Color(0xFFE6FBFC),
            darkBgColor: const Color(0xFF0E2427),
            label: isAr ? 'اسأل المساعد' : 'Ask the assistant',
            subtitle: isAr ? 'إجابات فورية عن طلباتك والتوصيل والإرجاع' : 'Instant answers about orders, delivery and returns',
            onTap: () => safePush(context, '/chat'),
          ),
          const SizedBox(height: 10),
          _ContactCard(
            icon: Icons.help_outline_rounded,
            color: const Color(0xFF6366F1),
            bgColor: const Color(0xFFEEF2FF),
            darkBgColor: const Color(0xFF16142A),
            label: isAr ? 'الأسئلة الشائعة' : 'FAQ',
            subtitle: isAr ? 'الدفع والشحن والإرجاع والمكافآت' : 'Payment, shipping, returns and rewards',
            onTap: () => safePush(context, '/faq'),
          ),

          // ── Last resort ───────────────────────────────────────────────────
          if (pages.contactWhatsapp.isNotEmpty || pages.contactEmail.isNotEmpty) ...[
            const SizedBox(height: 26),
            Text(isAr ? 'ما زلت تحتاج مساعدة؟' : 'Still need help?',
                style: TextStyle(
                    fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w700,
                    fontSize: 13, color: context.col.ink3)),
            const SizedBox(height: 10),
            Row(children: [
              if (pages.contactWhatsapp.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openWhatsapp(pages.contactWhatsapp),
                    icon: const Icon(Icons.chat_rounded, size: 18, color: Color(0xFF25D366)),
                    label: Text(context.s.whatsappLabel,
                        style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                            fontWeight: FontWeight.w700, color: context.col.ink0)),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: context.col.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              if (pages.contactWhatsapp.isNotEmpty && pages.contactEmail.isNotEmpty) const SizedBox(width: 10),
              if (pages.contactEmail.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openEmail(pages.contactEmail),
                    icon: const Icon(Icons.email_rounded, size: 18, color: Color(0xFF6366F1)),
                    label: Text(context.s.emailLabel,
                        style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                            fontWeight: FontWeight.w700, color: context.col.ink0)),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: context.col.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color darkBgColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.darkBgColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: context.col.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.col.border),
          boxShadow: AppShadows.shadowLifted,
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: isDark ? darkBgColor : bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(
                  fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w700,
                  fontSize: 14, color: context.col.ink0)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(
                  fontSize: 11.5, height: 1.4, color: context.col.ink3)),
            ],
          )),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.col.ink4),
        ]),
      ),
    );
  }
}
