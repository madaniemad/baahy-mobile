import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart' show Share;
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

class QrProfileScreen extends ConsumerStatefulWidget {
  const QrProfileScreen({super.key});

  @override
  ConsumerState<QrProfileScreen> createState() => _QrProfileScreenState();
}

class _QrProfileScreenState extends ConsumerState<QrProfileScreen> {
  Future<void> _share(String username, int reward) async {
    final link = 'https://baahy.com/u/$username?reward=$reward';
    final text = 'أضفني على تطبيق باهي 👋\nستحصل على $reward د.ل عند إتمام أول طلب 🎁\n$link';
    try {
      await Share.share(text);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم نسخ الرابط', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final username = user?.username ?? '';
    final reward = ref.watch(appConfigProvider).referralGiverAmount.toInt();

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface,
        elevation: 0,
        title: Text(context.tr('كود QR الخاص بي', 'My QR Code'),
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.col.ink0),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (username.isEmpty) ...[
                Icon(Icons.qr_code_outlined, size: 80, color: context.col.ink3),
                const SizedBox(height: 16),
                Text(
                  context.tr('أنت بحاجة إلى اسم مستخدم أولاً', 'You need a username first'),
                  style: TextStyle(fontFamily: 'Cairo', color: context.col.ink2, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.push('/username-setup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: Text(context.tr('اختر اسم مستخدم', 'Set Username'),
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.col.border),
                    boxShadow: AppShadows.shadowLifted,
                  ),
                  child: QrImageView(
                    data: 'https://baahy.com/u/$username?reward=$reward',
                    version: QrVersions.auto,
                    size: 220,
                  ),
                ),
                const SizedBox(height: 24),
                Text('@$username',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w800, color: context.col.ink0)),
                const SizedBox(height: 8),
                Text(
                  context.tr('اسمح لأصدقائك بمسح هذا الكود لإضافتك', 'Let friends scan this to add you'),
                  style: TextStyle(fontSize: 13, color: context.col.ink3, fontFamily: 'Cairo'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.share_outlined),
                  label: Text(context.tr('مشاركة', 'Share'),
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                  onPressed: () => _share(username, reward),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
