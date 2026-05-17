import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/user.dart';

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
    if (!await _api.isLoggedIn) return;
    state = state.copyWith(loading: true);
    try {
      final res = await _api.dio.get('/auth/me');
      state = AuthState(user: User.fromJson(res.data['user']));
    } catch (_) {
      await _api.clearToken();
      state = const AuthState();
    }
  }

  Future<void> requestOtp(String phone) async {
    await _api.dio.post('/auth/otp/send', data: {'phone': phone});
  }

  Future<void> verifyOtp(String phone, String code) async {
    final res = await _api.dio.post('/auth/otp/verify', data: {'phone': phone, 'code': code});
    await _api.setToken(res.data['token']);
    state = AuthState(user: User.fromJson(res.data['user']));
  }

  Future<void> logout() async {
    try { await _api.dio.post('/auth/logout'); } catch (_) {}
    await _api.clearToken();
    state = const AuthState();
  }

  Future<void> refreshProfile() async {
    try {
      final res = await _api.dio.get('/auth/me');
      state = AuthState(user: User.fromJson(res.data['user']));
    } catch (_) {}
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ApiClient.instance);
});

final currentUserProvider = Provider<User?>((ref) => ref.watch(authProvider).user);
