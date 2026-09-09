import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// One monotonic deadline shared by preparation, probing, ACP and callback I/O.
class AntigravityAuthenticationBudget({
  required final Duration timeout,
  required final StartAbortSignal abortSignal,
}) {
  final Stopwatch _elapsed = Stopwatch()..start();

  Duration get remaining {
    if (abortSignal.isAborted) throw const PluginStartAbortedException();
    final remaining = timeout - _elapsed.elapsed;
    if (remaining <= Duration.zero) throw TimeoutException("Antigravity authentication deadline elapsed");
    return remaining;
  }
}
