import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/public_profile.dart';

final publicProfileProvider = FutureProvider.autoDispose.family<PublicProfile, String>((ref, username) async {
  final res = await ApiClient.instance.dio.get('/users/$username');
  return PublicProfile.fromJson(res.data['data'] as Map<String, dynamic>);
});
