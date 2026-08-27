import "dart:io";

import "package:sesori_bridge/src/api/project_glossary_secret_storage.dart";
import "package:sesori_bridge/src/foundation/data_directory_hardening.dart";
import "package:test/test.dart";

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp("project_glossary_secret_storage_test");
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  FileProjectGlossarySecretStorage createStorage() => FileProjectGlossarySecretStorage(
    dataDirectory: directory.path,
    writeRestrictedFile: writeRestrictedFile,
  );

  test("lazily creates, coalesces, and reuses 256-bit local key material", () async {
    final storage = createStorage();
    expect(directory.listSync(), isEmpty);

    final results = await Future.wait([storage.getOrCreate(), storage.getOrCreate()]);
    final reloaded = await createStorage().getOrCreate();

    expect(results.first, hasLength(FileProjectGlossarySecretStorage.secretLength));
    expect(results.last, results.first);
    expect(reloaded, results.first);
    expect(directory.listSync().whereType<File>(), hasLength(1));
  });

  test("replaces malformed key material without exposing it", () async {
    final storage = createStorage();
    await storage.getOrCreate();
    final file = directory.listSync().whereType<File>().single;
    await file.writeAsString("not-valid-key-material");

    final replacement = await createStorage().getOrCreate();

    expect(replacement, hasLength(FileProjectGlossarySecretStorage.secretLength));
    expect(await file.readAsString(), isNot("not-valid-key-material"));
  });
}
