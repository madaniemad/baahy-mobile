import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/theme/app_theme.dart';

/// Non-dismissible screen shown when the installed version is below the backend
/// `min_version`. The user cannot proceed until they update.
class ForceUpdateScreen extends StatelessWidget {
  final String message;
  final String storeUrl;
  const ForceUpdateScreen({super.key, required this.message, required this.storeUrl});

  @override
  Widget build(BuildContext context) {
    final msg = message.trim().isNotEmpty
        ? message
        : 'يجب تحديث التطبيق للمتابعة. الإصدار الحالي لم يعد مدعوماً.';

    return PopScope(
      canPop: false, // block back / swipe-dismiss
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.system_update, size: 84, color: Colors.white),
                  const SizedBox(height: 24),
                  const Text(
                    'تحديث مطلوب',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    msg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        final url = storeUrl.trim();
                        if (url.isNotEmpty) {
                          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        }
                      },
                      child: const Text(
                        'تحديث الآن',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
