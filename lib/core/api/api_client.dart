import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _baseUrl = 'https://phplaravel-1620145-6391034.cloudwaysapps.com/api';

class ApiClient {
  static final _storage = FlutterSecureStorage();
  static Dio? _instance;

  static Dio get dio {
    _instance ??= _build();
    return _instance!;
  }

  static Dio _build() {
    final d = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    // Auth token interceptor
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Token expired — clear and let app redirect to sign-in
          _storage.delete(key: 'auth_token');
        }
        handler.next(error);
      },
    ));

    return d;
  }

  static Future<void> setToken(String token) =>
      _storage.write(key: 'auth_token', value: token);

  static Future<void> clearToken() =>
      _storage.delete(key: 'auth_token');

  static Future<bool> get isLoggedIn async =>
      (await _storage.read(key: 'auth_token')) != null;
}
