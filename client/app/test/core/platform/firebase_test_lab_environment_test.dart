import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/core/platform/firebase_test_lab_environment.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel("com.sesori.app/firebase-test-lab");
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test("detects Firebase Test Lab from the Android platform channel", () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, "isRunning");
      return true;
    });

    expect(
      await const FirebaseTestLabEnvironment().detect(),
      FirebaseTestLabEnvironmentStatus.running,
    );
  });

  test("detects a normal Android runtime", () async {
    messenger.setMockMethodCallHandler(channel, (_) async => false);

    expect(
      await const FirebaseTestLabEnvironment().detect(),
      FirebaseTestLabEnvironmentStatus.notRunning,
    );
  });

  test("fails closed when Android environment detection fails", () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: "unavailable"),
    );

    expect(
      await const FirebaseTestLabEnvironment().detect(),
      FirebaseTestLabEnvironmentStatus.unknown,
    );
  });

  test("does not invoke the Android channel on other platforms", () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    messenger.setMockMethodCallHandler(channel, (_) async => fail("channel should not be invoked"));

    expect(
      await const FirebaseTestLabEnvironment().detect(),
      FirebaseTestLabEnvironmentStatus.notRunning,
    );
  });
}
