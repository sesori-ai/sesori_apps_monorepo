import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as path;
import "package:sesori_desktop/core/di/register_module.dart";
import "package:sesori_desktop/core/platform/desktop_persistence_directory.dart";
import "package:sesori_desktop/core/platform/flutter_desktop_application_support_directory.dart";
import "package:sesori_persistence/sesori_persistence.dart";

const _channel = MethodChannel("plugins.it_nomads.com/flutter_secure_storage");

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(_channel, null);
  });

  test("debug/profile scope is development without native access", () {
    expect(clientPersistenceScope, PersistenceScope.development);
  });

  for (final platform in [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux]) {
    for (final scope in PersistenceScope.values) {
      test("$platform $scope uses only its master item and platform credential protection", () async {
        debugDefaultTargetPlatformOverride = platform;
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          return call.method == "read" ? "fixture-master" : null;
        });
        final store = _RegisterModule().masterKeyStore(scope: scope);
        expect(calls, isEmpty);
        expect(await store.read(), "fixture-master");
        await store.write(value: "new-fixture-master");
        final options = switch (platform) {
          TargetPlatform.macOS => const MacOsOptions(
            accountName: PersistenceScope.masterKeyNamespace,
            usesDataProtectionKeychain: false,
          ).toMap(),
          TargetPlatform.windows => WindowsOptions.defaultOptions.toMap(),
          _ => LinuxOptions.defaultOptions.toMap(),
        };
        expect(calls.map((call) => call.method), ["read", "write"]);
        expect(calls[0].arguments, {"key": scope.masterKeyStorageKey, "options": options});
        expect(calls[1].arguments, {
          "key": scope.masterKeyStorageKey,
          "value": "new-fixture-master",
          "options": options,
        });
      });
    }

    test("$platform forwards missing keys and native denial without resetting or retrying", () async {
      debugDefaultTargetPlatformOverride = platform;
      final store = _RegisterModule().masterKeyStore(scope: PersistenceScope.production);
      var attempts = 0;
      messenger.setMockMethodCallHandler(_channel, (call) async {
        attempts++;
        if (call.method == "read") return null;
        throw PlatformException(code: "fixture-denied", message: "fixture failure");
      });
      expect(await store.read(), isNull);
      await expectLater(
        store.write(value: "fixture-master"),
        throwsA(isA<PlatformException>().having((error) => error.code, "code", "fixture-denied")),
      );
      expect(attempts, 2);
    });
  }

  test("persistence directory reuses the desktop resolver without changing existing files", () async {
    final root = await Directory.systemTemp.createTemp("sesori-desktop-persistence-");
    addTearDown(() => root.delete(recursive: true));
    var lookups = 0;
    final directories = FlutterDesktopApplicationSupportDirectory.forTesting(
      load: () async {
        lookups++;
        return root;
      },
    );
    final capability = DesktopPersistenceDirectory(directories: directories);
    expect(lookups, 0);
    final directory = await capability.resolve();
    expect(directory.path, path.join(root.path, "persistence"));
    final sentinel = File(path.join(directory.path, "fixture.sqlite-wal"));
    await sentinel.writeAsString("fixture");
    expect((await capability.resolve()).path, directory.path);
    expect(await sentinel.readAsString(), "fixture");
    expect(lookups, 1);
  });

  test("directory lookup and creation failures propagate without substituting a cache", () async {
    final cause = StateError("fixture directory unavailable");
    final failed = DesktopPersistenceDirectory(
      directories: FlutterDesktopApplicationSupportDirectory.forTesting(load: () => Future<Directory>.error(cause)),
    );
    await expectLater(failed.resolve(), throwsA(same(cause)));
    final root = await Directory.systemTemp.createTemp("sesori-desktop-persistence-");
    addTearDown(() => root.delete(recursive: true));
    await File(path.join(root.path, "persistence")).writeAsString("fixture obstruction");
    final blocked = DesktopPersistenceDirectory(
      directories: FlutterDesktopApplicationSupportDirectory.forTesting(load: () async => root),
    );
    await expectLater(blocked.resolve(), throwsA(isA<FileSystemException>()));
  });
}

class _RegisterModule() extends RegisterModule;
