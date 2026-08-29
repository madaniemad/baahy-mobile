import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/deep_link_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  final String? referralCode;
  /// Where the code was actually sent — 'whatsapp' or 'sms'. The backend tells
  /// us; without showing it, users sat waiting for an SMS that never comes
  /// (iOS cannot autofill a WhatsApp code, so they must fetch it themselves).
  final String channel;
  const OtpScreen({required this.phone, this.referralCode,
    this.channel = 'whatsapp', super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _loading = false;
  bool _hasError = false;
  int _seconds = 45;
  Timer? _timer;
  bool _resending = false;
  String? _resendError;

  String get _code => _ctrl.text;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _ctrl.addListener(_onCodeChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _onCodeChange() {
    if (_hasError) setState(() => _hasError = false);
    setState(() {});
    if (_ctrl.text.length == 6) _verify();
  }

  void _startTimer() {
    // setState, not a bare assignment: without it the countdown that replaces the resend
    // link only appeared on the first tick a second later, and every tap in that window
    // cancelled the timer and restarted it — so tapping fast kept the link on screen
    // indefinitely and fired one request per tap.
    if (mounted) { setState(() => _seconds = 45); } else { _seconds = 45; }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_seconds > 0) {
        setState(() => _seconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  /// Resend a code. Was fire-and-forget with no in-flight guard: one user put 16
  /// requests through in 10 seconds this way and spent their whole hourly OTP budget
  /// on codes they never saw, then met a rate limit for the rest of the hour.
  Future<void> _resend() async {
    if (_resending || _seconds > 0) return;
    setState(() { _resending = true; _resendError = null; });
    try {
      await ref.read(authProvider.notifier).requestOtp(widget.phone);
      _startTimer();
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      String msg = context.s.errorTryAgain;
      if (e is DioException) {
        final d = e.response?.data;
        if (d is Map && d['message'] != null) msg = d['message'].toString();
      }
      if (mounted) setState(() => _resendError = msg);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.removeListener(_onCodeChange);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.length < 6) return;
    setState(() { _loading = true; _hasError = false; });
    try {
      final isNewUser = await ref.read(authProvider.notifier).verifyOtp(
        widget.phone, _code, referralCode: widget.referralCode);
      if (isNewUser) Analytics.instance.signUp();
      await DeepLinkService.consumePendingCode(); // clear after successful signup
      // New accounts have no name (phone-OTP signup) — collect it before continuing.
      if (mounted && isNewUser) await _askFullName();
      // Ask for notification permission at first sign-in (moved here from onboarding
      // so first-time users aren't interrupted mid-onboarding). Awaited so the OS
      // dialog shows on this screen; never block sign-in if it throws.
      try { await PushNotificationService.instance.requestPermissionIfNeeded(); } catch (_) {}
      if (mounted) context.go('/home');
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      HapticFeedback.mediumImpact();
      setState(() { _hasError = true; _loading = false; });
      _ctrl.clear();
      _focus.requestFocus();
    }
  }

  /// Required full-name prompt for brand-new accounts (phone-OTP signup leaves
  /// the name as a "User" placeholder). Non-dismissible so every new account
  /// gets a real name; a failed save still lets the user through.
  Future<void> _askFullName() async {
    final nameCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setLocal) {
          final canSave = nameCtrl.text.trim().length >= 2;
          return AlertDialog(
            backgroundColor: context.col.surface,
            title: Text(context.tr('ما اسمك الكامل؟', "What's your full name?"),
              style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                fontWeight: FontWeight.w800, color: context.col.ink0)),
            content: TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setLocal(() {}),
              onSubmitted: (_) { if (canSave) _submitName(dialogCtx, nameCtrl.text.trim()); },
              decoration: InputDecoration(hintText: context.tr('الاسم الكامل', 'Full name')),
            ),
            actions: [
              TextButton(
                onPressed: canSave ? () => _submitName(dialogCtx, nameCtrl.text.trim()) : null,
                child: Text(context.tr('متابعة', 'Continue')),
              ),
            ],
          );
        },
      ),
    );
    nameCtrl.dispose();
  }

  Future<void> _submitName(BuildContext dialogCtx, String name) async {
    try { await ref.read(authProvider.notifier).updateProfileName(name); } catch (_) {}
    if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
  }

  /// Width of one OTP box.
  ///
  /// 6 x 46 = 276, but an iPhone SE only offers 320 - 24 - 24 = 272 of content
  /// width — a 4px RenderFlex overflow. Cap to what actually fits; this stays
  /// at 46 on every other phone.
  double _otpBoxWidth(BuildContext context) {
    const gap = 6.0, maxBox = 46.0, hPadding = 48.0;
    final avail = MediaQuery.sizeOf(context).width - hPadding;
    return ((avail - gap * 5) / 6).clamp(24.0, maxBox);
  }

  @override
  Widget build(BuildContext context) {
    final code = _ctrl.text;
    return Scaffold(
      backgroundColor: context.col.surface,
      appBar: AppBar(
        backgroundColor: context.col.surface, elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back, color: context.col.ink0)),
      ),
      // NOTE: don't use a LayoutBuilder for the OTP box width — the body below
      // is wrapped in IntrinsicHeight (so Spacer() still works inside the
      // scroll view), and IntrinsicHeight cannot measure through a LayoutBuilder.
      // The keyboard is ALWAYS open on this screen, and the body is a Column
      // with a Spacer(). Once Scaffold shrinks the body by the keyboard height
      // the Spacer collapses to zero and the Column overflows (proven on
      // iPhone SE by test/keyboard_overflow_test.dart). Making the body scroll
      // while still filling the viewport keeps the Spacer layout when there is
      // room, and scrolls instead of overflowing when there isn't.
      body: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: ConstrainedBox(
            // minus the vertical padding above (8 + 24)
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: IntrinsicHeight(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.verified_user_outlined,
              color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 24),
          Text(context.s.confirmNumber,
            style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
              fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          const SizedBox(height: 8),
          // Phone number wrapped in LTR so +218... displays left-to-right
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.s.codeSentTo,
              style: TextStyle(fontSize: 14.5, color: context.col.ink2, height: 1.5)),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(widget.phone,
                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w700, fontSize: 15,
                  color: AppColors.primary))),
            const SizedBox(height: 10),
            // Say WHERE the code went. iOS cannot autofill a WhatsApp code (it
            // only reads SMS), so without this people sit waiting for an SMS
            // that is never coming.
            _ChannelChip(channel: widget.channel),
          ]),
          const SizedBox(height: 32),

          // Hidden single field + 6 visual boxes
          GestureDetector(
            onTap: () => _focus.requestFocus(),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                children: [
                  // Hidden field captures all input
                  SizedBox(
                    height: 0,
                    child: AutofillGroup(
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focus,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(height: 0.001, color: Colors.transparent),
                        cursorColor: Colors.transparent,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  // 6 visual boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (i) {
                      final filled = i < code.length;
                      final active = _focus.hasFocus && i == code.length;
                      return Container(
                        width: _otpBoxWidth(context), height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.col.surfaceSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            width: 1.5,
                            color: _hasError
                                ? AppColors.danger
                                : active
                                    ? AppColors.primary
                                    : filled
                                        ? AppColors.primary
                                        : context.col.borderStrong,
                          ),
                        ),
                        child: filled
                            ? Text(code[i],
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 24, fontWeight: FontWeight.w700,
                                  color: context.col.ink0))
                            : active
                                ? Container(
                                    width: 1.5, height: 24,
                                    color: AppColors.primary,
                                  )
                                : null,
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),

          if (_hasError) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(context.s.wrongCode,
                style: const TextStyle(color: AppColors.danger,
                  fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ],

          const SizedBox(height: 28),
          Column(children: [
            Text(context.s.didntReceive,
              style: TextStyle(fontSize: 13, color: context.col.ink2,
                fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            _seconds > 0
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.refresh_rounded, size: 15, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${context.s.resendIn} ${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 13.5,
                        color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ])
                : GestureDetector(
                    onTap: _resending ? null : _resend,
                    child: _resending
                        ? const SizedBox(height: 16, width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary))
                        : Text(context.s.resendCode,
                            style: const TextStyle(color: AppColors.primary,
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ),
            if (_resendError != null) ...[
              const SizedBox(height: 6),
              Text(_resendError!, textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger,
                  fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
          ]),

          const Spacer(),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(context.s.notReceivedInfo,
                  style: TextStyle(fontSize: 11.5, color: context.col.ink1, height: 1.45)),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (code.length == 6 && !_loading) ? _verify : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                  : Text(context.s.verify,
                      style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                        fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
            ),
          ),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

/// "Sent via WhatsApp / SMS" chip. The backend reports which channel it actually
/// used (it tries WhatsApp first, falls back to SMS), so this reflects reality
/// rather than an assumption.
class _ChannelChip extends StatelessWidget {
  final String channel;
  const _ChannelChip({required this.channel});

  @override
  Widget build(BuildContext context) {
    final isWhatsApp = channel == 'whatsapp';
    const waGreen = Color(0xFF25D366);
    final color = isWhatsApp ? waGreen : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isWhatsApp ? Icons.chat_rounded : Icons.sms_outlined,
          size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          isWhatsApp
              ? context.tr('أُرسل عبر واتساب', 'Sent via WhatsApp')
              : context.tr('أُرسل عبر رسالة نصية', 'Sent via SMS'),
          style: TextStyle(
            fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
            fontSize: 12, fontWeight: FontWeight.w700, color: color),
        ),
      ]),
    );
  }
}
