import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as path;
import "package:sesori_mobile/core/di/register_module.dart";
import "package:sesori_mobile/core/platform/application_support_directory_client.dart";
import "package:sesori_mobile/core/platform/flutter_persistence_directory.dart";
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

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scope in PersistenceScope.values) {
      test("$platform $scope uses only its master item and preserves native protection", () async {
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
        final options = platform == TargetPlatform.android
            ? const AndroidOptions(resetOnError: false, storageNamespace: PersistenceScope.masterKeyNamespace).toMap()
            : const IOSOptions(accountName: PersistenceScope.masterKeyNamespace).toMap();
        expect(calls.map((call) => call.method), ["read", "write"]);
        expect(calls[0].arguments, {"key": scope.masterKeyStorageKey, "options": options});
        expect(calls[1].arguments, {
          "key": scope.masterKeyStorageKey,
          "value": "new-fixture-master",
          "options": options,
        });
        if (platform == TargetPlatform.iOS) {
          expect(options["accessibility"], "unlocked");
          expect(options["synchronizable"], "false");
        }
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

  test("persistent directory uses the existing resolver lazily and retains files across resolutions", () async {
    final root = await Directory.systemTemp.createTemp("sesori-mobile-persistence-");
    addTearDown(() => root.delete(recursive: true));
    var lookups = 0;
    final directories = ApplicationSupportDirectoryClient.forTesting(
      load: () async {
        lookups++;
        return root;
      },
    );
    final capability = FlutterPersistenceDirectory(directories: directories);
    expect(lookups, 0);
    final directory = await capability.resolve();
    expect(directory.path, path.join(root.path, "persistence"));
    expect(directory.existsSync(), true);
    final sentinel = File(path.join(directory.path, "fixture.sqlite-wal"));
    await sentinel.writeAsString("fixture");
    expect((await capability.resolve()).path, directory.path);
    expect(await sentinel.readAsString(), "fixture");
    expect(lookups, 1);
  });

  test("directory lookup and creation failures propagate without substituting a cache", () async {
    final cause = StateError("fixture directory unavailable");
    final failed = FlutterPersistenceDirectory(
      directories: ApplicationSupportDirectoryClient.forTesting(load: () => Future<Directory>.error(cause)),
    );
    await expectLater(failed.resolve(), throwsA(same(cause)));

    final root = await Directory.systemTemp.createTemp("sesori-mobile-persistence-");
    addTearDown(() => root.delete(recursive: true));
    await File(path.join(root.path, "persistence")).writeAsString("fixture obstruction");
    final blocked = FlutterPersistenceDirectory(
      directories: ApplicationSupportDirectoryClient.forTesting(load: () async => root),
    );
    await expectLater(blocked.resolve(), throwsA(isA<FileSystemException>()));
  });
}

class _RegisterModule() extends RegisterModule;
