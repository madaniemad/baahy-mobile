import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://phplaravel-1620145-6391034.cloudwaysapps.com/api',
);

const _kToken = 'auth_token';

// Callback registered by auth layer to redirect to login on 401.
typedef OnUnauthorized = void Function();
OnUnauthorized? _onUnauthorized;

class ApiClient {
  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._();

  late final Dio dio;
  String? _token;

  ApiClient._() {
    dio = _build();
    _preloadToken();
  }

  Future<void> _preloadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_kToken);
  }

  static void setUnauthorizedCallback(OnUnauthorized cb) {
    _onUnauthorized = cb;
  }

  Dio _build() {
    final d = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 10),
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
          final isSilent = error.requestOptions.extra['silent401'] == true;
          final hadToken = _token != null;
          _token = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_kToken);
          if (hadToken && !isSilent) _onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));

    return d;
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
  }

  Future<bool> get isLoggedIn async {
    if (_token != null) return true;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_kToken);
    return _token != null;
  }
}
