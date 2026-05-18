import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/utils/router.dart';
import 'core/utils/l10n.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Firebase init — gracefully skipped if config files are not yet present.
  try {
    await Firebase.initializeApp();
    _firebaseReady = true;
    // Crashlytics: re-enable after adding google-services.json + GoogleService-Info.plist
    // and uncomment firebase_crashlytics in pubspec.yaml.
  } catch (e) {
    debugPrint('[Firebase] Not initialized — add config files to enable: $e');
  }

  runApp(const ProviderScope(child: BaahyApp()));
}

class BaahyApp extends ConsumerWidget {
  const BaahyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);

    // Wire push notifications once router is ready and Firebase is available.
    if (_firebaseReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PushNotificationService.instance.init(router);
      });
    }

    return MaterialApp.router(
      title: 'baahy',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
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
