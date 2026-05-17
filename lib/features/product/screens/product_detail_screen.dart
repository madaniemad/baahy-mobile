import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/wishlist_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';

final _productDetailProvider = FutureProvider.family<Product, int>((ref, id) async {
  final res = await ApiClient.instance.dio.get('/products/$id');
  return Product.fromJson(res.data['data']);
});

class ProductDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const ProductDetailScreen({required this.id, super.key});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _imageIndex = 0;
  ProductVariation? _selectedVariation;
  int _qty = 1;

  // Selections: attribute type name → value id
  final Map<String, int> _selections = {};

  void _trySelectVariation(Product product) {
    if (_selections.length != product.variations.first.attributes.length) return;

    _selectedVariation = product.variations.firstWhere(
      (v) => v.attributes.every((a) {
        // match all selected attribute values
        return true; // simplified — full impl would match attribute value ids
      }),
      orElse: () => product.variations.first,
    );
    setState(() {});
  }

  Future<void> _addToCart(Product product) async {
    if (product.productType == 'variable' && _selectedVariation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر المواصفات أولاً')));
      return;
    }
    await ref.read(cartProvider.notifier).add(
      product.id,
      variationId: _selectedVariation?.id,
      qty: _qty,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تمت الإضافة للسلة'),
          action: SnackBarAction(label: 'السلة', onPressed: () => context.push('/cart')),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    final productAsync = ref.watch(_productDetailProvider(widget.id));

    return Scaffold(
      backgroundColor: Colors.white,
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('خطأ في التحميل')),
        data: (product) {
          final name = isAr ? product.nameAr : product.name;
          final inWishlist = ref.watch(wishlistProvider).contains(product.id);
          final displayPrice = _selectedVariation?.salePrice
              ?? _selectedVariation?.price
              ?? product.displayPrice;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // Image gallery
                  SliverAppBar(
                    expandedHeight: 320,
                    pinned: true,
                    backgroundColor: Colors.white,
                    leading: IconButton(
                      onPressed: () => context.pop(),
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.shadowCard,
                        ),
                        child: const Icon(Icons.arrow_back, size: 20, color: AppColors.ink0),
                      ),
                    ),
                    actions: [
                      IconButton(
                        onPressed: () => ref.read(wishlistProvider.notifier).toggle(product.id),
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: AppShadows.shadowCard,
                          ),
                          child: Icon(
                            inWishlist ? Icons.favorite_rounded : Icons.favorite_outline,
                            size: 20,
                            color: inWishlist ? AppColors.danger : AppColors.ink0,
                          ),
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        children: [
                          PageView.builder(
                            itemCount: product.images.isEmpty ? 1 : product.images.length,
                            onPageChanged: (i) => setState(() => _imageIndex = i),
                            itemBuilder: (_, i) {
                              if (product.images.isEmpty) {
                                return Container(color: AppColors.bg,
                                  child: const Icon(Icons.image_outlined, size: 80, color: AppColors.ink4));
                              }
                              return CachedNetworkImage(
                                imageUrl: product.images[i],
                                fit: BoxFit.contain,
                              );
                            },
                          ),
                          if (product.images.length > 1)
                            Positioned(
                              bottom: 12,
                              left: 0, right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(product.images.length, (i) =>
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: i == _imageIndex ? 18 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: i == _imageIndex ? AppColors.primary : AppColors.border,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  )),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name + rating
                          Text(name, style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800, height: 1.3)),
                          if (product.averageRating != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                RatingBarIndicator(
                                  rating: product.averageRating!,
                                  itemSize: 16,
                                  itemBuilder: (_, __) =>
                                    const Icon(Icons.star_rounded, color: Color(0xFFFFC107)),
                                ),
                                const SizedBox(width: 6),
                                Text('${product.averageRating!.toStringAsFixed(1)} '
                                  '(${product.reviewsCount ?? 0})',
                                  style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
                              ],
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Price
                          Row(
                            children: [
                              Text(
                                '${displayPrice.toStringAsFixed(0)} د.ل',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 24, fontWeight: FontWeight.w800,
                                  color: AppColors.ink0),
                              ),
                              if (product.hasDiscount && _selectedVariation == null) ...[
                                const SizedBox(width: 8),
                                Text('${product.price.toStringAsFixed(0)} د.ل',
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 16, color: AppColors.ink3,
                                    decoration: TextDecoration.lineThrough)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('-${product.discountPercent}%',
                                    style: const TextStyle(color: Colors.white, fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ],
                          ),

                          // Stock
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: product.inStock ? AppColors.success : AppColors.danger,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                product.inStock
                                    ? context.tr('متوفر', 'In Stock')
                                    : context.tr('نفذت الكمية', 'Out of Stock'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: product.inStock ? AppColors.success : AppColors.danger,
                                ),
                              ),
                            ],
                          ),

                          // Vendor
                          if (product.vendor != null) ...[
                            const SizedBox(height: 16),
                            _VendorCard(vendor: product.vendor!),
                          ],

                          // Variations
                          if (product.variations.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _VariationPicker(
                              product: product,
                              selections: _selections,
                              onChanged: (attrType, valueId) {
                                setState(() => _selections[attrType] = valueId);
                                _trySelectVariation(product);
                              },
                            ),
                          ],

                          // Qty selector
                          const SizedBox(height: 20),
                          _QtySelector(
                            qty: _qty,
                            onChanged: (v) => setState(() => _qty = v),
                          ),

                          const SizedBox(height: 100), // space for bottom bar
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom add to cart bar
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(16, 12, 16,
                    MediaQuery.of(context).padding.bottom + 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: AppShadows.shadowPop,
                  ),
                  child: AppButton(
                    label: product.inStock
                        ? context.tr('أضف إلى السلة', 'Add to Cart')
                        : context.tr('نفذت الكمية', 'Out of Stock'),
                    onTap: product.inStock ? () => _addToCart(product) : null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  final Vendor vendor;
  const _VendorCard({required this.vendor});

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (vendor.logo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: vendor.logo!,
                width: 40, height: 40, fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(Icons.store_outlined, size: 32),
              ),
            )
          else
            const Icon(Icons.store_outlined, size: 32, color: AppColors.ink2),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isAr ? vendor.storeNameAr : vendor.storeName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                if (vendor.city != null)
                  Text(vendor.city!,
                    style: const TextStyle(fontSize: 12, color: AppColors.ink3)),
              ],
            ),
          ),
          if (vendor.averageRating != null)
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 16),
                const SizedBox(width: 2),
                Text(vendor.averageRating!.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
        ],
      ),
    );
  }
}

class _VariationPicker extends StatelessWidget {
  final Product product;
  final Map<String, int> selections;
  final void Function(String attrType, int valueId) onChanged;

  const _VariationPicker({
    required this.product,
    required this.selections,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;

    // Collect unique attribute types from all variations
    final Map<String, List<VariationAttribute>> attrMap = {};
    for (final v in product.variations) {
      for (final a in v.attributes) {
        attrMap.putIfAbsent(a.typeName, () => []);
        if (!attrMap[a.typeName]!.any((x) => x.value == a.value)) {
          attrMap[a.typeName]!.add(a);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: attrMap.entries.map((entry) {
        final typeName = entry.key;
        final values = entry.value;
        final typeNameAr = values.first.typeNameAr;
        final isColor = values.any((v) => v.colorHex != null);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isAr ? typeNameAr : typeName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: values.map((v) {
                final isSelected = false; // simplified
                if (isColor && v.colorHex != null) {
                  final hex = v.colorHex!.replaceAll('#', '');
                  final color = Color(int.parse('FF$hex', radix: 16));
                  return GestureDetector(
                    onTap: () => onChanged(typeName, 0),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: AppShadows.shadowCard,
                      ),
                    ),
                  );
                }
                return GestureDetector(
                  onTap: () => onChanged(typeName, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(isAr ? v.valueAr : v.value,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.ink0,
                      )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }
}

class _QtySelector extends StatelessWidget {
  final int qty;
  final void Function(int) onChanged;
  const _QtySelector({required this.qty, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('الكمية:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _QtyBtn(icon: Icons.remove, onTap: qty > 1 ? () => onChanged(qty - 1) : null),
              SizedBox(
                width: 40,
                child: Text('$qty',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                    fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              _QtyBtn(icon: Icons.add, onTap: () => onChanged(qty + 1)),
            ],
          ),
        ),
      ],
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, size: 18,
          color: onTap != null ? AppColors.ink0 : AppColors.ink4),
      ),
    );
  }
}
