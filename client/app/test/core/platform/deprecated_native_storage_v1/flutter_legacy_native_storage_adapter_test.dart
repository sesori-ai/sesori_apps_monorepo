import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/core/di/register_module.dart";

const _channel = MethodChannel("plugins.it_nomads.com/flutter_secure_storage");

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(_channel, null);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test("$platform snapshots and deletes named legacy items with the old namespace and no reset", () async {
      debugDefaultTargetPlatformOverride = platform;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(_channel, (call) async {
        calls.add(call);
        return call.method == "readAll" ? {"access_token": "fixture-token", "unknown": ""} : null;
      });
      final storage = _RegisterModule().legacyNativeStorage();
      expect(calls, isEmpty);
      expect(await storage.readAll(), {"access_token": "fixture-token", "unknown": ""});
      await storage.delete(key: "access_token");
      final options = platform == TargetPlatform.android
          ? const AndroidOptions(resetOnError: false).toMap()
          : const IOSOptions(accessibility: null).toMap();
      expect(calls.map((call) => call.method), ["readAll", "delete"]);
      expect(calls[0].arguments, {"options": options});
      expect(calls[1].arguments, {"key": "access_token", "options": options});
      if (platform == TargetPlatform.iOS) {
        expect(options.containsKey("accessibility"), false);
        expect(options["accountName"], IOSOptions.defaultOptions.accountName);
        expect(options["synchronizable"], "false");
      }
    });

    test("$platform native errors are not an empty snapshot or successful cleanup", () async {
      debugDefaultTargetPlatformOverride = platform;
      var attempts = 0;
      messenger.setMockMethodCallHandler(_channel, (call) async {
        attempts++;
        throw PlatformException(code: "fixture-denied", message: "fixture native failure");
      });
      final storage = _RegisterModule().legacyNativeStorage();
      final failure = throwsA(isA<PlatformException>().having((error) => error.code, "code", "fixture-denied"));
      await expectLater(storage.readAll(), failure);
      await expectLater(storage.delete(key: "access_token"), failure);
      expect(attempts, 2);
    });
  }
}

class _RegisterModule() extends RegisterModule;
