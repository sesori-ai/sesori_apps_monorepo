import "dart:io";

import "package:sesori_bridge/src/auth/bridge_identity_secret_storage.dart";
import "package:sesori_bridge/src/foundation/data_directory_hardening.dart";
import "package:test/test.dart";

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp("bridge_identity_secret_storage_test");
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  FileBridgeIdentitySecretStorage createStorage() => FileBridgeIdentitySecretStorage(
    dataDirectory: directory.path,
    writeRestrictedFile: writeRestrictedFile,
  );

  test("creates and reuses 256-bit bridge-local key material", () async {
    final first = await createStorage().getOrCreate();
    final second = await createStorage().getOrCreate();

    expect(first, hasLength(FileBridgeIdentitySecretStorage.secretLength));
    expect(second, first);
    expect(directory.listSync().whereType<File>(), hasLength(1));
  });

  test("replaces malformed key material without exposing it", () async {
    final storage = createStorage();
    await storage.getOrCreate();
    final file = directory.listSync().whereType<File>().single;
    await file.writeAsString("not-valid-key-material");

    final replacement = await storage.getOrCreate();

    expect(replacement, hasLength(FileBridgeIdentitySecretStorage.secretLength));
    expect(await file.readAsString(), isNot("not-valid-key-material"));
  });
}
