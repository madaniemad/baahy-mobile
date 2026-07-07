import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/deep_link_service.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  final String? referralCode;
  const OtpScreen({required this.phone, this.referralCode, super.key});

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
    _seconds = 45;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_seconds > 0) {
        setState(() => _seconds--);
      } else {
        _timer?.cancel();
      }
    });
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
      await ref.read(authProvider.notifier).verifyOtp(
        widget.phone, _code, referralCode: widget.referralCode);
      await DeepLinkService.consumePendingCode(); // clear after successful signup
      if (mounted) context.go('/home');
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      HapticFeedback.mediumImpact();
      setState(() { _hasError = true; _loading = false; });
      _ctrl.clear();
      _focus.requestFocus();
    }
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
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
                        width: 46, height: 56,
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
                    onTap: () {
                      ref.read(authProvider.notifier).requestOtp(widget.phone);
                      _startTimer();
                    },
                    child: Text(context.s.resendCode,
                      style: const TextStyle(color: AppColors.primary,
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ),
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
    );
  }
}
