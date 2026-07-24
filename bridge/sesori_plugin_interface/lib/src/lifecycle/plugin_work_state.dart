import "dart:async";

enum PluginWorkState { idle, busy, unknown }

/// Publishes replay-latest generic work state without exposing backend-specific
/// turn, process, or session status values to bridge core.
class PluginWorkStateController {
  PluginWorkStateController({required PluginWorkState initial}) : _current = initial;

  final StreamController<PluginWorkState> _updates = StreamController<PluginWorkState>.broadcast();
  PluginWorkState _current;
  bool _closed = false;
  Future<void>? _closeFuture;

  PluginWorkState get current => _current;

  Stream<PluginWorkState> get stream {
    return Stream<PluginWorkState>.multi((listener) {
      listener.add(_current);
      if (_closed) {
        unawaited(listener.close());
        return;
      }
      final subscription = _updates.stream.listen(listener.add, onDone: listener.close);
      listener.onCancel = subscription.cancel;
    }, isBroadcast: true);
  }

  void set(PluginWorkState next) {
    if (_closed || next == _current) return;
    _current = next;
    _updates.add(next);
  }

  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    _closed = true;
    await _updates.close();
  }
}
