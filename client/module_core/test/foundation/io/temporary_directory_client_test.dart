import "dart:async";
import "dart:io";

import "package:sesori_dart_core/src/foundation/io/temporary_directory_client.dart";
import "package:sesori_dart_core/src/foundation/platform/temporary_directory_provider.dart";
import "package:test/test.dart";

/// Replays scripted lookups so tests drive success, failure and retry.
class _FakeTemporaryDirectoryProvider({required final Future<Directory> Function() _load})
    implements TemporaryDirectoryProvider {
  int calls = 0;

  @override
  Future<Directory> temporaryDirectory() {
    calls++;
    return _load();
  }
}

void main() {
  test("warms once and shares the result", () async {
    final directory = Directory("/tmp/sesori-temporary-directory-client-test");
    final loadCompleter = Completer<Directory>();
    final provider = _FakeTemporaryDirectoryProvider(load: () => loadCompleter.future);
    final client = TemporaryDirectoryClient(provider: provider);

    final warmUp = client.warmUp();
    expect(provider.calls, 1);
    expect(identical(client.directory, client.directory), isTrue);

    loadCompleter.complete(directory);
    await warmUp;
    expect(await client.directory, same(directory));
    expect(provider.calls, 1);
  });

  test("retries after an eager lookup failure", () async {
    final firstLoad = Completer<Directory>();
    final recoveredDirectory = Directory("/tmp/sesori-temporary-directory-client-recovered");
    late final _FakeTemporaryDirectoryProvider provider;
    provider = _FakeTemporaryDirectoryProvider(
      load: () => provider.calls == 1 ? firstLoad.future : Future.value(recoveredDirectory),
    );
    final client = TemporaryDirectoryClient(provider: provider);

    final warmUp = client.warmUp();
    firstLoad.completeError(StateError("temporary directory unavailable"));
    await warmUp;

    expect(await client.directory, same(recoveredDirectory));
    expect(provider.calls, 2);
  });

  test("retries after a direct lookup failure", () async {
    final recoveredDirectory = Directory("/tmp/sesori-temporary-directory-client-direct-retry");
    late final _FakeTemporaryDirectoryProvider provider;
    provider = _FakeTemporaryDirectoryProvider(
      load: () => provider.calls == 1
          ? Future.error(StateError("temporary directory unavailable"))
          : Future.value(recoveredDirectory),
    );
    final client = TemporaryDirectoryClient(provider: provider);

    await expectLater(client.directory, throwsA(isA<StateError>()));

    expect(await client.directory, same(recoveredDirectory));
    expect(provider.calls, 2);
  });

  test("contains a synchronous warm-up failure", () async {
    final recoveredDirectory = Directory("/tmp/sesori-temporary-directory-client-sync-retry");
    late final _FakeTemporaryDirectoryProvider provider;
    provider = _FakeTemporaryDirectoryProvider(
      load: () {
        if (provider.calls == 1) throw StateError("temporary directory unavailable");
        return Future.value(recoveredDirectory);
      },
    );
    final client = TemporaryDirectoryClient(provider: provider);

    await client.warmUp();

    expect(await client.directory, same(recoveredDirectory));
    expect(provider.calls, 2);
  });
}
