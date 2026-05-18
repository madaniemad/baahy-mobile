import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True when the device has any network interface up.
/// Does NOT guarantee internet reachability — just that a connection type exists.
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});

/// Convenience: returns false while loading (optimistic — assume online).
extension ConnectivityX on AsyncValue<bool> {
  bool get isOnline => value ?? true;
}
