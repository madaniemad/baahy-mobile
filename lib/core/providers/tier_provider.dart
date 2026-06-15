import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../api/api_client.dart';
import '../providers/auth_provider.dart';
import '../models/tier_status.dart';

final tierProvider = FutureProvider.autoDispose<TierStatus>((ref) async {
  final isLoggedIn = ref.watch(authProvider).isLoggedIn;
  if (!isLoggedIn) return TierStatus.empty;
  try {
    final res = await ApiClient.instance.dio.get('/user/tier-status');
    return TierStatus.fromJson(res.data as Map<String, dynamic>);
  } catch (e, st) {
    Sentry.captureException(e, stackTrace: st);
    return TierStatus.empty;
  }
});
