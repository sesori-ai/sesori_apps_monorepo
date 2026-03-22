import "dart:async";

import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

import "core/di/injection.dart";
import "core/extensions/build_context_x.dart";
import "core/platform/notification_service.dart";
import "core/routing/app_router.dart";
import "core/routing/deep_link_service.dart";
import "core/widgets/connection_overlay.dart";
import "firebase_options.dart";
import "l10n/app_localizations.dart";

@pragma("vm:entry-point")
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_shouldInitializeFirebase) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    if (_supportsFirebaseAnalytics) {
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
    }

    if (_supportsFirebaseCrashlytics) {
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };
      // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  }
  configureDependencies();
  getIt<DeepLinkService>().init();
  if (_shouldInitializeFirebase) {
    unawaited(getIt<NotificationService>().initialize());
  }
  runApp(const SesoriApp());
}

bool get _shouldInitializeFirebase {
  if (kIsWeb) {
    return false;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => kReleaseMode,
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.windows => false,
  };
}

bool get _supportsFirebaseAnalytics {
  if (kIsWeb) {
    return false;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => kReleaseMode,
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.windows => false,
  };
}

bool get _supportsFirebaseCrashlytics {
  if (kIsWeb) {
    return false;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => kReleaseMode,
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.windows => false,
  };
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
