import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../foundation/control_channel_client.dart";

/// Terminates the supervised bridge if the control channel stays down past a
/// grace period (ADR A9). When the GUI crashes or is force-quit, the OS does
/// not reliably kill the child, so the helper must not linger invisibly with a
/// live token.
///
/// It observes [ControlChannelClient.connectionState]: a `disconnected` event
/// arms a one-shot grace timer; a `connected` event (the client reconnected in
/// time) cancels it; if the timer elapses while still disconnected, the process
/// exits with the given exit code. A clean [ControlChannelClient.dispose] closes the
/// state stream (done) WITHOUT a `disconnected` event, so a normal shutdown
/// never triggers an exit.
class ControlChannelLossListener({
  required final Stream<ControlChannelConnectionState> _connectionState,
  required final void Function(int code) _exitProcess,
  required final Duration _gracePeriod,
  required final int _exitCode,
}) {
  StreamSubscription<ControlChannelConnectionState>? _subscription;
  Timer? _graceTimer;
  bool _disposed = false;

  void start() {
    _subscription ??= _connectionState.listen(_handleState);
  }

  Future<void> dispose() async {
    _disposed = true;
    _graceTimer?.cancel();
    _graceTimer = null;
    // Isolate the cancel so a failure still lets teardown finish.
    try {
      await _subscription?.cancel();
    } on Object catch (error, stackTrace) {
      Log.w("[control] failed to cancel connection-state subscription", error, stackTrace);
    }
    _subscription = null;
  }

  void _handleState(ControlChannelConnectionState state) {
    if (_disposed) return;
    switch (state) {
      case ControlChannelConnectionState.connected:
        _graceTimer?.cancel();
        _graceTimer = null;
      case ControlChannelConnectionState.disconnected:
        _graceTimer ??= Timer(_gracePeriod, _onGraceElapsed);
    }
  }

  void _onGraceElapsed() {
    if (_disposed) return;
    Log.w("[control] control channel lost for ${_gracePeriod.inSeconds}s — exiting supervised bridge");
    _exitProcess(_exitCode);
  }
}
