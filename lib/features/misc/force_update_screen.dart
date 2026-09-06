import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/l10n.dart';

/// Brand accent. It is the button and the icon only — never the backdrop. A
/// full-bleed tiffany panel reads as a branded interstitial; the update block
/// should read as the app quietly asking for something.
const _accent = Color(0xFF3FD6E4);

const _kTitleAr = 'تحديث مطلوب';
const _kTitleEn = 'Update Required';
const _kButtonAr = 'تحديث الآن';
const _kButtonEn = 'Update Now';
const _kFallbackAr = 'يرجى تحديث التطبيق للحصول على أحدث المميزات والتحسينات.';
const _kFallbackEn = 'Please update the app to get the latest features and improvements.';

String _resolveMessage(bool isAr, String ar, String en) {
  final picked = isAr ? ar : en;
  if (picked.trim().isNotEmpty) return picked;
  return isAr ? _kFallbackAr : _kFallbackEn;
}

/// The store listing, guaranteed. The backend supplies the URL, but the button
/// must never dead-end if that setting is empty or malformed.
void _openStore(String storeUrl) {
  var url = storeUrl.trim();
  if (url.isEmpty || Uri.tryParse(url)?.hasScheme != true) {
    url = Platform.isIOS
        ? 'https://apps.apple.com/app/id1567889057'
        : 'https://play.google.com/store/apps/details?id=com.baahy.baahyapp';
  }
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// The frosted card both entry points share: a translucent surface over a real
/// backdrop blur, so whatever sits behind stays faintly readable and the panel
/// looks like glass rather than a coloured sheet.
class _UpdateCard extends StatelessWidget {
  final bool isAr;
  final String message;
  final String storeUrl;
  const _UpdateCard({required this.isAr, required this.message, required this.storeUrl});

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    final title = isAr ? _kTitleAr : _kTitleEn;
    final button = isAr ? _kButtonAr : _kButtonEn;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                // Translucent so the blur reads as glass; opaque enough that the
                // text keeps its contrast over any page behind it.
                color: col.surface.withValues(alpha: context.isDark ? 0.82 : 0.86),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: col.border.withValues(alpha: 0.6)),
              ),
              padding: const EdgeInsets.fromLTRB(26, 30, 26, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.system_update_rounded, size: 30, color: _accent),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontFamilyFallback: const ['Tajawal'],
                      color: col.ink0,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontFamilyFallback: const ['Tajawal'],
                      color: col.ink2,
                      fontSize: 14.5,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: _accent,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => _openStore(storeUrl),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: Text(
                            button,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontFamilyFallback: ['Tajawal'],
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
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
}

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = ref.watch(localeProvider).languageCode == 'ar';

    return PopScope(
      canPop: false, // block back / swipe-dismiss
      child: Scaffold(
        backgroundColor: context.col.bg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _UpdateCard(
                isAr: isAr,
                message: _resolveMessage(isAr, messageAr, messageEn),
                storeUrl: storeUrl,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Non-dismissible force-update DIALOG shown OVER the home page (so the user
/// still sees the familiar app behind it, instead of a full-screen block).
///
/// The whole page behind is blurred, not just the card, so the app is visibly
/// still there but plainly out of reach.
Future<void> showForceUpdateDialog(
  BuildContext context, {
  required bool isAr,
  required String messageAr,
  required String messageEn,
  required String storeUrl,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent, // the blur layer below is the scrim
    builder: (ctx) => PopScope(
      canPop: false,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: (ctx.isDark ? Colors.black : Colors.blueGrey.shade900)
                    .withValues(alpha: ctx.isDark ? 0.45 : 0.22),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: _UpdateCard(
                isAr: isAr,
                message: _resolveMessage(isAr, messageAr, messageEn),
                storeUrl: storeUrl,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
