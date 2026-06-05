import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../providers/auth_provider.dart';
import '../models/tier_status.dart';

final tierProvider = FutureProvider<TierStatus>((ref) async {
  final isLoggedIn = ref.watch(authProvider).isLoggedIn;
  if (!isLoggedIn) return TierStatus.empty;
  try {
    final res = await ApiClient.instance.dio.get('/user/tier-status');
    return TierStatus.fromJson(res.data as Map<String, dynamic>);
  } catch (_) {
    return TierStatus.empty;
  }
});
