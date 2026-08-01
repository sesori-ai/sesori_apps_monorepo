import "dart:async";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/core/platform/temporary_directory_client.dart";

void main() {
  test("warms once and shares the result", () async {
    final directory = Directory("/tmp/sesori-temporary-directory-client-test");
    final loadCompleter = Completer<Directory>();
    var loadCalls = 0;

    final client = TemporaryDirectoryClient.forTesting(
      load: () {
        loadCalls++;
        return loadCompleter.future;
      },
    );

    final warmUp = client.warmUp();
    expect(loadCalls, 1);
    expect(identical(client.directory, client.directory), isTrue);

    loadCompleter.complete(directory);
    await warmUp;
    expect(await client.directory, same(directory));
    expect(loadCalls, 1);
  });

  test("retries after an eager lookup failure", () async {
    final firstLoad = Completer<Directory>();
    final recoveredDirectory = Directory("/tmp/sesori-temporary-directory-client-recovered");
    var loadCalls = 0;

    final client = TemporaryDirectoryClient.forTesting(
      load: () {
        loadCalls++;
        return loadCalls == 1 ? firstLoad.future : Future.value(recoveredDirectory);
      },
    );

    final warmUp = client.warmUp();
    firstLoad.completeError(StateError("temporary directory unavailable"));
    await warmUp;

    expect(await client.directory, same(recoveredDirectory));
    expect(loadCalls, 2);
  });
}
