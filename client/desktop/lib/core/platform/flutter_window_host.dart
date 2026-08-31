import "dart:async";
import "dart:ui";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:window_manager/window_manager.dart";

/// Dumb `window_manager` adapter for the Sesori desktop window.
@LazySingleton(as: WindowHost)
class FlutterWindowHost.forTesting({required final WindowManager _manager}) with WindowListener implements WindowHost {
  new() : this.forTesting(manager: windowManager);

  @visibleForTesting
  this;

  static const WindowOptions _options = WindowOptions(
    size: Size(720, 620),
    minimumSize: Size(560, 480),
    center: true,
    backgroundColor: Color(0x00000000),
    title: "Sesori",
  );

  final StreamController<WindowHostEvent> _events = StreamController<WindowHostEvent>.broadcast(sync: true);
  bool _listenerRegistered = false;
  bool _initialized = false;
  bool _disposed = false;

  @override
  Stream<WindowHostEvent> get events => _events.stream;

  @override
  Future<void> initialize({required bool hidden}) async {
    _ensureNotDisposed();
    if (_initialized) {
      throw StateError("WindowHost is already initialized");
    }

    await _manager.ensureInitialized();
    _manager.addListener(this);
    _listenerRegistered = true;
    try {
      await _manager.setPreventClose(true);
      await _manager.waitUntilReadyToShow(_options);
      await _manager.setSkipTaskbar(hidden);
      if (!hidden) {
        await _manager.show();
        await _manager.focus();
      }
      _initialized = true;
    } on Object {
      _manager.removeListener(this);
      _listenerRegistered = false;
      try {
        await _manager.setPreventClose(false);
      } on Object catch (error, stackTrace) {
        logw("Failed to restore native close behavior after window initialization failed", error, stackTrace);
      }
      try {
        await _manager.setSkipTaskbar(false);
      } on Object catch (error, stackTrace) {
        logw("Failed to restore Dock/taskbar visibility after window initialization failed", error, stackTrace);
      }
      rethrow;
    }
  }

  @override
  void onWindowClose() {
    if (!_events.isClosed) {
      _events.add(WindowHostEvent.closeRequested);
    }
  }

  @override
  Future<void> show() async {
    _ensureInitialized();
    // On macOS this restores NSApplication's regular activation policy, which
    // puts the app back in the Dock before the window is shown.
    await _manager.setSkipTaskbar(false);
    await _manager.show();
    await _manager.focus();
  }

  @override
  Future<void> hide() async {
    _ensureInitialized();
    await _manager.hide();
    // On macOS this switches to the accessory activation policy: the tray
    // remains available while the hidden window disappears from the Dock.
    await _manager.setSkipTaskbar(true);
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
      if (_initialized) {
        await _manager.setPreventClose(false);
      }
    } on Object catch (error, stackTrace) {
      logw("Failed to restore native close behavior while disposing the window host", error, stackTrace);
    } finally {
      await _events.close();
    }
  }

  void _ensureInitialized() {
    _ensureNotDisposed();
    if (!_initialized) {
      throw StateError("WindowHost is not initialized");
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError("WindowHost is disposed");
    }
  }
}
