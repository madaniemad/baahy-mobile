import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../models/user.dart';

const _kCachedUser = 'cached_user';

class AuthState {
  final User? user;
  final bool loading;
  final String? error;
  const AuthState({this.user, this.loading = false, this.error});

  bool get isLoggedIn => user != null;
  AuthState copyWith({User? user, bool? loading, String? error}) =>
      AuthState(user: user ?? this.user, loading: loading ?? this.loading, error: error);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;
  AuthNotifier(this._api) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();

    // Step 1: Restore from cache immediately (no network, no secure-storage needed).
    // This runs even before checking the token so the UI is instant on every open.
    final cached = prefs.getString(_kCachedUser);
    if (cached != null) {
      try {
        state = AuthState(user: User.fromJson(jsonDecode(cached) as Map<String, dynamic>));
      } catch (_) {}
    }

    // Step 2: Check for a stored token.
    final hasToken = await _api.isLoggedIn;
    if (!hasToken) {
      // No token at all — clear any stale cache and stay logged out.
      if (state.isLoggedIn) {
        await prefs.remove(_kCachedUser);
        state = const AuthState();
      }
      return;
    }

    // Step 3: Token exists — silently refresh profile from API.
    if (!state.isLoggedIn) state = state.copyWith(loading: true);
    try {
      final res = await _api.dio.get('/auth/me',
          options: Options(extra: {'silent401': true}));
      final userJson = res.data['user'] as Map<String, dynamic>;
      await prefs.setString(_kCachedUser, jsonEncode(userJson));
      state = AuthState(user: User.fromJson(userJson));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Token genuinely expired — log out and clear cache.
        await _api.clearToken();
        await prefs.remove(_kCachedUser);
        state = const AuthState();
      }
      // Any other error (network, timeout): keep the cached user logged in.
      else if (state.loading) {
        state = const AuthState();
      }
    } catch (_) {
      if (state.loading) state = const AuthState();
    }
  }

  Future<void> requestOtp(String phone) async {
    await _api.dio.post('/auth/otp/send', data: {'phone': phone});
  }

  Future<void> verifyOtp(String phone, String code, {String? referralCode}) async {
    final body = <String, dynamic>{'phone': phone, 'code': code};
    if (referralCode != null && referralCode.isNotEmpty) body['referred_by_code'] = referralCode;
    final res = await _api.dio.post('/auth/otp/verify', data: body);
    await _api.setToken(res.data['token']);
    final userJson = res.data['user'] as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCachedUser, jsonEncode(userJson));
    state = AuthState(user: User.fromJson(userJson));
  }

  Future<void> logout() async {
    try { await _api.dio.post('/auth/logout'); } catch (_) {}
    await _api.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCachedUser);
    state = const AuthState();
  }

  Future<void> refreshProfile() async {
    try {
      final res = await _api.dio.get('/auth/me');
      final userJson = res.data['user'] as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCachedUser, jsonEncode(userJson));
      state = AuthState(user: User.fromJson(userJson));
    } catch (_) {}
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ApiClient.instance);
});

final currentUserProvider = Provider<User?>((ref) => ref.watch(authProvider).user);
