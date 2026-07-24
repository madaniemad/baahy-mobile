import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../api/api_client.dart';

/// Carries a pending force-update result from the splash to the home screen, so
/// the update is shown as a popup OVER home (not a full-screen block at splash).
final pendingForceUpdateProvider = StateProvider<VersionGateResult?>((ref) => null);

/// Result of the backend-driven version check.
class VersionGateResult {
  final bool forceUpdate; // installed < min_version → block
  final bool softUpdate;  // installed < latest_version (but >= min) → suggest
  final String storeUrl;
  final String messageAr;
  final String messageEn;
  const VersionGateResult({
    this.forceUpdate = false,
    this.softUpdate = false,
    this.storeUrl = '',
    this.messageAr = '',
    this.messageEn = '',
  });
  static const none = VersionGateResult();
}

/// Compares the installed app version against the backend's `min`/`latest`
/// versions (`GET /app/version`). Mirrors the legacy WooCommerce force-update
/// gate, now driven by the Laravel backend + admin site_settings.
///
/// FAIL-OPEN by design: any error (network, parse, missing settings) returns
/// [VersionGateResult.none] so a transient hiccup can never brick the app.
class VersionGate {
  static Future<VersionGateResult> check() async {
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      final info = await PackageInfo.fromPlatform();
      final current = info.version; // marketing version, e.g. "5.0.0"

      final res = await ApiClient.instance.dio.get(
        '/app/version',
        queryParameters: {'platform': platform},
      );
      final d = res.data;
      if (d is! Map) return VersionGateResult.none;

      final min = (d['min_version'] ?? '0.0.0').toString();
      final latest = (d['latest_version'] ?? '0.0.0').toString();
      final storeUrl = (d['store_url'] ?? '').toString();

      if (_lt(current, min)) {
        return VersionGateResult(
          forceUpdate: true,
          storeUrl: storeUrl,
          messageAr: (d['force_message'] ?? '').toString(),
          messageEn: (d['force_message_en'] ?? '').toString(),
        );
      }
      if (_lt(current, latest)) {
        return VersionGateResult(
          softUpdate: true,
          storeUrl: storeUrl,
          messageAr: (d['soft_message'] ?? '').toString(),
          messageEn: (d['soft_message_en'] ?? '').toString(),
        );
      }
      return VersionGateResult.none;
    } catch (_) {
      return VersionGateResult.none; // fail-open
    }
  }

  static bool _lt(String a, String b) => _cmp(a, b) < 0;

  /// Numeric semver-ish compare; missing components count as 0, build metadata
  /// (after "+") is ignored.
  static int _cmp(String a, String b) {
    final pa = _parts(a), pb = _parts(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x < y ? -1 : 1;
    }
    return 0;
  }

  static List<int> _parts(String v) => v
      .split('+')
      .first
      .split('.')
      .map((s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
}
