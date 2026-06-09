import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/utils/router.dart';
import 'core/utils/l10n.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/push_notification_service.dart';
import 'shared/theme/app_theme.dart';

// ──────────────────────────────────────────────────────────────────────────────
// FIREBASE SETUP:
// 1. Create a Firebase project at https://console.firebase.google.com
// 2. Add Android app (package: com.baahy.customer) → download google-services.json
//    → place at android/app/google-services.json
// 3. Add iOS app (bundle ID: com.baahy.customer) → download GoogleService-Info.plist
//    → place at ios/Runner/GoogleService-Info.plist
// 4. In android/app/build.gradle.kts add:
//    plugins { id("com.google.gms.google-services") }
//    id("com.google.firebase.crashlytics")
// 5. In android/build.gradle.kts add to plugins block (not apply):
//    id("com.google.gms.google-services") version "4.4.2" apply false
//    id("com.google.firebase.crashlytics") version "3.0.2" apply false
// Until then: Firebase is disabled but the app runs normally.
// ──────────────────────────────────────────────────────────────────────────────

bool _firebaseReady = false;
bool _fcmInited = false;
Future<void>? _firebaseInit;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Deep links — init early so cold-start URIs are captured before runApp.
  DeepLinkService.instance.init();

  // Firebase init — fire-and-forget so runApp() is not blocked.
  // FCM wiring happens in BaahyApp once this future settles.
  _firebaseInit = Firebase.initializeApp()
      .then((_) { _firebaseReady = true; })
      .catchError((Object e) {
        debugPrint('[Firebase] Not initialized — add config files to enable: $e');
      });

  final container = ProviderContainer();
  DeepLinkService.instance.setContainer(container);
  runApp(UncontrolledProviderScope(container: container, child: const BaahyApp()));
}

class BaahyApp extends ConsumerWidget {
  const BaahyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Wire push notifications once Firebase settles (fire-and-forget init above).
    // Guard ensures we never call init() more than once across rebuilds.
    if (!_fcmInited && _firebaseInit != null) {
      _firebaseInit!.then((_) {
        if (_firebaseReady && !_fcmInited) {
          _fcmInited = true;
          PushNotificationService.instance.init(router);
        }
      });
    }

    return MaterialApp.router(
      title: 'baahy',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: router,
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
