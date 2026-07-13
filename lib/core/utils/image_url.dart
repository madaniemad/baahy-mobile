/// Image URL helper — maps an original image to a pre-generated resized variant.
///
/// Product images live in Cloudflare R2 behind `images.baahy.com`. The originals
/// are full-resolution (a typical product shot is ~500 KB), but a product card
/// renders it at ~165pt — so a 20-item grid was pulling ~10 MB, which is ~3
/// minutes on a Libyan 3G connection.
///
/// We pre-generate WebP variants into the same bucket and serve those instead:
///
///     original :  images.baahy.com/wp-content/uploads/2025/02/foo.jpg
///     400px    :  images.baahy.com/t/400/wp-content/uploads/2025/02/foo.jpg.webp
///     800px    :  images.baahy.com/t/800/wp-content/uploads/2025/02/foo.jpg.webp
///
/// Typical result: 506 KB -> ~35 KB (and a PNG banner 276 KB -> 4 KB).
///
/// NOT Cloudflare Image Transformations: those bill per unique transformation
/// PER MONTH, so at 50k products x 4 images x 2 sizes it's ~$200/month forever.
/// Pre-generated variants cost one batch job plus a few cents of R2 storage, and
/// R2 egress is free.
///
/// Callers MUST keep a fallback to the original URL — a variant can be missing
/// (source image was broken, or the batch hasn't reached it), and we'd rather
/// serve a heavy image than a broken one. See ProductCard's errorWidget.
library;

const String kImageHost = 'https://images.baahy.com/';

/// Widths we actually generate. Anything larger falls back to the original.
const List<int> _kVariantWidths = [400, 800];

String optimizeImg(String url, {required int width}) {
  if (!url.startsWith(kImageHost)) return url; // not on R2 (local /storage, etc)
  if (url.startsWith('${kImageHost}t/')) return url; // already a variant

  final w = _kVariantWidths.cast<int?>().firstWhere(
        (v) => width <= v!,
        orElse: () => null,
      );
  if (w == null) return url; // wants bigger than we generate — use the original

  final path = url.substring(kImageHost.length);
  return '${kImageHost}t/$w/$path.webp';
}
