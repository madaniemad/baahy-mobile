import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/navigation.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back, color: context.col.ink0),
        ),
        title: Text(isAr ? 'الإعدادات' : 'Settings',
          style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w800, fontSize: 18)),
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
              trailing: Icon(Icons.arrow_forward_ios, size: 14, color: context.col.ink3),
              onTap: () => safePush(context, '/city'),
            ),
            _SettingsRow(
              icon: Icons.language_outlined,
              label: isAr ? 'اللغة' : 'Language',
              trailing: Text(isAr ? 'العربية' : 'English',
                style: TextStyle(fontSize: 13, color: context.col.ink2)),
              onTap: () {
                final msg = isAr ? 'Language changed to English' : 'تم التغيير إلى العربية';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(msg, style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'])),
                  duration: const Duration(seconds: 2),
                ));
                ref.read(localeProvider.notifier).toggle();
              },
            ),
            _SettingsRow(
              icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              label: isAr ? 'المظهر' : 'Appearance',
              trailing: Text(
                isDark ? (isAr ? 'داكن' : 'Dark') : (isAr ? 'فاتح' : 'Light'),
                style: TextStyle(fontSize: 13, color: context.col.ink2),
              ),
              onTap: () => ref.read(themeModeProvider.notifier).toggle(),
            ),
            _SettingsRow(
              icon: Icons.notifications_outlined,
              label: isAr ? 'الإشعارات' : 'Notifications',
              trailing: Icon(Icons.arrow_forward_ios, size: 14, color: context.col.ink3),
              onTap: () => safePush(context, '/notifications'),
            ),
          ]),
          const SizedBox(height: 12),

          // Support
          _Section([
            _SettingsRow(
              icon: Icons.help_outline_rounded,
              label: isAr ? 'الأسئلة الشائعة' : 'FAQ',
              trailing: Icon(Icons.arrow_forward_ios, size: 14, color: context.col.ink3),
              onTap: () => safePush(context, '/faq'),
            ),
            _SettingsRow(
              icon: Icons.support_agent_outlined,
              label: isAr ? 'تواصل مع الدعم' : 'Contact Support',
              trailing: Icon(Icons.arrow_forward_ios, size: 14, color: context.col.ink3),
              onTap: () => safePush(context, '/contact'),
            ),
          ]),
          const SizedBox(height: 12),

          // Legal
          _Section([
            _SettingsRow(
              icon: Icons.shield_outlined,
              label: isAr ? 'سياسة الخصوصية' : 'Privacy Policy',
              trailing: Icon(Icons.arrow_forward_ios, size: 14, color: context.col.ink3),
              onTap: () => safePush(context, '/privacy'),
            ),
            _SettingsRow(
              icon: Icons.description_outlined,
              label: isAr ? 'الشروط والأحكام' : 'Terms of Service',
              trailing: Icon(Icons.arrow_forward_ios, size: 14, color: context.col.ink3),
              onTap: () => safePush(context, '/terms'),
            ),
            _SettingsRow(
              icon: Icons.assignment_return_outlined,
              label: isAr ? 'سياسة الإرجاع' : 'Return Policy',
              trailing: Icon(Icons.arrow_forward_ios, size: 14, color: context.col.ink3),
              onTap: () => safePush(context, '/return-policy'),
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
            _SettingsRow(
              icon: Icons.delete_forever_outlined,
              label: context.s.deleteAccount,
              accent: true,
              trailing: const SizedBox.shrink(),
              onTap: () => _confirmDeleteAccount(context, ref),
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

Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final s = context.s;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: dialogCtx.col.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(s.deleteAccountTitle,
        style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
          fontWeight: FontWeight.w800, fontSize: 17)),
      content: Text(s.deleteAccountBody,
        style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
          fontSize: 13.5, height: 1.5, color: dialogCtx.col.ink1)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: Text(s.deleteAccountCancel,
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
              fontWeight: FontWeight.w600, color: dialogCtx.col.ink1)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          child: Text(s.deleteAccountConfirm,
            style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
              fontWeight: FontWeight.w800, color: AppColors.danger)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  // Blocking progress while the server deletes the account.
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
  );

  try {
    await ref.read(authProvider.notifier).deleteAccount();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss progress
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(s.deleteAccountDone,
        style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'])),
    ));
    context.go('/signin');
  } catch (e, st) {
    Sentry.captureException(e, stackTrace: st);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss progress
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(s.deleteAccountFailed,
        style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'])),
      backgroundColor: AppColors.danger,
    ));
  }
}

class _Section extends StatelessWidget {
  final List<Widget> children;
  const _Section(this.children);
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.col.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.col.border),
    ),
    child: Column(children: [
      for (var i = 0; i < children.length; i++) ...[
        children[i],
        if (i < children.length - 1)
          Divider(height: 1, indent: 48, endIndent: 0, color: context.col.border),
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
        Icon(icon, size: 20, color: accent ? AppColors.danger : context.col.ink1),
        const SizedBox(width: 12),
        Expanded(child: Text(label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
            color: accent ? AppColors.danger : context.col.ink0))),
        trailing,
      ]),
    ),
  );
}

class _AppVersionBadge extends StatelessWidget {
  const _AppVersionBadge();
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      Image.asset(
        isDark ? 'assets/images/logo_white.png' : 'assets/images/logo.png',
        height: 56,
        errorBuilder: (_, __, ___) => const Text('baahy', style: TextStyle(
          fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
      ),
      const SizedBox(height: 6),
      Text(context.s.versionN('1.0.0'),
        style: TextStyle(fontSize: 11, color: context.col.ink4)),
      const SizedBox(height: 2),
      Text('© 2026 Baahy. All rights reserved.',
        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, color: context.col.ink4)),
    ]);
  }
}
