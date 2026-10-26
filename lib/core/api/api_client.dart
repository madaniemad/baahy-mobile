import 'dart:math' show min;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.baahy.com/api',
);

/// Same API, reached the way the website reaches it: baahy.com -> Vercel -> Cloudways.
///
/// Some networks cannot resolve or reach `api.baahy.com` at all — Sentry logged 81
/// `Failed host lookup: 'api.baahy.com'` across 40 users in eight days, and a user on
/// 1 Sep 2026 could not sign in on the app while the website worked on the same phone,
/// on the same network, minutes later. The website survives because it never touches
/// that hostname. When the direct host is unreachable we take the same road.
const _fallbackBaseUrl = String.fromEnvironment(
  'API_FALLBACK_BASE_URL',
  defaultValue: 'https://baahy.com/api/proxy',
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
    await _loadRoute();
    _token = await _secureStorage.read(key: _kToken);
  }

  static void setUnauthorizedCallback(OnUnauthorized cb) {
    _onUnauthorized = cb;
  }

  /// Set once the direct host proves unreachable and the proxy works.
  static bool _preferFallback = false;

  /// Where product images should be fetched from, given what we have learned about this
  /// network. Image widgets open their own connections and never touch the Dio interceptor,
  /// so without this a device that cannot resolve api.baahy.com gets a working app with
  /// 63% of its product photos missing — every image stored as a relative path.
  ///
  /// Both hosts serve byte-identical files; the proxy simply arrives via baahy.com -> Vercel.
  static String get storageBase => _preferFallback
      ? 'https://baahy.com/api/proxy/storage/'
      : 'https://api.baahy.com/storage/';

  Dio _build() {
    final d = Dio(BaseOptions(
      baseUrl: _baseUrl,
      // 6s to open a connection was too tight for a Libyan mobile link: a cold TLS
      // handshake that overran it surfaced as a generic "sending failed" on a request
      // that never left the phone — invisible in Cloudflare and in the origin log alike,
      // which is exactly how one user spent an afternoon unable to log in (1 Sep 2026).
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    d.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // A request already switching roads (below) keeps the road it chose.
        if (_preferFallback && options.extra['viaFallback'] != true) options.baseUrl = _fallbackBaseUrl;
        // One Keychain read, awaited by whichever request happens to be first.
        await _tokenReady;
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // Retry ONCE, and only for failures where the request provably never arrived:
        // a DNS lookup that failed, or a connection that never opened. Sentry recorded
        // 81 `Failed host lookup: api.baahy.com` across 40 users and 146 connect timeouts
        // across 115 in eight days — transient, and a second attempt clears most of them.
        //
        // Deliberately NOT retried for anything that changes data: receiveTimeout and
        // badResponse. There the server may already have acted, and re-sending would mint a
        // second OTP and spend another of the caller's five hourly slots.
        //
        // A READ (GET/HEAD) changes nothing, so it may take the other road on ANY failure that
        // is not our server's own answer: timeouts, TLS or socket errors, and HTML error pages
        // from a carrier or Cloudflare (2026-10-26: a customer's app reached nothing for two
        // days and showed "0 orders" for a paid order while his network still reached baahy.com).
        const neverArrived = {
          DioExceptionType.connectionError,
          DioExceptionType.connectionTimeout,
        };
        const readFailures = {
          DioExceptionType.sendTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.badCertificate,
          DioExceptionType.unknown,
        };
        final opts = error.requestOptions;
        final isRead = const {'GET', 'HEAD'}.contains(opts.method.toUpperCase());
        final retryable = neverArrived.contains(error.type) ||
            (isRead && (readFailures.contains(error.type) || _notOurAnswer(error)));
        if (retryable) {
          // 1. One straight retry — most of these are transient.
          if (opts.extra['retried'] != true) {
            opts.extra['retried'] = true;
            await Future<void>.delayed(const Duration(milliseconds: 600));
            try {
              return handler.resolve(await d.fetch(opts));
            } catch (_) {/* fall through to the other road */}
          }
          // 2. Still unreachable: take the other road (direct host <-> the website's proxy).
          //    The working one is remembered on the phone for a day, so a device whose network
          //    cannot reach one host pays this discovery once, not on every request or launch.
          if (opts.extra['viaFallback'] != true) {
            opts.extra['viaFallback'] = true;
            final toProxy = !_preferFallback;
            opts.baseUrl = toProxy ? _fallbackBaseUrl : _baseUrl;
            try {
              final res = await d.fetch(opts);
              await _rememberRoute(toProxy, d);
              return handler.resolve(res);
            } catch (_) {/* both roads failed — report the original error */}
          }
          _reportUnreachable(error);
        }

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

  /// An error page that is not our API's answer: a carrier portal, Cloudflare, or a gateway
  /// in front of the server. Our API always answers JSON.
  static bool _notOurAnswer(DioException e) {
    final r = e.response;
    if (e.type != DioExceptionType.badResponse || r == null) return false;
    final code = r.statusCode ?? 0;
    final type = r.headers.value('content-type') ?? '';
    final gateway = code == 502 || code == 503 || code == 504 || (code >= 520 && code <= 530);
    return gateway || ((code == 403 || code == 429) && !type.contains('json'));
  }

  static const _kRoutePref = 'api_route_proxy_until';

  /// Remembers which road works (proxy or direct) for a day, then tries direct again.
  static Future<void> _rememberRoute(bool proxy, Dio d) async {
    _preferFallback = proxy;
    d.options.baseUrl = proxy ? _fallbackBaseUrl : _baseUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (proxy) {
        await prefs.setInt(_kRoutePref, DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch);
      } else {
        await prefs.remove(_kRoutePref);
      }
    } catch (_) {}
  }

  static Future<void> _loadRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final until = prefs.getInt(_kRoutePref) ?? 0;
      if (until > DateTime.now().millisecondsSinceEpoch) _preferFallback = true;
    } catch (_) {}
  }

  static final _reported = <String>{};

  /// Neither road answered: tell Sentry once per kind of failure per launch, with the account
  /// (set at sign-in), so a customer stuck like this shows up for us before they complain.
  static void _reportUnreachable(DioException e) {
    final key = '${e.type.name}:${e.response?.statusCode ?? ''}';
    if (!_reported.add(key)) return;
    Sentry.captureMessage(
      'API unreachable by both roads: $key',
      level: SentryLevel.warning,
      withScope: (scope) {
        scope.setTag('network', 'unreachable');
        scope.setTag('error_type', e.type.name);
        scope.setContexts('request', {
          'method': e.requestOptions.method,
          'path': e.requestOptions.path,
          'via_proxy': _preferFallback,
          'message': '${e.message ?? e.error}'.substring(0, min(200, '${e.message ?? e.error}'.length)),
        });
      },
    );
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
