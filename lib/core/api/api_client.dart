import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://phplaravel-1620145-6391034.cloudwaysapps.com/api',
);

// Callback registered by auth layer to redirect to login on 401.
typedef OnUnauthorized = void Function();
OnUnauthorized? _onUnauthorized;

class ApiClient {
  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._();

  late final Dio dio;
  final _storage = const FlutterSecureStorage();
  // In-memory token cache — avoids Keychain round-trip on every request.
  String? _token;

  ApiClient._() {
    dio = _build();
    _preloadToken();
  }

  Future<void> _preloadToken() async {
    _token = await _storage.read(key: 'auth_token');
  }

  static void setUnauthorizedCallback(OnUnauthorized cb) {
    _onUnauthorized = cb;
  }

  Dio _build() {
    final d = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    d.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Only redirect to sign-in if the request was made WITH a token.
          // Silent requests (initial auth check) set extra['silent401'] = true
          // to suppress the global redirect without affecting the error itself.
          final isSilent = error.requestOptions.extra['silent401'] == true;
          final hadToken = _token != null;
          _token = null;
          await _storage.delete(key: 'auth_token');
          if (hadToken && !isSilent) _onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));

    return d;
  }

  Future<void> setToken(String token) async {
    _token = token;
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: 'auth_token');
  }

  Future<bool> get isLoggedIn async {
    _token ??= await _storage.read(key: 'auth_token');
    return _token != null;
  }
}
