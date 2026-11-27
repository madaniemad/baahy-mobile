import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

import '../widgets/order_driver_live.dart';

/// Debug-only preview of the order page's four delivery states, without a real order or driver:
///
///   flutter run --dart-define=ORDER_DEMO=a     (a being prepared · b driver has it · c on the way · d delivered)
///
/// The app then opens straight on /orders/0 with a made-up order; tapping the order number in the app bar steps
/// a → b → c → d. Nothing is sent to the server for it (help / return cards just find nothing). Release builds
/// ignore the flag: [kOrderDemo] is empty unless kDebugMode.
const String _demoFlag = String.fromEnvironment('ORDER_DEMO');
const String kOrderDemo = kDebugMode ? _demoFlag : '';
bool get orderDemoOn => kOrderDemo.isNotEmpty;

const orderDemoStates = ['a', 'b', 'c', 'd'];

String orderDemoNext(String s) => orderDemoStates[(orderDemoStates.indexOf(s) + 1) % orderDemoStates.length];

/// Her pin (Hay Andalus, Tripoli) and his road in from Gargaresh — a fixed path so the dot moves along streets.
const _home = LatLng(32.8705, 13.1215);
const _path = <LatLng>[
  LatLng(32.8590, 13.1500),
  LatLng(32.8602, 13.1468),
  LatLng(32.8618, 13.1433),
  LatLng(32.8633, 13.1398),
  LatLng(32.8647, 13.1366),
  LatLng(32.8659, 13.1333),
  LatLng(32.8671, 13.1300),
  LatLng(32.8683, 13.1270),
  LatLng(32.8694, 13.1244),
  LatLng(32.8701, 13.1226),
];

/// The live source in the demo: one step along [_path] per call, ETA counting down.
DriverLiveFetch orderDemoLive() {
  var i = 0;
  return () async {
    final k = i % _path.length;
    final eta = (_path.length - k) + 2;
    i++;
    return DriverLive(onTheWay: true, driver: _path[k], at: DateTime.now(), etaMin: eta,
        path: [..._path.sublist(k), _home], destination: _home);
  };
}

/// GET orders/{id} as the server would answer it, for state [s].
Map<String, dynamic> orderDemoJson(String s) {
  final now = DateTime.now();
  String ago(int min) => now.subtract(Duration(minutes: min)).toIso8601String();
  final status = switch (s) { 'a' => 'processing', 'b' => 'fulfilled', 'c' => 'out_for_delivery', _ => 'delivered' };
  final history = <Map<String, dynamic>>[
    {'to_status': 'pending_confirmation', 'created_at': ago(190)},
    {'to_status': 'confirmed', 'created_at': ago(160)},
    {'to_status': 'processing', 'created_at': ago(159)},
    if (s != 'a') {'to_status': 'fulfilled', 'created_at': ago(70)},
    if (s == 'c' || s == 'd') {'to_status': 'out_for_delivery', 'created_at': ago(18)},
    if (s == 'd') {'to_status': 'delivered', 'created_at': ago(2)},
  ];
  return {
    'id': 0,
    'order_number': '113542731',
    'status': status,
    'total': 245,
    'subtotal': 225,
    'shipping_cost': 20,
    'discount': 0,
    'payment_method': 'cash_on_delivery',
    'payment_status': s == 'd' ? 'paid' : 'pending',
    'shipping_lat': _home.latitude,
    'shipping_lng': _home.longitude,
    'created_at': ago(190),
    'status_history': history,
    'delivery_driver': (s == 'b' || s == 'c')
        ? {'name': 'محمد', 'photo_url': null, 'phone': '+218910000000', 'vehicle': 'car', 'live': s == 'c'}
        : null,
    'vendor_groups': [
      {
        'vendor': {'id': 1, 'store_name': 'Rinas Cosmetics', 'store_name_ar': 'ريناس كوزمتكس'},
        'status': status,
        'items': [
          {'id': 1, 'product_id': 0, 'product_name': 'Hydrating serum 30 ml', 'product_name_ar': 'سيروم مرطب 30 مل',
            'quantity': 1, 'price': 135},
          {'id': 2, 'product_id': 0, 'product_name': 'Lip tint', 'product_name_ar': 'تينت للشفاه',
            'quantity': 2, 'price': 45},
        ],
      },
    ],
  };
}
