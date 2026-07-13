import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/deep_link_service.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class PhoneSignInScreen extends ConsumerStatefulWidget {
  const PhoneSignInScreen({super.key});

  @override
  ConsumerState<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends ConsumerState<PhoneSignInScreen> {
  final _ctrl = TextEditingController();
  final _refCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _showRefField = false;

  bool get _valid => _ctrl.text.replaceAll(RegExp(r'\D'), '').length >= 9;

  @override
  void initState() {
    super.initState();
    DeepLinkService.peekPendingCode().then((code) {
      if (code != null && mounted) {
        _refCtrl.text = code;
        setState(() => _showRefField = true);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_valid) return;
    setState(() { _loading = true; _error = null; });
    try {
      final phone = '+218 ${_ctrl.text.trim()}';
      final ref2 = _refCtrl.text.trim();
      await ref.read(authProvider.notifier).requestOtp(phone);
      if (mounted) await safePush(context, '/otp',
          extra: <String, dynamic>{'phone': phone, 'ref': ref2.isNotEmpty ? ref2 : null});
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      setState(() => _error = 'تعذر الإرسال، حاول مجدداً');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.col.surface,
      appBar: AppBar(
        backgroundColor: context.col.surface, elevation: 0,
        leading: IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          icon: Icon(Icons.arrow_back, color: context.col.ink0)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.phone_outlined,
                color: AppColors.primary, size: 26),
            ),
            const SizedBox(height: 24),
            Text(context.s.enterPhone,
              style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            const SizedBox(height: 8),
            Text(context.s.phoneSub,
              style: TextStyle(fontSize: 14.5, color: context.col.ink2, height: 1.5)),
            const SizedBox(height: 24),

            // Phone input — always LTR so country code stays on the left
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.col.borderStrong),
                  ),
                  child: const Text('+218',
                    style: TextStyle(fontFamily: 'PlusJakartaSans',
                      fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _error != null ? AppColors.danger : context.col.borderStrong),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      onChanged: (_) => setState(() => _error = null),
                      style: const TextStyle(fontFamily: 'PlusJakartaSans',
                        fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                      decoration: InputDecoration(
                        hintText: '91 234 5678',
                        hintStyle: TextStyle(color: context.col.ink4, fontWeight: FontWeight.w400),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
              ]),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ],

            const SizedBox(height: 14),
            if (!_showRefField)
              GestureDetector(
                onTap: () => setState(() => _showRefField = true),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.card_giftcard_outlined, size: 15, color: context.col.ink3),
                  const SizedBox(width: 5),
                  Text('لديك كود دعوة؟',
                    style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13,
                      color: context.col.ink3, fontWeight: FontWeight.w600)),
                ]),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: context.col.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.col.border),
                ),
                child: TextField(
                  controller: _refCtrl,
                  autofocus: _refCtrl.text.isEmpty,
                  textDirection: TextDirection.ltr,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                    fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1),
                  decoration: InputDecoration(
                    hintText: 'كود الدعوة',
                    hintStyle: TextStyle(
                      fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13,
                      color: context.col.ink4, fontWeight: FontWeight.w400,
                      letterSpacing: 0),
                    prefixIcon: Icon(Icons.card_giftcard_outlined,
                      size: 18, color: context.col.ink3),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),
              ),

                ],
              ),
            ),
          ),
          Padding(
            // Do NOT add viewInsets.bottom here: this block is in the Scaffold
            // body, and Scaffold.resizeToAvoidBottomInset (default true) has
            // already shrunk the body by the keyboard height. Adding it again
            // double-counts the keyboard — it shoved this block up by a whole
            // keyboard-height and pushed the title/phone field off-screen.
            // (Invisible on the Simulator, whose software keyboard is off by
            // default, so viewInsets.bottom was always 0 there.)
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_valid && !_loading) ? _send : null,
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                      : const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                  label: Text(context.s.sendCode,
                    style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                      fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // No "أو / continue as guest" here: once the user is in the
              // sign-in/sign-up flow they must complete one of the two.
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.lock_outline_rounded, size: 12, color: context.col.ink3),
                const SizedBox(width: 5),
                Flexible(child: Text(
                  context.s.termsAgreement,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: context.col.ink3, height: 1.5))),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}
