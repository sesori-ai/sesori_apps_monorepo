import "dart:io";

import "package:sesori_bridge/src/api/project_glossary_secret_storage.dart";
import "package:sesori_bridge/src/foundation/data_directory_hardening.dart";
import "package:test/test.dart";

void main() {
  late Directory directory;
  late FileProjectGlossarySecretStorage storage;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp("project_glossary_secret_storage_test");
    storage = FileProjectGlossarySecretStorage(
      dataDirectory: directory.path,
      writeRestrictedFile: writeRestrictedFile,
    );
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test("reads no material before the repository writes it", () async {
    expect(await storage.read(), isNull);
    expect(directory.listSync(), isEmpty);
  });

  test("persists and reads encoded material through the restricted writer", () async {
    await storage.write(encodedSecret: "encoded-secret");

    expect(await storage.read(), "encoded-secret");
    expect(directory.listSync().whereType<File>(), hasLength(1));
  });
}
