import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.baahy.com/api',
);

const _kToken = 'auth_token';

// Callback registered by auth layer to redirect to login on 401.
typedef OnUnauthorized = void Function();
OnUnauthorized? _onUnauthorized;

const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

class ApiClient {
  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._();

  late final Dio dio;
  String? _token;

  /// Completes once the stored token has been read out of the Keychain.
  ///
  /// This used to be fire-and-forget, which opened a window on every cold start: the app fires a
  /// burst of requests immediately, and any of them that beat the Keychain read went out with NO
  /// Authorization header, came back 401, and the error interceptor below deleted the stored token
  /// and bounced the user to sign-in. Nothing was wrong with the token — it just hadn't loaded yet.
  late final Future<void> _tokenReady;

  ApiClient._() {
    dio = _build();
    _tokenReady = _preloadToken();
  }

  Future<void> _preloadToken() async {
    _token = await _secureStorage.read(key: _kToken);
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
      onRequest: (options, handler) async {
        // One Keychain read, awaited by whichever request happens to be first.
        await _tokenReady;
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // A 401 on a request that carried no credentials says nothing about the stored token —
          // throwing the session away over one would log the user out for someone else's mistake.
          final sentWithToken = error.requestOptions.headers.containsKey('Authorization');
          if (sentWithToken) {
            final isSilent = error.requestOptions.extra['silent401'] == true;
            _token = null;
            await _secureStorage.delete(key: _kToken);
            if (!isSilent) _onUnauthorized?.call();
          }
        }
        handler.next(error);
      },
    ));

    return d;
  }

  Future<void> setToken(String token) async {
    _token = token;
    await _secureStorage.write(key: _kToken, value: token);
  }

  Future<void> clearToken() async {
    _token = null;
    await _secureStorage.delete(key: _kToken);
  }

  Future<bool> get isLoggedIn async {
    await _tokenReady;
    if (_token != null) return true;
    _token = await _secureStorage.read(key: _kToken);
    return _token != null;
  }
}
