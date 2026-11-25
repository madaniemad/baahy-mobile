import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/l10n.dart';

/// «تغيير طريقة الدفع» (Emad 2026-11-25): the customer changes how she pays until the order is delivered.
/// The server lists only the methods allowed for this order (its city, what is switched on); a transfer, card
/// or Tadawel opens the order's payment page in the browser (bank details + receipt, or the gateway).
class ChangePaymentMethodButton extends StatelessWidget {
  final int orderId;
  final VoidCallback onChanged;
  const ChangePaymentMethodButton({super.key, required this.orderId, required this.onChanged});

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    // The words before any wait (the context is not used across async gaps).
    final loadFail = context.tr('تعذّر تحميل طرق الدفع', 'Could not load the payment methods');
    final changed = context.tr('تم تغيير طريقة الدفع', 'Payment method changed');
    final failed = context.tr('تعذّر تغيير طريقة الدفع', 'Could not change it');
    Map<String, dynamic>? data;
    try {
      final r = await ApiClient.instance.dio.get('/orders/$orderId/payment-options');
      data = Map<String, dynamic>.from(r.data['data'] as Map);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(loadFail)));
      return;
    }
    if (!context.mounted) return;
    final methods = (data['methods'] as List? ?? const []).cast<Map>();
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(ctx.tr('كيف تريد الدفع؟', 'How would you like to pay?'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (data!['can_change'] != true)
              Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('${data['reason'] ?? ''}'))
            else ...[
              Text('${ctx.tr('المبلغ', 'Amount')}: ${fmtPrice((data['amount_due'] as num?)?.toDouble() ?? 0)}'),
              const SizedBox(height: 8),
              for (final m in methods)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: m['current'] == true ? null : () => Navigator.of(ctx).pop('${m['id']}'),
                    child: Text('${ctx.tr('${m['label_ar']}', '${m['label_en']}')}${m['current'] == true ? ctx.tr(' (الحالية)', ' (current)') : ''}'),
                  ),
                ),
              if (data['payment_url'] != null)
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop('__page'),
                  child: Text(ctx.tr('افتح صفحة الدفع للطريقة الحالية', 'Open the payment page for the current method')),
                ),
            ],
          ]),
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;
    String? url;
    if (chosen == '__page') {
      url = data['payment_url'] as String?;
    } else {
      try {
        final r = await ApiClient.instance.dio.post('/orders/$orderId/payment-method', data: {'method': chosen});
        url = (r.data['data'] as Map?)?['payment_url'] as String?;
        onChanged();
        if (url == null) messenger.showSnackBar(SnackBar(content: Text(changed)));
      } on DioException catch (e) {
        final msg = (e.response?.data is Map ? e.response!.data['message'] : null)?.toString();
        messenger.showSnackBar(SnackBar(content: Text(msg ?? failed)));
        return;
      }
    }
    if (url != null) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.payments_outlined, size: 18),
        label: Text(context.tr('تغيير طريقة الدفع', 'Change payment method')),
      );
}
