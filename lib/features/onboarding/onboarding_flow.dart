import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onb_city_picker.dart';

/// Onboarding is one setup screen (language + delivery city), then home —
/// Noon/Amazon style, decided 2026-10-23. The four promo slides (delivery,
/// payments, rewards, coupon) were removed; the first-order offer now lives in
/// the home coupon strip, which guests see too. Notification permission is asked
/// at first sign-in, not here.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});
  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  bool _finishing = false;

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
    body: OnbCityPicker(onContinue: _finish),
  );
}
