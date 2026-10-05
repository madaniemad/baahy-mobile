import 'package:flutter/material.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

/// What a shopper can narrow a single store's products by.
class StoreFilters {
  final String sort; // API values: latest | popular | price_asc | price_desc
  final double? minPrice;
  final double? maxPrice;
  final bool onSaleOnly;

  const StoreFilters({
    this.sort = 'latest',
    this.minPrice,
    this.maxPrice,
    this.onSaleOnly = false,
  });

  /// True when anything differs from the untouched default (drives the dot on the button).
  bool get isActive =>
      sort != 'latest' || minPrice != null || maxPrice != null || onSaleOnly;
}

Future<StoreFilters?> showStoreFilterSheet(
    BuildContext context, StoreFilters initial) {
  return showModalBottomSheet<StoreFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.col.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _StoreFilterSheet(initial: initial),
  );
}

class _StoreFilterSheet extends StatefulWidget {
  final StoreFilters initial;
  const _StoreFilterSheet({required this.initial});

  @override
  State<_StoreFilterSheet> createState() => _StoreFilterSheetState();
}

class _StoreFilterSheetState extends State<_StoreFilterSheet> {
  late String _sort = widget.initial.sort;
  late bool _onSale = widget.initial.onSaleOnly;
  late final TextEditingController _min = TextEditingController(
      text: widget.initial.minPrice?.toStringAsFixed(0) ?? '');
  late final TextEditingController _max = TextEditingController(
      text: widget.initial.maxPrice?.toStringAsFixed(0) ?? '');

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  static const _font =
      TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal']);

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t,
            style: _font.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: context.col.ink0)),
      );

  Widget _priceField(TextEditingController c, String hint) => Expanded(
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          style: _font.copyWith(fontSize: 14, color: context.col.ink0),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.col.borderStrong),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.col.borderStrong),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.teal),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final sorts = [
      ('latest', s.sortLatest),
      ('popular', s.sortPopular),
      ('price_asc', s.sortPriceAsc),
      ('price_desc', s.sortPriceDesc),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(s.filters,
                    style: _font.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.col.ink0)),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(const StoreFilters()),
                child: Text(s.resetFilters),
              ),
            ]),
            _title(s.sortBy),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in sorts)
                  ChoiceChip(
                    label: Text(o.$2,
                        style: _font.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _sort == o.$1
                                ? AppColors.teal600
                                : context.col.ink0)),
                    selected: _sort == o.$1,
                    selectedColor: AppColors.teal.withValues(alpha: 0.15),
                    onSelected: (_) => setState(() => _sort = o.$1),
                  ),
              ],
            ),
            _title(s.priceRange),
            Row(children: [
              _priceField(_min, s.priceFrom),
              const SizedBox(width: 10),
              _priceField(_max, s.priceTo),
            ]),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.teal,
              title: Text(s.dealsOnly,
                  style: _font.copyWith(fontWeight: FontWeight.w700)),
              value: _onSale,
              onChanged: (v) => setState(() => _onSale = v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(StoreFilters(
                  sort: _sort,
                  minPrice: double.tryParse(_min.text.trim()),
                  maxPrice: double.tryParse(_max.text.trim()),
                  onSaleOnly: _onSale,
                )),
                child: Text(s.applyFilters,
                    style: _font.copyWith(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
