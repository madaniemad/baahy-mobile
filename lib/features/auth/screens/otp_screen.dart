import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/theme/app_theme.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpScreen({required this.phone, super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _ctrls = List.generate(6, (_) => TextEditingController());
  final _focuses = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  bool _hasError = false;
  int _seconds = 45;
  Timer? _timer;

  String get _code => _ctrls.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _startTimer();
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
    for (final c in _ctrls) c.dispose();
    for (final f in _focuses) f.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.length < 6) return;
    setState(() { _loading = true; _hasError = false; });
    try {
      await ref.read(authProvider.notifier).verifyOtp(widget.phone, _code);
      if (mounted) context.go('/home');
    } catch (_) {
      setState(() { _hasError = true; _loading = false; });
      for (final c in _ctrls) c.clear();
      _focuses[0].requestFocus();
    }
  }

  void _onDigitChange(int i, String v) {
    setState(() => _hasError = false);
    if (v.isNotEmpty) {
      if (i < 5) _focuses[i + 1].requestFocus();
      final full = _code;
      if (full.length == 6) _verify();
    } else if (i > 0) {
      _focuses[i - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink0)),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF8F8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.check_rounded, color: AppColors.teal600, size: 28),
          ),
          const SizedBox(height: 24),
          const Text('تأكيد رقمك',
            style: TextStyle(fontFamily: 'Cairo',
              fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              text: 'أرسلنا رمزاً مكوناً من 6 أرقام إلى ',
              style: const TextStyle(fontSize: 14.5, color: AppColors.ink2, height: 1.5),
              children: [
                TextSpan(
                  text: widget.phone,
                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w700, color: AppColors.ink0)),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // OTP boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) => SizedBox(
              width: 46, height: 56,
              child: TextField(
                controller: _ctrls[i],
                focusNode: _focuses[i],
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                  fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink0),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.surfaceSoft,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: _ctrls[i].text.isNotEmpty && !_hasError
                          ? AppColors.primary
                          : _hasError ? AppColors.danger : Colors.transparent,
                      width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: _hasError ? AppColors.danger : AppColors.primary,
                      width: 1.5),
                  ),
                ),
                onChanged: (v) => _onDigitChange(i, v),
              ),
            )),
          ),

          if (_hasError) ...[
            const SizedBox(height: 12),
            const Center(
              child: Text('رمز غير صحيح. حاول مرة أخرى.',
                style: TextStyle(color: AppColors.danger,
                  fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ],

          const SizedBox(height: 28),
          Center(
            child: _seconds > 0
                ? Text('إعادة الإرسال خلال ${_seconds} ثانية',
                    style: const TextStyle(fontSize: 13, color: AppColors.ink3))
                : GestureDetector(
                    onTap: () {
                      ref.read(authProvider.notifier).requestOtp(widget.phone);
                      _startTimer();
                    },
                    child: const Text('إعادة إرسال الرمز',
                      style: TextStyle(color: AppColors.teal600,
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ),
          ),

          const Spacer(),

          // Tip
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 16, color: AppColors.ink3),
              SizedBox(width: 10),
              Expanded(
                child: Text('إذا لم يصلك الرمز، تحقق من صحة رقم الهاتف أو حاول مجدداً.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.ink2, height: 1.45)),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_code.length == 6 && !_loading) ? _verify : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink0))
                  : const Text('تحقق',
                      style: TextStyle(fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink0)),
            ),
          ),
        ]),
      ),
    );
  }
}
