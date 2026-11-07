import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/push_notification_service.dart';
import '../../core/utils/l10n.dart';
import '../../shared/widgets/nav_icons.dart';
import 'onb_theme.dart';

/// Onboarding's last step (Emad, 2026-10-31): why notifications matter, and one button.
/// «متابعة» opens the phone's own permission dialog — the only thing that can turn
/// notifications on — and then goes home whatever she chose. No skip and no "allow"
/// wording: Apple rejects a custom "Allow" before the system dialog, and blocking on a
/// refusal.
class OnbNotifications extends ConsumerStatefulWidget {
  final VoidCallback onContinue;
  const OnbNotifications({super.key, required this.onContinue});

  @override
  ConsumerState<OnbNotifications> createState() => _OnbNotificationsState();
}

const _ink = Color(0xFF14181A);
const _muted = Color(0xFF6B7578);
const _teal = Color(0xFF1FD7E2);
const _bell = Color(0xFFD0D5D7);            // very light grey list icons (Emad, 2026-11-01)

class _OnbNotificationsState extends ConsumerState<OnbNotifications> {
  bool _busy = false;

  Future<void> _continue() async {
    if (_busy) return;                       // a double tap must not ask twice
    setState(() => _busy = true);
    try { await PushNotificationService.instance.requestPermissionIfNeeded(); } catch (_) {}
    if (mounted) widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = ref.watch(localeProvider).languageCode == 'ar';
    String tr(String ar, String en) => isAr ? ar : en;
    final botPad = MediaQuery.of(context).padding.bottom;
    final topPad = MediaQuery.of(context).padding.top;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: ColoredBox(
        color: Colors.white,
        child: Stack(children: [
          // Same faded brand pattern as the setup screen before it.
          Positioned(top: 0, left: 0, right: 0, height: topPad + 150,
            child: IgnorePointer(child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Color(0x00FFFFFF)], stops: [0.0, 0.45, 1.0],
              ).createShader(r),
              child: Opacity(opacity: 0.30, child: Image.asset('assets/images/onb-pattern.png',
                  fit: BoxFit.cover, alignment: Alignment.topCenter, color: _teal, colorBlendMode: BlendMode.srcIn)),
            )),
          ),
          SafeArea(bottom: false, child: Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, botPad + 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: SingleChildScrollView(child: Column(children: [
                const SizedBox(height: 150),
                // Centred tiffany bell; the list icons stay very light grey (Emad, 2026-11-01).
                // Thin stroke: the variable Material Symbols bell at weight 200.
                const Icon(NavIcons.notifications_active, color: _teal, size: 68, weight: 200),
                const SizedBox(height: 20),
                Text(tr('ابقَ على اطّلاع أولاً بأول', 'Stay up to date'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback,
                      fontSize: 24, fontWeight: FontWeight.w700, color: _ink, height: 1.3)),
                const SizedBox(height: 10),
                Text(tr('فعّل الإشعارات لنبلغك بكل جديد.',
                        'Turn on notifications and we\'ll keep you posted.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback,
                      fontSize: 15.5, fontWeight: FontWeight.w500, color: _muted, height: 1.5)),
                const SizedBox(height: 32),
                // A plain list, not cards, centred as one block under the title so the icons
                // still line up (Emad, 2026-11-01).
                IntrinsicWidth(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _Point(icon: Icons.inventory_2_outlined,
                      text: tr('تأكيد طلبك وكل تحديث على حالته', 'Your order confirmed, and every update on it')),
                  _Point(icon: Icons.local_shipping_outlined,
                      text: tr('عندما يكون طلبك في الطريق إليك', 'When your order is on its way to you')),
                  // Each point is a notification the server really sends (returns/refund, wallet
                  // credit templates; cart_low_stock and favourite_vendor_* rules), 2026-11-01.
                  _Point(icon: Icons.assignment_return_outlined,
                      text: tr('تحديثات الإرجاع والمبالغ المستردة', 'Return updates and refunds')),
                  _Point(icon: Icons.account_balance_wallet_outlined,
                      text: tr('الكاش باك والمكافآت التي تُضاف إلى محفظتك', 'Cashback and rewards added to your wallet')),
                  _Point(icon: Icons.shopping_cart_outlined,
                      text: tr('عندما يوشك منتج في سلتك على النفاد', 'When an item in your cart is about to sell out')),
                  _Point(icon: Icons.storefront_outlined,
                      text: tr('الجديد والعروض من متاجرك المفضلة', 'New arrivals and sales from your favourite stores')),
                  _Point(icon: Icons.local_offer_outlined,
                      text: tr('العروض والتخفيضات التي تهمّك', 'Offers and discounts that matter to you')),
                ])),
              ]))),
              GestureDetector(
                onTap: _continue,
                child: Container(
                  height: 56, width: double.infinity, alignment: Alignment.center,
                  decoration: BoxDecoration(color: _teal, borderRadius: BorderRadius.circular(12)),
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                      : Text(tr('متابعة', 'Continue'), style: const TextStyle(fontFamily: Onb.font,
                          fontFamilyFallback: Onb.fontFallback, fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ]),
          )),
        ]),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Point({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(children: [
      Icon(icon, color: _bell, size: 24),
      const SizedBox(width: 14),
      Expanded(child: Text(text, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback,
          fontSize: 15.5, fontWeight: FontWeight.w500, color: _ink, height: 1.4))),
    ]),
  );
}
