/// Product family (2026-11-15): the same item in other colours / capacities / models / volumes /
/// sizes. Each option is a SEPARATE product (own price, stock, photos, cart line); choosing one
/// opens that product. Not a variation — the size picker and the cart are untouched.
/// From GET /api/products/{id} → `family`.
class ProductFamily {
  final int id;
  final List<ProductFamilyAxis> axes;
  const ProductFamily({required this.id, required this.axes});

  static ProductFamily? tryParse(dynamic j) {
    if (j is! Map) return null;
    final axes = (j['axes'] as List? ?? [])
        .whereType<Map>()
        .map((a) => ProductFamilyAxis.fromJson(Map<String, dynamic>.from(a)))
        .where((a) => a.options.isNotEmpty)
        .toList();
    if (axes.isEmpty) return null;
    return ProductFamily(id: (j['id'] as num?)?.toInt() ?? 0, axes: axes);
  }
}

class ProductFamilyAxis {
  final String key;
  final String labelAr;
  final String labelEn;
  /// 'swatch' = the member's photo; 'chips' = text buttons.
  final String display;
  final String? selectedAr;
  final String? selectedEn;
  final List<ProductFamilyOption> options;
  const ProductFamilyAxis({
    required this.key,
    required this.labelAr,
    required this.labelEn,
    required this.display,
    this.selectedAr,
    this.selectedEn,
    required this.options,
  });

  bool get isSwatch => display == 'swatch';
  String label(bool isAr) => isAr ? labelAr : labelEn;
  String? selected(bool isAr) => isAr ? selectedAr : (selectedEn ?? selectedAr);

  factory ProductFamilyAxis.fromJson(Map<String, dynamic> j) => ProductFamilyAxis(
        key: j['key']?.toString() ?? '',
        labelAr: j['label_ar']?.toString() ?? '',
        labelEn: j['label_en']?.toString() ?? '',
        display: j['display']?.toString() ?? 'chips',
        selectedAr: j['selected_ar']?.toString(),
        selectedEn: j['selected_en']?.toString(),
        options: (j['options'] as List? ?? [])
            .whereType<Map>()
            .map((o) => ProductFamilyOption.fromJson(Map<String, dynamic>.from(o)))
            .where((o) => o.productId > 0)
            .toList(),
      );
}

class ProductFamilyOption {
  final String valueAr;
  final String valueEn;
  final int productId;
  final String? image;
  final double currentPrice;
  final bool inStock;
  final bool selected;
  const ProductFamilyOption({
    required this.valueAr,
    required this.valueEn,
    required this.productId,
    this.image,
    required this.currentPrice,
    required this.inStock,
    required this.selected,
  });

  String value(bool isAr) => isAr ? valueAr : (valueEn.isNotEmpty ? valueEn : valueAr);

  static double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  factory ProductFamilyOption.fromJson(Map<String, dynamic> j) => ProductFamilyOption(
        valueAr: j['value_ar']?.toString() ?? '',
        valueEn: j['value_en']?.toString() ?? '',
        productId: (j['product_id'] as num?)?.toInt() ?? 0,
        image: j['image']?.toString(),
        currentPrice: _d(j['current_price']),
        inStock: j['in_stock'] == true || j['in_stock'] == 1,
        selected: j['selected'] == true,
      );
}
