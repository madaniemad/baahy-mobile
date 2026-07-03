part of '../screens/product_detail_screen.dart';


// ── Stock + ETA strip ─────────────────────────────────────────────────────────

class _StockEtaStrip extends StatelessWidget {
  final Product product;
  final String deliveryPromise;
  const _StockEtaStrip({required this.product, required this.deliveryPromise});

  @override
  Widget build(BuildContext context) {
    final lowStock = product.inStock &&
        product.manageStock &&
        product.productType != 'variable' &&
        product.stockQuantity != null &&
        product.stockQuantity! > 0 &&
        product.stockQuantity! <= 5;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.col.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(children: [
            Icon(
              product.inStock
                  ? (lowStock ? Icons.local_fire_department_rounded : Icons.check_circle_rounded)
                  : Icons.info_rounded,
              size: 16,
              color: product.inStock
                  ? (lowStock ? AppColors.warn : AppColors.success)
                  : AppColors.danger,
            ),
            const SizedBox(width: 8),
            Text(
              product.inStock
                  ? (lowStock
                      ? context.s.lowStockN(product.stockQuantity!)
                      : context.s.inStock)
                  : context.s.outOfStock,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: product.inStock
                    ? (lowStock ? AppColors.warn : AppColors.success)
                    : AppColors.danger,
              ),
            ),
          ]),
          if (product.inStock) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: context.col.border),
            const SizedBox(height: 10),
            if (product.fulfilledByBaahy)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.bolt_rounded, size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(context.s.deliveredDirect,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                    ]),
                  ),
                ]),
              ),
            Row(children: [
              const Icon(Icons.local_shipping_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(deliveryPromise,
                  style: TextStyle(fontSize: 12.5,
                    fontWeight: FontWeight.w600, color: context.col.ink1)),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

// ── Delivery date helpers ─────────────────────────────────────────────────────

DateTime _nextWorkingDay(DateTime date) {
  while (date.weekday == DateTime.friday) {
    date = date.add(const Duration(days: 1));
  }
  return date;
}

DateTime _addWorkingDays(DateTime date, int n) {
  for (int i = 0; i < n; i++) {
    date = date.add(const Duration(days: 1));
    date = _nextWorkingDay(date);
  }
  return date;
}

(DateTime, DateTime) _deliveryRange(int etaMin, int etaMax) {
  final now = DateTime.now();
  final DateTime start;
  if (now.weekday == DateTime.friday || now.hour >= 16) {
    start = _nextWorkingDay(now.add(const Duration(days: 1)));
  } else {
    start = now;
  }
  final earliest = _addWorkingDays(start, etaMin - 1);
  final latest   = _addWorkingDays(start, etaMax - 1);
  return (earliest, latest);
}

String _formatDeliveryDay(DateTime date, bool isAr) {
  final now   = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d     = DateTime(date.year, date.month, date.day);
  if (isAr) {
    if (d == today) return 'اليوم';
    if (d == today.add(const Duration(days: 1))) return 'غداً';
    const names = ['', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', '', 'السبت', 'الأحد'];
    return names[date.weekday];
  } else {
    if (d == today) return 'Today';
    if (d == today.add(const Duration(days: 1))) return 'Tomorrow';
    const names = ['', 'Mon', 'Tue', 'Wed', 'Thu', '', 'Sat', 'Sun'];
    return names[date.weekday];
  }
}

// ── Trust block ───────────────────────────────────────────────────────────────

class _TrustBlock extends ConsumerWidget {
  final AppConfig config;
  const _TrustBlock({required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = context.isAr;
    final cityRate = ref.watch(cityShippingRateProvider);
    final paymentLabels = config.paymentMethods
        .where((m) => m.enabled)
        .map((m) => isAr ? m.labelAr : (m.labelEn.isNotEmpty ? m.labelEn : m.labelAr))
        .join(' · ');

    // Compute actual delivery arrival dates for the user's city
    String deliveryText;
    if (cityRate != null) {
      final etaMin = cityRate.etaMin ?? cityRate.deliveryDays;
      final etaMax = cityRate.etaMax ?? (cityRate.etaMin ?? cityRate.deliveryDays);
      final cityName = isAr ? cityRate.cityAr : cityRate.city;
      final (earliest, latest) = _deliveryRange(etaMin, etaMax);
      final earliestStr = _formatDeliveryDay(earliest, isAr);
      final latestStr   = _formatDeliveryDay(latest, isAr);
      final sameDay = DateTime(earliest.year, earliest.month, earliest.day) ==
                      DateTime(latest.year, latest.month, latest.day);
      if (sameDay) {
        deliveryText = isAr ? 'يصل $earliestStr · $cityName' : 'Arrives $earliestStr · $cityName';
      } else {
        deliveryText = isAr
            ? 'يصل $earliestStr – $latestStr · $cityName'
            : 'Arrives $earliestStr – $latestStr · $cityName';
      }
    } else {
      deliveryText = isAr ? 'توصيل سريع في معظم المدن' : 'Fast delivery across most cities';
    }

    final rows = [
      (Icons.local_shipping_outlined, deliveryText),
      (Icons.refresh_rounded, isAr
          ? 'إرجاع خلال ${config.returnDays} أيام · من باب منزلك'
          : 'Returns within ${config.returnDays} days · From your door'),
      (Icons.credit_card_outlined, paymentLabels.isNotEmpty
          ? paymentLabels : (isAr ? 'الدفع عند الاستلام' : 'Cash on Delivery')),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border),
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.inventory_2_outlined,
                  size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.s.soldByBaahy,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  Text(context.s.qualityChecked,
                    style: TextStyle(fontSize: 11.5, color: context.col.ink3)),
                ],
              )),
            ]),
          ),
          Divider(height: 1, color: context.col.border),
          ...rows.map((row) => Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(row.$1, size: 20, color: context.col.ink2),
                const SizedBox(width: 12),
                Expanded(child: Text(row.$2,
                  style: TextStyle(fontSize: 13, color: context.col.ink1))),
              ]),
            ),
            if (row != rows.last) Divider(height: 1, color: context.col.border),
          ])),
        ],
      ),
    );
  }
}

// ── Frequently bought together ────────────────────────────────────────────────

class _FrequentlyBoughtTogether extends ConsumerStatefulWidget {
  final Product mainProduct;
  final int categoryId;
  final bool lazyLoad;
  const _FrequentlyBoughtTogether({required this.mainProduct, required this.categoryId, this.lazyLoad = false});
  @override
  ConsumerState<_FrequentlyBoughtTogether> createState() => _FBTState();
}

class _FBTState extends ConsumerState<_FrequentlyBoughtTogether> {
  late Map<int, bool> _checked;

  @override
  void initState() {
    super.initState();
    _checked = {widget.mainProduct.id: true};
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.lazyLoad) return const SizedBox.shrink();
    // Use parent category to get sister-category products; fall back to same category
    final parentId = widget.mainProduct.category?.parentId;
    final relatedAsync = parentId != null
        ? ref.watch(_sisterProductsProvider(parentId))
        : ref.watch(_relatedProductsProvider(widget.categoryId));

    return relatedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (related) {
        final mainCatId = widget.mainProduct.category?.id;
        final notMain = related.where((p) => p.id != widget.mainProduct.id).toList();
        final sisters = notMain.where((p) => p.category?.id != mainCatId).toList();
        // Prefer sister-category products; fall back to any product in parent category
        final others = (sisters.isNotEmpty ? sisters : notMain).take(2).toList();
        if (others.isEmpty) return const SizedBox.shrink();

        final all = [widget.mainProduct, ...others];
        // Initialize checked for new items
        for (final p in all) {
          _checked.putIfAbsent(p.id, () => true);
        }

        final selected = all.where((p) => _checked[p.id] == true).toList();
        final total = selected.fold(0.0, (s, p) => s + p.displayPrice);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.isAr ? 'منتجات مكملة' : 'Complete the Look',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),

              // Image stack with + signs
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < all.length; i++) ...[
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _checked[all[i].id] == true
                              ? AppColors.primary : context.col.border,
                          width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Opacity(
                        opacity: _checked[all[i].id] == true ? 1 : 0.3,
                        child: all[i].firstImage != null
                            ? CachedNetworkImage(
                                imageUrl: all[i].firstImage!, fit: BoxFit.cover,
                                memCacheWidth: 240)
                            : Container(color: context.col.surfaceSoft),
                      ),
                    ),
                    if (i < all.length - 1)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.add, size: 16, color: context.col.ink3),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Checkbox list
              Container(
                decoration: BoxDecoration(
                  color: context.col.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.col.border),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < all.length; i++) ...[
                      GestureDetector(
                        onTap: i == 0 ? null : () =>
                          setState(() => _checked[all[i].id] = !(_checked[all[i].id] ?? true)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(children: [
                            Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: _checked[all[i].id] == true ? context.col.ink0 : context.col.surface,
                                border: _checked[all[i].id] == true
                                    ? null : Border.all(color: context.col.borderStrong, width: 1.8),
                              ),
                              child: _checked[all[i].id] == true
                                  ? Icon(Icons.check, size: 13, color: context.col.bg)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (i == 0 ? (context.isAr ? 'هذا المنتج: ' : 'This product: ') : '') +
                                  (context.isAr ? all[i].nameAr : all[i].name),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                                Text('${fmtPrice(all[i].displayPrice)} ${context.s.lydUnit}',
                                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                    fontSize: 13, fontWeight: FontWeight.w700)),
                              ],
                            )),
                          ]),
                        ),
                      ),
                      if (i < all.length - 1) Divider(height: 1, color: context.col.border),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.s.totalForN(selected.length),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('${fmtPrice(total)} ${context.s.lydUnit}',
                    style: const TextStyle(fontFamily: 'PlusJakartaSans',
                      fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: selected.length < 2 ? null : () {
                    for (final p in selected.where((p) => p.id != widget.mainProduct.id)) {
                      ref.read(cartProvider.notifier).add(p);
                    }
                    safePush(context, '/cart');
                  },
                  icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                  label: Text(context.s.addNToCart(selected.length),
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Reviews snippet ───────────────────────────────────────────────────────────

class _ReviewsSnippet extends ConsumerWidget {
  final int productId;
  final int count;
  final double rating;
  final bool lazyLoad;
  const _ReviewsSnippet({required this.productId, required this.count, required this.rating, this.lazyLoad = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!lazyLoad) return const SizedBox.shrink();
    final reviewsAsync = ref.watch(_productReviewsProvider(productId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(context.s.reviewsCountN(count),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const Spacer(),
            GestureDetector(
              onTap: () => safePush(context, '/product/$productId/reviews'),
              child: Text(context.s.seeAllReviews,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
            ),
          ]),
          if (rating > 0) ...[
            const SizedBox(height: 12),
            Row(children: [
              Text(rating.toStringAsFixed(1),
                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                  fontSize: 32, fontWeight: FontWeight.w800)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                RatingBarIndicator(
                  rating: rating,
                  itemSize: 16,
                  itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: AppColors.gold),
                ),
                const SizedBox(height: 4),
                Text(context.s.basedOnN(count),
                  style: TextStyle(fontSize: 12, color: context.col.ink3)),
              ]),
            ]),
          ],
          const SizedBox(height: 14),
          reviewsAsync.when(
            loading: () => const SizedBox(height: 40,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (_, __) => const SizedBox.shrink(),
            data: (reviews) => Column(
              children: reviews.take(2).map((r) => _ReviewCard(review: r)).toList()),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.col.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: Text(review.reviewerName.isNotEmpty ? review.reviewerName[0] : '?',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(review.reviewerName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(review.createdAt ?? '',
                  style: TextStyle(fontSize: 11, color: context.col.ink3)),
              ],
            )),
            Row(children: List.generate(5, (i) => Icon(
              i < review.rating ? Icons.star_rounded : Icons.star_border_rounded,
              size: 13, color: AppColors.gold))),
          ]),
          const SizedBox(height: 8),
          Text(review.body, style: TextStyle(fontSize: 13, color: context.col.ink1, height: 1.5)),
        ],
      ),
    );
  }
}

// ── Simple-product attribute display (no variations) ─────────────────────────

class _ProductAttributesDisplay extends StatelessWidget {
  final Product product;
  const _ProductAttributesDisplay({required this.product});

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    const arNameMap = {'الحجم': 'المقاس'};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: product.productAttributes.where((a) => a.values.isNotEmpty).map((attr) {
        final rawLabel = isAr ? attr.nameAr : attr.name;
        final label = arNameMap[rawLabel.trim()] ?? rawLabel;
        final isColor = attr.displayType == 'color' ||
            attr.name.toLowerCase() == 'color' ||
            attr.nameAr.contains('لون');
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text('$label: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Wrap(
                spacing: 6,
                children: attr.values.map((v) {
                  final val = isAr ? v.valueAr : v.value;
                  if (isColor && v.colorHex != null) {
                    return _ColorSwatch(hex: v.colorHex!, selected: false, available: true, size: 22);
                  }
                  return Text(val, style: TextStyle(fontSize: 13, color: context.col.ink2));
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Variation picker ──────────────────────────────────────────────────────────

class _VariationPicker extends StatelessWidget {
  final Product product;
  final Map<String, String> selections;
  final void Function(String type, String value) onChanged;
  const _VariationPicker({required this.product, required this.selections, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    const arNameMap = {'الحجم': 'المقاس'};

    // Group options by typeName from variation_attributes
    final grouped = <String, List<VariationAttribute>>{};
    for (final v in product.variations) {
      for (final a in v.attributes) {
        grouped.putIfAbsent(a.typeName, () => []);
        if (!grouped[a.typeName]!.any((x) => x.value == a.value)) {
          grouped[a.typeName]!.add(a);
        }
      }
    }

    bool _isSize(String typeName, String rawAr) {
      final t = typeName.toLowerCase();
      return t == 'size' || t == 'مقاس' || rawAr.contains('مقاس') || rawAr.contains('حجم') || rawAr.contains('قياس');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        final typeName = entry.key;
        final options = entry.value;
        final rawAr = options.first.typeNameAr.isNotEmpty ? options.first.typeNameAr : typeName;
        final isColor = options.any((o) => o.colorHex != null) ||
            typeName.toLowerCase() == 'color' ||
            rawAr.contains('لون');
        final isSize = _isSize(typeName, rawAr);
        final label = isAr
            ? (isSize ? 'المقاس' : (arNameMap[rawAr.trim()] ?? rawAr))
            : (isSize ? 'Size' : typeName);

        // Single value → display label (not interactive)
        if (options.length == 1) {
          final opt = options.first;
          final val = isAr && opt.valueAr.isNotEmpty ? opt.valueAr : opt.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text('$label: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                if (isColor && opt.colorHex != null) ...[
                  _ColorSwatch(hex: opt.colorHex!, selected: false, available: true, size: 22),
                  const SizedBox(width: 6),
                ],
                Text(val, style: TextStyle(fontSize: 13, color: context.col.ink2)),
              ],
            ),
          );
        }

        // Multiple values → interactive picker
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                if (selections[typeName] != null)
                  Text(selections[typeName]!, style: TextStyle(fontSize: 13, color: context.col.ink2)),
              ]),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: options.map((opt) {
                  final isSelected = selections[typeName] == opt.value;
                  final isOutOfStock = !product.variations.any((v) =>
                      v.attributes.any((a) => a.typeName == typeName && a.value == opt.value) &&
                      (v.inStock || v.stockQuantity > 0));
                  if (isColor && opt.colorHex != null) {
                    return GestureDetector(
                      onTap: isOutOfStock ? null : () => onChanged(typeName, opt.value),
                      child: Tooltip(
                        message: isAr && opt.valueAr.isNotEmpty ? opt.valueAr : opt.value,
                        child: _ColorSwatch(hex: opt.colorHex!, selected: isSelected, available: !isOutOfStock, size: 36),
                      ),
                    );
                  }
                  return GestureDetector(
                    onTap: isOutOfStock ? null : () => onChanged(typeName, opt.value),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.adaptive(context)
                                : isOutOfStock ? context.col.surfaceSoft
                                : context.col.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.adaptive(context)
                                  : context.col.border,
                              width: isSelected ? 1.5 : 1),
                          ),
                          child: Text(opt.value,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isSelected ? Colors.white
                                  : isOutOfStock ? context.col.ink3
                                  : context.col.ink0)),
                        ),
                        if (isOutOfStock)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CustomPaint(painter: _OutOfStockPainter()),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Color swatch circle ───────────────────────────────────────────────────────

class _ColorSwatch extends StatelessWidget {
  final String hex;
  final bool selected;
  final bool available;
  final double size;
  const _ColorSwatch({required this.hex, required this.selected, required this.available, required this.size});

  static Color _parse(String hex) {
    try {
      final h = hex.replaceAll('#', '').padLeft(6, '0');
      return Color(int.parse('0xFF$h'));
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parse(hex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: selected ? AppColors.primary : const Color(0xFFD1D5DB),
          width: selected ? 2.5 : 1.5,
        ),
        boxShadow: selected
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 4, spreadRadius: 1)]
            : null,
      ),
      child: available
          ? null
          : ClipOval(child: CustomPaint(painter: _OutOfStockPainter())),
    );
  }
}

// ── Qty selector ──────────────────────────────────────────────────────────────

class _QtySelector extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final int max;
  const _QtySelector({required this.qty, required this.onChanged, this.enabled = true, this.max = 10});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(context.s.qty, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      const Spacer(),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: context.col.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          _QtyBtn(Icons.remove, qty > 1 && enabled ? () => onChanged(qty - 1) : null),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('$qty',
              style: const TextStyle(fontFamily: 'PlusJakartaSans',
                fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          _QtyBtn(Icons.add, enabled && qty < max ? () => onChanged(qty + 1) : null),
        ]),
      ),
    ]);
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Icon(icon, size: 18,
        color: onTap != null ? AppColors.adaptive(context) : context.col.border),
    ),
  );
}

// ── Trust strip (matches home screen style) ───────────────────────────────────

class _TrustPills extends StatelessWidget {
  const _TrustPills();

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _TrustChip(icon: Icons.local_shipping_outlined,
          label: isAr ? 'توصيل سريع' : 'Fast Delivery'),
        Container(width: 1, height: 28, color: context.col.border),
        _TrustChip(icon: Icons.refresh_rounded,
          label: isAr ? 'إرجاع واستبدال' : 'Returns & Exchanges'),
        Container(width: 1, height: 28, color: context.col.border),
        _TrustChip(icon: Icons.verified_outlined,
          label: isAr ? 'ضمان المنتج' : 'Product Warranty'),
      ],
    );
  }
}

class _TrustChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, size: 20, color: AppColors.primary),
    const SizedBox(height: 4),
    Text(label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.col.ink1),
      textAlign: TextAlign.center),
  ]);
}

// ── Delivery card ─────────────────────────────────────────────────────────────

class _DeliveryCard extends ConsumerWidget {
  const _DeliveryCard();

  static const _arabicDays = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
  static const _arabicMonths = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  static const _englishDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _englishMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String _fmtDate(DateTime d, bool isAr) => isAr
      ? '${_arabicDays[d.weekday % 7]} ${d.day} ${_arabicMonths[d.month - 1]}'
      : '${_englishDays[d.weekday % 7]}, ${_englishMonths[d.month - 1]} ${d.day}';

  static (int, int) _daysForCity(String city) {
    if (city.contains('طرابلس') || city.contains('مصراتة') || city.contains('الزاوية') ||
        city.contains('زليتن') || city.contains('الخمس') || city.contains('تاجوراء') ||
        city.contains('جنزور') || city.contains('قرجي')) return (1, 2);
    if (city.contains('بنغازي') || city.contains('البيضاء') || city.contains('سرت') ||
        city.contains('درنة') || city.contains('أجدابيا') || city.contains('الزنتان') ||
        city.contains('ترهونة') || city.contains('غريان')) return (2, 4);
    if (city == 'ليبيا' || city.isEmpty || city == 'كل ليبيا') return (1, 4);
    return (3, 6);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(cityProvider);
    final (minDays, maxDays) = _daysForCity(city);
    final now = DateTime.now();
    final isAr = context.isAr;
    final minDate = _fmtDate(now.add(Duration(days: minDays)), isAr);
    final maxDate = _fmtDate(now.add(Duration(days: maxDays)), isAr);
    final estimate = isAr
        ? (minDays == maxDays ? 'يصل يوم $minDate' : 'يصل بين $minDate و$maxDate')
        : (minDays == maxDays ? 'Arrives $minDate' : 'Arrives between $minDate and $maxDate');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.col.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Icon(Icons.local_shipping_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(context.s.deliveryToCity(city),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.col.surfaceSoft,
              borderRadius: BorderRadius.circular(12)),
            child: Text(estimate,
              style: TextStyle(fontSize: 12.5,
                fontWeight: FontWeight.w600, color: context.col.ink1),
              textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

// ── Vendor row ────────────────────────────────────────────────────────────────

class _VendorRow extends StatelessWidget {
  final Vendor vendor;
  const _VendorRow({required this.vendor});

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    final name = isAr
        ? (vendor.storeNameAr.isNotEmpty ? vendor.storeNameAr : vendor.storeName)
        : (vendor.storeName.isNotEmpty ? vendor.storeName : vendor.storeNameAr);
    return Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: context.col.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.col.border)),
        child: vendor.logo != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: vendor.logo!, fit: BoxFit.cover, memCacheWidth: 120))
            : Icon(Icons.store_outlined, size: 22, color: context.col.ink2),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          if (vendor.city != null && vendor.city!.isNotEmpty)
            Text(vendor.city!,
              style: TextStyle(fontSize: 12, color: context.col.ink3)),
        ],
      )),
      OutlinedButton(
        onPressed: () => safePush(context, '/vendors/${vendor.id}'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          side: BorderSide(color: AppColors.success.withValues(alpha: 0.8)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(context.s.visitStore,
          style: const TextStyle(fontFamily: 'Cairo',
            fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
      ),
    ]);
  }
}

// ── Coupon section ────────────────────────────────────────────────────────────

class _CouponSection extends StatefulWidget {
  const _CouponSection();
  @override
  State<_CouponSection> createState() => _CouponSectionState();
}

class _CouponSectionState extends State<_CouponSection> {
  bool _expanded = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Divider(height: 1, color: context.col.border),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(children: [
            const Spacer(),
            Text(context.s.hasCoupon,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Icon(Icons.local_offer_outlined, size: 15, color: context.col.ink3),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more_rounded, size: 20, color: context.col.ink3),
            ),
          ]),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: context.col.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.start,
                    style: const TextStyle(fontFamily: 'PlusJakartaSans',
                      fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                    decoration: InputDecoration(
                      hintText: 'أدخل كود الخصم',
                      hintTextDirection: TextDirection.rtl,
                      hintStyle: TextStyle(
                        color: context.col.ink3,
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                        letterSpacing: 0,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(context.s.apply,
                  style: const TextStyle(fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87)),
              ),
            ]),
          ),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

// ── You may also like ─────────────────────────────────────────────────────────

class _YouMayAlsoLike extends ConsumerStatefulWidget {
  final int productId;
  final int? categoryId;
  final bool lazyLoad;
  const _YouMayAlsoLike({required this.productId, this.categoryId, this.lazyLoad = false});
  @override
  ConsumerState<_YouMayAlsoLike> createState() => _YouMayAlsoLikeState();
}

class _YouMayAlsoLikeState extends ConsumerState<_YouMayAlsoLike> {
  final List<Product> _products = [];
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    if (widget.lazyLoad) _loadMore();
  }

  @override
  void didUpdateWidget(_YouMayAlsoLike old) {
    super.didUpdateWidget(old);
    if (!old.lazyLoad && widget.lazyLoad && _products.isEmpty) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{'per_page': 10, 'page': _page, 'sort': 'popular'};
      if (widget.categoryId != null) params['category_id'] = widget.categoryId;
      final res = await ApiClient.instance.dio.get('/products', queryParameters: params);
      final data = res.data['data']['data'] as List? ?? [];
      final fetched = data.map((p) => Product.fromJson(p))
          .where((p) => p.id != widget.productId).toList();
      if (mounted) {
        setState(() {
          _products.addAll(fetched);
          _page++;
          _hasMore = data.length == 10 && _products.length < 50;
          _loading = false;
        });
      }
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_products.isEmpty && !_loading) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.s.youMayAlsoLike,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (_, box) {
            const srcW = 165.0;
            const srcH = 345.0;
            final colW = (box.maxWidth - 12) / 2;
            final cellH = srcH * (colW / srcW);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: cellH.ceilToDouble(),
              ),
              itemCount: _products.length % 2 == 0 ? _products.length : _products.length - 1,
              itemBuilder: (_, i) => FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: srcW,
                  child: ProductCard(product: _products[i], width: srcW),
                ),
              ),
            );
          }),
          if (_loading) ...[
            const SizedBox(height: 16),
            const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
          ],
          if (_hasMore && !_loading) ...[
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton(
                onPressed: _loadMore,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                  side: const BorderSide(color: Colors.black54, width: 1.2),
                  shape: const StadiumBorder(),
                  foregroundColor: Colors.black87,
                ),
                child: Text(context.s.viewMore,
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Out-of-stock diagonal line painter ───────────────────────────────────────

class _OutOfStockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.88),
      Offset(size.width * 0.88, size.height * 0.12),
      Paint()
        ..color = const Color(0xFFAAAAAA)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }
  @override
  bool shouldRepaint(_) => false;
}

// ── Added to cart sheet ───────────────────────────────────────────────────────

class _AddedToCartSheet extends StatelessWidget {
  final Product product;
  final int qty;
  final VoidCallback? onViewCart;
  const _AddedToCartSheet({required this.product, required this.qty, this.onViewCart});

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    final name = isAr ? product.nameAr : product.name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: context.col.border,
              borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 22, color: AppColors.success),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.s.addedToCart,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('$qty× $name',
                  style: TextStyle(fontSize: 12, color: context.col.ink2),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1C1E),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(context.s.continueShopping,
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onViewCart?.call();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(context.s.viewCart,
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
