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

  test("missing window bounds have no restored value", () async {
    expect(await storage.readWindowBounds(), isNull);
  });

  test("persists typed window bounds under desktop-owned application data", () async {
    const bounds = WindowBounds(left: -120, top: 42, width: 1080, height: 760);

    await storage.writeWindowBounds(bounds: bounds);

    expect(await storage.readWindowBounds(), bounds);
    expect(
      File(path.join(root.path, "desktop-instance", "window-bounds")).readAsStringSync(),
      "-120.0\n42.0\n1080.0\n760.0",
    );
  });

  test("malformed window bounds are ignored", () async {
    final File file = File(path.join(root.path, "desktop-instance", "window-bounds"));
    file.createSync(recursive: true);
    file.writeAsStringSync("12\ninvalid\n720");

    expect(await storage.readWindowBounds(), isNull);
  });

  test("attention notifications default to enabled", () async {
    expect(await storage.readAttentionPreference(), DesktopAttentionPreference.enabled);
  });

  test("persists the desktop attention-notification preference", () async {
    await storage.writeAttentionPreference(preference: DesktopAttentionPreference.disabled);

    expect(await storage.readAttentionPreference(), DesktopAttentionPreference.disabled);
    expect(
      File(path.join(root.path, "desktop-instance", "attention-notifications")).readAsStringSync(),
      "disabled",
    );
  });

  test("invalid attention preferences safely default to enabled", () async {
    final File file = File(path.join(root.path, "desktop-instance", "attention-notifications"));
    file.createSync(recursive: true);
    file.writeAsStringSync("not-a-preference");

    expect(await storage.readAttentionPreference(), DesktopAttentionPreference.enabled);
  });
}

class _FixedApplicationSupportDirectory({required final Directory directory})
    implements DesktopApplicationSupportDirectory {
  @override
  Future<Directory> resolve() async => directory;
}
