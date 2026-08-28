import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/core/platform/firebase/firebase_messaging_static_adapter.dart";
import "package:sesori_mobile/core/platform/firebase/no_op_analytics_client.dart";
import "package:sesori_mobile/core/platform/firebase/no_op_failure_reporter.dart";
import "package:sesori_mobile/core/platform/firebase/no_op_push_messaging_source.dart";
import "package:sesori_mobile/core/platform/singular/singular_attribution_client.dart";
import "package:sesori_mobile/core/platform/singular/singular_static_adapter.dart";
import "package:sesori_shared/sesori_shared.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await configureDependencies(
      firebaseEnabled: false,
      createAnalyticsRuntimeCapability: ({required authSession}) async => const AnalyticsRuntimeCapability.disabled(
        reason: AnalyticsRuntimeDisabledReason.analyticsSinkUnavailable,
      ),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  test("disabled Firebase environment binds the interfaces to no-ops", () {
    expect(getIt<AnalyticsClient>(), isA<NoOpAnalyticsClient>());
    expect(getIt<FailureReporter>(), isA<NoOpFailureReporter>());
    expect(getIt<PushMessagingSource>(), isA<NoOpPushMessagingSource>());
  });

  test("Singular attribution resolves independently of Firebase", () {
    expect(getIt<AttributionClient>(), isA<SingularAttributionClient>());
    expect(getIt<SingularStaticAdapter>(), isA<SingularStaticAdapter>());
    expect(getIt<InstallationAnalyticsService>(), isA<InstallationAnalyticsService>());
  });

  test("disabled Firebase environment registers no FlutterFire SDK object", () {
    // The app talks to Firebase only through the three interfaces above, so a
    // build without the SDK has nothing to stand in for these. Registering
    // substitutes for them is what this step removed; keep it removed.
    expect(getIt.isRegistered<FirebaseApp>(), isFalse);
    expect(getIt.isRegistered<FirebaseMessaging>(), isFalse);
    expect(getIt.isRegistered<FirebaseAnalytics>(), isFalse);
    expect(getIt.isRegistered<FirebaseCrashlytics>(), isFalse);
  });

  test("the static messaging adapter still resolves, because startup always uses it", () async {
    // main() calls registerBackgroundHandler unconditionally, so this one keeps
    // a disabled-environment registration.
    final staticAdapter = getIt<FirebaseMessagingStaticAdapter>();
    staticAdapter.registerBackgroundHandler(handler: (_) async {});
    await expectLater(staticAdapter.foregroundMessageStream, emitsDone);
    await expectLater(staticAdapter.notificationOpenedStream, emitsDone);
  });

  test("the no-op push source yields no token and no events", () async {
    final pushMessagingSource = getIt<PushMessagingSource>();
    await pushMessagingSource.initialize();
    expect(await pushMessagingSource.getToken(), isNull);
    await pushMessagingSource.deleteToken();
    expect(await pushMessagingSource.getInitialNotificationOpen(), isNull);
    await expectLater(pushMessagingSource.tokenRefreshStream, emitsDone);
    await expectLater(pushMessagingSource.foregroundMessageStream, emitsDone);
    await expectLater(pushMessagingSource.notificationOpenedStream, emitsDone);
  });

  test("the no-op analytics and failure reporter accept calls without a sink", () async {
    await getIt<AnalyticsClient>().logInstallationEvent(
      event: const LoginAttemptStartedEvent(provider: AnalyticsLoginProvider.apple),
    );
    final reporter = getIt<FailureReporter>();
    reporter.log(message: "ignored");
    reporter.setGlobalKey(key: "ignored", value: 1);
    await reporter.recordFailure(
      error: Exception("ignored"),
      stackTrace: StackTrace.current,
      uniqueIdentifier: "ignored",
      fatal: false,
      reason: null,
      information: const <Object>[],
    );
  });

  test("services that depend on the no-ops still resolve", () {
    expect(getIt<ProductAnalyticsService>(), isA<ProductAnalyticsService>());
    expect(getIt<AnalyticsRouteListener>(), isA<AnalyticsRouteListener>());
    // Resolved from the settings and profile screens on every platform, which
    // is why PushMessagingSource needs a disabled-environment binding at all.
    expect(getIt<NotificationRegistrationService>(), isA<NotificationRegistrationService>());
    expect(getIt.isRegistered<AttachmentThumbnailStorage>(), isTrue);
    expect(getIt.checkLazySingletonInstanceExists<MessageThumbnailCacheService>(), isTrue);
    expect(getIt<AnalyticsRuntimeCapability>().isEnabled, isFalse);
  });
}
