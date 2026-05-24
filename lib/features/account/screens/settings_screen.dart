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
          _Section([
            _SettingsRow(
              icon: Icons.language_outlined,
              label: isAr ? 'اللغة' : 'Language',
              trailing: Text(isAr ? 'العربية' : 'English',
                style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
              onTap: () => ref.read(localeProvider.notifier).toggle(),
            ),
          ]),
          const SizedBox(height: 8),
          _Section([
            _SettingsRow(
              icon: Icons.notifications_outlined,
              label: isAr ? 'الإشعارات' : 'Notifications',
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.ink3),
              onTap: () => context.push('/notifications'),
            ),
          ]),
          const SizedBox(height: 8),
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
          Center(child: Text('baahy v1.0 · 2026',
            style: const TextStyle(fontSize: 11, color: AppColors.ink4))),
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
