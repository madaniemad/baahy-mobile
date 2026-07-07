import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

// Provider returns {items, shippingCost}
final _orderDataProvider = FutureProvider.family<Map<String, dynamic>, int>(
  (ref, orderId) async {
    try {
      final res   = await ApiClient.instance.dio.get('/orders/$orderId');
      final order = res.data['data'];
      final groups = (order?['vendor_groups'] as List?) ?? [];
      final items  = <Map<String, dynamic>>[];
      for (final g in groups) {
        items.addAll(((g['items'] as List?) ?? []).map((i) => Map<String, dynamic>.from(i)));
      }
      return {
        'items':         items,
        'shipping_cost': _d(order?['shipping_cost']),
      };
    } catch (e, st) {
      debugPrint('[ReturnScreen] _orderDataProvider error for order $orderId: $e');
      Sentry.captureException(e, stackTrace: st);
      rethrow;
    }
  });

// Reason key definitions — order matters (free reasons first)
class _ReturnReason {
  final String key;
  final String labelAr;
  final String labelEn;
  final bool isFree;
  const _ReturnReason(this.key, this.labelAr, this.labelEn, this.isFree);
}

const _kReasons = [
  _ReturnReason('defective',        'المنتج وصل تالفاً',          'Product arrived damaged',        true),
  _ReturnReason('wrong_item',       'استلمت منتجاً خاطئاً',        'Received wrong item',            true),
  _ReturnReason('not_as_described', 'المنتج لا يطابق الوصف',       'Product does not match description', true),
  _ReturnReason('changed_mind',     'غيّرت رأيي',                  'Changed my mind',                false),
  _ReturnReason('quality_issue',    'مشكلة في الجودة',             'Quality issue',                  false),
  _ReturnReason('other',            'سبب آخر',                     'Other',                          false),
];

class ReturnScreen extends ConsumerStatefulWidget {
  final int orderId;
  final DateTime? returnDeadline;
  const ReturnScreen({required this.orderId, this.returnDeadline, super.key});

  @override
  ConsumerState<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends ConsumerState<ReturnScreen> {
  int _step = 0;
  // item_id → qty (0 = not selected)
  final Map<int, int> _selected = {};
  String? _reasonKey;
  final _notesCtrl = TextEditingController();
  final List<XFile> _images = [];
  bool _loading = false;

  // Populated from order data
  double _shippingCost = 0.0;
  List<Map<String, dynamic>> _items = [];

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _itemsValue {
    double total = 0;
    for (final item in _items) {
      final id  = item['id'] as int? ?? 0;
      final qty = _selected[id] ?? 0;
      if (qty > 0) {
        total += _d(item['price']) * qty;
      }
    }
    return total;
  }

  bool get _isFreeReturn =>
      _reasonKey != null && _kReasons.firstWhere(
        (r) => r.key == _reasonKey,
        orElse: () => const _ReturnReason('_unknown', '', '', true),
      ).isFree;

  double get _collectionFee => _isFreeReturn ? 0.0 : _shippingCost;
  double get _netRefund     => (_itemsValue - _collectionFee).clamp(0, double.infinity);
  bool   get _isBlocked     => !_isFreeReturn && _itemsValue > 0 && _itemsValue <= _collectionFee;

  void _toggleSelectAll() {
    final returnable = _items.where((item) {
      final maxQty = math.max(0, (item['quantity'] as int? ?? 1) - (item['returned_qty'] as int? ?? 0));
      return maxQty > 0;
    }).toList();
    final allSelected = returnable.isNotEmpty &&
        returnable.every((item) => (_selected[item['id'] as int? ?? 0] ?? 0) > 0);
    setState(() {
      for (final item in returnable) {
        _selected[item['id'] as int? ?? 0] = allSelected ? 0 : 1;
      }
    });
  }

  Future<void> _submit() async {
    if (_reasonKey == null) return;
    if (_isBlocked) return;
    if (widget.returnDeadline != null && DateTime.now().isAfter(widget.returnDeadline!)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          context.isAr ? 'انتهت فترة الإرجاع المسموح بها لهذا الطلب' : 'Return period has expired',
          style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal']))));
      return;
    }
    final items = _selected.entries
        .where((e) => e.value > 0)
        .map((e) => {'order_item_id': e.key, 'qty_returned': e.value})
        .toList();
    if (items.isEmpty) return;
    setState(() => _loading = true);
    try {
      final formData = FormData();
      formData.fields.add(MapEntry('order_id', widget.orderId.toString()));
      formData.fields.add(MapEntry('reason_key', _reasonKey!));
      formData.fields.add(MapEntry('description', _notesCtrl.text.trim()));
      for (var i = 0; i < items.length; i++) {
        formData.fields.add(MapEntry('items[$i][order_item_id]', items[i]['order_item_id'].toString()));
        formData.fields.add(MapEntry('items[$i][qty_returned]', items[i]['qty_returned'].toString()));
      }
      if (_images.isNotEmpty) {
        final files = await Future.wait(_images.map((f) async =>
            MultipartFile.fromFile(f.path, filename: f.name)));
        for (final f in files) {
          formData.files.add(MapEntry('images[]', f));
        }
      }
      await ApiClient.instance.dio.post('/returns', data: formData);
      if (mounted) setState(() { _loading = false; _step = 2; });
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      if (!mounted) return;
      String msg = context.isAr ? 'حدث خطأ، حاول مجدداً' : 'Error, please try again';
      // Extract Arabic error message from API if available
      if (e is DioException) {
        final apiMsg = e.response?.data?['message'] as String?;
        if (apiMsg != null && apiMsg.isNotEmpty) msg = apiMsg;
      }
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal']))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step < 2,
      child: Scaffold(
      backgroundColor: context.col.surface,
      appBar: AppBar(
        backgroundColor: context.col.surface, elevation: 0,
        leading: _step < 2
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              color: context.col.ink0,
              onPressed: () => _step == 0
                  ? Navigator.of(context).pop()
                  : setState(() => _step--))
          : const SizedBox.shrink(),
        title: Text(
          context.isAr
            ? ['اختر المنتجات', 'سبب الإرجاع', 'تم الإرسال'][_step]
            : ['Select Items', 'Return Reason', 'Done'][_step],
          style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          if (_step < 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Row(children: List.generate(2, (i) {
                final done   = _step > i;
                final active = _step == i;
                return Expanded(
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done || active ? context.col.ink0 : context.col.surfaceSoft,
                      ),
                      child: Center(
                        child: done
                          ? Icon(Icons.check, size: 14, color: context.col.bg)
                          : Text('${i + 1}',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.w800, fontSize: 12,
                                color: active ? context.col.bg : context.col.ink3)),
                      ),
                    ),
                    if (i < 1)
                      Expanded(child: Container(height: 2,
                        color: _step > 0 ? context.col.ink0 : context.col.border)),
                  ]),
                );
              })),
            ),

          if (widget.returnDeadline != null && _step < 2) ...[
            const SizedBox(height: 8),
            _ReturnPolicyBanner(deadline: widget.returnDeadline!),
          ],
          const SizedBox(height: 16),
          Expanded(child: _buildStep()),
        ],
      ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _StepItems(
          orderId: widget.orderId,
          selected: _selected,
          onToggle: (id, qty) => setState(() => _selected[id] = qty),
          onLoaded: (items, shippingCost) {
            _items        = items;
            _shippingCost = shippingCost;
          },
          onSelectAll: _toggleSelectAll,
          onNext: () {
            if (_selected.values.any((v) => v > 0)) setState(() => _step = 1);
          },
        );
      case 1:
        return _StepReason(
          reasonKey:       _reasonKey,
          notesCtrl:       _notesCtrl,
          images:          _images,
          loading:         _loading,
          itemsValue:      _itemsValue,
          collectionFee:   _collectionFee,
          netRefund:       _netRefund,
          isFree:          _isFreeReturn,
          isBlocked:       _isBlocked,
          onReasonChanged: (k) => setState(() => _reasonKey = k),
          onImagesChanged: (imgs) => setState(() {
            _images.clear();
            _images.addAll(imgs);
          }),
          onSubmit: _submit,
        );
      default:
        return _StepDone(isFreeReturn: _isFreeReturn);
    }
  }
}

// ── Return policy banner ──────────────────────────────────────────────────────

class _ReturnPolicyBanner extends StatelessWidget {
  final DateTime deadline;
  const _ReturnPolicyBanner({required this.deadline});

  @override
  Widget build(BuildContext context) {
    // Strip time so June 15 → June 20 = exactly 5, regardless of hour
    final today       = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
    final daysLeft    = deadlineDay.difference(today).inDays;

    final color = daysLeft <= 2 ? AppColors.danger : AppColors.primary;
    final dateStr = '${deadline.day}/${deadline.month}/${deadline.year}';
    final String label;
    if (daysLeft <= 0) {
      label = context.isAr ? 'آخر يوم للإرجاع — ينتهي $dateStr' : 'Last day to return — expires $dateStr';
    } else {
      label = context.isAr
        ? 'متبقٍ $daysLeft يوم للإرجاع — ينتهي $dateStr'
        : '$daysLeft day${daysLeft == 1 ? '' : 's'} left to return — deadline $dateStr';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(daysLeft <= 2 ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
          size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12, fontWeight: FontWeight.w600,
              color: color)),
        ),
      ]),
    );
  }
}

// ── Step 1: Select items ──────────────────────────────────────────────────────

class _StepItems extends ConsumerWidget {
  final int orderId;
  final Map<int, int> selected;
  final void Function(int id, int qty) onToggle;
  final void Function(List<Map<String, dynamic>> items, double shippingCost) onLoaded;
  final VoidCallback onSelectAll;
  final VoidCallback onNext;
  const _StepItems({required this.orderId, required this.selected,
    required this.onToggle, required this.onLoaded,
    required this.onSelectAll, required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_orderDataProvider(orderId));

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, __) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 40, color: context.col.ink3),
              const SizedBox(height: 12),
              Text(
                context.isAr ? 'فشل تحميل المنتجات' : 'Failed to load items',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], color: context.col.ink2)),
              const SizedBox(height: 4),
              Text(
                context.isAr ? 'تحقق من اتصالك وحاول مجدداً' : 'Check your connection and try again',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12, color: context.col.ink3)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(_orderDataProvider(orderId)),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(context.isAr ? 'إعادة المحاولة' : 'Retry',
                    style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'])),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
        )),
      data: (data) {
        final items        = (data['items'] as List).cast<Map<String, dynamic>>();
        final shippingCost = data['shipping_cost'] as double;
        // Notify parent once loaded
        WidgetsBinding.instance.addPostFrameCallback((_) => onLoaded(items, shippingCost));

        final returnableCount = items.where((item) {
          final maxQty = math.max(0, (item['quantity'] as int? ?? 1) - (item['returned_qty'] as int? ?? 0));
          return maxQty > 0;
        }).length;
        final allSelected = returnableCount > 0 && items.where((item) {
          final maxQty = math.max(0, (item['quantity'] as int? ?? 1) - (item['returned_qty'] as int? ?? 0));
          return maxQty > 0;
        }).every((item) => (selected[item['id'] as int? ?? 0] ?? 0) > 0);

        return Column(
          children: [
            // Select-all header
            if (returnableCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.isAr
                        ? '$returnableCount منتج متاح للإرجاع'
                        : '$returnableCount item${returnableCount == 1 ? '' : 's'} returnable',
                      style: TextStyle(
                        fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12.5,
                        color: context.col.ink2, fontWeight: FontWeight.w500),
                    ),
                    GestureDetector(
                      onTap: onSelectAll,
                      child: Text(
                        allSelected
                          ? (context.isAr ? 'إلغاء الكل' : 'Deselect all')
                          : (context.isAr ? 'اختر الكل' : 'Select all'),
                        style: const TextStyle(
                          fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13,
                          color: AppColors.primary, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: context.col.border),
                itemBuilder: (_, i) {
                  final item   = items[i];
                  final id     = item['id'] as int? ?? i;
                  final maxQty = math.max(0, (item['quantity'] as int? ?? 1) - (item['returned_qty'] as int? ?? 0));
                  final qty    = selected[id] ?? 0;
                  // Extract product image from nested product object or direct field
                  String? imageUrl = item['product_image'] as String?;
                  if (imageUrl == null) {
                    final prod = item['product'] as Map<String, dynamic>?;
                    final imgs = prod?['images'];
                    if (imgs is List && imgs.isNotEmpty) {
                      imageUrl = imgs.first.toString();
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      GestureDetector(
                        onTap: maxQty > 0 ? () => onToggle(id, qty > 0 ? 0 : 1) : null,
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: qty > 0 ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: qty > 0 ? AppColors.primary : context.col.borderStrong,
                              width: 1.5),
                          ),
                          child: qty > 0
                              ? Icon(Icons.check_rounded, size: 14, color: context.col.bg)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 48, height: 48,
                          child: imageUrl != null
                            ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover,
                                memCacheWidth: 96,
                                errorWidget: (_, __, ___) => Container(
                                  color: context.col.surfaceSoft,
                                  child: Icon(Icons.shopping_bag_outlined, size: 20, color: context.col.ink4)))
                            : Container(color: context.col.surfaceSoft,
                                child: Icon(Icons.shopping_bag_outlined, size: 20, color: context.col.ink4)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item['product_name'] ?? item['name'] ?? '',
                          style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w600)),
                        Text(
                          maxQty == 0
                            ? (context.isAr ? 'تم إرجاعه مسبقاً' : 'Already returned')
                            : (context.isAr ? 'الكمية: $maxQty' : 'Qty: $maxQty'),
                          style: TextStyle(
                            fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12,
                            color: maxQty == 0 ? AppColors.danger : context.col.ink3)),
                      ])),
                      if (qty > 0) Row(mainAxisSize: MainAxisSize.min, children: [
                        GestureDetector(
                          onTap: qty > 1 ? () => onToggle(id, qty - 1) : () => onToggle(id, 0),
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              border: Border.all(color: context.col.border),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.remove, size: 14, color: context.col.ink1),
                          ),
                        ),
                        Container(
                          width: 32,
                          alignment: Alignment.center,
                          child: Text('$qty',
                            style: const TextStyle(fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                        GestureDetector(
                          onTap: qty < maxQty ? () => onToggle(id, qty + 1) : null,
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: qty < maxQty ? context.col.border : context.col.border.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(12),
                              color: qty < maxQty ? null : context.col.surfaceSoft,
                            ),
                            child: Icon(Icons.add, size: 14,
                              color: qty < maxQty ? context.col.ink1 : context.col.ink4),
                          ),
                        ),
                      ]),
                    ]),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16,
                MediaQuery.of(context).padding.bottom + 16),
              child: AppButton(
                label: context.isAr ? 'التالي' : 'Next',
                onTap: onNext,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Step 2: Reason + fee preview + notes ──────────────────────────────────────

class _StepReason extends StatelessWidget {
  final String? reasonKey;
  final TextEditingController notesCtrl;
  final List<XFile> images;
  final bool loading;
  final double itemsValue;
  final double collectionFee;
  final double netRefund;
  final bool isFree;
  final bool isBlocked;
  final ValueChanged<String> onReasonChanged;
  final ValueChanged<List<XFile>> onImagesChanged;
  final VoidCallback onSubmit;

  const _StepReason({
    required this.reasonKey, required this.notesCtrl, required this.images,
    required this.loading, required this.itemsValue, required this.collectionFee,
    required this.netRefund, required this.isFree, required this.isBlocked,
    required this.onReasonChanged, required this.onImagesChanged, required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Text(isAr ? 'سبب الإرجاع' : 'Return Reason',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ..._kReasons.map((r) {
                final selected = reasonKey == r.key;
                return GestureDetector(
                  onTap: () => onReasonChanged(r.key),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : context.col.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppColors.primary : context.col.border,
                        width: selected ? 2 : 1),
                    ),
                    child: Row(children: [
                      Icon(
                        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 18, color: selected ? AppColors.primary : context.col.ink3),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(isAr ? r.labelAr : r.labelEn,
                          style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                            fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ]),
                  ),
                );
              }),

              // Fee shown only after admin reviews the return request
              if (reasonKey != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.col.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.col.border),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline_rounded, size: 15, color: context.col.ink2),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isAr
                            ? 'سيتم تحديد رسوم الاستلام وصافي الاسترداد بعد مراجعة الطلب من قِبل الفريق'
                            : 'Collection fee and net refund will be confirmed after admin reviews your request',
                        style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                          fontSize: 12, color: context.col.ink2, height: 1.4),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
              ],

              const SizedBox(height: 4),
              Text(isAr ? 'ملاحظات إضافية' : 'Additional Notes',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.col.ink1)),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: isAr ? 'صف المشكلة بمزيد من التفصيل...' : 'Describe the issue in more detail...',
                  hintStyle: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13, color: context.col.ink3),
                  filled: true, fillColor: context.col.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.col.border)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.col.border)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 16),
              Text(isAr ? 'صور المنتج' : 'Product Photos',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.col.ink1)),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickMultiImage(imageQuality: 70);
                        if (picked.isNotEmpty) {
                          final existingPaths = images.map((f) => f.path).toSet();
                          final newImages = picked.where((f) => !existingPaths.contains(f.path)).toList();
                          final merged = [...images, ...newImages];
                          onImagesChanged(merged.take(5).toList());
                        }
                      },
                      child: Container(
                        width: 80, height: 80,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: context.col.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.col.border),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                              size: 28, color: context.col.ink3),
                            const SizedBox(height: 4),
                            Text(isAr ? 'إضافة' : 'Add',
                              style: TextStyle(fontSize: 11, color: context.col.ink3)),
                          ],
                        ),
                      ),
                    ),
                    ...images.asMap().entries.map((e) => Stack(
                      children: [
                        Container(
                          width: 80, height: 80,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(File(e.value.path), fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 2, right: 10,
                          child: GestureDetector(
                            onTap: () {
                              final updated = List<XFile>.from(images)..removeAt(e.key);
                              onImagesChanged(updated);
                            },
                            child: Container(
                              width: 20, height: 20,
                              decoration: const BoxDecoration(
                                color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
          child: AppButton(
            label: isAr ? 'إرسال طلب الإرجاع' : 'Submit Return Request',
            loading: loading,
            onTap: (reasonKey != null && !isBlocked && !loading) ? onSubmit : null,
          ),
        ),
      ],
    );
  }
}

class _FeeLine extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  const _FeeLine({required this.label, required this.value, this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(
        fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13,
        color: context.col.ink2, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      Text(value, style: TextStyle(
        fontFamily: 'PlusJakartaSans', fontSize: 13,
        color: valueColor ?? context.col.ink0,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
    ],
  );
}

// ── Step 3: Done ──────────────────────────────────────────────────────────────

class _StepDone extends StatelessWidget {
  final bool isFreeReturn;
  const _StepDone({required this.isFreeReturn});

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
              border: Border.all(color: AppColors.primary, width: 3)),
            child: const Icon(Icons.check_rounded, size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(isAr ? 'تم إرسال طلب الإرجاع' : 'Return Request Submitted',
            style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            isAr
              ? 'سنراجع طلبك ونردّ خلال 24 ساعة. عند الموافقة، سيمرّ سائقنا لاستلام المنتجات من باب منزلك.'
              : 'We\'ll review and respond within 24 hours. Upon approval, our driver will pick up the items from your door.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.col.ink2, height: 1.5, fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal']),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.col.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.col.border),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(isAr ? 'طريقة الاسترداد' : 'Refund method',
                  style: TextStyle(fontSize: 12.5, color: context.col.ink2, fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'])),
                Text(
                  isFreeReturn
                      ? (isAr ? 'يدوي (يحدده الإدارة)' : 'Manual (admin decides)')
                      : (isAr ? 'رصيد المحفظة فوراً' : 'Wallet credit instantly'),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'])),
              ]),
            ]),
          ),
          const SizedBox(height: 32),
          AppButton(
            label: isAr ? 'تم' : 'Done',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
