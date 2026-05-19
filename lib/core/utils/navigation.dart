import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

DateTime? _lastNavTime;

Future<T?> safePush<T>(BuildContext context, String path, {Object? extra}) {
  final now = DateTime.now();
  if (_lastNavTime != null &&
      now.difference(_lastNavTime!) < const Duration(milliseconds: 600)) {
    return Future.value(null);
  }
  _lastNavTime = now;
  if (extra != null) {
    return context.push<T>(path, extra: extra);
  } else {
    return context.push<T>(path);
  }
}
