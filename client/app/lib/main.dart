import "dart:async";
import "dart:ui" as ui;

import "package:cupertino_ui/cupertino_ui.dart";
import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "core/di/injection.dart";
import "core/extensions/appearance_mode_x.dart";
import "core/extensions/build_context_x.dart";
import "core/platform/firebase/firebase_messaging_static_adapter.dart";
import "core/platform/firebase_analytics_startup.dart";
import "core/routing/app_router.dart";
import "core/routing/deep_link_service.dart";
import "firebase_options.dart";
import "l10n/app_localizations.dart";

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
  final shouldInitializeFirebase = _shouldInitializeFirebase;
  final supportsFirebaseAnalytics = _supportsFirebaseAnalytics;
  final supportsFirebaseCrashlytics = _supportsFirebaseCrashlytics;
  if (shouldInitializeFirebase) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  await bootstrapSesoriApp(
    shouldInitializeFirebase: shouldInitializeFirebase,
    configureDependenciesFn: () async {
      await configureDependencies(
        firebaseEnabled: shouldInitializeFirebase,
        createAnalyticsRuntimeCapability: ({required authSession}) => _createAnalyticsRuntimeCapability(
          shouldInitializeFirebase: shouldInitializeFirebase,
          supportsFirebaseAnalytics: supportsFirebaseAnalytics,
          authSession: authSession,
        ),
      );
      _configureFirebaseSdk(
        supportsCrashlytics: supportsFirebaseCrashlytics,
      );
    },
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
  required Future<void> Function() configureDependenciesFn,
  required void Function() initializeDeepLinks,
  required Future<void> Function() startProductAnalyticsFn,
  required Future<void> Function() startAnalyticsRouteListenerFn,
  required Future<void> Function() startNotificationStartupFn,
  required Future<AppearanceMode> Function() readAppearanceFn,
  required Future<ChatInputMode> Function() readChatInputModeFn,
  required void Function(Widget app) runAppFn,
}) async {
  await configureDependenciesFn();
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
}

Future<AnalyticsRuntimeCapability> _createAnalyticsRuntimeCapability({
  required bool shouldInitializeFirebase,
  required bool supportsFirebaseAnalytics,
  required AuthSession authSession,
}) async {
  final capability = !shouldInitializeFirebase || !supportsFirebaseAnalytics
      ? const AnalyticsRuntimeCapability.disabled(
          reason: AnalyticsRuntimeDisabledReason.analyticsSinkUnavailable,
        )
      : await FirebaseAnalyticsStartup(analytics: FirebaseAnalytics.instance).configure(
          ineligibilityReason: await _analyticsIneligibilityReason(authSession: authSession),
        );
  if (capability case AnalyticsRuntimeDisabled(:final reason)) {
    logi("Firebase analytics runtime disabled (${reason.name})");
  }
  return capability;
}

/// Unix seconds at which the release lanes compiled this binary. Builds made
/// outside those lanes leave it 0, which reads as a build too old for a store
/// crawl to still be running it.
const _buildEpochSeconds = int.fromEnvironment("SESORI_BUILD_EPOCH_SECONDS");

/// How long after compilation a store may still be crawling the binary. Play
/// runs its pre-launch report against every track upload "subject to capacity",
/// so this is a heuristic on Google's scheduling delay, not a contract.
const _buildWindow = Duration(hours: 2);

/// Whether a binary stamped at [buildEpochSeconds] could still be under a store
/// pre-launch crawl at [now].
bool isWithinBuildWindow({required int buildEpochSeconds, required DateTime now}) =>
    buildEpochSeconds > 0 &&
    now.isBefore(DateTime.fromMillisecondsSinceEpoch(buildEpochSeconds * 1000, isUtc: true).add(_buildWindow));

/// Why this process must not report analytics, or null when it may.
///
/// Store crawlers never sign in, so an unauthenticated launch inside the build
/// window is treated as one. A signed-in device keeps reporting at any time.
Future<AnalyticsRuntimeDisabledReason?> _analyticsIneligibilityReason({required AuthSession authSession}) async {
  if (!kReleaseMode) return AnalyticsRuntimeDisabledReason.debugOrProfile;
  if (isWithinBuildWindow(buildEpochSeconds: _buildEpochSeconds, now: DateTime.now()) &&
      !await authSession.hasLocallyValidSession()) {
    return AnalyticsRuntimeDisabledReason.recentBuildUnauthenticated;
  }
  return null;
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
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
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
              create: (_) => SseToastCubit(getIt<ConnectionService>()),
              child: _SseToastListener(child: child ?? const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders backend toast states through the design-system popup alert
/// presenter, so guidance such as a local `/login` hint reaches the user on
/// any screen, including startup routes with no scaffold.
class const _SseToastListener({required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocListener<SseToastCubit, SseToastState>(
      listener: (context, state) {
        if (state case SseToastShow(:final title, :final message, :final variant)) {
          final overlay = appRootNavigatorKey.currentState?.overlay;
          if (overlay == null) return;
          PregoPopupAlertPresenter.fromOverlayState(overlay).show(
            title: title ?? message,
            content: title == null ? const PregoPopupAlertContent() : PregoPopupAlertContent(message: message),
            variant: switch (variant) {
              SseToastVariant.info => PregoPopupAlertsNotificationsVariant.info,
              SseToastVariant.success => PregoPopupAlertsNotificationsVariant.success,
              SseToastVariant.warning => PregoPopupAlertsNotificationsVariant.warning,
              SseToastVariant.error => PregoPopupAlertsNotificationsVariant.error,
            },
            duration: switch (variant) {
              SseToastVariant.error || SseToastVariant.warning => const Duration(seconds: 8),
              SseToastVariant.info || SseToastVariant.success => const Duration(seconds: 4),
            },
          );
        }
      },
      child: child,
    );
  }
}
