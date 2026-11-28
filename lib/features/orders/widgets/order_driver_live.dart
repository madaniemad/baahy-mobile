import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/order.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../map/map_location_picker.dart' show kDarkMapStyle;

/// The order page's driver card and live map (Emad 2026-11-28: «does the customer actually see a live view of the
/// driver when the driver is on the way to them? Like most delivery apps» and «that same page should have the driver
/// details, driver contact, if they want to call the driver, or if they want to message the driver»). Styled to the
/// studio's draft board of 2026-11-28 (admin-design/customer-order-tracking), not yet approved by Emad.

/// GET orders/{id}/driver-live. The server decides everything: on_the_way only while Baahy's own driver has started
/// this order's delivery; his position only when under 5 minutes old; eta_min, km and the road (encoded polyline)
/// from one Google Routes call with traffic, cached per job for 2 minutes there, so polling does not multiply calls.
class DriverLive {
  final bool onTheWay;
  final LatLng? driver;
  final DateTime? at;
  final int? etaMin;
  /// Road km from his position to her pin, as Google measured it.
  final double? km;
  /// The road itself, from his position (at the time Google was asked) to her pin. Empty = no road line.
  final List<LatLng> path;
  final LatLng? destination;
  const DriverLive({
    required this.onTheWay, this.driver, this.at, this.etaMin, this.km, this.path = const [], this.destination,
  });

  static LatLng? _pt(dynamic raw) {
    if (raw is! Map) return null;
    final lat = raw['lat'], lng = raw['lng'];
    if (lat is! num || lng is! num || (lat == 0 && lng == 0)) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  static DriverLive? parse(dynamic raw) {
    if (raw is! Map) return null;
    final d = raw['driver'];
    final eta = raw['eta_min'];
    final km = raw['km'];
    final path = raw['path'];
    return DriverLive(
      onTheWay: raw['on_the_way'] == true,
      driver: _pt(d),
      at: d is Map && d['at'] != null ? DateTime.tryParse(d['at'].toString()) : null,
      etaMin: eta is num && eta > 0 ? eta.round() : null,
      km: km is num && km > 0 ? km.toDouble() : null,
      path: path is String && path.isNotEmpty ? decodePolyline(path) : const [],
      destination: _pt(raw['destination']),
    );
  }
}

/// Google's encoded polyline format → points.
List<LatLng> decodePolyline(String s) {
  final out = <LatLng>[];
  var i = 0, lat = 0, lng = 0;
  try {
    while (i < s.length) {
      for (var k = 0; k < 2; k++) {
        var shift = 0, result = 0, b = 0;
        do {
          b = s.codeUnitAt(i++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        final d = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
        if (k == 0) {
          lat += d;
        } else {
          lng += d;
        }
      }
      out.add(LatLng(lat / 1e5, lng / 1e5));
    }
  } catch (_) {
    return const [];
  }
  return out;
}

typedef DriverLiveFetch = Future<DriverLive?> Function();

DriverLiveFetch driverLiveFromServer(int orderId) => () async {
      final res = await ApiClient.instance.dio.get('/orders/$orderId/driver-live',
          options: Options(extra: const {'silent401': true}));
      return DriverLive.parse(res.data is Map ? res.data['data'] : null);
    };

// ─── Driver card ──────────────────────────────────────────────────────────────

class OrderDriverCard extends StatelessWidget {
  final DeliveryDriver driver;
  final String orderNumber;
  const OrderDriverCard({required this.driver, required this.orderNumber, super.key});

  Future<void> _open(BuildContext context, Uri uri) async {
    final msg = context.s.couldNotOpenApp;
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok) messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  void _call(BuildContext context) => _open(context, Uri(scheme: 'tel', path: driver.phone));

  void _message(BuildContext context) {
    final digits = (driver.phone ?? '').replaceAll(RegExp(r'\D'), '');
    final text = context.s.driverWaText(orderNumber);
    _open(context, Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(text)}'));
  }

  @override
  Widget build(BuildContext context) {
    const size = 52.0;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final initial = driver.name.characters.isNotEmpty ? driver.name.characters.first : '';
    // No photo: his first letter on tiffany-soft (studio board).
    final fallback = Container(
      width: size, height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF123637) : const Color(0xFFE8FBFC),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Text(initial,
        style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
          fontSize: 22, fontWeight: FontWeight.w700, color: dark ? AppColors.primary : AppColors.teal700)),
    );
    final photo = driver.photoUrl;
    final vehicle = context.s.vehicleLabel(driver.vehicle);
    final state = driver.live ? context.s.driverOnWayToYou : context.s.driverCollected;
    final hasPhone = driver.phone != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          photo == null
              ? fallback
              : Container(
                  width: size, height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 2)),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: photo,
                      fit: BoxFit.cover,
                      memCacheWidth: 160,
                      placeholder: (_, __) => fallback,
                      errorWidget: (_, __, ___) => fallback,
                    ),
                  ),
                ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.s.driverRole,
              style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                color: context.col.ink3, fontSize: 12)),
            Text(driver.name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                color: context.col.ink0, fontSize: 17, fontWeight: FontWeight.w700, height: 1.3)),
            Text(vehicle != null ? '$vehicle · $state' : state,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                color: context.col.ink2, fontSize: 13)),
          ])),
        ]),
        if (hasPhone) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _ContactButton(
              glyph: const Icon(Icons.call_outlined, size: 19, color: Colors.white),
              label: context.s.callDriver,
              filled: true,
              onTap: () => _call(context),
            )),
            const SizedBox(width: 8),
            Expanded(child: _ContactButton(
              glyph: const _WhatsAppGlyph(size: 19),
              label: context.s.messageDriver,
              filled: false,
              onTap: () => _message(context),
            )),
          ]),
        ],
      ]),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final Widget glyph;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _ContactButton({required this.glyph, required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
        fontSize: 15, fontWeight: FontWeight.w700, color: filled ? Colors.white : context.col.ink0);
    // «اتصال» tiffany with WHITE text and icon; «رسالة» on surfaceSoft with the WhatsApp glyph (studio board).
    return SizedBox(
      height: 46,
      child: Material(
        color: filled ? AppColors.primary : context.col.surfaceSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: filled ? BorderSide.none : BorderSide(color: context.col.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            glyph,
            const SizedBox(width: 7),
            Text(label, style: style),
          ]),
        ),
      ),
    );
  }
}

/// The WhatsApp glyph in its green (#25D366), drawn from the studio board's 24×24 SVG path (Material has no
/// WhatsApp icon and the app has no SVG package).
class _WhatsAppGlyph extends StatelessWidget {
  final double size;
  const _WhatsAppGlyph({required this.size});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _SvgPathPainter(_waPath, Color(0xFF25D366)));
}

const _waPath = 'M12 2a10 10 0 0 0-8.6 15.1L2 22l5-1.3A10 10 0 1 0 12 2zm0 18.2a8.2 8.2 0 0 1-4.2-1.2l-.3-.2-3 .8.8-2.9'
    '-.2-.3A8.2 8.2 0 1 1 12 20.2zm4.5-6.1c-.2-.1-1.5-.7-1.7-.8-.2-.1-.4-.1-.6.1l-.8 1c-.1.2-.3.2-.5.1a6.7 6.7 0 0 1'
    '-3.3-2.9c-.3-.4.2-.4.7-1.3.1-.2 0-.3 0-.4l-.8-1.8c-.2-.5-.4-.4-.6-.4h-.5a1 1 0 0 0-.7.3 3 3 0 0 0-.9 2.2 5.2 5.2'
    ' 0 0 0 1.1 2.8 11.9 11.9 0 0 0 4.6 4c1.7.7 2.4.8 3.2.7a2.8 2.8 0 0 0 1.8-1.3 2.3 2.3 0 0 0 .2-1.3c-.1-.1-.3-.2-.5-.3z';

/// Paints one SVG path (viewBox 0 0 24 24; commands M L H V C A Z, absolute or relative) filled in [color].
class _SvgPathPainter extends CustomPainter {
  final String d;
  final Color color;
  const _SvgPathPainter(this.d, this.color);

  static Path parse(String d) {
    final path = Path();
    final tokens = RegExp(r'[MmLlHhVvCcAaZz]|-?(?:\d*\.\d+|\d+\.?)(?:[eE]-?\d+)?')
        .allMatches(d).map((m) => m.group(0)!).toList();
    var i = 0;
    var cmd = 'M';
    var x = 0.0, y = 0.0, sx = 0.0, sy = 0.0;
    bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
    double n() => double.parse(tokens[i++]);
    while (i < tokens.length) {
      if (isCmd(tokens[i])) cmd = tokens[i++];
      final rel = cmd == cmd.toLowerCase();
      switch (cmd.toUpperCase()) {
        case 'Z':
          path.close();
          x = sx; y = sy;
          continue;
        case 'M':
          final nx = n(), ny = n();
          x = rel ? x + nx : nx; y = rel ? y + ny : ny;
          path.moveTo(x, y);
          sx = x; sy = y;
          cmd = rel ? 'l' : 'L'; // further pairs are lines
        case 'L':
          final nx = n(), ny = n();
          x = rel ? x + nx : nx; y = rel ? y + ny : ny;
          path.lineTo(x, y);
        case 'H':
          final nx = n();
          x = rel ? x + nx : nx;
          path.lineTo(x, y);
        case 'V':
          final ny = n();
          y = rel ? y + ny : ny;
          path.lineTo(x, y);
        case 'C':
          final v = [n(), n(), n(), n(), n(), n()];
          if (rel) {
            path.cubicTo(x + v[0], y + v[1], x + v[2], y + v[3], x + v[4], y + v[5]);
            x += v[4]; y += v[5];
          } else {
            path.cubicTo(v[0], v[1], v[2], v[3], v[4], v[5]);
            x = v[4]; y = v[5];
          }
        case 'A':
          final rx = n(), ry = n(), rot = n(), large = n(), sweep = n(), ex = n(), ey = n();
          x = rel ? x + ex : ex; y = rel ? y + ey : ey;
          path.arcToPoint(Offset(x, y),
              radius: Radius.elliptical(rx, ry), rotation: rot, largeArc: large != 0, clockwise: sweep != 0);
        default:
          i++; // unknown token: skip
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(parse(d), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SvgPathPainter old) => old.d != d || old.color != color;
}

// ─── Live map ─────────────────────────────────────────────────────────────────

/// Her delivery pin, his car marker and the road between them, polled every [interval] while this page is the one on
/// screen and the app is in the foreground; nothing is asked otherwise. Shown only while the order says he started
/// her delivery.
class OrderLiveMapCard extends StatefulWidget {
  final DriverLiveFetch fetch;
  final Duration interval;
  /// Her pin from the order, so the map has a place before the first answer.
  final LatLng? destination;
  /// The server said it is no longer on the way after it was: reload the order (delivered, or handed back).
  final VoidCallback? onEnded;
  const OrderLiveMapCard({
    required this.fetch,
    this.interval = const Duration(seconds: 15),
    this.destination,
    this.onEnded,
    super.key,
  });

  @override
  State<OrderLiveMapCard> createState() => _OrderLiveMapCardState();
}

class _OrderLiveMapCardState extends State<OrderLiveMapCard>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _tripoli = LatLng(32.8872, 13.1913);

  DriverLive? _data;
  bool _everOnTheWay = false;
  bool _busy = false;
  Timer? _timer;
  Timer? _pulseTimer;
  bool _pulseBig = true;
  AppLifecycleState _life = AppLifecycleState.resumed;
  GoogleMapController? _map;
  double? _iconDpr;
  BitmapDescriptor? _home;
  BitmapDescriptor? _carBig;
  BitmapDescriptor? _carSmall;

  // His marker glides from where it was to where he is, instead of jumping every 15 s.
  late final AnimationController _move =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  LatLng? _from;
  LatLng? _to;
  LatLng? _shown;

  LatLng? get _dest => _data?.destination ?? widget.destination;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _move.addListener(() {
      final a = _from, b = _to;
      if (a == null || b == null) return;
      final t = Curves.easeInOut.transform(_move.value);
      setState(() => _shown = LatLng(
          a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
    _timer = Timer.periodic(widget.interval, (_) => _tick());
    // The soft pulse around his marker: two halo sizes, swapped while she is looking.
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (_visible && _carSmall != null) setState(() => _pulseBig = !_pulseBig);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dpr = MediaQuery.of(context).devicePixelRatio;
    if (_iconDpr != dpr) {
      _iconDpr = dpr;
      _buildIcons(dpr);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pulseTimer?.cancel();
    _move.dispose();
    _map?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _life = state;
    if (state == AppLifecycleState.resumed) _tick();
  }

  /// Only while she is looking at this page: app in the foreground and no other screen pushed on top.
  bool get _visible {
    if (!mounted || _life != AppLifecycleState.resumed) return false;
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  Future<void> _tick() async {
    if (_busy || !_visible) return;
    _busy = true;
    DriverLive? d;
    try {
      d = await widget.fetch();
    } catch (_) {
      d = null; // keep what is on screen; the next tick tries again
    } finally {
      _busy = false;
    }
    if (!mounted || d == null) return;
    if (!d.onTheWay) {
      final wasLive = _everOnTheWay;
      setState(() => _data = d);
      if (wasLive) widget.onEnded?.call();
      return;
    }
    _everOnTheWay = true;
    final next = d.driver;
    setState(() => _data = d);
    if (next != null) {
      if (_shown == null) {
        setState(() => _shown = next);
      } else if (_shown != next) {
        _from = _shown;
        _to = next;
        _move.forward(from: 0);
      }
    }
    _fit(next);
  }

  void _fit(LatLng? driver) {
    final map = _map, dest = _dest;
    if (map == null) return;
    if (dest == null && driver == null) return;
    if (dest == null || driver == null) {
      map.animateCamera(CameraUpdate.newLatLngZoom(dest ?? driver!, 14.5));
      return;
    }
    // Both ends and the road between them in view.
    final pts = [driver, dest, ..._road()];
    var s = pts.first.latitude, n = s, w = pts.first.longitude, e = w;
    for (final p in pts) {
      s = math.min(s, p.latitude); n = math.max(n, p.latitude);
      w = math.min(w, p.longitude); e = math.max(e, p.longitude);
    }
    // Very close: bounds collapse to a point; zoom in on her pin instead.
    if (n - s < 0.0015 && e - w < 0.0015) {
      map.animateCamera(CameraUpdate.newLatLngZoom(dest, 16));
      return;
    }
    map.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e)), 64)); // marker + pulse never reach the edge (studio QA)
  }

  /// Index of the road point nearest his marker: the road is drawn (and measured) from there on, so the part he has
  /// already driven since Google was asked drops away. A pointer into Google's road only; it decides nothing.
  int _nearestOnRoad(List<LatLng> path, LatLng at) {
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < path.length; i++) {
      final dl = path[i].latitude - at.latitude, dg = path[i].longitude - at.longitude;
      final d = dl * dl + dg * dg;
      if (d < bestD) { bestD = d; best = i; }
    }
    return best;
  }

  /// The rest of Google's road ahead of him; empty when there is no road (never a straight line instead).
  List<LatLng> _road() {
    final path = _data?.path ?? const <LatLng>[];
    final at = _shown;
    if (path.length < 2) return const [];
    if (at == null) return path;
    final i = _nearestOnRoad(path, at);
    return i >= path.length - 1 ? const [] : path.sublist(i);
  }

  /// Km left along Google's road (the road's own length, not a straight line); else Google's figure.
  double? _kmLeft(List<LatLng> road) {
    if (road.length >= 2) {
      var m = 0.0;
      for (var i = 1; i < road.length; i++) {
        m += _metres(road[i - 1], road[i]);
      }
      return m / 1000;
    }
    return _data?.km;
  }

  static double _metres(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * math.pi / 180) * math.cos(b.latitude * math.pi / 180) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(x)));
  }

  /// Her pin (tiffany, a house inside, white outline) and his marker (white disc, car glyph, tiffany ring, soft halo
  /// in two sizes for the pulse), drawn once per screen density.
  Future<void> _buildIcons(double dpr) async {
    final home = await _draw(34, 42, dpr, (c) {
      final pin = Path()
        ..moveTo(17, 41)
        ..cubicTo(17, 41, 32, 28, 32, 17)
        ..arcToPoint(const Offset(2, 17), radius: const Radius.circular(15), clockwise: false)
        ..cubicTo(2, 28, 17, 41, 17, 41)
        ..close();
      c.drawPath(pin, Paint()..color = AppColors.primary);
      c.drawPath(pin, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5);
      final house = Path()
        ..moveTo(11, 18.5)
        ..lineTo(17, 13.5)
        ..lineTo(23, 18.5)
        ..lineTo(23, 25)
        ..lineTo(11, 25)
        ..close();
      c.drawPath(house, Paint()..color = Colors.white);
    });
    Future<BitmapDescriptor?> car(double haloR, double haloA) => _draw(64, 64, dpr, (c) {
          const o = Offset(32, 32);
          c.drawCircle(o, haloR, Paint()..color = AppColors.primary.withValues(alpha: haloA));
          c.drawCircle(o.translate(0, 3), 20,
              Paint()
                ..color = Colors.black.withValues(alpha: 0.2)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
          c.drawCircle(o, 20, Paint()..color = Colors.white);
          c.drawCircle(o, 18.5, Paint()
            ..color = AppColors.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
          final glyph = TextPainter(
            textDirection: TextDirection.ltr,
            text: TextSpan(
              text: String.fromCharCode(Icons.directions_car_rounded.codePoint),
              style: TextStyle(
                fontFamily: Icons.directions_car_rounded.fontFamily,
                package: Icons.directions_car_rounded.fontPackage,
                fontSize: 20,
                color: const Color(0xFF0A1A1A),
              ),
            ),
          )..layout();
          glyph.paint(c, o - Offset(glyph.width / 2, glyph.height / 2));
        });
    final big = await car(32, 0.25);
    final small = await car(26, 0.16);
    if (!mounted) return;
    setState(() {
      _home = home;
      _carBig = big;
      _carSmall = small;
    });
  }

  Future<BitmapDescriptor?> _draw(double w, double h, double dpr, void Function(Canvas) paint) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(dpr);
    paint(c);
    final img = await rec.endRecording().toImage((w * dpr).round(), (h * dpr).round());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return null;
    return BitmapDescriptor.bytes(bytes.buffer.asUint8List(), imagePixelRatio: dpr);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d != null && !d.onTheWay) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dest = _dest;
    final road = _road();
    final km = d?.driver != null ? _kmLeft(road) : null;
    final eta = d?.etaMin;
    // With Google's road time: ETA + the sub-line. Without it: the sub-line alone (copy table).
    final sub = eta != null
        ? context.s.liveSub
        : (d != null && d.driver == null ? context.s.liveLocating : context.s.liveOnTheWay);

    final markers = <Marker>{
      if (dest != null)
        Marker(
          markerId: const MarkerId('home'),
          position: dest,
          icon: _home ?? BitmapDescriptor.defaultMarkerWithHue(184),
          anchor: const Offset(0.5, 41 / 42),
          zIndexInt: 1,
        ),
      if (_shown != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: _shown!,
          icon: (_pulseBig ? _carBig : _carSmall) ?? BitmapDescriptor.defaultMarkerWithHue(184),
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 2,
        ),
    };
    final polylines = <Polyline>{
      if (road.length >= 2)
        Polyline(
          polylineId: const PolylineId('road'),
          points: road,
          color: AppColors.primary,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
    };

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(
          aspectRatio: 360 / 230,
          child: Stack(children: [
           Positioned.fill(child: GoogleMap(
            initialCameraPosition: CameraPosition(target: dest ?? _tripoli, zoom: dest != null ? 14 : 11),
            markers: markers,
            polylines: polylines,
            // No shops, malls or mosques on it (studio QA 2026-11-28): only the two markers and the road names.
            style: isDark ? _noPoi(kDarkMapStyle) : _noPoi(null),
            onMapCreated: (ctrl) {
              _map = ctrl;
              _fit(_shown);
            },
            // A picture inside a scrolling page: the page keeps the drag; the camera follows him by itself.
            scrollGesturesEnabled: false,
            zoomGesturesEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            buildingsEnabled: false,
          )),
           // «● مباشر» at the top, away from the Google logo (bottom left).
           Positioned(
             top: 10,
             right: 10,
             child: Container(
               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
               decoration: BoxDecoration(
                 color: context.col.surface,
                 borderRadius: BorderRadius.circular(999),
                 boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
               ),
               child: Row(mainAxisSize: MainAxisSize.min, children: [
                 Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                 const SizedBox(width: 6),
                 Text(context.tr('مباشر', 'Live'),
                     style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'], fontWeight: FontWeight.w700, fontSize: 12.5, color: context.col.ink0)),
               ]),
             ),
           ),
          ]),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (eta != null)
                Text(context.s.liveEta(eta),
                  style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                    color: context.col.ink0, fontSize: 16, fontWeight: FontWeight.w800)),
              Text(sub,
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                  color: context.col.ink3, fontSize: 12)),
            ])),
            if (km != null && km > 0) ...[
              const SizedBox(width: 10),
              Text(context.s.km(km < 10 ? km.toStringAsFixed(1) : km.round().toString()),
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                  color: context.col.ink2, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ]),
        ),
      ]),
    );
  }
}


/// The map style without points of interest (businesses, malls, mosques, transit), road names kept. [base]: a style JSON
/// array (the dark style) or null for Google's default.
String _noPoi(String? base) {
  const off = '{"featureType":"poi","stylers":[{"visibility":"off"}]},{"featureType":"transit","stylers":[{"visibility":"off"}]}';
  final b = (base ?? '[]').trim();
  if (b == '[]' || !b.endsWith(']')) return '[$off]';
  return '${b.substring(0, b.length - 1).trimRight()},$off]';
}
