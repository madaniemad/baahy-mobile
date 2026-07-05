/// Image URL helper.
///
/// History: banner/CMS images used to be uploaded as multi-MB PNGs served
/// full-size from the origin, so this routed them through the web app's Vercel
/// Image Optimization endpoint to get resized WebP.
///
/// The backend now stores every banner/CMS image as a sized WebP and serves it
/// from a cached origin (`x-cache: HIT`, immutable, ~40–130 KB). Meanwhile the
/// Vercel optimizer was returning `x-vercel-cache: MISS` on essentially every
/// request — i.e. re-optimizing the image each time — which ADDED latency and
/// was the cause of slow first-paint banners. So we now load images directly
/// from the cached origin.
///
/// This is intentionally a pass-through: the function is kept so call sites stay
/// stable if we later put a real CDN in front of the origin.
String optimizeImg(String url, {required int width}) => url;
