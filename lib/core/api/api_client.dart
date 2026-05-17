import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _baseUrl = 'https://phplaravel-1620145-6391034.cloudwaysapps.com/api';

class ApiClient {
  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._();

  late final Dio dio;
  final _storage = const FlutterSecureStorage();

  ApiClient._() {
    dio = _build();
  }

  Dio _build() {
    final d = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

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
          _storage.delete(key: 'auth_token');
        }
        handler.next(error);
      },
    ));

    return d;
  }

  Future<void> setToken(String token) =>
      _storage.write(key: 'auth_token', value: token);

  Future<void> clearToken() =>
      _storage.delete(key: 'auth_token');

  Future<bool> get isLoggedIn async =>
      (await _storage.read(key: 'auth_token')) != null;
}
