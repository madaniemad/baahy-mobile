import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

/// Bank-transfer (LyPay / OnePay) instructions shown on an order that is awaiting
/// a manual transfer (payment_method == 'lypay' && status == 'pending_payment').
/// Lists our receiving accounts (copyable account # / IBAN) and an optional
/// receipt upload. The team confirms the transfer manually against the bank.
/// Mirrors the web `BankTransferCard`.
class BankTransferCard extends StatefulWidget {
  final int orderId;
  final double total;
  final bool alreadyUploaded;
  const BankTransferCard({
    required this.orderId,
    required this.total,
    this.alreadyUploaded = false,
    super.key,
  });

  @override
  State<BankTransferCard> createState() => _BankTransferCardState();
}

class _BankTransferCardState extends State<BankTransferCard> {
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;
  bool _uploading = false;
  late bool _uploaded = widget.alreadyUploaded;
  String? _copiedKey;

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    try {
      final r = await ApiClient.instance.dio.get('/bank-transfer-accounts');
      final list = (r.data['data'] as List?) ?? const [];
      if (mounted) {
        setState(() {
          _accounts = list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copy(String value, String key) {
    Clipboard.setData(ClipboardData(text: value.replaceAll(' ', '')));
    setState(() => _copiedKey = key);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && _copiedKey == key) setState(() => _copiedKey = null);
    });
  }

  Future<void> _uploadSlip() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.col.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: ctx.col.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: Text(ctx.tr('التقاط صورة', 'Take photo'),
              style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'])),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(ctx.tr('اختيار من المعرض', 'Choose from gallery'),
              style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'])),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (source == null || !mounted) return;

    final img = await picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
    if (img == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final form = FormData.fromMap({
        'slip': await MultipartFile.fromFile(img.path, filename: 'slip.jpg'),
      });
      await ApiClient.instance.dio.post('/orders/${widget.orderId}/payment-slip', data: form);
      if (mounted) setState(() => _uploaded = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('فشل رفع الإيصال، حاول مجدداً', 'Upload failed, try again'))));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Amber "pending" palette (fixed, semantic — not a theme accent), tuned for both modes.
    final bg     = dark ? const Color(0xFF241A06) : const Color(0xFFFFFBEB);
    final border = dark ? const Color(0xFF5A4410) : const Color(0xFFFDE68A);
    final ink    = dark ? const Color(0xFFFCD34D) : const Color(0xFF92400E);
    final body   = dark ? const Color(0xFFF0B429) : const Color(0xFFB45309);
    const btn    = Color(0xFFD97706);
    final amount = '${fmtPrice(widget.total)} ${context.s.lydUnit}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.account_balance_outlined, size: 19, color: ink),
          const SizedBox(width: 8),
          Expanded(child: Text(
            context.tr('أكمل التحويل المصرفي', 'Complete your bank transfer'),
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: ink,
              fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal']))),
        ]),
        const SizedBox(height: 8),
        Text.rich(TextSpan(
          style: TextStyle(fontSize: 13, height: 1.6, color: body,
            fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal']),
          children: [
            TextSpan(text: context.tr('حوّل مبلغ ', 'Transfer ')),
            TextSpan(text: amount, style: TextStyle(fontWeight: FontWeight.w800, color: ink)),
            TextSpan(text: context.tr(
              ' إلى أحد الحسابات أدناه، ثم ارفع صورة الإيصال. سنؤكد طلبك بعد وصول المبلغ.',
              ' to one of the accounts below, then upload your receipt. We’ll confirm your order once payment is received.')),
          ],
        )),
        const SizedBox(height: 14),

        if (_loading)
          Padding(padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(context.tr('جارٍ تحميل بيانات الحساب…', 'Loading account details…'),
              style: TextStyle(fontSize: 12.5, color: body)))
        else if (_accounts.isEmpty)
          Text(context.tr('ستظهر بيانات الحساب المصرفي هنا قريباً.', 'Bank account details will appear here shortly.'),
            style: TextStyle(fontSize: 12.5, color: body))
        else
          ..._accounts.asMap().entries.map((e) => Padding(
            padding: EdgeInsets.only(bottom: e.key == _accounts.length - 1 ? 0 : 11),
            child: _account(e.value, e.key, dark, border, btn),
          )),

        const SizedBox(height: 12),
        Text(context.tr(
          'حوّل إلى أيٍّ من الحسابين، وضع اسمك ورقم هاتفك في خانة الملاحظات عند التحويل.',
          'Transfer to any account, and add your name and phone number in the transfer notes.'),
          style: TextStyle(fontSize: 11.5, height: 1.55, color: body,
            fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'])),

        const SizedBox(height: 15),
        if (_uploaded)
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
            const SizedBox(width: 7),
            Flexible(child: Text(
              context.tr('تم رفع الإيصال — بانتظار التأكيد', 'Receipt uploaded — awaiting confirmation'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success,
                fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal']))),
          ])
        else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ElevatedButton.icon(
              onPressed: _uploading ? null : _uploadSlip,
              icon: _uploading
                ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.file_upload_outlined, size: 17, color: Colors.white),
              label: Text(
                _uploading ? context.tr('جارٍ الرفع…', 'Uploading…') : context.tr('رفع إيصال التحويل', 'Upload transfer receipt'),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white,
                  fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'])),
              style: ElevatedButton.styleFrom(
                backgroundColor: btn,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _account(Map<String, dynamic> a, int i, bool dark, Color border, Color btn) {
    final bank = (a['bank_name'] ?? '').toString();
    final name = (a['account_name'] ?? '').toString();
    final acc  = (a['account_number'] ?? '').toString();
    final iban = (a['iban'] ?? '').toString();
    final note = (a['note'] ?? '').toString();
    final logoUrl = (a['logo_url'] ?? '').toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: dark ? context.col.surface : Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: dark ? context.col.border : border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          if (logoUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(logoUrl, width: 34, height: 34, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.account_balance_outlined, size: 20, color: context.col.ink3)),
            ),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Text.rich(TextSpan(
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: context.col.ink0,
                fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal']),
              children: [
                TextSpan(text: bank),
                if (name.isNotEmpty) TextSpan(text: '  —  $name',
                  style: TextStyle(fontWeight: FontWeight.w600, color: context.col.ink2, fontSize: 12)),
              ],
            )),
          ),
        ]),
        _copyRow(context.tr('رقم الحساب', 'Account #'), acc, 'acc-$i', btn),
        if (iban.isNotEmpty) _copyRow('IBAN', iban, 'iban-$i', btn),
        if (note.isNotEmpty) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(note, style: TextStyle(fontSize: 11.5, color: context.col.ink3,
            fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal']))),
      ]),
    );
  }

  Widget _copyRow(String label, String value, String key, Color btn) {
    final copied = _copiedKey == key;
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: context.col.ink3,
            fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'])),
          const SizedBox(height: 3),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(value,
              style: TextStyle(fontSize: 12.5, height: 1.35, color: context.col.ink0,
                letterSpacing: 0.2, fontFeatures: const [FontFeature.tabularFigures()],
                fontFamily: 'PlusJakartaSans', fontFamilyFallback: const ['Manrope'])),
          ),
        ])),
        const SizedBox(width: 8),
        InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => _copy(value, key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: copied ? AppColors.success.withValues(alpha: 0.5) : btn.withValues(alpha: 0.45)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(copied ? Icons.check_rounded : Icons.copy_rounded, size: 13,
                color: copied ? AppColors.success : btn),
              const SizedBox(width: 5),
              Text(copied ? context.tr('تم النسخ', 'Copied') : context.tr('نسخ', 'Copy'),
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                  color: copied ? AppColors.success : btn,
                  fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'])),
            ]),
          ),
        ),
      ]),
    );
  }
}
