import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Full-screen product photos.
///
/// The product page can only ever show the images inside a 340pt header, so the
/// detail that actually decides a purchase — fabric texture, print, the small
/// text on a perfume box — was never visible. This is where that gets looked at.
///
/// The one thing to be careful about here is gestures. The header gallery nests
/// an InteractiveViewer inside a PageView inside a CustomScrollView, and all
/// three want the same drag, which is why pinching there barely works. This
/// screen avoids that: the PageView is frozen while an image is zoomed, so at
/// any moment exactly one recogniser is interested in the drag.
class ProductImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const ProductImageViewer({
    required this.images,
    this.initialIndex = 0,
    super.key,
  });

  /// Fade in over the product page rather than sliding — the photo is already
  /// on screen underneath, so a push would look like a different picture.
  static Route<void> route(List<String> images, int initialIndex) =>
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) =>
            ProductImageViewer(images: images, initialIndex: initialIndex),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      );

  @override
  State<ProductImageViewer> createState() => _ProductImageViewerState();
}

class _ProductImageViewerState extends State<ProductImageViewer> {
  late final PageController _page =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  /// One controller per page so leaving a zoomed image and coming back to it
  /// does not inherit someone else's transform.
  final _transforms = <int, TransformationController>{};
  bool _zoomed = false;

  TransformationController _controllerFor(int i) =>
      _transforms.putIfAbsent(i, TransformationController.new);

  @override
  void dispose() {
    _page.dispose();
    for (final c in _transforms.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncZoom(int i) {
    // getMaxScaleOnAxis() is the scale actually applied, whatever combination of
    // pinch and double-tap produced it.
    final z = _controllerFor(i).value.getMaxScaleOnAxis() > 1.01;
    if (z != _zoomed) setState(() => _zoomed = z);
  }

  void _resetZoom(int i) {
    _controllerFor(i).value = Matrix4.identity();
    if (_zoomed) setState(() => _zoomed = false);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Swipe down to leave, but only at rest: while zoomed the same drag is
          // how you move around the image.
          GestureDetector(
            onVerticalDragEnd: _zoomed
                ? null
                : (d) {
                    if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).pop();
                  },
            child: PageView.builder(
              controller: _page,
              // Frozen while zoomed — otherwise panning a magnified photo flicks
              // to the next one instead of moving within this one.
              physics: _zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              itemCount: widget.images.length,
              onPageChanged: (i) {
                // Leave the page you came from at 1x so the dots and the swipe
                // both behave when you come back to it.
                _resetZoom(_index);
                setState(() => _index = i);
              },
              itemBuilder: (_, i) => InteractiveViewer(
                transformationController: _controllerFor(i),
                minScale: 1.0,
                maxScale: 5.0,
                onInteractionEnd: (_) => _syncZoom(i),
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.images[i],
                    fit: BoxFit.contain,
                    // No memCacheWidth on purpose: the header caps decoding at
                    // 1200px, which is the whole reason to come here.
                    placeholder: (_, __) => const Center(
                      child: SizedBox(
                        width: 26, height: 26,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white54),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white38, size: 64),
                  ),
                ),
              ),
            ),
          ),

          // Close + position. Kept above the PageView so the tap target is never
          // swallowed by a zoomed image underneath it.
          Positioned(
            top: top + 8, left: 12, right: 12,
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
                const Spacer(),
                if (widget.images.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${_index + 1}/${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
