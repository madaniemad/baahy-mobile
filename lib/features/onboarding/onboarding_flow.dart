import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/push_notification_service.dart';
import 'onb_city_picker.dart';
import 'onb_notifications.dart';

/// Onboarding is one setup screen (language + delivery city), then home —
/// Noon/Amazon style, decided 2026-10-23. The four promo slides (delivery,
/// payments, rewards, coupon) were removed; the first-order offer now lives in
/// the home coupon strip, which guests see too.
///
/// Then the notifications step (Emad, 2026-10-31): every new customer sees the phone's
/// permission dialog — guests too, who were never asked when it waited for sign-in.
/// One «متابعة» button opens the dialog and moves on whatever she answers (Apple
/// rejects an app that blocks on it). Shown only while the phone can still ask.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});
  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  bool _finishing = false;
  bool _askNotifications = false;
  bool _onNotifications = false;

  @override
  void initState() {
    super.initState();
    PushNotificationService.instance.canStillAsk().then((v) {
      if (mounted && v) setState(() => _askNotifications = true);
    });
  }

  Future<void> _finish() async {
    if (_finishing) return;                    // a double tap must not navigate twice
    _finishing = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_v2_done', true);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _onNotifications
          ? OnbNotifications(key: const ValueKey('notif'), onContinue: _finish)
          : OnbCityPicker(
              key: const ValueKey('city'),
              hasNext: _askNotifications,
              // Asked again on the tap: the check started in initState may not have answered yet (audit 2026-10-31).
              onContinue: () async {
                final ask = _askNotifications || await PushNotificationService.instance.canStillAsk();
                if (!mounted) return;
                ask ? setState(() => _onNotifications = true) : _finish();
              },
            ),
    ),
  );
}
