import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_config_provider.dart';
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
  bool _refLocked = false; // code came from a referral link/clipboard → shown but not editable
  final _phoneFocus = FocusNode();
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = () => safePush(context, '/terms');
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = () => safePush(context, '/privacy');

  /// The 9 national digits (the field formats them as "91 234 5678").
  String get _digits => _ctrl.text.replaceAll(RegExp(r'\D'), '');
  bool get _valid => _digits.length == 9;

  @override
  void initState() {
    super.initState();
    DeepLinkService.peekPendingCode().then((code) {
      if (code != null && mounted) {
        _refCtrl.text = code;
        setState(() { _showRefField = true; _refLocked = true; });
      }
    });
    _phoneFocus.addListener(() { if (mounted) setState(() {}); });
    _refCtrl.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _refCtrl.dispose();
    _phoneFocus.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_valid) return;
    setState(() { _loading = true; _error = null; });
    try {
      final phone = '+218 $_digits';
      final ref2 = _refCtrl.text.trim();
      final channel = await ref.read(authProvider.notifier).requestOtp(phone);
      if (mounted) await safePush(context, '/otp',
          extra: <String, dynamic>{
            'phone': phone,
            'ref': ref2.isNotEmpty ? ref2 : null,
            'channel': channel,
          });
    } catch (e, st) {
      // Tagged so Sentry can answer the only question that matters without a customer to
      // ask: connectionTimeout/connectionError never reached us, receiveTimeout means we
      // were too slow, badResponse means we refused it.
      Sentry.captureException(e, stackTrace: st, withScope: (scope) {
        scope.setTag('flow', 'otp_send');
        scope.setTag('dio_type', e is DioException ? e.type.name : 'other');
        scope.setTag('http_status', '${e is DioException ? e.response?.statusCode : null}');
      });
      // Show the server's own reason. A rate limit says "wait N minutes"; hiding that
      // behind a generic "try again" is what drove users to tap resend until they burnt
      // the hourly budget and locked their own number out for the rest of the hour.
      // Tell a network failure apart from a refusal. "Sending failed" for both is what
      // let a user sit for an afternoon retrying a request that never left the phone,
      // while support hunted for a server fault that did not exist.
      if (!mounted) return;
      String msg = context.tr('تعذر الإرسال، حاول مجدداً', 'Could not send, please try again');
      if (e is DioException) {
        final d = e.response?.data;
        if (d is Map && d['message'] != null) {
          msg = d['message'].toString();
        } else if (e.type == DioExceptionType.connectionTimeout ||
                   e.type == DioExceptionType.connectionError ||
                   e.type == DioExceptionType.sendTimeout ||
                   e.type == DioExceptionType.receiveTimeout) {
          msg = context.s.checkInternet;
        }
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(appConfigProvider);
    String amt(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
    final hasRef = _refCtrl.text.trim().isNotEmpty;
    final borderColor = _error != null
        ? AppColors.danger
        : (_phoneFocus.hasFocus ? AppColors.primary : context.col.border);
    const font = ['Tajawal'];

    // Redesigned 2026-10-23 (Emad): one phone box (+218 inside), WhatsApp named, the button right
    // under the field, plain benefit rows instead of tinted tiles, tappable terms, and the invite
    // code says what it actually does. The 20 LYD welcome credit is for EVERY new account — it is
    // not presented as the invite code's reward (see the referral rules).
    return Scaffold(
      backgroundColor: context.col.surface,
      appBar: AppBar(
        backgroundColor: context.col.surface, elevation: 0,
        leading: IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          icon: Icon(Icons.arrow_back, color: context.col.ink0)),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.s.enterPhone,
              style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: font,
                fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            const SizedBox(height: 8),
            Text(context.s.phoneSub,
              style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: font,
                fontSize: 14.5, color: context.col.ink2, height: 1.5)),
            const SizedBox(height: 24),

            // One box: +218 + number (a flag emoji renders as two boxes in our fonts). Always LTR so the code stays on the left.
            Directionality(
              textDirection: TextDirection.ltr,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: _phoneFocus.hasFocus ? 1.5 : 1),
                ),
                child: Row(children: [
                  const SizedBox(width: 16),
                  const Text('+218',
                    style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  Container(width: 1, height: 26, color: context.col.border),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _phoneFocus,
                      autofocus: true,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      inputFormatters: [_LibyanPhoneFormatter()],
                      onChanged: (_) => setState(() => _error = null),
                      style: const TextStyle(fontFamily: 'PlusJakartaSans',
                        fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                      decoration: InputDecoration(
                        hintText: '91 234 5678',
                        hintStyle: TextStyle(color: context.col.ink4, fontWeight: FontWeight.w400),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ]),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ],

            const SizedBox(height: 14),
            if (!_showRefField)
              GestureDetector(
                onTap: () => setState(() => _showRefField = true),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.card_giftcard_outlined, size: 15, color: context.col.ink3),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(context.tr('لديك كود دعوة؟', 'Have an invite code?'),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: font, fontSize: 13,
                        color: context.col.ink3, fontWeight: FontWeight.w600)),
                  ),
                ]),
              )
            else ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.col.border),
                ),
                child: TextField(
                  controller: _refCtrl,
                  readOnly: _refLocked,
                  enableInteractiveSelection: !_refLocked,
                  autofocus: !_refLocked && _refCtrl.text.isEmpty,
                  textDirection: TextDirection.ltr,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                    fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1),
                  decoration: InputDecoration(
                    hintText: context.tr('كود الدعوة', 'Invite code'),
                    hintStyle: TextStyle(
                      fontFamily: 'Manrope', fontFamilyFallback: font, fontSize: 13,
                      color: context.col.ink4, fontWeight: FontWeight.w400,
                      letterSpacing: 0),
                    prefixIcon: Icon(Icons.card_giftcard_outlined,
                      size: 18, color: _refLocked ? const Color(0xFF1F8A5B) : context.col.ink3),
                    // Locked code (from a referral link/clipboard) can't be EDITED, but a
                    // returning user with a stale code can explicitly REMOVE it via the ×.
                    suffixIcon: _refLocked
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.check_circle, size: 18, color: Color(0xFF1F8A5B)),
                          IconButton(
                            icon: Icon(Icons.close_rounded, size: 18, color: context.col.ink3),
                            splashRadius: 18,
                            tooltip: context.isAr ? 'إزالة' : 'Remove',
                            onPressed: () async {
                              await DeepLinkService.consumePendingCode();
                              if (mounted) setState(() {
                                _refCtrl.clear();
                                _refLocked = false;
                                _showRefField = false;
                              });
                            },
                          ),
                        ])
                      : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),
              ),
              // What the code does — the inviter's reward, never the newcomer's (that is the
              // welcome credit every new account gets).
              if (hasRef && cfg.referralGiverAmount > 0) ...[
                const SizedBox(height: 8),
                Text(context.s.inviteRewardLine(
                      amt(cfg.referralGiverAmount), amt(cfg.referralMinOrder)),
                  style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: font,
                    fontSize: 12.5, color: context.col.ink2, height: 1.5)),
              ],
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_valid && !_loading) ? _send : null,
                icon: _loading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                label: Text(context.s.sendCode,
                  style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: font,
                    fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            // No "أو / continue as guest" here: once the user is in the
            // sign-in/sign-up flow they must complete one of the two.
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.lock_outline_rounded, size: 12, color: context.col.ink3),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: font,
                      fontSize: 11.5, color: context.col.ink3, height: 1.5),
                    children: [
                      TextSpan(text: context.s.termsLead),
                      TextSpan(text: context.s.termsLink, recognizer: _termsTap,
                        style: TextStyle(color: AppColors.adaptive(context), fontWeight: FontWeight.w700)),
                      TextSpan(text: context.s.termsAnd),
                      TextSpan(text: context.s.privacyLink, recognizer: _privacyTap,
                        style: TextStyle(color: AppColors.adaptive(context), fontWeight: FontWeight.w700)),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 28),
            Divider(height: 1, color: context.col.border),
            const SizedBox(height: 20),
            // Account perks — four short items in two columns, no tinted tiles. True for new and
            // returning customers alike; each hides itself when that reward is switched off.
            Builder(builder: (context) {
              final offer = context.isAr ? cfg.firstOrderOfferAr : cfg.firstOrderOfferEn;
              final pct = RegExp(r'\d+(\.\d+)?\s*%').firstMatch(offer ?? '')?.group(0)?.replaceAll(' ', '');
              final topCashback = cfg.tierPlatinumCashback > cfg.cashbackRate
                  ? cfg.tierPlatinumCashback : cfg.cashbackRate;
              final perks = <(IconData, String)>[
                if (cfg.welcomeBonusAmount > 0)
                  (Icons.account_balance_wallet_outlined, context.s.perkWelcome(amt(cfg.welcomeBonusAmount))),
                if (pct != null) (Icons.local_offer_outlined, context.s.perkFirstOrder(pct)),
                if (topCashback > 0) (Icons.savings_outlined, context.s.perkCashback(amt(topCashback))),
                if (cfg.referralGiverAmount > 0)
                  (Icons.card_giftcard_outlined, context.s.perkInvite(amt(cfg.referralGiverAmount))),
              ];
              if (perks.isEmpty) return const SizedBox.shrink();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.s.accountPerks,
                  style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: font,
                    fontSize: 13.5, fontWeight: FontWeight.w800, color: context.col.ink0)),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (_, box) => Wrap(
                  runSpacing: 12,
                  children: [
                    for (final p in perks)
                      SizedBox(width: box.maxWidth / 2, child: _BenefitRow(icon: p.$1, label: p.$2)),
                  ],
                )),
              ]);
            }),
          ]),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _BenefitRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: AppColors.primary, size: 18),
      const SizedBox(width: 8),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(label,
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
              fontSize: 12.5, fontWeight: FontWeight.w500,
              color: context.col.ink1, height: 1.4)),
        ),
      ),
    ]);
  }
}

/// Libyan mobile number: Arabic/Persian digits → Latin, a pasted +218 / 00218 / leading 0
/// dropped, 9 digits max, shown as "91 234 5678".
class _LibyanPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final buf = StringBuffer();
    for (final r in newValue.text.runes) {
      if (r >= 0x0660 && r <= 0x0669) {
        buf.writeCharCode(0x30 + r - 0x0660);
      } else if (r >= 0x06F0 && r <= 0x06F9) {
        buf.writeCharCode(0x30 + r - 0x06F0);
      } else if (r >= 0x30 && r <= 0x39) {
        buf.writeCharCode(r);
      }
    }
    var d = buf.toString();
    if (d.startsWith('00218')) {
      d = d.substring(5);
    } else if (d.startsWith('218') && d.length > 9) {
      d = d.substring(3);
    }
    if (d.startsWith('0')) d = d.substring(1);
    if (d.length > 9) d = d.substring(0, 9);
    final out = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 2 || i == 5) out.write(' ');
      out.write(d[i]);
    }
    final text = out.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
