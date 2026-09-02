import "dart:async";
import "dart:ui";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:screen_retriever/screen_retriever.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:window_manager/window_manager.dart";

/// Dumb `window_manager` adapter for the Sesori desktop window.
@LazySingleton(as: WindowHost)
class FlutterWindowHost.forTesting({
  required final WindowManager _manager,
  required final ScreenRetriever _screenRetriever,
}) with WindowListener implements WindowHost {
  new() : this.forTesting(manager: windowManager, screenRetriever: screenRetriever);

  @visibleForTesting
  this;

  static const Size _defaultSize = Size(720, 620);

  final StreamController<WindowHostEvent> _events = StreamController<WindowHostEvent>.broadcast(sync: true);
  final StreamController<WindowHostState> _states = StreamController<WindowHostState>.broadcast(sync: true);
  WindowHostState _currentState = WindowHostState.hidden;
  bool _listenerRegistered = false;
  bool _initialized = false;
  bool _disposed = false;

  @override
  Stream<WindowHostEvent> get events => _events.stream;

  @override
  WindowHostState get currentState => _currentState;

  @override
  Stream<WindowHostState> get states => _states.stream;

  @override
  Future<void> initialize({
    required bool hidden,
    required WindowBounds? initialBounds,
    required WindowSize minimumSize,
  }) async {
    _ensureNotDisposed();
    if (_initialized) {
      throw StateError("WindowHost is already initialized");
    }

    await _manager.ensureInitialized();
    _manager.addListener(this);
    _listenerRegistered = true;
    try {
      await _manager.setPreventClose(true);
      await _manager.waitUntilReadyToShow(
        WindowOptions(
          size: switch (initialBounds) {
            final bounds? => Size(bounds.width, bounds.height),
            null => _defaultSize,
          },
          minimumSize: Size(minimumSize.width, minimumSize.height),
          center: initialBounds == null,
          backgroundColor: const Color(0x00000000),
          title: "Sesori",
        ),
      );
      if (initialBounds != null) {
        await setBounds(bounds: initialBounds);
      }
      await _manager.setSkipTaskbar(hidden);
      if (hidden) {
        // Native runners hide the window before the first frame where
        // possible; keep the state explicit here as a cross-platform
        // fallback for hosts that initially order the window.
        await _manager.hide();
        _emitState(state: WindowHostState.hidden);
      } else {
        await _manager.show();
        _emitState(state: WindowHostState.unfocused);
        await _manager.focus();
        _emitState(state: WindowHostState.focused);
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
    _emitEvent(event: WindowHostEvent.closeRequested);
  }

  @override
  void onWindowMove() {
    _emitEvent(event: WindowHostEvent.moved);
  }

  @override
  void onWindowResize() {
    _emitEvent(event: WindowHostEvent.resized);
  }

  @override
  void onWindowFocus() {
    _emitState(state: WindowHostState.focused);
  }

  @override
  void onWindowBlur() {
    if (_currentState != WindowHostState.hidden) {
      _emitState(state: WindowHostState.unfocused);
    }
  }

  @override
  void onWindowMinimize() {
    _emitState(state: WindowHostState.hidden);
  }

  @override
  void onWindowRestore() {
    _emitState(state: WindowHostState.unfocused);
  }

  @override
  Future<WindowBounds> getBounds() async {
    _ensureInitialized();
    final bounds = await _manager.getBounds();
    return WindowBounds(
      left: bounds.left,
      top: bounds.top,
      width: bounds.width,
      height: bounds.height,
    );
  }

  @override
  Future<void> setBounds({required WindowBounds bounds}) async {
    _ensureNotDisposed();
    await _manager.setBounds(Rect.fromLTWH(bounds.left, bounds.top, bounds.width, bounds.height));
  }

  @override
  Future<List<WindowBounds>> getDisplayBounds() async {
    _ensureNotDisposed();
    final displays = await _screenRetriever.getAllDisplays();
    return List<WindowBounds>.unmodifiable(
      displays.map((display) {
        final position = display.visiblePosition ?? Offset.zero;
        final size = display.visibleSize ?? display.size;
        return WindowBounds(left: position.dx, top: position.dy, width: size.width, height: size.height);
      }),
    );
  }

  @override
  Future<void> show() async {
    _ensureInitialized();
    // On macOS this restores NSApplication's regular activation policy, which
    // puts the app back in the Dock before the window is shown.
    await _manager.setSkipTaskbar(false);
    await _manager.show();
    _emitState(state: WindowHostState.unfocused);
    await _manager.focus();
    _emitState(state: WindowHostState.focused);
  }

  @override
  Future<void> hide() async {
    _ensureInitialized();
    await _manager.hide();
    _emitState(state: WindowHostState.hidden);
    // On macOS this switches to the accessory activation policy: the tray
    // remains available while the hidden window disappears from the Dock.
    await _manager.setSkipTaskbar(true);
  }

  void _emitEvent({required WindowHostEvent event}) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  void _emitState({required WindowHostState state}) {
    if (_currentState == state) {
      return;
    }
    _currentState = state;
    if (!_states.isClosed) {
      _states.add(state);
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
      if (_initialized) {
        await _manager.setPreventClose(false);
      }
    } on Object catch (error, stackTrace) {
      logw("Failed to restore native close behavior while disposing the window host", error, stackTrace);
    } finally {
      await Future.wait<void>([_events.close(), _states.close()]);
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
