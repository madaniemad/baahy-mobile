import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

/// The latest return request on an order, or null when there is none.
///
/// Until 2026-10-17 the app could file a return and never show it again: she had no way to see
/// where it stood, nor to change it. Emad: she should be able to take an item off, or withdraw
/// the return, from the same place — e.g. she realises she opened the perfume and a seller
/// refusal would cost her the return and delivery fees.
final orderReturnProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, int>((ref, orderId) async {
  final res = await ApiClient.instance.dio.get('/returns', queryParameters: {'order_id': orderId});
  final list = (res.data?['data']?['data'] as List?) ?? const [];
  if (list.isEmpty) return null;
  return Map<String, dynamic>.from(list.first as Map);
});

/// Statuses where the return is still open (mirrors ReturnRequest::OPEN_STATUSES).
const kOpenReturnStatuses = {
  'pending', 'approved', 'collection_assigned', 'collected', 'collection_refused', 'dropped',
};

class ReturnRequestCard extends ConsumerStatefulWidget {
  final int orderId;
  const ReturnRequestCard({required this.orderId, super.key});

  @override
  ConsumerState<ReturnRequestCard> createState() => _ReturnRequestCardState();
}

class _ReturnRequestCardState extends ConsumerState<ReturnRequestCard> {
  bool _busy = false;

  static String _statusLabel(BuildContext c, String s) {
    switch (s) {
      case 'pending':             return c.tr('قيد المراجعة', 'Under review');
      case 'approved':            return c.tr('تم قبول الطلب', 'Accepted');
      case 'collection_assigned': return c.tr('بانتظار الاستلام', 'Awaiting pickup');
      case 'collected':
      case 'dropped':             return c.tr('قيد الفحص لدى البائع', 'Being checked by the seller');
      case 'collection_refused':  return c.tr('قيد المعالجة', 'In progress');
      case 'completed':           return c.tr('مكتمل', 'Completed');
      case 'rejected':            return c.tr('مرفوض', 'Rejected');
      case 'cancelled':           return c.tr('ملغى', 'Cancelled');
      default:                    return s;
    }
  }

  static Color _statusColor(String s) {
    switch (s) {
      case 'completed': return AppColors.success;
      case 'rejected':  return AppColors.danger;
      case 'cancelled': return const Color(0xFF8A9499);
      default:          return AppColors.primary;
    }
  }

  static String _itemName(Map it) {
    final oi = it['order_item'] as Map?;
    final name = (oi?['product_name'] ?? '').toString().split('\n').first.trim();
    final qty = it['qty_returned'] ?? 1;
    return '$name × $qty';
  }

  Future<void> _run(Future<Response> Function() call, String okAr, String okEn) async {
    setState(() => _busy = true);
    try {
      await call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr(okAr, okEn)), backgroundColor: AppColors.success));
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = (e.response?.data is Map) ? e.response?.data['message']?.toString() : null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg ?? context.tr('تعذّر تنفيذ الطلب، حاول مجدداً', 'Something went wrong, please try again'))));
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _busy = false);
      ref.invalidate(orderReturnProvider(widget.orderId));
    }
  }

  Future<void> _removeItems(Map<String, dynamic> rr, List<Map> active) async {
    final picked = <int>{};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.col.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ctx.tr('إزالة منتجات من طلب الإرجاع', 'Remove items from the return'),
              style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                fontSize: 16, fontWeight: FontWeight.w800, color: ctx.col.ink0)),
            const SizedBox(height: 6),
            Text(ctx.tr('اختر المنتجات التي لا ترغب في إرجاعها.', 'Choose the items you no longer want to return.'),
              style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                fontSize: 13, color: ctx.col.ink2)),
            const SizedBox(height: 8),
            ...active.map((it) {
              final id = (it['id'] as num).toInt();
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.primary,
                value: picked.contains(id),
                onChanged: (v) => setSheet(() => v == true ? picked.add(id) : picked.remove(id)),
                title: Text(_itemName(it),
                  style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                    fontSize: 14, color: ctx.col.ink0)),
              );
            }),
            if (picked.length == active.length && active.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(ctx.tr('إزالة جميع المنتجات تُلغي طلب الإرجاع.', 'Removing every item cancels the return.'),
                  style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                    fontSize: 12.5, color: AppColors.danger)),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: picked.isEmpty ? null : () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(ctx.tr('إزالة', 'Remove'),
                  style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                    fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
        ),
      )),
    );
    if (ok != true || picked.isEmpty || !mounted) return;
    await _run(
      () => ApiClient.instance.dio.post('/returns/${rr['id']}/remove-items', data: {'item_ids': picked.toList()}),
      'تم تعديل طلب الإرجاع', 'Return updated');
  }

  Future<void> _cancel(Map<String, dynamic> rr) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('إلغاء طلب الإرجاع؟', 'Cancel the return?'),
          style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w800)),
        content: Text(ctx.tr('سيتم إلغاء طلب الإرجاع ولن يتم استلام أي منتج.', 'The return will be cancelled and nothing will be collected.'),
          style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('رجوع', 'Back'), style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal']))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('إلغاء الطلب', 'Cancel return'),
              style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                fontWeight: FontWeight.w700, color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() => ApiClient.instance.dio.post('/returns/${rr['id']}/cancel'),
      'تم إلغاء طلب الإرجاع', 'Return cancelled');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderReturnProvider(widget.orderId));
    final rr = async.valueOrNull;
    if (rr == null) return const SizedBox.shrink();

    final status  = (rr['status'] ?? '').toString();
    final canEdit = rr['can_edit'] == true;
    final items   = ((rr['return_items'] as List?) ?? const []).cast<Map>();
    final active  = items.where((it) => it['status'] != 'removed').toList();
    final net     = double.tryParse('${rr['net_refund_amount'] ?? 0}') ?? 0;
    final color   = _statusColor(status);
    const font    = 'Manrope';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.assignment_return_outlined, size: 18, color: context.col.ink1),
          const SizedBox(width: 8),
          Expanded(child: Text(context.tr('طلب الإرجاع', 'Return request'),
            style: TextStyle(fontFamily: font, fontFamilyFallback: const ['Tajawal'],
              fontSize: 14.5, fontWeight: FontWeight.w800, color: context.col.ink0))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9999)),
            child: Text(_statusLabel(context, status),
              style: TextStyle(fontFamily: font, fontFamilyFallback: const ['Tajawal'],
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
        const SizedBox(height: 10),
        ...items.map((it) {
          final removed = it['status'] == 'removed' || it['status'] == 'rejected';
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              _itemName(it) + (it['status'] == 'removed' ? context.tr('  (أُزيل)', '  (removed)') : ''),
              style: TextStyle(fontFamily: font, fontFamilyFallback: const ['Tajawal'], fontSize: 13,
                color: removed ? context.col.ink3 : context.col.ink1,
                decoration: removed ? TextDecoration.lineThrough : null),
            ),
          );
        }),
        if (status != 'cancelled' && status != 'rejected' && net > 0) ...[
          const SizedBox(height: 6),
          Text(
            context.tr(
              status == 'completed' ? 'المبلغ المسترد: ${fmtPrice(net)} د.ل' : 'المبلغ المتوقع استرداده: ${fmtPrice(net)} د.ل',
              status == 'completed' ? 'Refunded: ${fmtPrice(net)} LYD' : 'Expected refund: ${fmtPrice(net)} LYD'),
            style: TextStyle(fontFamily: font, fontFamilyFallback: const ['Tajawal'],
              fontSize: 13, fontWeight: FontWeight.w700, color: context.col.ink0)),
        ],
        if (canEdit) ...[
          const SizedBox(height: 12),
          Row(children: [
            if (active.length > 1) ...[
              Expanded(child: OutlinedButton(
                onPressed: _busy ? null : () => _removeItems(rr, active),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  side: BorderSide(color: context.col.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(context.tr('تعديل المنتجات', 'Edit items'),
                  style: TextStyle(fontFamily: font, fontFamilyFallback: const ['Tajawal'],
                    fontWeight: FontWeight.w700, color: context.col.ink0)),
              )),
              const SizedBox(width: 10),
            ],
            Expanded(child: OutlinedButton(
              onPressed: _busy ? null : () => _cancel(rr),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 11),
                side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(context.tr('إلغاء طلب الإرجاع', 'Cancel return'),
                style: const TextStyle(fontFamily: font, fontFamilyFallback: ['Tajawal'],
                  fontWeight: FontWeight.w700, color: AppColors.danger)),
            )),
          ]),
          const SizedBox(height: 6),
          Text(context.tr('يمكنك تعديل طلب الإرجاع أو إلغاؤه قبل استلام المنتج.',
              'You can edit or cancel the return until the item is collected.'),
            style: TextStyle(fontFamily: font, fontFamilyFallback: const ['Tajawal'],
              fontSize: 12, color: context.col.ink3)),
        ],
      ]),
    );
  }
}
