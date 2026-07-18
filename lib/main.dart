import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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

  // Initialize Firebase up front so the push pipeline (getToken → /device-token)
  // can start as soon as it's ready.
  _firebaseInit = _initFirebaseWithRetry();
  await _firebaseInit;

  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://2cec46307e2718d20887b9719687b2f5@o4511447317807104.ingest.de.sentry.io/4511453087793232';
      options.environment = kReleaseMode ? 'production' : 'debug';
      options.tracesSampleRate = kReleaseMode ? 0.1 : 0.0;
      options.enableAutoSessionTracking = true;
    },
    appRunner: () {
      // Deep links — init early so cold-start URIs are captured before runApp.
      DeepLinkService.instance.init();
      final container = ProviderContainer();
      DeepLinkService.instance.setContainer(container);
      runApp(UncontrolledProviderScope(container: container, child: const BaahyApp()));
    },
  );
}

/// Initialize Firebase with a short retry as defensive hardening against a
/// transient plugin-channel race at startup.
///
/// NOTE: the months-long "channel-error, Unable to establish connection on
/// channel" that left Firebase (and all push) dead was NOT a race — it was
/// firebase_core 3.15.0 being incompatible with Flutter 3.41's UIScene/implicit
/// engine. Upgrading to firebase_core 4.x / firebase_messaging 16.x fixed it.
Future<void> _initFirebaseWithRetry() async {
  for (var attempt = 0; attempt < 8; attempt++) {
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
      return;
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }
  debugPrint('[Firebase] not initialized after retries — push disabled');
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
      // Distribute each text line's leading evenly above and below the glyphs so
      // Arabic text (Tajawal reserves extra vertical space) sits vertically
      // centred in pills/buttons instead of riding high. Applies app-wide.
      builder: (context, child) => DefaultTextHeightBehavior(
        textHeightBehavior: const TextHeightBehavior(
          leadingDistribution: TextLeadingDistribution.even,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
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
