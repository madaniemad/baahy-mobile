import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart' show Share;
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

class QrProfileScreen extends ConsumerWidget {
  const QrProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final username = user?.username ?? '';

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
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppShadows.shadowCard,
                  ),
                  child: QrImageView(
                    data: 'baahy://user/$username',
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
                  onPressed: () => Share.share('أضفني على تطبيق باهي: baahy://user/$username'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
