import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

DateTime? _lastNavTime;

void safePush(BuildContext context, String path, {Object? extra}) {
  final now = DateTime.now();
  if (_lastNavTime != null &&
      now.difference(_lastNavTime!) < const Duration(milliseconds: 600)) return;
  _lastNavTime = now;
  if (extra != null) {
    context.push(path, extra: extra);
  } else {
    context.push(path);
  }
}
