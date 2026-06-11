import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginFailed;

/// Latches the first `PluginFailed` a plugin's status stream reports and
/// drives the bridge's reaction to it.
///
/// The runner records failures here from the moment `start()` returns,
/// checks [failure] right before entering the relay session, and late-binds
/// [onFailure] to the session's `cancel()` once the session exists — so a
/// terminal plugin failure always produces an orderly shutdown with exit
/// code 1, never a zombie bridge serving requests against a dead plugin.
///
/// Until PR 12 activates the supervisor's exit monitor nothing can emit
/// `PluginFailed` after a successful start; the latch is the (tested)
/// machinery awaiting that signal.
class PluginFailureLatch {
  PluginFailed? _failure;
  void Function(PluginFailed failure)? _onFailure;

  /// The first failure recorded, if any.
  PluginFailed? get failure => _failure;

  /// Records [failure] if none is latched yet; later failures are ignored.
  void record(PluginFailed failure) {
    if (_failure != null) {
      return;
    }
    _failure = failure;
    _onFailure?.call(failure);
  }

  /// Binds the failure reaction, replacing any previous one. Fires
  /// immediately when a failure is already latched, so binding after
  /// [record] cannot miss it.
  void bind(void Function(PluginFailed failure) onFailure) {
    _onFailure = onFailure;
    final failure = _failure;
    if (failure != null) {
      onFailure(failure);
    }
  }
}
