import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_desktop/core/platform/flutter_system_tray.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:tray_manager/tray_manager.dart";

void main() {
  setUpAll(() {
    registerFallbackValue(_MockMenu());
    registerFallbackValue(_MockMenuItem());
    registerFallbackValue(_MockImage());
  });

  late _MockNativeTrayFactory native;
  late _MockTrayIcon icon;
  late _MockImage image;
  late _MockMenu menu;
  late Map<String, _MockMenuItem> items;
  late Map<String, void Function(MenuEvent)> itemListeners;
  late void Function(TrayIconEvent) iconListener;

  setUp(() {
    native = _MockNativeTrayFactory();
    icon = _MockTrayIcon();
    image = _MockImage();
    menu = _MockMenu();
    items = <String, _MockMenuItem>{};
    itemListeners = <String, void Function(MenuEvent)>{};

    when(() => native.loadAsset(path: any(named: "path"))).thenReturn(image);
    when(native.createTrayIcon).thenReturn(icon);
    when(native.createMenu).thenReturn(menu);
    when(() => native.createMenuItem(label: any(named: "label"))).thenAnswer((invocation) {
      final String label = invocation.namedArguments[#label] as String;
      final _MockMenuItem item = _MockMenuItem();
      when(() => item.addListener(any())).thenAnswer((listenerInvocation) {
        itemListeners[label] = listenerInvocation.positionalArguments.single as void Function(MenuEvent);
        return 1;
      });
      items[label] = item;
      return item;
    });
    when(() => icon.addListener(any())).thenAnswer((invocation) {
      iconListener = invocation.positionalArguments.single as void Function(TrayIconEvent);
      return 7;
    });
    when(() => icon.setVisible(any())).thenReturn(true);
    when(icon.openContextMenu).thenReturn(true);
    when(() => icon.removeListener(any())).thenReturn(true);
  });

  FlutterSystemTray createTray({required bool isLinux, required bool isWindows, required bool isMacOS}) {
    return FlutterSystemTray.forTesting(
      native: native,
      isLinux: isLinux,
      isWindows: isWindows,
      isMacOS: isMacOS,
      linuxHostProbe: () async => isLinux ? true : throw StateError("must not probe"),
    );
  }

  test("Linux requires positive StatusNotifier watcher evidence", () async {
    final FlutterSystemTray tray = FlutterSystemTray.forTesting(
      native: native,
      isLinux: true,
      isWindows: false,
      isMacOS: false,
      linuxHostProbe: () async => false,
    );
    addTearDown(tray.dispose);

    final SystemTrayAvailability availability = await tray.initialize(menu: _menu);

    expect(availability, SystemTrayAvailability.unavailable);
    verifyNever(native.createTrayIcon);
  });

  test("renders typed menu entries and emits typed commands", () async {
    final FlutterSystemTray tray = createTray(isLinux: true, isWindows: false, isMacOS: false);
    addTearDown(tray.dispose);

    final SystemTrayAvailability availability = await tray.initialize(menu: _menu);
    final Future<SystemTrayCommand> command = tray.commands.first;
    expect(itemListeners.keys, <String>["Turn Bridge On"]);
    itemListeners.values.single(const MenuItemClickedEvent(itemId: 1));

    expect(availability, SystemTrayAvailability.available);
    expect(items.keys, <String>["Bridge: Off", "Turn Bridge On"]);
    verify(() => native.loadAsset(path: "assets/tray_icon.png")).called(1);
    verify(() => icon.isIconTemplate = false).called(1);
    verify(() => icon.icon = image).called(1);
    verify(() => icon.setContextMenu(menu)).called(1);
    verify(() => icon.setVisible(true)).called(1);
    verify(() => items.values.first.isEnabled = false).called(1);
    verify(() => items.values.last.isEnabled = true).called(1);
    verify(menu.addSeparator).called(1);
    expect(await command, SystemTrayCommand.toggleBridge);
  });

  test("rebuilds the same menu and releases previous items after the click returns", () async {
    final FlutterSystemTray tray = createTray(isLinux: false, isWindows: false, isMacOS: true);
    addTearDown(tray.dispose);

    await tray.initialize(menu: _menu);
    final List<_MockMenuItem> firstItems = items.values.toList();
    await tray.setMenu(menu: _menu);

    verify(menu.clear).called(2);
    verify(() => icon.setContextMenu(menu)).called(2);
    for (final _MockMenuItem item in firstItems) {
      verifyNever(item.dispose);
    }
    await Future<void>.delayed(Duration.zero);
    for (final _MockMenuItem item in firstItems) {
      verify(item.dispose).called(1);
    }
    verifyNever(menu.dispose);
  });

  test("opens the same context menu for left and right icon clicks", () async {
    final FlutterSystemTray tray = createTray(isLinux: false, isWindows: false, isMacOS: true);
    addTearDown(tray.dispose);

    await tray.initialize(menu: _menu);
    iconListener(const TrayIconClickedEvent(trayIconId: 1));
    iconListener(const TrayIconRightClickedEvent(trayIconId: 1));
    iconListener(const TrayIconDoubleClickedEvent(trayIconId: 1));

    verify(icon.openContextMenu).called(2);
  });

  test("uses the bundled ICO asset on Windows and disposes the native tray", () async {
    final FlutterSystemTray tray = createTray(isLinux: false, isWindows: true, isMacOS: false);

    await tray.initialize(menu: _menu);
    await tray.dispose();

    verify(() => native.loadAsset(path: "assets/tray_icon.ico")).called(1);
    verify(() => icon.removeListener(7)).called(1);
    verify(icon.dispose).called(1);
    verify(menu.dispose).called(1);
    verify(image.dispose).called(1);
  });

  test("uses a macOS template icon for automatic light/dark recoloring", () async {
    final FlutterSystemTray tray = createTray(isLinux: false, isWindows: false, isMacOS: true);
    addTearDown(tray.dispose);

    await tray.initialize(menu: _menu);

    verify(() => icon.isIconTemplate = true).called(1);
  });

  test("releases native handles when the icon cannot be shown", () async {
    when(() => icon.setVisible(any())).thenReturn(false);
    final FlutterSystemTray tray = createTray(isLinux: false, isWindows: false, isMacOS: true);
    addTearDown(tray.dispose);

    await expectLater(tray.initialize(menu: _menu), throwsStateError);

    verify(icon.dispose).called(1);
    verify(menu.dispose).called(1);
    verify(image.dispose).called(1);
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

class _MockNativeTrayFactory() extends Mock implements NativeTrayFactory;

class _MockTrayIcon() extends Mock implements TrayIcon;

class _MockMenu() extends Mock implements Menu;

class _MockMenuItem() extends Mock implements MenuItem;

class _MockImage() extends Mock implements Image;
