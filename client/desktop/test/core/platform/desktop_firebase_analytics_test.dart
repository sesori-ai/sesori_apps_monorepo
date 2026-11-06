import "dart:io";

import "package:firebase_analytics/firebase_analytics.dart";
import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/platform/desktop_firebase_analytics.dart";
import "package:sesori_desktop/core/platform/desktop_firebase_sdk.dart";

class _MockSdk() extends Mock implements DesktopFirebaseSdk;

class _MockAnalytics() extends Mock implements FirebaseAnalytics;

void main() {
  late _MockSdk sdk;
  late _MockAnalytics analytics;
  late DesktopFirebaseAnalytics client;

  setUp(() {
    sdk = _MockSdk();
    analytics = _MockAnalytics();
    when(sdk.initialize).thenAnswer((_) async => analytics);
    when(() => analytics.setAnalyticsCollectionEnabled(any())).thenAnswer((_) async {});
    when(
      () => analytics.setConsent(
        adPersonalizationSignalsConsentGranted: false,
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        personalizationStorageConsentGranted: false,
        securityStorageConsentGranted: false,
        analyticsStorageConsentGranted: true,
        functionalityStorageConsentGranted: true,
      ),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logEvent(
        name: any(named: "name"),
        parameters: any(named: "parameters"),
      ),
    ).thenAnswer((_) async {});
    client = DesktopFirebaseAnalytics(sdk: sdk, capability: const AnalyticsRuntimeCapability.enabled());
  });

  test("macOS enables usage analytics only after denying advertising consent", () async {
    await client.initialize(platform: TargetPlatform.macOS);

    verifyInOrder([
      sdk.initialize,
      () => analytics.setAnalyticsCollectionEnabled(false),
      () => analytics.setConsent(
        adPersonalizationSignalsConsentGranted: false,
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        personalizationStorageConsentGranted: false,
        securityStorageConsentGranted: false,
        analyticsStorageConsentGranted: true,
        functionalityStorageConsentGranted: true,
      ),
      () => analytics.setAnalyticsCollectionEnabled(true),
    ]);
    verifyNoMoreInteractions(analytics);
  });

  for (final platform in TargetPlatform.values.where((value) => value != TargetPlatform.macOS)) {
    test("$platform never initializes Firebase or reports installation events", () async {
      await client.initialize(platform: platform);
      await client.logInstallationEvent(
        event: const InstallationAnalyticsEvent.accountLogin(method: AnalyticsLoginProvider.github),
      );

      verifyZeroInteractions(sdk);
      verifyZeroInteractions(analytics);
    });
  }

  for (final reason in [
    AnalyticsRuntimeDisabledReason.debugOrProfile,
    AnalyticsRuntimeDisabledReason.analyticsSinkUnavailable,
  ]) {
    test("disabled $reason runtime never initializes Firebase", () async {
      final disabled = DesktopFirebaseAnalytics(
        sdk: sdk,
        capability: AnalyticsRuntimeCapability.disabled(reason: reason),
      );
      await disabled.initialize(platform: TargetPlatform.macOS);
      await disabled.logInstallationEvent(
        event: const InstallationAnalyticsEvent.accountLogin(method: AnalyticsLoginProvider.github),
      );

      verifyZeroInteractions(sdk);
      verifyZeroInteractions(analytics);
    });
  }

  test("initialization failure does not block startup or admit later events", () async {
    when(sdk.initialize).thenThrow(StateError("native initialization failed"));

    await expectLater(client.initialize(platform: TargetPlatform.macOS), completes);
    await client.logInstallationEvent(
      event: const InstallationAnalyticsEvent.accountLogin(method: AnalyticsLoginProvider.github),
    );
    verifyZeroInteractions(analytics);
  });

  test("consent failure keeps collection disabled and admits no custom events", () async {
    when(
      () => analytics.setConsent(
        adPersonalizationSignalsConsentGranted: false,
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        personalizationStorageConsentGranted: false,
        securityStorageConsentGranted: false,
        analyticsStorageConsentGranted: true,
        functionalityStorageConsentGranted: true,
      ),
    ).thenThrow(StateError("native consent failed"));

    await expectLater(client.initialize(platform: TargetPlatform.macOS), completes);
    await client.logInstallationEvent(
      event: const InstallationAnalyticsEvent.accountLogin(method: AnalyticsLoginProvider.github),
    );
    verifyNever(() => analytics.setAnalyticsCollectionEnabled(true));
    verifyNever(
      () => analytics.logEvent(
        name: any(named: "name"),
        parameters: any(named: "parameters"),
      ),
    );
  });

  test("reports the five approved authentication events without account identity", () async {
    await client.initialize(platform: TargetPlatform.macOS);
    clearInteractions(analytics);

    for (final event in [
      const InstallationAnalyticsEvent.loginAttemptStarted(provider: AnalyticsLoginProvider.github),
      const InstallationAnalyticsEvent.loginAttemptCompleted(provider: AnalyticsLoginProvider.github),
      const InstallationAnalyticsEvent.loginAttemptFailed(
        provider: AnalyticsLoginProvider.github,
        failureKind: AnalyticsLoginFailureKind.cancelled,
      ),
      const InstallationAnalyticsEvent.accountCreated(method: AnalyticsLoginProvider.github),
      const InstallationAnalyticsEvent.accountLogin(method: AnalyticsLoginProvider.github),
    ]) {
      await client.logInstallationEvent(event: event);
    }

    verifyInOrder([
      () => analytics.logEvent(name: "login_attempt_started", parameters: {"provider": "github", "schema_version": 1}),
      () =>
          analytics.logEvent(name: "login_attempt_completed", parameters: {"provider": "github", "schema_version": 1}),
      () => analytics.logEvent(
        name: "login_attempt_failed",
        parameters: {"provider": "github", "failure_kind": "cancelled", "schema_version": 1},
      ),
      () => analytics.logEvent(name: "sign_up", parameters: {"method": "github", "schema_version": 1}),
      () => analytics.logEvent(name: "login", parameters: {"method": "github", "schema_version": 1}),
    ]);
    verifyNoMoreInteractions(analytics);
  });

  test("a Firebase event failure cannot fail authentication", () async {
    await client.initialize(platform: TargetPlatform.macOS);
    when(
      () => analytics.logEvent(
        name: any(named: "name"),
        parameters: any(named: "parameters"),
      ),
    ).thenThrow(StateError("native event failed"));

    await expectLater(
      client.logInstallationEvent(
        event: const InstallationAnalyticsEvent.accountLogin(method: AnalyticsLoginProvider.github),
      ),
      completes,
    );
  });

  test("native collection, screen reporting and advertising default off", () {
    final plist = File("macos/Runner/Info.plist").readAsStringSync();
    for (final key in [
      "FIREBASE_ANALYTICS_COLLECTION_ENABLED",
      "FirebaseAutomaticScreenReportingEnabled",
      "GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS",
      "GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_STORAGE",
      "GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_USER_DATA",
    ]) {
      expect(plist, matches(RegExp("<key>$key</key>\\s*<false\\s*/>")), reason: key);
    }
  });

  test("native analytics initialization follows primary admission and precedes rendering", () {
    final code = File("lib/main.dart").readAsStringSync();
    const initialize = "getIt<DesktopFirebaseAnalytics>().initialize(platform: defaultTargetPlatform)";
    expect(initialize.allMatches(code), hasLength(1));
    expect(code.indexOf(initialize), greaterThan(code.indexOf('logi("Desktop startup: primary process claimed")')));
    expect(code.indexOf(initialize), lessThan(code.indexOf("runApp(")));
  });

  test("no bundled default Firebase plist can eagerly initialize a secondary process", () {
    expect(File("macos/Runner/GoogleService-Info.plist").existsSync(), isFalse);
    expect(
      File("macos/Runner.xcodeproj/project.pbxproj").readAsStringSync(),
      isNot(contains("GoogleService-Info.plist")),
    );
  });
}
