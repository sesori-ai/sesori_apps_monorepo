import "dart:async";
import "dart:io";

import "package:dbus/dbus.dart";
import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:tray_manager/tray_manager.dart";

@visibleForTesting
typedef LinuxStatusNotifierHostProbe = Future<bool> Function();

/// The native constructors behind [FlutterSystemTray]. Tests replace them
/// because they need the platform library.
@visibleForTesting
class const NativeTrayFactory() {
  TrayIcon? createTrayIcon() => TrayIcon.create();

  Image? loadAsset({required String path}) => ImageAsset.fromAsset(path);

  Menu? createMenu() => Menu.create();

  MenuItem? createMenuItem({required String label}) => MenuItem.createWithLabelAndType(label, MenuItemType.normal);
}

/// Flutter/tray_manager adapter. It renders the supplied menu verbatim and
/// reports clicked entries as typed commands; lifecycle policy stays in
/// `BridgeControlCubit`.
@LazySingleton(as: SystemTray)
class FlutterSystemTray.forTesting({
  required final NativeTrayFactory _native,
  required final bool _isLinux,
  required final bool _isWindows,
  required final bool _isMacOS,
  required final LinuxStatusNotifierHostProbe _linuxHostProbe,
}) implements SystemTray {
  new()
    : this.forTesting(
        native: const NativeTrayFactory(),
        isLinux: Platform.isLinux,
        isWindows: Platform.isWindows,
        isMacOS: Platform.isMacOS,
        linuxHostProbe: _hasLinuxStatusNotifierHost,
      );

  @visibleForTesting
  this;

  static const String _linuxStatusNotifierWatcher = "org.kde.StatusNotifierWatcher";
  static const String _pngIconPath = "assets/tray_icon.png";
  static const String _windowsIconPath = "assets/tray_icon.ico";

  final StreamController<SystemTrayCommand> _commands = StreamController<SystemTrayCommand>.broadcast(sync: true);
  _NativeTray? _tray;
  bool _disposed = false;

  @override
  Stream<SystemTrayCommand> get commands => _commands.stream;

  @override
  Future<SystemTrayAvailability> initialize({required SystemTrayMenu menu}) async {
    _ensureNotDisposed();
    if (_tray != null) {
      await setMenu(menu: menu);
      return SystemTrayAvailability.available;
    }
    if (_isLinux && !await _linuxHostProbe()) {
      return SystemTrayAvailability.unavailable;
    }

    final String iconPath = _isWindows ? _windowsIconPath : _pngIconPath;
    final Image? image = _native.loadAsset(path: iconPath);
    final Menu? nativeMenu = _native.createMenu();
    final TrayIcon? icon = _native.createTrayIcon();
    if (image == null || nativeMenu == null || icon == null) {
      image?.dispose();
      nativeMenu?.dispose();
      icon?.dispose();
      throw StateError("Unable to create the system tray from $iconPath");
    }
    final _NativeTray tray = _NativeTray(
      icon: icon,
      image: image,
      menu: nativeMenu,
      listenerId: icon.addListener(_onTrayIconEvent),
    );
    try {
      // macOS template images are recolored by the system for light/dark menu
      // bars. The asset is therefore a transparent monochrome mark, not a
      // precomposited square icon.
      icon
        ..isIconTemplate = _isMacOS
        ..icon = image;
      _render(tray: tray, menu: menu);
      if (!icon.setVisible(true)) {
        throw StateError("Unable to show the system tray icon");
      }
    } on Object {
      tray.dispose();
      rethrow;
    }
    _tray = tray;
    return SystemTrayAvailability.available;
  }

  @override
  Future<void> setMenu({required SystemTrayMenu menu}) async {
    _ensureNotDisposed();
    final _NativeTray? tray = _tray;
    if (tray == null) {
      throw StateError("System tray is not initialized");
    }
    _render(tray: tray, menu: menu);
  }

  /// Rebuilds the items of the one native menu. Replacing the menu itself
  /// could leave macOS showing the previous one, because nativeapi detaches an
  /// opened menu from the status item only when that same menu closes.
  void _render({required _NativeTray tray, required SystemTrayMenu menu}) {
    final List<MenuItem> previous = tray.items;
    tray.items = <MenuItem>[];
    tray.menu.clear();
    // A command can rebuild the menu from inside the clicked item's native
    // callback, so that item has to outlive the call.
    Timer.run(() {
      for (final MenuItem item in previous) {
        item.dispose();
      }
    });
    for (final SystemTrayMenuEntry entry in menu.entries) {
      switch (entry) {
        case SystemTrayTextItem(:final label):
          _addItem(tray: tray, label: label, enabled: false);
        case SystemTrayCommandItem(:final command, :final label, :final enabled):
          _addItem(tray: tray, label: label, enabled: enabled).addListener((event) {
            if (event is MenuItemClickedEvent && !_commands.isClosed) {
              _commands.add(command);
            }
          });
        case SystemTraySeparator():
          tray.menu.addSeparator();
      }
    }
    // Setting the same menu again is what publishes the new layout on Linux.
    tray.icon.setContextMenu(tray.menu);
  }

  MenuItem _addItem({required _NativeTray tray, required String label, required bool enabled}) {
    final MenuItem? item = _native.createMenuItem(label: label);
    if (item == null) {
      throw StateError("Unable to create a system tray menu item");
    }
    tray.items.add(item);
    item.isEnabled = enabled;
    tray.menu.addItem(item);
    return item;
  }

  void _onTrayIconEvent(TrayIconEvent event) {
    switch (event) {
      // Linux reports no icon clicks: the panel opens the menu itself.
      case TrayIconClickedEvent() || TrayIconRightClickedEvent():
        if (_tray?.icon.openContextMenu() == false) {
          logw("Failed to open the system tray menu");
        }
      case TrayIconDoubleClickedEvent():
        break;
    }
  }

  @override
  @disposeMethod
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    try {
      _tray?.dispose();
      _tray = null;
    } finally {
      await _commands.close();
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError("System tray is disposed");
    }
  }

  static Future<bool> _hasLinuxStatusNotifierHost() async {
    final DBusClient client = DBusClient.session();
    try {
      return await client.nameHasOwner(_linuxStatusNotifierWatcher);
    } finally {
      await client.close();
    }
  }
}

/// The native handles of one shown tray icon. Handles are released
/// explicitly; a collected `TrayIcon` would silently remove the icon.
class _NativeTray({
  required final TrayIcon icon,
  required final Image _image,
  required final Menu menu,
  required final ListenerId _listenerId,
}) {
  List<MenuItem> items = <MenuItem>[];

  void dispose() {
    icon
      ..removeListener(_listenerId)
      ..dispose();
    for (final MenuItem item in items) {
      item.dispose();
    }
    menu.dispose();
    _image.dispose();
  }
}
