import "dart:async";

import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "core/analytics/analytics_user_id_tracker.dart";
import "core/di/injection.dart";
import "core/extensions/build_context_x.dart";
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
  // Pre-warm the liquid-glass shaders so the frosted top nav / glass buttons
  // render without a first-frame compile hitch. No-ops on Skia/web.
  await LiquidGlassWidgets.initialize();
  // The native splash runs in fullscreen, which leaves the status/nav bars
  // hidden on iOS until the engine is told otherwise. Restore them and let
  // content draw behind them so the background image still reaches the edges.
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: SystemUiOverlay.values,
  );
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
  if (_shouldInitializeFirebase) {
    await bootstrapSesoriApp(
      shouldInitializeFirebase: true,
      supportsFirebaseAnalytics: _supportsFirebaseAnalytics,
      configureDependenciesFn: configureDependencies,
      initializeDeepLinks: () => getIt<DeepLinkService>().init(),
      startNotificationStartupFn: () => startNotificationStartup(
        localNotificationClient: getIt<LocalNotificationClient>(),
        pushMessagingSource: getIt<PushMessagingSource>(),
        notificationRegistrationService: getIt<NotificationRegistrationService>(),
        foregroundNotificationDispatcher: getIt<ForegroundNotificationDispatcher>(),
        notificationOpenDispatcher: getIt<NotificationOpenDispatcher>(),
      ),
      runAppFn: runApp,
    );
    return;
  }

  await bootstrapSesoriApp(
    shouldInitializeFirebase: false,
    supportsFirebaseAnalytics: false,
    configureDependenciesFn: configureDependencies,
    initializeDeepLinks: () => getIt<DeepLinkService>().init(),
    startNotificationStartupFn: () async {},
    runAppFn: runApp,
  );
}

Future<void> bootstrapSesoriApp({
  required bool shouldInitializeFirebase,
  required bool supportsFirebaseAnalytics,
  required void Function() configureDependenciesFn,
  required void Function() initializeDeepLinks,
  required Future<void> Function() startNotificationStartupFn,
  required void Function(Widget app) runAppFn,
}) async {
  configureDependenciesFn();
  initializeDeepLinks();
  if (shouldInitializeFirebase) {
    if (supportsFirebaseAnalytics) {
      // Side effect: the tracker auto-subscribes to auth state changes and
      // syncs the hashed user ID with Firebase Analytics. Do not remove.
      AnalyticsUserIdTracker(
        authSession: getIt<AuthSession>(),
        analytics: FirebaseAnalytics.instance,
      );
    }
    unawaited(
      startNotificationStartupFn().catchError((Object error, StackTrace stackTrace) {
        loge("Error bootstrapping notification startup", error, stackTrace);
      }),
    );
  }
  runAppFn(
    LiquidGlassWidgets.wrap(
      child: const SesoriApp(),
      adaptiveQuality: true,
      // ignore: experimental_member_use
      adaptiveConfig: const GlassAdaptiveScopeConfig(
        initialQuality: GlassQuality.standard,
      ),
    ),
  );
}

Future<void> startNotificationStartup({
  required LocalNotificationClient localNotificationClient,
  required PushMessagingSource pushMessagingSource,
  required NotificationRegistrationService notificationRegistrationService,
  required ForegroundNotificationDispatcher foregroundNotificationDispatcher,
  required NotificationOpenDispatcher notificationOpenDispatcher,
}) async {
  await _runNotificationStartupStep(() => localNotificationClient.initialize());
  await _runNotificationStartupStep(() => pushMessagingSource.initialize());
  await _runNotificationStartupStep(() => notificationRegistrationService.start());
  await _runNotificationStartupStep(() => foregroundNotificationDispatcher.start());
  await _runNotificationStartupStep(() => notificationOpenDispatcher.start());
}

Future<void> _runNotificationStartupStep(Future<void> Function() step) async {
  try {
    await step();
  } catch (error, stackTrace) {
    loge("Error initializing notification startup", error, stackTrace);
  }
}

bool get _shouldInitializeFirebase {
  if (kIsWeb) {
    return false;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => !kProfileMode,
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.windows => false,
  };
}

bool get _supportsFirebaseAnalytics {
  if (kIsWeb) {
    return false;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => !kProfileMode,
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.windows => false,
  };
}

bool get _supportsFirebaseCrashlytics {
  if (kIsWeb) {
    return false;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => !kProfileMode,
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
      theme: ThemeData(
        colorScheme: PregoColors.light.toFlutterColorScheme(),
        textTheme: PregoTextTheme.light.asFlutterTextTheme(),
        fontFamily: PregoTextTheme.fontFamily,
        fontFamilyFallback: PregoTextTheme.fontFamilyFallback,
        extensions: [PregoDesignSystem.light],
        // Dark status-bar icons for the light theme's light backgrounds.
        // Without this, transparent AppBars (e.g. ProjectListScreen) default
        // to light/white icons that vanish against a light background.
        appBarTheme: const AppBarTheme(systemOverlayStyle: SystemUiOverlayStyle.dark),
      ),
      darkTheme: ThemeData(
        colorScheme: PregoColors.dark.toFlutterColorScheme(),
        textTheme: PregoTextTheme.dark.asFlutterTextTheme(),
        fontFamily: PregoTextTheme.fontFamily,
        fontFamilyFallback: PregoTextTheme.fontFamilyFallback,
        extensions: [PregoDesignSystem.dark],
        // Light status-bar icons for the dark theme's dark backgrounds.
        appBarTheme: const AppBarTheme(systemOverlayStyle: SystemUiOverlayStyle.light),
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
      builder: (context, child) => ConnectionOverlay(
        router: appRouter,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
