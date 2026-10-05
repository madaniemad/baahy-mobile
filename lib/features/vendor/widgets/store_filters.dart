import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

/// What a shopper can narrow a single store's products by.
class StoreFilters {
  final String sort; // API values: latest | popular | price_asc | price_desc
  final double? minPrice;
  final double? maxPrice;
  final bool onSaleOnly;
  final int? minRating;
  final Set<String> brands;
  final Set<int> attributeValueIds;

  const StoreFilters({
    this.sort = 'latest',
    this.minPrice,
    this.maxPrice,
    this.onSaleOnly = false,
    this.minRating,
    this.brands = const {},
    this.attributeValueIds = const {},
  });

  /// True when anything differs from the untouched default (drives the dot on the button).
  bool get isActive =>
      sort != 'latest' ||
      minPrice != null ||
      maxPrice != null ||
      onSaleOnly ||
      minRating != null ||
      brands.isNotEmpty ||
      attributeValueIds.isNotEmpty;
}

class _AttrValue {
  final int id;
  final String value;
  final String valueAr;
  final Color? color;
  const _AttrValue(this.id, this.value, this.valueAr, this.color);
}

class _AttrType {
  final String name;
  final String nameAr;
  final List<_AttrValue> values;
  const _AttrType(this.name, this.nameAr, this.values);
}

/// The options that exist among THIS store's products (and the open category), so the sheet
/// never offers a size, colour or brand the shopper could not find on the page.
class _StoreOptions {
  final List<_AttrType> attrTypes;
  final List<String> brands;
  final bool hasReviews;
  const _StoreOptions(this.attrTypes, this.brands, this.hasReviews);
}

Future<_StoreOptions> _loadOptions(int vendorId, int? categoryId) async {
  final res = await ApiClient.instance.dio
      .get('/products/filter-options', queryParameters: {
    'vendor_id': vendorId,
    if (categoryId != null) 'category_id': categoryId,
  });
  final data = res.data['data'] as Map;
  final types = <_AttrType>[];
  for (final t in (data['attribute_types'] as List? ?? [])) {
    final name = (t['name'] ?? '').toString();
    final nameAr = (t['name_ar'] ?? '').toString();
    // Brand has its own section below.
    if (name.toLowerCase().contains('brand') || nameAr.contains('ماركة')) {
      continue;
    }
    final values = <_AttrValue>[];
    for (final v in (t['values'] as List? ?? [])) {
      Color? color;
      final hex = v['color_hex']?.toString();
      if (t['display_type'] == 'color' && hex != null && hex.isNotEmpty) {
        try {
          color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
        } catch (_) {}
      }
      values.add(_AttrValue(v['id'] as int, (v['value'] ?? '').toString(),
          (v['value_ar'] ?? '').toString(), color));
    }
    if (values.isNotEmpty) types.add(_AttrType(name, nameAr, values));
  }
  return _StoreOptions(
    types,
    (data['brands'] as List? ?? []).map((b) => b.toString()).toList(),
    data['has_reviews'] == true,
  );
}

Future<StoreFilters?> showStoreFilterSheet(
    BuildContext context, StoreFilters initial,
    {required int vendorId, int? categoryId}) {
  return showModalBottomSheet<StoreFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.col.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
    ),
    builder: (_) => _StoreFilterSheet(
        initial: initial, vendorId: vendorId, categoryId: categoryId),
  );
}

class _StoreFilterSheet extends StatefulWidget {
  final StoreFilters initial;
  final int vendorId;
  final int? categoryId;
  const _StoreFilterSheet(
      {required this.initial, required this.vendorId, this.categoryId});

  @override
  State<_StoreFilterSheet> createState() => _StoreFilterSheetState();
}

class _StoreFilterSheetState extends State<_StoreFilterSheet> {
  late String _sort = widget.initial.sort;
  late bool _onSale = widget.initial.onSaleOnly;
  late int? _rating = widget.initial.minRating;
  late final Set<String> _brands = {...widget.initial.brands};
  late final Set<int> _attrIds = {...widget.initial.attributeValueIds};
  late final Future<_StoreOptions?> _options =
      _loadOptions(widget.vendorId, widget.categoryId)
          .then<_StoreOptions?>((o) => o)
          .catchError((_) => null);
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

  Widget _chip(String label, bool sel, VoidCallback onTap,
          {TextDirection? dir, Widget? leading}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? AppColors.teal.withValues(alpha: 0.15) : context.col.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: sel ? AppColors.teal : context.col.border, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (leading != null) ...[leading, const SizedBox(width: 4)],
            Text(label,
                textDirection: dir,
                style: _font.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: sel ? AppColors.teal600 : context.col.ink1)),
          ]),
        ),
      );

  List<Widget> _optionSections(_StoreOptions o) {
    final isAr = context.isAr;
    return [
      for (final t in o.attrTypes) ...[
        _title(isAr && t.nameAr.isNotEmpty ? t.nameAr : t.name),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in t.values)
            if (v.color != null)
              GestureDetector(
                onTap: () => setState(() =>
                    _attrIds.contains(v.id) ? _attrIds.remove(v.id) : _attrIds.add(v.id)),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: v.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _attrIds.contains(v.id)
                            ? context.col.ink0
                            : context.col.border,
                        width: _attrIds.contains(v.id) ? 2.5 : 1.5),
                  ),
                ),
              )
            else
              _chip(
                isAr && v.valueAr.isNotEmpty ? v.valueAr : v.value,
                _attrIds.contains(v.id),
                () => setState(() =>
                    _attrIds.contains(v.id) ? _attrIds.remove(v.id) : _attrIds.add(v.id)),
                // Latin/numeric sizes ("7-8 Years") must not be reversed by RTL bidi.
                dir: t.name.toLowerCase().contains('size') ? TextDirection.ltr : null,
              ),
        ]),
      ],
      if (o.brands.isNotEmpty) ...[
        _title(context.s.brand),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final b in o.brands)
            _chip(b, _brands.contains(b),
                () => setState(() => _brands.contains(b) ? _brands.remove(b) : _brands.add(b)),
                dir: TextDirection.ltr),
        ]),
      ],
      if (o.hasReviews) ...[
        _title(context.tr('الحد الأدنى للتقييم', 'Min. rating')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final star in const [3, 4, 5])
            _chip(
              '$star+',
              _rating == star,
              () => setState(() => _rating = _rating == star ? null : star),
              leading: const Icon(Icons.star_rounded, size: 15, color: AppColors.gold),
            ),
        ]),
      ],
    ];
  }

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
            FutureBuilder<_StoreOptions?>(
              future: _options,
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final o = snap.data;
                if (o == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _optionSections(o),
                );
              },
            ),
            const SizedBox(height: 16),
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
                  minRating: _rating,
                  brands: {..._brands},
                  attributeValueIds: {..._attrIds},
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
