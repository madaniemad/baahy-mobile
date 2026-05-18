import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/app_config.dart';

// Fetches from /api/app-config (backed by site_settings table in Laravel).
// Falls back to built-in defaults if endpoint fails for any reason.
final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  try {
    final res = await ApiClient.instance.dio.get('/app-config');
    final data = res.data['data'];
    if (data != null && data is Map<String, dynamic>) {
      return AppConfig.fromJson(data);
    }
    return AppConfig.defaults;
  } catch (_) {
    return AppConfig.defaults;
  }
});

// Sync accessor — returns defaults while async loads, never null.
extension AppConfigX on AsyncValue<AppConfig> {
  AppConfig get config => value ?? AppConfig.defaults;
}
