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
    final scale = MediaQuery.textScalerOf(context).scale(1.0);

    final icon = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child:
          const Icon(Icons.storefront_outlined, color: Colors.white, size: 24),
    );

    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('تاجر أو عندك متجر؟', 'A merchant or have a store?'),
          style: font.copyWith(
              fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 2),
        Text(
          context.tr('عرض وإدارة وبيع منتجاتك أصبح أسهل مع باهي',
              'Showing, managing and selling your products is easier with Baahy'),
          style: font.copyWith(
              fontSize: 12,
              height: 1.3,
              color: Colors.white.withValues(alpha: 0.9)),
        ),
      ],
    );

    Widget button({required bool wide}) => Container(
          width: wide ? double.infinity : null,
          alignment: wide ? Alignment.center : null,
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: wide ? 11 : 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE14D),
            borderRadius: BorderRadius.circular(wide ? 12 : 20),
          ),
          child: Text(
            context.tr('افتح متجرك الآن', 'Open your store now'),
            style: font.copyWith(
                fontSize: wide ? 14 : 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.black),
          ),
        );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => launchUrl(_url, mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.primary,
        ),
        child: LayoutBuilder(builder: (context, c) {
          // Side by side only when the text keeps a readable width; otherwise the button drops
          // below (320-360pt phones, English, or large text sizes).
          final stacked = c.maxWidth < (context.isAr ? 310 : 350) || scale > 1.15;
          if (stacked) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: texts),
                  ]),
                  const SizedBox(height: 12),
                  button(wide: true),
                ]);
          }
          return Row(children: [
            icon,
            const SizedBox(width: 12),
            Expanded(child: texts),
            const SizedBox(width: 8),
            button(wide: false),
          ]);
        }),
      ),
    );
  }
}
