import "package:meta/meta.dart";

/// Events emitted by the dumb native-window adapter.
enum WindowHostEvent() {
  closeRequested,
  moved,
  resized,
}

/// Platform-neutral native window size in logical pixels.
@immutable
class const WindowSize({
  required final double width,
  required final double height,
}) {
  @override
  bool operator ==(Object other) => other is WindowSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

/// Platform-neutral native window or display rectangle in logical pixels.
@immutable
class const WindowBounds({
  required final double left,
  required final double top,
  required final double width,
  required final double height,
}) {
  double get right => left + width;

  double get bottom => top + height;

  double get centerX => left + width / 2;

  double get centerY => top + height / 2;

  @override
  bool operator ==(Object other) {
    return other is WindowBounds &&
        other.left == left &&
        other.top == top &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(left, top, width, height);
}

/// Layer-0 capability for the desktop application's native window.
///
/// The adapter owns only native window operations and translates callbacks to
/// typed events. Layer-3/4 business logic owns persistence, attention policy,
/// and whether a close hides the window or performs a safe application quit.
abstract interface class WindowHost() {
  Stream<WindowHostEvent> get events;

  /// Prepares the native window before the Flutter application is rendered.
  ///
  /// [initialBounds] and [minimumSize] have already been validated by the
  /// owning service. Bounds are applied before the first explicit show. A
  /// hidden launch keeps the native surface out of sight until the tray
  /// availability decision is known.
  Future<void> initialize({
    required bool hidden,
    required WindowBounds? initialBounds,
    required WindowSize minimumSize,
  });

  Future<WindowBounds> getBounds();

  Future<void> setBounds({required WindowBounds bounds});

  /// Returns usable work-area rectangles for the currently attached displays.
  Future<List<WindowBounds>> getDisplayBounds();

  Future<void> show();

  Future<void> hide();

  Future<void> dispose();
}
