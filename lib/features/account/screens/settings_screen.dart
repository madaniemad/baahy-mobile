import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink0),
        ),
        title: Text(isAr ? 'الإعدادات' : 'Settings',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Preferences
          _Section([
            _SettingsRow(
              icon: Icons.location_city_outlined,
              label: isAr ? 'تغيير المدينة' : 'Change City',
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.ink3),
              onTap: () => context.push('/city'),
            ),
            _SettingsRow(
              icon: Icons.language_outlined,
              label: isAr ? 'اللغة' : 'Language',
              trailing: Text(isAr ? 'العربية' : 'English',
                style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
              onTap: () {
                final msg = isAr ? 'Language changed to English' : 'تم التغيير إلى العربية';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
                  duration: const Duration(seconds: 2),
                ));
                ref.read(localeProvider.notifier).toggle();
              },
            ),
            _SettingsRow(
              icon: Icons.notifications_outlined,
              label: isAr ? 'الإشعارات' : 'Notifications',
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.ink3),
              onTap: () => context.push('/notifications'),
            ),
          ]),
          const SizedBox(height: 12),

          // Support
          _Section([
            _SettingsRow(
              icon: Icons.help_outline_rounded,
              label: isAr ? 'الأسئلة الشائعة' : 'FAQ',
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.ink3),
              onTap: () => context.push('/faq'),
            ),
            _SettingsRow(
              icon: Icons.support_agent_outlined,
              label: isAr ? 'تواصل مع الدعم' : 'Contact Support',
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.ink3),
              onTap: () => context.push('/contact'),
            ),
          ]),
          const SizedBox(height: 12),

          // Legal
          _Section([
            _SettingsRow(
              icon: Icons.shield_outlined,
              label: isAr ? 'سياسة الخصوصية' : 'Privacy Policy',
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.ink3),
              onTap: () => context.push('/privacy'),
            ),
            _SettingsRow(
              icon: Icons.description_outlined,
              label: isAr ? 'الشروط والأحكام' : 'Terms of Service',
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.ink3),
              onTap: () => context.push('/terms'),
            ),
            _SettingsRow(
              icon: Icons.assignment_return_outlined,
              label: isAr ? 'سياسة الإرجاع' : 'Return Policy',
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.ink3),
              onTap: () => context.push('/return-policy'),
            ),
          ]),
          const SizedBox(height: 12),

          // Danger zone
          _Section([
            _SettingsRow(
              icon: Icons.logout_rounded,
              label: isAr ? 'تسجيل الخروج' : 'Sign out',
              accent: true,
              trailing: const SizedBox.shrink(),
              onTap: () => ref.read(authProvider.notifier).logout(),
            ),
          ]),

          const SizedBox(height: 24),
          Center(child: _AppVersionBadge()),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final List<Widget> children;
  const _Section(this.children);
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(children: [
      for (var i = 0; i < children.length; i++) ...[
        children[i],
        if (i < children.length - 1)
          const Divider(height: 1, indent: 48, endIndent: 0, color: AppColors.border),
      ],
    ]),
  );
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback onTap;
  final bool accent;
  const _SettingsRow({
    required this.icon, required this.label,
    required this.trailing, required this.onTap, this.accent = false,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, size: 20, color: accent ? AppColors.danger : AppColors.ink1),
        const SizedBox(width: 12),
        Expanded(child: Text(label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
            color: accent ? AppColors.danger : AppColors.ink0))),
        trailing,
      ]),
    ),
  );
}

class _AppVersionBadge extends StatelessWidget {
  const _AppVersionBadge();
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Image.asset('assets/images/logo.png', height: 28, errorBuilder: (_, __, ___) =>
        const Text('baahy', style: TextStyle(fontFamily: 'Cairo',
          fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary))),
      const SizedBox(height: 6),
      Text(context.s.versionN('1.0.0'),
        style: const TextStyle(fontSize: 11, color: AppColors.ink4)),
      const SizedBox(height: 2),
      const Text('© 2026 Baahy. All rights reserved.',
        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, color: AppColors.ink4)),
    ]);
  }
}
