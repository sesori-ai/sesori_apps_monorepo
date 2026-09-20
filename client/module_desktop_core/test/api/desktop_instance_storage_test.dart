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

  test("missing state is distinct from an explicit desired Off", () async {
    expect(await storage.readBridgeDesiredState(), isNull);
    await storage.writeBridgeDesiredState(state: BridgeProcessDesiredState.off);
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

  test("missing sidebar layout uses defaults", () async {
    expect(await storage.readSidebarLayout(), const DesktopSidebarLayout());
  });

  test("sidebar layout round-trips as a typed JSON file", () async {
    const layout = DesktopSidebarLayout(
      width: 315,
      collapsed: true,
      collapsedProjectIds: {"project-1", "project-2"},
      deferredSessions: {"older": 5, "newer": 9},
    );
    await storage.writeSidebarLayout(layout: layout);
    final restored = await storage.readSidebarLayout();
    expect(restored, layout);
    expect(restored.deferredSessions.keys, ["older", "newer"]);
    expect(DesktopSidebarLayout.fromJson(const {"width": 315}).deferredSessions, isEmpty);
    expect(File(path.join(root.path, "desktop-instance", "sidebar-layout")).existsSync(), isTrue);
  });

  test("malformed sidebar JSON surfaces to the cubit's fallback", () async {
    final file = File(path.join(root.path, "desktop-instance", "sidebar-layout"));
    file.createSync(recursive: true);
    file.writeAsStringSync("not-json");
    await expectLater(storage.readSidebarLayout(), throwsFormatException);
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
