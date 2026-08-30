import "dart:io";

import "package:path/path.dart" as path;
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  late Directory root;
  late BridgeIdStorage storage;

  setUp(() {
    root = Directory.systemTemp.createTempSync("sesori_bridge_id_");
    storage = BridgeIdStorage(
      applicationSupportDirectory: _FixedApplicationSupportDirectory(directory: root),
    );
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  test("missing bridge id reads as null", () async {
    expect(await storage.read(), isNull);
  });

  test("persists the bridge id under desktop-owned application data", () async {
    await storage.write(bridgeId: "br_abc123");

    expect(await storage.read(), "br_abc123");
    expect(
      File(path.join(root.path, "desktop-instance", "bridge-id")).readAsStringSync(),
      "br_abc123",
    );
  });

  test("blank persisted content reads as null", () async {
    final File file = File(path.join(root.path, "desktop-instance", "bridge-id"));
    file.createSync(recursive: true);
    file.writeAsStringSync("  \n");

    expect(await storage.read(), isNull);
  });

  test("clear is idempotent", () async {
    await storage.clear();
    await storage.write(bridgeId: "br_to_clear");
    await storage.clear();
    await storage.clear();

    expect(await storage.read(), isNull);
  });
}

class _FixedApplicationSupportDirectory({required final Directory directory})
    implements DesktopApplicationSupportDirectory {
  @override
  Future<Directory> resolve() async => directory;
}
