import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

import "core/di/injection.dart";
import "core/extensions/build_context_x.dart";
import "core/routing/app_router.dart";
import "core/routing/deep_link_service.dart";
import "core/widgets/connection_overlay.dart";
import "firebase_options.dart";
import "l10n/app_localizations.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_shouldInitializeFirebase) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Explicitly disable any data collection except for the very basic analytics
    // Note: Those are also disabled by default in Info.plist and AndroidManifest.xml
    FirebaseAnalytics.instance
        .setConsent(
          adPersonalizationSignalsConsentGranted: false,
          adStorageConsentGranted: false,
          adUserDataConsentGranted: false,
          personalizationStorageConsentGranted: false,
          securityStorageConsentGranted: false,
          analyticsStorageConsentGranted: true,
          functionalityStorageConsentGranted: true,
        )
        .ignore();

    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
  configureDependencies();
  getIt<DeepLinkService>().init();
  runApp(const SesoriApp());
}

bool get _shouldInitializeFirebase {
  if (defaultTargetPlatform != TargetPlatform.android) {
    return true;
  }

  return kReleaseMode;
}

class SesoriApp extends StatelessWidget {
  const SesoriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => context.loc.appTitle,
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      darkTheme: ThemeData.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
      builder: (context, child) => ConnectionOverlay(
        router: appRouter,
        child: child!,
      ),
    );
  }
}
