import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

/// Centre pop-up on checkout when notifications are off (Emad, 2026-11-08: "like the force
/// update"). Same frosted look. Once per app session, so going back and forth to checkout does
/// not nag.
///
/// Two shapes, because Apple reviews pre-permission screens (5.1.1):
/// - the phone can still show its own question → ONE button «متابعة» that asks it. No "Allow"
///   wording and no way out before the system dialog (onboarding follows the same rule).
/// - the customer already refused → only Settings can turn them on: «فتح الإعدادات» + «ليس الآن».
bool _shownThisSession = false;

Future<void> maybeShowCheckoutNotificationsPrompt(BuildContext context) async {
  if (_shownThisSession) return;
  final push = PushNotificationService.instance;
  if (await push.notificationsEnabled()) return;
  final canAsk = await push.canStillAsk();
  if (!context.mounted || _shownThisSession) return;
  _shownThisSession = true;

  await showDialog<void>(
    context: context,
    barrierDismissible: !canAsk,
    barrierColor: Colors.transparent, // the blur layer below is the scrim
    useSafeArea: false,
    builder: (ctx) => PopScope(
      canPop: !canAsk,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: canAsk ? null : () => Navigator.of(ctx).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: (ctx.isDark ? Colors.black : Colors.blueGrey.shade900)
                      .withValues(alpha: ctx.isDark ? 0.45 : 0.22),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: _PromptCard(canAsk: canAsk),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PromptCard extends StatelessWidget {
  final bool canAsk;
  const _PromptCard({required this.canAsk});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final col = context.col;
    const font = 'Manrope';
    const fallback = ['Tajawal'];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: (context.isDark ? Colors.black : Colors.white)
                  .withValues(alpha: context.isDark ? 0.35 : 0.42),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: context.isDark ? 0.18 : 0.55)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.14), shape: BoxShape.circle),
                    child: const Icon(Icons.notifications_active_outlined, size: 26, color: AppColors.teal700),
                  ),
                  const SizedBox(height: 14),
                  Text(s.notifPopTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: font, fontFamilyFallback: fallback, color: col.ink0,
                          fontSize: 21, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Text(s.notifPopBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: font, fontFamilyFallback: fallback, color: col.ink2,
                          fontSize: 15, height: 1.55)),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await PushNotificationService.instance.enableFromReminder();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: Text(canAsk ? s.notifPopContinue : s.notifPopSettings,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontFamily: font, fontFamilyFallback: fallback,
                                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
                  if (!canAsk)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(s.notifPopNotNow,
                          style: TextStyle(fontFamily: font, fontFamilyFallback: fallback, color: col.ink2,
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    )
                  else
                    const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
