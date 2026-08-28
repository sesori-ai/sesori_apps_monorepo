/// Events emitted by the dumb native-window adapter.
// WORKAROUND: dart_style 3.1.12 crashes on empty enhanced enum constructors.
// ignore: use_primary_constructors
enum WindowHostEvent { closeRequested }

/// Layer-0 capability for the desktop application's native window.
///
/// The adapter owns only native window operations and translates callbacks to
/// typed events. Layer-4 business logic decides whether a close hides the
/// window or performs a safe application quit.
abstract interface class WindowHost() {
  Stream<WindowHostEvent> get events;

  /// Prepares the native window before the Flutter application is rendered.
  Future<void> initialize();

  Future<void> show();

  Future<void> hide();

  Future<void> dispose();
}
