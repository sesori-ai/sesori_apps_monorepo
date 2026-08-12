import "package:firebase_analytics/firebase_analytics.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/firebase_analytics_client.dart";

const _serverDerivedUserKey = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
const _occurredAtMicros = 1720000000123456;

class MockFirebaseAnalytics extends Mock implements FirebaseAnalytics;

void main() {
  late MockFirebaseAnalytics analytics;
  late FirebaseAnalyticsClient client;

  setUp(() {
    analytics = MockFirebaseAnalytics();
    client = FirebaseAnalyticsClient(
      analytics: analytics,
      capability: const AnalyticsRuntimeCapability.enabled(),
    );
    when(
      () => analytics.logEvent(
        name: any(named: "name"),
        parameters: any(named: "parameters"),
      ),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logScreenView(
        screenName: any(named: "screenName"),
        screenClass: any(named: "screenClass"),
      ),
    ).thenAnswer((_) async {});
  });

  test("logs exact product wire parameters with the server-derived user key", () async {
    await client.logProductEvent(
      envelope: _productEnvelope(
        event: const ProductAnalyticsEvent.installCommandCopied(
          method: BridgeInstallMethod.powershell,
          os: BridgeInstallOs.windows,
          surface: OnboardingSurface.bridgeOffline,
        ),
      ),
      userKey: _serverDerivedUserKey,
    );

    verify(
      () => analytics.logEvent(
        name: "bridge_install_command_copied",
        parameters: {
          "method": "powershell",
          "os": "windows",
          "surface": "bridge_offline",
          "schema_version": 1,
          "user_key": _serverDerivedUserKey,
          "occurred_at_micros": _occurredAtMicros,
        },
      ),
    ).called(1);
    verifyNoMoreInteractions(analytics);
  });

  test("rejects malformed product user keys before calling Firebase", () async {
    final envelope = _productEnvelope(event: const ProductAnalyticsEvent.analyticsSchemaReady());
    final invalidUserKeys = [
      _serverDerivedUserKey.substring(1),
      _serverDerivedUserKey.toUpperCase(),
      "${_serverDerivedUserKey.substring(0, 63)}g",
    ];

    for (final userKey in invalidUserKeys) {
      await expectLater(
        client.logProductEvent(envelope: envelope, userKey: userKey),
        throwsArgumentError,
      );
    }

    verifyZeroInteractions(analytics);
  });

  test("rejects product and installation events when runtime analytics is disabled", () async {
    final disabledClient = FirebaseAnalyticsClient(
      analytics: analytics,
      capability: const AnalyticsRuntimeCapability.disabled(
        reason: AnalyticsRuntimeDisabledReason.debugOrProfile,
      ),
    );

    await expectLater(
      disabledClient.logProductEvent(
        envelope: _productEnvelope(event: const ProductAnalyticsEvent.analyticsSchemaReady()),
        userKey: _serverDerivedUserKey,
      ),
      throwsStateError,
    );
    expect(
      () => disabledClient.logInstallationEvent(
        event: const InstallationAnalyticsEvent.loginAttemptStarted(
          provider: AnalyticsLoginProvider.github,
        ),
      ),
      throwsStateError,
    );

    verifyZeroInteractions(analytics);
  });

  test("logs the canonical screen event before exactly one native mirror", () async {
    await client.logProductEvent(
      envelope: _productEnvelope(
        event: const ProductAnalyticsEvent.screenViewed(
          screen: AnalyticsScreen.sessionDetail,
        ),
      ),
      userKey: _serverDerivedUserKey,
    );

    verifyInOrder([
      () => analytics.logEvent(
        name: "product_screen_viewed",
        parameters: {
          "screen": "session_detail",
          "schema_version": 1,
          "user_key": _serverDerivedUserKey,
          "occurred_at_micros": _occurredAtMicros,
        },
      ),
      () => analytics.logScreenView(
        screenName: "session_detail",
        screenClass: "GoRouter",
      ),
    ]);
    verifyNoMoreInteractions(analytics);
  });

  test("does not fail canonical screen acceptance when the native mirror fails", () async {
    when(
      () => analytics.logScreenView(
        screenName: "settings",
        screenClass: "GoRouter",
      ),
    ).thenAnswer((_) async => throw StateError("native mirror failed"));

    await expectLater(
      client.logProductEvent(
        envelope: _productEnvelope(
          event: const ProductAnalyticsEvent.screenViewed(
            screen: AnalyticsScreen.settings,
          ),
        ),
        userKey: _serverDerivedUserKey,
      ),
      completes,
    );

    verifyInOrder([
      () => analytics.logEvent(
        name: "product_screen_viewed",
        parameters: {
          "screen": "settings",
          "schema_version": 1,
          "user_key": _serverDerivedUserKey,
          "occurred_at_micros": _occurredAtMicros,
        },
      ),
      () => analytics.logScreenView(
        screenName: "settings",
        screenClass: "GoRouter",
      ),
    ]);
    verifyNoMoreInteractions(analytics);
  });

  test("logs exact installation wire parameters without a user key", () async {
    await client.logInstallationEvent(
      event: const InstallationAnalyticsEvent.loginAttemptFailed(
        provider: AnalyticsLoginProvider.apple,
        failureKind: AnalyticsLoginFailureKind.cancelled,
      ),
    );

    final parameters =
        verify(
              () => analytics.logEvent(
                name: "login_attempt_failed",
                parameters: captureAny(named: "parameters"),
              ),
            ).captured.single
            as Map<String, Object>;
    expect(parameters, {
      "provider": "apple",
      "failure_kind": "cancelled",
      "schema_version": 1,
    });
    expect(parameters, isNot(contains("user_key")));
    verifyNoMoreInteractions(analytics);
  });
}

ProductAnalyticsEnvelope _productEnvelope({required ProductAnalyticsEvent event}) {
  return ProductAnalyticsEnvelope(
    event: event,
    occurredAtUtc: DateTime.fromMicrosecondsSinceEpoch(
      _occurredAtMicros,
      isUtc: true,
    ),
  );
}
