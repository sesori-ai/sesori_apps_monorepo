import "dart:async";

import "plugin_status.dart";

/// Publishes a plugin's [PluginStatus] as a replay-latest stream while
/// enforcing the legal-transition state machine documented on [PluginStatus].
///
/// Every new [stream] listener immediately receives the current status, then
/// every subsequent change. After [PluginStopped] is published the stream
/// closes; listeners that subscribe later still receive `PluginStopped`
/// followed by done, so a late subscriber always learns the final state.
///
/// Two publishing paths:
///
/// - [set] — for deliberate lifecycle steps. Throws [StateError] on an
///   illegal transition, because a deliberate illegal step is a bug.
/// - [trySet] — for racy sources (exit monitors, health probes) that may
///   observe a runtime the plugin itself is already tearing down. Illegal
///   transitions are silently dropped and `false` is returned, which is what
///   keeps a clean shutdown from reporting `Failed` after `Stopping`.
///
/// Setting a status equal to the current one is a no-op (no emission) and
/// reports success.
class PluginStatusController {
  PluginStatusController({required PluginStatus initial}) : _current = initial;

  final StreamController<PluginStatus> _updates = StreamController<PluginStatus>.broadcast();
  PluginStatus _current;

  /// The latest published status.
  PluginStatus get current => _current;

  /// Whether [PluginStopped] has been published and the stream has closed.
  bool get isClosed => _current is PluginStopped;

  /// Replay-latest view of the status: each listener first receives the
  /// current status, then live updates until the stream closes after
  /// [PluginStopped].
  Stream<PluginStatus> get stream {
    return Stream<PluginStatus>.multi((listener) {
      listener.add(_current);
      if (isClosed) {
        unawaited(listener.close());
        return;
      }
      final subscription = _updates.stream.listen(
        listener.add,
        onDone: listener.close,
      );
      listener.onCancel = subscription.cancel;
    }, isBroadcast: true);
  }

  /// Publishes a deliberate transition to [next].
  ///
  /// Throws [StateError] when the transition is illegal. A no-op when [next]
  /// equals the current status.
  void set(PluginStatus next) {
    if (!trySet(next)) {
      throw StateError("Illegal plugin status transition: $_current -> $next.");
    }
  }

  /// Publishes [next] if the transition is legal; silently drops it and
  /// returns `false` otherwise.
  ///
  /// Use this from racy status sources — an exit monitor firing during a
  /// clean shutdown must not surface `PluginFailed` after `PluginStopping`.
  bool trySet(PluginStatus next) {
    if (next == _current) {
      return true;
    }
    if (!_current.canTransitionTo(next)) {
      return false;
    }
    _current = next;
    _updates.add(next);
    if (next is PluginStopped) {
      unawaited(_updates.close());
    }
    return true;
  }
}
