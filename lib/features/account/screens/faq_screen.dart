import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_pages_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

class FaqScreen extends ConsumerWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pages = ref.watch(appPagesProvider);
    final items = pages.faqItems;

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back, color: context.col.ink0),
        ),
        title: Text(context.s.faqTitle,
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      ),
      body: items.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _FaqTile(item: items[i]),
            ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final Map<String, String> item;
  const _FaqTile({required this.item});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _open ? context.col.borderStrong : context.col.border),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Expanded(
                  child: Text(context.isAr ? (widget.item['q_ar'] ?? widget.item['q'] ?? '') : (widget.item['q_en']?.isNotEmpty == true ? widget.item['q_en']! : (widget.item['q_ar'] ?? widget.item['q'] ?? '')),
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5)),
                ),
                Icon(
                  _open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: context.col.ink2, size: 20,
                ),
              ]),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(context.isAr ? (widget.item['a_ar'] ?? widget.item['a'] ?? '') : (widget.item['a_en']?.isNotEmpty == true ? widget.item['a_en']! : (widget.item['a_ar'] ?? widget.item['a'] ?? '')),
                  style: TextStyle(
                      fontSize: 13, color: context.col.ink2, height: 1.65)),
            ),
        ],
      ),
    );
  }
}
