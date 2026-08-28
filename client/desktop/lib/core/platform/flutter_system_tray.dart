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

/// Flutter/tray_manager adapter. It renders the supplied menu verbatim and
/// translates plugin keys back to typed commands; lifecycle policy stays in
/// `BridgeControlCubit`.
@LazySingleton(as: SystemTray)
class FlutterSystemTray.forTesting({
  required final TrayManager _manager,
  required final bool _isLinux,
  required final bool _isWindows,
  required final LinuxStatusNotifierHostProbe _linuxHostProbe,
}) with TrayListener implements SystemTray {
  new()
    : this.forTesting(
        manager: trayManager,
        isLinux: Platform.isLinux,
        isWindows: Platform.isWindows,
        linuxHostProbe: _hasLinuxStatusNotifierHost,
      );

  @visibleForTesting
  this;

  static const String _linuxStatusNotifierWatcher = "org.kde.StatusNotifierWatcher";
  static const String _pngIconPath = "assets/tray_icon.png";
  static const String _windowsIconPath = "assets/tray_icon.ico";

  final StreamController<SystemTrayCommand> _commands = StreamController<SystemTrayCommand>.broadcast(sync: true);
  bool _listenerRegistered = false;
  bool _trayCreated = false;
  bool _disposed = false;

  @override
  Stream<SystemTrayCommand> get commands => _commands.stream;

  @override
  Future<SystemTrayAvailability> initialize({required SystemTrayMenu menu}) async {
    _ensureNotDisposed();
    if (_trayCreated) {
      await setMenu(menu: menu);
      return SystemTrayAvailability.available;
    }
    if (_isLinux && !await _linuxHostProbe()) {
      return SystemTrayAvailability.unavailable;
    }

    _manager.addListener(this);
    _listenerRegistered = true;
    try {
      await _manager.setIcon(_isWindows ? _windowsIconPath : _pngIconPath);
      _trayCreated = true;
      await _manager.setContextMenu(_toPlatformMenu(menu: menu));
      return SystemTrayAvailability.available;
    } on Object {
      _manager.removeListener(this);
      _listenerRegistered = false;
      if (_trayCreated) {
        try {
          await _manager.destroy();
        } on Object catch (error, stackTrace) {
          logw("Failed to remove a partially initialized system tray", error, stackTrace);
        }
        _trayCreated = false;
      }
      rethrow;
    }
  }

  @override
  Future<void> setMenu({required SystemTrayMenu menu}) async {
    _ensureNotDisposed();
    if (!_trayCreated) {
      throw StateError("System tray is not initialized");
    }
    await _manager.setContextMenu(_toPlatformMenu(menu: menu));
  }

  Menu _toPlatformMenu({required SystemTrayMenu menu}) {
    return Menu(
      items: menu.entries.map((entry) => _toPlatformItem(entry: entry)).toList(growable: false),
    );
  }

  MenuItem _toPlatformItem({required SystemTrayMenuEntry entry}) {
    return switch (entry) {
      SystemTrayTextItem(:final label) => MenuItem(label: label, disabled: true),
      SystemTrayCommandItem(:final command, :final label, :final enabled) => MenuItem(
        key: command.key,
        label: label,
        disabled: !enabled,
      ),
      SystemTraySeparator() => MenuItem.separator(),
    };
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_showContextMenu());
  }

  Future<void> _showContextMenu() async {
    try {
      await _manager.popUpContextMenu();
    } on Object catch (error, stackTrace) {
      logw("Failed to open the system tray menu", error, stackTrace);
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final SystemTrayCommand? command = SystemTrayCommand.fromKey(key: menuItem.key);
    if (command == null) {
      logw("Ignoring an unknown system tray command");
      return;
    }
    if (!_commands.isClosed) {
      _commands.add(command);
    }
  }

  @override
  @disposeMethod
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    if (_listenerRegistered) {
      _manager.removeListener(this);
      _listenerRegistered = false;
    }
    try {
      if (_trayCreated) {
        await _manager.destroy();
        _trayCreated = false;
      }
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
