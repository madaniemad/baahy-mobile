import 'dart:convert';
import 'dart:typed_data';

import 'package:baahy_customer/core/api/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// api.baahy.com answers like Imunify360 does for a greylisted IP; the proxy answers normally.
class _Adapter implements HttpClientAdapter {
  _Adapter({this.blockProxy = false});
  final bool blockProxy;
  final hits = <String>[];
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    hits.add('${o.method} ${o.uri}');
    final direct = o.uri.host == 'api.baahy.com' || blockProxy;
    final body = direct
        ? {'message': 'Access denied by Imunify360 bot-protection. IPs used for automation should be whitelisted'}
        : {'channel': 'whatsapp'};
    return ResponseBody.fromString(jsonEncode(body), direct ? 403 : 200,
        headers: {'content-type': ['application/json']});
  }
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a firewall-blocked POST is sent again by the proxy, and the route is remembered', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final api = ApiClient.instance;
    final a = _Adapter();
    api.dio.httpClientAdapter = a;
    final res = await api.dio.post('/auth/otp/send', data: {'phone': '+218 924704638'});
    expect(res.data['channel'], 'whatsapp');
    expect(a.hits, ['POST https://api.baahy.com/api/auth/otp/send', 'POST https://baahy.com/api/proxy/auth/otp/send']);
    // Next request goes straight to the proxy.
    await api.dio.post('/auth/otp/send', data: {'phone': '+218 924704638'});
    expect(a.hits.last, 'POST https://baahy.com/api/proxy/auth/otp/send');
    expect(a.hits.length, 3);
  });

  test('blocked on both roads: the firewall text never reaches the screen', () async {
    final api = ApiClient.instance;
    api.dio.httpClientAdapter = _Adapter(blockProxy: true);
    try {
      await api.dio.post('/auth/otp/send', data: {'phone': '+218 924704638'});
      fail('should throw');
    } on DioException catch (e) {
      expect(e.response?.statusCode, 403);
      expect(e.response?.data, isNull);
    }
  });
}
