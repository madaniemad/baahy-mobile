import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';

final _orderItemsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>(
  (ref, orderId) async {
    final res = await ApiClient.instance.dio.get('/orders/$orderId');
    final items = (res.data['data']?['items'] as List?) ?? [];
    return items.map((i) => Map<String, dynamic>.from(i)).toList();
  });

const _kReasonsAr = [
  'المنتج وصل تالفاً',
  'المنتج لا يطابق الوصف',
  'استلمت منتجاً خاطئاً',
  'لم يعجبني المنتج',
  'مشكلة في الجودة',
  'أخرى',
];
const _kReasonsEn = [
  'Product arrived damaged',
  'Product does not match description',
  'Received wrong item',
  'Not satisfied with the product',
  'Quality issue',
  'Other',
];

class ReturnScreen extends ConsumerStatefulWidget {
  final int orderId;
  const ReturnScreen({required this.orderId, super.key});

  @override
  ConsumerState<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends ConsumerState<ReturnScreen> {
  int _step = 0;
  final Map<int, bool> _selected = {};
  String? _reason;
  final _notesCtrl = TextEditingController();
  final List<XFile> _images = [];
  bool _loading = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) return;
    final items = _selected.entries
        .where((e) => e.value)
        .map((e) => {'order_item_id': e.key})
        .toList();
    setState(() => _loading = true);
    try {
      final formData = FormData.fromMap({
        'items': items.map((i) => i['order_item_id'].toString()).join(','),
        'reason': _reason,
        'notes': _notesCtrl.text.trim(),
        if (_images.isNotEmpty)
          'images[]': await Future.wait(_images.map((f) async =>
            MultipartFile.fromFile(f.path, filename: f.name))),
      });
      await ApiClient.instance.dio.post(
        '/orders/${widget.orderId}/returns',
        data: formData,
      );
      if (mounted) setState(() => _step = 2);
    } catch (_) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.s.errorTryAgain)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: _step < 2
          ? IconButton(
              icon: Icon(_step == 0 ? Icons.arrow_back : Icons.arrow_back),
              onPressed: () => _step == 0
                  ? Navigator.of(context).pop()
                  : setState(() => _step--))
          : const SizedBox.shrink(),
        title: Text(
          context.isAr
            ? ['اختر المنتجات', 'سبب الإرجاع', 'تم الإرسال'][_step]
            : ['Select Items', 'Return Reason', 'Done'][_step],
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          // Step indicator
          if (_step < 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Row(children: List.generate(2, (i) {
                final done = _step > i;
                final active = _step == i;
                return Expanded(
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done || active ? AppColors.ink0 : AppColors.surfaceSoft,
                      ),
                      child: Center(
                        child: done
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : Text('${i + 1}',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.w800, fontSize: 12,
                                color: active ? Colors.white : AppColors.ink3)),
                      ),
                    ),
                    if (i < 1)
                      Expanded(child: Container(height: 2,
                        color: _step > 0 ? AppColors.ink0 : AppColors.border)),
                  ]),
                );
              })),
            ),

          const SizedBox(height: 16),
          Expanded(child: _buildStep()),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _StepItems(
          orderId: widget.orderId,
          selected: _selected,
          onToggle: (id, val) => setState(() => _selected[id] = val),
          onNext: () {
            if (_selected.values.any((v) => v)) setState(() => _step = 1);
          },
        );
      case 1:
        return _StepReason(
          reason: _reason,
          notesCtrl: _notesCtrl,
          images: _images,
          loading: _loading,
          onReasonChanged: (r) => setState(() => _reason = r),
          onImagesChanged: (imgs) => setState(() {
            _images.clear();
            _images.addAll(imgs);
          }),
          onSubmit: _submit,
        );
      default:
        return _StepDone(orderId: widget.orderId);
    }
  }
}

// ── Step 1: Select items ──────────────────────────────────────────────────────

class _StepItems extends ConsumerWidget {
  final int orderId;
  final Map<int, bool> selected;
  final void Function(int id, bool val) onToggle;
  final VoidCallback onNext;
  const _StepItems({required this.orderId, required this.selected,
    required this.onToggle, required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(_orderItemsProvider(orderId));

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, __) => Center(child: Text(context.s.loadReturnFailed)),
      data: (items) => Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) {
                final item = items[i];
                final id = item['id'] as int? ?? i;
                final isChecked = selected[id] ?? false;
                return CheckboxListTile(
                  value: isChecked,
                  onChanged: (v) => onToggle(id, v ?? false),
                  activeColor: AppColors.primary,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  title: Text(item['product_name'] ?? item['name'] ?? '',
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                  subtitle: Text(context.s.quantityN(item['quantity'] as int? ?? 1),
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.ink3)),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16,
              MediaQuery.of(context).padding.bottom + 16),
            child: AppButton(
              label: context.s.next,
              onTap: onNext,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 2: Reason + notes ────────────────────────────────────────────────────

class _StepReason extends StatelessWidget {
  final String? reason;
  final TextEditingController notesCtrl;
  final List<XFile> images;
  final bool loading;
  final ValueChanged<String> onReasonChanged;
  final ValueChanged<List<XFile>> onImagesChanged;
  final VoidCallback onSubmit;
  const _StepReason({required this.reason, required this.notesCtrl,
    required this.images, required this.loading,
    required this.onReasonChanged, required this.onImagesChanged, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Text(context.s.returnReason,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...(context.isAr ? _kReasonsAr : _kReasonsEn).map((r) => GestureDetector(
                onTap: () => onReasonChanged(r),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: reason == r
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: reason == r ? AppColors.primary : AppColors.border,
                      width: reason == r ? 2 : 1),
                  ),
                  child: Row(children: [
                    Icon(
                      reason == r ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 18, color: reason == r ? AppColors.primary : AppColors.ink3),
                    const SizedBox(width: 10),
                    Text(r, style: const TextStyle(fontFamily: 'Cairo',
                      fontWeight: FontWeight.w600, fontSize: 14)),
                  ]),
                ),
              )),
              const SizedBox(height: 8),
              Text(context.s.additionalNotes,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink1)),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: context.isAr ? 'صف المشكلة بمزيد من التفصيل...' : 'Describe the issue in more detail...',
                  hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.ink3),
                  filled: true, fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 16),
              Text(context.s.productPhotos,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink1)),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Add photo button
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickMultiImage(imageQuality: 70);
                        if (picked.isNotEmpty) {
                          final merged = [...images, ...picked];
                          onImagesChanged(merged.take(5).toList());
                        }
                      },
                      child: Container(
                        width: 80, height: 80,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined,
                              size: 28, color: AppColors.ink3),
                            const SizedBox(height: 4),
                            Text(context.s.addPhoto, style: const TextStyle(fontSize: 11, color: AppColors.ink3)),
                          ],
                        ),
                      ),
                    ),
                    ...images.asMap().entries.map((e) => Stack(
                      children: [
                        Container(
                          width: 80, height: 80,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
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
            label: context.isAr ? 'إرسال طلب الإرجاع' : 'Submit Return Request',
            loading: loading,
            onTap: reason != null ? onSubmit : null,
          ),
        ),
      ],
    );
  }
}

// ── Step 3: Done ──────────────────────────────────────────────────────────────

class _StepDone extends StatelessWidget {
  final int orderId;
  const _StepDone({required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF5F5F5),
              border: Border.all(color: AppColors.primary, width: 3)),
            child: const Icon(Icons.check_rounded,
              size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(context.s.returnSubmitted,
            style: const TextStyle(fontFamily: 'Cairo',
              fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            context.isAr
              ? 'سنراجع ونردّ خلال 24 ساعة. عند الموافقة، سيمرّ سائقنا لاستلام المنتجات من باب منزلك.'
              : 'We\'ll review and respond within 24 hours. Upon approval, our driver will pick up the items from your door.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.ink2, height: 1.5),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(context.s.refundTo,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.ink2)),
                Text(context.s.baahyWalletInstant,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
          const SizedBox(height: 32),
          AppButton(
            label: context.s.done,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
