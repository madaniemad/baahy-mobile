import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers/app_pages_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/l10n.dart';
import '../../core/utils/navigation.dart';
import '../theme/app_theme.dart';

const _waGreen = Color(0xFF25D366);

/// The server's `403 {code: 'account_restricted', reason, message, message_en}` answer to
/// POST /orders and every payment/*/initiate: staff restricted this account from ordering.
class AccountRestriction {
  final String? reason;
  final String messageAr;
  final String messageEn;
  const AccountRestriction({this.reason, this.messageAr = '', this.messageEn = ''});

  /// Null unless [e] is that answer.
  static AccountRestriction? from(Object e) {
    if (e is! DioException) return null;
    final d = e.response?.data;
    if (d is! Map || d['code'] != 'account_restricted') return null;
    String str(dynamic v) => v is String ? v.trim() : '';
    final reason = str(d['reason']);
    return AccountRestriction(
      reason: reason.isEmpty ? null : reason,
      messageAr: str(d['message']),
      messageEn: str(d['message_en']),
    );
  }

  /// The server's message in the app language (the other one when this one is empty); null when
  /// it sent neither, and the app's own wording is shown instead.
  String? message(bool isAr) {
    final first = isAr ? messageAr : messageEn;
    final other = isAr ? messageEn : messageAr;
    if (first.isNotEmpty) return first;
    return other.isNotEmpty ? other : null;
  }
}

/// Support for a restricted account. Self-service (the order's «تحتاج مساعدة؟», the assistant)
/// cannot lift a restriction, so this opens the team on WhatsApp — a button only, the number is
/// never shown. Falls back to the Contact us page when no WhatsApp number is configured.
Future<void> openRestrictedSupport(BuildContext context, WidgetRef ref) async {
  final number = ref.read(appPagesProvider).contactWhatsapp.replaceAll(RegExp(r'\D'), '');
  if (number.isNotEmpty) {
    final text = Uri.encodeComponent(context.s.orderingBlockedSupportText);
    try {
      if (await launchUrl(Uri.parse('https://wa.me/$number?text=$text'),
          mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
  }
  if (context.mounted) await safePush(context, '/contact');
}

/// The body text: the server's message when there is one (it already carries the reason and the
/// support line), otherwise the reason (if any) and the support line.
String _restrictionBody(BuildContext context, String? serverMessage, String? reason) {
  if (serverMessage != null && serverMessage.trim().isNotEmpty) return serverMessage.trim();
  return [
    if (reason != null && reason.trim().isNotEmpty) context.s.orderingBlockedReason(reason.trim()),
    context.s.orderingBlockedHelp,
  ].join('\n');
}

Widget _supportButton(BuildContext context, VoidCallback onPressed) => SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.chat_rounded, size: 18, color: _waGreen),
        label: Text(context.s.contactSupport,
            style: TextStyle(
                fontFamily: 'Manrope',
                fontFamilyFallback: const ['Tajawal'],
                fontWeight: FontWeight.w700,
                color: context.col.ink0)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: context.col.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );

/// The card at the top of checkout while this account may not order.
class AccountRestrictedCard extends ConsumerWidget {
  /// The server's message from a refused order or payment; null when built from the profile.
  final String? serverMessage;
  final String? reason;
  const AccountRestrictedCard({super.key, this.serverMessage, this.reason});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.transparent : AppColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: isDark ? 0.6 : 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline_rounded, size: 20, color: AppColors.danger),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(context.s.orderingBlockedTitle,
                style: TextStyle(
                    fontFamily: 'Manrope',
                    fontFamilyFallback: const ['Tajawal'],
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.4,
                    color: context.col.ink0)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(_restrictionBody(context, serverMessage, reason),
            style: TextStyle(fontSize: 13, height: 1.55, color: context.col.ink1)),
        const SizedBox(height: 12),
        _supportButton(context, () => openRestrictedSupport(context, ref)),
      ]),
    );
  }
}

/// The same message as a dialog, for the moment the server refuses an order or payment.
Future<void> showAccountRestrictedDialog(
    BuildContext context, WidgetRef ref, AccountRestriction r) {
  return showDialog<void>(
    context: context,
    builder: (dlg) => AlertDialog(
      title: Text(context.s.orderingBlockedTitle,
          style: const TextStyle(
              fontFamily: 'Manrope',
              fontFamilyFallback: ['Tajawal'],
              fontWeight: FontWeight.w700,
              fontSize: 17)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_restrictionBody(context, r.message(context.isAr), r.reason),
            style: const TextStyle(height: 1.55)),
        const SizedBox(height: 16),
        _supportButton(dlg, () {
          Navigator.of(dlg).pop();
          openRestrictedSupport(context, ref);
        }),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dlg).pop(),
            child: Text(context.s.close)),
      ],
    ),
  );
}

/// For screens other than checkout: when [e] is the `account_restricted` answer, mark the account
/// (the profile is then refreshed so it sticks), show the dialog and return true.
bool handleAccountRestricted(BuildContext context, WidgetRef ref, Object e) {
  final r = AccountRestriction.from(e);
  if (r == null) return false;
  ref.read(authProvider.notifier).markOrderingBlocked(r.reason);
  if (context.mounted) showAccountRestrictedDialog(context, ref, r);
  return true;
}
