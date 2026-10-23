import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../api/api_client.dart';
import '../models/friend.dart';

class UserSearchState {
  final List<Friend> results;
  final bool loading;
  final bool error;
  /// The (cleaned) query [results] / [error] answer; '' = nothing searched yet.
  final String query;

  const UserSearchState({this.results = const [], this.loading = false, this.error = false, this.query = ''});
  UserSearchState copyWith({List<Friend>? results, bool? loading, bool? error, String? query}) =>
      UserSearchState(
        results: results ?? this.results,
        loading: loading ?? this.loading,
        error: error ?? this.error,
        query: query ?? this.query,
      );
}

class UserSearchNotifier extends StateNotifier<UserSearchState> {
  UserSearchNotifier() : super(const UserSearchState());

  Timer? _debounce;
  int _seq = 0;     // newest request wins; clear() and new keystrokes invalidate older ones
  String _lastQ = ''; // the query last sent (or about to be)

  /// Usernames are typed as "@ali" as often as "ali": strip the handle and spaces.
  static String _clean(String q) => q.trim().replaceFirst(RegExp(r'^@+'), '').trim();

  void search(String query) {
    final q = _clean(query);
    if (q.isEmpty) {
      clear();
      return;
    }
    if (q == _lastQ) return; // only surrounding spaces / the @ changed
    _lastQ = q;
    _debounce?.cancel();
    ++_seq;
    // Keep the previous results on screen while the next ones load.
    state = state.copyWith(loading: true, error: false);
    _debounce = Timer(const Duration(milliseconds: 300), () => _doSearch(q));
  }

  void retry() {
    if (_lastQ.isEmpty) return;
    _debounce?.cancel();
    state = state.copyWith(loading: true, error: false);
    _doSearch(_lastQ);
  }

  Future<void> _doSearch(String q) async {
    final seq = ++_seq;
    try {
      final res = await ApiClient.instance.dio.get('/users/search', queryParameters: {'q': q});
      // Disposed, or a newer keystroke / clear() superseded this request.
      if (!mounted || seq != _seq) return;
      final data = res.data['data'] as List? ?? [];
      state = UserSearchState(
        query: q,
        results: data.whereType<Map>().map((j) => Friend.fromJson(Map<String, dynamic>.from(j))).toList(),
      );
    } catch (e, st) {
      if (!mounted || seq != _seq) return;
      Sentry.captureException(e, stackTrace: st);
      state = UserSearchState(query: q, error: true);
    }
  }

  void clear() {
    _debounce?.cancel();
    ++_seq;
    _lastQ = '';
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
