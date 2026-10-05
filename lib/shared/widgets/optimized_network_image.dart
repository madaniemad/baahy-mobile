import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/utils/image_url.dart';

/// A product image that loads the pre-generated WebP variant (see
/// [optimizeImg]) and falls back to the ORIGINAL url if the variant is
/// missing (404). Same approach as ProductCard.
///
/// [memCacheWidth] is the decode width in physical px (~2x the displayed
/// logical width). The variant width requested from the CDN defaults to the
/// same value; pass [variantWidth] to override.
class OptimizedNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? variantWidth;
  final Widget? placeholder;
  final Widget? error;

  const OptimizedNetworkImage({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.variantWidth,
    this.placeholder,
    this.error,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final ph = placeholder;
    final err = error;
    final optimized = optimizeImg(url, width: variantWidth ?? memCacheWidth ?? 400);
    Widget original() => CachedNetworkImage(
          imageUrl: url,
          width: width,
          height: height,
          fit: fit,
          memCacheWidth: memCacheWidth,
          placeholder: ph == null ? null : (_, __) => ph,
          errorWidget: err == null ? null : (_, __, ___) => err,
        );
    // Not on the variant host (or no variant exists): nothing to fall back to.
    if (optimized == url) return original();
    return CachedNetworkImage(
      imageUrl: optimized,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      placeholder: ph == null ? null : (_, __) => ph,
      // Variant can legitimately be missing; serve the original instead.
      errorWidget: (_, __, ___) => original(),
    );
  }
}
