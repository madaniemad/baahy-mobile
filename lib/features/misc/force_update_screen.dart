import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/l10n.dart';

/// Non-dismissible screen shown when the installed version is below the backend
/// `min_version`. The user cannot proceed until they update. Localized to the
/// app language (Arabic / English).
class ForceUpdateScreen extends ConsumerWidget {
  final String messageAr;
  final String messageEn;
  final String storeUrl;
  const ForceUpdateScreen({
    super.key,
    required this.messageAr,
    required this.messageEn,
    required this.storeUrl,
  });

  static const _teal = Color(0xFF3FD6E4); // brand tiffany

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = ref.watch(localeProvider).languageCode == 'ar';

    final title = isAr ? 'تحديث مطلوب' : 'Update Required';
    final button = isAr ? 'تحديث الآن' : 'Update Now';
    final msg = (isAr ? messageAr : messageEn).trim().isNotEmpty
        ? (isAr ? messageAr : messageEn)
        : (isAr
            ? 'يرجى تحديث التطبيق للحصول على أحدث المميزات والتحسينات.'
            : 'Please update the app to get the latest features and improvements.');

    return PopScope(
      canPop: false, // block back / swipe-dismiss
      child: Scaffold(
        backgroundColor: _teal,
        body: SafeArea(
          child: Directionality(
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // icon inside a white circle with a soft concentric glow
                  SizedBox(
                    width: 190,
                    height: 190,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _ring(190, 0.10),
                        _ring(158, 0.16),
                        Container(
                          width: 124,
                          height: 124,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.system_update, size: 58, color: _teal),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 42,
                    height: 3,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    msg,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 15, height: 1.55),
                  ),
                  const SizedBox(height: 34),
                  SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          // Fall back to the store listing directly if the backend
                          // sent an empty/invalid URL — the button must never fail.
                          var url = storeUrl.trim();
                          if (url.isEmpty || Uri.tryParse(url)?.hasScheme != true) {
                            url = Platform.isIOS
                                ? 'https://apps.apple.com/app/id1567889057'
                                : 'https://play.google.com/store/apps/details?id=com.baahy.baahyapp';
                          }
                          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(button,
                                  style: const TextStyle(color: _teal, fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(width: 10),
                              const Icon(Icons.arrow_forward, color: _teal, size: 20),
                            ],
                          ),
                        ),
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

  static Widget _ring(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
      );
}

const _forceTeal = Color(0xFF3FD6E4);

Widget _forceRing(double size, double alpha) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
    );

/// Non-dismissible force-update DIALOG shown OVER the home page (so the user
/// still sees the familiar app behind it, instead of a full-screen block).
/// Same design as [ForceUpdateScreen], sized as a card.
Future<void> showForceUpdateDialog(
  BuildContext context, {
  required bool isAr,
  required String messageAr,
  required String messageEn,
  required String storeUrl,
}) {
  final title  = isAr ? 'تحديث مطلوب' : 'Update Required';
  final button = isAr ? 'تحديث الآن' : 'Update Now';
  final msg = (isAr ? messageAr : messageEn).trim().isNotEmpty
      ? (isAr ? messageAr : messageEn)
      : (isAr
          ? 'يرجى تحديث التطبيق للحصول على أحدث المميزات والتحسينات.'
          : 'Please update the app to get the latest features and improvements.');

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => PopScope(
      canPop: false,
      child: Directionality(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        child: Dialog(
          backgroundColor: _forceTeal,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 132,
                  height: 132,
                  child: Stack(alignment: Alignment.center, children: [
                    _forceRing(132, 0.10),
                    _forceRing(108, 0.16),
                    Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.system_update, size: 40, color: _forceTeal),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(3))),
                const SizedBox(height: 14),
                Text(msg,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                        color: Colors.white.withValues(alpha: 0.92), fontSize: 14.5, height: 1.5)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () {
                        var url = storeUrl.trim();
                        if (url.isEmpty || Uri.tryParse(url)?.hasScheme != true) {
                          url = Platform.isIOS
                              ? 'https://apps.apple.com/app/id1567889057'
                              : 'https://play.google.com/store/apps/details?id=com.baahy.baahyapp';
                        }
                        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(button,
                                style: const TextStyle(color: _forceTeal, fontSize: 16, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 10),
                            const Icon(Icons.arrow_forward, color: _forceTeal, size: 20),
                          ],
                        ),
                      ),
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
