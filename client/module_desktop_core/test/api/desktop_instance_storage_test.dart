import "dart:io";

import "package:path/path.dart" as path;
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  late Directory root;
  late DesktopInstanceStorage storage;

  setUp(() {
    root = Directory.systemTemp.createTempSync("sesori_desktop_state_");
    storage = DesktopInstanceStorage(
      applicationSupportDirectory: _FixedApplicationSupportDirectory(directory: root),
    );
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  test("missing state defaults to desired Off", () async {
    expect(await storage.readBridgeDesiredState(), BridgeProcessDesiredState.off);
  });

  test("persists desired On under desktop-owned application data", () async {
    await storage.writeBridgeDesiredState(state: BridgeProcessDesiredState.on);

    expect(await storage.readBridgeDesiredState(), BridgeProcessDesiredState.on);
    expect(
      File(path.join(root.path, "desktop-instance", "bridge-desired-state")).readAsStringSync(),
      "on",
    );
  });

  test("invalid persisted state safely defaults to Off", () async {
    final File file = File(path.join(root.path, "desktop-instance", "bridge-desired-state"));
    file.createSync(recursive: true);
    file.writeAsStringSync("not-a-state");

    expect(await storage.readBridgeDesiredState(), BridgeProcessDesiredState.off);
  });
}

class _FixedApplicationSupportDirectory({required final Directory directory})
    implements DesktopApplicationSupportDirectory {
  @override
  Future<Directory> resolve() async => directory;
}
