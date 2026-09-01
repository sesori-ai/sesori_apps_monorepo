import "dart:async";
import "dart:ui" as ui;

import "package:cupertino_ui/cupertino_ui.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "core/di/analytics_runtime_bootstrap.dart";
import "core/di/injection.dart";
import "core/extensions/appearance_mode_x.dart";
import "core/platform/firebase/firebase_messaging_static_adapter.dart";
import "core/platform/firebase_analytics_startup.dart";
import "core/platform/singular_attribution_startup.dart";
import "core/routing/app_router.dart";
import "core/routing/deep_link_service.dart";
import "firebase_options.dart";

const _singularSdkKeyDefine = String.fromEnvironment("SESORI_SINGULAR_SDK_KEY");
const _singularSdkSecretDefine = String.fromEnvironment("SESORI_SINGULAR_SDK_SECRET");

@pragma("vm:entry-point")
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void _configureFirebaseSdk({
  required bool supportsCrashlytics,
}) {
  getIt<FirebaseMessagingStaticAdapter>().registerBackgroundHandler(
    handler: _firebaseMessagingBackgroundHandler,
  );

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
  final shouldInitializeFirebase = _supportsFirebase;
  final supportsFirebaseAnalytics = _supportsFirebase;
  final supportsFirebaseCrashlytics = _supportsFirebase;
  if (shouldInitializeFirebase) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  await bootstrapSesoriApp(
    shouldInitializeFirebase: shouldInitializeFirebase,
    configureDependenciesFn: () async {
      final analyticsBootstrap = await configureDependencies(
        firebaseEnabled: shouldInitializeFirebase,
        createAnalyticsRuntimeBootstrap: ({required crawlGateService}) => _createAnalyticsRuntimeBootstrap(
          shouldInitializeFirebase: shouldInitializeFirebase,
          supportsFirebaseAnalytics: supportsFirebaseAnalytics,
          crawlGateService: crawlGateService,
        ),
      );
      _configureFirebaseSdk(
        supportsCrashlytics: supportsFirebaseCrashlytics,
      );
      return analyticsBootstrap;
    },
    prepareSingularAttributionFn: _prepareSingularAttribution,
    applySingularCrawlGateFn: _applySingularCrawlGate,
    initializeDeepLinks: () => getIt<DeepLinkService>().init(),
    startProductAnalyticsFn: () => getIt<ProductAnalyticsService>().start(),
    startAnalyticsRouteListenerFn: () => getIt<AnalyticsRouteListener>().start(),
    startNotificationStartupFn: () => startNotificationStartup(
      localNotificationClient: getIt<LocalNotificationClient>(),
      pushMessagingSource: getIt<PushMessagingSource>(),
      notificationRegistrationService: getIt<NotificationRegistrationService>(),
      foregroundNotificationDispatcher: getIt<ForegroundNotificationDispatcher>(),
      notificationOpenDispatcher: getIt<NotificationOpenDispatcher>(),
    ),
    readAppearanceFn: () => getIt<AppearanceStore>().read(),
    readChatInputModeFn: () => getIt<ChatInputModeStore>().read(),
    runAppFn: runApp,
  );
}

Future<void> bootstrapSesoriApp({
  required bool shouldInitializeFirebase,
  required Future<AnalyticsRuntimeBootstrap> Function() configureDependenciesFn,
  required void Function() prepareSingularAttributionFn,
  required void Function({required AnalyticsStoreCrawlGate crawlGate}) applySingularCrawlGateFn,
  required void Function() initializeDeepLinks,
  required Future<void> Function() startProductAnalyticsFn,
  required Future<void> Function() startAnalyticsRouteListenerFn,
  required Future<void> Function() startNotificationStartupFn,
  required Future<AppearanceMode> Function() readAppearanceFn,
  required Future<ChatInputMode> Function() readChatInputModeFn,
  required void Function(Widget app) runAppFn,
}) async {
  final analyticsBootstrap = await configureDependenciesFn();
  prepareSingularAttributionFn();
  initializeDeepLinks();
  await startProductAnalyticsFn();
  await startAnalyticsRouteListenerFn();
  if (shouldInitializeFirebase) {
    unawaited(
      startNotificationStartupFn().catchError((Object error, StackTrace stackTrace) {
        loge("Error bootstrapping notification startup", error, stackTrace);
      }),
    );
  }

  // Awaited: the persisted theme has to be in place before the first frame,
  // otherwise a pinned light/dark choice flashes the device theme on launch.
  // The chat input mode rides along concurrently — same store, and reading it
  // here keeps the composer preference synchronous for the rest of the app.
  // Both reads swallow their own failures, so the parallel wait cannot throw.
  final (appearance, chatInputMode) = await (readAppearanceFn(), readChatInputModeFn()).wait;

  final isImpeller = ui.ImageFilter.isShaderFilterSupported;

  if (isImpeller) {
    logd("🚀 Running on Impeller Rendering Engine");
  } else {
    logd("🎨 Running on Skia Rendering Engine (or fallback)");
  }

  runAppFn(
    LiquidGlassWidgets.wrap(
      child: SesoriApp(initialAppearance: appearance, initialChatInputMode: chatInputMode),
      brightnessResolver: Theme.maybeBrightnessOf,
      adaptiveQuality: true,
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

  unawaited(
    _completeAnalyticsStartup(
      crawlGate: analyticsBootstrap.crawlGate,
      applySingularCrawlGateFn: applySingularCrawlGateFn,
    ),
  );
}

Future<void> _completeAnalyticsStartup({
  required Future<AnalyticsStoreCrawlGate> crawlGate,
  required void Function({required AnalyticsStoreCrawlGate crawlGate}) applySingularCrawlGateFn,
}) async {
  try {
    applySingularCrawlGateFn(crawlGate: await crawlGate);
  } on Object catch (error, stackTrace) {
    logw("Error completing analytics startup", error, stackTrace);
  }
}

Future<AnalyticsRuntimeBootstrap> _createAnalyticsRuntimeBootstrap({
  required bool shouldInitializeFirebase,
  required bool supportsFirebaseAnalytics,
  required AnalyticsCrawlGateService crawlGateService,
}) async {
  if (!shouldInitializeFirebase || !supportsFirebaseAnalytics) {
    return AnalyticsRuntimeBootstrap(
      capability: const AnalyticsRuntimeCapability.disabled(
        reason: AnalyticsRuntimeDisabledReason.analyticsSinkUnavailable,
      ),
      crawlGate: Future.value(AnalyticsStoreCrawlGate.allow),
    );
  }

  final ineligibilityReason = _measurementIneligibilityReason();
  final analyticsStartup = getIt<FirebaseAnalyticsStartup>();
  final capability = await analyticsStartup.prepare(ineligibilityReason: ineligibilityReason);
  if (capability case AnalyticsRuntimeDisabled(:final reason)) {
    logi("Firebase analytics runtime disabled (${reason.name})");
    return AnalyticsRuntimeBootstrap(
      capability: capability,
      crawlGate: Future.value(AnalyticsStoreCrawlGate.allow),
    );
  }

  return AnalyticsRuntimeBootstrap(
    capability: capability,
    crawlGate: _resolveAndApplyAnalyticsCrawlGate(
      analyticsStartup: analyticsStartup,
      crawlGateService: crawlGateService,
      eligibility: defaultTargetPlatform == TargetPlatform.android
          ? AnalyticsCrawlGateEligibility.eligibleRelease
          : AnalyticsCrawlGateEligibility.ineligible,
    ),
  );
}

Future<AnalyticsStoreCrawlGate> _resolveAndApplyAnalyticsCrawlGate({
  required FirebaseAnalyticsStartup analyticsStartup,
  required AnalyticsCrawlGateService crawlGateService,
  required AnalyticsCrawlGateEligibility eligibility,
}) async {
  var crawlGate = AnalyticsStoreCrawlGate.allow;
  try {
    crawlGate = await crawlGateService.resolve(eligibility: eligibility);
  } on Object catch (error, stackTrace) {
    logw("Failed to resolve the analytics store-crawl gate; allowing analytics", error, stackTrace);
  }
  await analyticsStartup.applyCrawlGate(crawlGate: crawlGate);
  return crawlGate;
}

void _prepareSingularAttribution() {
  getIt<SingularAttributionStartup>().prepare(
    isSupportedPlatform: _supportsSingular,
    ineligibilityReason: _measurementIneligibilityReason(),
    sdkKey: _singularSdkKeyDefine,
    sdkSecret: _singularSdkSecretDefine,
  );
}

void _applySingularCrawlGate({required AnalyticsStoreCrawlGate crawlGate}) {
  getIt<SingularAttributionStartup>().applyCrawlGate(crawlGate: crawlGate);
}

/// Why this process must never report analytics, or null when it may.
AnalyticsRuntimeDisabledReason? _measurementIneligibilityReason() =>
    kReleaseMode ? null : AnalyticsRuntimeDisabledReason.debugOrProfile;

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

bool get _supportsFirebase {
  if (kIsWeb) {
    return false;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => !kProfileMode,
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.windows => false,
  };
}

bool get _supportsSingular {
  if (kIsWeb) return false;

  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows => false,
  };
}

class const SesoriApp({
  /// The persisted appearance, read before the first frame.
  required final AppearanceMode initialAppearance,

  /// The persisted chat input preference, read alongside the appearance.
  required final ChatInputMode initialChatInputMode,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Above the router so the whole app — including full-screen modal routes —
    // rebuilds when the appearance or chat input choice changes.
    return MultiBlocProvider(
      providers: [
        BlocProvider<AppearanceCubit>(
          create: (_) => AppearanceCubit(
            store: getIt<AppearanceStore>(),
            initialMode: initialAppearance,
          ),
        ),
        BlocProvider<ChatInputModeCubit>(
          create: (_) => ChatInputModeCubit(
            store: getIt<ChatInputModeStore>(),
            initialMode: initialChatInputMode,
          ),
        ),
      ],
      child: const _SesoriAppShell(),
    );
  }
}

class const _SesoriAppShell() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<AppearanceCubit>().state.themeMode;

    return MaterialApp.router(
      onGenerateTitle: (context) => context.loc.appTitle,
      themeMode: themeMode,
      theme: buildPregoThemeData(brightness: Brightness.light),
      darkTheme: buildPregoThemeData(brightness: Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
      // Legacy UI dependencies still need the SDK theme/localization types.
      // ignore: deprecated_member_use
      builder: (context, child) => MaterialUiCompatibilityBridge(
        // ignore: deprecated_member_use
        child: CupertinoUiCompatibilityBridge(
          child: BlocProvider(
            // Provides the connection cubit app-wide (above the router) so every
            // screen's `ConnectionBanner.maybeFor` can watch it. There is no visual
            // overlay any more — the bridge-offline and connection-lost states
            // surface as an inline banner in each screen's top navigation.
            create: (_) => ConnectionOverlayCubit(
              getIt<ConnectionService>(),
              getIt<RegisteredBridgesService>(),
            ),
            child: BlocProvider(
              create: (_) => SseToastCubit(
                connectionService: getIt<ConnectionService>(),
                routeSource: getIt<RouteSource>(),
              ),
              child: SseToastListener(
                navigatorKey: appRootNavigatorKey,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
