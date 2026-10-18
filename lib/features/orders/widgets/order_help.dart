import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

/// "Need help?" on an order (Emad, 2026-10-18): self-service first, the assistant second,
/// WhatsApp last — so WhatsApp is deliberately NOT offered anywhere in here. The server
/// (GET /orders/{id}/help) decides which reasons fit the order's stage, so the menu can
/// change without an app release; requests never edit the order, staff answer them and
/// the answer shows in [HelpRequestsCard] with a notification.
final orderHelpProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, orderId) async {
  final res = await ApiClient.instance.dio.get('/orders/$orderId/help');
  return Map<String, dynamic>.from(res.data['data'] as Map);
});

IconData _reasonIcon(String key) => switch (key) {
      'change_date' => Icons.event_outlined,
      'change_address' => Icons.location_on_outlined,
      'change_phone' => Icons.phone_iphone_outlined,
      'late' => Icons.schedule_outlined,
      'missing_item' => Icons.remove_shopping_cart_outlined,
      'damaged_item' => Icons.broken_image_outlined,
      'wrong_item' => Icons.swap_horiz_rounded,
      'not_received' => Icons.inventory_2_outlined,
      _ => Icons.edit_note_rounded,
    };

String _apiError(BuildContext context, Object e) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map) {
      final errors = d['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
      if (d['message'] != null) return d['message'].toString();
    }
  }
  return context.tr('تعذّر إرسال الطلب، حاول مجدداً', 'Could not send your request, please try again');
}

/// The sheet behind "Need help?". [extra] are the order screen's own actions (return,
/// cancel) so everything she can do herself is in one place, before the assistant.
Future<void> showOrderHelpSheet(
  BuildContext context,
  WidgetRef ref, {
  required int orderId,
  required String orderNumber,
  List<({IconData icon, String label, VoidCallback onTap, Color? color})> extra = const [],
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.col.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetCtx) => Consumer(builder: (sheetCtx, sheetRef, _) {
      final help = sheetRef.watch(orderHelpProvider(orderId));
      Widget row(IconData icon, String label, VoidCallback onTap, {Color? color}) => InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
              child: Row(children: [
                Icon(icon, size: 21, color: color ?? context.col.ink1),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(label,
                        style: TextStyle(
                            fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                            fontSize: 14.5, fontWeight: FontWeight.w600, color: color ?? context.col.ink0))),
                Icon(Icons.chevron_right_rounded, size: 18, color: context.col.ink4),
              ]),
            ),
          );
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                  child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(color: context.col.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(context.tr('تحتاج مساعدة؟', 'Need help?'),
                  style: const TextStyle(
                      fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(context.tr('اختر ما يناسبك، وسيصلك الرد هنا في التطبيق.', 'Choose what fits, and you will get our answer here in the app.'),
                  style: TextStyle(fontSize: 12.5, color: context.col.ink2)),
              const SizedBox(height: 8),
              ...help.when(
                loading: () => [
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
                ],
                error: (_, __) => [
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(context.tr('تعذّر تحميل الخيارات، حاول مجدداً.', 'Could not load the options, please try again.'),
                          style: TextStyle(color: context.col.ink2)))
                ],
                data: (d) => [
                  for (final r in (d['reasons'] as List? ?? const []).cast<Map>())
                    row(_reasonIcon(r['key'].toString()), context.isAr ? r['label_ar'].toString() : r['label_en'].toString(), () async {
                      Navigator.of(sheetCtx).pop();
                      final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(
                          builder: (_) => OrderHelpRequestScreen(
                              orderId: orderId, orderNumber: orderNumber, reason: Map<String, dynamic>.from(r))));
                      if (sent == true) ref.invalidate(orderHelpProvider(orderId));
                    }),
                ],
              ),
              for (final e in extra)
                row(e.icon, e.label, () {
                  Navigator.of(sheetCtx).pop();
                  e.onTap();
                }, color: e.color),
              Divider(height: 20, color: context.col.border),
              row(Icons.auto_awesome_outlined, context.tr('اسأل المساعد', 'Ask the assistant'), () {
                Navigator.of(sheetCtx).pop();
                safePush(context, '/chat',
                    extra: context.tr('أحتاج مساعدة بخصوص طلب رقم $orderNumber', 'I need help with order $orderNumber'));
              }),
            ]),
          ),
        ),
      );
    }),
  );
}

/// One request: the reason's own question (a date, an address, a phone), free text, and
/// photos where they help (a damaged or wrong item).
class OrderHelpRequestScreen extends StatefulWidget {
  final int orderId;
  final String orderNumber;
  final Map<String, dynamic> reason;
  const OrderHelpRequestScreen({super.key, required this.orderId, required this.orderNumber, required this.reason});

  @override
  State<OrderHelpRequestScreen> createState() => _OrderHelpRequestScreenState();
}

class _OrderHelpRequestScreenState extends State<OrderHelpRequestScreen> {
  final _details = TextEditingController();
  final _phone = TextEditingController();
  final _otherAddress = TextEditingController();
  DateTime? _date;
  List<Map<String, dynamic>>? _addresses;
  int? _addressId; // -1 = typed below
  List<XFile> _photos = [];
  bool _sending = false;
  String? _error;

  String? get _field => widget.reason['field']?.toString();
  bool get _photosAllowed => widget.reason['photos'] == true;
  bool get _detailsRequired => widget.reason['details_required'] == true;

  @override
  void initState() {
    super.initState();
    if (_field == 'address') _loadAddresses();
  }

  @override
  void dispose() {
    _details.dispose();
    _phone.dispose();
    _otherAddress.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    try {
      final res = await ApiClient.instance.dio.get('/addresses');
      final list = (res.data['data'] as List? ?? const []).map((a) => Map<String, dynamic>.from(a as Map)).toList();
      if (mounted) setState(() { _addresses = list; _addressId = list.isEmpty ? -1 : null; });
    } catch (_) {
      if (mounted) setState(() { _addresses = const []; _addressId = -1; });
    }
  }

  String _addressText(Map<String, dynamic> a) => [a['label'], a['city'], a['area'], a['street']]
      .map((v) => (v ?? '').toString().trim())
      .where((v) => v.isNotEmpty)
      .join('، ');

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (d != null) setState(() { _date = d; _error = null; });
  }

  Future<void> _pickPhotos() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 70);
    if (picked.isEmpty) return;
    setState(() => _photos = [..._photos, ...picked].take(3).toList());
  }

  Future<void> _submit() async {
    String? address;
    if (_field == 'date' && _date == null) return setState(() => _error = context.tr('اختر الموعد الذي يناسبك.', 'Choose the date that suits you.'));
    if (_field == 'address') {
      if (_addressId == null) return setState(() => _error = context.tr('اختر العنوان الجديد أو اكتبه.', 'Choose or type the new address.'));
      address = _addressId == -1
          ? _otherAddress.text.trim()
          : _addressText(_addresses!.firstWhere((a) => a['id'] == _addressId));
      if (address.isEmpty) return setState(() => _error = context.tr('اكتب العنوان الجديد.', 'Type the new address.'));
    }
    if (_field == 'phone' && _phone.text.trim().isEmpty) {
      return setState(() => _error = context.tr('اكتب رقم الهاتف الجديد.', 'Type the new phone number.'));
    }
    if (_detailsRequired && _details.text.trim().isEmpty) {
      return setState(() => _error = context.tr('اكتب لنا تفاصيل طلبك.', 'Tell us the details.'));
    }
    setState(() { _sending = true; _error = null; });
    try {
      final form = FormData();
      form.fields.add(MapEntry('reason', widget.reason['key'].toString()));
      if (_details.text.trim().isNotEmpty) form.fields.add(MapEntry('details', _details.text.trim()));
      if (_date != null) {
        form.fields.add(MapEntry('date',
            '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}'));
      }
      if (address != null) form.fields.add(MapEntry('address', address));
      if (_field == 'phone') form.fields.add(MapEntry('phone', _phone.text.trim()));
      for (final p in _photos) {
        form.files.add(MapEntry('photos[]', await MultipartFile.fromFile(p.path, filename: p.name)));
      }
      await ApiClient.instance.dio.post('/orders/${widget.orderId}/help', data: form);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('تم إرسال طلبك، وسيصلك الرد هنا في التطبيق.', 'Request sent — our answer will come here in the app.')),
          backgroundColor: AppColors.success));
      Navigator.of(context).pop(true);
    } catch (e, st) {
      if (e is! DioException || (e.response?.statusCode ?? 500) >= 500) Sentry.captureException(e, stackTrace: st);
      if (mounted) setState(() { _sending = false; _error = _apiError(context, e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = context.isAr ? widget.reason['label_ar'].toString() : widget.reason['label_en'].toString();
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: context.col.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.col.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.col.border)),
        );
    Text title(String t) => Text(t, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.col.ink1));

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface,
        elevation: 0,
        titleSpacing: 0,
        title: Text(label, style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
          Text(context.tr('الطلب رقم ${widget.orderNumber}', 'Order ${widget.orderNumber}'),
              style: TextStyle(fontSize: 12.5, color: context.col.ink2)),
          const SizedBox(height: 14),
          if (_field == 'date') ...[
            title(context.tr('الموعد الذي يناسبك', 'The date that suits you')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(_date == null
                  ? context.tr('اختر التاريخ', 'Choose a date')
                  : '${_date!.day}/${_date!.month}/${_date!.year}'),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
          ],
          if (_field == 'address') ...[
            title(context.tr('العنوان الجديد', 'The new address')),
            const SizedBox(height: 8),
            if (_addresses == null)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: AppColors.primary)))
            else ...[
              for (final a in _addresses!)
                RadioListTile<int>(
                  value: a['id'] as int,
                  groupValue: _addressId,
                  onChanged: (v) => setState(() { _addressId = v; _error = null; }),
                  title: Text(_addressText(a), style: const TextStyle(fontSize: 13.5)),
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                ),
              RadioListTile<int>(
                value: -1,
                groupValue: _addressId,
                onChanged: (v) => setState(() { _addressId = v; _error = null; }),
                title: Text(context.tr('عنوان آخر', 'Another address'), style: const TextStyle(fontSize: 13.5)),
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
              ),
              if (_addressId == -1)
                TextField(controller: _otherAddress, maxLines: 2, maxLength: 500,
                    decoration: deco(context.tr('المدينة، المنطقة، الشارع، أقرب معلم', 'City, area, street, nearest landmark'))),
            ],
            const SizedBox(height: 12),
          ],
          if (_field == 'phone') ...[
            title(context.tr('رقم الهاتف الجديد', 'The new phone number')),
            const SizedBox(height: 8),
            TextField(controller: _phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr,
                decoration: deco('09XXXXXXXX')),
            const SizedBox(height: 16),
          ],
          title(_detailsRequired
              ? context.tr('اكتب لنا التفاصيل', 'Tell us the details')
              : context.tr('تفاصيل إضافية (اختياري)', 'More details (optional)')),
          const SizedBox(height: 8),
          TextField(controller: _details, maxLines: 4, maxLength: 1000,
              decoration: deco(context.tr('اكتب ما تريد أن نعرفه', 'Anything we should know'))),
          if (_photosAllowed) ...[
            const SizedBox(height: 6),
            title(context.tr('صور (اختياري، حتى 3)', 'Photos (optional, up to 3)')),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in _photos)
                Chip(
                  label: Text(p.name, overflow: TextOverflow.ellipsis),
                  onDeleted: () => setState(() => _photos = _photos.where((x) => x.path != p.path).toList()),
                ),
              if (_photos.length < 3)
                ActionChip(
                  avatar: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: Text(context.tr('أضف صورة', 'Add a photo')),
                  onPressed: _pickPhotos,
                ),
            ]),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _sending ? null : _submit,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(context.tr('إرسال الطلب', 'Send request'),
                      style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Her requests on this order, newest first, with our status and answer. Nothing shows
/// until she has filed one.
class HelpRequestsCard extends ConsumerWidget {
  final int orderId;
  const HelpRequestsCard({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(orderHelpProvider(orderId)).valueOrNull?['requests'] as List? ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    Color statusColor(String s) => switch (s) {
          'in_progress' => AppColors.warn,
          'resolved' => AppColors.success,
          'declined' => context.col.ink3,
          _ => AppColors.primary,
        };
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: context.col.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.col.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('طلباتك على هذا الطلب', 'Your requests on this order'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          for (final raw in list) ...[
            Divider(height: 20, color: context.col.border),
            Builder(builder: (context) {
              final r = Map<String, dynamic>.from(raw as Map);
              final status = r['status'].toString();
              final c = statusColor(status);
              final asked = r['requested_date'] ?? r['requested_address'] ?? r['requested_phone'];
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                      child: Text(context.isAr ? r['reason_ar'].toString() : r['reason_en'].toString(),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
                    child: Text(context.isAr ? r['status_ar'].toString() : r['status_en'].toString(),
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c)),
                  ),
                ]),
                if (asked != null) ...[
                  const SizedBox(height: 4),
                  Text(asked.toString(), style: TextStyle(fontSize: 12.5, color: context.col.ink2)),
                ],
                if ((r['details'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(r['details'].toString(), style: TextStyle(fontSize: 12.5, color: context.col.ink2)),
                ],
                if ((r['staff_reply'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10)),
                    child: Text('${context.tr('ردّ باهي', 'Baahy')}: ${r['staff_reply']}',
                        style: TextStyle(fontSize: 12.5, height: 1.45, color: context.col.ink0)),
                  ),
                ],
              ]);
            }),
          ],
        ]),
      ),
    );
  }
}
