import "dart:io";

import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/platform/desktop_firebase_analytics.dart";
import "package:sesori_desktop/core/platform/desktop_firebase_sdk.dart";

class _MockSdk() extends Mock implements DesktopFirebaseSdk;

const _loginEvent = InstallationAnalyticsEvent.accountLogin(method: AnalyticsLoginProvider.github);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockSdk sdk;
  late DesktopFirebaseAnalytics client;

  setUp(() {
    sdk = _MockSdk();
    when(sdk.initialize).thenAnswer((_) async {});
    when(() => sdk.logInstallationEvent(event: _loginEvent)).thenAnswer((_) async {});
    client = DesktopFirebaseAnalytics(sdk: sdk, capability: const AnalyticsRuntimeCapability.enabled());
  });

  test("macOS initializes before reporting an authentication event", () async {
    await client.initialize(platform: TargetPlatform.macOS);
    await client.logInstallationEvent(event: _loginEvent);
    verifyInOrder([sdk.initialize, () => sdk.logInstallationEvent(event: _loginEvent)]);
    verifyNoMoreInteractions(sdk);
  });

  for (final platform in TargetPlatform.values.where((value) => value != TargetPlatform.macOS)) {
    test("$platform never initializes Firebase or reports installation events", () async {
      await client.initialize(platform: platform);
      await client.logInstallationEvent(event: _loginEvent);
      verifyZeroInteractions(sdk);
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
      await disabled.logInstallationEvent(event: _loginEvent);
      verifyZeroInteractions(sdk);
    });
  }

  test("initialization failure does not block startup or admit later events", () async {
    when(sdk.initialize).thenThrow(PlatformException(code: "firebase_configuration_missing"));
    await expectLater(client.initialize(platform: TargetPlatform.macOS), completes);
    await client.logInstallationEvent(event: _loginEvent);
    verifyNever(() => sdk.logInstallationEvent(event: _loginEvent));
  });

  test("a Firebase event failure cannot fail authentication", () async {
    await client.initialize(platform: TargetPlatform.macOS);
    when(() => sdk.logInstallationEvent(event: _loginEvent)).thenThrow(PlatformException(code: "native_event_failed"));
    await expectLater(client.logInstallationEvent(event: _loginEvent), completes);
  });

  group("native SDK channel", () {
    const channel = MethodChannel("sesori/desktop_firebase_analytics");
    late List<MethodCall> calls;
    late DesktopFirebaseSdk nativeSdk;

    setUp(() {
      calls = [];
      nativeSdk = DesktopFirebaseSdk(channel: channel);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    test("initialization invokes only the explicit native startup method", () async {
      await nativeSdk.initialize();
      expect(calls.single.method, "initialize");
      expect(calls.single.arguments, isNull);
    });

    test("reports exactly the five approved authentication payloads without identity", () async {
      for (final event in [
        const InstallationAnalyticsEvent.loginAttemptStarted(provider: AnalyticsLoginProvider.github),
        const InstallationAnalyticsEvent.loginAttemptCompleted(provider: AnalyticsLoginProvider.github),
        const InstallationAnalyticsEvent.loginAttemptFailed(
          provider: AnalyticsLoginProvider.github,
          failureKind: AnalyticsLoginFailureKind.cancelled,
        ),
        const InstallationAnalyticsEvent.accountCreated(method: AnalyticsLoginProvider.github),
        _loginEvent,
      ]) {
        await nativeSdk.logInstallationEvent(event: event);
      }
      expect(calls.map((call) => call.method), everyElement("logInstallationEvent"));
      expect(calls.map((call) => call.arguments), [
        {
          "name": "login_attempt_started",
          "parameters": {"provider": "github", "schema_version": 1},
        },
        {
          "name": "login_attempt_completed",
          "parameters": {"provider": "github", "schema_version": 1},
        },
        {
          "name": "login_attempt_failed",
          "parameters": {"provider": "github", "failure_kind": "cancelled", "schema_version": 1},
        },
        {
          "name": "sign_up",
          "parameters": {"method": "github", "schema_version": 1},
        },
        {
          "name": "login",
          "parameters": {"method": "github", "schema_version": 1},
        },
      ]);
    });

    test("native errors reach the failure-isolating adapter with their details", () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(
          code: "firebase_configuration_missing",
          message: "Missing desktop Firebase configuration",
        );
      });
      await expectLater(
        nativeSdk.initialize(),
        throwsA(isA<PlatformException>().having((error) => error.code, "code", "firebase_configuration_missing")),
      );
    });
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

  test("native initialization uses explicit options and denies advertising before enabling collection", () {
    final native = File("macos/Runner/DesktopFirebaseAnalyticsChannel.swift").readAsStringSync();
    expect(native, contains('Bundle.main.path(forResource: "DesktopFirebase-Info", ofType: "plist")'));
    expect(native, contains("FirebaseApp.configure(options: options)"));
    expect(native, contains(".analyticsStorage: .granted"));
    for (final consent in ["adStorage", "adUserData", "adPersonalization"]) {
      expect(native, contains(".$consent: .denied"));
    }
    expect(
      native.indexOf("Analytics.setConsent("),
      lessThan(native.indexOf("Analytics.setAnalyticsCollectionEnabled(true)")),
    );
    expect(native.indexOf('case "initialize":'), lessThan(native.indexOf("FirebaseApp.configure(")));
  });

  test("native analytics initialization follows primary admission and precedes rendering", () {
    final code = File("lib/main.dart").readAsStringSync();
    const initialize = "getIt<DesktopFirebaseAnalytics>().initialize(platform: defaultTargetPlatform)";
    expect(initialize.allMatches(code), hasLength(1));
    expect(code.indexOf(initialize), greaterThan(code.indexOf('logi("Desktop startup: primary process claimed")')));
    expect(code.indexOf(initialize), lessThan(code.indexOf("runApp(")));
  });

  test("no default Firebase configuration or FlutterFire plugin can eagerly initialize another process", () {
    expect(File("macos/Runner/GoogleService-Info.plist").existsSync(), isFalse);
    expect(
      File("macos/Runner.xcodeproj/project.pbxproj").readAsStringSync(),
      isNot(contains("GoogleService-Info.plist")),
    );
    expect(File("macos/Flutter/GeneratedPluginRegistrant.swift").readAsStringSync(), isNot(contains("firebase_core")));
    expect(File("windows/flutter/generated_plugins.cmake").readAsStringSync(), isNot(contains("firebase_core")));
  });

  test("the dedicated desktop Firebase app is configured and bundled separately from mobile", () {
    final config = File("macos/Runner/DesktopFirebase-Info.plist").readAsStringSync();
    expect(config, matches(RegExp(r"<key>BUNDLE_ID</key>\s*<string>com\.sesori\.desktop</string>")));
    expect(config, matches(RegExp(r"<key>PROJECT_ID</key>\s*<string>sesori-ai</string>")));
    expect(
      config,
      matches(RegExp(r"<key>GOOGLE_APP_ID</key>\s*<string>1:1068630921159:ios:6da01be1e22018c89713e2</string>")),
    );
    expect(
      File("macos/Runner.xcodeproj/project.pbxproj").readAsStringSync(),
      contains("DesktopFirebase-Info.plist in Resources"),
    );
  });
}
