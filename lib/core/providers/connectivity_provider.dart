import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityNotifier extends StateNotifier<bool> {
  ConnectivityNotifier() : super(true) {
    _init();
  }

  StreamSubscription? _sub;
  Timer? _debounce;

  void _init() {
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final hasInterface = results.any((r) => r != ConnectivityResult.none);
      if (hasInterface) {
        _debounce?.cancel();
        if (!state) state = true;
      } else {
        // Debounce 3 s, then do a real ping before marking offline.
        _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 3), _pingAndUpdate);
      }
    });
  }

  Future<void> _pingAndUpdate() async {
    try {
      final r = await InternetAddress.lookup('8.8.8.8')
          .timeout(const Duration(seconds: 4));
      final reachable = r.isNotEmpty && r.first.rawAddress.isNotEmpty;
      if (state != reachable) state = reachable;
    } catch (_) {
      if (state) state = false;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  return ConnectivityNotifier();
});
