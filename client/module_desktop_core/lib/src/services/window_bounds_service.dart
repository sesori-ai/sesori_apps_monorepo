import "dart:async";
import "dart:math" as math;

import "package:injectable/injectable.dart";
import "package:meta/meta.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../foundation/platform/window_host.dart";
import "../repositories/desktop_instance_repository.dart";

/// Layer-3 owner of native window-bounds restoration and persistence.
@lazySingleton
class WindowBoundsService._create({
  required final WindowHost _windowHost,
  required final DesktopInstanceRepository _repository,
  required final Duration _persistenceDebounce,
}) {
  new({
    required WindowHost windowHost,
    required DesktopInstanceRepository repository,
  }) : this._create(
         windowHost: windowHost,
         repository: repository,
         persistenceDebounce: const Duration(milliseconds: 300),
       );

  @visibleForTesting
  new test({
    required WindowHost windowHost,
    required DesktopInstanceRepository repository,
    required Duration persistenceDebounce,
  }) : this._create(
         windowHost: windowHost,
         repository: repository,
         persistenceDebounce: persistenceDebounce,
       );

  static const double minimumWidth = 560;
  static const double minimumHeight = 480;

  StreamSubscription<WindowHostEvent>? _eventSubscription;
  Timer? _persistenceTimer;
  Future<void> _pendingWrite = Future<void>.value();
  bool _initialized = false;
  bool _disposed = false;

  /// Restores valid saved bounds before the native adapter first shows the
  /// window, then begins tracking user moves and resizes.
  Future<void> initializeWindow({required bool hidden}) async {
    if (_disposed) {
      throw StateError("WindowBoundsService is disposed");
    }
    if (_initialized) {
      throw StateError("WindowBoundsService is already initialized");
    }

    WindowBounds? initialBounds;
    try {
      initialBounds = await _loadClampedBounds();
    } on Object catch (error, stackTrace) {
      logw("Failed to restore desktop window bounds; using the default window", error, stackTrace);
    }

    await _windowHost.initialize(hidden: hidden, initialBounds: initialBounds);
    _eventSubscription = _windowHost.events.listen(
      (event) => _onWindowEvent(event: event),
      onError: (Object error, StackTrace stackTrace) {
        loge("Desktop window event stream failed", error, stackTrace);
      },
    );
    _initialized = true;
  }

  Future<WindowBounds?> _loadClampedBounds() async {
    final savedBounds = await _repository.readWindowBounds();
    if (savedBounds == null) {
      return null;
    }
    if (!_isUsable(bounds: savedBounds)) {
      logw("Ignoring unusable persisted desktop window bounds");
      return null;
    }

    final displays = (await _windowHost.getDisplayBounds()).where((bounds) => _isUsable(bounds: bounds)).toList();
    if (displays.isEmpty) {
      logw("No usable display work area was available for desktop window restoration");
      return null;
    }

    final display = _selectDisplay(savedBounds: savedBounds, displays: displays);
    return _clampToDisplay(bounds: savedBounds, display: display);
  }

  void _onWindowEvent({required WindowHostEvent event}) {
    switch (event) {
      case WindowHostEvent.moved || WindowHostEvent.resized:
        _schedulePersistence();
      case WindowHostEvent.closeRequested:
        _flushScheduledPersistence();
    }
  }

  void _schedulePersistence() {
    _persistenceTimer?.cancel();
    _persistenceTimer = Timer(_persistenceDebounce, () {
      _persistenceTimer = null;
      _queuePersistence();
    });
  }

  void _flushScheduledPersistence() {
    if (_persistenceTimer == null) {
      return;
    }
    _persistenceTimer?.cancel();
    _persistenceTimer = null;
    _queuePersistence();
  }

  void _queuePersistence() {
    _pendingWrite = _pendingWrite.then((_) => _persistCurrentBounds());
  }

  Future<void> _persistCurrentBounds() async {
    try {
      final bounds = await _windowHost.getBounds();
      if (!_isUsable(bounds: bounds)) {
        logw("Ignoring unusable desktop window bounds update");
        return;
      }
      await _repository.writeWindowBounds(bounds: bounds);
    } on Object catch (error, stackTrace) {
      logw("Failed to persist desktop window bounds", error, stackTrace);
    }
  }

  static WindowBounds _selectDisplay({
    required WindowBounds savedBounds,
    required List<WindowBounds> displays,
  }) {
    WindowBounds selected = displays.first;
    double greatestIntersection = -1;
    for (final display in displays) {
      final intersection = _intersectionArea(first: savedBounds, second: display);
      if (intersection > greatestIntersection) {
        selected = display;
        greatestIntersection = intersection;
      }
    }
    if (greatestIntersection > 0) {
      return selected;
    }

    double shortestDistance = double.infinity;
    for (final display in displays) {
      final horizontalDistance = savedBounds.centerX - display.centerX;
      final verticalDistance = savedBounds.centerY - display.centerY;
      final distance = horizontalDistance * horizontalDistance + verticalDistance * verticalDistance;
      if (distance < shortestDistance) {
        selected = display;
        shortestDistance = distance;
      }
    }
    return selected;
  }

  static double _intersectionArea({required WindowBounds first, required WindowBounds second}) {
    final width = math.max(0.0, math.min(first.right, second.right) - math.max(first.left, second.left));
    final height = math.max(0.0, math.min(first.bottom, second.bottom) - math.max(first.top, second.top));
    return (width * height).toDouble();
  }

  static WindowBounds _clampToDisplay({required WindowBounds bounds, required WindowBounds display}) {
    final minimumUsableWidth = math.min(minimumWidth, display.width);
    final minimumUsableHeight = math.min(minimumHeight, display.height);
    final width = bounds.width.clamp(minimumUsableWidth, display.width).toDouble();
    final height = bounds.height.clamp(minimumUsableHeight, display.height).toDouble();
    final left = bounds.left.clamp(display.left, display.right - width).toDouble();
    final top = bounds.top.clamp(display.top, display.bottom - height).toDouble();
    return WindowBounds(left: left, top: top, width: width, height: height);
  }

  static bool _isUsable({required WindowBounds bounds}) {
    return bounds.left.isFinite &&
        bounds.top.isFinite &&
        bounds.width.isFinite &&
        bounds.height.isFinite &&
        bounds.width > 0 &&
        bounds.height > 0;
  }

  @disposeMethod
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _flushScheduledPersistence();
    await _eventSubscription?.cancel();
    await _pendingWrite;
  }
}
