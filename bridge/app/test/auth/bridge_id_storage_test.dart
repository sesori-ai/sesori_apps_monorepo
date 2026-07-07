import "dart:io";

import "package:sesori_bridge/src/auth/bridge_id_storage.dart";
import "package:test/test.dart";

void main() {
  late Directory tempDir;
  late BridgeIdStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("bridge_id_storage_test");
    storage = BridgeIdStorage(filePath: "${tempDir.path}/nested/bridge_id");
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test("read returns null when the file is missing", () async {
    expect(await storage.read(), isNull);
  });

  test("write then read round-trips the bridge id and creates the directory", () async {
    await storage.write(bridgeId: "br_test1234");

    expect(await storage.read(), equals("br_test1234"));
  });

  test("read returns null for an empty file", () async {
    await storage.write(bridgeId: "   ");

    expect(await storage.read(), isNull);
  });

  test("clear removes the persisted file", () async {
    await storage.write(bridgeId: "br_test1234");

    await storage.clear();

    expect(await storage.read(), isNull);
  });

  test("clear is a no-op when the file is absent", () async {
    await storage.clear();

    expect(await storage.read(), isNull);
  });
}
