import 'package:flutter/services.dart';

/// Centralised haptic patterns.
///
/// The iOS Taptic Engine only exposes short, discrete pulses (a single
/// `HapticFeedback.*Impact()` is ~10-20ms — that's the "very short" buzz).
/// To make feedback feel stronger/longer we sequence several pulses into a
/// recognisable rhythm. Use these instead of calling `HapticFeedback` directly
/// so success/error feel consistent across the app.
class Haptics {
  /// Celebratory burst — order placed, wallet recharged, payment done.
  /// Leads with the strongest system buzz (`vibrate`) then a decaying tail of
  /// impacts, giving a distinctly longer, unmissable "done!" feel (~0.8s).
  static Future<void> success() async {
    await HapticFeedback.vibrate();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.mediumImpact();
  }

  /// Sharp warning double pulse — payment failed / validation error.
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 130));
    await HapticFeedback.heavyImpact();
  }

  /// Single firm tap — confirmations, primary button presses.
  static Future<void> tap() => HapticFeedback.mediumImpact();

  /// Light selection tick — chips, toggles, steppers.
  static Future<void> select() => HapticFeedback.selectionClick();
}
