import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/navigation.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

/// Downscale a captured photo before visual-search upload. Full-res captures (1080p+)
/// are multi-MB and time out on slow connections; visual search doesn't need that detail.
/// Runs on a background isolate via compute(). Returns the original bytes if decode fails
/// or the image is already small enough.
Uint8List _downscaleForSearch(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  if (decoded.width <= 1280 && decoded.height <= 1280) return bytes;
  final resized = decoded.width >= decoded.height
      ? img.copyResize(decoded, width: 1280)
      : img.copyResize(decoded, height: 1280);
  return img.encodeJpg(resized, quality: 82);
}

enum _CamState { loading, live, scanning, error }

class CameraSearchScreen extends StatefulWidget {
  const CameraSearchScreen({super.key});
  @override
  State<CameraSearchScreen> createState() => _CameraSearchScreenState();
}

class _CameraSearchScreenState extends State<CameraSearchScreen>
    with TickerProviderStateMixin {

  List<CameraDescription> _cameras = [];
  CameraController?       _controller;
  int                     _camIdx = 0;
  FlashMode               _flash  = FlashMode.off;

  _CamState _state    = _CamState.loading;
  File?     _captured;
  String?   _error;

  // Alternative-brand state: brand not in catalog, showing similar products
  String? _altBrand;
  String? _altQuery;
  int?    _altCategory;

  late final AnimationController _scanAnim;
  late final Animation<double>   _scanPos;

  @override
  void initState() {
    super.initState();
    _scanAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _scanPos = Tween<double>(begin: 0.04, end: 0.96).animate(
      CurvedAnimation(parent: _scanAnim, curve: Curves.easeInOut),
    );
    _initCameras();
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _setError('لا توجد كاميرا');
        return;
      }
      await _startCamera(0);
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> _startCamera(int idx) async {
    if (idx >= _cameras.length) { _setError('لا توجد كاميرا'); return; }
    final ctrl = CameraController(
      _cameras[idx],
      ResolutionPreset.veryHigh, // 1080p — sharper preview + better visual-search recognition
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await ctrl.initialize();
      if (!mounted) { await ctrl.dispose(); return; }
      await _controller?.dispose();
      setState(() { _controller = ctrl; _camIdx = idx; _state = _CamState.live; });
    } catch (e) {
      await ctrl.dispose();
      _setError(e.toString());
    }
  }

  Future<void> _capture() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _state != _CamState.live) return;
    try {
      final xfile = await ctrl.takePicture();
      if (!mounted) return;
      setState(() { _captured = File(xfile.path); _state = _CamState.scanning; });
      _scanAnim.repeat(reverse: true);
      await _analyse();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> _pickGallery() async {
    setState(() => _state = _CamState.loading);
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800, maxHeight: 800, imageQuality: 75,
    );
    if (file == null || !mounted) {
      setState(() => _state = _CamState.live);
      return;
    }
    setState(() { _captured = File(file.path); _state = _CamState.scanning; });
    _scanAnim.repeat(reverse: true);
    await _analyse();
  }

  Future<void> _analyse() async {
    try {
      final rawBytes = await _captured!.readAsBytes();
      final bytes = await compute(_downscaleForSearch, rawBytes);
      final res = await ApiClient.instance.dio.post(
        '/search-by-image',
        data: {'image': base64Encode(bytes)},
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 45),
        ),
      );

      final query      = res.data['query']             as String? ?? '';
      final brand      = res.data['brand']             as String?;
      final categoryId = res.data['category_id']       as int?;
      final altBrand   = res.data['alternative_brand'] as String?;
      if (!mounted) return;
      _scanAnim.stop();

      if (query.isEmpty && (brand == null || brand.isEmpty)) {
        _setError(context.isAr
            ? 'تعذّر التعرف على المنتج. حاول مجدداً بصورة أوضح.'
            : 'Could not identify product. Try a clearer photo.');
        return;
      }

      // Brand not in catalog — show intermediate "not found + alternatives" panel
      if (altBrand != null) {
        setState(() {
          _state       = _CamState.scanning; // keep image visible
          _altBrand    = altBrand;
          _altQuery    = query;
          _altCategory = categoryId;
        });
        return;
      }

      final params = <String>[];
      if (categoryId != null) params.add('category=$categoryId');
      if (brand != null && brand.isNotEmpty) params.add('brand=${Uri.encodeComponent(brand)}');
      if (query.isNotEmpty) params.add('q=${Uri.encodeComponent(query)}');
      final url = '/search/results${params.isEmpty ? "" : "?${params.join("&")}"}';
      if (mounted) {
        safePush(context, url);
        _scanAnim.stop();
        _scanAnim.reset();
        setState(() {
          _captured    = null;
          _altBrand    = null;
          _altQuery    = null;
          _altCategory = null;
          _state       = _CamState.live;
        });
      }

    } on DioException catch (e) {
      if (!mounted) return;
      _scanAnim.stop();
      final isLimit = e.response?.data?['error'] == 'limit_hit';
      _setError(isLimit
          ? (context.isAr ? 'تجاوزت الحد اليومي (10 بحوث بالصور)' : 'Daily limit reached (10 searches)')
          : (context.isAr ? 'حدث خطأ. تحقق من الاتصال.' : 'Error. Check your connection.'));
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    await _startCamera((_camIdx + 1) % _cameras.length);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    final next = _flash == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await _controller!.setFlashMode(next);
    if (!mounted) return;
    setState(() { _flash = next; });
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() { _state = _CamState.error; _error = msg; });
  }

  void _retry() {
    _scanAnim.stop();
    _scanAnim.reset();
    setState(() {
      _captured    = null;
      _error       = null;
      _altBrand    = null;
      _altQuery    = null;
      _altCategory = null;
      _state       = _CamState.loading;
    });
    _cameras.isEmpty ? _initCameras() : _startCamera(_camIdx);
  }

  @override
  void dispose() {
    _scanAnim.dispose();
    _controller?.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq       = MediaQuery.of(context);
    final screenW  = mq.size.width;
    final screenH  = mq.size.height;
    // Frame: square, almost full width, vertically centered
    final frameSize = screenW - 40.0;
    final frameL    = 20.0;
    final frameT    = (screenH - frameSize) / 2.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [

        // ── Loading spinner ─────────────────────────────────────────────────
        if (_state == _CamState.loading)
          const Center(child: CircularProgressIndicator(
            color: AppColors.teal, strokeWidth: 2)),

        // ── Live camera fill ────────────────────────────────────────────────
        if (_state == _CamState.live && _controller != null)
          _CameraFill(controller: _controller!),

        // ── Captured image — shown ONLY within the frame area ───────────────
        if (_captured != null && _state == _CamState.scanning)
          Positioned(
            left: frameL, top: frameT,
            width: frameSize, height: frameSize,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_captured!, fit: BoxFit.cover),
            ),
          ),

        // ── Corner brackets + dim ───────────────────────────────────────────
        if (_state == _CamState.live || _state == _CamState.scanning)
          _BracketOverlay(
            frameL: frameL, frameT: frameT, frameSize: frameSize,
            dimOutside: _state == _CamState.live,
          ),

        // ── Animated scan line (stays within frame) ─────────────────────────
        if (_state == _CamState.scanning)
          AnimatedBuilder(
            animation: _scanPos,
            builder: (_, __) => _ScanLine(
              progress: _scanPos.value,
              frameL: frameL, frameT: frameT, frameSize: frameSize,
              screenW: screenW,
            ),
          ),

        // ── Hint text (live) ────────────────────────────────────────────────
        if (_state == _CamState.live)
          Positioned(
            bottom: 108, left: 0, right: 0,
            child: Text(
              context.isAr ? 'ضع المنتج داخل الإطار' : 'Position your product in the frame',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70, fontSize: 13,
                fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w500,
                shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
              ),
            ),
          ),

        // ── Scanning label ──────────────────────────────────────────────────
        if (_state == _CamState.scanning)
          Positioned(
            bottom: 60, left: 0, right: 0,
            child: Text(
              context.isAr ? 'جارٍ تحليل الصورة...' : 'Scanning your image...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white, fontSize: 16,
                fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 10, color: Colors.black)],
              ),
            ),
          ),

        // ── Brand-not-in-catalog panel ──────────────────────────────────────
        if (_altBrand != null)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.col.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)],
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: context.col.ink3.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.search_off_rounded, size: 18, color: context.col.ink3),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.isAr
                            ? 'لا يوجد $_altBrand في باهي'
                            : '$_altBrand not available on Baahy',
                        style: TextStyle(
                          fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 14,
                          fontWeight: FontWeight.w600, color: context.col.ink1),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final p = <String>[];
                        if (_altCategory != null) p.add('category=$_altCategory');
                        if (_altQuery != null && _altQuery!.isNotEmpty)
                          p.add('q=${Uri.encodeComponent(_altQuery!)}');
                        safePush(context, '/search/results?${p.join("&")}');
                        _scanAnim.stop();
                        _scanAnim.reset();
                        setState(() {
                          _captured    = null;
                          _altBrand    = null;
                          _altQuery    = null;
                          _altCategory = null;
                          _state       = _CamState.live;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        context.isAr
                            ? 'شاهد ${_altQuery ?? "منتجات"} مشابهة'
                            : 'See similar ${_altQuery ?? "products"}',
                        style: const TextStyle(
                          fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w700,
                          fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _retry,
                    child: Text(
                      context.isAr ? 'ابحث بصورة أخرى' : 'Try another photo',
                      style: TextStyle(
                        fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13,
                        color: context.col.ink3),
                    ),
                  ),
                ]),
              ),
            ),
          ),

        // ── Error overlay (covers full screen, but NOT the top bar) ─────────
        if (_state == _CamState.error)
          Positioned(
            top: 0, left: 0, right: 0, bottom: 0,
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.camera_alt_outlined, color: Colors.white38, size: 52),
                const SizedBox(height: 16),
                Text(_error ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                    fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(context.isAr ? 'حاول مجدداً' : 'Try again',
                    style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.black87, elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _pickGallery,
                  icon: const Icon(Icons.photo_library_rounded, color: Colors.white60, size: 18),
                  label: Text(
                    context.isAr ? 'اختر من المعرض' : 'Choose from gallery',
                    style: const TextStyle(color: Colors.white60,
                      fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),

        // ── Bottom controls (live) ──────────────────────────────────────────
        if (_state == _CamState.live)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              top: false,
              child: _BottomBar(
                onGallery: _pickGallery,
                onCapture: _capture,
                onFlip: _cameras.length > 1 ? _flipCamera : null,
              ),
            ),
          ),

        // ── Top bar — LAST in stack so always on top ────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: _TopBar(
            flashOn: _flash == FlashMode.torch,
            showFlash: _state == _CamState.live,
            onBack: () => Navigator.of(context).pop(),
            onFlash: _toggleFlash,
          ),
        ),
      ]),
    );
  }
}

// ── Camera fill ──────────────────────────────────────────────────────────────

class _CameraFill extends StatelessWidget {
  const _CameraFill({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Cover the screen with the MINIMUM zoom needed, without distortion.
    // controller.value.aspectRatio already accounts for the preview orientation;
    // multiplying by the screen aspect and forcing scale >= 1 gives true "cover".
    var scale = controller.value.aspectRatio * (size.width / size.height);
    if (scale < 1) scale = 1 / scale;
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: Center(child: CameraPreview(controller)),
      ),
    );
  }
}

// ── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.flashOn, required this.showFlash,
    required this.onBack,  required this.onFlash,
  });
  final bool flashOn, showFlash;
  final VoidCallback onBack, onFlash;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent],
          stops: const [0.6, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Row(children: [
            // Back button — plain Material InkWell for reliable tap
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(24),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
            const Spacer(),
            // baahyVision title
            RichText(text: const TextSpan(children: [
              TextSpan(text: 'baahy',
                style: TextStyle(
                  color: AppColors.teal, fontSize: 19, fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                )),
              TextSpan(text: '  Vision',
                style: TextStyle(
                  color: Colors.white, fontSize: 19, fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                )),
            ])),
            const Spacer(),
            if (showFlash)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onFlash,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Icon(
                      flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: flashOn ? AppColors.teal : Colors.white, size: 22),
                  ),
                ),
              )
            else
              const SizedBox(width: 50),
          ]),
        ),
      ),
    );
  }
}

// ── Bracket overlay ───────────────────────────────────────────────────────────

class _BracketOverlay extends StatelessWidget {
  const _BracketOverlay({
    required this.frameL, required this.frameT, required this.frameSize,
    required this.dimOutside,
  });
  final double frameL, frameT, frameSize;
  final bool   dimOutside;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _BracketPainter(
          frameL: frameL, frameT: frameT, frameSize: frameSize,
          dimOutside: dimOutside,
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  _BracketPainter({
    required this.frameL, required this.frameT, required this.frameSize,
    required this.dimOutside,
  });
  final double frameL, frameT, frameSize;
  final bool   dimOutside;

  @override
  void paint(Canvas canvas, Size size) {
    final r = frameL;
    final b = frameT;
    final right  = frameL + frameSize;
    final bottom = frameT + frameSize;

    // Dim outside frame on live camera view
    if (dimOutside) {
      final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.4);
      final outer = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      final inner = Path()..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTRB(r, b, right, bottom), const Radius.circular(12)));
      canvas.drawPath(Path.combine(PathOperation.difference, outer, inner), dimPaint);
    }

    // Corner brackets
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const arm = 26.0;
    const cr  = 9.0;

    _corner(canvas, paint, frameL, frameT, arm, cr, 1, 1);
    _corner(canvas, paint, right,  frameT, arm, cr, -1, 1);
    _corner(canvas, paint, frameL, bottom, arm, cr, 1, -1);
    _corner(canvas, paint, right,  bottom, arm, cr, -1, -1);
  }

  void _corner(Canvas c, Paint p, double cx, double cy,
      double arm, double r, double xs, double ys) {
    final path = Path();
    path.moveTo(cx + xs * arm, cy);
    path.lineTo(cx + xs * r,   cy);
    path.arcToPoint(Offset(cx, cy + ys * r),
      radius: Radius.circular(r),
      clockwise: xs * ys > 0,
    );
    path.lineTo(cx, cy + ys * arm);
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_BracketPainter old) =>
    old.frameL != frameL || old.frameT != frameT ||
    old.frameSize != frameSize || old.dimOutside != dimOutside;
}

// ── Scan line ─────────────────────────────────────────────────────────────────

class _ScanLine extends StatelessWidget {
  const _ScanLine({
    required this.progress,
    required this.frameL, required this.frameT,
    required this.frameSize, required this.screenW,
  });
  final double progress, frameL, frameT, frameSize, screenW;

  @override
  Widget build(BuildContext context) {
    final lineY = frameT + frameSize * progress;
    return Positioned(
      top: lineY - 1.5,
      left: frameL + 6,
      width: frameSize - 12,
      height: 3,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.transparent,
            AppColors.teal.withValues(alpha: 0.8),
            Colors.white,
            AppColors.teal.withValues(alpha: 0.8),
            Colors.transparent,
          ]),
          boxShadow: [
            BoxShadow(
              color: AppColors.teal.withValues(alpha: 0.55),
              blurRadius: 12, spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onGallery, required this.onCapture, required this.onFlip,
  });
  final VoidCallback  onGallery;
  final VoidCallback  onCapture;
  final VoidCallback? onFlip;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
          stops: const [0.6, 1.0],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _CircleBtn(onTap: onGallery,
          child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 22)),
        // Capture
        GestureDetector(
          onTap: onCapture,
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3.5),
            ),
            padding: const EdgeInsets.all(5),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Colors.white,
              ),
              child: const Icon(Icons.search_rounded, color: Colors.black87, size: 32),
            ),
          ),
        ),
        _CircleBtn(
          onTap: onFlip,
          child: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 22)),
      ]),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.onTap, required this.child});
  final VoidCallback? onTap;
  final Widget        child;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 50, height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: onTap != null ? 0.18 : 0.07),
      ),
      child: Center(child: child),
    ),
  );
}
