import 'dart:async';
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
/// details, driver contact, if they want to call the driver, or if they want to message the driver»).

/// GET orders/{id}/driver-live. The server decides everything: on_the_way only while Baahy's own driver has started
/// this order's delivery; his position only when under 5 minutes old; eta_min from Google road time with traffic
/// (cached per job for 2 minutes there, so polling does not multiply Google calls).
class DriverLive {
  final bool onTheWay;
  final LatLng? driver;
  final DateTime? at;
  final int? etaMin;
  final LatLng? destination;
  const DriverLive({required this.onTheWay, this.driver, this.at, this.etaMin, this.destination});

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
    return DriverLive(
      onTheWay: raw['on_the_way'] == true,
      driver: _pt(d),
      at: d is Map && d['at'] != null ? DateTime.tryParse(d['at'].toString()) : null,
      etaMin: eta is num && eta > 0 ? eta.round() : null,
      destination: _pt(raw['destination']),
    );
  }
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
    final fallback = Container(
      width: size, height: size,
      decoration: BoxDecoration(color: context.col.surfaceSoft, shape: BoxShape.circle),
      child: Icon(Icons.person_outline_rounded, size: 28, color: context.col.ink3),
    );
    final photo = driver.photoUrl;
    final hasPhone = driver.phone != null;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 1.6),
            ),
            child: ClipOval(
              child: photo == null
                  ? fallback
                  : CachedNetworkImage(
                      imageUrl: photo,
                      width: size, height: size,
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
              style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
            Text(driver.name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                color: context.col.ink0, fontSize: 16, fontWeight: FontWeight.w800, height: 1.3)),
            Text(driver.live ? context.s.driverHeadingToYou : context.s.driverHasOrder,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                color: context.col.ink3, fontSize: 12)),
          ])),
        ]),
        if (hasPhone) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _ContactButton(
              icon: Icons.call_rounded,
              label: context.s.callDriver,
              filled: true,
              onTap: () => _call(context),
            )),
            const SizedBox(width: 10),
            Expanded(child: _ContactButton(
              icon: Icons.chat_bubble_outline_rounded,
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
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _ContactButton({required this.icon, required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
        fontSize: 14, fontWeight: FontWeight.w700, color: filled ? Colors.white : context.col.ink0);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return SizedBox(
      height: 44,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(label, style: style),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                elevation: 0, shape: shape, padding: EdgeInsets.zero),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18, color: AppColors.primary),
              label: Text(label, style: style),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.col.ink0, shape: shape, padding: EdgeInsets.zero,
                side: const BorderSide(color: AppColors.primary, width: 1.2)),
            ),
    );
  }
}

// ─── Live map ─────────────────────────────────────────────────────────────────

/// Her delivery pin and his dot, polled every [interval] while this page is the one on screen and the app is in
/// the foreground; nothing is asked otherwise. Shown only while the order says he started her delivery.
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
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const _tripoli = LatLng(32.8872, 13.1913);

  DriverLive? _data;
  bool _everOnTheWay = false;
  bool _busy = false;
  Timer? _timer;
  AppLifecycleState _life = AppLifecycleState.resumed;
  GoogleMapController? _map;
  BitmapDescriptor? _dot;
  double? _dotDpr;

  // His dot glides from where it was to where he is, instead of jumping every 15 s.
  late final AnimationController _move =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  LatLng? _from;
  LatLng? _to;
  LatLng? _shown;

  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dpr = MediaQuery.of(context).devicePixelRatio;
    if (_dotDpr != dpr) {
      _dotDpr = dpr;
      _buildDot(dpr);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _move.dispose();
    _pulse.dispose();
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
    final sw = LatLng(
        driver.latitude < dest.latitude ? driver.latitude : dest.latitude,
        driver.longitude < dest.longitude ? driver.longitude : dest.longitude);
    final ne = LatLng(
        driver.latitude > dest.latitude ? driver.latitude : dest.latitude,
        driver.longitude > dest.longitude ? driver.longitude : dest.longitude);
    // Very close: bounds collapse to a point; zoom in on her pin instead.
    if ((ne.latitude - sw.latitude).abs() < 0.0015 && (ne.longitude - sw.longitude).abs() < 0.0015) {
      map.animateCamera(CameraUpdate.newLatLngZoom(dest, 16));
      return;
    }
    map.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 56));
  }

  /// His position: a tiffany dot in a white ring with a soft halo, drawn once per screen density.
  Future<void> _buildDot(double dpr) async {
    const logical = 34.0;
    final px = logical * dpr;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final o = Offset(px / 2, px / 2);
    c.drawCircle(o, px / 2, Paint()..color = AppColors.primary.withValues(alpha: 0.22));
    c.drawCircle(o, 10.5 * dpr, Paint()..color = Colors.white);
    c.drawCircle(o, 7.5 * dpr, Paint()..color = AppColors.primary);
    final img = await rec.endRecording().toImage(px.round(), px.round());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted || bytes == null) return;
    setState(() => _dot = BitmapDescriptor.bytes(bytes.buffer.asUint8List(), imagePixelRatio: dpr));
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d != null && !d.onTheWay) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dest = _dest;
    final title = d?.etaMin != null
        ? context.s.liveEta(d!.etaMin!)
        : (d != null && d.driver == null ? context.s.liveLocating : context.s.liveOnTheWay);

    final markers = <Marker>{
      if (dest != null)
        Marker(
          markerId: const MarkerId('home'),
          position: dest,
          icon: BitmapDescriptor.defaultMarkerWithHue(184),
          zIndexInt: 1,
        ),
      if (_shown != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: _shown!,
          icon: _dot ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndexInt: 2,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 2, 4, 10),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                  color: context.col.ink0, fontSize: 16, fontWeight: FontWeight.w800)),
              if (d?.etaMin != null)
                Text(context.s.liveEtaNote,
                  style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                    color: context.col.ink3, fontSize: 11.5)),
            ])),
            const SizedBox(width: 8),
            _LiveBadge(pulse: _pulse),
          ]),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 210,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: dest ?? _tripoli, zoom: dest != null ? 14 : 11),
              markers: markers,
              style: isDark ? kDarkMapStyle : null,
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
            ),
          ),
        ),
      ]),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final Animation<double> pulse;
  const _LiveBadge({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        FadeTransition(
          opacity: Tween<double>(begin: 0.35, end: 1).animate(pulse),
          child: Container(width: 7, height: 7,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
        ),
        const SizedBox(width: 6),
        Text(context.s.liveBadge,
          style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
            color: Theme.of(context).brightness == Brightness.dark ? AppColors.primary : AppColors.teal700,
            fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
