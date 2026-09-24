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

  late _MockTrayIcon icon;
  late _MockImage image;
  late _MockMenu menu;
  late Map<String, _MockMenuItem> items;
  late Map<String, void Function(MenuEvent)> itemListeners;
  late void Function(TrayIconEvent) iconListener;

  setUp(() {
    icon = _MockTrayIcon();
    image = _MockImage();
    menu = _MockMenu();
    items = <String, _MockMenuItem>{};
    itemListeners = <String, void Function(MenuEvent)>{};

    when(() => icon.addListener(any())).thenAnswer((invocation) {
      iconListener = invocation.positionalArguments.single as void Function(TrayIconEvent);
      return 7;
    });
    when(() => icon.setVisible(any())).thenReturn(true);
    when(icon.openContextMenu).thenReturn(true);
    when(() => icon.removeListener(any())).thenReturn(true);
  });

  _MockMenuItem createItem(String label) {
    final _MockMenuItem item = _MockMenuItem();
    when(() => item.addListener(any())).thenAnswer((invocation) {
      itemListeners[label] = invocation.positionalArguments.single as void Function(MenuEvent);
      return 1;
    });
    items[label] = item;
    return item;
  }

  _TestSystemTray createTray({
    required bool isLinux,
    required bool isWindows,
    required bool isMacOS,
    required LinuxStatusNotifierHostProbe? linuxHostProbe,
  }) {
    return _TestSystemTray(
      icon: icon,
      image: image,
      menu: menu,
      createItem: createItem,
      isLinux: isLinux,
      isWindows: isWindows,
      isMacOS: isMacOS,
      linuxHostProbe: linuxHostProbe ?? () async => isLinux ? true : throw StateError("must not probe"),
    );
  }

  test("Linux requires positive StatusNotifier watcher evidence", () async {
    final _TestSystemTray tray = createTray(
      isLinux: true,
      isWindows: false,
      isMacOS: false,
      linuxHostProbe: () async => false,
    );
    addTearDown(tray.dispose);

    final SystemTrayAvailability availability = await tray.initialize(menu: _menu);

    expect(availability, SystemTrayAvailability.unavailable);
    expect(tray.loadedAssets, isEmpty);
  });

  test("renders typed menu entries and emits typed commands", () async {
    final _TestSystemTray tray = createTray(isLinux: true, isWindows: false, isMacOS: false, linuxHostProbe: null);
    addTearDown(tray.dispose);

    final SystemTrayAvailability availability = await tray.initialize(menu: _menu);
    final Future<SystemTrayCommand> command = tray.commands.first;
    expect(itemListeners.keys, <String>["Turn Bridge On"]);
    itemListeners.values.single(const MenuItemClickedEvent(itemId: 1));

    expect(availability, SystemTrayAvailability.available);
    expect(items.keys, <String>["Bridge: Off", "Turn Bridge On"]);
    expect(tray.loadedAssets, <String>["assets/tray_icon.png"]);
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
    final _TestSystemTray tray = createTray(isLinux: false, isWindows: false, isMacOS: true, linuxHostProbe: null);
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
    final _TestSystemTray tray = createTray(isLinux: false, isWindows: false, isMacOS: true, linuxHostProbe: null);
    addTearDown(tray.dispose);

    await tray.initialize(menu: _menu);
    iconListener(const TrayIconClickedEvent(trayIconId: 1));
    iconListener(const TrayIconRightClickedEvent(trayIconId: 1));
    iconListener(const TrayIconDoubleClickedEvent(trayIconId: 1));

    verify(icon.openContextMenu).called(2);
  });

  test("uses the bundled ICO asset on Windows and disposes the native tray", () async {
    final _TestSystemTray tray = createTray(isLinux: false, isWindows: true, isMacOS: false, linuxHostProbe: null);

    await tray.initialize(menu: _menu);
    await tray.dispose();

    expect(tray.loadedAssets, <String>["assets/tray_icon.ico"]);
    verify(() => icon.removeListener(7)).called(1);
    verify(icon.dispose).called(1);
    verify(menu.dispose).called(1);
    verify(image.dispose).called(1);
  });

  test("uses a macOS template icon for automatic light/dark recoloring", () async {
    final _TestSystemTray tray = createTray(isLinux: false, isWindows: false, isMacOS: true, linuxHostProbe: null);
    addTearDown(tray.dispose);

    await tray.initialize(menu: _menu);

    verify(() => icon.isIconTemplate = true).called(1);
  });

  test("releases native handles when the icon cannot be shown", () async {
    when(() => icon.setVisible(any())).thenReturn(false);
    final _TestSystemTray tray = createTray(isLinux: false, isWindows: false, isMacOS: true, linuxHostProbe: null);
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

class _TestSystemTray({
  required final TrayIcon icon,
  required final Image image,
  required final Menu menu,
  required final MenuItem Function(String label) createItem,
  required super.isLinux,
  required super.isWindows,
  required super.isMacOS,
  required super.linuxHostProbe,
}) extends FlutterSystemTray {
  this : super.forTesting();

  final List<String> loadedAssets = <String>[];

  @override
  TrayIcon? createTrayIcon() => icon;

  @override
  Image? loadAsset({required String path}) {
    loadedAssets.add(path);
    return image;
  }

  @override
  Menu? createMenu() => menu;

  @override
  MenuItem? createMenuItem({required String label}) => createItem(label);
}

class _MockTrayIcon() extends Mock implements TrayIcon;

class _MockMenu() extends Mock implements Menu;

class _MockMenuItem() extends Mock implements MenuItem;

class _MockImage() extends Mock implements Image;
