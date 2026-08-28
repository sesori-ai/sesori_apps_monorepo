import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_desktop/core/platform/flutter_system_tray.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:tray_manager/tray_manager.dart";

void main() {
  setUpAll(() {
    registerFallbackValue(Menu());
  });

  late _MockTrayManager manager;

  setUp(() {
    manager = _MockTrayManager();
    when(() => manager.setIcon(any())).thenAnswer((_) async {});
    when(() => manager.setContextMenu(any())).thenAnswer((_) async {});
    when(manager.destroy).thenAnswer((_) async {});
  });

  test("Linux requires positive StatusNotifier watcher evidence", () async {
    final FlutterSystemTray tray = FlutterSystemTray.forTesting(
      manager: manager,
      isLinux: true,
      isWindows: false,
      linuxHostProbe: () async => false,
    );
    addTearDown(tray.dispose);

    final SystemTrayAvailability availability = await tray.initialize(menu: _menu);

    expect(availability, SystemTrayAvailability.unavailable);
    verifyNever(() => manager.addListener(tray));
    verifyNever(() => manager.setIcon(any()));
  });

  test("renders typed menu entries and emits typed commands", () async {
    final FlutterSystemTray tray = FlutterSystemTray.forTesting(
      manager: manager,
      isLinux: true,
      isWindows: false,
      linuxHostProbe: () async => true,
    );
    addTearDown(tray.dispose);

    final SystemTrayAvailability availability = await tray.initialize(menu: _menu);
    final Menu renderedMenu = verify(() => manager.setContextMenu(captureAny())).captured.single as Menu;
    final Future<SystemTrayCommand> command = tray.commands.first;
    tray.onTrayMenuItemClick(MenuItem(key: SystemTrayCommand.toggleBridge.key));

    expect(availability, SystemTrayAvailability.available);
    verify(() => manager.addListener(tray)).called(1);
    verify(() => manager.setIcon("assets/tray_icon.png")).called(1);
    expect(renderedMenu.items, hasLength(3));
    expect(renderedMenu.items![0].label, "Bridge: Off");
    expect(renderedMenu.items![0].disabled, isTrue);
    expect(renderedMenu.items![1].key, SystemTrayCommand.toggleBridge.key);
    expect(renderedMenu.items![1].disabled, isFalse);
    expect(renderedMenu.items![2].type, "separator");
    expect(await command, SystemTrayCommand.toggleBridge);
  });

  test("uses the bundled ICO asset on Windows and disposes the native tray", () async {
    final FlutterSystemTray tray = FlutterSystemTray.forTesting(
      manager: manager,
      isLinux: false,
      isWindows: true,
      linuxHostProbe: () async => throw StateError("must not probe"),
    );

    await tray.initialize(menu: _menu);
    await tray.dispose();

    verify(() => manager.setIcon("assets/tray_icon.ico")).called(1);
    verify(() => manager.removeListener(tray)).called(1);
    verify(manager.destroy).called(1);
  });
}

final SystemTrayMenu _menu = SystemTrayMenu(
  entries: const <SystemTrayMenuEntry>[
    SystemTrayTextItem(label: "Bridge: Off"),
    SystemTrayCommandItem(
      command: SystemTrayCommand.toggleBridge,
      label: "Turn Bridge On",
      enabled: true,
    ),
    SystemTraySeparator(),
  ],
);

class _MockTrayManager() extends Mock implements TrayManager;
