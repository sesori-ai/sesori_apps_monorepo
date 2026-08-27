import "package:sesori_bridge/src/api/project_glossary_secret_storage.dart";
import "package:sesori_bridge/src/repositories/project_glossary_key_material_repository.dart";
import "package:test/test.dart";

void main() {
  test("creates, coalesces, caches, and reloads 256-bit local key material", () async {
    final storage = _MemorySecretStorage();
    final repository = ProjectGlossaryKeyMaterialRepository(storage: storage);

    final results = await Future.wait([repository.getOrCreate(), repository.getOrCreate()]);
    final cached = await repository.getOrCreate();
    final reloaded = await ProjectGlossaryKeyMaterialRepository(storage: storage).getOrCreate();

    expect(results.first, hasLength(ProjectGlossaryKeyMaterialRepository.secretLength));
    expect(results.last, results.first);
    expect(cached, results.first);
    expect(reloaded, results.first);
    expect(storage.writeCount, 1);
  });

  test("replaces malformed key material without exposing it", () async {
    final storage = _MemorySecretStorage(encodedSecret: "not-valid-key-material");

    final replacement = await ProjectGlossaryKeyMaterialRepository(storage: storage).getOrCreate();

    expect(replacement, hasLength(ProjectGlossaryKeyMaterialRepository.secretLength));
    expect(storage.encodedSecret, isNot("not-valid-key-material"));
    expect(storage.writeCount, 1);
  });
}

class _MemorySecretStorage({var String? encodedSecret}) implements FileProjectGlossarySecretStorage {
  int writeCount = 0;

  @override
  Future<String?> read() async => encodedSecret;

  @override
  Future<void> write({required String encodedSecret}) async {
    writeCount++;
    this.encodedSecret = encodedSecret;
  }
}
