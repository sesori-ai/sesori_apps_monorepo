import "dart:async";
import "dart:ui" as ui;

import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "core/analytics/analytics_user_id_tracker.dart";
import "core/di/injection.dart";
import "core/extensions/appearance_mode_x.dart";
import "core/extensions/build_context_x.dart";
import "core/platform/firebase/firebase_messaging_static_adapter.dart";
import "core/routing/app_router.dart";
import "core/routing/deep_link_service.dart";
import "firebase_options.dart";
import "l10n/app_localizations.dart";

@pragma("vm:entry-point")
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void _configureFirebaseSdk({
  required bool supportsAnalytics,
  required bool supportsCrashlytics,
}) {
  getIt<FirebaseMessagingStaticAdapter>().registerBackgroundHandler(
    handler: _firebaseMessagingBackgroundHandler,
  );

  if (supportsAnalytics) {
    // Explicitly disable any data collection except for the very basic analytics.
    // These are also disabled by default in Info.plist and AndroidManifest.xml.
    getIt<FirebaseAnalytics>()
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

  if (supportsCrashlytics) {
    final crashlytics = getIt<FirebaseCrashlytics>();
    FlutterError.onError = crashlytics.recordFlutterFatalError;
    // Pass uncaught asynchronous errors outside the Flutter framework to Crashlytics.
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }
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
  final shouldInitializeFirebase = _shouldInitializeFirebase;
  final supportsFirebaseAnalytics = _supportsFirebaseAnalytics;
  final supportsFirebaseCrashlytics = _supportsFirebaseCrashlytics;
  if (shouldInitializeFirebase) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  await bootstrapSesoriApp(
    shouldInitializeFirebase: shouldInitializeFirebase,
    supportsFirebaseAnalytics: supportsFirebaseAnalytics,
    configureDependenciesFn: () {
      configureDependencies(firebaseEnabled: shouldInitializeFirebase);
      _configureFirebaseSdk(
        supportsAnalytics: supportsFirebaseAnalytics,
        supportsCrashlytics: supportsFirebaseCrashlytics,
      );
    },
    initializeDeepLinks: () => getIt<DeepLinkService>().init(),
    startNotificationStartupFn: () => startNotificationStartup(
      localNotificationClient: getIt<LocalNotificationClient>(),
      pushMessagingSource: getIt<PushMessagingSource>(),
      notificationRegistrationService: getIt<NotificationRegistrationService>(),
      foregroundNotificationDispatcher: getIt<ForegroundNotificationDispatcher>(),
      notificationOpenDispatcher: getIt<NotificationOpenDispatcher>(),
    ),
    readAppearanceFn: () => getIt<AppearanceStore>().read(),
    runAppFn: runApp,
  );
}

Future<void> bootstrapSesoriApp({
  required bool shouldInitializeFirebase,
  required bool supportsFirebaseAnalytics,
  required void Function() configureDependenciesFn,
  required void Function() initializeDeepLinks,
  required Future<void> Function() startNotificationStartupFn,
  required Future<AppearanceMode> Function() readAppearanceFn,
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
        analytics: getIt<FirebaseAnalytics>(),
      );
    }
    unawaited(
      startNotificationStartupFn().catchError((Object error, StackTrace stackTrace) {
        loge("Error bootstrapping notification startup", error, stackTrace);
      }),
    );
  }

  // Awaited: the persisted theme has to be in place before the first frame,
  // otherwise a pinned light/dark choice flashes the device theme on launch.
  final appearance = await readAppearanceFn();

  final isImpeller = ui.ImageFilter.isShaderFilterSupported;

  if (isImpeller) {
    logd("🚀 Running on Impeller Rendering Engine");
  } else {
    logd("🎨 Running on Skia Rendering Engine (or fallback)");
  }

  runAppFn(
    LiquidGlassWidgets.wrap(
      child: SesoriApp(initialAppearance: appearance),
      adaptiveQuality: true,
      // ignore: experimental_member_use
      adaptiveConfig: GlassAdaptiveScopeConfig(
        targetFrameMs: 8,
        minQuality: .minimal,
        initialQuality: .standard,
        maxQuality: .standard,
        allowStepUp: false,
        onQualityChanged: (oldQuality, newQuality) {
          logd("Quality changed for liquid glass: ${oldQuality.name} -> ${newQuality.name}");
        },
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
  const SesoriApp({required this.initialAppearance, super.key});

  /// The persisted appearance, read before the first frame.
  final AppearanceMode initialAppearance;

  @override
  Widget build(BuildContext context) {
    // Above the router so the whole app — including full-screen modal routes —
    // rebuilds when the appearance choice changes.
    return BlocProvider<AppearanceCubit>(
      create: (_) => AppearanceCubit(
        store: getIt<AppearanceStore>(),
        initialMode: initialAppearance,
      ),
      child: const _SesoriAppShell(),
    );
  }
}

class _SesoriAppShell extends StatelessWidget {
  const _SesoriAppShell();

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<AppearanceCubit>().state.themeMode;

    return MaterialApp.router(
      onGenerateTitle: (context) => context.loc.appTitle,
      themeMode: themeMode,
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
      builder: (context, child) => BlocProvider(
        // Provides the connection cubit app-wide (above the router) so every
        // screen's `ConnectionBanner.maybeFor` can watch it. There is no visual
        // overlay any more — the bridge-offline and connection-lost states
        // surface as an inline banner in each screen's top navigation.
        create: (_) => ConnectionOverlayCubit(
          getIt<ConnectionService>(),
          getIt<RegisteredBridgesService>(),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
