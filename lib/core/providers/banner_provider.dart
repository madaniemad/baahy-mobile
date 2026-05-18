import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/banner.dart';

final bannersProvider = FutureProvider<BannersData>((ref) async {
  try {
    final res = await ApiClient.instance.dio.get('/content/banners');
    final data = res.data['data'] as Map<String, dynamic>?;
    if (data == null) return const BannersData();
    return BannersData.fromJson(data);
  } catch (_) {
    return const BannersData();
  }
});
