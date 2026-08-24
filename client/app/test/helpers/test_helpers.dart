import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_svg/flutter_svg.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:mocktail/mocktail.dart";
import "package:record/record.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:sesori_dart_core/src/services/session_activity_calculator.dart";
import "package:sesori_dart_core/testing.dart";

import "package:sesori_mobile/capabilities/voice/audio_format_config.dart";
import "package:sesori_mobile/capabilities/voice/recorder_prewarm_client.dart";
import "package:sesori_mobile/capabilities/voice/recording_file_provider.dart";
import "package:sesori_mobile/capabilities/voice/wake_lock_service.dart";
import "package:sesori_mobile/core/di/injection.dart";
export "package:sesori_dart_core/testing.dart";

// ---------------------------------------------------------------------------
// Mock classes
// ---------------------------------------------------------------------------

/// A fixed-state [ConnectionOverlayCubit] stand-in for widget tests.
///
/// Screens read the cubit through `ConnectionBanner.maybeFor` to decide
/// whether the top-nav connection banner shows, so any harness that pumps a
/// screen must provide one. Defaults to a connected [ConnectionOverlayHidden]
/// (no banner, chain up); pass e.g. `ConnectionOverlayState.bridgeOffline()`
/// to exercise the banner.
class StubConnectionOverlayCubit({
  ConnectionOverlayState initialState = const ConnectionOverlayState.hidden(connected: true),
}) extends Cubit<ConnectionOverlayState> implements ConnectionOverlayCubit {
  this : super(initialState);

  @override
  void reconnect() {}
}

/// The composer resolves its resting layout (hold-to-talk vs tap-to-type)
/// from [ChatInputModeCubit], so any harness that pumps a composer-bearing
/// screen must provide one. Defaults to the app default, voice-first.
class StubChatInputModeCubit({ChatInputMode initialState = ChatInputMode.voiceFirst})
    extends Cubit<ChatInputMode>
    implements ChatInputModeCubit {
  this : super(initialState);

  @override
  Future<void> select({required ChatInputMode mode}) async => emit(mode);
}

class MockAudioRecorder() extends Mock implements AudioRecorder;

class MockRecorderPrewarmClient() extends Mock implements RecorderPrewarmClient;

class MockRecordingFileProvider() extends Mock implements RecordingFileProvider;

class MockWakeLockService() extends Mock implements WakeLockService;

class MockAudioFormatConfig() extends Mock implements AudioFormatConfig;

class MockFlutterSecureStorage() extends Mock implements FlutterSecureStorage;

void stubProductAnalyticsService({required MockProductAnalyticsService service}) {
  final states = BehaviorSubject<ProductAnalyticsState>.seeded(ProductAnalyticsState.initial);
  addTearDown(states.close);
  when(
    () => service.logEvent(
      event: any(named: "event"),
      occurredAtUtc: any(named: "occurredAtUtc"),
    ),
  ).thenAnswer((_) async => AnalyticsDeliveryResult.acceptedBySdk);
  when(() => service.state).thenAnswer((_) => states.value);
  when(() => service.stateStream).thenAnswer((_) => states.stream);
}

void registerListServices({
  required MockProjectRepository projectRepository,
}) {
  _registerListServices(projectRepository: projectRepository, productAnalyticsService: null);
}

void registerListServicesWithProductAnalytics({
  required MockProjectRepository projectRepository,
  required MockProductAnalyticsService productAnalyticsService,
}) {
  _registerListServices(
    projectRepository: projectRepository,
    productAnalyticsService: productAnalyticsService,
  );
}

void _registerListServices({
  required MockProjectRepository projectRepository,
  required MockProductAnalyticsService? productAnalyticsService,
}) {
  if (getIt.isRegistered<ProjectListService>()) {
    getIt.unregister<ProjectListService>();
  }
  if (getIt.isRegistered<SessionListService>()) {
    getIt.unregister<SessionListService>();
  }
  if (getIt.isRegistered<ProductAnalyticsService>()) {
    getIt.unregister<ProductAnalyticsService>();
  }
  final analyticsService = productAnalyticsService ?? MockProductAnalyticsService();
  stubProductAnalyticsService(service: analyticsService);
  getIt.registerSingleton<ProjectListService>(
    ProjectListService(
      repository: projectRepository,
      activityCalculator: const SessionActivityCalculator(),
    ),
  );
  getIt.registerSingleton<SessionListService>(
    SessionListService(
      repository: projectRepository,
      activityCalculator: const SessionActivityCalculator(),
    ),
  );
  getIt.registerSingleton<ProductAnalyticsService>(analyticsService);
  // The list cubits project the catalog scan onto their state, so every test
  // that renders a list needs one. Registered here rather than per test file
  // because it is a dependency of the lists themselves, not of any one screen.
  if (getIt.isRegistered<CatalogRescanService>()) {
    getIt.unregister<CatalogRescanService>();
  }
  getIt.registerSingleton<CatalogRescanService>(FakeCatalogRescanService());
}

class MockFirebaseCrashlytics() extends Mock implements FirebaseCrashlytics;

class MockFirebaseAnalytics() extends Mock implements FirebaseAnalytics;

// ---------------------------------------------------------------------------
// Fake classes — for registerFallbackValue
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// registerAllFallbackValues
// ---------------------------------------------------------------------------

/// Registers all fallback values required by mocktail argument matchers.
///
/// Call once in [setUpAll] before any test group that uses [any()] or
/// [captureAny()] for [ServerConnectionConfig] or [Uri] parameters.
void registerAllFallbackValues() {
  registerCoreFallbackValues();
  registerFallbackValue(const RecordConfig());
  registerFallbackValue(http.MultipartFile.fromString("audio", ""));
  registerFallbackValue(AuthProvider.github);
}

/// Finds the brand artwork [PregoBrandLogo] draws for [pluginId].
///
/// Matched by asset rather than by rendered pixels: the artwork is what the
/// component promises for a harness it knows, and loading it would mean
/// decoding an SVG per assertion. Monochrome marks ship a `_light` and a
/// `_dark` export, so the basename is matched with that optional suffix.
Finder findBrandLogo(String pluginId) => find.byWidgetPredicate((widget) {
  if (widget is! SvgPicture) return false;
  final loader = widget.bytesLoader;
  return loader is SvgAssetLoader &&
      RegExp("/${RegExp.escape(pluginId)}(_light|_dark)?\\.svg\$").hasMatch(loader.assetName);
}, description: "brand artwork for $pluginId");
