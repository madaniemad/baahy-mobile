import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

/// Invitation for store owners to apply to sell on Baahy; opens the website's /sell page.
class SellOnBaahyBanner extends StatelessWidget {
  const SellOnBaahyBanner({super.key});

  static final _url = Uri.parse('https://baahy.com/sell');

  @override
  Widget build(BuildContext context) {
    const font =
        TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal']);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => launchUrl(_url, mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.teal600],
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront_outlined,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('تاجر أو عندك متجر؟ انضم معانا',
                        'A merchant or have a store? Join us'),
                    style: font.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.tr('عرض وإدارة وبيع منتجاتك أصبح أسهل مع باهي',
                        'Showing, managing and selling your products is easier with Baahy'),
                    style: font.copyWith(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.92)),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              context.tr('افتح متجرك الآن', 'Open your store now'),
              style: font.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.teal600),
            ),
          ),
        ]),
      ),
    );
  }
}
