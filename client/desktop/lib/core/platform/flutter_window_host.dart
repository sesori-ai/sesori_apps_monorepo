import "dart:async";

import "package:flutter/foundation.dart" show TargetPlatform, defaultTargetPlatform, visibleForTesting;
import "package:flutter/services.dart";
import "package:injectable/injectable.dart";
import "package:nativeapi/nativeapi.dart" as native show Application, Brightness;
import "package:screen_retriever/screen_retriever.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:window_manager/window_manager.dart";

import "macos_termination_channel.dart";
import "windows_runner_window.dart";

/// Dumb `window_manager` adapter for the Sesori desktop window. It also
/// relays the macOS runner's system quit requests.
@LazySingleton(as: WindowHost)
class FlutterWindowHost.forTesting({
  required final Window? Function() _findWindow,
  required final DisplayManager _displayManager,
  required final native.Application _application,
  required final MethodChannel _terminationChannel,
}) implements WindowHost {
  new()
    : this.forTesting(
        findWindow: _findAppWindow,
        displayManager: DisplayManager.instance,
        application: native.Application.instance,
        terminationChannel: macosTerminationChannel,
      );

  @visibleForTesting
  this;

  static const Size _defaultSize = Size(720, 620);

  final StreamController<WindowHostEvent> _events = StreamController<WindowHostEvent>.broadcast(sync: true);
  final StreamController<WindowHostState> _states = StreamController<WindowHostState>.broadcast(sync: true);
  WindowHostState _currentState = WindowHostState.hidden;
  // Set once initialization succeeds. The listener keeps the window open on
  // close requests until dispose removes it.
  ({Window window, ListenerId listener})? _native;
  bool _disposed = false;

  static Window? _findAppWindow() => switch (defaultTargetPlatform) {
    TargetPlatform.windows => findWindowsRunnerWindow(),
    _ => WindowManager.instance.getCurrent(),
  };

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
    if (_native != null) {
      throw StateError("WindowHost is already initialized");
    }

    final Window window = _findWindow() ?? (throw StateError("The native Sesori window is not available"));
    final ListenerId listenerId = window.addListener(_onWindowEvent);
    try {
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        // macOS only: the content runs under the title bar and the traffic
        // lights stay. Windows and Linux keep their native chrome.
        window.titleBarStyle = TitleBarStyle.hidden;
        window.isWindowControlButtonsVisible = true;
      }
      switch (initialBounds) {
        case final bounds?:
          window.setSize(Size(bounds.width, bounds.height).toNative(), false);
        case null:
          window.setSize(_defaultSize.toNative(), false);
          _centerOnCursorDisplay(window: window);
      }
      window.minimumSize = Size(minimumSize.width, minimumSize.height).toNative();
      window.backgroundColor = const Color(0x00000000).toNative();
      window.title = "Sesori";
      if (initialBounds != null) {
        _applyBounds(window: window, bounds: initialBounds);
      }
      _setTaskbarVisible(window: window, visible: !hidden);
      if (hidden) {
        // Native runners hide the window before the first frame where
        // possible; keep this as a cross-platform fallback for hosts that
        // initially order the window.
        window.hide();
        _emitState(state: WindowHostState.hidden);
      } else {
        _showAndFocus(window: window);
      }
      _terminationChannel.setMethodCallHandler(_onRunnerCall);
      _native = (window: window, listener: listenerId);
    } on Object {
      window.removeListener(listenerId);
      try {
        _setTaskbarVisible(window: window, visible: true);
      } on Object catch (error, stackTrace) {
        logw("Failed to restore Dock/taskbar visibility after window initialization failed", error, stackTrace);
      }
      rethrow;
    }
  }

  Future<void> _onRunnerCall(MethodCall call) async {
    // No exit owner listens yet during startup; the runner then quits as before.
    if (call.method != "quitRequested" || !_events.hasListener) {
      throw MissingPluginException();
    }
    _emitEvent(event: WindowHostEvent.quitRequested);
  }

  void _onWindowEvent(WindowEvent event) {
    switch (event) {
      case WindowCloseRequestedEvent(:final request):
        // The window stays open; the close owner decides between hiding to
        // the tray and quitting.
        request.cancel();
        _emitEvent(event: WindowHostEvent.closeRequested);
      case WindowMovedEvent():
        _emitEvent(event: WindowHostEvent.moved);
      case WindowResizedEvent():
        _emitEvent(event: WindowHostEvent.resized);
      case WindowFocusedEvent():
        if (_currentState != WindowHostState.hidden) {
          _emitState(state: WindowHostState.focused);
        }
      case WindowBlurredEvent():
        if (_currentState != WindowHostState.hidden) {
          _emitState(state: WindowHostState.unfocused);
        }
      case WindowMinimizedEvent():
        _emitState(state: WindowHostState.hidden);
      case WindowRestoredEvent():
        // Leaving the maximized state is reported as a restore too; only
        // leaving the minimized one brings the window back into view.
        if (_currentState == WindowHostState.hidden) {
          _emitState(state: WindowHostState.unfocused);
        }
      default:
        break;
    }
  }

  @override
  Future<WindowBounds> getBounds() async {
    final bounds = _initializedWindow().bounds.toRect();
    return WindowBounds(
      left: bounds.left,
      top: bounds.top,
      width: bounds.width,
      height: bounds.height,
    );
  }

  @override
  Future<void> setBounds({required WindowBounds bounds}) async {
    _applyBounds(window: _initializedWindow(), bounds: bounds);
  }

  @override
  Future<List<WindowBounds>> getDisplayBounds() async {
    _ensureNotDisposed();
    return List<WindowBounds>.unmodifiable(
      _displayManager.getAll().map((display) {
        final workArea = display.workArea.toRect();
        return WindowBounds(left: workArea.left, top: workArea.top, width: workArea.width, height: workArea.height);
      }),
    );
  }

  @override
  Future<void> show() async {
    final window = _initializedWindow();
    _setTaskbarVisible(window: window, visible: true);
    _showAndFocus(window: window);
  }

  @override
  Future<void> hide() async {
    final window = _initializedWindow();
    window.hide();
    _emitState(state: WindowHostState.hidden);
    _setTaskbarVisible(window: window, visible: false);
  }

  @override
  Future<void> startDragging() async {
    _initializedWindow().startDragging();
  }

  @override
  Future<void> toggleZoom() async {
    final window = _initializedWindow();
    if (window.isMaximized) {
      window.unmaximize();
    } else {
      window.maximize();
    }
  }

  @override
  Future<void> setBrightness({required WindowBrightness brightness}) async {
    _initializedWindow();
    _application.setBrightness(switch (brightness) {
      WindowBrightness.light => native.Brightness.light,
      WindowBrightness.dark => native.Brightness.dark,
    });
  }

  /// Centres the window in the work area of the display under the cursor, as
  /// window_manager 0.5 did; the native `center()` picks the main display.
  void _centerOnCursorDisplay({required Window window}) {
    final cursor = _displayManager.getCursorPosition().toOffset();
    final display =
        _displayManager.getAll().where((display) {
          return (display.position.toOffset() & display.size.toSize()).contains(cursor);
        }).firstOrNull ??
        _displayManager.getPrimary();
    if (display == null) {
      window.center();
      return;
    }
    final workArea = display.workArea.toRect();
    final size = window.size.toSize();
    window.position = Offset(
      workArea.left + (workArea.width - size.width) / 2,
      workArea.top + (workArea.height - size.height) / 2,
    ).toNative();
  }

  void _applyBounds({required Window window, required WindowBounds bounds}) {
    window.bounds = Rect.fromLTWH(bounds.left, bounds.top, bounds.width, bounds.height).toNative();
  }

  void _showAndFocus({required Window window}) {
    if (window.isMinimized) {
      window.restore();
    }
    window.show();
    _emitState(state: WindowHostState.unfocused);
    window.focus();
    _emitState(state: WindowHostState.focused);
  }

  /// On macOS the Dock lists apps rather than windows, so this also switches
  /// between the regular and accessory activation policies: the tray stays
  /// available while a hidden window takes the app out of the Dock.
  void _setTaskbarVisible({required Window window, required bool visible}) {
    window.isVisibleInTaskbar = visible;
    _application.setDockIconVisible(visible);
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
    _terminationChannel.setMethodCallHandler(null);
    try {
      // Without the listener the window closes natively again.
      if (_native case (:final window, :final listener)?) {
        window.removeListener(listener);
      }
    } on Object catch (error, stackTrace) {
      logw("Failed to restore native close behavior while disposing the window host", error, stackTrace);
    } finally {
      await Future.wait<void>([_events.close(), _states.close()]);
    }
  }

  Window _initializedWindow() {
    _ensureNotDisposed();
    return _native?.window ?? (throw StateError("WindowHost is not initialized"));
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError("WindowHost is disposed");
    }
  }
}
