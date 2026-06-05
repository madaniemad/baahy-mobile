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

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back, color: context.col.ink0),
        ),
        title: Text(context.s.contactUs,
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.col.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.col.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.s.hereToHelp,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Text(context.s.supportAvailable,
                    style: TextStyle(fontSize: 13, color: context.col.ink2)),
                const SizedBox(height: 20),
                if (pages.contactWhatsapp.isNotEmpty)
                  _ContactRow(
                    icon: Icons.chat_rounded,
                    color: const Color(0xFF25D366),
                    label: context.s.whatsappLabel,
                    subtitle: pages.contactWhatsapp,
                    onTap: () => _openWhatsapp(pages.contactWhatsapp),
                  ),
                if (pages.contactPhone.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ContactRow(
                    icon: Icons.phone_outlined,
                    color: AppColors.primary,
                    label: context.s.phoneLabel,
                    subtitle: pages.contactPhone,
                    onTap: () => _openPhone(pages.contactPhone),
                  ),
                ],
                if (pages.contactEmail.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ContactRow(
                    icon: Icons.email_outlined,
                    color: context.col.ink1,
                    label: context.s.emailLabel,
                    subtitle: pages.contactEmail,
                    onTap: () => _openEmail(pages.contactEmail),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.s.orderComplaintTip,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.primary, height: 1.5),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13.5)),
            Text(subtitle, style: TextStyle(
                fontFamily: 'PlusJakartaSans', fontSize: 12.5, color: context.col.ink2)),
          ],
        )),
        Icon(Icons.arrow_forward_ios, size: 14, color: context.col.ink3),
      ]),
    );
  }
}
