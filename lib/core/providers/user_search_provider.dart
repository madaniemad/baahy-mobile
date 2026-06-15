import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../api/api_client.dart';
import '../models/friend.dart';

class UserSearchState {
  final List<Friend> results;
  final bool loading;

  const UserSearchState({this.results = const [], this.loading = false});
  UserSearchState copyWith({List<Friend>? results, bool? loading}) =>
      UserSearchState(results: results ?? this.results, loading: loading ?? this.loading);
}

class UserSearchNotifier extends StateNotifier<UserSearchState> {
  UserSearchNotifier() : super(const UserSearchState());

  Timer? _debounce;

  void search(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      state = const UserSearchState();
      return;
    }
    state = state.copyWith(loading: true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _doSearch(query.trim()));
  }

  Future<void> _doSearch(String q) async {
    try {
      final res = await ApiClient.instance.dio.get('/users/search', queryParameters: {'q': q});
      final data = res.data['data'] as List? ?? [];
      state = UserSearchState(results: data.map((j) => Friend.fromJson(j as Map<String, dynamic>)).toList());
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      state = const UserSearchState();
    }
  }

  void clear() {
    _debounce?.cancel();
    state = const UserSearchState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final userSearchProvider = StateNotifierProvider.autoDispose<UserSearchNotifier, UserSearchState>((ref) {
  return UserSearchNotifier();
});
