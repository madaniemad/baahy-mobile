import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baahy_customer/features/auth/screens/otp_screen.dart';
import 'package:baahy_customer/features/auth/screens/phone_signin_screen.dart';
import 'package:baahy_customer/shared/theme/app_theme.dart';

/// Guards the class of bug that shipped in phone_signin_screen: layouts that
/// only break when a keyboard is present.
///
/// The iOS Simulator has its software keyboard OFF by default (it uses the
/// Mac's hardware keyboard), so `viewInsets.bottom` is always 0 there — these
/// bugs are invisible in normal development and only appear on a real device.
/// Here we simulate the keyboard by setting viewInsets.bottom, at the SMALLEST
/// supported phone size (iPhone SE) — the worst case.
void main() {
  const seSize = Size(320, 568); // iPhone SE — tightest screen we support
  const keyboardInset = 291.0; // its numeric keypad height

  Widget harness(Widget child) => ProviderScope(
        child: MaterialApp(
          // context.col does Theme.of(context).extension<BaahyColors>()! —
          // without the real theme that null-asserts before any layout happens.
          theme: buildAppTheme(),
          locale: const Locale('ar'),
          home: MediaQuery(
            data: const MediaQueryData(
              size: seSize,
              viewInsets: EdgeInsets.only(bottom: keyboardInset),
            ),
            child: child,
          ),
        ),
      );

  Future<void> expectNoOverflow(WidgetTester tester, Widget screen, String name) async {
    await tester.binding.setSurfaceSize(seSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(harness(screen));
    await tester.pump();

    final err = tester.takeException();
    expect(err, isNull,
        reason: '$name threw/overflowed with the keyboard open on iPhone SE: $err');
  }

  testWidgets('OtpScreen survives the keyboard on the smallest phone',
      (t) => expectNoOverflow(t, const OtpScreen(phone: '0910000000'), 'OtpScreen'));

  testWidgets('PhoneSignInScreen survives the keyboard on the smallest phone',
      (t) => expectNoOverflow(t, const PhoneSignInScreen(), 'PhoneSignInScreen'));
}
