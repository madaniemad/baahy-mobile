import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../api/api_client.dart';

class AppNotification {
  final int id;
  final String title;
  final String body;
  final String? type;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type,
    this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'],
    title: j['title'] ?? '',
    body: j['body'] ?? '',
    type: j['type'],
    data: j['data'] is Map ? Map<String, dynamic>.from(j['data']) : null,
    isRead: j['is_read'] == true || j['is_read'] == 1,
    createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
  );
}

class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  final ApiClient _api;
  NotificationsNotifier(this._api) : super([]) {
    fetch();
  }

  Future<void> fetch() async {
    if (!await _api.isLoggedIn) return;
    try {
      final res = await _api.dio.get('/notifications');
      // The API returns `data` as a Laravel paginator object
      // ({current_page, data: [...], ...}), so the list lives at data.data.
      // Stay resilient in case it's ever returned as a flat list.
      final raw = res.data['data'];
      final list = raw is List
          ? raw
          : (raw is Map && raw['data'] is List ? raw['data'] as List : const []);
      state = list.map((n) => AppNotification.fromJson(n)).toList();
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }

  Future<void> markRead(int id) async {
    try {
      await _api.dio.put('/notifications/$id/read');
      state = state.map((n) => n.id == id
          ? AppNotification(id: n.id, title: n.title, body: n.body, type: n.type,
              data: n.data, isRead: true, createdAt: n.createdAt)
          : n).toList();
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }

  Future<void> markAllRead() async {
    try {
      await _api.dio.put('/notifications/read-all');
      state = state.map((n) => AppNotification(
          id: n.id, title: n.title, body: n.body, type: n.type,
          data: n.data, isRead: true, createdAt: n.createdAt)).toList();
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<AppNotification>>((ref) {
  return NotificationsNotifier(ApiClient.instance);
});

final unreadNotificationCountProvider = Provider<int>((ref) =>
    ref.watch(notificationsProvider).where((n) => !n.isRead).length);
