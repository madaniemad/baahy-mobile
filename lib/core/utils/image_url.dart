/// Image URL optimization.
///
/// Mobile hits the Cloudways origin (`api.baahy.com`) directly — no CDN. Some
/// content (notably hero/promo banners) is uploaded as multi-megabyte PNGs and
/// served full-size, which makes the home screen show empty grey boxes for
/// several seconds on a cold open. `memCacheWidth` only caps the in-memory
/// decode, not the download, so it does not help here.
///
/// [optimizeImg] routes such origin images through the web app's Vercel Image
/// Optimization endpoint (`/_next/image`), which returns an edge-cached, resized
/// WebP — typically ~40x smaller than the original PNG (e.g. 2.2 MB → ~50 KB).
///
/// Scope: only full-size origin images on `api.baahy.com`. Anything else
/// (data URIs, other hosts, already-relative paths) is returned unchanged.
library;

const String _optimizerBase = String.fromEnvironment(
  'IMAGE_OPTIMIZER_BASE',
  defaultValue: 'https://baahy-web.vercel.app',
);

// Vercel Image Optimization only accepts widths from its configured device/image
// sizes. Any other width returns HTTP 400. These are the Next.js defaults
// (deviceSizes + imageSizes) — baahy-web/next.config.ts does not override them,
// so a requested width MUST be snapped up to one of these values.
const List<int> _allowedWidths = [
  16, 32, 48, 64, 96, 128, 256, 384,
  640, 750, 828, 1080, 1200, 1920, 2048, 3840,
];

int _snapWidth(int w) {
  for (final aw in _allowedWidths) {
    if (aw >= w) return aw;
  }
  return _allowedWidths.last;
}

// Vercel/Next.js Image Optimization also validates the `q` (quality) param
// against `images.qualities`. baahy-web does not override it, so only the
// Next.js default of 75 is accepted — any other value returns HTTP 400. Do NOT
// change this without adding the value to `images.qualities` in baahy-web.
const int _quality = 75;

/// Returns an optimized (resized WebP, edge-cached) URL for a full-size origin
/// image, or [url] unchanged for anything not eligible.
///
/// [width] is the intended display/decode width in device pixels; it is snapped
/// up to the nearest Vercel-supported size.
String optimizeImg(String url, {required int width}) {
  if (url.isEmpty) return url;
  // Only optimize http(s) images on our own origin. Leave data URIs, other
  // hosts, and relative paths untouched.
  if (!url.startsWith('http')) return url;
  if (!url.contains('api.baahy.com')) return url;
  final w = _snapWidth(width);
  final encoded = Uri.encodeComponent(url);
  return '$_optimizerBase/_next/image?url=$encoded&w=$w&q=$_quality';
}
