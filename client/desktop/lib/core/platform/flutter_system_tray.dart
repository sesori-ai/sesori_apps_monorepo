import "dart:async";
import "dart:io";

import "package:dbus/dbus.dart";
import "package:flutter/foundation.dart" show protected, visibleForTesting;
import "package:flutter/services.dart" show EventChannel;
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:tray_manager/tray_manager.dart";

@visibleForTesting
typedef LinuxStatusNotifierHostProbe = Future<bool> Function();

/// Colour of the mark itself. macOS shows the one that contrasts with the menu
/// bar; Linux and Windows keep the white mark.
enum _MarkShade() {
  black,
  white,
}

/// Flutter/tray_manager adapter. It renders the supplied menu verbatim, shows
/// the icon variant for its status and reports clicked entries as typed
/// commands; lifecycle policy stays in `BridgeControlCubit`.
@LazySingleton(as: SystemTray)
class FlutterSystemTray.forTesting({
  required final bool _isLinux,
  required final bool _isWindows,
  required final bool _isMacOS,
  required final LinuxStatusNotifierHostProbe _linuxHostProbe,
}) implements SystemTray {
  new()
    : this.forTesting(
        isLinux: Platform.isLinux,
        isWindows: Platform.isWindows,
        isMacOS: Platform.isMacOS,
        linuxHostProbe: _hasLinuxStatusNotifierHost,
      );

  @visibleForTesting
  this;

  static const String _linuxStatusNotifierWatcher = "org.kde.StatusNotifierWatcher";
  static const EventChannel _menuBarAppearanceChannel = EventChannel("sesori/menu_bar_appearance");

  final StreamController<SystemTrayCommand> _commands = StreamController<SystemTrayCommand>.broadcast(sync: true);
  _NativeTray? _tray;
  StreamSubscription<bool>? _menuBarAppearance;
  SystemTrayStatus _status = SystemTrayStatus.off;
  // Corrected by the first appearance report, a moment after the icon shows.
  _MarkShade _shade = _MarkShade.black;
  bool _disposed = false;

  // The native constructors need the platform library, so tests override
  // them.
  @protected
  @visibleForTesting
  TrayIcon? createTrayIcon() => TrayIcon.create();

  @protected
  @visibleForTesting
  Image? loadAsset({required String path}) => ImageAsset.fromAsset(path);

  @protected
  @visibleForTesting
  Menu? createMenu() => Menu.create();

  @protected
  @visibleForTesting
  MenuItem? createMenuItem({required String label}) => MenuItem.createWithLabelAndType(label, MenuItemType.normal);

  /// Whether the macOS menu bar behind [icon] is dark, reported on every
  /// change by the runner's `MenuBarAppearance.swift`.
  @protected
  @visibleForTesting
  Stream<bool> watchMenuBarDarkness({required TrayIcon icon}) =>
      _menuBarAppearanceChannel.receiveBroadcastStream(icon.nativeObject.address).cast<bool>();

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

    _status = menu.status;
    final String iconPath = _iconPath();
    final Image? image = loadAsset(path: iconPath);
    final Menu? nativeMenu = createMenu();
    final TrayIcon? icon = createTrayIcon();
    if (image == null || nativeMenu == null || icon == null) {
      image?.dispose();
      nativeMenu?.dispose();
      icon?.dispose();
      throw StateError("Unable to create the system tray from $iconPath");
    }
    final _NativeTray tray = _NativeTray(
      icon: icon,
      image: image,
      iconPath: iconPath,
      menu: nativeMenu,
      listenerId: icon.addListener(_onTrayIconEvent),
    );
    try {
      // The status dot has colour, so the macOS image cannot be a template the
      // system recolours; the mark's shade follows the menu bar instead.
      icon.icon = image;
      if (_isLinux) {
        // Linux's host renders the exported menu; openContextMenu is unsupported there.
        icon.setContextMenuTrigger(ContextMenuTrigger.clicked);
      }
      _render(tray: tray, menu: menu);
      if (!icon.setVisible(true)) {
        throw StateError("Unable to show the system tray icon");
      }
    } on Object {
      tray.dispose();
      rethrow;
    }
    _tray = tray;
    if (_isMacOS) {
      _menuBarAppearance = watchMenuBarDarkness(icon: icon).listen(
        _onMenuBarAppearance,
        onError: (Object error, StackTrace stackTrace) {
          logw("Failed to follow the menu bar appearance", error, stackTrace);
        },
      );
    }
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
    _status = menu.status;
    _showIcon(tray: tray);
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

  void _onMenuBarAppearance(bool isDark) {
    _shade = isDark ? _MarkShade.white : _MarkShade.black;
    final _NativeTray? tray = _tray;
    if (tray == null) {
      return;
    }
    try {
      _showIcon(tray: tray);
    } on Object catch (error, stackTrace) {
      logw("Failed to recolour the system tray icon", error, stackTrace);
    }
  }

  /// Swaps in the variant for the current status and shade, if it changed.
  void _showIcon({required _NativeTray tray}) {
    final String path = _iconPath();
    if (path == tray.iconPath) {
      return;
    }
    final Image? image = loadAsset(path: path);
    if (image == null) {
      throw StateError("Unable to load the system tray icon $path");
    }
    tray.icon.icon = image;
    tray.image.dispose();
    tray
      ..image = image
      ..iconPath = path;
  }

  String _iconPath() {
    final String status = _status.name;
    if (_isWindows) {
      return "assets/tray/tray_icon_$status.ico";
    }
    final _MarkShade shade = _isMacOS ? _shade : _MarkShade.white;
    return "assets/tray/tray_icon_${status}_${shade.name}.png";
  }

  MenuItem _addItem({required _NativeTray tray, required String label, required bool enabled}) {
    final MenuItem? item = createMenuItem(label: label);
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
      await _menuBarAppearance?.cancel();
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
  required Image image,
  required String iconPath,
  required final Menu menu,
  required final ListenerId _listenerId,
}) {
  Image image = image;
  String iconPath = iconPath;
  List<MenuItem> items = <MenuItem>[];

  void dispose() {
    icon
      ..removeListener(_listenerId)
      ..dispose();
    for (final MenuItem item in items) {
      item.dispose();
    }
    menu.dispose();
    image.dispose();
  }
}
