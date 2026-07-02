import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/app_pages_provider.dart';
import '../../../core/utils/l10n.dart';
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

  Future<void> _openPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
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
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 17)),
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
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: context.col.ink0)),
              const SizedBox(height: 6),
              Text(context.s.supportAvailable,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: context.col.ink2, height: 1.5)),
            ]),
          ),

          // ── Contact cards ──────────────────────────────────────────────────
          Text(isAr ? 'تواصل معنا عبر' : 'Reach us via',
              style: TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                  fontSize: 13, color: context.col.ink3)),
          const SizedBox(height: 10),

          if (pages.contactWhatsapp.isNotEmpty) ...[
            _ContactCard(
              icon: Icons.chat_rounded,
              color: const Color(0xFF25D366),
              bgColor: const Color(0xFFECFDF5),
              darkBgColor: const Color(0xFF0F2A1F),
              label: context.s.whatsappLabel,
              subtitle: isAr ? 'دردشة فورية · الأسرع' : 'Instant chat · Fastest',
              value: pages.contactWhatsapp,
              onTap: () => _openWhatsapp(pages.contactWhatsapp),
            ),
            const SizedBox(height: 10),
          ],

          if (pages.contactEmail.isNotEmpty) ...[
            _ContactCard(
              icon: Icons.email_rounded,
              color: const Color(0xFF6366F1),
              bgColor: const Color(0xFFEEF2FF),
              darkBgColor: const Color(0xFF16142A),
              label: context.s.emailLabel,
              subtitle: isAr ? 'رد خلال 24 ساعة' : 'Reply within 24h',
              value: pages.contactEmail,
              onTap: () => _openEmail(pages.contactEmail),
            ),
            const SizedBox(height: 10),
          ],

          // ── Hours ─────────────────────────────────────────────────────────
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.col.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.col.border),
            ),
            child: Row(children: [
              Icon(Icons.access_time_rounded, size: 16, color: context.col.ink3),
              const SizedBox(width: 8),
              Text(isAr ? 'الدعم متاح 7 أيام في الأسبوع' : 'Support available 7 days a week',
                  style: TextStyle(fontSize: 12.5, color: context.col.ink2, fontFamily: 'Cairo')),
            ]),
          ),

          // ── Order complaint tip ───────────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 17),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.s.orderComplaintTip,
                  style: TextStyle(fontSize: 12, color: context.col.ink1, height: 1.5),
                ),
              ),
            ]),
          ),
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
  final String value;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.darkBgColor,
    required this.label,
    required this.subtitle,
    required this.value,
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
                  fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                  fontSize: 14, color: context.col.ink0)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(
                  fontSize: 11.5, color: context.col.ink3)),
              const SizedBox(height: 3),
              Text(value,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 12.5,
                  color: color, fontWeight: FontWeight.w600)),
            ],
          )),
          Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: context.col.ink4),
        ]),
      ),
    );
  }
}
